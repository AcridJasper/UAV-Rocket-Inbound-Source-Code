class KFWeap_Minimap extends KFWeap_MeleeBase
	config(UAVRocket);

var() config int UAVCost;
var AKEvent BuyReadySound, BuyNotReadySound;
var() config float SelfDamageReductionValue;
var vector UAVRocketTargetLocation;

// Name of the special anim used to launch UAV drone 
var name SpawningAnim;

var() AkEvent PersistentSoundLoop;
var() AKEvent PersistentSoundStop;

// Time interval for updating radar positions 
var float RadarUpdateEntitiesTime;
// Distance the radar can track enemies 
var float MaxRadarDistance;
// Speed at which the radar moves (rad/sec) 
var float RadarSpeed;
var byte RadarTargetSize;

var transient array<KFPawn_Monster> EnemiesInRadar;
var transient bool bRequiresRadarClear;

var class<KFGFxWorld_WeaponRadar> RadarUIClass;
var KFGFxWorld_WeaponRadar RadarUI;

var() config bool EnableMinimapCrosshair;
var() config Color CrosshairColor;

// ************************** Radar **************************

simulated state WeaponEquipping
{
	simulated function BeginState(Name PreviousStateName)
	{
		local KFPawn InstigatorPawn;

		super.BeginState(PreviousStateName);

		if( Instigator != none )
		{
			InstigatorPawn = KFPawn(Instigator);
			if( InstigatorPawn != none )
				InstigatorPawn.PlayWeaponSoundEvent(PersistentSoundLoop);
		}

	 	if( WorldInfo.NetMode == NM_Client || WorldInfo.NetMode == NM_Standalone )
			StartRadar();
	}
} 

simulated state WeaponPuttingDown
{
	simulated function BeginState(Name PreviousStateName)
	{
		super.BeginState(PreviousStateName);

	 	if( WorldInfo.NetMode == NM_Client || WorldInfo.NetMode == NM_Standalone )
	 	{
			StopRadar();
			StopFire(HEAVY_ATK_FIREMODE);
		}
	}
}

simulated function StartRadar()
{
	EnemiesInRadar.Length = 0;
	SetTimer(RadarUpdateEntitiesTime, true, nameof(UpdateRadarEntities));
}

simulated function StopRadar()
{
	ClearTimer(nameof(UpdateRadarEntities));
}

simulated function UpdateRadarEntities()
{
	local KFPawn_Monster KFPM;
	local int RadarIndex;
	local bool bIsAlive;

	bIsAlive = false;

	// Get nearby enemies
	foreach CollidingActors(class'KFPawn_Monster', KFPM, MaxRadarDistance, Location, true)
	{
		RadarIndex = FindEnemyTrackedByRadar(KFPM);
		bIsAlive = KFPM.IsAliveAndWell();

		if( RadarIndex == INDEX_NONE )
		{
			if( bIsAlive )
				EnemiesInRadar.AddItem(KFPM);
		}
		else if( !bIsAlive )
			EnemiesInRadar.RemoveItem(KFPM);
	}
}

simulated function int FindEnemyTrackedByRadar(KFPawn_Monster KFPM)
{
	local int i;

	for( i = 0; i < EnemiesInRadar.Length; ++i )
	{
		if( KFPM == EnemiesInRadar[i] )
			return i;
	}

	return INDEX_NONE;
}

simulated function Tick(float Delta)
{
	local float DistanceSqrd;
	local vector Distance, ScreenDirection, UILocation;
	local rotator ViewRotation;
	local int i;
	local array<vector> RadarElements;

	super.Tick(Delta);

	if( RadarUI != none )
	{
		if( bRequiresRadarClear )
			RadarUI.Clear();

		if( EnemiesInRadar.Length == 0 )
		{
			if( bRequiresRadarClear )
				bRequiresRadarClear = false;

			return;
		}

		ViewRotation = Rotation;
		ViewRotation.Yaw  *= -1;
		ViewRotation.Pitch = 0;
		ViewRotation.Roll  = 0;

		RadarElements.Length = 0;

		for( i = EnemiesInRadar.Length - 1; i >= 0; --i )
		{
			if( !EnemiesInRadar[i].IsAliveAndWell() )
			{
				EnemiesInRadar.Remove(i, 1);
				continue;
			}

			Distance = EnemiesInRadar[i].Location - Location;
			DistanceSqrd = VSizeSQ(Distance);

			if( DistanceSqrd > MaxRadarDistance * MaxRadarDistance )
			{
				EnemiesInRadar.Remove(i, 1);
				continue;
			}

			Distance.Z = 0;
			ScreenDirection = Distance >> ViewRotation;

			UILocation.X = ScreenDirection.Y / MaxRadarDistance;
			UILocation.Y = ScreenDirection.X / MaxRadarDistance;

			RadarElements.AddItem(UILocation);
		}

		if( RadarElements.length > 0 )
		{
			RadarUI.AddRadarElements(RadarElements);
			bRequiresRadarClear = true;
		}
	}
}

