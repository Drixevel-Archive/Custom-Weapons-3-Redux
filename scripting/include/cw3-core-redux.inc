#if defined _cw3_core_redux_included_
#endinput
#endif
#define _cw3_core_redux_included_

/**
* Returns a Handle to the client's custom weapon KeyValues config in a specific slot.
* Note three things:
* 1. Use KvRewind() before using the Handle;
* 2. Please do not close the Handle;
* 3. The Handle should not be depended on to always exist. Try not to use it globally or asynchronously with timers.
* 4. This will cause errors if the weapon is a wearable. Use CW3_GetWeaponConfig if you want to be wearable-compatible!
*
* @param client			Client index.
* @param slot				Weapon slot to check.
*
* @return					Handle to the weapon's KeyValues config. If the weapon in "slot" is not custom, INVALID_HANDLE is returned.
* @error					Invalid client index, or client not connected.
*/
native Handle CW3_GetClientWeapon(int client, int slot);

/**
* Check if a weapon ent is custom or not.
*
* @param weapon			Weapon ent index.
*
* @return					true if the given weapon ent is custom, false if it is not.
*/
native bool CW3_IsCustom(int weapon);

/**
* Returns a Handle to the weapons custom KeyValues config.
* Note three things:
* 1. Use KvRewind() before using the Handle;
* 2. Please do not close the Handle;
* 3. The Handle should not be depended on to always exist. Try not to use it globally or asynchronously with timers.
*
* @param weapon			Weapon index.
*
* @return					Handle to the weapon's KeyValues config. If the weapon is not custom, INVALID_HANDLE is returned.
* @error					Invalid weapon index.
*/
native Handle CW3_GetWeaponConfig(int weapon);

/**
* Returns the name of a custom weapon that the client has equipped.
*
* @param client			Client index.
* @param slot				Weapon slot to check.
* @param name				String buffer to store the weapon's name in.
* @param namelen			Size of the buffer.
*
* @return					True if the client has a custom weapon in that slot, false otherwise.
							If there was no custom weapon, "name" is cleared.
* @error					Invalid client index, or client not connected.
*/
native bool CW3_GetClientWeaponName(int client, int slot, char[] name, int namelen);

/**
* Equips a custom item on a player.
*
* @param client			Client index.
* @param weapon			Handle to the weapon config.
* @param makeActive		Force the weapon to be active after equipping.
*
* @return					Entity index of the weapon.
* @error					Invalid client index, or client not connected.
*/
native int CW3_EquipItem(int client, Handle weapon, bool makeActive = true);

/**
* Equips a custom item on a player by its index.
*
* @param client			Client index.
* @param class				The player class which uses the item. If checkClass is true, this must be the client's class.
* @param slot				The weapon slot of "class" that the item belongs in.
* @param index				The index of the weapon, from 0 to GetNumItems()-1.
* @param makeActive		Force the weapon to be active after equipping.
* @param checkClass		If true, and "class" and the player's class are different, weapon equipping will fail.
*
* @return					Entity index of the weapon.
* @error					Invalid client index, client not connected, or invalid class.
*/
native int CW3_EquipItemByIndex(int client, TFClassType class, int slot, int index, bool makeActive = true, bool checkClass = true);

/**
* Equips a custom item on a player by its name.
*
* @param client			Client index.
* @param name				The "proper" name of the weapon, case-insensitive.
* @param makeActive		Force the weapon to be active after equipping.
*
* @return					Entity index of the weapon, or -1 if no matching weapon was found.
* @error					Invalid client index, or client not connected.
*/
native int CW3_EquipItemByName(int client, const char[] name, bool makeActive = true);

/**
* Checks the amount of custom items available for a specific class, in a specific slot.
*
* @param class				Player class.
* @param slot				Weapon slot.
*
* @return					Number of items available in that slot on that class.
* @error					Invalid class.
*/
native int CW3_GetNumItems(TFClassType class, int slot);

/**
* Returns the weapon config of an item index.
*
* @param class				The player class which uses the item.
* @param slot				The weapon slot of "class" that the item belongs in.
* @param index				The index of the weapon, from 0 to GetNumItems()-1.
*
* @return					Handle to the weapon's KeyValues config. Please check the rules on CW3_GetClientWeapon() before using it.
* @error					Invalid class.
*/
native Handle CW3_GetItemConfigByIndex(TFClassType class, int slot, int index);

/**
* Checks the name of an item by its index.
*
* @param class				The player class which uses the item.
* @param slot				The weapon slot of "class" that the item belongs in.
* @param index				The index of the weapon, from 0 to GetNumItems()-1.
* @param name				String buffer to store the weapon's name in.
* @param namelen			Size of the buffer.
*
* @return					Number of bytes written.
* @error					Invalid class.
*/
native int CW3_GetItemNameByIndex(TFClassType class, int slot, int index, char[] name, int namelen);

/**
* Finds a weapon config by its name.
*
* @param name				The "proper" name of the weapon, case-insensitive.
*
* @return					Handle to the weapon's KeyValues config. Please check the rules on CW3_GetClientWeapon() before using it.
*							Returns -1 on failure.
*/
native Handle CW3_FindItemByName(char[] name);

/**
* Called when an equipped weapon is finished being spawned.
*
* @param weapon			Entity index of the weapon being equipped.
* @param client			Client index who is equipping this weapon. Validity check is run before this forward is sent out.
*
* @return					Does nothing.
*/
forward void CW3_OnWeaponSpawned(int weapon, int slot, int client);

/**
* Called when a weapon entity has been spawned by tf2items,
* but the weapon creation process is not complete.
* Use this forward to do things linked to the weapon entity,
* such as apply a model, custom attributes, or sounds.
*
* @param weapon			Entity index of the weapon being equipped.
* @param slot   Slot the weapon will be equipped in.
* @param client			Client index who is equipping this weapon. Validity check is run before this forward is sent out.
* 
* Just a tip, you can use the weapon slot to get the weapon Handle.
*
* @return					Does nothing.
*/
forward void CW3_OnWeaponEntCreated(int weapon, int slot, int client, bool wearable, bool makeActive);

/**
* Called when a client changes their currently active weapon slot.
* Use this to toggle visibility of a weapon model if needed.
*
* @param client			Client index who changing their active weapon. Validity check is run before this forward is sent out.
* @param weapon			Entity index of the weapon being switched to.
* 
* Just a tip, you can use the weapon slot to get the weapon Handle.
*
* @return					Does nothing.
*/
forward void CW3_OnWeaponSwitch(int client, int weapon);

#if !defined REQUIRE_PLUGIN
public void __pl_cw3_core_redux_SetNTVOptional()
{
	MarkNativeAsOptional("CW3_GetClientWeapon");
	MarkNativeAsOptional("CW3_GetWeaponConfig");
	MarkNativeAsOptional("CW3_IsCustom");
	MarkNativeAsOptional("CW3_GetClientWeaponName");
	
	MarkNativeAsOptional("CW3_EquipItem");
	MarkNativeAsOptional("CW3_EquipItemByIndex");
	MarkNativeAsOptional("CW3_EquipItemByName");
	
	MarkNativeAsOptional("CW3_GetNumItems");
	MarkNativeAsOptional("CW3_GetItemConfigByIndex");
	MarkNativeAsOptional("CW3_GetItemNameByIndex");
	MarkNativeAsOptional("CW3_FindItemByName");
}
#endif

public SharedPlugin __pl_cw3_core_redux_ = 
{
	name = "cw3-core-redux",
	file = "cw3-core-redux.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
