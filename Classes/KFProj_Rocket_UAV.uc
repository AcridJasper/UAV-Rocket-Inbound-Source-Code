class KFProj_Rocket_UAV extends KFProj_BallisticExplosive
    config(UAVRocket);

var AkEvent SonicBoomSound, PlayRocketTrusterSound, StopRocketTrusterSound, PlayRocketWhizSound, StopRocketWhizSound;

// Contact laser
var() config bool EnableUAVContactLaser;
var ParticleSystemComponent ContactLaserPSC;
var ParticleSystem ContactLaserFX;
var Color ContactLaserColorNeutral;

var() config bool EnableUAVSpotlight;
var SpotLightComponent SpotLightTemplate;
// var PointLightComponent RayLight;
// var LightPoolPriority RayLightPriority;

// VFX with rotation
var GameExplosion VFXExplosionTemplate;

var() config float ExplosionDamage, ExplosionRadius;

simulated event PreBeginPlay()
{
    super.PreBeginPlay();

    if( ExplosionTemplate != none )
    {
        ExplosionTemplate.Damage = ExplosionDamage * UpgradeDamageMod;
        ExplosionTemplate.DamageRadius = ExplosionRadius;
    }
}

simulated function PostBeginPlay()
{
    // if( RayLight != None )
    // {
    //     AttachComponent(RayLight);
    //     `LightPool.RegisterPointLight(RayLight, RayLightPriority);
    // }

    // PlaySoundBase(SonicBoomSound, true,, true, Location);
    PlaySoundBase(PlayRocketWhizSound, true,, true, Location);
    PlaySoundBase(PlayRocketWhizSound, true,, true, Location);
    
    if( EnableUAVContactLaser )
    {
        if( ContactLaserFX != none )
        {
            ContactLaserPSC = new(self) class'ParticleSystemComponent';
            AttachComponent(ContactLaserPSC);
            ContactLaserPSC.SetTemplate( ContactLaserFX );
            ContactLaserPSC.SetColorParameter(name("LaserColorParm"), ContactLaserColorNeutral);
        }
    }

    if( SpotLightTemplate != None )
    {
        SpotLightTemplate.SetEnabled(EnableUAVSpotlight);
        AttachComponent(SpotLightTemplate);
    }

    super.PostBeginPlay();
}

simulated event Tick( float DeltaTime )
{
    // Trace
    local vector TraceHitLocation, TraceHitNormal, TraceStart, TraceEnd;
    local rotator TraceAimDir;
    local float TraceDist;
    // local Actor TraceHitActor;
    // local TraceHitInfo HitInfo;

    super.Tick( DeltaTime );

    if( EnableUAVContactLaser )
    {
        TraceDist = 150000;
        TraceStart = Location;
        TraceAimDir = rotator(Velocity);
        TraceEnd = TraceStart + Vector(TraceAimDir) * TraceDist;
        /*TraceHitActor = */Trace( TraceHitLocation, TraceHitNormal, TraceEnd, TraceStart, true, vect(0,0,0), /*HitInfo*/, TRACEFLAG_Bullet ); //1
        if( IsZero(TraceHitLocation) )
        {
            if( ContactLaserPSC != none )
                ContactLaserPSC.SetVectorParameter('LaserEndpoint', TraceEnd);
        }
        else
        {
            if( ContactLaserPSC != none )
                ContactLaserPSC.SetVectorParameter('LaserEndpoint', TraceHitLocation);
        }
    }

    if( Physics == PHYS_Projectile && Velocity != vect(0,0,0) )
        SetRotation(rotator(Velocity));
}

simulated protected function StopFlightEffects()
{
    Super.StopFlightEffects();

    TriggerVFXExplosion();
    PlaySoundBase(StopRocketTrusterSound);
    PlaySoundBase(StopRocketWhizSound);

    if( SpotLightTemplate != None )
    {
        SpotLightTemplate.SetEnabled(false);
        SpotLightTemplate.DetachFromAny();
        DetachComponent(SpotLightTemplate);
    }

    if( ContactLaserPSC != None )
    {
        ContactLaserPSC.DeactivateSystem();
        DetachComponent(ContactLaserPSC);
        ContactLaserPSC = None;
    }
}

simulated function TriggerVFXExplosion()
{
    local KFExplosionActorReplicated ExploActor;

    if( VFXExplosionTemplate != none )
    {
        ExploActor = Spawn(class'KFExplosionActorReplicated', self,, Location, rotator(vect(0,1,0)),, true);
        if( ExploActor != None )
        {
            ExploActor.Instigator = Instigator;
            ExploActor.InstigatorController = Instigator.Controller;
            ExploActor.bReplicateInstigator = true;
            ExploActor.Explode(VFXExplosionTemplate);
        }
    }
}