reliable client function ClientWeaponSet(bool bOptionalSet, optional bool bDoNotActivate)
{
	local KFInventoryManager KFIM;

	super.ClientWeaponSet(bOptionalSet, bDoNotActivate);

	if( RadarUI == none && RadarUIClass != none )
	{
		KFIM = KFInventoryManager(InvManager);
		if( KFIM != none )
			RadarUI = KFGFxWorld_WeaponRadar(KFIM.GetRadarUIMovie(RadarUIClass));
	}
}

function ItemRemovedFromInvManager()
{
	local KFInventoryManager KFIM;

	Super.ItemRemovedFromInvManager();

	if( RadarUI != none )
	{
		KFIM = KFInventoryManager(InvManager);
		if( KFIM != none )
		{
			//Create the screen's UI piece
			KFIM.RemoveRadarUIMovie(RadarUI.class);

			RadarUI.Close();
			RadarUI = none;
		}
	}
}

simulated state Inactive
{
	// when dropped, destroyed, etc, play the stop on the persistent sound
	simulated event BeginState(Name PreviousStateName)
	{
		local KFPawn InstigatorPawn;

		super.BeginState(PreviousStateName);

		if( Instigator != none )
		{
			InstigatorPawn = KFPawn(Instigator);
			if( InstigatorPawn != none )
				InstigatorPawn.PlayWeaponSoundEvent(PersistentSoundStop);
		}
	}
}

// ************************** Crosshair for no reason lmao **************************

simulated function DrawHUD( HUD H, Canvas C )
{
    local Texture2D CrosshairMain, CrosshairDrop;
	local KFPlayerController KFPC;

	KFPC = KFPlayerController(Instigator.Controller);
    if( KFPC != none && KFPC.bCinematicMode )
        return;

    if( EnableMinimapCrosshair )
    {
	   	CrosshairMain = Texture2D'WEP_Minimap_MAT.Minimap_Crosshair'; // main colarable crosshair
	   	CrosshairDrop = Texture2D'WEP_Minimap_MAT.Minimap_Crosshair_Dropshadow'; // drop shadow
		C.SetPos(C.SizeX * 0, C.SizeY * 0);
	    C.DrawColor = CrosshairColor;
	    C.DrawTexture(CrosshairMain, C.ClipX/1920);
	    C.DrawTexture(CrosshairDrop, C.ClipX/1920);
    }
}

exec function ToggleMinimapCrosshair()
{
	EnableMinimapCrosshair = !EnableMinimapCrosshair;
	SaveConfig();
}

exec function ChangeMinimapCrosshairColor(float Red, float Green, float Blue)
{
	CrosshairColor.R = Red;
	CrosshairColor.G = Green;
	CrosshairColor.B = Blue;
	SaveConfig();
}

// ************************** Spawning **************************

