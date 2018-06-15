#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcemod-misc>
#include <tf2_stocks>
#include <sdkhooks>

#include <tf2items>
#include <tf2attributes>

#include <cw3-core-redux>
#include <cw3-attributes-redux>

Handle fOnAddAttribute;
Handle fOnWeaponRemoved;

public Plugin myinfo =
{
	name = "Custom Weapons 3 - Redux: Attributes",
	author = "MasterOfTheXP (original cw2 developer), Theray070696 (rewrote cw2 into cw3), Keith Warren (Shaders Allen)",
	description = "Applies default or custom attributes to the custom weapons.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("cw3-attributes-redux");

	CreateNative("CW3_AddAttribute", Native_AddAttribute);
	CreateNative("CW3_ResetAttribute", Native_ResetAttribute);

	fOnAddAttribute = CreateGlobalForward("CW3_OnAddAttribute", ET_Event, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_Cell);
	fOnWeaponRemoved = CreateGlobalForward("CW3_OnWeaponRemoved", ET_Ignore, Param_Cell, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_cw3_addattribute", Command_AddAttribute, ADMFLAG_CHEATS);

	HookEvent("player_death", Event_RemoveWeapon);
	HookEvent("post_inventory_application", Event_RemoveWeapon);
}

public void Event_RemoveWeapon(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidClient(client))
	{
		for (int i = 0; i < MAXSLOTS; i++)
		{
			Call_StartForward(fOnWeaponRemoved);
			Call_PushCell(i);
			Call_PushCell(client);
			Call_Finish();
		}
	}
}

public void CW3_OnWeaponEntCreated(int weapon, int slot, int client)
{
	Handle hConfig = CW3_GetWeaponConfig(weapon);

	if (hConfig == null)
	{
		hConfig = CW3_GetClientWeapon(client, slot);

		if(hConfig == null)
		{
			return;
		}
	}

	Call_StartForward(fOnWeaponRemoved);
	Call_PushCell(slot);
	Call_PushCell(client);
	Call_Finish();

	KvRewind(hConfig);

	if ((KvJumpToKey(hConfig, "attributes") || KvJumpToKey(hConfig, "cw3_attributes")) && KvGotoFirstSubKey(hConfig))
	{
		do
		{
			char Att[64];
			KvGetSectionName(hConfig, Att, sizeof(Att));

			char szPlugin[64];
			KvGetString(hConfig, "plugin", szPlugin, sizeof(szPlugin));

			char Value[PLATFORM_MAX_PATH + 64];
			KvGetString(hConfig, "value", Value, sizeof(Value));

			bool whileActive = view_as<bool>(KvGetNum(hConfig, "while active", view_as<int>(false)));

			AddAttribute(slot, client, Att, szPlugin, Value, weapon, whileActive);

		}
		while(KvGotoNextKey(hConfig));
	}
}

public Action Command_AddAttribute(int client, int args)
{
	if (args < 3)
	{
		char sCommand[64];
		GetCmdArg(0, sCommand, sizeof(sCommand));

		ReplyToCommand(client, "[SM] Usage: %s <client> <slot> <\"attribute name\"> <\"value\"> <\"plugin\"> - Sets an attribute onto a user's weapon.", sCommand);
		return Plugin_Handled;
	}

	char target_arg[MAX_TARGET_LENGTH];
	GetCmdArg(1, target_arg, sizeof(target_arg));

	char strslot[12];
	GetCmdArg(2, strslot, sizeof(strslot));

	char attribute[64];
	GetCmdArg(3, attribute, sizeof(attribute));

	char value[64];
	GetCmdArg(4, value, sizeof(value));

	char plugin[64];
	GetCmdArg(5, plugin, sizeof(plugin));

	int slot = StringToInt(strslot);

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(target_arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		AddAttribute(slot, target_list[i], attribute, plugin, value);
	}

	return Plugin_Handled;
}

public int Native_AddAttribute(Handle plugin, int numParams)
{
	int slot = GetNativeCell(1);
	int client = GetNativeCell(2);
	bool whileActive = GetNativeCell(6);

	char attrib[64];
	GetNativeString(3, attrib, sizeof(attrib));

	char atPlugin[64];
	GetNativeString(4, atPlugin, sizeof(atPlugin));

	char value[PLATFORM_MAX_PATH + 64];
	GetNativeString(5, value, sizeof(value));

	if (client <= 0 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %i is invalid", client);
	}

	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %i is not in game", client);
	}

	return view_as<bool>(AddAttribute(slot, client, attrib, atPlugin, value, _, whileActive));
}

public int Native_ResetAttribute(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);

	if (client <= 0 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %i is invalid", client);
	}

	if (!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %i is not in game", client);
	}

	Call_StartForward(fOnWeaponRemoved);
	Call_PushCell(slot);
	Call_PushCell(client);
	Call_Finish();

	return true;
}

Action AddAttribute(int slot, int client, char[] attrib, char[] plugin, char[] value, int weapon = -1, bool whileActive = false)
{
	if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	if (StrContains(attrib, "while active", false) != -1)
	{
		whileActive = true;
	}

	if (StrEqual(plugin, "tf2attributes", false) || StrEqual(plugin, "tf2-attributes", false) || StrEqual(plugin, "tf2attributes.int", false) || StrEqual(plugin, "tf2items", false))
	{
		if (!IsValidEntity(weapon))
		{
			weapon = GetPlayerWeaponSlot(client, slot);

			if (!IsValidEntity(weapon))
			{
				return Plugin_Continue;
			}
		}

		TF2Attrib_SetByName(weapon, attrib, StringToFloat(value));
		return Plugin_Handled;
	}

	Call_StartForward(fOnAddAttribute);
	Call_PushCell(slot);
	Call_PushCell(client);
	Call_PushString(attrib);
	Call_PushString(plugin);
	Call_PushString(value);
	Call_PushCell(whileActive);

	Action act = Plugin_Continue;
	Call_Finish(act);

	if (!act)
	{
		PrintToServer("[CW3 Attributes] WARNING! Attribute \"%s\" (value \"%s\" plugin \"%s\") seems to have been ignored by all attribute plugins. It's either an invalid attribute, incorrect plugin, an error occured in the att. plugin, or the att. plugin forgot to return Plugin_Handled.", attrib, value, plugin);
	}

	return act;
}
