#if defined _cw3_attributes_redux_included_
#endinput
#endif
#define _cw3_attributes_redux_included_

// Slots : Primary(0), Secondary(1), Melee(2), Grenade(3), Building(4), PDA(5), Item1(6), Item2(7)
#define MAXSLOTS  8
#define MAX_SLOTS  MAXSLOTS

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
forward Action CW3_OnAddAttribute(int slot, int client, const char[] attrib, const char[] plugin, const char[] value, bool whileActive);

/**
* Called when a weapon is removed.
*
* @param slot				Slot the weapon was in.
* @param client			Client index that had this weapon in the given slot.
*/
forward void CW3_OnWeaponRemoved(int slot, int client);

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
native bool CW3_AddAttribute(int slot, int client, const char[] attrib, const char[] plugin, const char[] value, bool whileActive);

/**
* Resets all attributes on the specified weapon slot.
*
* @param client			Client index.
* @param slot				Slot index.
*/
native void CW3_ResetAttribute(int client, int slot);

// m_bHasAttribute[MAXPLAYERS + 1][MAXSLOTS + 1] causes a super-marginal performance boost. At the end of your CW3_OnAddAttribute function, add the following line:
// if(!m_bHasAttribute[client][slot]) m_bHasAttribute[client][slot] = bool:action;
// Without the // of course. In your CW3_OnWeaponRemoved function, set m_bHasAttribute[client][slot] to false.
bool m_bHasAttribute[MAXPLAYERS + 1][MAXSLOTS + 1];

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
stock bool HasAttribute(int client, int slot = -1, const int attribute[][] = m_bHasAttribute, bool active = false)
{
	if (!IsValidClient(client))
	{
		return false;
	}
	
	if (!active)
	{
		for (int i = 0; i <= 4; i++)
		{
			if (m_bHasAttribute[client][i])
			{
				if (attribute[client][i])
				{
					if(slot == -1 || slot == i) return true;
				}
			}
		}
	}
	
	if (active)
	{
		if (!IsPlayerAlive(client))
		{
			return false;
		}

		int i = GetClientSlot(client);
		
		if (i != -1)
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
stock int GetAttributeValueI(int client, int slot = -1, const bool[][] baseAttribute, const int[][] attribute, bool active = false)
{
	if (!IsValidClient(client))
	{
		return 0;
	}
	
	if (!active)
	{
		for (int i = 0; i <= 4; i++)
		{
			if (m_bHasAttribute[client][i])
			{
				if (baseAttribute[client][i])
				{
					if(slot == -1 || slot == i)
					{
						return attribute[client][i];
					}
				}
			}
		}
	}
	
	if (active)
	{
		if (!IsPlayerAlive(client))
		{
			return 0;
		}

		int i = GetClientSlot(client);
		
		if (i != -1)
		{
			if (m_bHasAttribute[client][i])
			{
				if(baseAttribute[client][i])
				{
					return attribute[client][i];
				}
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
stock float GetAttributeValueF(int client, int slot = -1, const bool[][] baseAttribute, const float[][] attribute, bool active = false)
{
	if (!IsValidClient(client))
	{
		return 0.0;
	}
	
	if (!active)
	{
		for (int i = 0; i <= 4; i++)
		{
			if (m_bHasAttribute[client][i])
			{
				if (baseAttribute[client][i])
				{
					if(slot == -1 || slot == i)
					{
						return attribute[client][i];
					}
				}
			}
		}
	}
	
	if (active)
	{
		if (!IsPlayerAlive(client))
		{
			return 0.0;
		}

		int i = GetClientSlot(client);
		
		if (i != -1)
		{
			if (m_bHasAttribute[client][i])
			{
				if (baseAttribute[client][i])
				{
					return attribute[client][i];
				}
			}
		}
	}
	
	return 0.0;
}

#if !defined REQUIRE_PLUGIN
public void __pl_cw3_attributes_redux_SetNTVOptional()
{
	MarkNativeAsOptional("CW3_AddAttribute");
	MarkNativeAsOptional("CW3_ResetAttribute");
}
#endif

public SharedPlugin __pl_cw3_attributes_redux = 
{
	name = "cw3-attributes-redux",
	file = "cw3-attributes-redux.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};