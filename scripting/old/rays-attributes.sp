#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2items>
#include <tf2attributes>
#include <smlib>
#include <RayLib>

#undef REQUIRE_PLUGIN
#include <cw3>
#define REQUIRE_PLUGIN

#include <cw3-attributes>

#define	TF_DMG_MELEE	(1 << 27) | (1 << 12) | (1 << 7)    // 134217728 + 4096 + 128 = 134221952

#define	MAX_EDICT_BITS	11
#define	MAX_EDICTS		(1 << MAX_EDICT_BITS)

new g_iLastButtons[MAXPLAYERS + 1] = 0;

new sentry[MAXPLAYERS + 1] = {-1, ...};
new bool:sentrySizeChanged[MAXPLAYERS + 1] =  {false, ...};

new dispenser[MAXPLAYERS + 1] = {-1, ...};
new bool:dispenserDetecting[MAXPLAYERS + 1] =  {false, ...};
new bool:playerMarked[MAXPLAYERS + 1] = {false, ...};
new playerMarkedByBuilding[MAXPLAYERS + 1] = {-1, ...};

new bool:BuildingBeingHauled[2049] = {false, ...};

new bool:isInfected[MAXPLAYERS + 1] = false;
new Handle:infectionTimer[MAXPLAYERS + 1];

enum 
{
	TFQual_None = -1,       // Probably should never actually set an item's quality to this
	TFQual_Normal = 0,
	TFQual_NoInspect = 0,   // Players cannot see your attributes
	TFQual_Rarity1,
	TFQual_Genuine = 1,
	TFQual_Rarity2,
	TFQual_Level = 2,       //  Same color as "Level # Weapon" text in description
	TFQual_Vintage,
	TFQual_Rarity3,         //  Is actually 4 - sort of brownish
	TFQual_Rarity4,
	TFQual_Unusual = 5,
	TFQual_Unique,
	TFQual_Community,
	TFQual_Developer,
	TFQual_Selfmade,
	TFQual_Customized,
	TFQual_Strange,
	TFQual_Completed,
	TFQual_Haunted,         //  13
	TFQual_Collectors,
	TFQual_Decorated
}

#define PLUGIN_VERSION "2.0.0"

public Plugin:myinfo =
{
	name = "Custom Weapons 3: Ray's Attributes",
	author = "Theray070696",
	description = "Random attributes that wouldn't fit into my AW2 Attributes plugin.",
	version = PLUGIN_VERSION,
	url = ""
};

