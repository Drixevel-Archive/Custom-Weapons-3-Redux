#pragma semicolon 1
#include <tf2_stocks>
#include <sdkhooks>
#include <cw3-attributes>

#define PLUGIN_VERSION "Beta 2"

public Plugin:myinfo = {
    name = "Custom Weapons 3: Basic Attributes",
    author = "MasterOfTheXP (original author), Theray070696 (porting to CW3)",
    description = "Standard custom attributes.",
    version = PLUGIN_VERSION,
    url = "http://mstr.ca/"
};

/* *** Attributes In This Plugin ***
  !  "speed boost on hit teammate"
       "<user's speed boost duration> <teammate's>"
	   Upon hitting a teammate, both of your speeds will be boosted
	   for N seconds.
	   Can currently only be used on hitscan weapons and melee weapons,
	   due to TraceAttack not having a weapon parameter. :c
  -> "aim punch multiplier"
       "<multiplier>"
	   Upon hitting an enemy, the "aim punch" applied to their aim
	   will be multiplied by this amount.
	   High amounts are useful for disorienting enemies,
	   and low amounts will disable aim punch to prevent throwing off enemies.
  -> "aim punch to self"
       "<multiplier>"
	   Upon attacking with this weapon, the user will receive this much aim punch.
  -> "look down attack velocity"
       "<start velocity> <push velocity>"
	   When the user looks down and attacks with this weapon,
	   they will be pushed up into the air by N Hammer units.
	   "Start" value is for if the user is on the ground,
	   "push" is applied when they are already vertically moving.
  -> "add metal on attack"
       "<amount>"
	   Each time the user attacks with this weapon, they will gain this much metal.
	   You probably want to use a negative value with this attribute.
	   If negative, the user won't be able to fire this weapon unless they have
	   sufficient metal.
  -> "infinite ammo"
       "<ammo counter>"
	   This weapon's offhand ammo count will always be set to this amount.
	   If you're going to use this attribute, you also ought to add either
	   "hidden primary max ammo bonus" or "hidden secondary max ammo penalty" (TF2 attributes)
	   to your weapon, setting them to 0.0.
	   That way, the user cannot pick up and waste precious ammo packs and dropped weapons.
  -> "crits ignite"
	   Critical hits from this weapon will ignite the victim.
  -> "crit damage multiplier"
	   <multiplier>
	   Scales the amount of crit damage from this weapon.
	   The multiplier is applied to the base damage, so 1.5 on a sniper rifle headshot =
	   50 * 1.5 = 75, and 75 * 3 = 225.
  -> "old honorbound"
	   Works like honorbound used to. Can't switch from your weapon until you get a kill with it.
*/

