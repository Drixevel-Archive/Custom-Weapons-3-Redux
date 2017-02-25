#pragma semicolon 1
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2items>
#include <tf2attributes>
#include <cw3>

#define PLUGIN_VERSION "Beta 1"

public Plugin:myinfo = {
	name = "Custom Weapons 3: CW2 Attributes Module",
	author = "MasterOfTheXP (original plugin), Theray070696 (updating CW2 and porting to CW3 module)",
	description = "Legacy module to allow CW2 attributes to work properly with CW3.",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
};

new Handle:fOnAddAttribute;
new Handle:fOnWeaponGive;

new plugincount;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	fOnAddAttribute = CreateGlobalForward("CustomWeaponsTF_OnAddAttribute", ET_Event, Param_Cell, Param_Cell, Param_String, Param_String, Param_String);
	fOnWeaponGive = CreateGlobalForward("CustomWeaponsTF_OnWeaponSpawned", ET_Event, Param_Cell, Param_Cell);
	
	CreateNative("CusWepsTF_AddAttribute", Native_AddAttribute);
	
	CreateNative("CusWepsTF_GetClientWeapon", Native_GetClientWeapon);
	CreateNative("CusWepsTF_GetClientWeaponName", Native_GetClientWeaponName);
	
	CreateNative("CusWepsTF_EquipItem", Native_EquipItem);
	CreateNative("CusWepsTF_EquipItemByIndex", Native_EquipItemIndex);
	CreateNative("CusWepsTF_EquipItemByName", Native_EquipItemName);
	
	CreateNative("CusWepsTF_GetNumItems", Native_GetNumItems);
	CreateNative("CusWepsTF_GetItemConfigByIndex", Native_GetItemConfig);
	CreateNative("CusWepsTF_GetItemNameByIndex", Native_GetItemName);
	CreateNative("CusWepsTF_FindItemByName", Native_FindItemByName);
	
	RegPluginLibrary("customweaponstf");
	return APLRes_Success;
}

public OnPluginStart()
{
	RegAdminCmd("sm_custom_addattribute", Command_AddAttribute, ADMFLAG_CHEATS);
}

public OnMapStart()
{
	plugincount = 0;
	new String:FileName[PLATFORM_MAX_PATH], String:Dir[PLATFORM_MAX_PATH], FileType:type;
	BuildPath(Path_SM, Dir, sizeof(Dir), "plugins/customweaponstf");
	
	if (!DirExists(Dir))
	{
		PrintToServer("[CW2 Attributes] Warning! CW2 Attributes' attribute plugin directory (%s) does not exist! You'll be limited to just stock TF2 attributes, which are boring.", Dir);
	} else
	{
		new Handle:hDir = OpenDirectory(Dir);
		while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
		{
			if (FileType_File != type) continue;
			if (StrContains(FileName, ".smx") == -1) continue;
			Format(FileName, sizeof(FileName), "customweaponstf/%s", FileName);
			ServerCommand("sm plugins load %s", FileName);
			plugincount++;
		}
		CloseHandle(hDir);
	}
	
	PrintToServer("[CW2 Attributes] CW2 Attributes loaded successfully with %i attribute plugins.", plugincount);
}

public OnPluginEnd()
{
	new String:Dir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Dir, sizeof(Dir), "plugins/customweaponstf");
	if (!DirExists(Dir))
	{
		PrintToServer("[CW2 Attributes] WARNING! CW2 Attributes' attribute directory (%s) does not exist, so any running attribute plugins will not be unloaded. If you're removing CW2 Attributes (goodbye!) any running attribute plugins will likely still show up as <ERROR> in your server's plugin list.", Dir);
	} else
	{
		new Handle:hDir = OpenDirectory(Dir), String:FileName[PLATFORM_MAX_PATH], FileType:type;
		while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
		{
			if (FileType_File != type) continue;
			if (StrContains(FileName, ".smx") == -1) continue;
			Format(FileName, sizeof(FileName), "customweaponstf/%s", FileName);
			ServerCommand("sm plugins unload %s", FileName);
		}
		CloseHandle(hDir);
	}
}

