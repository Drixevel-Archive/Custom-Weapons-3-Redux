//=============================================================================//
// To Do
// - Custom weapon removal command
// - Admin flag restriction
// - Weapon menu restructuring (slot choice, followed by paginated menu)
// - "You have equipped <weapon>" message on equip
//=============================================================================//
#pragma semicolon 1
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2items>
#include <tf2attributes>

#undef REQUIRE_PLUGIN
#include <cw3>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "Beta 2"

public Plugin:myinfo = {
	name = "Custom Weapons 3: Attributes Module",
	author = "Theray070696",
	description = "Not backwards compatible with existing CW2 attributes. Use the CW2 Legacy or CW2 Attribute Module for those.",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
};

new Handle:fOnAddAttribute;
new Handle:fOnWeaponRemoved;

new plugincount;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	fOnAddAttribute = CreateGlobalForward("CW3_OnAddAttribute", ET_Event, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_Cell);
	fOnWeaponRemoved = CreateGlobalForward("CW3_OnWeaponRemoved", ET_Ignore, Param_Cell, Param_Cell);
	
	CreateNative("CW3_AddAttribute", Native_AddAttribute);
	CreateNative("CW3_ResetAttribute", Native_ResetAttribute);
	
	RegPluginLibrary("cw3-attributes");
	return APLRes_Success;
}

public OnPluginStart()
{
	RegAdminCmd("sm_cw3_addattribute", Command_AddAttribute, ADMFLAG_CHEATS);
	
	HookEvent("player_death", Event_Weapon_Removed);
	HookEvent("post_inventory_application", Event_Weapon_Removed);
}

public OnMapStart()
{
	plugincount = 0;
	new String:FileName[PLATFORM_MAX_PATH], String:Dir[PLATFORM_MAX_PATH], FileType:type;
	BuildPath(Path_SM, Dir, sizeof(Dir), "plugins/cw3/attributes");
	
	if (!DirExists(Dir))
	{
		PrintToServer("[CW3 Attributes] Warning! CW3 Attributes' attribute plugin directory (%s) does not exist! You'll be limited to just stock TF2 attributes, which are boring.", Dir);
	} else
	{
		new Handle:hDir = OpenDirectory(Dir);
		while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
		{
			if (FileType_File != type) continue;
			if (StrContains(FileName, ".smx") == -1) continue;
			Format(FileName, sizeof(FileName), "cw3/attributes/%s", FileName);
			ServerCommand("sm plugins load %s", FileName);
			plugincount++;
		}
		CloseHandle(hDir);
	}
	
	PrintToServer("[CW3 Attributes] CW3 Attributes loaded successfully with %i attribute plugins.", plugincount);
}

public OnPluginEnd()
{
	new String:Dir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Dir, sizeof(Dir), "plugins/cw3/attributes");
	if (!DirExists(Dir))
	{
		PrintToServer("[CW3 Attributes] WARNING! CW3 Attributes' attribute directory (%s) does not exist, so any running attribute plugins will not be unloaded. If you're removing CW3 Attributes (goodbye!) any running attribute plugins will likely still show up as <ERROR> in your server's plugin list.", Dir);
	} else
	{
		new Handle:hDir = OpenDirectory(Dir), String:FileName[PLATFORM_MAX_PATH], FileType:type;
		while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
		{
			if (FileType_File != type) continue;
			if (StrContains(FileName, ".smx") == -1) continue;
			Format(FileName, sizeof(FileName), "cw3/attributes/%s", FileName);
			ServerCommand("sm plugins unload %s", FileName);
		}
		CloseHandle(hDir);
	}
}

public Event_Weapon_Removed(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsValidClient(client))
	{
		for(new i = 0; i < 5; i++)
		{
			Call_StartForward(fOnWeaponRemoved);
			Call_PushCell(i);
			Call_PushCell(client);
			Call_Finish();
		}
	}
}