// Here's where we store attribute values, which are received when the attribute is applied.
// There's one for each of the 2048 (+1) edict slots, which will sometimes be weapons.
// For example, when "crit damage multiplier" "0.6" is set on a weapon, we want
// CritDamage[thatweaponindex] to be set to 0.6, so we know to multiply the crit damage by 0.6x.
new bool:TeammateSpeedBoost[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:TeammateSpeedBoost_User[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:TeammateSpeedBoost_Teammate[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:AimPunchMultiplier[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:AimPunchToSelf[MAXPLAYERS + 1][MAXSLOTS + 1];
new bool:LookDownAttackVelocity[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:LookDownAttackVelocity_Start[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:LookDownAttackVelocity_Push[MAXPLAYERS + 1][MAXSLOTS + 1];
new AddMetalOnAttack[MAXPLAYERS + 1][MAXSLOTS + 1];
new InfiniteAmmo[MAXPLAYERS + 1][MAXSLOTS + 1];
new bool:CritsIgnite[MAXPLAYERS + 1][MAXSLOTS + 1];
new Float:CritDamage[MAXPLAYERS + 1][MAXSLOTS + 1];

new bool:OldHonorbound[MAXPLAYERS + 1][MAXSLOTS + 1]; // DAMNIT TOUGH BREAK!

// Here's a great spot to place "secondary" variables used by attributes, such as
// "ReduxHypeBonusDraining[MAXPLAYERS + 1][MAXSLOTS + 1]" (custom-attributes.sp) or client variables,
// like the one seen below, which shows the next time we can play a "click" noise.
new Float:NextOutOfAmmoSoundTime[MAXPLAYERS + 1];

new bool:IsHonorbound[MAXPLAYERS + 1];

public OnPluginStart()
{
	HookEvent("player_death", Event_Death);
	
	// We'll set weapons' ammo counts every ten times a second if they have infinite ammo.
	CreateTimer(0.1, Timer_TenTimesASecond, _, TIMER_REPEAT);
	
	// Since we're hooking damage (seen below), we need to hook the below hooks on players who were
	// already in the game when the plugin loaded, if any.
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		OnClientPutInServer(i);
	}
}

// Usually, you'll want to hook damage done to players, using SDK Hooks.
// You'll need to do so in OnPluginStart (taken care of above) and in OnClientPutInServer.
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public Action:OnWeaponSwitch(client, weapon)
{
	if(weapon == -1) return Plugin_Continue;
	if(client <= 0 || client > MaxClients) return Plugin_Continue;
	
	new slot = GetClientSlot(client); // Get the slot as a backup in case the following fails.
	if(weapon > 0 && IsValidEdict(weapon)) // If a weapon id is over 0 and it's a valid edict,
	{
		slot = GetWeaponSlot(client, weapon); // Get the slot from the attackers weapon.
	}
	
	if(slot == -1) return Plugin_Continue;
	
	if(IsHonorbound[client])
	{
		return Plugin_Handled;
	} else
	{
		if(OldHonorbound[client][slot])
		{
			IsHonorbound[client] = true;
			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new weapon = GetEventInt(event, "weaponid");
	new bool:feign = bool:(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER);
	if(weapon != -1 && (attacker > 0 && attacker <= MaxClients))
	{
		new slot = GetClientSlot(attacker); // Get the slot as a backup in case the following fails.
		if(weapon > 0 && IsValidEdict(weapon)) // If a weapon id is over 0 and it's a valid edict,
		{
			slot = GetWeaponSlot(attacker, weapon); // Get the slot from the attackers weapon.
		}
		
		if(slot != -1 && m_bHasAttribute[attacker][slot])
		{
			if(OldHonorbound[attacker][slot] && IsHonorbound[attacker] && !feign)
			{
				IsHonorbound[attacker] = false;
			}
		}
	}
	
	if(!feign)
	{
		IsHonorbound[victim] = false;
	}
}

// This is called whenever a custom attribute is added, so first...
public Action:CW3_OnAddAttribute(slot, client, const String:attrib[], const String:plugin[], const String:value[], bool:whileActive)
{
	// Filter out other plugins. If "plugin" is not "basic-attributes", then ignore this attribute.
	if (!StrEqual(plugin, "basic-attributes")) return Plugin_Continue;
	
	// "action" here is what we'll return to the base Custom Weapons plugin when we're done.
	// It defaults to "Plugin_Continue" which means the attribute wasn't recognized. So let's check if we
	// know what attribute this is...
	new Action:action;
	
	// Compare the attribute's name against each of our own.
	// In this case, if it's "aim punch multiplier"...
	if (StrEqual(attrib, "aim punch multiplier"))
	{
		// ...then get the number from the "value" string, and remember that.
		AimPunchMultiplier[client][slot] = StringToFloat(value);
		
		// We recognize the attribute and are ready to make it work!
		action = Plugin_Handled;
	}
	// If it wasn't aim punch multiplier, was it any of our other attributes?
	else if (StrEqual(attrib, "speed boost on hit teammate"))
	{
		// Here, we use ExplodeString to get two numbers out of the same string.
		new String:values[2][10];
		ExplodeString(value, " ", values, sizeof(values), sizeof(values[]));
		
		// ...And then set them to two different variables.
		TeammateSpeedBoost_User[client][slot] = StringToFloat(values[0]);
		TeammateSpeedBoost_Teammate[client][slot] = StringToFloat(values[1]);
		
		// This attribute could potentially be used to ONLY give a speed boost to the user,
		// or ONLY the teammate, so we use a third boolean variable to see if it's on.
		TeammateSpeedBoost[client][slot] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "aim punch to self"))
	{
		AimPunchToSelf[client][slot] = StringToFloat(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "look down attack velocity"))
	{
		new String:values2[2][10];
		ExplodeString(value, " ", values2, sizeof(values2), sizeof(values2[]));
		
		LookDownAttackVelocity_Start[client][slot] = StringToFloat(values2[0]);
		LookDownAttackVelocity_Push[client][slot] = StringToFloat(values2[1]);
		
		LookDownAttackVelocity[client][slot] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "add metal on attack"))
	{
		AddMetalOnAttack[client][slot] = StringToInt(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "infinite ammo"))
	{
		InfiniteAmmo[client][slot] = StringToInt(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "crits ignite"))
	{
		// Some attributes are simply on/off, so we don't need to check the "value" string.
		CritsIgnite[client][slot] = true;
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "crit damage multiplier"))
	{
		CritDamage[client][slot] = StringToFloat(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "old honorbound"))
	{
		OldHonorbound[client][slot] = true;
		action = Plugin_Handled;
	}
	
	// If the weapon isn't already marked as custom (as far as this plugin is concerned)
	// then mark it as custom, but ONLY if we've set "action" to Plugin_Handled.
	if (!m_bHasAttribute[client][slot]) m_bHasAttribute[client][slot] = bool:action;
	
	// Let Custom Weapons know that we're going to make the attribute work (Plugin_Handled)
	// or let it print a warning (Plugin_Continue).
	return action;
}
// ^ Remember, this is called once for every custom attribute (attempted to be) applied!


// Now, let's start making those attributes work.
// Every time a player takes damage, we'll check if the weapon that the attacker used
// has one of our attributes.
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (attacker <= 0 || attacker > MaxClients) return Plugin_Continue; // Attacker isn't valid, so the weapon won't be either.
	
	new slot = GetClientSlot(attacker); // Get the slot as a backup in case the following fails.
	if(weapon > 0 && IsValidEdict(weapon)) // If a weapon id is over 0 and it's a valid edict,
	{
		slot = GetWeaponSlot(attacker, weapon); // Get the slot from the attackers weapon.
	} else // Otherwise
	{
		if (inflictor > 0 && (inflictor > 0 || inflictor <= MaxClients) && IsValidEdict(inflictor)) // If the inflictor id is over 0 and it's not a client AND it's a valid edict,
		{
			slot = GetWeaponSlot(attacker, inflictor); // Get the slot from the inflictor, as it might be a sentry gun.
		}
	}
	
	if (slot == -1) return Plugin_Continue; // Slot is invalid, so it won't be custom.
	if (!m_bHasAttribute[attacker][slot]) return Plugin_Continue; // Slot is valid, but doesn't have one of our attributes. We don't care!
	
	// If we've gotten this far, we might need to take "action" c:
	// But, seriously, we might. Our "action" will be set to Plugin_Changed if we
	// change anything about this damage.
	new Action:action;
	
	// Does this weapon have the "aim punch multiplier" attribute? 1.0 is the default for this attribute, so let's compare against that.
	// Also, make sure the victim is a player.
	if (AimPunchMultiplier[attacker][slot] != 1.0 && victim > 0 && victim <= MaxClients)
	{
		// It does! So, we'll use this sorta-complex-looking data timer to multiply the victim's aim punch in one frame (0.0 seconds).
		new Handle:data;
		CreateDataTimer(0.0, Timer_DoAimPunch, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, GetClientUserId(victim));
		WritePackCell(data, EntIndexToEntRef(weapon));
		WritePackCell(data, false);
		ResetPack(data);
	}
	
	// Now, maybe the above was applied. Wether it was or not, the weapon might have ALSO had "crit damage multiplier".
	// So we'll use another "if" statement to check (NOT else if) but, of course, we also need to see if it's a crit (if "damagetype" includes DMG_CRIT)
	if (CritDamage[attacker][slot] != 1.0 && damagetype & DMG_CRIT)
	{
		// It does, and this is a crit, so multiply the damage by the variable we just checked.
		damage *= CritDamage[attacker][slot];
		
		// We changed the damage, so we need to return Plugin_Changed below...
		action = Plugin_Changed;
	}
	
	// Return Plugin_Continue if the damage wasn't changed, or Plugin_Changed if it was. Done!
	return action;
}

// We also check AFTER the damage was applied, which you should honestly try to do if your attribute
// is not going to change anything about the damage itself.
// This way, other plugins (and attributes!) can change the damage's information, and you will know.
public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype, weapon, const Float:damageForce[3], const Float:damagePosition[3])
{
	if (attacker <= 0 || attacker > MaxClients) return;
	
	new slot = GetClientSlot(attacker); // Get the slot as a backup in case the following fails.
	if(weapon > 0 && IsValidEdict(weapon)) // If a weapon id is over 0 and it's a valid edict,
	{
		slot = GetWeaponSlot(attacker, weapon); // Get the slot from the attackers weapon.
	} else // Otherwise
	{
		if (inflictor > 0 && (inflictor > 0 || inflictor <= MaxClients) && IsValidEdict(inflictor)) // If the inflictor id is over 0 and it's not a client AND it's a valid edict,
		{
			slot = GetWeaponSlot(attacker, inflictor); // Get the slot from the inflictor, as it might be a sentry gun.
		}
	}
	
	if (slot == -1) return;
	if (!m_bHasAttribute[attacker][slot]) return;
	
	if (CritsIgnite[attacker][slot] && victim > 0 && victim <= MaxClients && damagetype & DMG_CRIT && damage > 0.0)
		TF2_IgnitePlayer(victim, attacker);
}

// Here's where we set the aim punch for "aim punch multiplier" and "aim punch to self".
public Action:Timer_DoAimPunch(Handle:timer, Handle:data)
{
	new client = GetClientOfUserId(ReadPackCell(data));
	if (!client) return;
	if (!IsPlayerAlive(client)) return;
	new slot = EntRefToEntIndex(ReadPackCell(data));
	if (slot == -1) return;
	new bool:self = bool:ReadPackCell(data);
	if (!self)
	{
		new Float:angle[3];
		GetEntPropVector(client, Prop_Send, "m_vecPunchAngle", angle);
		for (new i = 0; i <= 2; i++)
			angle[i] *= AimPunchMultiplier[client][slot];
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", angle);
	}
	else
	{
		new Float:angle[3];
		angle[0] = AimPunchToSelf[client][slot]*-1;
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", angle);
	}
}

// In addition to the above damage hooks, we also have TraceAttack, which is done before either of them,
// and also can detect most hits on teammates! Unfortunately, though, it doesn't have as much information as OnTakeDamage.
// Still, it can be really useful. We'll use it here for "speed boost on hit teammate".
public Action:OnTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if (attacker <= 0 || attacker > MaxClients) return Plugin_Continue;
	new weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon"); // We have to get the weapon manually, sadly; this also means that
																		// attributes that use this can only be applied to "hitscan" weapons.
	new slot = GetClientSlot(attacker); // Get the slot as a backup in case the following fails.
	if(weapon > 0 && IsValidEdict(weapon)) // If a weapon id is over 0 and it's a valid edict,
	{
		slot = GetWeaponSlot(attacker, weapon); // Get the slot from the attackers weapon.
	} else // Otherwise
	{
		if (inflictor > 0 && (inflictor > 0 || inflictor <= MaxClients) && IsValidEdict(inflictor)) // If the inflictor id is over 0 and it's not a client AND it's a valid edict,
		{
			slot = GetWeaponSlot(attacker, inflictor); // Get the slot from the inflictor, as it might be a sentry gun.
		}
	}
	
	if (slot == -1) return Plugin_Continue;
	if (!m_bHasAttribute[attacker][slot]) return Plugin_Continue;
	
	if (TeammateSpeedBoost[attacker][slot])
	{
		if (GetClientTeam(attacker) == GetClientTeam(victim))
		{
			// Apply the speed boosts for the amounts of time that the weapon wants.
			TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, TeammateSpeedBoost_User[attacker][slot]);
			TF2_AddCondition(victim, TFCond_SpeedBuffAlly, TeammateSpeedBoost_Teammate[attacker][slot]);
		}
	}
	return Plugin_Continue;
}

