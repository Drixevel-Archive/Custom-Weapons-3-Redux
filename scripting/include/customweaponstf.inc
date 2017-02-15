#if defined _customweaponstf_included_
  #endinput
#endif
#define _customweaponstf_included_

// Here they are! Natives for Custom Weapons. Do what you want with 'em,
// and keep in mind that this plugin is still in beta, so natives will probably added,
// and these natives might (although it's very unlikely) be changed.
// Got ideas or suggestions for natives? Post about them at https://forums.alliedmods.net/showthread.php?t=236242 !

// .inc Version: Beta 6

/*  ______ ____  _______          __     _____  _____   _____ 
  |  ____/ __ \|  __ \ \        / /\   |  __ \|  __ \ / ____|
  | |__ | |  | | |__) \ \  /\  / /  \  | |__) | |  | | (___  
  |  __|| |  | |  _  / \ \/  \/ / /\ \ |  _  /| |  | |\___ \ 
  | |   | |__| | | \ \  \  /\  / ____ \| | \ \| |__| |____) |
  |_|    \____/|_|  \_\  \/  \/_/    \_\_|  \_\_____/|_____/  */
// Well, there's only two; one is crucially important and has been here since the beginning...

/**
 * Called when an equipped weapon requests an attribute.
 *
 * @param weapon			Entity index of the weapon being equipped.
 * @param client			Client index who is equipping this weapon.
 * @param attrib			Name of the attribute that has been requested.
 * @param plugin			Name of the plugin that it wants to equip the attribute from.
 * @param value				Desired value of the attribute. May not always be specified.
 *
 * @return					Return Plugin_Handled to confim that the attribute has been applied, Plugin_Continue otherwise.
							Custom Weapons will log a warning if no plugin returns Plugin_Handled.
 */
forward Action:CustomWeaponsTF_OnAddAttribute(weapon, client, const String:attrib[], const String:plugin[], const String:value[]);

// Then there's this one...

/**
 * Called when an equipped weapon is finished being spawned.
 *
 * @param weapon			Entity index of the weapon being equipped.
 * @param client			Client index who is equipping this weapon.
 *
 * @return					Does nothing.
 */
forward Action:CustomWeaponsTF_OnWeaponSpawned(weapon, client);

/*   _____ _      _____ ______ _   _ _______ _____ 
   / ____| |    |_   _|  ____| \ | |__   __/ ____|
  | |    | |      | | | |__  |  \| |  | | | (___  
  | |    | |      | | |  __| | . ` |  | |  \___ \ 
  | |____| |____ _| |_| |____| |\  |  | |  ____) |
   \_____|______|_____|______|_| \_|  |_| |_____/  */
 // Getting/setting clients' custom weapons.

/**
 * Adds an attribute to the specified weapon.
 *
 * @param client			Client index.
 * @param weapon				Weapon index.
 * @param attrib			Name of the attribute that you want requested.
 * @param plugin			Name of the plugin that you want to equip the attribute from.
 * @param value				Desired value of the attribute.
 *
 * @return					True if the attribute was applied successfully, false otherwise.
 */
native bool:CusWepsTF_AddAttribute(weapon, client, const String:attrib[], const String:plugin[], const String:value[]);

/**
 * Returns a Handle to the client's custom weapon KeyValues config in a specific slot.
 * Note three things:
 * 1. Use KvRewind() before using the Handle;
 * 2. Please do not close the Handle;
 * 3. The Handle should not be depended on to always exist. Try not to use it globally or asynchronously with timers.
 *
 * @param client			Client index.
 * @param slot				Weapon slot to check.
 *
 * @return					Handle to the weapon's KeyValues config. If the weapon in "slot" is not custom, INVALID_HANDLE is returned.
 * @error					Invalid client index, or client not connected.
 */
native Handle:CusWepsTF_GetClientWeapon(client, slot);

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
native bool:CusWepsTF_GetClientWeaponName(client, slot, String:name[], namelen);

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
native CusWepsTF_EquipItem(client, Handle:weapon, bool:makeActive = true);

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
native CusWepsTF_EquipItemByIndex(client, TFClassType:class, slot, index, bool:makeActive = true, bool:checkClass = true);

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
native CusWepsTF_EquipItemByName(client, const String:name[], bool:makeActive = true);

/*   _____ ______ _      ______ _____ _______ _____ ____  _   _ 
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
native CusWepsTF_GetNumItems(TFClassType:class, slot);

/**
 * Returns the weapon config of an item index.
 *
 * @param class				The player class which uses the item.
 * @param slot				The weapon slot of "class" that the item belongs in.
 * @param index				The index of the weapon, from 0 to GetNumItems()-1.
 *
 * @return					Handle to the weapon's KeyValues config. Please check the rules on CusWepsTF_GetClientWeapon() before using it.
 * @error					Invalid class.
 */
native Handle:CusWepsTF_GetItemConfigByIndex(TFClassType:class, slot, index);

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
native CusWepsTF_GetItemNameByIndex(TFClassType:class, slot, index, String:name[], namelen);

/**
 * Finds a weapon config by its name.
 *
 * @param name				The "proper" name of the weapon, case-insensitive.
 *
 * @return					Handle to the weapon's KeyValues config. Please check the rules on CusWepsTF_GetClientWeapon() before using it.
 *							Returns -1 on failure.
 */
native Handle:CusWepsTF_FindItemByName(String:name[]);

public SharedPlugin:__pl_customweaponstf = 
{
	name = "customweaponstf",
	file = "customweaponstf.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_customweaponstf_SetNTVOptional()
{
	MarkNativeAsOptional("CusWepsTF_AddAttribute");
	
	MarkNativeAsOptional("CusWepsTF_GetClientWeapon");
	MarkNativeAsOptional("CusWepsTF_GetClientWeaponName");
	
	MarkNativeAsOptional("CusWepsTF_EquipItem");
	MarkNativeAsOptional("CusWepsTF_EquipItemByIndex");
	MarkNativeAsOptional("CusWepsTF_EquipItemByName");
	
	MarkNativeAsOptional("CusWepsTF_GetNumItems");
	MarkNativeAsOptional("CusWepsTF_GetItemConfigByIndex");
	MarkNativeAsOptional("CusWepsTF_GetItemNameByIndex");
	MarkNativeAsOptional("CusWepsTF_FindItemByName");
}
#endif
