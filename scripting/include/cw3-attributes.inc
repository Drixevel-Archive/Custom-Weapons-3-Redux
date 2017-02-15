#if defined _cw3_attributes_included_
  #endinput
#endif
#define _cw3_attributes_included_

// Global define a la AW2~
// Slots : Primary(0), Secondary(1), Melee(2), PDA(3), PDA2(4) only. From 0 to 4
#define MAXSLOTS  4

// Here it is! The natives for CW3. Do what you want with it,
// and keep in mind that this plugin is still in indev, so natives will probably added,
// and this native might (although it's very unlikely) be changed.
// Got ideas, suggestions or requests for natives? Post about it at https://forums.alliedmods.net/showthread.php?t=236242 !

// .inc Version: Beta 2

/*  ______ ____  _______          __     _____  _____   _____ 
  |  ____/ __ \|  __ \ \        / /\   |  __ \|  __ \ / ____|
  | |__ | |  | | |__) \ \  /\  / /  \  | |__) | |  | | (___  
  |  __|| |  | |  _  / \ \/  \/ / /\ \ |  _  /| |  | |\___ \ 
  | |   | |__| | | \ \  \  /\  / ____ \| | \ \| |__| |____) |
  |_|    \____/|_|  \_\  \/  \/_/    \_\_|  \_\_____/|_____/  */
// Well, there's only one; which is crucially important and has been here since the beginning...

/**
 * Called when an equipped weapon requests an attribute.
 *
 * @param slot				Slot the weapon is in.
 * @param client			Client index who is equipping this weapon.
 * @param attrib			Name of the attribute that has been requested.
 * @param plugin			Name of the plugin that it wants to equip the attribute from.
 * @param value				Desired value of the attribute. May not always be specified.
 * @param whileActive		Whether or not the attribute should only work while active. This is not law, and you can ignore this if you want to.
 *
 * @return					Return Plugin_Handled to confim that the attribute has been applied, Plugin_Continue otherwise.
							CW3 will log a warning if no plugin returns Plugin_Handled.
 */
forward Action:CW3_OnAddAttribute(slot, client, const String:attrib[], const String:plugin[], const String:value[], bool:whileActive);

/**
 * Called when a weapon is removed.
 *
 * @param slot				Slot the weapon was in.
 * @param client			Client index that had this weapon in the given slot.
 */
forward CW3_OnWeaponRemoved(slot, client);

/*   _____ _      _____ ______ _   _ _______ _____ 
   / ____| |    |_   _|  ____| \ | |__   __/ ____|
  | |    | |      | | | |__  |  \| |  | | | (___  
  | |    | |      | | |  __| | . ` |  | |  \___ \ 
  | |____| |____ _| |_| |____| |\  |  | |  ____) |
   \_____|______|_____|______|_| \_|  |_| |_____/  */
 // Getting/setting clients' custom attributes.

/**
 * Adds an attribute to the specified weapon.
 *
 * @param slot				Slot index.
 * @param client			Client index.
 * @param attrib			Name of the attribute that you want requested.
 * @param plugin			Name of the plugin that you want to equip the attribute from.
 * @param value				Desired value of the attribute.
 *
 * @return					True if the attribute was applied successfully, false otherwise.
 */
native bool:CW3_AddAttribute(slot, client, const String:attrib[], const String:plugin[], const String:value[], bool:whileActive);

/**
 * Resets all attributes on the specified weapon slot.
 *
 * @param client			Client index.
 * @param slot				Slot index.
 */
native CW3_ResetAttribute(client, slot);

/*
   _____ _______ ____   _____ _  __ _____ 
  / ____|__   __/ __ \ / ____| |/ // ____|
 | (___    | | | |  | | |    | ' /| (___  
  \___ \   | | | |  | | |    |  <  \___ \ 
  ____) |  | | | |__| | |____| . \ ____) |
 |_____/   |_|  \____/ \_____|_|\_\_____/  */
 // Stuff that could be useful for attribute devs.

// m_bHasAttribute[MAXPLAYERS + 1][MAXSLOTS + 1] causes a super-marginal performance boost. At the end of your CW3_OnAddAttribute function, add the following line:
// if(!m_bHasAttribute[client][slot]) m_bHasAttribute[client][slot] = bool:action;
// Without the // of course. In your CW3_OnWeaponRemoved function, set m_bHasAttribute[client][slot] to false.
new bool:m_bHasAttribute[MAXPLAYERS + 1][MAXSLOTS + 1];