// Light attacks (mouse 1 but not holding)
simulated state MeleeSpawning extends MeleeChainAttacking
{
	simulated function bool TryPutDown() { return false; }

	// Overriden to not call FireAmmunition right at the start of the state
    simulated event BeginState( Name PreviousStateName )
	{
        local KFPerk InstigatorPerk;
		local KFPawn_Human KFPawn;
		local KFPlayerReplicationInfo KFPRI;
    	local KFPlayerController KFPC;

/*    	// Main trace
    	local vector HitNormal, StartTrace, EndTrace;
    	local rotator AimRot;
    	local float TraceDist;
    	// Up trace
    	local vector UpTargetLocation, UpHitNormal, UpStartTrace, UpEndTrace;
    	local rotator UpAimRot;
    	local float UpTraceDist;*/

        InstigatorPerk = GetPerk();
        if( InstigatorPerk != none )
            SetZedTimeResist( InstigatorPerk.GetZedTimeModifier(self) );

		// ConsumeAmmo(CurrentFireMode);

		// Rocket cost money to spawn
		KFPawn = KFPawn_Human(Instigator);
    	KFPC = KFPlayerController(Instigator.Controller);
		KFPRI = KFPlayerReplicationInfo(Instigator.Controller.PlayerReplicationInfo);
		if( KFPRI.Score <= UAVCost )
		{
			KFPawn.PlaySoundBase(BuyNotReadySound);
      		KFPC.MyGFxHUD.HudChatBox.AddChatMessage("Not enough dosh to launch UAV Rocket", "FF0000");
		}
		else
		{
			KFPRI.AddDosh(-UAVCost); // Take away some dosh for the purchance
			KFPawn.PlaySoundBase(BuyReadySound);

			// stop the player from interrupting the super attack with another attack
			StartFireDisabled = true;
			
			ProjectileFire(); // This launches the rocket

			// this doesn't spawn when trace collides with ZED or coprses
/*			// Main trace
			TraceDist = 150000;
    		StartTrace = GetSafeStartTraceLocation();
    		AimRot = GetAdjustedAim(StartTrace);
    		EndTrace = StartTrace + vector(AimRot) * TraceDist;
    		Trace( UAVRocketTargetLocation, HitNormal, EndTrace, StartTrace, true, vect(0,0,0),, 1 );
    		// DrawDebugLine( UAVRocketTargetLocation, StartTrace, 255,0,0, true );

    		// Up trace (this goes up from main trace looking for ceiling)
			UpTraceDist = 2500;
	    	UpStartTrace = UAVRocketTargetLocation;
	    	UpAimRot = rotator(vect(0,0,1));
    		UpEndTrace = UpStartTrace + vector(UpAimRot) * UpTraceDist;
    		Trace( UpTargetLocation, UpHitNormal, UpEndTrace, UpStartTrace, true, vect(0,0,0),, 1 );
    		// DrawDebugLine( UpTargetLocation, UpStartTrace, 255,0,255, true );
    		if( UpTargetLocation == vect(0,0,0) )
    		{
				KFPRI.AddDosh(-UAVCost); // Take away some dosh for the purchance
				KFPawn.PlaySoundBase(BuyReadySound);
	    		SpawnUAVRocket();
    		}
	    	else
      			KFPC.MyGFxHUD.HudChatBox.AddChatMessage("Can't launch UAV Rocket, it's blocked by roof !", "FF0000");*/
		}

	    // set timer for spawning projectile
		TimeWeaponFiring(CurrentFireMode);
		ClearPendingFire(CurrentFireMode);

		NotifyBeginState();
	}

	simulated function name GetMeleeAnimName(EPawnOctant AtkDir, EMeleeAttackType AtkType)
	{
		// use the special attack anim
		return SpawningAnim;
	}

	simulated function EndState(Name NextStateName)
	{
		Super.EndState(NextStateName);
		ClearZedTimeResist();
		NotifyEndState();

		// player can now interrupt attacks with other attacks again
		StartFireDisabled = false;

		NotifyWeaponFired(CurrentFireMode);
	}
}

simulated function Refund()
{
    local KFPlayerController KFPC;
	local KFPlayerReplicationInfo KFPRI;

    KFPC = KFPlayerController(Instigator.Controller);
	KFPRI = KFPlayerReplicationInfo(Instigator.Controller.PlayerReplicationInfo);
	if( KFPRI != none )
		KFPRI.AddDosh(UAVCost); // Refund

	if( KFPC != none )
    	KFPC.MyGFxHUD.HudChatBox.AddChatMessage("Can't launch UAV Rocket, it's blocked by roof !", "FF0000");
}

simulated function Launching()
{
    local KFPlayerController KFPC;

    KFPC = KFPlayerController(Instigator.Controller);
	if( KFPC != none )
    	KFPC.MyGFxHUD.HudChatBox.AddChatMessage("UAV Rocket inbound", "AAFF00");
}

function SpawnUAVRocket()
{
	local KFProj_Rocket_UAV UAVRocket;
	local vector SpawnLocation, Direction;
	local rotator SpawnRotation;
    
    if( Role == ROLE_Authority )
    {
    	SpawnLocation = UAVRocketTargetLocation + (VRand() * (float(2000)));
		SpawnLocation.Z = float(20000);
	    SpawnRotation = Rotator(Direction);
    	Direction = Normal(UAVRocketTargetLocation - SpawnLocation);

		UAVRocket = Spawn( class'KFProj_Rocket_UAV', Instigator,, SpawnLocation, SpawnRotation,, true );
		if( UAVRocket != none )
		{
			UAVRocket.Instigator = Instigator;
			UAVRocket.InstigatorController = Instigator.Controller;
		    UAVRocket.Velocity = Direction * float(6000);
		}
	}
}

