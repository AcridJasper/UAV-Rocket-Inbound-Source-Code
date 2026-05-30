class KFProj_Trace_Minimap extends KFProj_BallisticExplosive
	config(UAVRocket);

var Vector UAVRocketTargetLocation, TraceHitLocation;
var() config float UAVRocketAmount, RocketRing, UAVRocketSpawnOffsetZ, UAVRocketSpeed, RoofCheckDistance;

// On ZED
simulated function ProcessTouch(Actor Other, Vector HitLocation, Vector HitNormal)
{
	TraceHitLocation = HitLocation;
    UAVRocketTargetLocation = HitLocation;
	Super.ProcessTouch(Other, HitLocation, HitNormal);
}

// When explodes
simulated function TriggerExplosion(Vector HitLocation, Vector HitNormal, Actor HitActor)
{
	TraceHitLocation = HitLocation;
    UAVRocketTargetLocation = HitLocation;
	Super.TriggerExplosion(HitLocation, HitNormal, HitActor);
}

simulated protected function StopSimulating()
{
	local int i;
    local vector Normal, EffectStartTrace, EffectEndTrace;
	local KFWeap_Minimap Minimap;

	EffectStartTrace = Location + vect(0,0,1) * 25.f; // off set the trace so it doesn't hit floor were it landed
	EffectEndTrace = EffectStartTrace + vect(0,0,1) * RoofCheckDistance;

   	Minimap = KFWeap_Minimap(Owner);
	Trace(TraceHitLocation, Normal, EffectEndTrace, EffectStartTrace, false,,, TRACEFLAG_Bullet);
    if( IsZero(TraceHitLocation) )
    {
    	if( Role == ROLE_Authority && Physics == PHYS_Falling )
    	{
           	for(i = 0; i < UAVRocketAmount; i++)
            	SpawnUAVRocket();

	    	if( Minimap != none )
	    		Minimap.Launching();	
    	}
    }
    else
    {
	    if( Minimap != none )
	    	Minimap.Refund();	
    }

   	// SpawnUAVRocket();

    Super.StopSimulating();
}

simulated function SpawnUAVRocket()
{
	local KFProj_Rocket_UAV UAVRocket;
	local vector SpawnLocation, Direction;
	local rotator SpawnRotation;
    
    if( Role == ROLE_Authority )
    {
    	SpawnLocation = UAVRocketTargetLocation + (VRand() * (RocketRing));
		SpawnLocation.Z = UAVRocketSpawnOffsetZ;
	    SpawnRotation = Rotator(Direction);
    	Direction = Normal(UAVRocketTargetLocation - SpawnLocation);

		UAVRocket = Spawn( class'KFProj_Rocket_UAV', Instigator,, SpawnLocation, SpawnRotation,, true );
		if( UAVRocket != none )
		{
			UAVRocket.Instigator = Instigator;
			UAVRocket.InstigatorController = Instigator.Controller;
		    UAVRocket.Velocity = Direction * UAVRocketSpeed;
		}
	}
}

simulated protected function PrepareExplosionTemplate()
{
	super.PrepareExplosionTemplate();
	ExplosionTemplate.bIgnoreInstigator = true; // just in case
}

defaultproperties
{
	Physics=PHYS_Falling
	Speed=150000
	MaxSpeed=150000
	TossZ=0
	GravityScale=1.0
	bCanDisintegrate=false

	// Fake ahh explosion :)
	Begin Object Class=KFGameExplosion Name=ExploTemplate0
		Damage=0
		DamageRadius=1
		DamageFalloffExponent=0
		DamageDelay=0.f
		MyDamageType=class'KFDT_Blast_HRG_CranialPopper'

		bIgnoreInstigator=true
        ActorClassToIgnoreForDamage = class'KFPawn_Human'

		// Damage Effects
		KnockDownStrength=0
		FractureMeshRadius=0
		FracturePartVel=0
        ParticleEmitterTemplate=ParticleSystem'WEP_Minimap_EMIT.FX_UAV_Marker'
		ExplosionSound=AkEvent'WW_WEP_EXP_C4.Play_WEP_EXP_C4_Prox_Beep'

		// Camera Shake
		CamShake=none
	End Object
	ExplosionTemplate=ExploTemplate0
}