public CW3_OnWeaponEntCreated(ent, slot, client)
{
	new Handle:hConfig = CW3_GetWeaponConfig(ent);
	
	if(hConfig == INVALID_HANDLE)
	{
		hConfig = CW3_GetClientWeapon(client, slot);
		if(hConfig == INVALID_HANDLE)
		{
			return;
		}
	}
	
	Call_StartForward(fOnWeaponRemoved);
	Call_PushCell(slot);
	Call_PushCell(client);
	Call_Finish();
	
	KvRewind(hConfig);
	
	if(KvJumpToKey(hConfig, "cw3_attributes"))
	{
		KvGotoFirstSubKey(hConfig);
		do
		{
			new String:Att[64], String:szPlugin[64], String:Value[PLATFORM_MAX_PATH + 64];
			KvGetSectionName(hConfig, Att, sizeof(Att));
			KvGetString(hConfig, "plugin", szPlugin, sizeof(szPlugin));
			KvGetString(hConfig, "value", Value, sizeof(Value));
			new bool:whileActive = bool:KvGetNum(hConfig, "while active", _:false);
			
			AddAttribute(slot, client, Att, szPlugin, Value, ent, whileActive);
			
		} while(KvGotoNextKey(hConfig));
	}
}

public Action:Command_AddAttribute(client, args)
{
	if(args < 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_cw3_addattribute <client> <slot> <\"attribute name\"> <\"value\"> <\"plugin\"> - Sets an attribute onto a user's weapon.");
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

	if((target_count = ProcessTargetString(target_arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for(new i = 0; i < target_count; i++)
	{
		AddAttribute(slot, target_list[i], attribute, plugin, value);
	}
	
	return Plugin_Handled;
}

// NATIVE

public Native_AddAttribute(Handle:plugin, args)
{
	new slot = GetNativeCell(1), client = GetNativeCell(2), String:attrib[64], String:atPlugin[64], String:value[PLATFORM_MAX_PATH + 64], bool:whileActive = GetNativeCell(6);
	
	GetNativeString(3, attrib, sizeof(attrib));
	GetNativeString(4, atPlugin, sizeof(atPlugin));
	GetNativeString(5, value, sizeof(value));
	
	if(!NativeCheck_IsClientValid(client)) return false;
	
	return bool:AddAttribute(slot, client, attrib, atPlugin, value, _, whileActive);
}

public Native_ResetAttribute(Handle:plugin, args)
{
	new client = GetNativeCell(1), slot = GetNativeCell(2);
	
	if(!NativeCheck_IsClientValid(client)) return;
	
	Call_StartForward(fOnWeaponRemoved);
	Call_PushCell(slot);
	Call_PushCell(client);
	Call_Finish();
}

// STOCKS

stock Action:AddAttribute(slot, client, String:attrib[], String:plugin[], String:value[], weapon = -1, bool:whileActive = false)
{
	if(!IsValidClient(client)) return Plugin_Continue;
	
	if(StrContains(attrib, "while active", false) != -1) whileActive = true;
	
	if(!StrEqual(plugin, "tf2attributes", false) && !StrEqual(plugin, "tf2attributes.int", false) && !StrEqual(plugin, "tf2items", false))
	{
		new Action:act = Plugin_Continue;
		Call_StartForward(fOnAddAttribute);
		Call_PushCell(slot);
		Call_PushCell(client);
		Call_PushString(attrib);
		Call_PushString(plugin);
		Call_PushString(value);
		Call_PushCell(_:whileActive);
		Call_Finish(act);
		if (!act) PrintToServer("[CW3 Attributes] WARNING! Attribute \"%s\" (value \"%s\" plugin \"%s\") seems to have been ignored by all attribute plugins. It's either an invalid attribute, incorrect plugin, an error occured in the att. plugin, or the att. plugin forgot to return Plugin_Handled.", attrib, value, plugin);
		
		return act;
	} else if(!StrEqual(plugin, "tf2items", false))
	{
		if(weapon == -1)
		{
			weapon = GetPlayerWeaponSlot(client, slot);
			if(weapon == -1)
			{
				return Plugin_Continue;
			}
		}
		
		if(StrEqual(plugin, "tf2attributes", false)) TF2Attrib_SetByName(weapon, attrib, StringToFloat(value));
		else TF2Attrib_SetByName(weapon, attrib, Float:StringToInt(value));
	}
	
	return Plugin_Handled;
}

public NativeCheck_IsClientValid(client)
{
	if (client <= 0 || client > MaxClients) return ThrowNativeError(SP_ERROR_NATIVE, "Client index %i is invalid", client);
	if (!IsClientInGame(client)) return ThrowNativeError(SP_ERROR_NATIVE, "Client %i is not in game", client);
	return true;
}

/*
	Common check that says whether or not a client index is occupied.
*/
stock bool:IsValidClient(iClient)
{
	return (0 < iClient && iClient <= MaxClients && IsClientInGame(iClient));
}