// Here's another great thing to track; TF2_CalcIsAttackCritical.
// It's a simple forward (no hooking needed) that fires whenever a client uses a weapon. Very handy!
public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	new slot = GetClientSlot(client); // Get the slot as a backup in case the following fails.
	if(weapon > 0 && IsValidEdict(weapon)) // If a weapon id is over 0 and it's a valid edict,
	{
		slot = GetWeaponSlot(client, weapon); // Get the slot from the attackers weapon.
	}
	
	if (slot == -1 || !m_bHasAttribute[client][slot]) return Plugin_Continue;
	
	if (LookDownAttackVelocity[client][slot])
	{
		new Float:ang[3];
		GetClientEyeAngles(client, ang);
		if (ang[0] >= 50.0)
		{
			new Float:vel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
			if (vel[2] == 0.0) vel[2] = LookDownAttackVelocity_Start[client][slot];
			else vel[2] += LookDownAttackVelocity_Push[client][slot];
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
		}
	}
	if (AddMetalOnAttack[client][slot])
	{
		new metal = GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3);
		metal += AddMetalOnAttack[client][slot];
		if (metal < 0) metal = 0;
		if (metal > 200) metal = 200;
		SetEntProp(client, Prop_Data, "m_iAmmo", metal, 4, 3);
	}
	if (AimPunchToSelf[client][slot] != 0.0)
	{
		new Handle:data;
		CreateDataTimer(0.0, Timer_DoAimPunch, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, GetClientUserId(client));
		WritePackCell(data, EntIndexToEntRef(slot));
		WritePackCell(data, true);
		ResetPack(data);
	}
	return Plugin_Continue;
}