new bool:ClassStatSteal[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:BlockSlot[MAXPLAYERS + 1][MAXSLOTS + 1];
new bool:BlockSlot_Slot[MAXPLAYERS + 1][MAXSLOTS + 1][MAXSLOTS + 1];

new bool:CritBleeding[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:FasterSwimming[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:FasterSwimming_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:SwimDamageBoost[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:SwimDamageBoost_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:FasterSwimmingSwingSpeed[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:FasterSwimmingSwingSpeed_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:SlowerWalking[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:SlowerWalking_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:LessDamageOnLand[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:LessDamageOnLand_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:SlowerWalkingSwingSpeed[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:SlowerWalkingSwingSpeed_Value[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:InfectVictimOnBackstab[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:InfectVictimOnBackstab_TimeToStun[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:InfectVictimOnBackstab_PercentHealth[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:LucioMedigun[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:LucioMedigun_Range[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:LucioMedigun_HealthPerSecond[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:LucioMedigun_SpeedBoostPercent[MAXPLAYERS + 1][MAXSLOTS + 1];

// Buildings :D
new bool:ChangeSentrySize[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:ChangeSentrySize_Size[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:DetectingDispenser[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:DetectingDispenser_Range[MAXPLAYERS + 1][MAXSLOTS + 1];

public OnPluginStart()
{
	CreateConVar("sm_rays_attributes_version", PLUGIN_VERSION, "Don't touch this!");
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) continue;
		OnClientPutInServer(i);
	}
	
	HookEntityOutput("item_healthkit_small", "OnPlayerTouch", Attributes_HealthKit);
	HookEntityOutput("item_healthkit_medium", "OnPlayerTouch", Attributes_HealthKit);
	HookEntityOutput("item_healthkit_full", "OnPlayerTouch", Attributes_HealthKit);
	
	HookEvent("player_death", Event_Death);
	HookEvent("post_inventory_application", EventPlayerInventory);
	HookEvent("player_spawn", EventPlayerSpawn);
	
	HookEvent("player_builtobject", Event_BuildObject);
	HookEvent("object_removed", Event_Remove);
	HookEvent("object_destroyed", Event_Break);
	HookEvent("player_dropobject", Event_Drop);
	HookEvent("player_carryobject", Event_Pickup);
}

public OnMapStart()
{
	PrecacheSound("items/powerup_pickup_plague_infected.wav", true);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Attributes_OnTakeDamage);
	SDKHook(client, SDKHook_PreThink, OnClientPreThink);
}

public OnClientPreThink(client)
{
	Attributes_PreThink(client);
}

public Action:Event_BuildObject(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new TFObjectType:thing = TFObjectType:GetEventInt(event, "object");
	
	if(Client_IsValid(client) && IsClientInGame(client))
	{
		new building = GetEventInt(event, "index");
		if(building > MaxClients && IsValidEntity(building))
		{
			if(thing == TFObject_Sentry)
			{
				sentry[client] = building;
				
				if(HasAttribute(client, _, ChangeSentrySize))
				{
					Building_SetScale(building, GetAttributeValueF(client, _, ChangeSentrySize, ChangeSentrySize_Size));
					sentrySizeChanged[client] = true;
				} else
				{
					sentrySizeChanged[client] = false;
				}
			} else if(thing == TFObject_Dispenser)
			{
				dispenser[client] = building;
				
				if(HasAttribute(client, _, DetectingDispenser))
				{
					dispenserDetecting[client] = true;
					
					BeginDetecting(building, client);
				} else
				{
					dispenserDetecting[client] = false;
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Event_Death(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(Client_IsValid(client))
	{
		playerMarked[client] = false;
		playerMarkedByBuilding[client] = -1;
		
		isInfected[client] = false;
		if(infectionTimer[client] != INVALID_HANDLE)
		{
			KillTimer(infectionTimer[client]);
			infectionTimer[client] = INVALID_HANDLE;
		}
	}
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
	isInfected[client] = false;
	if(infectionTimer[client] != INVALID_HANDLE)
	{
		KillTimer(infectionTimer[client]);
		infectionTimer[client] = INVALID_HANDLE;
	}
}

public Action:Event_Pickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new ent = GetEventInt(event, "index");
	if (ent > 0)
	{
		BuildingBeingHauled[ent] = true;
		Event_Remove(event, name, dontBroadcast); // Handle normal removal stuff
	}
	return Plugin_Continue;
}

public Action:Event_Drop(Handle:event, const String:name[], bool:dontBroadcast)
{
	new ent = GetEventInt(event, "index");
	if (ent > 0)
	{
		BuildingBeingHauled[ent] = false;
		Event_BuildObject(event, name, dontBroadcast); // Handle normal placement stuff
	}
	return Plugin_Continue;
}

public Action:Event_Break(Handle:event, const String:name[], bool:dontBroadcast)
{
	new ent = GetEventInt(event, "index");
	if (ent > 0)
	{
		BuildingBeingHauled[ent] = false;
		Event_Remove(event, name, dontBroadcast); // Handle normal removal stuff
	}
	return Plugin_Continue;
}

public Action:Event_Remove(Handle:event, const String:name[], bool:dontBroadcast)
{
	new ent = GetEventInt(event, "index");
	if(ent <= 0) return Plugin_Continue;
	
	new client = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
	if(!Client_IsValid(client)) return Plugin_Continue;
	
	if(sentry[client] == ent)
	{
		sentry[client] = -1;
		sentrySizeChanged[client] = false;
	}
	
	if(dispenser[client] == ent)
	{
		dispenser[client] = -1;
		dispenserDetecting[client] = false;
		
		for(new enemy = 1; enemy <= MaxClients; enemy++)
		{
			if(Client_IsValid(enemy) && IsClientInGame(enemy) && IsPlayerAlive(enemy))
			{
				if(playerMarked[enemy] && playerMarkedByBuilding[enemy] == ent)
				{
					SetEntProp(enemy, Prop_Send, "m_bGlowEnabled", 0);
					playerMarked[enemy] = false;
					playerMarkedByBuilding[enemy] = -1;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Attributes_HealthKit(const String:output[], caller, activator, Float:delay)
{
	if(Client_IsValid(activator) && IsClientInGame(activator) && IsPlayerAlive(activator))
	{
		if(isInfected[activator])
		{
			isInfected[activator] = false;
			if(infectionTimer[activator] != INVALID_HANDLE)
			{
				KillTimer(infectionTimer[activator]);
				infectionTimer[activator] = INVALID_HANDLE;
			}
		}
	}
}

stock GetWeaponSlot(client, weapon)
{
	if(!Client_IsValid(client)) return -1;
	
	for(new i = 0; i < MAXSLOTS + 1; i++)
    {
        if(weapon == GetPlayerWeaponSlot(client, i))
        {
            return i;
        }
    }
	return -1;
}

stock GetHealingTarget(client)
{
	new String:s[64];
	new medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if(medigun <= MaxClients || !IsValidEdict(medigun))
	{
		return -1;
	}
	GetEdictClassname(medigun, s, sizeof(s));
	if(strcmp(s, "tf_weapon_medigun", false) == 0)
	{
		if(GetEntProp(medigun, Prop_Send, "m_bHealing"))
		{
			return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
		}
	}
	return -1;
}

stock GetClientSlot(client)
{
	if(!Client_IsValid(client)) return -1;
	if(!IsPlayerAlive(client)) return -1;
	
	new slot = GetWeaponSlot(client, Client_GetActiveWeapon(client));
	return slot;
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

// From STT
stock Building_SetScale(iBuilding, Float:flScale)
{
	SetEntPropFloat(iBuilding, Prop_Send, "m_flModelScale", flScale);

	// Set the bounds of the building blueprint, without this, the engineer could get stuck in his own building!
	new Float:flMins[3];
	new Float:flMaxs[3];
	GetEntPropVector(iBuilding, Prop_Send, "m_vecBuildMins", flMins);
	GetEntPropVector(iBuilding, Prop_Send, "m_vecBuildMaxs", flMaxs);
	ScaleVector(flMins, flScale);
	ScaleVector(flMaxs, flScale);
	SetEntPropVector(iBuilding, Prop_Send, "m_vecBuildMins", flMins);
	SetEntPropVector(iBuilding, Prop_Send, "m_vecBuildMaxs", flMaxs);
}

stock BeginDetecting(building, client)
{
	if(!Client_IsValid(client)) return;
	if(!dispenserDetecting[client]) return;
	
	SetEntProp(building, Prop_Send, "m_bDisabled", 1); // Disable dispensing
	
	new Handle:dataPack;
	CreateDataTimer(0.01, DetectEnemies, dataPack, TIMER_REPEAT);
	WritePackCell(dataPack, building);
	WritePackCell(dataPack, client);
}

public Action:DetectEnemies(Handle:timer, Handle:dataPack)
{
	new building, client;
	
	ResetPack(dataPack);
	building = ReadPackCell(dataPack);
	client = ReadPackCell(dataPack);
	
	if(!Client_IsValid(client)) return Plugin_Stop;
	if(!dispenserDetecting[client]) return Plugin_Stop;
	
	if(GetEntPropFloat(building, Prop_Send, "m_flPercentageConstructed") < 1.0) return Plugin_Continue; // Don't want to kill the timer, as the dispenser is being built
	
	decl Float:vBuildingPos[3];
	Entity_GetAbsOrigin(building, vBuildingPos);
	
	new team = GetClientTeam(client);
	
	for(new enemy = 1; enemy <= MaxClients; enemy++)
	{
		if(Client_IsValid(enemy) && IsClientInGame(enemy) && IsPlayerAlive(enemy) && team != GetClientTeam(enemy))
		{
			new Float:vEnemyPos[3];
			GetClientAbsOrigin(enemy, vEnemyPos);
			
			new Float:m_flDistance = GetVectorDistance(vBuildingPos, vEnemyPos);
			
			if(m_flDistance <= GetAttributeValueF(client, _, DetectingDispenser, DetectingDispenser_Range))
			{
				if(!TF2_IsPlayerInCondition(enemy, TFCond_Disguising) && !TF2_IsPlayerInCondition(enemy, TFCond_Disguised) && !TF2_IsPlayerInCondition(enemy, TFCond_Cloaked) && !TF2_IsPlayerInCondition(enemy, TFCond_HalloweenGhostMode))
				{
					if(!playerMarked[enemy] && playerMarkedByBuilding[enemy] == -1 && !BuildingBeingHauled[building]) // If the enemy was not marked
					{
						SetEntProp(enemy, Prop_Send, "m_bGlowEnabled", 1); // Outline enemy.
						playerMarked[enemy] = true;
						playerMarkedByBuilding[enemy] = building;
					}
				} else // If the enemy is invisible, disguised, or something else
				{
					if(playerMarked[enemy] && playerMarkedByBuilding[enemy] == building) // But was marked at some point
					{
						SetEntProp(enemy, Prop_Send, "m_bGlowEnabled", 0); // Remove outline.
						playerMarked[enemy] = false;
						playerMarkedByBuilding[enemy] = -1;
					}
				}
			} else // If the enemy is not in range
			{
				if(playerMarked[enemy] && playerMarkedByBuilding[enemy] == building) // And the enemy was marked
				{
					SetEntProp(enemy, Prop_Send, "m_bGlowEnabled", 0); // Remove outline.
					playerMarked[enemy] = false;
					playerMarkedByBuilding[enemy] = -1;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

stock Action:ActionApply(Action:aPrevious, Action:aNew)
{
	if(aNew != Plugin_Continue) aPrevious = aNew;
	return aPrevious;
}

public Attributes_PreThink(client)
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
		buttons = Attribute_Stat_Steal_Prethink(client, buttons, slot2, buttonsLast);
		buttons = Attribute_Faster_Swimming_Prethink(client, buttons, slot2, buttonsLast);
		buttons = Attribute_Slower_Walking_Prethink(client, buttons, slot2, buttonsLast);
		buttons = Attribute_Faster_Swimming_Swing_Speed_Prethink(client, buttons, slot2, buttonsLast);
		buttons = Attribute_Slower_Walking_Swing_Speed_Prethink(client, buttons, slot2, buttonsLast);
	}
	CloseHandle(hArray);

	if(buttons != buttons2) SetEntProp(client, Prop_Data, "m_nButtons", buttons);    
	g_iLastButtons[client] = buttons;
}

public Action:Attributes_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damageCustom)
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
	
	// Attributes go here
	aReturn = ActionApply(aReturn, Attribute_Crit_Bleeding_OnTakeDamage(victim, attacker, slot, damage, damagetype, damageForce, damagePosition, bBuilding));
	aReturn = ActionApply(aReturn, Attribute_SwimDamageBoost_OnTakeDamage(victim, attacker, slot, damage, damagetype, damageForce, damagePosition, bBuilding));
	aReturn = ActionApply(aReturn, Attribute_LessDamageOnLand_OnTakeDamage(victim, attacker, slot, damage, damagetype, damageForce, damagePosition, bBuilding));
	aReturn = ActionApply(aReturn, Attribute_InfectVictim_OnTakeDamage(victim, attacker, damage, damagetype, slot, damageCustom));
	
	return aReturn;
}

public Action:Attribute_Crit_Bleeding_OnTakeDamage(victim, &attacker, slot, &Float:damage, &damagetype, Float:damageForce[3], Float:damagePosition[3], bool:bBuilding)
{
	if(!Client_IsValid(attacker)) return Plugin_Continue;
	if (slot == -1) return Plugin_Continue;
	
	if(!m_bHasAttribute[attacker][slot] || !CritBleeding[attacker][slot] || bBuilding) return Plugin_Continue;
	
	if(!Client_IsValid(victim)) return Plugin_Continue;
	if(!TF2_IsPlayerInCondition(victim, TFCond_Bleeding)) return Plugin_Continue;
	
	damage *= 3.0;
	damagetype = DMG_CRIT;
	
	return Plugin_Changed;
}

public Action:Attribute_SwimDamageBoost_OnTakeDamage(victim, &attacker, slot, &Float:damage, &damagetype, Float:damageForce[3], Float:damagePosition[3], bool:bBuilding)
{
	if(!Client_IsValid(attacker) || !Client_IsValid(victim) || slot == -1 || bBuilding) return Plugin_Continue;
	
	if((TF2_IsPlayerInCondition(attacker, TFCond_SwimmingCurse) || (GetEntityFlags(attacker) & FL_INWATER) || TF2_IsPlayerInCondition(attacker, TFCond_Jarated) || TF2_IsPlayerInCondition(attacker, TFCond_Milked)) && (m_bHasAttribute[attacker][slot] && SwimDamageBoost[attacker][slot]))
	{
		damage *= SwimDamageBoost_Value[attacker][slot];
	}
	
	return Plugin_Changed;
}

public Action:Attribute_LessDamageOnLand_OnTakeDamage(victim, &attacker, slot, &Float:damage, &damagetype, Float:damageForce[3], Float:damagePosition[3], bool:bBuilding)
{
	if(!Client_IsValid(attacker) || !Client_IsValid(victim) || slot == -1 || bBuilding) return Plugin_Continue;
	
	if(!(TF2_IsPlayerInCondition(attacker, TFCond_SwimmingCurse) || (GetEntityFlags(attacker) & FL_INWATER) || TF2_IsPlayerInCondition(attacker, TFCond_Jarated) || TF2_IsPlayerInCondition(attacker, TFCond_Milked)) && (m_bHasAttribute[attacker][slot] && LessDamageOnLand[attacker][slot]))
	{
		damage *= LessDamageOnLand_Value[attacker][slot];
	}
	
	return Plugin_Changed;
}

stock Action:Attribute_InfectVictim_OnTakeDamage(victim, &attacker, &Float:damage, &damageType, slot, damageCustom)
{
	if(!Client_IsValid(attacker) || !Client_IsValid(victim) || slot == -1 || damage <= 0.0) return Plugin_Continue;
	
	if(!m_bHasAttribute[attacker][slot] || !InfectVictimOnBackstab[attacker][slot]) return Plugin_Continue;
	
	if(damageCustom == TF_CUSTOM_BACKSTAB && !GetHasBackstabShield(victim))
	{
		isInfected[victim] = true;
		
		damage = 0.0;
		
		EmitSoundToClient(victim, "items/powerup_pickup_plague_infected.wav");
		
		new Handle:dataPack;
		CreateDataTimer(InfectVictimOnBackstab_TimeToStun[attacker][slot], InfectVictim_Timer_Stun, dataPack);
		WritePackCell(dataPack, victim);
		WritePackCell(dataPack, attacker);
		WritePackCell(dataPack, slot);
		
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
		new damage = RoundToNearest(TF2_GetMaxHealth(victim) * InfectVictimOnBackstab_PercentHealth[attacker][slot]);
		
		TF2_StunPlayer(victim, 1.5, 0.25, TF_STUNFLAGS_LOSERSTATE);
		
		Entity_Hurt(victim, damage, attacker, TF_DMG_MELEE, "tf_weapon_knife");
		
		EmitSoundToClient(victim, "items/powerup_pickup_plague_infected.wav");
		
		new Handle:dataPack2;
		infectionTimer[victim] = CreateDataTimer(1.0, InfectVictim_Timer_Damage, dataPack2, TIMER_REPEAT);
		WritePackCell(dataPack2, victim);
		WritePackCell(dataPack2, attacker);
		WritePackCell(dataPack2, damage);
	}
}

public Action:InfectVictim_Timer_Damage(Handle:timer, Handle:dataPack)
{
	new victim, attacker, damage;
	
	ResetPack(dataPack);
	victim = ReadPackCell(dataPack);
	attacker = ReadPackCell(dataPack);
	damage = ReadPackCell(dataPack);
	
	if(Client_IsValid(victim) && isInfected[victim])
	{
		TF2_StunPlayer(victim, 1.5, 0.25, TF_STUNFLAGS_LOSERSTATE);
		
		Entity_Hurt(victim, damage, attacker, TF_DMG_MELEE, "tf_weapon_knife");
		
		EmitSoundToClient(victim, "items/powerup_pickup_plague_infected.wav");
	}
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
			if(infectionTimer[client] != INVALID_HANDLE)
			{
				KillTimer(infectionTimer[client]);
				infectionTimer[client] = INVALID_HANDLE;
			}
		}
	}
}

new TFClassType:oldClass[MAXPLAYERS + 1];

stock Attribute_Stat_Steal_Prethink(client, &buttons, &slot, &buttonsLast)
{
	if(slot == -1) return buttons;
	new weapon = GetPlayerWeaponSlot(client, slot);
	if(weapon == -1) return buttons;
	if(!m_bHasAttribute[client][slot]) return buttons;
	if(!ClassStatSteal[client][slot]) return buttons;
	
	// Apply attribute from heal target to healer.
	//	Scout: Allows double jumping
	//	Soldier: 15% explosive damage resistance
	//	Pyro: Afterburn immunity
	//	Demoman: 15% explosive damage resistance
	//	Heavy: +50 extra health
	//	Engineer: Heals nearby buildings at a slow rate
	//	Medic: Natural health regen rate doubled
	//	Sniper: Needles have no damage falloff
	//	Spy: Disguises as an enemy Medic when the Spy is disguised
	
	new healTarget = GetHealingTarget(client); // Get the heal target
	
	if(Client_IsValid(healTarget)) // If the heal target is valid
	{
		new TFClassType:class = TF2_GetPlayerClass(healTarget); // Get heal target's class
		
		// Is the class a different one?
		if(class != oldClass[client])
		{
			// Get primary weapon for later
			//new weapon2 = GetPlayerWeaponSlot(client, 0); // Not needed just yet.
			
			// First, clear attributes from old heal targets, if there were any.
			if(oldClass[client] != TFClass_Unknown)
			{
				TF2Attrib_RemoveByName(weapon, "move speed bonus");
				TF2Attrib_RemoveByName(weapon, "dmg taken from blast reduced");
				TF2Attrib_RemoveByName(weapon, "afterburn immunity");
				TF2Attrib_RemoveByName(weapon, "max health additive bonus");
				TF2Attrib_RemoveByName(weapon, "health regen");
				//if(weapon2 != -1) // Make sure primary weapon exists
				//{
					//TF2Attrib_RemoveByName(weapon2, "dmg falloff decreased"); // Won't work, need to make "no damage falloff" attribute
				//}
			}
			
			// Do something based on what class the heal target is
			switch(class)
			{
				case TFClass_Scout: TF2Attrib_SetByName(weapon, "move speed bonus", 1.25);
				case TFClass_Soldier: TF2Attrib_SetByName(weapon, "dmg taken from blast reduced", 0.85);
				case TFClass_Pyro: TF2Attrib_SetByName(weapon, "afterburn immunity", 1.0);
				case TFClass_DemoMan: TF2Attrib_SetByName(weapon, "dmg taken from blast reduced", 0.85);
				case TFClass_Heavy: TF2Attrib_SetByName(weapon, "max health additive bonus", 50.0);
				//case TFClass_Engineer: // Later.
				case TFClass_Medic: TF2Attrib_SetByName(weapon, "health regen", 3.0);
				//case TFClass_Sniper: // Disable for now.
				//{
					//if(weapon2 != -1) // Make sure primary weapon exists
					//{
						//TF2Attrib_SetByName(weapon2, "dmg falloff decreased", 1.0); // Won't work, need to make "no damage falloff" attribute
					//}
				//}
				//case TFClass_Spy: // Later.
			}
			
			oldClass[client] = class;
		}
	}
	
	return buttons;
}

stock Attribute_Faster_Swimming_Prethink(client, &buttons, &slot, &buttonsLast)
{
	if (slot == -1) return buttons;
	new weapon = GetPlayerWeaponSlot(client, slot);
	if(weapon == -1) return buttons;
	if(!HasAttribute(client, _, FasterSwimming)) return buttons;
	
	if((TF2_IsPlayerInCondition(client, TFCond_SwimmingCurse) || (GetEntityFlags(client) & FL_INWATER) || TF2_IsPlayerInCondition(client, TFCond_Jarated) || TF2_IsPlayerInCondition(client, TFCond_Milked)) && (m_bHasAttribute[client][slot] && FasterSwimming[client][slot]))
	{
		TF2Attrib_SetByName(weapon, "move speed bonus", FasterSwimming_Value[client][slot]);
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
	} else if(HasAttribute(client, _, FasterSwimming))
	{
		weapon = GetPlayerWeaponSlot(client, GetSlotContainingAttribute(client, FasterSwimming));
		if(TF2Attrib_GetByName(weapon, "move speed bonus") != Address_Null)
		{
			TF2Attrib_RemoveByName(weapon, "move speed bonus");
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
		}
	}
	
	return buttons;
}

stock Attribute_Slower_Walking_Prethink(client, &buttons, &slot, &buttonsLast)
{
	if (slot == -1) return buttons;
	new weapon = GetPlayerWeaponSlot(client, slot);
	if(weapon == -1) return buttons;
	if(!HasAttribute(client, _, SlowerWalking)) return buttons;
	
	if(!(TF2_IsPlayerInCondition(client, TFCond_SwimmingCurse) || (GetEntityFlags(client) & FL_INWATER) || TF2_IsPlayerInCondition(client, TFCond_Jarated) || TF2_IsPlayerInCondition(client, TFCond_Milked)) && (m_bHasAttribute[client][slot] && SlowerWalking[client][slot]))
	{
		TF2Attrib_SetByName(weapon, "move speed penalty", SlowerWalking_Value[client][slot]);
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
	} else if(HasAttribute(client, _, SlowerWalking))
	{
		weapon = GetPlayerWeaponSlot(client, GetSlotContainingAttribute(client, SlowerWalking));
		if(TF2Attrib_GetByName(weapon, "move speed penalty") != Address_Null)
		{
			TF2Attrib_RemoveByName(weapon, "move speed penalty");
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
		}
	}
	
	return buttons;
}

stock Attribute_Faster_Swimming_Swing_Speed_Prethink(client, &buttons, &slot, &buttonsLast)
{
	if (slot == -1) return buttons;
	new weapon = GetPlayerWeaponSlot(client, slot);
	if(weapon == -1) return buttons;
	if(!HasAttribute(client, _, FasterSwimmingSwingSpeed)) return buttons;
	
	if((TF2_IsPlayerInCondition(client, TFCond_SwimmingCurse) || (GetEntityFlags(client) & FL_INWATER) || TF2_IsPlayerInCondition(client, TFCond_Jarated) || TF2_IsPlayerInCondition(client, TFCond_Milked)) && (m_bHasAttribute[client][slot] && FasterSwimmingSwingSpeed[client][slot]))
	{
		TF2Attrib_SetByName(weapon, "fire rate bonus", FasterSwimmingSwingSpeed_Value[client][slot]);
	} else if(HasAttribute(client, _, FasterSwimmingSwingSpeed))
	{
		weapon = GetPlayerWeaponSlot(client, GetSlotContainingAttribute(client, FasterSwimmingSwingSpeed));
		if(TF2Attrib_GetByName(weapon, "fire rate bonus") != Address_Null)
		{
			TF2Attrib_RemoveByName(weapon, "fire rate bonus");
		}
	}
	
	return buttons;
}

stock Attribute_Slower_Walking_Swing_Speed_Prethink(client, &buttons, &slot, &buttonsLast)
{
	if (slot == -1) return buttons;
	new weapon = GetPlayerWeaponSlot(client, slot);
	if(weapon == -1) return buttons;
	if(!HasAttribute(client, _, SlowerWalkingSwingSpeed)) return buttons;
	
	if(!(TF2_IsPlayerInCondition(client, TFCond_SwimmingCurse) || (GetEntityFlags(client) & FL_INWATER) || TF2_IsPlayerInCondition(client, TFCond_Jarated) || TF2_IsPlayerInCondition(client, TFCond_Milked)) && (m_bHasAttribute[client][slot] && SlowerWalkingSwingSpeed[client][slot]))
	{
		TF2Attrib_SetByName(weapon, "fire rate penalty", SlowerWalkingSwingSpeed_Value[client][slot]);
	} else if(HasAttribute(client, _, SlowerWalkingSwingSpeed))
	{
		weapon = GetPlayerWeaponSlot(client, GetSlotContainingAttribute(client, SlowerWalkingSwingSpeed));
		if(TF2Attrib_GetByName(weapon, "fire rate penalty") != Address_Null)
		{
			TF2Attrib_RemoveByName(weapon, "fire rate penalty");
		}
	}
	
	return buttons;
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
	new edict = MAXPLAYERS + 1;
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

	edict = MAXPLAYERS + 1;
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
	for(int i = 0; i < MAXSLOTS + 1; i++)
	{
		new weapon = GetPlayerWeaponSlot(client, i);
		
		if(weapon != -1 && TF2Attrib_GetByName(weapon, "backstab shield") != Address_Null)
		{
			PrintToChatAll("Found weapon with backstab shield!");
			return true;
		}
	}
	
	for(new i = 0; i < MAXSLOTS + 1; i++)
	{
		new wearable = GetPlayerWeaponSlot_Wearable(client, i);
		
		if(wearable != -1 && TF2Attrib_GetByName(wearable, "backstab shield") != Address_Null)
		{
			PrintToChatAll("Found wearable with backstab shield!");
			return true;
		}
	}
	
	return false;
}

stock GetSlotContainingAttribute(client, const attribute[][] = HasAttribute)
{
	if(!Client_IsValid(client)) return false;
	
	for(new i = 0; i < MAXSLOTS + 1; i++)
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

stock TF2_GetMaxHealth(iClient)
{
    new maxhealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, iClient);
    return ((maxhealth == -1 || maxhealth == 80896) ? GetEntProp(iClient, Prop_Data, "m_iMaxHealth") : maxhealth);
}

public CW3_OnWeaponSpawned(weapon, slot, client)
{
	if(!Client_IsValid(client)) return;
	
	for(new i = 0; i <= MAXSLOTS; i++)
	{
		if(m_bHasAttribute[client][i] && BlockSlot[client][i])
		{
			if(BlockSlot_Slot[client][i][slot])
			{
				TF2_RemoveWeaponSlot(client, slot);
			}
		}
	}
	
	if(HasAttribute(client, _, LucioMedigun))
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
	}
	
	if(sentry[client] != -1 && IsValidEntity(sentry[client]) && IsEntityBuilding(sentry[client]) && Client_IsValid(GetEntPropEnt(sentry[client], Prop_Send, "m_hBuilder")) && GetEntPropEnt(sentry[client], Prop_Send, "m_hBuilder") == client)
	{
		if((!HasAttribute(client, _, ChangeSentrySize) && sentrySizeChanged[client]) || (HasAttribute(client, _, ChangeSentrySize) && !sentrySizeChanged[client]))
		{
			SetVariantInt(1000);
			AcceptEntityInput(sentry[client], "RemoveHealth");
		}
	}
	
	if(dispenser[client] != -1 && IsValidEntity(dispenser[client]) && IsEntityBuilding(dispenser[client]) && Client_IsValid(GetEntPropEnt(dispenser[client], Prop_Send, "m_hBuilder")) && GetEntPropEnt(dispenser[client], Prop_Send, "m_hBuilder") == client)
	{
		if((!HasAttribute(client, _, DetectingDispenser) && dispenserDetecting[client]) || (HasAttribute(client, _, DetectingDispenser) && !dispenserDetecting[client]))
		{
			SetVariantInt(1000);
			AcceptEntityInput(dispenser[client], "RemoveHealth");
		}
	}
	
	return;
}

public Action:CW3_OnAddAttribute(slot, client, const String:attrib[], const String:plugin[], const String:value[], bool:whileActive)
{
	if(!StrEqual(plugin, "rays-attributes")) return Plugin_Continue;
	
	new Action:action;
	
	new weapon = GetWeaponSlot(client, slot);
	
	if(StrEqual(attrib, "class stat steal"))
	{
		ClassStatSteal[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "disable slot"))
	{
		TF2_RemoveWeaponSlot(client, StringToInt(value));
		
		BlockSlot[client][slot] = true;
		BlockSlot_Slot[client][slot][StringToInt(value)] = true;
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "crit bleeding players"))
	{
		CritBleeding[client][slot] = true;
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "swim speed increased"))
	{
		FasterSwimming[client][slot] = true;
		FasterSwimming_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "mod sentry size"))
	{
		ChangeSentrySize[client][slot] = true;
		ChangeSentrySize_Size[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "dispenser detects enemies"))
	{
		DetectingDispenser[client][slot] = true;
		DetectingDispenser_Range[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "damage while swimming increased"))
	{
		SwimDamageBoost[client][slot] = true;
		SwimDamageBoost_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "move speed decrease while not swimming"))
	{
		SlowerWalking[client][slot] = true;
		SlowerWalking_Value[client][slot] = StringToFloat(value);
    
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "attack speed increased while swimming"))
	{
		FasterSwimmingSwingSpeed[client][slot] = true;
		FasterSwimmingSwingSpeed_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "attack speed decreased while not swimming"))
	{
		SlowerWalkingSwingSpeed[client][slot] = true;
		SlowerWalkingSwingSpeed_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "damage while not swimming decreased"))
	{
		LessDamageOnLand[client][slot] = true;
		LessDamageOnLand_Value[client][slot] = StringToFloat(value);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "infect victim on backstab"))
	{
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		InfectVictimOnBackstab[client][slot] = true;
		
		InfectVictimOnBackstab_TimeToStun[client][slot] = StringToFloat(values[0]);
		InfectVictimOnBackstab_PercentHealth[client][slot] = StringToFloat(values[1]);
		
		action = Plugin_Handled;
	} else if(StrEqual(attrib, "lucio medigun"))
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		
		new String:values[3][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		LucioMedigun[client][slot] = true;
		
		LucioMedigun_Range[client][slot] = StringToFloat(values[0]);
		LucioMedigun_HealthPerSecond[client][slot] = StringToFloat(values[1]);
		LucioMedigun_SpeedBoostPercent[client][slot] = StringToFloat(values[2]);
		
		action = Plugin_Handled;
	}
	
	if(!m_bHasAttribute[client][slot]) m_bHasAttribute[client][slot] = bool:action;
	
	return action;
}

new bool:ClearSlots[MAXSLOTS + 1] = {false, ...};

public CW3_OnWeaponRemoved(slot, client)
{
	m_bHasAttribute[client][slot] = false;
	
	ClassStatSteal[client][slot] = false;
	oldClass[client] = TFClass_Unknown;
	
	BlockSlot[client][slot] = false;
	BlockSlot_Slot[client][slot] = ClearSlots;
	
	CritBleeding[client][slot] = false;
	
	FasterSwimming[client][slot] = false;
	FasterSwimming_Value[client][slot] = 1.0;
	
	SwimDamageBoost[client][slot] = false;
	SwimDamageBoost_Value[client][slot] = 1.0;
	
	FasterSwimmingSwingSpeed[client][slot] = false;
	FasterSwimmingSwingSpeed_Value[client][slot] = 1.0;
    
	SlowerWalking[client][slot] = false;
	SlowerWalking_Value[client][slot] = 1.0;
    
	LessDamageOnLand[client][slot] = false;
	LessDamageOnLand_Value[client][slot] = 1.0;
    
	SlowerWalkingSwingSpeed[client][slot] = false;
	SlowerWalkingSwingSpeed_Value[client][slot] = 1.0;
	
	InfectVictimOnBackstab[client][slot] = false;
	InfectVictimOnBackstab_TimeToStun[client][slot] = 0.0;
	InfectVictimOnBackstab_PercentHealth[client][slot] = 0.0;
	
	LucioMedigun[client][slot] = false;
	LucioMedigun_Range[client][slot] = 0.0;
	LucioMedigun_HealthPerSecond[client][slot] = 0.0;
	LucioMedigun_SpeedBoostPercent[client][slot] = 0.0;
	
	// Buildings :D
	ChangeSentrySize[client][slot] = false;
	ChangeSentrySize_Size[client][slot] = 1.0;
	
	DetectingDispenser[client][slot] = false;
	DetectingDispenser_Range[client][slot] = 0.0;
}