/**
 * Checks if a client is valid. (Written by Orion)
 *
 * @param client			Client index.
 * @param replaycheck		Whether or not to check if the client is SourceTV or the Replay bot.
 *
 * @return					True if the client is valid, false otherwise.
 */
stock bool:IsValidClient(client, bool:replaycheck = true)
{
    if(client <= 0 || client > MaxClients) return false;
    if(!IsClientInGame(client)) return false;
    if(!IsClientConnected(client)) return false;
    if(GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
    if(replaycheck)
    {
        if(IsClientSourceTV(client) || IsClientReplay(client)) return false;
    }
    return true;
}

/**
 * Checks if a client has an attribute in any slot, a specific slot, or in the active slot. (Written by Orion)
 *
 * @param client			Client index.
 * @param slot				Which slot to check. Pass _ to check all slots.
 * @param attribute			Which attribute to search for. Defaults to m_bHasAttribute if nothing is passed.
 * @param active			Whether or not the attribute should only be checked on the active weapon.
 *
 * @return					True if the client has the attribute within the specified parameters, false otherwise.
 */
stock bool:HasAttribute(client, slot = -1, const attribute[][] = m_bHasAttribute, bool:active = false)
{
	if(!IsValidClient(client)) return false;
	
	if(!active)
	{
		for(new i = 0; i <= 4; i++)
		{
			if(m_bHasAttribute[client][i])
			{
				if(attribute[client][i])
				{
					if(slot == -1 || slot == i) return true;
				}
			}
		}
	}
	
	if(active)
	{
		if(!IsPlayerAlive(client)) return false;

		new i = GetClientSlot(client);
		if(i != -1)
		{
			if(m_bHasAttribute[client][i])
			{
				if(attribute[client][i]) return true;
			}
		}
	}
	
	return false;
}

/**
 * Gets the value of an attribute in any slot, a specific slot, or in the active slot. Int only. (Written by Orion)
 *
 * @param client			Client index.
 * @param slot				Which slot to check. Pass _ to check all slots.
 * @param baseAttribute		Which attribute to search for. 
 * @param attribute			Which value to fetch. Must be an integer.
 * @param active			Whether or not the attribute should only be checked on the active weapon. Optional.
 *
 * @return					The value of the attribute in the specified parameters, or 0 if nothing was found.
 */
stock GetAttributeValueI(client, slot = -1, const bool:baseAttribute[][], const attribute[][], bool:active = false)
{
	if(!IsValidClient(client)) return 0;
	
	if(!active)
	{
		for(new i = 0; i <= 4; i++)
		{
			if(m_bHasAttribute[client][i])
			{
				if(baseAttribute[client][i])
				{
					if(slot == -1 || slot == i) return attribute[client][i];
				}
			}
		}
	}
	
	if(active)
	{
		if(!IsPlayerAlive(client)) return 0;

		new i = GetClientSlot(client);
		if(i != -1)
		{
			if(m_bHasAttribute[client][i])
			{
				if(baseAttribute[client][i]) return attribute[client][i];
			}
		}
	}
	
	return 0;
}

/**
 * Gets the value of an attribute in any slot, a specific slot, or in the active slot. Float only. (Written by Orion)
 *
 * @param client			Client index.
 * @param slot				Which slot to check. Pass _ to check all slots.
 * @param baseAttribute		Which attribute to search for. 
 * @param attribute			Which value to fetch. Must be a Float.
 * @param active			Whether or not the attribute should only be checked on the active weapon. Optional.
 *
 * @return					The value of the attribute in the specified parameters, or 0.0 if nothing was found.
 */
stock Float:GetAttributeValueF(client, slot = -1, const bool:baseAttribute[][], const Float:attribute[][], bool:active = false)
{
	if(!IsValidClient(client)) return 0.0;
	
	if(!active)
	{
		for(new i = 0; i <= 4; i++)
		{
			if(m_bHasAttribute[client][i])
			{
				if(baseAttribute[client][i])
				{
					if(slot == -1 || slot == i) return attribute[client][i];
				}
			}
		}
	}
	
	if(active)
	{
		if(!IsPlayerAlive(client)) return 0.0;

		new i = GetClientSlot(client);
		if(i != -1)
		{
			if(m_bHasAttribute[client][i])
			{
				if(baseAttribute[client][i]) return attribute[client][i];
			}
		}
	}
	
	return 0.0;
}

public SharedPlugin:__pl_cw3_attributes = 
{
	name = "cw3-attributes",
	file = "cw3-attributes.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_cw3_attributes_SetNTVOptional()
{
	MarkNativeAsOptional("CW3_AddAttribute");
	MarkNativeAsOptional("CW3_ResetAttribute");
}
#endif