// Here's another one, OnPlayerRunCmd. It's called once every frame for every single player.
// You can use it to change around what the client is pressing (like fire/alt-fire) and do other
// precise actions. But it's once every frame (66 times/second), so avoid using expensive things like
// comparing strings or TF2_IsPlayerInCondition!
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:ang[3], &weapon2)
{
	if (client <= 0 || client > MaxClients) return Plugin_Continue;
	
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon <= 0 || weapon > 2048) return Plugin_Continue;
	
	new slot = GetClientSlot(client); // Get the slot as a backup in case the following fails.
	if(weapon > 0 && IsValidEdict(weapon)) // If a weapon id is over 0 and it's a valid edict,
	{
		slot = GetWeaponSlot(client, weapon); // Get the slot from the attackers weapon.
	}
	
	if (slot == -1 || !m_bHasAttribute[client][slot]) return Plugin_Continue;
	
	new Action:action;
	if (AddMetalOnAttack[client][slot] < 0)
	{
		new required = AddMetalOnAttack[client][slot] * -1;
		
		if (required > GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3))
		{
			new Float:nextattack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack"),
			Float:nextsec = GetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack"), Float:time = GetGameTime();
			if (nextattack-0.1 <= time) SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", time+0.1);
			if (nextsec-0.1 <= time) SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", time+0.1);
			if (buttons & IN_ATTACK || buttons & IN_ATTACK2)
			{
				buttons &= ~(IN_ATTACK|IN_ATTACK2);
				action = Plugin_Changed;
				if (GetTickedTime() >= NextOutOfAmmoSoundTime[client])
				{
					ClientCommand(client, "playgamesound weapons/shotgun_empty.wav");
					NextOutOfAmmoSoundTime[client] = GetTickedTime() + 0.5;
				}
			}
		}
	}
	return action;
}

