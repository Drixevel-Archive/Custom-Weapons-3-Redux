#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcemod-misc>
#include <tf2_stocks>
#include <sdkhooks>

#include <tf2items>
#include <tf2attributes>

#include <cw3-core-redux>

bool g_bHasCustomSounds[MAX_ENTITY_LIMIT];

ConVar g_hAllowDownloads;
ConVar g_hDownloadUrl;

public Plugin myinfo =
{
	name = "Custom Weapons 3 - Redux: Sounds",
	author = "MasterOfTheXP (original cw2 developer), Theray070696 (rewrote cw2 into cw3), Keith Warren (Shaders Allen)",
	description = "Applies custom sounds to weapons.",
	version = "1.0.0",
	url = "http://www.shadersallen.com/"
};

public void OnPluginStart()
{
	AddNormalSoundHook(SoundHook);
}

public void OnConfigsExecuted()
{
	g_hAllowDownloads = FindConVar("sv_allowdownload");
	g_hDownloadUrl = FindConVar("sv_downloadurl");

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/customweapons");

	if (!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}

	Handle hDir = OpenDirectory(sPath);

	char FileName[PLATFORM_MAX_PATH];
	FileType type;

	while((ReadDirEntry(hDir, FileName, sizeof(FileName), type)))
	{
		if (FileType_File != type || (StrContains(FileName, ".cfg") == -1 && StrContains(FileName, ".txt") == -1))
		{
			continue;
		}

		Format(FileName, sizeof(FileName), "%s/%s", sPath, FileName);

		Handle hFile = CreateKeyValues("custom_weapon");

		if (!FileToKeyValues(hFile, FileName))
		{
			CloseHandle(hDir);
			continue;
		}

		if (!KvJumpToKey(hFile, "classes"))
		{
			CloseHandle(hDir);
			continue;
		}

		int numClasses;

		for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; class++)
		{
			int value;
			switch(class)
			{
			case TFClass_Scout: value = KvGetNum(hFile, "scout", -1);
			case TFClass_Soldier: value = KvGetNum(hFile, "soldier", -1);
			case TFClass_Pyro: value = KvGetNum(hFile, "pyro", -1);
			case TFClass_DemoMan: value = KvGetNum(hFile, "demoman", -1);
			case TFClass_Heavy: value = KvGetNum(hFile, "heavy", -1);
			case TFClass_Engineer: value = KvGetNum(hFile, "engineer", -1);
			case TFClass_Medic: value = KvGetNum(hFile, "medic", -1);
			case TFClass_Sniper: value = KvGetNum(hFile, "sniper", -1);
			case TFClass_Spy: value = KvGetNum(hFile, "spy", -1);
			}

			if(value == -1)
			{
				continue;
			}

			numClasses++;
		}

		if (!numClasses)
		{
			CloseHandle(hDir);
			continue;
		}

		KvRewind(hFile);

		if (KvJumpToKey(hFile, "sound") && KvGotoFirstSubKey(hFile))
		{
			do
			{
				char section[64];
				KvGetSectionName(hFile, section, sizeof(section));

				if (StrEqual(section, "player", false))
				{
					char replace[PLATFORM_MAX_PATH];
					KvGetString(hFile, "replace", replace, sizeof(replace));

					SuperPrecacheSound(replace);
				}
			}
			while(KvGotoNextKey(hFile));
		}
	}

	CloseHandle(hDir);
}

public void CW3_OnWeaponEntCreated(int weapon, int slot, int client, bool wearable, bool makeActive)
{
	if (wearable)
	{
		return;
	}

	Handle hConfig = CW3_GetWeaponConfig(weapon);

	if (hConfig == null)
	{
		return;
	}

	KvRewind(hConfig);

	if (KvJumpToKey(hConfig, "sound"))
	{
		g_bHasCustomSounds[weapon] = true;
	}
}

public Action SoundHook(int clients[64], int& numClients, char sound[PLATFORM_MAX_PATH], int& entity, int& channel, float& volume, int& level, int& pitch, int& flags)
{
	if (entity > 0 && entity <= MaxClients)
	{
		if (IsClientInGame(entity))
		{
			int client = entity;
			int wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

			if (wep <= 0 || wep > 2048)
			{
				return Plugin_Continue;
			}

			if (!g_bHasCustomSounds[wep])
			{
				return Plugin_Continue;
			}

			Handle hConfig = CW3_GetWeaponConfig(wep);

			if (hConfig == null)
			{
				return Plugin_Continue;
			}

			KvRewind(hConfig);
			KvJumpToKey(hConfig, "sound");
			KvGotoFirstSubKey(hConfig);

			do
			{
				char section[64];
				KvGetSectionName(hConfig, section, sizeof(section));

				if (StrEqual(section, "player", false))
				{
					char find[PLATFORM_MAX_PATH];
					KvGetString(hConfig, "find", find, sizeof(find));

					char replace[PLATFORM_MAX_PATH];
					KvGetString(hConfig, "replace", replace, sizeof(replace));

					if (StrEqual(sound, find, false))
					{
						Format(sound, sizeof(sound), replace);
						EmitSoundToClient(client, sound, _, channel, KvGetNum(hConfig, "level", level), flags, KvGetFloat(hConfig, "volume", volume), KvGetNum(hConfig, "pitch", pitch));
						return Plugin_Changed;
					}
				}
			}
			while(KvGotoNextKey(hConfig));
		}
	}

	return Plugin_Continue;
}

public void OnEntityDestroyed(int entity)
{
	if (entity <= 0 || entity > 2048)
	{
		return;
	}

	g_bHasCustomSounds[entity] = false;
}

stock bool HasFastDownload()
{
	// if for whatever reason these are invalid, its pretty certain the fastdl isn't working
	if (g_hAllowDownloads == null || g_hDownloadUrl == null)
	{
		return false;
	}

	// if sv_allowdownload 0, fastdl is disabled
	if (!GetConVarBool(g_hAllowDownloads))
	{
		return false;
	}

	// if sv_downloadurl isn't set, the fastdl isn't enabled properly
	char strUrl[PLATFORM_MAX_PATH];
	GetConVarString(g_hDownloadUrl, strUrl, sizeof(strUrl));

	if (StrEqual(strUrl, ""))
	{
		return false;
	}

	return true;
}

stock void SuperPrecacheSound(char[] strPath, char[] strPluginName = "")
{
	if (strlen(strPath) == 0)
	{
		return;
	}

	PrecacheSound(strPath, true);

	char strBuffer[PLATFORM_MAX_PATH];
	Format(strBuffer, sizeof(strBuffer), "sound/%s", strPath);
	AddFileToDownloadsTable(strBuffer);

	if (!FileExists(strBuffer) && !FileExists(strBuffer, true))
	{
		if (strlen(strPluginName) == 0)
		{
			LogError("PRECACHE ERROR: Unable to precache sound at '%s'. No fastdl service detected, and file is not on the server.", strPath);
		}
		else
		{
			LogError("PRECACHE ERROR: Unable to precache sound at '%s'. No fastdl service detected, and file is not on the server. It was required by the plugin '%s'", strPath, strPluginName);
		}
	}
}
