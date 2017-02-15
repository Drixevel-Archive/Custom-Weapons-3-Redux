#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2items>
#include <tf2attributes>
#include <smlib>

#include <cw3-attributes>

// Sounds
#define SOUND_EXPLOSION_BIG                 "ambient/explosions/explode_8.wav"
#define SOUND_1217_RELOAD                   "weapons/shotgun_reload.wav"
#define SOUND_FIRELEAK_OIL                "physics/flesh/flesh_bloody_impact_hard1.wav"
#define SOUND_FLAME_ENGULF                  "misc/flame_engulf.wav"
#define SOUND_BONEBREAK						"player/pl_fleshbreak.wav"

// Particles
#define PARTICLE_FIRE                       "buildingdamage_dispenser_fire1"
#define PARTICLE_AREA_FIRE_BLUE             "player_glowblue"
#define PARTICLE_WHITE_PARTICLE             "arm_muzzleflash_flare"

// Models
#define MODEL_DEFAULTPHYSICS                "models/props_2fort/coffeepot.mdl"
#define MODEL_FIRELEAK                  "models/props_farm/haypile001.mdl"

// Teams
#define TEAM_SPEC    0
#define TEAM_RED    2
#define TEAM_BLUE   3

// Damage Types
#define TF_DMG_BULLET                       (1 << 1) // 2
#define TF_DMG_BLEED                        (1 << 2) // 4
#define TF_DMG_CRIT                         (1 << 20) // 1048576
#define TF_DMG_UNKNOWN_1                    (1 << 11) // 2048
#define TF_DMG_FIRE                         (1 << 24) // 16777216
#define TF_DMG_AFTERBURN                    TF_DMG_UNKNOWN_1 | (1 << 3) // 2048 + 8 = 2056

#define TF_DMG_MELEE                        (1 << 27) | (1 << 12) | (1 << 7)    // 134217728 + 4096 + 128 = 134221952
#define TF_DMG_MELEE_CRIT                   TF_DMG_MELEE | TF_DMG_CRIT // 134221952 + 1048576 = 135270528

#define TF_DMG_PROPAGATE                    (1 << 31) //Att #1212

#define    MAX_EDICT_BITS    11
#define    MAX_EDICTS        (1 << MAX_EDICT_BITS)

// Attribute Stuff
#define ATTRIBUTE_1026_PUSHSCALE                    0.03
#define ATTRIBUTE_1026_PUSHMAX                      3.0
#define ATTRIBUTE_1026_COOLDOWN                     3.5

#define ATTRIBUTE_FIRELEAK_TIME         0.5
#define ATTRIBUTE_FIRELEAK_COST         30

new Float:fAttribute_1034_Time[MAXPLAYERS+1] = 0.0;

new Float:g_fOilLeakDelay[MAXPLAYERS+1] = 0.0;
new g_iOilLeakStatus[MAX_EDICTS + 1] = 0;
new g_iOilLeakDamage[MAXPLAYERS+1] = 0;
new g_iOilLeakDamageOwner[MAXPLAYERS+1] = 0;
new Float:g_fOilLeakLife[MAX_EDICTS + 1] = 0.0;

new Handle:g_hOilLeakEntities = INVALID_HANDLE;

new g_iAchBoilerTimer1193[MAXPLAYERS+1] = 0;
new g_iAchBoilerBurner1193[MAXPLAYERS+1] = 0;

new Float:g_fTotalDamage1296[MAXPLAYERS+1] = 0.0;

new bool:g_bFastCloaked[MAXPLAYERS+1] = false;
new g_entitySlot[MAX_EDICTS+1] = -1;
new Float:g_fEntityCreateTime[MAX_EDICTS+1] = 0.0;
new g_iLastButtons[MAXPLAYERS+1] = 0;
new bool:g_bWasDisguised[MAXPLAYERS+1] = false;

new bool:g_bHiddenEntities[MAX_EDICTS+1] = false;

new g_iTeamColor[4][4];
new g_iTeamColorSoft[4][4];

new Handle:g_hAllowDownloads = INVALID_HANDLE;
new Handle:g_hDownloadUrl = INVALID_HANDLE;

new g_iExplosionSprite;
new g_iHaloSprite;
new g_iWhite;
new g_iBeamSprite;

// Homing rockets data
#define FPS_LOGIC_RATE        22.0
new Handle:g_hLogicTimer;    // Logic timer
new Handle:g_hProjectileList = INVALID_HANDLE;

new g_iCloakIsHook[MAXPLAYERS+1] = 0;
new Float:g_fCloakIsHookTime[MAXPLAYERS+1] = 0.0;
new Float:g_vCloakIsHookOrigin[MAXPLAYERS+1][3];

new oldDisguise[MAXPLAYERS+1][3];

new bool:isInfected[MAXPLAYERS+1] = false;

new bool:g_bAttWallSmash[MAXPLAYERS+1] = false;
new g_iAttWallSmashAttacker[MAXPLAYERS+1] = false;

new String:g_strSound1315Ping[][PLATFORM_MAX_PATH] = {
	"physics/flesh/flesh_strider_impact_bullet1.wav",
	"physics/flesh/flesh_strider_impact_bullet2.wav",
	"physics/flesh/flesh_strider_impact_bullet3.wav"
};

#define PLUGIN_VERSION "2.0.1"

public Plugin:myinfo =
{
	name = "Custom Weapons 3: AW2 Attributes",
	author = "MechaTheSlag (Attributes & AW2), Theray070696 (Porting to CW2 and CW3)",
	description = "Advanced Weaponiser 2's attributes, ported to Custom Weapons 3!",
	version = PLUGIN_VERSION,
	url = ""
};