// If you need to check things like strings or conditions, a repeating-0.1-second timer like this one
// is a much better choice. Though, really, you should try to keep things out of OnGameFrame/OnPlayerRunCmd
// as often as possible. Even if the below "infinite ammo" was being set 66 times a second instead of 10 times,
// client prediction still makes it look like 10 times per second.
public Action:Timer_TenTimesASecond(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		if (!IsPlayerAlive(client)) continue;
		new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (wep == -1) continue;
		
		new slot = GetClientSlot(client); // Get the slot as a backup in case the following fails.
		if(wep > 0 && IsValidEdict(wep)) // If a weapon id is over 0 and it's a valid edict,
		{
			slot = GetWeaponSlot(client, wep); // Get the slot from the attackers weapon.
		}
		
		if (slot == -1 || !m_bHasAttribute[client][slot]) continue;
		
		if (InfiniteAmmo[client][slot])
			SetAmmo_Weapon(wep, InfiniteAmmo[client][slot]);
	}
}

// Once a weapon entity has been "destroyed", it's been unequipped.
// Unfortunately, that also means that we need to reset all of its variables.
// If you don't, really bad things will happen to the next weapon that occupies that entity slot,
// custom or not!
public CW3_OnWeaponRemoved(slot, client)
{
	m_bHasAttribute[client][slot] = false;
	TeammateSpeedBoost[client][slot] = true;
	TeammateSpeedBoost_User[client][slot] = 0.0;
	TeammateSpeedBoost_Teammate[client][slot] = 0.0;
	AimPunchMultiplier[client][slot] = 1.0;
	LookDownAttackVelocity[client][slot] = false;
	LookDownAttackVelocity_Start[client][slot] = 0.0;
	LookDownAttackVelocity_Push[client][slot] = 0.0;
	AddMetalOnAttack[client][slot] = 0;
	InfiniteAmmo[client][slot] = 0;
	AimPunchToSelf[client][slot] = 0.0;
	CritsIgnite[client][slot] = false;
	CritDamage[client][slot] = 1.0;
	
	OldHonorbound[client][slot] = false;
}

stock SetAmmo_Weapon(weapon, newAmmo)
{
	new owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner == -1) return;
	new iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
	new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
	SetEntData(owner, iAmmoTable+iOffset, newAmmo, 4, true);
}

stock GetClientSlot(client)
{
	if(!IsClientInGame(client)) return -1;
	if(!IsPlayerAlive(client)) return -1;
	
	new slot = GetWeaponSlot(client, GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon"));
	return slot;
}

stock GetWeaponSlot(client, weapon)
{
	if(client <= 0 || client > MaxClients) return -1;
	
	for(new i = 0; i < MAXSLOTS; i++)
	{
		if(weapon == GetPlayerWeaponSlot(client, i))
		{
			return i;
		}
	}
	return -1;
}