public CW3_OnWeaponEntCreated(ent, slot, client, bool:wearable, bool:makeActive)
{
	new Handle:hConfig = CW3_GetWeaponConfig(ent);
	
	if(hConfig == INVALID_HANDLE)
	{
		return;
	}
	
	KvRewind(hConfig);
	
	if (KvJumpToKey(hConfig, "attributes"))
	{
		KvGotoFirstSubKey(hConfig);
		do {
			new String:Att[64], String:szPlugin[64], String:Value[PLATFORM_MAX_PATH + 64];
			KvGetSectionName(hConfig, Att, sizeof(Att));
			KvGetString(hConfig, "plugin", szPlugin, sizeof(szPlugin));
			KvGetString(hConfig, "value", Value, sizeof(Value));
			
			AddAttribute(ent, client, Att, szPlugin, Value);
			
		} while (KvGotoNextKey(hConfig));
	}
	
	new Action:act = Plugin_Continue;
	Call_StartForward(fOnWeaponGive);
	Call_PushCell(ent);
	Call_PushCell(client);
	Call_Finish(act);
}

public Action:Command_AddAttribute(client, args)
{
	if (args < 3)
	{
		ReplyToCommand(client, "[SM] Usage: custom_addattribute <client> <slot> <\"attribute name\"> <\"value\"> <\"plugin\"> - Sets an attribute onto a user's weapon.");
		return Plugin_Handled;
	}
	
	new String:target_arg[MAX_TARGET_LENGTH], slot, String:strslot[10], String:attribute[64], String:value[64], String:plugin[64];
	GetCmdArg(1, target_arg, sizeof(target_arg));
	GetCmdArg(2, strslot, sizeof(strslot));
	GetCmdArg(3, attribute, sizeof(attribute));
	GetCmdArg(4, value, sizeof(value));
	GetCmdArg(5, plugin, sizeof(plugin));
	slot = StringToInt(strslot);
	
	new String:target_name[MAX_TARGET_LENGTH], target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	if ((target_count = ProcessTargetString(target_arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (new i = 0; i < target_count; i++)
	{
		new wep = GetPlayerWeaponSlot(target_list[i], slot);
		//if (wep == -1) continue; AddAttribute checks this so we don't have to here.
		
		AddAttribute(wep, target_list[i], attribute, plugin, value);
	}
	
	return Plugin_Handled;
}

// NATIVES

public Native_AddAttribute(Handle:plugin, args)
{
	new weapon = GetNativeCell(1), client = GetNativeCell(2), String:attrib[64], String:atPlugin[64], String:value[PLATFORM_MAX_PATH + 64];
	
	GetNativeString(3, attrib, sizeof(attrib));
	GetNativeString(4, atPlugin, sizeof(atPlugin));
	GetNativeString(5, value, sizeof(value));
	
	return bool:AddAttribute(weapon, client, attrib, atPlugin, value);
}

public Native_GetClientWeapon(Handle:plugin, args)
{
	new client = GetNativeCell(1), slot = GetNativeCell(2);
	if (!NativeCheck_IsClientValid(client)) return (_:INVALID_HANDLE);
	
	new wep = GetPlayerWeaponSlot(client, slot);
	return CW3_IsCustom(wep) ? (_:CW3_GetWeaponConfig(wep)) : (_:INVALID_HANDLE);
}

public Native_GetClientWeaponName(Handle:plugin, args)
{
	new client = GetNativeCell(1), slot = GetNativeCell(2), namelen = GetNativeCell(4);
	if (!NativeCheck_IsClientValid(client)) return false;
	
	new wep = GetPlayerWeaponSlot(client, slot);
	if (!CW3_IsCustom(wep))
	{
		SetNativeString(3, "", GetNativeCell(4));
		return false;
	}
	
	new Handle:conf = CW3_GetWeaponConfig(wep);
	
	if(conf == INVALID_HANDLE)
	{
		SetNativeString(3, "", GetNativeCell(4));
		return false;
	}
	
	new String:name[namelen];
	KvRewind(conf);
	KvGetSectionName(conf, name, namelen);
	SetNativeString(3, name, namelen);
	return true;
}

public Native_EquipItem(Handle:plugin, args)
{
	new client = GetNativeCell(1), Handle:weapon = Handle:GetNativeCell(2), bool:makeActive = GetNativeCell(3);
	if (!NativeCheck_IsClientValid(client)) return -1;
	
	return CW3_EquipItem(client, weapon, makeActive);
}

public Native_EquipItemIndex(Handle:plugin, args)
{
	new client = GetNativeCell(1), TFClassType:class = TFClassType:GetNativeCell(2), slot = GetNativeCell(3), index = GetNativeCell(4),
	bool:makeActive = GetNativeCell(5), bool:checkClass = GetNativeCell(6);
	if (!NativeCheck_IsClientValid(client)) return -1;
	if (!NativeCheck_IsClassValid(class)) return -1;
	
	return CW3_EquipItemByIndex(client, class, slot, index, makeActive, checkClass);
}

public Native_EquipItemName(Handle:plugin, args)
{
	new client = GetNativeCell(1), String:name[96], bool:makeActive = GetNativeCell(3);
	GetNativeString(2, name, sizeof(name));
	if (!NativeCheck_IsClientValid(client)) return 0;
	
	new TFClassType:myClass = TF2_GetPlayerClass(client), TFClassType:class2; // Loop through all classes -- first by the player's class, then other classes in order
	do {
		new TFClassType:class = (class2 == TFClassType:0 ? myClass : class2);
		if (class2 == myClass) continue;
		
		for (new i = 0; i <= 4; i++) // Slots
		{
			new num = CW3_GetNumItems(class, i);
			for (new j = 0; j < num; j++)
			{
				new Handle:hConfig = CW3_GetItemConfigByIndex(class, i, j);
				KvRewind(hConfig);
				
				new String:jName[96];
				KvGetSectionName(hConfig, jName, sizeof(jName));
				
				if (StrEqual(name, jName, false)) return CW3_EquipItem(client, hConfig, makeActive);
			}
		}
	} while (++class2 < TFClassType:10);
	
	return -1;
}

public Native_GetNumItems(Handle:plugin, args)
{
	new TFClassType:class = TFClassType:GetNativeCell(1), slot = GetNativeCell(2);
	if (!NativeCheck_IsClassValid(class)) return -1;
	
	return CW3_GetNumItems(class, slot);
}

public Native_GetItemConfig(Handle:plugin, args)
{
	new TFClassType:class = TFClassType:GetNativeCell(1), slot = GetNativeCell(2), index = GetNativeCell(3);
	if (!NativeCheck_IsClassValid(class)) return -1;
	
	return _:CW3_GetItemConfigByIndex(class, slot, index);
}

public Native_GetItemName(Handle:plugin, args)
{
	new TFClassType:class = TFClassType:GetNativeCell(1), slot = GetNativeCell(2), index = GetNativeCell(3), namelen = GetNativeCell(5);
	if (!NativeCheck_IsClassValid(class)) return -1;
	
	new Handle:hWeapon = CW3_GetItemConfigByIndex(class, slot, index);
	KvRewind(hWeapon);
	
	new String:name[namelen], bytes;
	KvGetSectionName(hWeapon, name, namelen);
	SetNativeString(4, name, namelen, _, bytes);
	return bytes;
}

public Native_FindItemByName(Handle:plugin, args)
{
	new String:name[96];
	GetNativeString(1, name, sizeof(name));
	
	for (new TFClassType:class = TFClass_Scout; class <= TFClass_Engineer; class++)
	{
		for (new i = 0; i < 5; i++) // Slots
		{
			new num = CW3_GetNumItems(class, i);
			for (new j = 0; j < num; j++)
			{
				new Handle:hConfig = CW3_GetItemConfigByIndex(class, i, j);
				KvRewind(hConfig);
				
				new String:jName[96];
				KvGetSectionName(hConfig, jName, sizeof(jName));
				
				if (StrEqual(name, jName, false)) return _:hConfig;
			}
		}
	}
	
	return _:INVALID_HANDLE;
}

// STOCKS

// Code copied from weapon spawning code, neater to do this in a stock so we can call it without adding ~30 lines to this file.
stock Action:AddAttribute(weapon, client, String:attrib[], String:plugin[], String:value[])
{
	if(!IsValidClient(client)) return Plugin_Continue;
	if(weapon == -1) return Plugin_Continue;
	
	if(!StrEqual(plugin, "tf2attributes", false) && !StrEqual(plugin, "tf2attributes.int", false) && !StrEqual(plugin, "tf2items", false))
	{
		new Action:act = Plugin_Continue;
		Call_StartForward(fOnAddAttribute);
		Call_PushCell(weapon);
		Call_PushCell(client);
		Call_PushString(attrib);
		Call_PushString(plugin);
		Call_PushString(value);
		Call_Finish(act);
		//if (!act) PrintToServer("[Custom Weapons] WARNING! Attribute \"%s\" (value \"%s\" plugin \"%s\") seems to have been ignored by all attributes plugins. It's either an invalid attribute, incorrect plugin, an error occured in the att. plugin, or the att. plugin forgot to return Plugin_Handled.", attrib, value, plugin);
		
		return act;
	} else if(!StrEqual(plugin, "tf2items", false))
	{
		if(StrEqual(plugin, "tf2attributes", false)) TF2Attrib_SetByName(weapon, attrib, StringToFloat(value));
		else TF2Attrib_SetByName(weapon, attrib, Float:StringToInt(value));
	}
	
	return Plugin_Handled;
}

stock GetClientSlot(client)
{
	if (!IsValidClient(client)) return -1;
	if (!IsPlayerAlive(client)) return -1;
	
	decl String:strActiveWeapon[32];
	GetClientWeapon(client, strActiveWeapon, sizeof(strActiveWeapon));
	new slot = GetWeaponSlot(strActiveWeapon);
	return slot;
}

// From chdata.inc
stock GetSlotFromPlayerWeapon(iClient, iWeapon)
{
	if(!IsValidClient(iClient)) return -1;
	
	for (new i = 0; i <= 5; i++)
	{
		if (iWeapon == GetPlayerWeaponSlot(iClient, i))
		{
			return i;
		}
	}
	return -1;
}

stock TF2_GetClassString(TFClassType:class, String:str[], maxlen, bool:proper = false)
{
	switch (class)
	{
		case TFClass_Scout: Format(str, maxlen, "scout");
		case TFClass_Soldier: Format(str, maxlen, "soldier");
		case TFClass_Pyro: Format(str, maxlen, "pyro");
		case TFClass_DemoMan: Format(str, maxlen, "demoman");
		case TFClass_Heavy: Format(str, maxlen, "heavy");
		case TFClass_Engineer: Format(str, maxlen, "engineer");
		case TFClass_Medic: Format(str, maxlen, "medic");
		case TFClass_Sniper: Format(str, maxlen, "sniper");
		case TFClass_Spy: Format(str, maxlen, "spy");
	}
	if (proper) str[0] = CharToUpper(str[0]);
}

stock TF2_GetPlayerClassString(client, String:str[], maxlen, bool:proper = false)
	TF2_GetClassString(TF2_GetPlayerClass(client), str, maxlen, proper);

public NativeCheck_IsClientValid(client)
{
	if (client <= 0 || client > MaxClients) return ThrowNativeError(SP_ERROR_NATIVE, "Client index %i is invalid", client);
	if (!IsClientInGame(client)) return ThrowNativeError(SP_ERROR_NATIVE, "Client %i is not in game", client);
	return true;
}

public NativeCheck_IsClassValid(TFClassType:class)
{
	if (class < TFClass_Scout || class > TFClass_Engineer) return ThrowNativeError(SP_ERROR_NATIVE, "Player class index %i is invalid", class);
	return true;
}

// Common stocks from chdata.inc below

/*
	Common check that says whether or not a client index is occupied.
*/
stock bool:IsValidClient(iClient)
{
	return (0 < iClient && iClient <= MaxClients && IsClientInGame(iClient));
}