defaultproperties
{
    Physics=PHYS_Projectile
    Speed=9000
    MaxSpeed=9000
    TossZ=0
    GravityScale=1.0
    MomentumTransfer=50000.0f
    ArmDistSquared=0
    LifeSpan=12 //15 20

    bWarnAIWhenFired=true

    ContactLaserFX=ParticleSystem'WEP_Minimap_EMIT.FX_UAV_Rocket_Contact_Laser_3P'
    ContactLaserColorNeutral=(R=255,G=0,B=0,A=255)

/*  Begin Object Class=PointLightComponent Name=PointLight0
        LightColor=(R=250,G=160,B=100,A=255)
        Brightness=1.5f
        Radius=1500.f
        FalloffExponent=3.0f
        CastShadows=FALSE
        CastStaticShadows=false
        CastDynamicShadows=false
        bCastPerObjectShadows=false
        bEnabled=true
        LightingChannels=(Indoor=TRUE,Outdoor=TRUE,bInitialized=TRUE)
    End Object
    RayLight=PointLight0
    RayLightPriority=LPP_High*/

    Begin Object Class=LightFunction Name=FlashLightFunction_0
        SourceMaterial=Material'FX_Mat_Lib.VFX_Flashlight_PM'
    End Object

    Begin Object Class=SpotLightComponent Name=SpotLight
        Brightness=1.0 //0.5
        InnerConeAngle=5
        OuterConeAngle=20
        Radius=6000 //8000
        CastShadows=FALSE
        CastStaticShadows=FALSE
        CastDynamicShadows=FALSE
        bCastPerObjectShadows=false
        ForceCastDynamicShadows=FALSE
        Function=FlashLightFunction_0
        LightingChannels=(Indoor=TRUE,Outdoor=TRUE,bInitialized=TRUE)
        bEnabled=false
        bUpdateOwnerRenderTime=TRUE
    End Object
    SpotLightTemplate=SpotLight

    ProjFlightTemplate=ParticleSystem'WEP_Minimap_EMIT.FX_UAV_Projectile'
    ProjFlightTemplateZedTime=ParticleSystem'WEP_Minimap_EMIT.FX_UAV_Projectile'

    bCanDisintegrate=false
    // ProjDisintegrateTemplate=ParticleSystem'ZED_Siren_EMIT.FX_Siren_grenade_disable_01'

    // AmbientSoundPlayEvent=AkEvent'WW_WEP_SA_RPG7.Play_WEP_SA_RPG7_Projectile_Loop'
    // AmbientSoundStopEvent=AkEvent'WW_WEP_SA_RPG7.Stop_WEP_SA_RPG7_Projectile_Loop'

    // Explosion light
    Begin Object Class=PointLightComponent Name=ExplosionPointLight
        LightColor=(R=252,G=218,B=171,A=255)
        Brightness=4.f
        Radius=2000.f
        FalloffExponent=10.f
        CastShadows=False
        CastStaticShadows=FALSE
        CastDynamicShadows=False
        bCastPerObjectShadows=false
        bEnabled=FALSE
        LightingChannels=(Indoor=TRUE,Outdoor=TRUE,bInitialized=TRUE)
    End Object

    SonicBoomSound=AkEvent'WEP_Minimap_SND.Play_UAVRocket_SonicBoom'
    PlayRocketTrusterSound=AkEvent'WEP_Minimap_SND.Play_UAVRocket_Truster'
    StopRocketTrusterSound=AkEvent'WEP_Minimap_SND.Stop_UAVRocket_Truster'
    PlayRocketWhizSound=AkEvent'WEP_Minimap_SND.Play_UAVRocket_Whiz'
    StopRocketWhizSound=AkEvent'WEP_Minimap_SND.Stop_UAVRocket_Whiz'

    // Explosion
    Begin Object Class=KFGameExplosion Name=ExploTemplate0
        // Damage=800 //750
        // DamageRadius=1500
        DamageFalloffExponent=1.5f
        DamageDelay=0.f
        MyDamageType=class'KFDT_Explosive_RPG7'

        // Damage Effects
        KnockDownStrength=0
        FractureMeshRadius=200.0
        FracturePartVel=500.0
        ParticleEmitterTemplate=none //ParticleSystem''
        // ExplosionEffects=KFImpactEffectInfo'WEP_Minimap_ARCH.UAV_Explosion'
        ExplosionSound=AkEvent'WEP_Minimap_SND.Play_UAVRocket_Explosion'

        // Dynamic Light
        ExploLight=ExplosionPointLight
        ExploLightStartFadeOutTime=0.0
        ExploLightFadeOutTime=0.2

        // Camera Shake
        CamShake=CameraShake'FX_CameraShake_Arch.Misc_Explosions.Light_Explosion_Rumble'
        CamShakeInnerRadius=200
        CamShakeOuterRadius=900
        CamShakeFalloff=1.5f
        bOrientCameraShakeTowardsEpicenter=true
    End Object
    ExplosionTemplate=ExploTemplate0

    // this is simply for VFX and sounds (i'm being deadass)
    Begin Object Class=KFGameExplosion Name=ExploTemplate1
        Damage=0
        DamageRadius=0
        DamageFalloffExponent=0
        DamageDelay=0.f
        MomentumTransferScale=0
        MyDamageType=Class'KFDT_Blast_HRG_CranialPopper'

        bIgnoreInstigator=true

        // Damage Effects
        KnockDownStrength=0
        FractureMeshRadius=0.0
        FracturePartVel=0.0
        ExplosionEffects=KFImpactEffectInfo'WEP_Minimap_ARCH.UAV_Explosion'
        ExplosionSound=AkEvent'WEP_Minimap_SND.Play_UAVRocket_ExplosionBlast'

        // Camera Shake
        CamShake=none
    End Object
    VFXExplosionTemplate=ExploTemplate1
}