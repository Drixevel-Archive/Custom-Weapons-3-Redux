#if defined _cw3_included_
  #endinput
#endif
#define _cw3_included_

// Here they are! Natives for Custom Weapons. Do what you want with 'em,
// and keep in mind that this plugin is still in indev, so natives will probably added,
// and these natives might be changed.
// Got ideas or suggestions for natives? Post about them at https://forums.alliedmods.net/showthread.php?t=236242 !

// .inc Version: Beta 2

/*  ______ ____  _______          __     _____  _____   _____ 
  |  ____/ __ \|  __ \ \        / /\   |  __ \|  __ \ / ____|
  | |__ | |  | | |__) \ \  /\  / /  \  | |__) | |  | | (___  
  |  __|| |  | |  _  / \ \/  \/ / /\ \ |  _  /| |  | |\___ \ 
  | |   | |__| | | \ \  \  /\  / ____ \| | \ \| |__| |____) |
  |_|    \____/|_|  \_\  \/  \/_/    \_\_|  \_\_____/|_____/  */

/**
 * Called when an equipped weapon is finished being spawned.
 *
 * @param weapon			Entity index of the weapon being equipped.
 * @param client			Client index who is equipping this weapon. Validity check is run before this forward is sent out.
 *
 * @return					Does nothing.
 */
forward CW3_OnWeaponSpawned(weapon, slot, client);

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
forward CW3_OnWeaponEntCreated(weapon, slot, client, bool:wearable, bool:makeActive);

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
forward CW3_OnWeaponSwitch(client, weapon);

/*   _____ _      _____ ______ _   _ _______ _____ 
   / ____| |    |_   _|  ____| \ | |__   __/ ____|
  | |    | |      | | | |__  |  \| |  | | | (___  
  | |    | |      | | |  __| | . ` |  | |  \___ \ 
  | |____| |____ _| |_| |____| |\  |  | |  ____) |
   \_____|______|_____|______|_| \_|  |_| |_____/  */
 // Getting/setting clients' custom weapons.

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
native Handle:CW3_GetClientWeapon(client, slot);

/**
 * Check if a weapon ent is custom or not.
 *
 * @param weapon			Weapon ent index.
 *
 * @return					true if the given weapon ent is custom, false if it is not.
 */
native bool:CW3_IsCustom(weapon);

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
native Handle:CW3_GetWeaponConfig(weapon);

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
native bool:CW3_GetClientWeaponName(client, slot, String:name[], namelen);

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
native CW3_EquipItem(client, Handle:weapon, bool:makeActive = true);

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
native CW3_EquipItemByIndex(client, TFClassType:class, slot, index, bool:makeActive = true, bool:checkClass = true);

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
native CW3_EquipItemByName(client, const String:name[], bool:makeActive = true);

/*  _____ ______ _      ______ _____ _______ _____ ____  _   _ 
   / ____|  ____| |    |  ____/ ____|__   __|_   _/ __ \| \ | |
  | (___ | |__  | |    | |__ | |       | |    | || |  | |  \| |
   \___ \|  __| | |    |  __|| |       | |    | || |  | | . ` |
   ____) | |____| |____| |___| |____   | |   _| || |__| | |\  |
  |_____/|______|______|______\_____|  |_|  |_____\____/|_| \_| */
// Item "selection" -- scrolling through items without a particular client in mind.

/**
 * Checks the amount of custom items available for a specific class, in a specific slot.
 *
 * @param class				Player class.
 * @param slot				Weapon slot.
 *
 * @return					Number of items available in that slot on that class.
 * @error					Invalid class.
 */
native CW3_GetNumItems(TFClassType:class, slot);

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
native Handle:CW3_GetItemConfigByIndex(TFClassType:class, slot, index);

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
native CW3_GetItemNameByIndex(TFClassType:class, slot, index, String:name[], namelen);

/**
 * Finds a weapon config by its name.
 *
 * @param name				The "proper" name of the weapon, case-insensitive.
 *
 * @return					Handle to the weapon's KeyValues config. Please check the rules on CW3_GetClientWeapon() before using it.
 *							Returns -1 on failure.
 */
native Handle:CW3_FindItemByName(String:name[]);

/*	  _____  _     _    _  _____ _____ _   _ 
 	|  __ \| |   | |  | |/ ____|_   _| \ | |
 	| |__) | |   | |  | | |  __  | | |  \| |
	|  ___/| |   | |  | | | |_ | | | | . ` |
 	| |    | |___| |__| | |__| |_| |_| |\  |
 	|_|    |______\____/ \_____|_____|_| \_| */
// Controlling Custom Weapons 3

/**
 * Assume control of the Custom Weapons 3 plugin
 * This will prevent the /c menu from opening, more to come later.
 *
 * @param plugin_only 	Set to true to assume complete control of Custom Weapons 3.
 * @return		    	none
 */
native CW3_ControlCW3(bool:plugin_only=true);

public SharedPlugin:__pl_cw3 = 
{
	name = "cw3",
	file = "cw3.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_cw3_SetNTVOptional()
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
	
	MarkNativeAsOptional("CW3_ControlCW3");
}
#endif
