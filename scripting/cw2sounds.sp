#pragma semicolon 1
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2items>
#include <tf2attributes>
#include <cw3>

#define PLUGIN_VERSION "Beta 2"

public Plugin:myinfo = {
	name = "Custom Weapons 3: CW2 Sound Module",
	author = "MasterOfTheXP (original plugin), 404 (updating CW2), Theray070696 (updating CW2 and porting to CW3 module), and Chdata (updating CW2)",
	description = "Legacy module which uses CW2's sound system for CW3.",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
};

new bool:HasCustomSounds[2049];

new Handle:g_hAllowDownloads = INVALID_HANDLE;
new Handle:g_hDownloadUrl = INVALID_HANDLE;

public OnPluginStart()
{
	AddNormalSoundHook(SoundHook);
}

public OnMapStart()
{
	g_hAllowDownloads = FindConVar("sv_allowdownload");
	g_hDownloadUrl = FindConVar("sv_downloadurl");
	
	new String:Root[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Root, sizeof(Root), "configs/customweapons");
	new Handle:hDir = OpenDirectory(Root), String:FileName[PLATFORM_MAX_PATH], FileType:type;
	while((ReadDirEntry(hDir, FileName, sizeof(FileName), type)))
	{
		if(FileType_File != type) continue;
		Format(FileName, sizeof(FileName), "%s/%s", Root, FileName);
		new Handle:hFile = CreateKeyValues("Whyisthisneeded");
		if(!FileToKeyValues(hFile, FileName))
		{
			CloseHandle(hDir);
			continue;
		}
		if(!KvJumpToKey(hFile, "classes"))
		{
			CloseHandle(hDir);
			continue;
		}
		new numClasses;
		for(new TFClassType:class = TFClass_Scout; class <= TFClass_Engineer; class++)
		{
			new value;
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
			if(value == -1) continue;
			numClasses++;
		}
		if(!numClasses)
		{
			CloseHandle(hDir);
			continue;
		}
		
		KvRewind(hFile);
		if(KvJumpToKey(hFile, "sound"))
		{
			KvGotoFirstSubKey(hFile);
			do
			{
				new String:section[64];
				KvGetSectionName(hFile, section, sizeof(section));
				if(StrEqual(section, "player", false))
				{
					new String:replace[PLATFORM_MAX_PATH];
					KvGetString(hFile, "replace", replace, sizeof(replace));
					SuperPrecacheSound(replace);
				}
			} while(KvGotoNextKey(hFile));
		}
	}
	
	CloseHandle(hDir);
}

public CW3_OnWeaponEntCreated(ent, slot, client, bool:wearable, bool:makeActive)
{
	if(wearable) return;
	
	new Handle:hConfig = CW3_GetWeaponConfig(ent);
	
	if(hConfig == INVALID_HANDLE)
	{
		return;
	}
	
	KvRewind(hConfig);
	if(KvJumpToKey(hConfig, "sound"))
		HasCustomSounds[ent] = true;
}

public Action:SoundHook(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if(entity > 0 && entity <= MaxClients)
	{
		if(IsClientInGame(entity))
		{
			new client = entity;
			new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (wep <= 0 || wep > 2048) return Plugin_Continue;
			if (!HasCustomSounds[wep]) return Plugin_Continue;
			new Handle:hConfig = CW3_GetWeaponConfig(wep);
			
			if(hConfig == INVALID_HANDLE) return Plugin_Continue;
			
			KvRewind(hConfig);
			KvJumpToKey(hConfig, "sound");
			KvGotoFirstSubKey(hConfig);
			do
			{
				new String:section[64];
				KvGetSectionName(hConfig, section, sizeof(section));
				if(StrEqual(section, "player", false))
				{
					new String:find[PLATFORM_MAX_PATH], String:replace[PLATFORM_MAX_PATH];
					KvGetString(hConfig, "find", find, sizeof(find));
					KvGetString(hConfig, "replace", replace, sizeof(replace));
					if (StrEqual(sound, find, false))
					{
						Format(sound, sizeof(sound), replace);
						EmitSoundToClient(client, sound, _, channel, KvGetNum(hConfig, "level", level), flags, KvGetFloat(hConfig, "volume", volume), KvGetNum(hConfig, "pitch", pitch));
						return Plugin_Changed;
					}
				}
			} while(KvGotoNextKey(hConfig));
		}
	}
	return Plugin_Continue;
}

public OnEntityDestroyed(ent)
{
	if(ent <= 0 || ent > 2048) return;
	HasCustomSounds[ent] = false;
}

stock bool:HasFastDownload()
{
	// if for whatever reason these are invalid, its pretty certain the fastdl isn't working
	if(g_hAllowDownloads == INVALID_HANDLE || g_hDownloadUrl == INVALID_HANDLE)
	{
		return false;
	}
	
	// if sv_allowdownload 0, fastdl is disabled
	if(!GetConVarBool(g_hAllowDownloads))
	{
		return false;
	}
	
	// if sv_downloadurl isn't set, the fastdl isn't enabled properly
	decl String:strUrl[PLATFORM_MAX_PATH];
	GetConVarString(g_hDownloadUrl, strUrl, sizeof(strUrl));
	if(StrEqual(strUrl, ""))
	{
		return false;
	}
	
	return true;
}

stock SuperPrecacheSound(String:strPath[], String:strPluginName[] = "")
{
	if(strlen(strPath) == 0) return;
	
	PrecacheSound(strPath, true);
	decl String:strBuffer[PLATFORM_MAX_PATH];
	Format(strBuffer, sizeof(strBuffer), "sound/%s", strPath);
	AddFileToDownloadsTable(strBuffer);
	
	if(!FileExists(strBuffer) && !FileExists(strBuffer, true))
	{
		if(StrEqual(strPluginName, "")) LogError("PRECACHE ERROR: Unable to precache sound at '%s'. No fastdl service detected, and file is not on the server.", strPath);
		else LogError("PRECACHE ERROR: Unable to precache sound at '%s'. No fastdl service detected, and file is not on the server. It was required by the plugin '%s'", strPath, strPluginName);
	}
}