new bool:FastcloakOnBackstab[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:ProjectilesBounce[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ProjectilesBounce_Count[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:Earthquake[MAXPLAYERS + 1][MAXSLOTS + 1];
new bool:EarthquakeActive[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:Earthquake_Range[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:DamageReloads[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:DamageReloads_Max[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:DamageReloads_Damage[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:AltFireIsOil[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:AttackWhileCloaked[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:ResetAfterburn[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:ControllableProjectiles[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ControllableProjectiles_Control[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:ItemIsHeavy[MAXPLAYERS + 1][MAXSLOTS + 1];
new bool:ItemIsHeavyActive[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ItemIsHeavy_Force[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:NoReloading[2049];

new bool:CloakIsHook[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:ReducedFallDamage[MAXPLAYERS + 1][MAXSLOTS + 1];
new bool:ReducedFallDamageActive[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ReducedFallDamage_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:ShareDamage[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ShareDamage_Range[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ShareDamage_Ratio[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:ReflectCrits[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:ChargeLand[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ChargeLand_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:CritCharging[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:CrouchCloak[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:CrouchCloak_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:JumpCloak[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:JumpCloak_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:RemoveDebuffCloak[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:CloakOnlyWhenFullMeter[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:DrawMiniCrits[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:DrawMiniCrits_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:DamageOnGround[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:DamageOnGround_Value1[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:DamageOnGround_Value2[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:ReducedDamageInAir[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ReducedDamageInAir_Value1[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ReducedDamageInAir_Value2[MAXPLAYERS + 1][MAXSLOTS + 1];
new bool:ReducedDamageInAirActive[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:KeepDisguiseOnBackstab[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:InfectVictimOnBackstab[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:InfectVictimOnBackstab_TimeToStun[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:InfectVictimOnBackstab_TimeToDeath[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:WallKill[MAXPLAYERS + 1][MAXSLOTS + 1];
new WallKill_Damage[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:SentryHeal[MAXPLAYERS + 1][MAXSLOTS + 1];
new bool:SentryHealActive[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:SentryHeal_Ratio[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:SentryHeal_Max[MAXPLAYERS + 1][MAXSLOTS + 1];

public OnPluginStart()
{
	CreateConVar("sm_aw2_attrib_version", PLUGIN_VERSION, "Don't touch this!");
	
	HookEvent("post_inventory_application", EventPlayerInventory);
	HookEvent("player_spawn", EventPlayerSpawn);
	HookEvent("rocket_jump_landed", Attributes_JumpLand);
	HookEvent("sticky_jump_landed", Attributes_JumpLand);
	HookEvent("object_deflected", Attributes_Deflect);
	HookEvent("player_death", Attributes_Death);
	
	HookEntityOutput("item_healthkit_small", "OnPlayerTouch", Attributes_HealthKit);
	HookEntityOutput("item_healthkit_medium", "OnPlayerTouch", Attributes_HealthKit);
	HookEntityOutput("item_healthkit_full", "OnPlayerTouch", Attributes_HealthKit);
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) continue;
		OnClientPutInServer(i);
	}
	
	MiscOnPluginStart();
	AttributesInit();
	
	g_hLogicTimer = INVALID_HANDLE;
	g_hProjectileList = CreateArray(1);
}

stock MiscOnPluginStart()
{
	g_iTeamColor[TEAM_RED][0] = 255;
	g_iTeamColor[TEAM_RED][1] = 0;
	g_iTeamColor[TEAM_RED][2] = 0;
	g_iTeamColor[TEAM_RED][3] = 255;
	g_iTeamColor[TEAM_BLUE][0] = 0;
	g_iTeamColor[TEAM_BLUE][1] = 0;
	g_iTeamColor[TEAM_BLUE][2] = 255;
	g_iTeamColor[TEAM_BLUE][3] = 255;
	
	g_iTeamColorSoft[TEAM_RED][0] = 189;
	g_iTeamColorSoft[TEAM_RED][1] = 59;
	g_iTeamColorSoft[TEAM_RED][2] = 59;
	g_iTeamColorSoft[TEAM_RED][3] = 255;
	g_iTeamColorSoft[TEAM_BLUE][0] = 91;
	g_iTeamColorSoft[TEAM_BLUE][1] = 122;
	g_iTeamColorSoft[TEAM_BLUE][2] = 140;
	g_iTeamColorSoft[TEAM_BLUE][3] = 255;
}

public OnPluginEnd()
{
	AttributesStop();
}

public OnMapStart()
{
	g_hLogicTimer = CreateTimer(1.0 / FPS_LOGIC_RATE, OnThinkRocketHook, _, TIMER_REPEAT);
	ClearArray(g_hProjectileList);
	
	MiscOnMapStart();
	Attributes_Precache();
}

public OnMapEnd()
{
	ClearArray(g_hProjectileList);
	if(g_hLogicTimer != INVALID_HANDLE) KillTimer(g_hLogicTimer);
	g_hLogicTimer = INVALID_HANDLE;
}

stock MiscOnMapStart()
{
	g_hAllowDownloads = FindConVar("sv_allowdownload");
	g_hDownloadUrl = FindConVar("sv_downloadurl");
	
	g_iWhite = PrecacheModel("materials/sprites/white.vmt");
	g_iBeamSprite = PrecacheModel("materials/cable/rope.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	g_iExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");
}

stock Attributes_Precache()
{
	// Particles
	PrecacheParticle(PARTICLE_FIRE);
	PrecacheParticle(PARTICLE_AREA_FIRE_BLUE);
	PrecacheParticle(PARTICLE_WHITE_PARTICLE);
	
	// Models
	SuperPrecacheModel(MODEL_FIRELEAK);
	SuperPrecacheModel(MODEL_DEFAULTPHYSICS, true);
	
	// Sounds
	SuperPrecacheSound(SOUND_EXPLOSION_BIG);
	SuperPrecacheSound(SOUND_FIRELEAK_OIL);
	SuperPrecacheSound(SOUND_FLAME_ENGULF);
	SuperPrecacheSound(SOUND_BONEBREAK);
	SuperPrecacheSound(SOUND_1217_RELOAD);
	
	for(new i = 0; i < sizeof(g_strSound1315Ping); i++)
	{
		SuperPrecacheSound(g_strSound1315Ping[i]);
	}
}

public Attributes_HealthKit(const String:output[], caller, activator, Float:delay)
{
	if(Client_IsValid(activator) && IsClientInGame(activator) && IsPlayerAlive(activator))
	{
		if(isInfected[activator])
		{
			isInfected[activator] = false;
		}
	}
}

public Action:CW3_OnAddAttribute(slot, client, const String:attrib[], const String:plugin[], const String:value[], bool:whileActive)
{
	if(!StrEqual(plugin, "advanced-weaponiser-2-attributes") && !StrEqual(plugin, "aw2attrib")) return Plugin_Continue;
	
	new weapon = GetPlayerWeaponSlot(client, slot);
	
	new Action:action;
	
	if(StrEqual(attrib, "fastcloak on backstab", false))
	{
		FastcloakOnBackstab[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "projectiles bounce", false))
	{
		ProjectilesBounce[client][slot] = true;
		ProjectilesBounce_Count[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "earthquake on rocket jump land", false))
	{
		Earthquake[client][slot] = true;
		
		if(whileActive)
		{
			EarthquakeActive[client][slot] = true;
		}
		
		Earthquake_Range[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "reload clip on damage"))
	{
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		DamageReloads[client][slot] = true;
		
		DamageReloads_Max[client][slot] = StringToFloat(values[0]);
		DamageReloads_Damage[client][slot] = StringToFloat(values[1]);
		
		g_fTotalDamage1296[client] = 0.0;
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "alt fire is oil"))
	{
		AltFireIsOil[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "attack while cloaked"))
	{
		AttackWhileCloaked[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "reset afterburn"))
	{
		ResetAfterburn[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "controllable projectiles"))
	{
		ControllableProjectiles[client][slot] = true;
		
		ControllableProjectiles_Control[client][slot] = StringToFloat(value) * 1000.0;
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "item is heavy"))
	{
		ItemIsHeavy[client][slot] = true;
		
		if(whileActive)
		{
			ItemIsHeavyActive[client][slot] = true;
		}
		
		ItemIsHeavy_Force[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "no reloading"))
	{
		if(weapon == -1) return Plugin_Continue;
		
		NoReloading[weapon] = true;
		TF2Attrib_SetByName(weapon, "reload time increased hidden", 1001.0);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "cloak is hook"))
	{
		CloakIsHook[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "fall dmg reduced"))
	{
		ReducedFallDamage[client][slot] = true;
		
		if(whileActive)
		{
			ReducedFallDamageActive[client][slot] = true;
		}
		
		ReducedFallDamage_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "share damage"))
	{
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		ShareDamage[client][slot] = true;
		
		ShareDamage_Range[client][slot] = StringToFloat(values[0]);
		ShareDamage_Ratio[client][slot] = StringToFloat(values[1]);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "reflected projectiles crit"))
	{
		ReflectCrits[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "charge on explosive jump land"))
	{
		ChargeLand[client][slot] = true;
		
		ChargeLand_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "crit charging players"))
	{
		CritCharging[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "crouch to cloak"))
	{
		CrouchCloak[client][slot] = true;
		
		CrouchCloak_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "increased jump height while cloaked"))
	{
		JumpCloak[client][slot] = true;
		
		JumpCloak_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "on cloak remove debuffs"))
	{
		RemoveDebuffCloak[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "only cloak with full meter"))
	{
		CloakOnlyWhenFullMeter[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "on switch give and take mini crits"))
	{
		DrawMiniCrits[client][slot] = true;
		
		DrawMiniCrits_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "deal more damage in air"))
	{
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		DamageOnGround[client][slot] = true;
		
		DamageOnGround_Value1[client][slot] = StringToFloat(values[0]);
		DamageOnGround_Value2[client][slot] = StringToFloat(values[1]);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "damage mod air ground"))
	{
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		ReducedDamageInAir[client][slot] = true;
		
		if(whileActive)
		{
			ReducedDamageInAirActive[client][slot] = true;
		}
		
		ReducedDamageInAir_Value1[client][slot] = StringToFloat(values[0]);
		ReducedDamageInAir_Value2[client][slot] = StringToFloat(values[1]);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "keep disguise on backstab"))
	{
		KeepDisguiseOnBackstab[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "infect victim on backstab"))
	{
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		InfectVictimOnBackstab[client][slot] = true;
		
		InfectVictimOnBackstab_TimeToStun[client][slot] = StringToFloat(values[0]);
		InfectVictimOnBackstab_TimeToDeath[client][slot] = StringToFloat(values[1]);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "kill victim on wall hit"))
	{
		WallKill[client][slot] = true;
		
		WallKill_Damage[client][slot] = StringToInt(value);
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "sentry heals builder"))
	{
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		SentryHeal[client][slot] = true;
		
		if(whileActive)
		{
			SentryHealActive[client][slot] = true;
		}
		
		SentryHeal_Ratio[client][slot] = StringToFloat(values[0]);
		SentryHeal_Max[client][slot] = StringToFloat(values[1]);
		
		action = Plugin_Handled;
	}
	
	if(!m_bHasAttribute[client][slot]) m_bHasAttribute[client][slot] = bool:action;
	
	return action;
}

public Attributes_Death(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(Client_IsValid(client))
	{
		oldDisguise[client][0] = 0;
		oldDisguise[client][1] = 0;
		oldDisguise[client][2] = 0;
		
		isInfected[client] = false;
	}
}

public CW3_OnWeaponRemoved(slot, client)
{
	if(Client_IsValid(client))
	{
		m_bHasAttribute[client][slot] = false;
		
		FastcloakOnBackstab[client][slot] = false;
		
		ProjectilesBounce[client][slot] = false;
		ProjectilesBounce_Count[client][slot] = 0.0;
		
		Earthquake[client][slot] = false;
		EarthquakeActive[client][slot] = false;
		Earthquake_Range[client][slot] = 0.0;
		
		DamageReloads[client][slot] = false;
		DamageReloads_Max[client][slot] = 0.0;
		DamageReloads_Damage[client][slot] = 0.0;
		
		AltFireIsOil[client][slot] = false;
		
		AttackWhileCloaked[client][slot] = false;
		
		ResetAfterburn[client][slot] = false;
		
		ControllableProjectiles[client][slot] = false;
		ControllableProjectiles_Control[client][slot] = 0.0;
		
		ItemIsHeavy[client][slot] = false;
		ItemIsHeavyActive[client][slot] = false;
		ItemIsHeavy_Force[client][slot] = 0.0;
		
		CloakIsHook[client][slot] = false;
		
		ReducedFallDamage[client][slot] = false;
		ReducedFallDamageActive[client][slot] = false;
		ReducedFallDamage_Value[client][slot] = 0.0;
		
		ShareDamage[client][slot] = false;
		ShareDamage_Range[client][slot] = 0.0;
		ShareDamage_Ratio[client][slot] = 0.0;
		
		ReflectCrits[client][slot] = false;
		
		ChargeLand[client][slot] = false;
		ChargeLand_Value[client][slot] = 0.0;
		
		CritCharging[client][slot] = false;
		
		CrouchCloak[client][slot] = false;
		CrouchCloak_Value[client][slot] = 255.0;
		
		JumpCloak[client][slot] = false;
		JumpCloak_Value[client][slot] = 0.0;
		
		RemoveDebuffCloak[client][slot] = false;
		
		CloakOnlyWhenFullMeter[client][slot] = false;
		
		DrawMiniCrits[client][slot] = false;
		DrawMiniCrits_Value[client][slot] = 0.0;
		
		DamageOnGround[client][slot] = false;
		DamageOnGround_Value1[client][slot] = 0.0;
		DamageOnGround_Value2[client][slot] = 0.0;
		
		ReducedDamageInAir[client][slot] = false;
		ReducedDamageInAir_Value1[client][slot] = 0.0;
		ReducedDamageInAir_Value2[client][slot] = 0.0;
		ReducedDamageInAirActive[client][slot] = false;
		
		KeepDisguiseOnBackstab[client][slot] = false;
		
		InfectVictimOnBackstab[client][slot] = false;
		InfectVictimOnBackstab_TimeToStun[client][slot] = 0.0;
		InfectVictimOnBackstab_TimeToDeath[client][slot] = 0.0;
		
		WallKill[client][slot] = false;
		WallKill_Damage[client][slot] = 0;
		
		SentryHeal[client][slot] = false;
		SentryHealActive[client][slot] = false;
		SentryHeal_Ratio[client][slot] = 0.0;
		SentryHeal_Max[client][slot] = 0.0;
	}
}

public OnEntityDestroyed(Ent)
{
	if(Ent <= 0 || Ent > 2048) return;
	NoReloading[Ent] = false;
	SDKUnhook(Ent, SDKHook_Reload, OnWeaponReload);
}

public TF2_OnConditionAdded(client, TFCond:condition)
{
	if(Client_IsValid(client))
	{
		if(condition == TFCond_Disguised)
		{
			oldDisguise[client][0] = GetEntProp(client, Prop_Send, "m_nDisguiseClass");
			oldDisguise[client][1] = GetEntProp(client, Prop_Send, "m_nDisguiseTeam");
			oldDisguise[client][2] = GetEntProp(client, Prop_Send, "m_iDisguiseTargetIndex");
		}
		
		new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(weapon != -1 && GetHasAttributeInAnySlot(client))
		{
			if(GetHasAttributeInAnySlot(client, _, JumpCloak) && condition == TFCond_Cloaked)
			{
				TF2Attrib_SetByName(weapon, "increased jump height", JumpCloak_Value[client][GetSlotContainingAttribute(client, JumpCloak)]);
			} else if(GetHasAttributeInAnySlot(client, _, RemoveDebuffCloak) && condition == TFCond_Cloaked)
			{
				TF2_RemoveCondition(client, TFCond_OnFire);
				TF2_RemoveCondition(client, TFCond_Milked);
				TF2_RemoveCondition(client, TFCond_Jarated);
				TF2_RemoveCondition(client, TFCond_Bleeding);
			} else if(GetHasAttributeInAnySlot(client, _, CloakOnlyWhenFullMeter) && condition == TFCond_Cloaked)
			{
				if(GetEntProp(client, Prop_Send, "m_flChargeMeter") < 100.0)
				{
					CreateTimer(0.5, Timer_RemoveCloak, client);
				}
			}
		}
	}
}

public Action:Timer_RemoveCloak(Handle:hTimer, any:client)
{
	if(Client_IsValid(client))
	{
		TF2_RemoveCondition(client, TFCond_Cloaked);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(Client_IsValid(client))
	{
		if(GetHasAttributeInAnySlot(client, _, CrouchCloak))
		{
			if(buttons & IN_DUCK || GetEntProp(client, Prop_Send, "m_bDucking") || GetEntProp(client, Prop_Send, "m_bDucked"))
			{
				//SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				//SetEntityRenderColor(client, 0, 0, 0, RoundToNearest(GetAttributeValueInAnySlot(client, _, CrouchCloak, CrouchCloak_Value, 255.0)));
				HideClientWearables(client, true);
				HideEntity(client, true);
			} else
			{
				//SetEntityRenderColor(client, 0, 0, 0, 255);
				HideClientWearables(client, false);
				HideEntity(client, false);
			}
		}
		
		if(GetHasAttributeInAnySlot(client, _, CloakOnlyWhenFullMeter))
		{
			if(TF2_IsPlayerInCondition(client, TFCond_Cloaked)) return Plugin_Continue;
			new Float:m_flCloak = GetEntPropFloat(client, Prop_Send, "m_flCloakMeter");
			
			if(m_flCloak < 100.0)
			{
				buttons &= ~IN_ATTACK2;
				return Plugin_Continue;
			}
		}
	}
	
	return Plugin_Continue;
}

stock Action:CritCharging_OnTakeDamage(victim, &attacker, &damagetype, slot)
{
	if(!Client_IsValid(attacker) || !Client_IsValid(victim) || slot == -1) return Plugin_Continue;
	if(!m_bHasAttribute[attacker][slot]) return Plugin_Continue;
	
	if(CritCharging[attacker][slot] && TF2_IsPlayerInCondition(victim, TFCond_Charging))
	{
		damagetype = DMG_CRIT;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action:Attributes_JumpLand(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!Client_IsValid(client)) return Plugin_Continue;
	
	new slot = GetClientSlot(client);

	if(m_bHasAttribute[client][slot] && ChargeLand[client][slot])
	{
		TF2_AddCondition(client, TFCond_Charging, ChargeLand_Value[client][slot]);
	}
	
	Attribute_1026_RocketJumpLand(client, slot);
	
	return Plugin_Continue;
}

public Action:Attributes_Deflect(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	new deflector = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!Client_IsValid(deflector)) return Plugin_Continue;
	
	new slot = GetClientSlot(deflector);
	if(slot == -1) return Plugin_Continue;
	if(!m_bHasAttribute[deflector][slot]) return Plugin_Continue;
	if(!ReflectCrits[deflector][slot]) return Plugin_Continue;
	
	new deflected = GetEventInt(hEvent, "object_entindex");
	SetEntProp(deflected, Prop_Send, "m_bCritical", 1);
	
	return Plugin_Continue;
}

stock AttributesInit()
{
	Attribute_1056_Init();
}

stock Attribute_1056_Init()
{
	g_hOilLeakEntities = CreateArray();
}

public Action:EventPlayerInventory(Handle:hEvent, String:strName[], bool:bDontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!Client_IsValid(client)) return Plugin_Continue;
	if(!IsPlayerAlive(client)) return Plugin_Continue;
	
	RefreshClientLoadout(client, true);
	
	return Plugin_Continue;
}

public Action:EventPlayerSpawn(Handle:hEvent, String:strName[], bool:bDontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!Client_IsValid(client)) return Plugin_Continue;
	if(!Team_IsValid(client)) return Plugin_Continue;
	
	RefreshClientLoadout(client);
	CreateTimer(0.1, PostSpawn, client);
	
	return Plugin_Continue;
}

public Action:PostSpawn(Handle:hTimer, any:client)
{
	if(!Client_IsValid(client)) return Plugin_Continue;
	if(!Team_IsValid(client)) return Plugin_Continue;
	if(!IsPlayerAlive(client)) return Plugin_Continue;
	
	TF2_RegeneratePlayer(client);
	RefreshClientLoadout(client, true);
	return Plugin_Continue;
}

stock RefreshClientLoadout(client, bool:bSilent = false)
{
	new TFClassType:class = TF2_GetPlayerClass(client);
	for(new i = 0; i <= MAXSLOTS; i++)
	{
		ManageClientLoadoutSlot(client, class, i, bSilent);
	}
	
	// bug fixes
	isInfected[client] = false;
	FastCloakRemove(client);
}

stock bool:ManageClientLoadoutSlot(client, TFClassType:class, slot, bool:bSilent = false)
{
	if(IsFakeClient(client)) return false;
	
	Attribute_OnInventory(client, slot);
	
	return true;
}

stock Attribute_OnInventory(client, slot)
{
	Attribute_1039_OnInventory(client, slot);
}

stock Attribute_1039_OnInventory(client, &slot)
{
	if(!m_bHasAttribute[client][slot]) return;
	if(!CloakIsHook[client][slot]) return;
	
	CloakIsHookToggle(client, true);
	g_iCloakIsHook[client] = 0;
}

stock Attributes_1039_Stop()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		CloakIsHookToggle(i, true);
	}
}

stock CloakIsHookToggle(client, bool:bForceStop = false)
{
	if(!Client_IsValid(client)) return;
	
	if(bForceStop && g_iCloakIsHook[client] != 1) return;
	if(g_iCloakIsHook[client] > 1) return;
	
	if(g_iCloakIsHook[client] > 0)
	{
		TF2_RemoveCondition(client, TFCond_Cloaked);
		g_iCloakIsHook[client] = 2;
		SetEntityMoveType(client, MOVETYPE_WALK);
		
		decl Float:vEyeAngles[3], Float:vVelocity[3];
		GetClientEyeAngles(client, vEyeAngles);
		AnglesToVelocity(vEyeAngles, vVelocity, 400.0);
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVelocity);
	} else
	{
		decl Float:vEyeAngles[3];
		GetClientEyeAngles(client, vEyeAngles);
		CloakIsHookInit(client, vEyeAngles);
	}
}

stock bool:CloakIsHookInit(client, Float:vAngles[3])
{
	if(g_iCloakIsHook[client] == 1) return false;
	
	if(GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") <= 5.0) return false;
	if(!GetClientViewTarget2(client, vAngles, g_vCloakIsHookOrigin[client], true)) return false;
	
	decl Float:vOrigin[3];
	Entity_GetAbsOrigin(client, vOrigin);
	// too far away
	if(GetVectorDistance(vOrigin, g_vCloakIsHookOrigin[client])/50.0 > 10.0) return false;
	if(g_vCloakIsHookOrigin[client][2] <= vOrigin[2]) return false;
	
	TF2_AddCondition(client, TFCond_Cloaked, 999.0);
	g_iCloakIsHook[client] = 1;
	g_fCloakIsHookTime[client] = GetEngineTime();
	return true;
}

stock Attribute_1012_Prethink(client, &buttons, &slot, &buttonsLast)
{
	if(!g_bAttWallSmash[client]) return buttons;
	if(OnGround(client))
	{
		g_bAttWallSmash[client] = false;
		g_iAttWallSmashAttacker[client] = -1;
		return buttons;
	}
	
	// Check if smashing into wall
	decl Float:vClientOrigin[3];
	decl Float:vAngles[3];
	decl Float:vVelocity[3];
	GetClientEyePosition(client, vClientOrigin);
	Entity_GetLocalVelocity(client, vVelocity);
	
	new Float:fSpeed = GetVectorLength(vVelocity);
	
	if (fSpeed < 25.0) return buttons;
	
	GetVectorAngles(vVelocity, vAngles);
	vAngles[0] = 0.0;
	//TR_TraceRayFilter(vClientOrigin, vAngles, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitEntity, client);
	
	//if (!TR_DidHit()) return buttons;
	
	new attacker = g_iAttWallSmashAttacker[client];
	
	if(!Client_IsValid(attacker)) return buttons;
	
	new slot2 = GetClientSlot(attacker);
	
	new damage = 100;
	
	if(m_bHasAttribute[attacker][slot2] && WallKill[attacker][slot2])
	{
		damage = WallKill_Damage[attacker][slot2];
	}
	
	Entity_Hurt(client, damage, attacker);
	EmitSoundToClient(attacker, SOUND_BONEBREAK);
	EmitSoundToAll(SOUND_BONEBREAK, client);
	
	g_bAttWallSmash[client] = false;
	g_iAttWallSmashAttacker[client] = -1;
	
	return buttons;
}

stock Attribute_1039_Prethink(client, &buttons, &slot, &buttonsLast)
{
	if(!IsPlayerAlive(client)) return buttons;
	
	if(!m_bHasAttribute[client][slot]) return buttons;
	if(!CloakIsHook[client][slot]) return buttons;
	
	// toggle ATTACK2
	new Float:fSpeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	if(buttonsLast & IN_ATTACK2 != IN_ATTACK2 && buttons & IN_ATTACK2 == IN_ATTACK2 && g_fCloakIsHookTime[client] < GetEngineTime() - 1.0 && fSpeed >= 5.0)
	{
		buttons &= ~IN_ATTACK2;
		CloakIsHookToggle(client);
	}
	if(GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") <= 0.0) CloakIsHookToggle(client, true);
	
	if(g_iCloakIsHook[client] > 1 && OnGround(client)) g_iCloakIsHook[client] = 0;
	
	if(g_iCloakIsHook[client] != 1)
	{
		return buttons;
	}
	
	if(GetEntityMoveType(client) == MOVETYPE_NONE) return buttons;
	
	decl Float:vOrigin[3];
	Entity_GetAbsOrigin(client, vOrigin);
	
	decl Float:vVelocity[3];
	SubtractVectors(g_vCloakIsHookOrigin[client], vOrigin, vVelocity);
	NormalizeVector(vVelocity, vVelocity);
	ScaleVector(vVelocity, 900.0);
	if(OnGround(client) && vVelocity[2] < 300.0 && vVelocity[2] > 0) vVelocity[2] = 300.0;
	else vVelocity[2] += 20.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVelocity);
	
	decl Float:vOriginEye[3];
	GetClientEyePosition(client, vOriginEye);
	vOrigin[2] = (vOriginEye[2] - vOrigin[2])/2.0 + vOrigin[2];
	new Float:fDistance = GetVectorDistance(vOrigin, g_vCloakIsHookOrigin[client]) / 50.0;
	if(fDistance >= 1.1 && g_fCloakIsHookTime[client] >= GetEngineTime() - 0.5)
	{
		ClientRope(client, g_vCloakIsHookOrigin[client]);
	} else
	{
		TF2_AddCondition(client, TFCond_Cloaked, 999.0);
		SetEntityMoveType(client, MOVETYPE_NONE);
	}
	
	return buttons;
}

stock AttributesStop()
{
	FastCloakRemoveAll();
	Attributes_1056_Think(true);
	Attributes_1039_Stop();
}

stock FastCloak(client)
{
	if(g_bFastCloaked[client]) return;
	
	HideClientWearables(client, true);
	HideEntity(client, true);
	TF2_AddCondition(client, TFCond_Cloaked, 999.0);
	g_bFastCloaked[client] = true;
}

stock FastCloakThink(client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Cloaked)) return;
	if(!g_bFastCloaked[client]) return;
	
	HideClientWearables(client, false);
	HideEntity(client, false);
	g_bFastCloaked[client] = false;
}

stock FastCloakRemove(client)
{
	if(Client_IsValid(client))
	{
		HideClientWearables(client, false);
		HideEntity(client, false);
		g_bFastCloaked[client] = false;
	}
}

stock FastCloakRemoveAll()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		FastCloakRemove(i);
	}
}

public Action:OnWeaponReload(weapon)
{
	if(weapon == -1) return Plugin_Continue;
	if(!NoReloading[weapon]) return Plugin_Continue;
	
	return Plugin_Handled; // As simple as this may be, this cancels reloading.
}

public OnEntityCreated(entity, const String:strClassname[])
{
	if(!IsValidEntity(entity)) return;
	
	Attributes_EntityCreated(entity, String:strClassname);
}

public Attributes_EntityCreated(entity, const String:strClassname[])
{
	if(entity <= 0) return;
	if(!IsValidEdict(entity)) return;
	
	g_entitySlot[entity] = -1;
	g_fEntityCreateTime[entity] = GetEngineTime();
	
	if(StrContains(strClassname, "tf_projectile_", false) >= 0 && !StrEqual(strClassname, "tf_projectile_syringe"))
	{
		SDKHook(entity, SDKHook_StartTouch, ProjectileStartTouch);
		SDKHook(entity, SDKHook_Think, ProjectilePreThink);
		
		// Add this entity to the projectile list, used currently for controllable projectiles
		PushArrayCell(g_hProjectileList, entity);
		
		CreateTimer(0.0, Attributes_ProjCreatedPost, entity);
	}
	
	if(StrContains(strClassname, "tf_weapon_", false) >= 0)
	{
		SDKHook(entity, SDKHook_Reload, OnWeaponReload);
	}
	
	Attribute_1040_EntityCreated(entity);
}

new g_iProjectileBounces[MAX_EDICTS+1] = 0;

stock Attribute_1040_EntityCreated(entity)
{
	g_iProjectileBounces[entity] = 0;
}

public Action:ProjectileStartTouch(entity, other)
{
	new owner = Entity_GetOwner(entity);
	if(!Client_IsValid(owner)) return Plugin_Continue;
	
	new Action:aReturn = Plugin_Continue;
	
	aReturn = ActionApply(aReturn, Attribute_1040_PStartTouch(entity, other, owner, g_entitySlot[entity]));

	return aReturn;
}

public Action:Attributes_ProjCreatedPost(Handle:hTimer, any:entity)
{
	if(!IsValidEdict(entity)) return Plugin_Continue;
	
	decl String:strClassname[255];
	GetEdictClassname(entity, strClassname, sizeof(strClassname));
	if(StrEqual(strClassname, "tf_projectile_syringe")) return Plugin_Continue;
	if(StrContains(strClassname, "tf_projectile_", false) < 0) return Plugin_Continue;
	
	new owner = Entity_GetOwner(entity);
	if(Client_IsValid(owner))
	{
		new slot = GetClientSlot(owner);
		g_entitySlot[entity] = slot;
	}
	
	return Plugin_Continue;
}

stock Action:Attribute_1040_PStartTouch(entity, other, owner, slot)
{
	if(slot < 0 || slot > MAXSLOTS) return Plugin_Continue;
	
	if(!m_bHasAttribute[owner][slot]) return Plugin_Continue;
	if(!ProjectilesBounce[owner][slot]) return Plugin_Continue;
	if(Client_IsValid(other)) return Plugin_Continue;
	if(IsEntityBuilding(other)) return Plugin_Continue;
	
	new total = RoundFloat(ProjectilesBounce_Count[owner][slot]);
	if(g_iProjectileBounces[entity] >= total) return Plugin_Continue;
	SDKHook(entity, SDKHook_Touch, Attribute_1040_OnTouchBounce);
	g_iProjectileBounces[entity]++;
	
	return Plugin_Handled;
}

public Action:Attribute_1040_OnTouchBounce(entity, other)
{
	decl Float:vOrigin[3];
	Entity_GetAbsOrigin(entity, vOrigin);
	
	decl Float:vAngles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);
	
	decl Float:vVelocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVelocity);
	
	new Handle:hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceRayDontHitEntity, entity);
	
	if(!TR_DidHit(hTrace))
	{
		CloseHandle(hTrace);
		return Plugin_Continue;
	}
	
	decl Float:vNormal[3];
	TR_GetPlaneNormal(hTrace, vNormal);
	
	CloseHandle(hTrace);
	
	new Float:dotProduct = GetVectorDotProduct(vNormal, vVelocity);
	
	ScaleVector(vNormal, dotProduct);
	ScaleVector(vNormal, 2.0);
	
	decl Float:vBounceVec[3];
	SubtractVectors(vVelocity, vNormal, vBounceVec);
	
	decl Float:vNewAngles[3];
	GetVectorAngles(vBounceVec, vNewAngles);
	
	TeleportEntity(entity, NULL_VECTOR, vNewAngles, vBounceVec);

	SDKUnhook(entity, SDKHook_Touch, Attribute_1040_OnTouchBounce);
	return Plugin_Handled;
}

public Action:OnThinkRocketHook(Handle:timer, any:Data)
{
	new index = GetArraySize(g_hProjectileList)-1;
	while(index >= 0)
	{
		if(!ControllableProjectileThink(GetArrayCell(g_hProjectileList, index)))
			RemoveFromArray(g_hProjectileList, index);
		--index;
	}
}

stock ControllableProjectileThink(entity)
{
	if(!IsValidEntity(entity) || IsClassname(entity, "tf_viewmodel") || IsClassname(entity, "tf_viewmodel_vm")) return false;
	
	new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(!Client_IsValid(owner)) return false;
	
	if(!HasAttribute(owner, _, ControllableProjectiles)) return false;
	
	new Float:fLife = GetEntityLife(entity);
	fLife -= 0.05;
	if(fLife < 0.0) return true;
	
	decl Float:vRocketOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vRocketOrigin);
	decl Float:vTargetOrigin[3];
	GetClientPointPosition(owner, vTargetOrigin, MASK_VISIBLE);
	
	decl Float:vRocketVelocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vRocketVelocity);
	new Float:fRocketSpeed = GetVectorLength(vRocketVelocity);
	
	decl Float:vDifference[3];
	SubtractVectors(vTargetOrigin, vRocketOrigin, vDifference);
	
	// middle += velocity
	// (aka becomes less accurate)
	new Float:fBase = GetAttributeValueF(owner, _, ControllableProjectiles, ControllableProjectiles_Control);
	new Float:fInaccuracy = fBase - fLife*150.0;
	if(fInaccuracy < 0.0) fInaccuracy = 0.0;
	if(fInaccuracy > 400.0) fInaccuracy = 400.0;
	NormalizeVector(vDifference, vDifference);
	ScaleVector(vDifference, fInaccuracy);
	
	AddVectors(vRocketVelocity, vDifference, vDifference);
	NormalizeVector(vDifference, vDifference);
	
	decl Float:fRocketAngle[3];
	GetVectorAngles(vDifference, fRocketAngle);
	SetEntPropVector(entity, Prop_Data, "m_angRotation", fRocketAngle);
	
	ScaleVector(vDifference, fRocketSpeed);
	SetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vDifference);
	
	return true;
}

stock Attribute_1056_OnProjectile(entity, &client, &slot)
{
	if(!IsClassname(entity, "tf_projectile_flare")) return;
	
	decl Float:vOrigin[3];
	Entity_GetAbsOrigin(entity, vOrigin);
	
	Attribute_1056_IgniteLeak(vOrigin);
}

new Float:g_f1026LastLand[MAXPLAYERS+1] = 0.0;

stock Attribute_1026_RocketJumpLand(client, slot)
{
	if(GetEngineTime() <= g_f1026LastLand[client] + ATTRIBUTE_1026_COOLDOWN) return;
	
	if((GetHasAttributeInAnySlot(client, _, Earthquake) && !GetHasAttributeInAnySlot(client, _, EarthquakeActive)) || EarthquakeActive[client][slot])
	{
		new Float:fPushMax = ATTRIBUTE_1026_PUSHMAX;
		
		new Float:fDistance;
		
		decl Float:vClientPos[3];
		Entity_GetAbsOrigin(client, vClientPos);
		decl Float:vVictimPos[3];
		decl Float:vPush[3];
		
		new team = GetClientTeam(client);
		
		EmitSoundFromOrigin(SOUND_EXPLOSION_BIG, vClientPos);
		TE_SetupExplosion(vClientPos, g_iExplosionSprite, 10.0, 1, 0, 0, 750);
		TE_SendToAll();
		TE_SetupBeamRingPoint(vClientPos, 10.0, GetAttributeValueInAnySlot(client, _, Earthquake, Earthquake_Range, 600.0), g_iWhite, g_iHaloSprite, 0, 10, 0.2, 10.0, 0.5, g_iTeamColorSoft[team], 50, 0);
		TE_SendToAll();
		
		Shake(client);
		
		for(new victim = 0; victim <= MaxClients; victim++)
		{
			if(Client_IsValid(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && team != GetClientTeam(victim) && OnGround(victim))
			{
				Entity_GetAbsOrigin(victim, vVictimPos);
				fDistance = GetVectorDistance(vVictimPos, vClientPos);
				if(fDistance <= GetAttributeValueInAnySlot(client, _, Earthquake, Earthquake_Range, 600.0))
				{
					SubtractVectors(vVictimPos, vClientPos, vPush);
					new Float:fPushScale = (GetAttributeValueInAnySlot(client, _, Earthquake, Earthquake_Range, 600.0) - fDistance)*ATTRIBUTE_1026_PUSHSCALE;
					if(fPushScale > fPushMax) fPushScale = fPushMax;
					ScaleVector(vPush, fPushScale);
					Shake(victim);
					if(vPush[2] < 400.0) vPush[2] = 400.0;
					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vPush);
					g_f1026LastLand[client] = GetEngineTime();
				}
			}
		}
	}
}

stock Attribute_1087_Prethink(client, &buttons, &slot, &buttonsLast)
{
	if(!m_bHasAttribute[client][slot]) return buttons;
	if(AttackWhileCloaked[client][slot] && (buttons & IN_ATTACK == IN_ATTACK))
	{
		new Float:flTime = GetGameTime();
		if(TF2_IsPlayerInCondition(client, TFCond_Cloaked))
		{
			TF2_RemoveCondition(client, TFCond_Cloaked);
			SetEntPropFloat(client, Prop_Send, "m_flNextAttack", flTime);
		}
		SetEntPropFloat(client, Prop_Send, "m_flStealthNoAttackExpire", flTime);
		SetEntPropFloat(client, Prop_Send, "m_flInvisChangeCompleteTime", flTime);
	}

	return buttons;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Attributes_OnTakeDamage);
	SDKHook(client, SDKHook_PreThink, OnClientPreThink);
	SDKHook(client, SDKHook_WeaponSwitchPost, Attributes_WeaponSwitch);
}

public Action:Attributes_WeaponSwitch(client, weapon)
{
	if(!Client_IsValid(client) || weapon == -1) return Plugin_Continue;
	
	new slot = GetWeaponSlot(client, weapon);
	
	if(slot == -1) return Plugin_Continue;
	if(!m_bHasAttribute[client][slot]) return Plugin_Continue;
	
	if(DrawMiniCrits[client][slot])
	{
		TF2_AddCondition(client, TFCond_Buffed, DrawMiniCrits_Value[client][slot]);
		TF2_AddCondition(client, TFCond_MarkedForDeath, DrawMiniCrits_Value[client][slot]);
	}
	
	return Plugin_Continue;
}

stock Attributes_PreThink(client)
{
	if(!IsPlayerAlive(client)) return;
	
	new buttonsLast = g_iLastButtons[client];
	new buttons = GetClientButtons(client);
	new buttons2 = buttons;
	
	new Handle:hArray = CreateArray();
	new slot = GetClientSlot(client);
	if(slot >= 0) PushArrayCell(hArray, slot);
	PushArrayCell(hArray, 4);
	
	new slot2;
	for(new i = 0; i < GetArraySize(hArray); i++)
	{
		slot2 = GetArrayCell(hArray, i);
		InfectVictim_Prethink(client);
		KeepDisguise_Prethink(client);
		buttons = Attribute_1034_Prethink(client, buttons, slot2, buttonsLast);
		buttons = Attribute_1039_Prethink(client, buttons, slot2, buttonsLast);
		buttons = Attribute_1012_Prethink(client, buttons, slot2, buttonsLast);
		buttons = Attribute_1056_Prethink(client, buttons, slot2, buttonsLast);
		buttons = Attribute_1087_Prethink(client, buttons, slot2, buttonsLast);
	}
	CloseHandle(hArray);
	
	slot2 = -1;
	
	for(slot2 = 0; slot2 <= MAXSLOTS; slot2++)
	{
		DamageGround_Prethink(client, buttons, buttonsLast, slot2);
	}

	if(buttons != buttons2) SetEntProp(client, Prop_Data, "m_nButtons", buttons);    
	g_iLastButtons[client] = buttons;
	
	g_bWasDisguised[client] = IsDisguised(client);
}

stock KeepDisguise_Prethink(client)
{
	if(Client_IsValid(client) && TF2_IsPlayerInCondition(client, TFCond_Disguised))
	{
		new class, team, target;
		
		class = GetEntProp(client, Prop_Send, "m_nDisguiseClass");
		team = GetEntProp(client, Prop_Send, "m_nDisguiseTeam");
		target = GetEntProp(client, Prop_Send, "m_iDisguiseTargetIndex");
		
		if(class != oldDisguise[client][0] || team != oldDisguise[client][1] || target != oldDisguise[client][2])
		{
			oldDisguise[client][0] = class;
			oldDisguise[client][1] = team;
			oldDisguise[client][2] = target;
		}
	}
}

stock DamageGround_Prethink(client, &buttons, &buttonsLast, slot)
{
	if(Client_IsValid(client))
	{
		new weapon = GetPlayerWeaponSlot(client, slot);
		if(weapon != -1 && m_bHasAttribute[client][slot] && DamageOnGround[client][slot])
		{
			if(GetEntityFlags(client) & FL_ONGROUND)
			{
				TF2Attrib_RemoveByName(weapon, "damage bonus");
				TF2Attrib_SetByName(weapon, "damage penalty", DamageOnGround_Value2[client][slot]);
			} else if(!(buttons & IN_JUMP || buttonsLast & IN_JUMP))
			{
				TF2Attrib_RemoveByName(weapon, "damage penalty");
				TF2Attrib_SetByName(weapon, "damage bonus", DamageOnGround_Value1[client][slot]);
			}
		}
	}
}

public OnClientPreThink(client)
{
	Attributes_PreThink(client);
	FastCloakThink(client);
}

public ProjectilePreThink(entity)
{
	if(!IsValidEdict(entity)) return;
	
	new client = Entity_GetOwner(entity);
	new slot = g_entitySlot[entity];
	
	Attribute_1056_OnProjectile(entity, client, slot);
}

stock Attribute_1056_Prethink(client, &buttons, &slot, &buttonsLast)
{
	if(m_bHasAttribute[client][slot] && AltFireIsOil[client][slot])
	{
		if(buttons & IN_ATTACK2 == IN_ATTACK2)
		{
			Attribute_1056_OilLeak(client, slot);
			if(GetClientTeam(client) == TEAM_SPEC)
			{
				return buttons;
			}
		}
	}
	
	if(GetFlamethrowerStrength(client) >= 2)
	{
		decl Float:vOrigin[3];
		Entity_GetAbsOrigin(client, vOrigin);
		Attribute_1056_IgniteLeak(vOrigin);
	}
	
	new attacker = g_iOilLeakDamageOwner[client];
	if(Client_IsValid(attacker))
	{
		new weapon = GetPlayerWeaponSlot(attacker, slot);
		
		//Entity_Hurt(client, 2 + RoundFloat(g_iOilLeakDamage[client] * 1.5), attacker, TF_DMG_FIRE);
		SDKHooks_TakeDamage(client, attacker, attacker, 2 + (g_iOilLeakDamage[client] * 1.5), TF_DMG_FIRE, weapon);
		
		g_iOilLeakDamage[client] += 2;
	} else
	{
		g_iOilLeakDamage[client] -= 4;
		if(g_iOilLeakDamage[client] < 0) g_iOilLeakDamage[client] = 0;
	}
	g_iOilLeakDamageOwner[client] = -1;
	
	return buttons;
}

stock Attribute_1056_OilLeak(client, slot)
{
	if(g_fOilLeakDelay[client] >= GetEngineTime() - ATTRIBUTE_FIRELEAK_TIME) return;
	if(!SubtractWeaponAmmo(client, slot, ATTRIBUTE_FIRELEAK_COST)) return;
	
	g_fOilLeakDelay[client] = GetEngineTime();
	
	if(!m_bHasAttribute[client][slot]) return;
	if(!AltFireIsOil[client][slot])
	{
		return;
	} else
	{
		EmitSoundToAll(SOUND_FIRELEAK_OIL, client, SNDCHAN_WEAPON, _, SND_CHANGEVOL|SND_CHANGEPITCH, 1.0, GetRandomInt(60, 140));
	}
	
	if(g_hOilLeakEntities == INVALID_HANDLE) g_hOilLeakEntities = CreateArray();
	
	new entity = CreateEntityByName("prop_physics_override");
	if(IsValidEdict(entity))
	{
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
		SetEntityModel(entity, MODEL_DEFAULTPHYSICS);
		DispatchSpawn(entity);
		
		AcceptEntityInput(entity, "DisableCollision");
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, _, _, _, 0);
		
		decl String:strName[10];
		Format(strName, sizeof(strName), "tf2leak");
		DispatchKeyValue(entity, "targetname", strName);
		
		decl Float:fAngles[3], Float:fVelocity[3], Float:fOrigin[3];
		GetClientEyePosition(client, fOrigin);
		GetClientEyeAngles(client, fAngles);
		AnglesToVelocity(fAngles, fVelocity, 600.0);
		
		TeleportEntity(entity, fOrigin, fAngles, fVelocity);
		
		new team = GetClientTeam(client);
		
		if(team == TEAM_BLUE)
		{
			AttachParticle(entity, "peejar_trail_blu");
			AttachParticle(entity, "peejar_trail_blu");
			AttachParticle(entity, "peejar_trail_blu");
			AttachParticle(entity, "peejar_trail_blu");
			AttachParticle(entity, "peejar_trail_blu");
			AttachParticle(entity, "peejar_trail_blu");
			AttachParticle(entity, "peejar_trail_blu");
		} else if(team == TEAM_RED)
		{
			AttachParticle(entity, "peejar_trail_red");
			AttachParticle(entity, "peejar_trail_red");
			AttachParticle(entity, "peejar_trail_red");
			AttachParticle(entity, "peejar_trail_red");
			AttachParticle(entity, "peejar_trail_red");
			AttachParticle(entity, "peejar_trail_red");
			AttachParticle(entity, "peejar_trail_red");
		}
		
		g_fOilLeakLife[entity] = GetEngineTime() + 10.0;
		g_iOilLeakStatus[entity] = 0;
		
		PushArrayCell(g_hOilLeakEntities, entity);
	}
}

stock Attribute_1056_IgniteLeak(Float:vPos[3])
{
	decl Float:vOrigin[3];
	decl Float:vFire[3];
	for(new i = GetArraySize(g_hOilLeakEntities)-1; i >= 0; i--)
	{
		new entity = GetArrayCell(g_hOilLeakEntities, i);
		
		if(IsClassname(entity, "prop_physics"))
		{
			Entity_GetAbsOrigin(entity, vOrigin);
			if(g_iOilLeakStatus[entity] == 1 && GetVectorDistance(vOrigin, vPos) / 50.0 <= 3.0)
			{
				g_iOilLeakStatus[entity] = 2;
				g_fOilLeakLife[entity] = GetEngineTime() + 5.0;
				Attribute_1056_IgniteLeak(vOrigin);
				vFire[2] = 5.0;
				
				vFire[0] = 22.0;
				vFire[1] = 22.0;
				AttachParticle(entity, PARTICLE_FIRE, _, vFire);
				
				vFire[0] = 22.0;
				vFire[1] = -22.0;
				AttachParticle(entity, PARTICLE_FIRE, _, vFire);
				
				vFire[0] = -22.0;
				vFire[1] = 22.0;
				AttachParticle(entity, PARTICLE_FIRE, _, vFire);
				
				vFire[0] = -22.0;
				vFire[1] = -22.0;
				AttachParticle(entity, PARTICLE_FIRE, _, vFire);
				
				vFire[0] = 0.0;
				vFire[1] = 0.0;
				AttachParticle(entity, PARTICLE_FIRE, _, vFire);
				
				new String:strParticle[16];
				if(GetClientTeam(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) == TEAM_BLUE) Format(strParticle, sizeof(strParticle), "%s", PARTICLE_AREA_FIRE_BLUE);
				if(!StrEqual(strParticle, "")) AttachParticle(entity, strParticle, _, vFire);
			}
		}
	}
}

stock Attributes_1056_Think(bool:bTerminate = false)
{
	if(g_hOilLeakEntities == INVALID_HANDLE) return;
	
	new iClientLeaks[MAXPLAYERS + 1] = 0;
	
	for(new i = GetArraySize(g_hOilLeakEntities) - 1; i >= 0; i--)
	{
		new entity = GetArrayCell(g_hOilLeakEntities, i);
		new owner = Attribute_1056_OilThink(entity);
		if(bTerminate || owner < 0 || iClientLeaks[owner] > 12)
		{
			if(IsClassname(entity, "prop_physics")) AcceptEntityInput(entity, "kill");
			RemoveFromArray(g_hOilLeakEntities, i);
		} else
		{
			iClientLeaks[owner]++;
		}
	}
	
	if(bTerminate) CloseHandle(g_hOilLeakEntities);
}

stock Attribute_1056_OilThink(entity)
{
	if(!IsClassname(entity, "prop_physics")) return -1;
	
	new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(!Client_IsIngame(owner) || !Client_IsValid(owner)) return -1;
	
	new Float:fLife = g_fOilLeakLife[entity];
	if(GetEngineTime() >= fLife) return -1;
	
	
	decl Float:vOrigin[3];
	Entity_GetAbsOrigin(entity, vOrigin);
	
	if(g_iOilLeakStatus[entity] == 0)
	{
		new Float:vAngleDown[3];
		vAngleDown[0] = 90.0;
		new Handle:hTrace = TR_TraceRayFilterEx(vOrigin, vAngleDown, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitPlayers);
		if(TR_DidHit(hTrace))
		{
			decl Float:vEnd[3];
			TR_GetEndPosition(vEnd, hTrace);
			if(GetVectorDistance(vEnd, vOrigin) / 50.0 <= 0.4)
			{
				new Float:vStop[3];
				SetEntityMoveType(entity, MOVETYPE_NONE);
				TeleportEntity(entity, vEnd, NULL_VECTOR, vStop);
				
				SetEntityRenderColor(entity, _, _, _, 255);
				SetEntityRenderMode(entity, RENDER_NONE);
				SetEntityModel(entity, MODEL_FIRELEAK);
				g_iOilLeakStatus[entity] = 1;
			}
		}
		CloseHandle(hTrace);
	} else if(g_iOilLeakStatus[entity] == 2)
	{
		for(new client = 0; client <= MaxClients; client++)
		{
			if(Client_IsValid(client) && IsPlayerAlive(client) && (GetClientTeam(client) != GetClientTeam(owner) || client == owner))
			{
				if(Entity_GetDistanceOrigin(client, vOrigin) / 50.0 <= 1.5)
				{
					g_iOilLeakDamageOwner[client] = owner;
				}
			}
		}
	}
	
	return owner;
}

stock InfectVictim_Prethink(client)
{
	if(!Client_IsValid(client)) return;
	
	if(isInfected[client])
	{
		new healers = GetEntProp(client, Prop_Send, "m_nNumHealers");
		
		if(healers > 0)
		{
			isInfected[client] = false;
		}
	}
}

stock Attribute_1034_Prethink(client, &buttons, slot, &buttonsLast)
{
	if(slot == -1) return buttons;
	
	if((GetHasAttributeInAnySlot(client, _, ItemIsHeavy) && !GetHasAttributeInAnySlot(client, _, ItemIsHeavyActive)) || ItemIsHeavyActive[client][slot])
	{
		if(OnGround(client))
		{
			fAttribute_1034_Time[client] = 0.0;
		}
		if(GetEntityMoveType(client) != MOVETYPE_WALK) return buttons;
		
		decl Float:vVelocity[3];
		Entity_GetLocalVelocity(client, vVelocity);
		
		fAttribute_1034_Time[client] += 0.1;
		if(fAttribute_1034_Time[client] > 1.0) fAttribute_1034_Time[client] = 1.0;
		
		new Float:fPush = GetAttributeValueInAnySlot(client, _, ItemIsHeavy, ItemIsHeavy_Force, 5.0) * fAttribute_1034_Time[client];
		
		if(vVelocity[2] > 0)
		{
			vVelocity[2] -= fPush * 0.3;
		} else
		{
			vVelocity[2] -= fPush * 1.0;
		}
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVelocity);
	}
	
	return buttons;
}

public OnGameFrame()
{
	Attributes_1056_Think();
}

stock Action:Attribute_1012_OnTakeDamage(victim, &attacker, slot, &Float:fDamage, &iDamageType, Float:fForce[3], Float:fForcePos[3], bool:bBuilding)
{
	if (bBuilding) return Plugin_Continue;
	if (!Client_IsValid(attacker) || !Client_IsValid(victim)) return Plugin_Continue;
	if (attacker == victim) return Plugin_Continue;
	if (slot == -1) return Plugin_Continue;
	
	if(!m_bHasAttribute[attacker][slot] || !WallKill[attacker][slot]) return Plugin_Continue;
	
	if (fDamage <= 0.0) return Plugin_Continue;
	
	decl Float:fVelocity[3];
	decl Float:fAngle[3];
	GetClientEyeAngles(attacker, fAngle);
	AnglesToVelocity(fAngle, fVelocity, 230.0);
	fVelocity[2] = 270.0;
	
	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, fVelocity);
	
	g_bAttWallSmash[victim] = true;
	g_iAttWallSmashAttacker[victim] = attacker;
	
	return Plugin_Continue;
}

stock Action:Attribute_1062_OnTakeDamage(victim, &attacker, slot, &Float:damage, &damagetype, Float:damageForce[3], Float:damagePosition[3], bool:bBuilding, damageCustom)
{
	if(!Client_IsValid(attacker) || !Client_IsValid(victim)) return Plugin_Continue;
	if(attacker == victim) return Plugin_Continue;
	if(damage <= 0.0) return Plugin_Continue;
	if(damageCustom != TF_CUSTOM_BACKSTAB) return Plugin_Continue;
	if(slot == -1) return Plugin_Continue;
	
	if(!GetHasBackstabShield(victim))
	{
		if(!m_bHasAttribute[attacker][slot]) return Plugin_Continue;
		if(!FastcloakOnBackstab[attacker][slot]) return Plugin_Continue;
		
		if(m_bHasAttribute[attacker][4] && CloakIsHook[attacker][4]) // Get watch
		{
			new Float:vAngles[3];
			vAngles[0] = -90.0;
			if(CloakIsHookInit(attacker, vAngles)) return Plugin_Continue;
			vAngles[0] = -45.0;
			for(new i = 0; i <= 7; i++)
			{
				vAngles[1] = float(i) * 45.0;
				if(CloakIsHookInit(attacker, vAngles)) return Plugin_Continue;
			}
			return Plugin_Continue;
		}
		
		FastCloak(attacker);
	}
	
	return Plugin_Continue;
}

stock Action:Attribute_1193_OnTakeDamage(victim, &attacker, slot, &Float:damage, &damagetype, Float:damageForce[3], Float:damagePosition[3], bool:bBuilding)
{
	if(bBuilding) return Plugin_Continue;
	if(!Client_IsValid(attacker) || !Client_IsValid(victim)) return Plugin_Continue;
	if(attacker == victim) return Plugin_Continue;
	if(damage <= 0.0) return Plugin_Continue;
	if(slot == -1) return Plugin_Continue;
	
	if(!m_bHasAttribute[attacker][slot] || !ResetAfterburn[attacker][slot])
	{
		if(g_iAchBoilerBurner1193[victim] == attacker && IsAfterDamage(damagetype)) g_iAchBoilerTimer1193[victim] = 0;
		
		if(IsAfterDamage(damagetype))
		{
			if(g_iAchBoilerBurner1193[victim] != attacker)
			{
				g_iAchBoilerBurner1193[victim] = 0;
				g_iAchBoilerTimer1193[victim] = 0;
			}
		}
		
		return Plugin_Continue;
	}
	
	if(!TF2_IsPlayerInCondition(victim, TFCond_OnFire)) return Plugin_Continue;
	
	if(IsAfterDamage(damagetype))
	{
		if(g_iAchBoilerBurner1193[victim] != attacker)
		{
			g_iAchBoilerBurner1193[victim] = 0;
			g_iAchBoilerTimer1193[victim] = 0;
		} else
		{
			g_iAchBoilerTimer1193[victim] += 1;
		}
		
		return Plugin_Continue;
	}
	
	TF2_IgnitePlayer(victim, attacker);
	EmitSoundToAll(SOUND_FLAME_ENGULF, victim, _, _, SND_CHANGEVOL, SNDVOL_NORMAL * 1.5);
	
	g_iAchBoilerBurner1193[victim] = attacker;
	
	return Plugin_Continue;
}

public TF2_OnConditionRemoved(client, TFCond:condition)
{
	if(Client_IsValid(client))
	{
		new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(weapon != -1)
		{
			if(GetHasAttributeInAnySlot(client, _, JumpCloak) && condition == TFCond_Cloaked)
			{
				TF2Attrib_RemoveByName(weapon, "increased jump height");
			}
		}
	}
	
	Attribute_1193_OnConditionRemoved(client, condition);
}

stock Attribute_1193_OnConditionRemoved(client, TFCond:condition)
{
	if(!Client_IsValid(client)) return;
	if(condition != TFCond_OnFire) return;
	if(g_iAchBoilerTimer1193[client] == 0) return;

	g_iAchBoilerBurner1193[client] = 0;
	g_iAchBoilerTimer1193[client] = 0;
}

stock Action:Attribute_1296_OnTakeDamage(victim, &attacker, slot, &Float:damage, &damagetype, Float:damageForce[3], Float:damagePosition[3], bool:bBuilding)
{
	if(!Client_IsValid(attacker)) return Plugin_Continue;
	if(GetClientTeam(attacker) == GetClientTeam(victim)) return Plugin_Continue;
	if(attacker == victim) return Plugin_Continue;
	if (damage <= 0.0)return Plugin_Continue;
	
	new weaponSlot = GetSlotContainingAttribute(attacker, DamageReloads);
	if(weaponSlot == -1 || weaponSlot == slot) return Plugin_Continue;
	new weapon = GetPlayerWeaponSlot(attacker, weaponSlot);
	new Float:damageNeeded = DamageReloads_Damage[attacker][weaponSlot];
	
	g_fTotalDamage1296[attacker] += damage;
	
	if(g_fTotalDamage1296[attacker] >= damageNeeded)
	{
		EmitSoundToClient(attacker, SOUND_1217_RELOAD);
	}
	
	while(g_fTotalDamage1296[attacker] >= damageNeeded)
	{
		if(weapon == -1) return Plugin_Continue;
		g_fTotalDamage1296[attacker] -= damageNeeded;
		new clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
		if(clip >= DamageReloads_Max[attacker][weaponSlot]) return Plugin_Continue;
		SetClip(weapon, clip + 1);
	}
	
	return Plugin_Continue;
}

stock Action:Attribute_1321_OnTakeDamage(victim, &attacker, slot, &Float:fDamage, &damageType, Float:fForce[3], Float:fForcePos[3], bool:bBuilding)
{
	if(!Client_IsValid(victim)) return Plugin_Continue;
	if(!Client_IsValid(attacker)) return Plugin_Continue;
	
	if(GetHasAttributeInAnySlot(victim, _, ShareDamage)) return Plugin_Continue;
	
	if(attacker == victim) return Plugin_Continue;
	if(bBuilding) return Plugin_Continue;
	if(IsAfterDamage(damageType)) return Plugin_Continue;
	new dmgType = damageType;
	
	if(dmgType == DMG_FALL || dmgType == DMG_CRUSH) return Plugin_Continue;
	
	if(TF2_GetPlayerClass(attacker) == TFClass_Spy && (damageType & TF_DMG_MELEE_CRIT == TF_DMG_MELEE_CRIT)) return Plugin_Continue;
	
	new tank[MAXPLAYERS + 1] = 0;
	new totalTanks = 0;
	
	decl Float:vClientPos[3];
	Entity_GetAbsOrigin(victim, vClientPos);
	vClientPos[2] += 80.0;
	decl Float:vTeammatePos[3];
	decl health;
	
	new team = GetClientTeam(victim);
	
	for(new teammate = 0; teammate <= MaxClients; teammate++)
	{
		if(Client_IsValid(teammate) && IsClientInGame(teammate) && IsPlayerAlive(teammate) && team == GetClientTeam(teammate))
		{
			Entity_GetAbsOrigin(teammate, vTeammatePos);
			vTeammatePos[2] += 80.0;
			TR_TraceRayFilter(vClientPos, vTeammatePos, MASK_PLAYERSOLID, RayType_EndPoint, TraceRayDontHitPlayers);
			if(!TR_DidHit(INVALID_HANDLE))
			{
				new slotTank = GetClientSlot(teammate);
				
				health = GetClientHealth(teammate);
				if(slotTank != -1 && m_bHasAttribute[teammate][slotTank] && ShareDamage[teammate][slotTank] && Entity_GetDistanceOrigin(teammate, vClientPos) <= ShareDamage_Range[teammate][slotTank] && health > 1)
				{
					tank[totalTanks] = teammate;
					totalTanks++;
				}
			}
		}
	}
	
	if(totalTanks == 0) return Plugin_Continue;
	
	new Float:fRatio = ShareDamage_Ratio[tank[0]][GetSlotContainingAttribute(tank[0], ShareDamage)];
	new Float:fTankDamage = fDamage*fRatio;
	
	if(fTankDamage < 1.0) return Plugin_Continue;
	
	if(IsDamageTypeCrit(damageType)) fTankDamage /= 3.0;
	fDamage *= 1.0 - fRatio;
	if(totalTanks > 1) fTankDamage /= totalTanks;
	
	decl Float:vVictimPos[3];
	Entity_GetAbsOrigin(victim, vVictimPos);
	vVictimPos[2] += 80.0;
	decl Float:vTankPos[3];
	decl Float:vDiff[3];
	decl Float:vParticlePos[3];

	new Float:fAngle[3];
	fAngle[0] = -90.0;
	
	for(new currentTank = 0; currentTank < totalTanks; currentTank++)
	{
		health = GetClientHealth(tank[currentTank]);
		if(health > fTankDamage)
		{
			Entity_Hurt(tank[currentTank], RoundFloat(fTankDamage), attacker, TF_DMG_PROPAGATE);
		} else
		{
			SetEntityHealth(tank[currentTank], 1);
		}
		new random = GetRandomInt(0, sizeof(g_strSound1315Ping) - 1);
		EmitSoundToAll(g_strSound1315Ping[random], tank[currentTank]);
		
		Entity_GetAbsOrigin(tank[currentTank], vTankPos);
		vTankPos[2] += 80.0;
		SubtractVectors(vTankPos, vVictimPos, vDiff);
		ScaleVector(vDiff, 0.2);
		
		vParticlePos = vVictimPos;
		AddVectors(vParticlePos, vDiff, vParticlePos);
		ShowParticle(PARTICLE_WHITE_PARTICLE, 0.7, vParticlePos, fAngle);
		AddVectors(vParticlePos, vDiff, vParticlePos);
		ShowParticle(PARTICLE_WHITE_PARTICLE, 0.8, vParticlePos, fAngle);
		AddVectors(vParticlePos, vDiff, vParticlePos);
		ShowParticle(PARTICLE_WHITE_PARTICLE, 0.9, vParticlePos, fAngle);
		AddVectors(vParticlePos, vDiff, vParticlePos);
		ShowParticle(PARTICLE_WHITE_PARTICLE, 1.0, vParticlePos, fAngle);
	}
	
	return Plugin_Changed;
}

stock Action:Attribute_1066_OnTakeDamage(victim, &attacker, slot, &Float:damage, &damagetype, Float:damageForce[3], Float:damagePosition[3], bool:bBuilding)
{
	if(damage <= 0.0) return Plugin_Continue;
	
	new dmgType = damagetype;
	if(dmgType & DMG_CRUSH) return Plugin_Continue;
	
	if(bBuilding) return Plugin_Continue;
	if(attacker != victim && Client_IsValid(attacker)) return Plugin_Continue;
	
	new slotVictim = GetClientSlot(victim);
	if (slotVictim == -1)return Plugin_Continue;
	
	if((GetHasAttributeInAnySlot(victim, _, ReducedFallDamage) && !GetHasAttributeInAnySlot(victim, _, ReducedFallDamageActive)) || (ReducedFallDamageActive[victim][slotVictim]))
	{
		new Float:fValue = GetAttributeValueInAnySlot(victim, _, ReducedFallDamage, ReducedFallDamage_Value, 1.0);
		
		damage *= fValue;
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

stock Action:KeepDisguise_OnTakeDamage(victim, &attacker, &Float:damage, &damageType, slot, damageCustom)
{
	if(!Client_IsValid(attacker) || !Client_IsValid(victim) || slot == -1) return Plugin_Continue;
	
	if(!m_bHasAttribute[attacker][slot] || !KeepDisguiseOnBackstab[attacker][slot]) return Plugin_Continue;
	
	if(damageCustom == TF_CUSTOM_BACKSTAB && !GetHasBackstabShield(victim))
	{
		if(Client_IsValid(oldDisguise[attacker][2]) && g_bWasDisguised[attacker])
		{
			new Handle:dataPack;
			CreateDataTimer(0.01, KeepDisguise_Timer_Disguise, dataPack);
			WritePackCell(dataPack, attacker);
		}
	}
	
	return Plugin_Continue;
}

public Action:KeepDisguise_Timer_Disguise(Handle:timer, Handle:dataPack)
{
	new attacker;
	
	ResetPack(dataPack);
	attacker = ReadPackCell(dataPack);
	
	TF2_DisguisePlayer(attacker, TFTeam:oldDisguise[attacker][1], TFClassType:oldDisguise[attacker][0], oldDisguise[attacker][2]);
	
	SetEntProp(attacker, Prop_Send, "m_nMaskClass", oldDisguise[attacker][0]);
	SetEntProp(attacker, Prop_Send, "m_nDisguiseClass", oldDisguise[attacker][0]);
	SetEntProp(attacker, Prop_Send, "m_nDesiredDisguiseClass", oldDisguise[attacker][0]);
	SetEntProp(attacker, Prop_Send, "m_nDisguiseTeam", oldDisguise[attacker][1]);
	SetEntProp(attacker, Prop_Send, "m_iDisguiseTargetIndex", oldDisguise[attacker][2]);
	
	SetEntProp(attacker, Prop_Send, "m_iDisguiseHealth", IsPlayerAlive(oldDisguise[attacker][2]) ? GetClientHealth(oldDisguise[attacker][2]) : TF2_GetMaxHealth(oldDisguise[attacker][2]));
	
	TF2_AddCondition(attacker, TFCond_Disguised);
}

stock Action:SentryHeal_OnTakeDamage(victim, &attacker, inflictor, &Float:damage, bool:building)
{
	if(!Client_IsValid(attacker) || !Client_IsValid(victim) || building || attacker == inflictor) return Plugin_Continue;
	
	new slot = GetClientSlot(attacker);
	if (slot == -1)return Plugin_Continue;
	
	if((GetHasAttributeInAnySlot(attacker, _, SentryHeal) && !GetHasAttributeInAnySlot(attacker, _, SentryHealActive)) || SentryHealActive[attacker][slot])
	{
		new String:attackerObject[128];
		GetEdictClassname(inflictor, attackerObject, sizeof(attackerObject));
		
		// Sentry damage (bullets and rockets)
		if(StrEqual(attackerObject, "obj_sentrygun"))
		{
			new healthToHeal = RoundFloat(damage * GetAttributeValueInAnySlot(attacker, _, SentryHeal, SentryHeal_Ratio, 1.0));
			
			if(healthToHeal < 0)
			{
				Entity_Hurt(attacker, healthToHeal * -1, inflictor);
			} else
			{
				AddPlayerHealth(attacker, healthToHeal, GetAttributeValueInAnySlot(attacker, _, SentryHeal, SentryHeal_Max, 1.5));
			}
			
			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

stock Action:InfectVictim_OnTakeDamage(victim, &attacker, &Float:damage, &damageType, slot, damageCustom)
{
	if(!Client_IsValid(attacker) || !Client_IsValid(victim) || slot == -1 || !(damage > 0.0)) return Plugin_Continue;
	
	if(!m_bHasAttribute[attacker][slot] || !InfectVictimOnBackstab[attacker][slot]) return Plugin_Continue;
	
	if(damageCustom == TF_CUSTOM_BACKSTAB && !GetHasBackstabShield(victim))
	{
		isInfected[victim] = true;
		
		EmitSoundToAll("player/spy_shield_break.wav", victim);
		
		new Handle:dataPack;
		CreateDataTimer(InfectVictimOnBackstab_TimeToStun[attacker][slot], InfectVictim_Timer_Stun, dataPack);
		WritePackCell(dataPack, victim);
		WritePackCell(dataPack, attacker);
		WritePackCell(dataPack, slot);
		
		damage = 10.0;
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action:InfectVictim_Timer_Stun(Handle:timer, Handle:dataPack)
{
	new victim, attacker, slot;
	
	ResetPack(dataPack);
	victim = ReadPackCell(dataPack);
	attacker = ReadPackCell(dataPack);
	slot = ReadPackCell(dataPack);
	
	if(Client_IsValid(victim) && isInfected[victim])
	{
		TF2_StunPlayer(victim, InfectVictimOnBackstab_TimeToDeath[attacker][slot] + 2.5, 0.5, TF_STUNFLAGS_LOSERSTATE);
		
		CreateDataTimer(InfectVictimOnBackstab_TimeToDeath[attacker][slot], InfectVictim_Timer_Death, dataPack);
		WritePackCell(dataPack, victim);
		WritePackCell(dataPack, attacker);
	}
}

public Action:InfectVictim_Timer_Death(Handle:timer, Handle:dataPack)
{
	new victim, attacker;
	
	ResetPack(dataPack);
	victim = ReadPackCell(dataPack);
	attacker = ReadPackCell(dataPack);
	
	if(Client_IsValid(victim) && isInfected[victim])
	{
		// You are ded, not big surprise.
		Entity_Hurt(victim, 1000000000, attacker, TF_DMG_MELEE_CRIT, "tf_weapon_knife");
	}
}

stock Action:AirDamageMod_OnTakeDamage(victim, &attacker, &Float:damage)
{
	if(!Client_IsValid(attacker) || !Client_IsValid(victim) || damage <= 0.0) return Plugin_Continue;
	
	new slot = GetClientSlot(victim);
	if(slot == -1) return Plugin_Continue;
	
	new buttons = GetClientButtons(victim);
	new buttonsLast = g_iLastButtons[victim];
	
	if((HasAttribute(victim, _, ReducedDamageInAir) && !HasAttribute(victim, _, ReducedDamageInAirActive)) || ReducedDamageInAirActive[victim][slot])
	{
		if(GetEntityFlags(victim) & FL_ONGROUND)
		{
			damage *= GetAttributeValueF(victim, _, ReducedDamageInAir, ReducedDamageInAir_Value1);
		} else if(!(buttons & IN_JUMP || buttonsLast & IN_JUMP))
		{
			damage *= GetAttributeValueF(victim, _, ReducedDamageInAir, ReducedDamageInAir_Value2);
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action:Attributes_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3], damageCustom)
{
	if(victim <= 0) return Plugin_Continue;
	if(attacker <= 0) return Plugin_Continue;
	if(Client_IsValid(attacker) && Client_IsValid(victim) && attacker != victim && GetClientTeam(attacker) == GetClientTeam(victim)) return Plugin_Continue;
	
	new bool:bBuilding = IsEntityBuilding(victim);
	if(!bBuilding && damage <= 0.0) return Plugin_Continue;
	
	// Set up return
	new Action:aReturn = Plugin_Continue;
	
	// Get the slot
	new slot = GetClientSlot(attacker);
	if(weapon > 0 && IsValidEdict(weapon))
	{
		slot = GetWeaponSlot(attacker, weapon);
	} else
	{
		if(inflictor > 0 && !Client_IsValid(inflictor) && IsValidEdict(inflictor))
		{
			slot = GetWeaponSlot(attacker, inflictor);
		}
	}
	
	new oldType = damageType;
	
	if(IsDamageTypeCrit(oldType) && !bBuilding) damage *= 3.0;
	
	// Attributes go here
	aReturn = ActionApply(aReturn, Attribute_1066_OnTakeDamage(victim, attacker, slot, damage, damageType, damageForce, damagePosition, bBuilding));
	aReturn = ActionApply(aReturn, Attribute_1012_OnTakeDamage(victim, attacker, slot, damage, damageType, damageForce, damagePosition, bBuilding));
	aReturn = ActionApply(aReturn, Attribute_1062_OnTakeDamage(victim, attacker, slot, damage, damageType, damageForce, damagePosition, bBuilding, damageCustom));
	aReturn = ActionApply(aReturn, Attribute_1193_OnTakeDamage(victim, attacker, slot, damage, damageType, damageForce, damagePosition, bBuilding));
	aReturn = ActionApply(aReturn, Attribute_1296_OnTakeDamage(victim, attacker, slot, damage, damageType, damageForce, damagePosition, bBuilding));
	aReturn = ActionApply(aReturn, Attribute_1321_OnTakeDamage(victim, attacker, slot, damage, damageType, damageForce, damagePosition, bBuilding));
	aReturn = ActionApply(aReturn, CritCharging_OnTakeDamage(victim, attacker, damageType, slot));
	aReturn = ActionApply(aReturn, InfectVictim_OnTakeDamage(victim, attacker, damage, damageType, slot, damageCustom));
	aReturn = ActionApply(aReturn, KeepDisguise_OnTakeDamage(victim, attacker, damage, damageType, slot, damageCustom));
	aReturn = ActionApply(aReturn, SentryHeal_OnTakeDamage(victim, attacker, inflictor, damage, bBuilding));
	aReturn = ActionApply(aReturn, AirDamageMod_OnTakeDamage(victim, attacker, damage));
	
	if(IsDamageTypeCrit(oldType)) damage /= 3.0;
	
	return aReturn;
}

// STOCKS

// Sets ammo in clip
stock SetClip(weapon, clip)
{
	SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
	ChangeEdictState(weapon, FindSendPropInfo("CTFWeaponBase", "m_iClip1"));
}

/*
    Adds health to a player until they reach a certain amount of overheal.

    Does not go above the overheal amount.

    Defaults to normal medigun overheal amount.
*/
stock AddPlayerHealth(iClient, iAdd, Float:flOverheal = 1.5, bAdditive = false, bool:bEvent = false)
{
    new iHealth = GetClientHealth(iClient);
    new iNewHealth = iHealth + iAdd;
    new iMax = bAdditive ? (TF2_GetMaxHealth(iClient) + RoundFloat(flOverheal)) : TF2_GetMaxOverHeal(iClient, flOverheal);
    if (iHealth < iMax)
    {
        iNewHealth = Math_Min(iNewHealth, iMax);
        if (bEvent)
        {
            ShowHealthGain(iClient, iNewHealth-iHealth);
        }
        SetEntityHealth(iClient, iNewHealth);
    }
}

stock ShowHealthGain(iPatient, iHealth, iHealer = -1)
{
    new iUserId = GetClientUserId(iPatient);
    new Handle:hEvent = CreateEvent("player_healed", true);
    SetEventBool(hEvent, "sourcemod", true);
    SetEventInt(hEvent, "patient", iUserId);
    SetEventInt(hEvent, "healer", Client_IsValid(iHealer) ? GetClientUserId(iHealer) : iUserId);
    SetEventInt(hEvent, "amount", iHealth);
    FireEvent(hEvent);

    hEvent = CreateEvent("player_healonhit", true);
    SetEventBool(hEvent, "sourcemod", true);
    SetEventInt(hEvent, "amount", iHealth);
    SetEventInt(hEvent, "entindex", iPatient);
    FireEvent(hEvent);
}

stock TF2_GetMaxHealth(iClient)
{
    new maxhealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, iClient);
    return ((maxhealth == -1 || maxhealth == 80896) ? GetEntProp(iClient, Prop_Data, "m_iMaxHealth") : maxhealth);
}

// Returns a client's max health if fully overhealed
stock TF2_GetMaxOverHeal(iClient, Float:flOverHeal = 1.5) // Quick-Fix would be 1.25
{
    return RoundFloat(float(TF2_GetMaxHealth(iClient)) * flOverHeal);
}

new g_iRopeTime[MAXPLAYERS+1] = 0;

stock ClientRope(client, Float:vTargetOrigin[3])
{
	if(g_iRopeTime[client] <= 0)
	{
		new team = GetClientTeam(client);
		decl Float:vOrigin[3];
		Entity_GetAbsOrigin(client, vOrigin);
		vOrigin[2] += 30.0;
		TE_SetupBeamPoints(vOrigin, vTargetOrigin, g_iBeamSprite, g_iHaloSprite, 0, 0, 0.1, 3.0, 0.1, 0, 0.0, g_iTeamColor[team], 3);
		TE_SendToAll();
		g_iRopeTime[client] = 4;
	} else
	{
		g_iRopeTime[client]--;
	}
}

stock bool:GetHasAttributeInAnySlot(client, slot = -1, const attribute[][] = m_bHasAttribute)
{
	if(!Client_IsValid(client)) return false;
	
	for(new i = 0; i < MAXSLOTS; i++)
	{
		if(m_bHasAttribute[client][i])
		{
			if(attribute[client][i])
			{
				if(slot == -1 || slot == i) return true;
			}
		}
	}
	
	return false;
}

stock Float:GetAttributeValueInAnySlot(client, slot = -1, const bool:baseAttribute[][], const Float:attribute[][], Float:defaultValue)
{
	if(!Client_IsValid(client)) return defaultValue;
	
	for(new i = 0; i < MAXSLOTS; i++)
	{
		if(m_bHasAttribute[client][i])
		{
			if(baseAttribute[client][i])
			{
				if(slot == -1 || slot == i)
				{
					return attribute[client][i];
				}
			}
		}
	}
	
	return defaultValue;
}

stock GetSlotContainingAttribute(client, const attribute[][] = m_bHasAttribute)
{
	if(!Client_IsValid(client)) return false;
	
	for(new i = 0; i < MAXSLOTS; i++)
	{
		if(m_bHasAttribute[client][i])
		{
			if(attribute[client][i])
			{
				return i;
			}
		}
	}
	
	return -1;
}

stock FindEntityByClassname2(startEnt, const String:classname[])
{
	while(startEnt > -1 && !IsValidEntity(startEnt))
	{
		startEnt--;
	}
	return FindEntityByClassname(startEnt, classname);
}

stock GetPlayerWeaponSlot_Wearable(client, slot)
{
	new edict = MaxClients + 1;
	if(slot == TFWeaponSlot_Secondary)
	{
		while((edict = FindEntityByClassname2(edict, "tf_wearable_demoshield")) != -1)
		{
			new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if((idx == 131 || idx == 406) && GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
			{
				return edict;
			}
		}
	}

	edict = MaxClients + 1;
	while((edict = FindEntityByClassname2(edict, "tf_wearable")) != -1)
	{
		new String:netclass[32];
		if(GetEntityNetClass(edict, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFWearable"))
		{
			new idx = GetEntProp(edict, Prop_Send, "m_iItemDefinitionIndex");
			if(((slot == TFWeaponSlot_Primary && (idx == 405 || idx == 608))
				|| (slot == TFWeaponSlot_Secondary && (idx == 57 || idx == 133 || idx == 231 || idx == 444 || idx == 642)))
				&& GetEntPropEnt(edict, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(edict, Prop_Send, "m_bDisguiseWearable"))
			{
				return edict;
			}
		}
	}
	return -1;
}

stock bool:GetHasBackstabShield(client)
{
	for(int i = 0; i < MAXSLOTS; i++)
	{
		new weapon = GetPlayerWeaponSlot(client, i);
		
		if(weapon != -1 && TF2Attrib_GetByName(weapon, "backstab shield") != Address_Null)
		{
			return true;
		}
	}
	
	for(new i = 0; i < 7; i++)
	{
		new wearable = GetPlayerWeaponSlot_Wearable(client, i);
		
		if(wearable != -1 && TF2Attrib_GetByName(wearable, "backstab shield") != Address_Null)
		{
			return true;
		}
	}
	
	return false;
}

stock Shake(client)
{    
	new flags = GetCommandFlags("shake") & (~FCVAR_CHEAT);
	SetCommandFlags("shake", flags);

	FakeClientCommand(client, "shake");
	
	flags = GetCommandFlags("shake") | (FCVAR_CHEAT);
	SetCommandFlags("shake", flags);
}

stock EmitSoundFromOrigin(const String:sound[],const Float:orig[3])
{
	EmitSoundToAll(sound, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, orig, NULL_VECTOR, true, 0.0);
}

stock GetWeaponSlot(client, weapon)
{
	if(!Client_IsValid(client)) return -1;
	
	for(new i = 0; i < MAXSLOTS; i++)
	{
		if(weapon == GetPlayerWeaponSlot(client, i))
		{
			return i;
		}
	}
	return -1;
}

stock bool:OnGround(client)
{
	return (GetEntityFlags(client) & FL_ONGROUND == FL_ONGROUND);
}

public Action:RemoveParticle(Handle:timer, any:particle)
{
	if(particle >= 0 && IsValidEntity(particle))
	{
		new String:classname[32];
		GetEdictClassname(particle, classname, sizeof(classname));
		if(StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "Stop");
			AcceptEntityInput(particle, "Kill");
			AcceptEntityInput(particle, "Deactivate");
			particle = -1;
		}
	}
}

stock PrecacheParticle(String:strName[])
{
	if(IsValidEntity(0))
	{
		new particle = CreateEntityByName("info_particle_system");
		if(IsValidEdict(particle))
		{
			new String:tName[32];
			GetEntPropString(0, Prop_Data, "m_iName", tName, sizeof(tName));
			DispatchKeyValue(particle, "targetname", "tf2particle");
			DispatchKeyValue(particle, "parentname", tName);
			DispatchKeyValue(particle, "effect_name", strName);
			DispatchSpawn(particle);
			SetVariantString(tName);
			AcceptEntityInput(particle, "SetParent", 0, particle, 0);
			ActivateEntity(particle);
			AcceptEntityInput(particle, "start");
			CreateTimer(0.01, RemoveParticle, particle);
		}
	}
}

stock SuperPrecacheSound(String:strPath[], String:strPluginName[] = "")
{
	if(strlen(strPath) == 0) return;
	
	PrecacheSound(strPath, true);
	decl String:strBuffer[PLATFORM_MAX_PATH];
	Format(strBuffer, sizeof(strBuffer), "sound/%s", strPath);
	AddFileToDownloadsTable(strBuffer);

	if(!FileExists(strBuffer) && !FileExists(strBuffer, true))
	{
		if(StrEqual(strPluginName, "")) LogError("PRECACHE ERROR: Unable to precache sound at '%s'. No fastdl service detected, and file is not on the server.", strPath);
		else LogError("PRECACHE ERROR: Unable to precache sound at '%s'. No fastdl service detected, and file is not on the server. It was required by the plugin '%s'", strPath, strPluginName);
	}
}

stock SuperPrecacheModel(String:strModel[], bool:bRequiredOnServer = false, bool:bMdlOnly = false)
{
	decl String:strBase[PLATFORM_MAX_PATH];
	decl String:strPath[PLATFORM_MAX_PATH];
	Format(strBase, sizeof(strBase), strModel);
	SplitString(strBase, ".mdl", strBase, sizeof(strBase));
	
	if(!bMdlOnly)
	{
		Format(strPath, sizeof(strPath), "%s.phy", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
		
		Format(strPath, sizeof(strPath), "%s.sw.vtx", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
		
		Format(strPath, sizeof(strPath), "%s.vvd", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
		
		Format(strPath, sizeof(strPath), "%s.dx80.vtx", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
		
		Format(strPath, sizeof(strPath), "%s.dx90.vtx", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
	}
	
	AddFileToDownloadsTable(strModel);
	
	if(HasFastDownload())
	{
		if(bRequiredOnServer && !FileExists(strModel) && !FileExists(strModel, true))
		{
			LogError("PRECACHE ERROR: Unable to precache REQUIRED model '%s'. File is not on the server.", strModel);
		}
	}
	
	return PrecacheModel(strModel, true);
}

stock bool:HideClientWearables(client, bool:bHide)
{
	for(new i = 0; i <= 5; i++)
	{
		new weapon = GetPlayerWeaponSlot(client, i);
		if(weapon > 0 && IsValidEdict(weapon))
		{
			if(!IsHiddenEntity(weapon)) HideEntity(weapon, bHide);
		}
	}

	new String:strEntities[][50] = {"tf_wearable", "tf_wearable_demoshield"};
	for(new i = 0; i < sizeof(strEntities); i++)
	{
		new entity = -1;
		while((entity = FindEntityByClassname(entity, strEntities[i])) != -1)
		{
			if(IsClassname(entity, strEntities[i]) && Entity_GetOwner(entity) == client && !IsHiddenEntity(entity)) HideEntity(entity, bHide);
		}
	}
}

stock bool:SubtractWeaponAmmo(client, slot, ammo)
{
	new weapon = GetPlayerWeaponSlot(client, slot);
	if(IsValidEntity(weapon))
	{
		new realammo = GetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 4);
		realammo -= ammo;
		if(realammo < 0) return false;
		SetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + 4, realammo);
		return true;
	}
	return false;
}

stock HideEntity(entity, bool:bHide)
{
	if(bHide)
	{
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 255, 255, 255, 0);
	} else
	{
		SetEntityRenderColor(entity, 255, 255, 255, 255);
		SetEntityRenderMode(entity, RENDER_NORMAL);
	}
}

stock bool:IsHiddenEntity(entity)
{
	return g_bHiddenEntities[entity];
}

stock bool:IsDisguised(client)
{
	if(!Client_IsValid(client)) return false;
	new class = GetEntProp(client, Prop_Send, "m_nDisguiseClass");
	return (class != 0);
}

stock Action:ActionApply(Action:aPrevious, Action:aNew)
{
	if(aNew != Plugin_Continue) aPrevious = aNew;
	return aPrevious;
}

stock GetClientPointPosition(client, Float:fEyePos[3], mask = MASK_PLAYERSOLID)
{
	decl Float:fEyeAngle[3];
	GetClientEyePosition(client, fEyePos);
	GetClientEyeAngles(client, fEyeAngle);
	TR_TraceRayFilter(fEyePos, fEyeAngle, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitEntity, client);
	
	if(TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(fEyePos);
	}
}

stock Float:GetEntityLife(entity)
{
	return GetEngineTime() - g_fEntityCreateTime[entity];
}

stock ShowParticle(String:particlename[], Float:time, Float:pos[3], Float:ang[3] = NULL_VECTOR)
{
	new particle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, RemoveParticle, particle);
	}
	else
	{
		LogError("ShowParticle: could not create info_particle_system");
		return -1;
	}
	return particle;
}

stock any:AttachParticle(ent, String:particleType[], Float:time = 0.0, Float:addPos[3] = NULL_VECTOR, Float:addAngle[3] = NULL_VECTOR, bool:bShow = true, String:strVariant[] = "", bool:bMaintain = false)
{
	new particle = CreateEntityByName("info_particle_system");
	if(IsValidEdict(particle))
	{
		new Float:pos[3];
		new Float:ang[3];
		decl String:tName[32];
		Entity_GetAbsOrigin(ent, pos);
		AddVectors(pos, addPos, pos);
		GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);
		AddVectors(ang, addAngle, ang);

		Format(tName, sizeof(tName), "target%i", ent);
		DispatchKeyValue(ent, "targetname", tName);

		TeleportEntity(particle, pos, ang, NULL_VECTOR);
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", ent);
		if(bShow)
		{
			SetVariantString(tName);
		} else
		{
			SetVariantString("!activator");
		}
		AcceptEntityInput(particle, "SetParent", ent, particle, 0);
		if(!StrEqual(strVariant, ""))
		{
			SetVariantString(strVariant);
			if(bMaintain) AcceptEntityInput(particle, "SetParentAttachmentMaintainOffset", ent, particle, 0);
			else AcceptEntityInput(particle, "SetParentAttachment", ent, particle, 0);
		}
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		if(time > 0.0) CreateTimer(time, RemoveParticle, particle);
	}
	else LogError("AttachParticle: could not create info_particle_system");
	return particle;
}

stock bool:IsClassname(entity, String:strClassname[])
{
	if(entity <= 0) return false;
	if(!IsValidEdict(entity)) return false;
	
	decl String:strClassname2[32];
	GetEdictClassname(entity, strClassname2, sizeof(strClassname2));
	if(!StrEqual(strClassname, strClassname2, false)) return false;
	
	return true;
}

stock AnglesToVelocity(Float:fAngle[3], Float:fVelocity[3], Float:fSpeed = 1.0)
{
	fVelocity[0] = Cosine(DegToRad(fAngle[1]));
	fVelocity[1] = Sine(DegToRad(fAngle[1]));
	fVelocity[2] = Sine(DegToRad(fAngle[0])) * -1.0;
	
	NormalizeVector(fVelocity, fVelocity);
	
	ScaleVector(fVelocity, fSpeed);
}

public bool:TraceRayDontHitEntity(entity, contentsMask, any:data)
{
	return (entity != data);
}

public bool:TraceRayDontHitPlayers(entity, mask)
{
	if(Client_IsValid(entity)) return false;
	
	return true;
}

stock bool:IsEntityBuilding(entity)
{
	if(entity <= 0) return false;
	if(!IsValidEdict(entity)) return false;
	if(IsClassname(entity, "obj_sentrygun")) return true;
	if(IsClassname(entity, "obj_dispenser")) return true;
	if(IsClassname(entity, "obj_teleporter")) return true;
	return false;
}

stock bool:IsAfterDamage(damageType)
{
	if(damageType == TF_DMG_BLEED) return true;
	if(damageType == TF_DMG_AFTERBURN) return true;
	
	return false;
}

stock bool:IsDamageTypeCrit(damageType)
{
	return (damageType & TF_DMG_CRIT == TF_DMG_CRIT);
}

stock bool:HasFastDownload()
{
	// if for whatever reason these are invalid, its pretty certain the fastdl isn't working
	if(g_hAllowDownloads == INVALID_HANDLE || g_hDownloadUrl == INVALID_HANDLE)
	{
		return false;
	}
	
	// if sv_allowdownload 0, fastdl is disabled
	if(!GetConVarBool(g_hAllowDownloads))
	{
		return false;
	}
	
	// if sv_downloadurl isn't set, the fastdl isn't enabled properly
	decl String:strUrl[PLATFORM_MAX_PATH];
	GetConVarString(g_hDownloadUrl, strUrl, sizeof(strUrl));
	if(StrEqual(strUrl, ""))
	{
		return false;
	}
	
	return true;
}

stock GetFlamethrowerStrength(client)
{
	if(!Client_IsValid(client)) return 0;
	if(!IsPlayerAlive(client)) return 0;
	new entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!IsClassname(entity, "tf_weapon_flamethrower")) return 0;
	
	new strength = GetEntProp(entity, Prop_Send, "m_iActiveFlames");
	return strength;
}

stock GetClientSlot(client)
{
	if(!Client_IsValid(client)) return -1;
	if(!IsPlayerAlive(client)) return -1;
	
	new slot = GetWeaponSlot(client, Client_GetActiveWeapon(client));
	return slot;
}

stock bool:GetClientViewTarget2(client, Float:vecClientEyeAng[3], Float:vOrigin[3], bool:bCeiling = false)
{
	decl Float:vecClientEyePos[3];
	GetClientEyePosition(client, vecClientEyePos);

	//Check for colliding entities
	TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitPlayers);
	
	vOrigin[0] = vecClientEyePos[0];
	vOrigin[1] = vecClientEyePos[1];
	vOrigin[2] = vecClientEyePos[2];

	if(TR_DidHit())
	{
		TR_GetEndPosition(vOrigin);
		decl Float:fNormal[3];
		TR_GetPlaneNormal(INVALID_HANDLE, fNormal);
		GetVectorAngles(fNormal, fNormal);
		if(!bCeiling) return true;
		else
		{
			if(fNormal[0] >= 0.0 && fNormal[0] <= 90.0) return true;
		}
	}
	return false;
}