// Reduce the damage received from self attacks
function AdjustDamage(out int InDamage, class<DamageType> DamageType, Actor DamageCauser)
{
    super.AdjustDamage(InDamage, DamageType, DamageCauser);

	if( Instigator != none && DamageCauser.Instigator == Instigator )
		InDamage *= SelfDamageReductionValue;
}

defaultproperties
{
	BuyReadySound=AkEvent'WW_WEP_HRG_SonicGun.Play_WEP_HRG_SonicGun_Charge_Once'
	BuyNotReadySound=AkEvent'WW_WEP_SA_SW500.Play_WEP_SA_SW500_Handling_DryFire'

	RadarUpdateEntitiesTime=0.1f
	MaxRadarDistance=2000
	RadarSpeed=2.0f
	RadarTargetSize=10.0f
	RadarUIClass=class'KFGFxWorld_WeaponRadar'
    NumBloodMapMaterials=2 // no blood on radar itself
	bRequiresRadarClear=false

	PlayerViewOffset=(X=12,Y=6,Z=0.5)
	
	// Content
	PackageKey="Minimap"
	FirstPersonMeshName="WEP_Minimap_MESH.WEP_1stP_Minimap_Rig"
	FirstPersonAnimSetNames(0)="WEP_Minimap_ARCH.Wep_1stP_Minimap_Anim"
	PickupMeshName="WEP_Minimap_MESH.Wep_Minimap_Pickup"
	AttachmentArchetypeName="WEP_Minimap_ARCH.Wep_Minimap_3P"

    // Inventory
    InventoryGroup=IG_Equipment
	GroupPriority=47
	InventorySize=1
	bCanThrow=true
	bDropOnDeath=true
	WeaponSelectTexture=Texture2D'WEP_Minimap_MAT.UI_WeaponSelect_Minimap'

	// DEFAULT_FIREMODE
	FireModeIconPaths(DEFAULT_FIREMODE)=Texture2D'WEP_Minimap_MAT.UI_FireModeSelect_Minimap'
	FiringStatesArray(DEFAULT_FIREMODE)=MeleeSpawning
	WeaponFireTypes(DEFAULT_FIREMODE)=EWFT_Projectile
	WeaponProjectiles(DEFAULT_FIREMODE)=class'KFProj_Trace_Minimap'
	InstantHitDamageTypes(DEFAULT_FIREMODE)=none
	InstantHitDamage(DEFAULT_FIREMODE)=0
	FireInterval(DEFAULT_FIREMODE)=1 // 60 RPM //1.33 //45 RPM
	AmmoCost(BASH_FIREMODE)=0
	FireOffset=(X=0,Y=0,Z=0)

	SpawningAnim=Guncheck_v2

	// HEAVY_ATK_FIREMODE (Does only bash attacks)
	FiringStatesArray(HEAVY_ATK_FIREMODE)=MeleeAttackBasic
	InstantHitDamageTypes(HEAVY_ATK_FIREMODE)=class'KFDT_Bludgeon_Carryable'
	InstantHitDamage(HEAVY_ATK_FIREMODE)=60
	InstantHitMomentum(HEAVY_ATK_FIREMODE)=30000.f

	// Does only bash attacks
	FiringStatesArray(BASH_FIREMODE)=MeleeAttackBasic
	InstantHitDamageTypes(BASH_FIREMODE)=class'KFDT_Bludgeon_Carryable'
	InstantHitDamage(BASH_FIREMODE)=60
	InstantHitMomentum(BASH_FIREMODE)=30000.f

	// Block Sounds
	BlockSound=AkEvent'ww_wep_steampunk_gear.Play_WEP_Gear_Block'
	ParrySound=AkEvent'WW_WEP_Bullet_Impacts.Play_Parry_Metal'
	
	ParryStrength=5
	ParryDamageMitigationPercent=0.80
	BlockDamageMitigation=0.60

	PersistentSoundLoop=AkEvent'WW_WEP_Datapad.Play_WEP_Datapad_Hold_LP'
	PersistentSoundStop=AkEvent'WW_WEP_Datapad.Stop_WEP_Datapad_Hold_LP'

    // IdleFidgetAnims=(Guncheck_v1, Guncheck_v2)

	AssociatedPerkClasses(0)=none
}