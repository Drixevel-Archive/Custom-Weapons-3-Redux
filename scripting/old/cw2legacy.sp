#pragma semicolon 1
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2items>
#include <tf2attributes>
#include <cw3>

#define PLUGIN_VERSION "Beta 1"

public Plugin:myinfo = {
	name = "Custom Weapons 3: CW2 Module",
	author = "MasterOfTheXP (original plugin), 404 (updating CW2), Theray070696 (updating CW2 and porting to CW3 module), and Chdata (updating CW2)",
	description = "Legacy module. Works exactly as CW2 did.",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
};

new Handle:fOnAddAttribute;
new Handle:fOnWeaponGive;

static g_iTheWeaponSlotIWasLastHitBy[MAXPLAYERS + 1] = {-1,...};
static g_bPluginReloaded = false;

new String:LogName[2049][64]; // Look at this gigantic amount of memory wastage
//new String:KillIcon[2049][64];
new String:WeaponName[MAXPLAYERS + 1][5][64];
new String:WeaponDescription[MAXPLAYERS + 1][5][512];

new Handle:ReplacementWeapons[256]; // I don't think people would make more than 256 weapons... And these aren't by entity id, so we don't need 2049.

new Handle:CustomConfig[2049];
new bool:HasCustomViewmodel[2049];
new ViewmodelOfWeapon[2049];
new bool:HasCustomWorldmodel[2049];
new WorldmodelOfWeapon[2049];
new bool:HasCustomSounds[2049];

new Handle:cvarEnabled;
new Handle:cvarKillWearablesOnDeath;

new Handle:g_hAllowDownloads = INVALID_HANDLE;
new Handle:g_hDownloadUrl = INVALID_HANDLE;

new plugincount;

// TODO: Delete this once the wearables plugin is released!
// [
new tiedEntity[2049]; // Entity to tie the wearable to.
new wearableOwner[2049]; // Who owns this wearable.
new bool:onlyVisIfActive[2049]; // NOT "visible weapon". If true, this wearable is only shown if the weapon is active.
new bool:hasWearablesTied[2049]; // If true, this entity has (or did have) at least one wearable tied to it.

new bool:g_bSdkStarted = false;
new Handle:g_hSdkEquipWearable;
// ]

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

	//RegAdminCmd("sm_creload", Command_ReloadSelf, ADMFLAG_ROOT);
	
	cvarEnabled = CreateConVar("sm_customweapons_enable", "1", "Enable Custom Weapons. When set to 0, custom weapons will be removed from all players.");
	cvarKillWearablesOnDeath = CreateConVar("sm_customweapons_killwearablesondeath", "1", "Removes custom weapon models when the user dies. Recommended unless bad things start happening.");
	CreateConVar("sm_customweaponstf_version", PLUGIN_VERSION, "Change anything you want, but please don't change this!");
	
	HookEvent("post_inventory_application", Event_Resupply);
	HookEvent("player_death", Event_Death, EventHookMode_Pre);
	
	AddNormalSoundHook(SoundHook);
	
	CreateTimer(1.0, Timer_OneSecond, _, TIMER_REPEAT);
	
	TF2_SdkStartup();
}

public OnClientPostAdminCheck(client)
{
	g_iTheWeaponSlotIWasLastHitBy[client] = -1;
	
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnMapStart()
{
	for (new i = 1; i <= MaxClients; i++) // MaxClients is only guaranteed to be initialized by the time OnMapStart() fires.
	{
		if (IsClientInGame(i))
		{
			OnClientPostAdminCheck(i);
		}
	}

	g_hAllowDownloads = FindConVar("sv_allowdownload");
	g_hDownloadUrl = FindConVar("sv_downloadurl");
	
	new String:Root[PLATFORM_MAX_PATH];
	plugincount = 0;
	BuildPath(Path_SM, Root, sizeof(Root), "configs/customweapons");
	if (!DirExists(Root)) SetFailState("Custom Weapons' weapon directory (%s) does not exist! Would you kindly install it?", Root);
	new Handle:hDir = OpenDirectory(Root), String:FileName[PLATFORM_MAX_PATH], FileType:type;
	while ((ReadDirEntry(hDir, FileName, sizeof(FileName), type)))
	{
		if (FileType_File != type) continue;
		Format(FileName, sizeof(FileName), "%s/%s", Root, FileName);
		new Handle:hFile = CreateKeyValues("Whyisthisneeded");
		if (!FileToKeyValues(hFile, FileName))
		{
			PrintToServer("[Custom Weapons] WARNING! Something seems to have gone wrong with opening %s. It won't be added to the weapons list.", FileName);
			CloseHandle(hDir);
			continue;
		}
		if (!KvJumpToKey(hFile, "classes"))
		{
			PrintToServer("[Custom Weapons] WARNING! Weapon config %s does not have any classes marked as being able to use the weapon.", FileName);
			CloseHandle(hDir);
			continue;
		}
		new numClasses;
		for (new TFClassType:class = TFClass_Scout; class <= TFClass_Engineer; class++)
		{
			new value;
			switch (class)
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
			if (value == -1) continue;
			numClasses++;
		}
		if (!numClasses)
		{
			PrintToServer("[Custom Weapons] WARNING! Weapon config %s does not have any classes marked as being able to use the weapon.", FileName);
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
		
		new String:viewModelName[PLATFORM_MAX_PATH];
		
		if (KvJumpToKey(hFile, "viewmodel"))
		{
			KvGetString(hFile, "modelname", viewModelName, sizeof(viewModelName));
			if (StrContains(viewModelName, "models/", false)) Format(viewModelName, sizeof(viewModelName), "models/%s", viewModelName);
			if (-1 == StrContains(viewModelName, ".mdl", false)) Format(viewModelName, sizeof(viewModelName), "%s.mdl", viewModelName);
			if (strlen(viewModelName) && FileExists(viewModelName, true))
			{
				decl String:modelfile[PLATFORM_MAX_PATH + 4];
				decl String:strLine[PLATFORM_MAX_PATH];
				Format(modelfile, sizeof(modelfile), "%s.dep", viewModelName);
				new Handle:hStream = INVALID_HANDLE;
				if (FileExists(modelfile))
				{
					// Open stream, if possible
					hStream = OpenFile(modelfile, "r");
					if (hStream == INVALID_HANDLE)
					{
						return;
					}

					while(!IsEndOfFile(hStream))
					{
						// Try to read line. If EOF has been hit, exit.
						ReadFileLine(hStream, strLine, sizeof(strLine));

						// Cleanup line
						CleanString(strLine);

						// If file exists...
						if (!FileExists(strLine, true))
						{
							continue;
						}

						// Precache depending on type, and add to download table
						if (StrContains(strLine, ".vmt", false) != -1)		PrecacheDecal(strLine, true);
						else if (StrContains(strLine, ".mdl", false) != -1)	PrecacheModel(strLine, true);
						else if (StrContains(strLine, ".pcf", false) != -1)	PrecacheGeneric(strLine, true);
						AddFileToDownloadsTable(strLine);
					}

					// Close file
					CloseHandle(hStream);
				} else
				{
					SuperPrecacheModel(viewModelName);
				}
			}
		}
		
		KvRewind(hFile);
		if (KvJumpToKey(hFile, "worldmodel"))
		{
			new String:worldModelName[PLATFORM_MAX_PATH];
			KvGetString(hFile, "modelname", worldModelName, sizeof(worldModelName));
			
			if (!StrEqual(worldModelName, viewModelName, false))
			{
				if (StrContains(worldModelName, "models/", false)) Format(worldModelName, sizeof(worldModelName), "models/%s", worldModelName);
				if (-1 == StrContains(worldModelName, ".mdl", false)) Format(worldModelName, sizeof(worldModelName), "%s.mdl", worldModelName);
				if (strlen(worldModelName) && FileExists(worldModelName, true))
				{
					decl String:modelfile[PLATFORM_MAX_PATH + 4];
					decl String:strLine[PLATFORM_MAX_PATH];
					Format(modelfile, sizeof(modelfile), "%s.dep", worldModelName);
					new Handle:hStream = INVALID_HANDLE;
					if (FileExists(modelfile))
					{
						// Open stream, if possible
						hStream = OpenFile(modelfile, "r");
						if (hStream == INVALID_HANDLE)
						{
							return;
						}
	
						while(!IsEndOfFile(hStream))
						{
							// Try to read line. If EOF has been hit, exit.
							ReadFileLine(hStream, strLine, sizeof(strLine));
	
							// Cleanup line
							CleanString(strLine);
	
							// If file exists...
							if (!FileExists(strLine, true))
							{
								continue;
							}
	
							// Precache depending on type, and add to download table
							if (StrContains(strLine, ".vmt", false) != -1)		PrecacheDecal(strLine, true);
							else if (StrContains(strLine, ".mdl", false) != -1)	PrecacheModel(strLine, true);
							else if (StrContains(strLine, ".pcf", false) != -1)	PrecacheGeneric(strLine, true);
							AddFileToDownloadsTable(strLine);
						}
	
						// Close file
						CloseHandle(hStream);
					} else
					{
						SuperPrecacheModel(worldModelName);
					}
				}
			}
		}
	}
	
	GetReplacementWeapons();
	
	CloseHandle(hDir);
	
	new String:Dir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Dir, sizeof(Dir), "plugins/customweaponstf");
	if (!DirExists(Dir)) PrintToServer("[Custom Weapons] Warning! Custom Weapons' plugin directory (%s) does not exist! You'll be limited to just stock TF2 attributes, which are boring.", Root);
	else {
	
	hDir = OpenDirectory(Dir);
	while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
	{
		if (FileType_File != type) continue;
		if (StrContains(FileName, ".smx") == -1) continue;
		Format(FileName, sizeof(FileName), "customweaponstf/%s", FileName);
		ServerCommand("sm plugins load %s", FileName);
		plugincount++;
	}
	CloseHandle(hDir); }
	
	PrintToServer("[Custom Weapons] Custom Weapons loaded successfully with %i plugins.", plugincount);
}

public OnPluginEnd()
{
	if (!g_bPluginReloaded) // Reloaded unexpectedly?! -> else reloaded via the /creload command
	{
		// Note: This will play if you manually use sm plugins reload customweaponstf instead of /c reload
		PrintToChatAll("[SM] Custom Weapons 2 has unexpectedly been unloaded! Functionality disabled.");
	}

	new String:Dir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Dir, sizeof(Dir), "plugins/customweaponstf");
	if (!DirExists(Dir)) PrintToServer("[Custom Weapons] WARNING! Custom Weapons' plugin directory (%s) does not exist, so any running attribute plugins will not be unloaded. If you're removing Custom Weapons (goodbye!) any running attribute plugins will likely still show up as <ERROR> in your server's plugin list.", Dir);
	else {
		new Handle:hDir = OpenDirectory(Dir), String:FileName[PLATFORM_MAX_PATH], FileType:type;
		while (ReadDirEntry(hDir, FileName, sizeof(FileName), type))
		{
			if (FileType_File != type) continue;
			if (StrContains(FileName, ".smx") == -1) continue;
			Format(FileName, sizeof(FileName), "customweaponstf/%s", FileName);
			ServerCommand("sm plugins unload %s", FileName);
		}
		CloseHandle(hDir); }
}

public CW3_OnWeaponEntCreated(ent, slot, client, bool:wearable, bool:makeActive)
{
	new TFClassType:class = TF2_GetPlayerClass(client);
	
	new Handle:hConfig = CW3_GetWeaponConfig(ent);
	
	if(hConfig == INVALID_HANDLE)
	{
		return;
	}
	
	KvRewind(hConfig);
	new String:name[96], String:logName[64];
	
	KvGetSectionName(hConfig, name, sizeof(name));
	KvGetString(hConfig, "logname", logName, sizeof(logName));
	
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
	
	if(!wearable)
	{
		KvRewind(hConfig);
		if (KvJumpToKey(hConfig, "viewmodel"))
		{
			new String:ModelName[PLATFORM_MAX_PATH];
			KvGetString(hConfig, "modelname", ModelName, sizeof(ModelName));
			if (StrContains(ModelName, "models/", false)) Format(ModelName, sizeof(ModelName), "models/%s", ModelName);
			if (-1 == StrContains(ModelName, ".mdl", false)) Format(ModelName, sizeof(ModelName), "%s.mdl", ModelName);
			if (strlen(ModelName) && FileExists(ModelName, true))
			{
				/*new vmModel = PrecacheModel(ModelName, true);
				
				SetEntProp(ent, Prop_Send, "m_nModelIndex", vmModel);*/
				
				new vm = EquipWearable(client, ModelName, true, ent, true);
				if (vm > -1) ViewmodelOfWeapon[vm] = ent;
				new String:arms[PLATFORM_MAX_PATH];
				switch (class)
				{
					case TFClass_Scout: Format(arms, sizeof(arms), "models/weapons/c_models/c_scout_arms.mdl");
					case TFClass_Soldier: Format(arms, sizeof(arms), "models/weapons/c_models/c_soldier_arms.mdl");
					case TFClass_Pyro: Format(arms, sizeof(arms), "models/weapons/c_models/c_pyro_arms.mdl");
					case TFClass_DemoMan: Format(arms, sizeof(arms), "models/weapons/c_models/c_demo_arms.mdl");
					case TFClass_Heavy: Format(arms, sizeof(arms), "models/weapons/c_models/c_heavy_arms.mdl");
					case TFClass_Engineer: Format(arms, sizeof(arms), "models/weapons/c_models/c_engineer_arms.mdl");
					case TFClass_Medic: Format(arms, sizeof(arms), "models/weapons/c_models/c_medic_arms.mdl");
					case TFClass_Sniper: Format(arms, sizeof(arms), "models/weapons/c_models/c_sniper_arms.mdl");
					case TFClass_Spy: Format(arms, sizeof(arms), "models/weapons/c_models/c_spy_arms.mdl");
				}
				if (strlen(arms) && FileExists(arms, true))
				{
					PrecacheModel(arms, true);
					new armsVm = EquipWearable(client, arms, true, ent, true);
					if (armsVm > -1) ViewmodelOfWeapon[armsVm] = ent;
				}
				HasCustomViewmodel[ent] = true;
				new attachment = KvGetNum(hConfig, "attachment", -1);
				if (attachment > -1)
				{
					SetEntProp(vm, Prop_Send, "m_fEffects", 0);
					SetEntProp(vm, Prop_Send, "m_iParentAttachment", attachment);
					new Float:offs[3], Float:angOffs[3], Float:flScale;
					KvGetVector(hConfig, "pos", offs);
					KvGetVector(hConfig, "ang", angOffs);
					flScale = KvGetFloat(hConfig, "scale", 1.0);
					SetEntPropVector(vm, Prop_Send, "m_vecOrigin", offs);
					SetEntPropVector(vm, Prop_Send, "m_angRotation", angOffs);
					if (flScale != 1.0) SetEntPropFloat(vm, Prop_Send, "m_flModelScale", flScale);
				}
			}
		}
		
		KvRewind(hConfig);
		if (KvJumpToKey(hConfig, "worldmodel"))
		{
			new String:ModelName[PLATFORM_MAX_PATH];
			KvGetString(hConfig, "modelname", ModelName, sizeof(ModelName));
			if (StrContains(ModelName, "models/", false)) Format(ModelName, sizeof(ModelName), "models/%s", ModelName);
			if (-1 == StrContains(ModelName, ".mdl", false)) Format(ModelName, sizeof(ModelName), "%s.mdl", ModelName);
			if (strlen(ModelName) && FileExists(ModelName, true))
			{
				new wr = EquipWearable(client, ModelName, false, ent, true);
				if (wr > -1) WorldmodelOfWeapon[wr] = ent;
				HasCustomWorldmodel[ent] = true;
				
				/*new model = PrecacheModel(ModelName, true);
				SetEntProp(ent, Prop_Send, "m_iWorldModelIndex", model);
				SetEntProp(ent, Prop_Send, "m_nModelIndexOverrides", model, _, 0);*/
				
				new attachment = KvGetNum(hConfig, "attachment", -1);
				if (attachment > -1)
				{
					SetEntProp(wr, Prop_Send, "m_fEffects", 0);
					SetEntProp(wr, Prop_Send, "m_iParentAttachment", attachment);
					new Float:offs[3], Float:angOffs[3], Float:scale;
					KvGetVector(hConfig, "pos", offs);
					KvGetVector(hConfig, "ang", angOffs);
					scale = KvGetFloat(hConfig, "scale", 1.0);
					SetEntPropVector(wr, Prop_Send, "m_vecOrigin", offs);
					SetEntPropVector(wr, Prop_Send, "m_angRotation", angOffs);
					if (scale != 1.0) SetEntPropFloat(wr, Prop_Send, "m_flModelScale", scale);
				}
				new replace = KvGetNum(hConfig, "replace", 1);
				if (replace == 1)
				{
					SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
					SetEntityRenderColor(ent, 0, 0, 0, 0);
				}
				else if (replace == 2)
				{
					SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 0.0);
				}
			}
		}
	}
	
	KvRewind(hConfig);
	if(KvJumpToKey(hConfig, "sound"))
		HasCustomSounds[ent] = true;
	
	strcopy(LogName[ent], 64, logName);
	
	CustomConfig[ent] = hConfig;
	
	new Action:act = Plugin_Continue;
	Call_StartForward(fOnWeaponGive);
	Call_PushCell(ent);
	Call_PushCell(client);
	Call_Finish(act);
}

public CW3_OnWeaponSwitch(client, Wep)
{
	if (!IsValidEntity(Wep)) return;
	if (HasCustomViewmodel[Wep])
		SetEntProp(GetEntPropEnt(client, Prop_Send, "m_hViewModel"), Prop_Send, "m_fEffects", 32);
	
	// TODO: Delete this once the wearables plugin is released!
	new i = -1;
	while ((i = FindEntityByClassname(i, "tf_wearable*")) != -1)
	{
		if (!onlyVisIfActive[i]) continue;
		if (client != wearableOwner[i]) continue;
		new effects = GetEntProp(i, Prop_Send, "m_fEffects");
		if (Wep == tiedEntity[i]) SetEntProp(i, Prop_Send, "m_fEffects", effects & ~32);
		else SetEntProp(i, Prop_Send, "m_fEffects", effects |= 32);
	}
}

public Action:SoundHook(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (entity > 0 && entity <= MaxClients)
	{
		if (IsClientInGame(entity))
		{
			new client = entity;
			new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (wep <= 0 || wep > 2048) return Plugin_Continue;
			if (!HasCustomSounds[wep]) return Plugin_Continue;
			new Handle:hConfig = CustomConfig[wep];
			KvRewind(hConfig);
			KvJumpToKey(hConfig, "sound");
			KvGotoFirstSubKey(hConfig);
			do {
				new String:section[64];
				KvGetSectionName(hConfig, section, sizeof(section));
				if (StrEqual(section, "player", false))
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
			} while (KvGotoNextKey(hConfig));
		}
	}
	return Plugin_Continue;
}

public OnEntityDestroyed(ent)
{
	if (ent <= 0 || ent > 2048) return;
	LogName[ent][0] = '\0';
	CustomConfig[ent] = INVALID_HANDLE;
	HasCustomViewmodel[ent] = false;
	ViewmodelOfWeapon[ent] = 0;
	HasCustomSounds[ent] = false;
	HasCustomWorldmodel[ent] = false;
	WorldmodelOfWeapon[ent] = 0;
	
	// TODO: Delete this once the wearables plugin is released!
	if (ent <= 0 || ent > 2048) return;
	if (hasWearablesTied[ent])
	{	
		new i = -1;
		while ((i = FindEntityByClassname(i, "tf_wearable*")) != -1)
		{
			if (ent != tiedEntity[i]) continue;
			if (IsValidClient(wearableOwner[ent]))
			{
				TF2_RemoveWearable(wearableOwner[ent], i);
			}
			else
			{
				AcceptEntityInput(i, "Kill"); // This can cause graphical glitches
			}
		}
		hasWearablesTied[ent] = false;
	}
	tiedEntity[ent] = 0;
	wearableOwner[ent] = 0;
	onlyVisIfActive[ent] = false;
}

public Action:Event_Resupply(Handle:event, const String:name[], bool:dontBroadcast)
{
	new uid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(uid);
	if (!client) return;
	if (!GetConVarBool(cvarEnabled)) return;
	
	CreateTimer(0.01, Timer_ReplaceWeapons, client);
}

bool:GetValueFromConfig(iClient, iSlot, const String:szKey[], String:szValue[], iszValueSize)
{
	if (!IsValidClient(iClient) || iSlot > 4)
    {
        return false;
    }

	new Handle:hConfig = CW3_GetClientWeapon(iClient, iSlot);
	if (hConfig == INVALID_HANDLE)
	{
		return false;
	}

	KvRewind(hConfig);

	if (StrEqual(szKey, "name"))
	{
		return KvGetSectionName(hConfig, szValue, iszValueSize);
	}
	else
	{
		KvGetString(hConfig, szKey, szValue, iszValueSize);
	}

	return false;
}

public Action:OnTakeDamage(iVictim, &iAtker, &iInflictor, &Float:flDamage, &iDmgType, &iWeapon, Float:vDmgForce[3], Float:vDmgPos[3], iDmgCustom)
{
	if (0 < iAtker && iAtker <= MaxClients)
	{
		g_iTheWeaponSlotIWasLastHitBy[iVictim] = GetSlotFromPlayerWeapon(iAtker, iWeapon);
	}
	return Plugin_Continue;
}

// Displays a menu describing what weapon the victim was killed by
DisplayDeathMenu(iKiller, iVictim, TFClassType:iAtkClass, iAtkSlot)
{
	if (iAtkSlot == -1 || iAtkClass == TFClass_Unknown || iKiller == iVictim || !IsValidClient(iKiller)) // In event_death, iVictim will surely be valid at this point
	{
		return;
	}

	new Handle:hMenu = CreateMenu(MenuHandler_Null);
	SetMenuTitle(hMenu, "%s\n \n%s", WeaponName[iKiller][iAtkSlot], WeaponDescription[iKiller][iAtkSlot]);
	AddMenuItem(hMenu, "exit", "Close");
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, false);
	DisplayMenu(hMenu, iVictim, 4); // 4 second lasting menu
}

public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client)
	{
		return Plugin_Continue;
	}

	new iKiller = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (iKiller && IsValidClient(iKiller) && g_iTheWeaponSlotIWasLastHitBy[client] != -1) // TODO: Test this vs environmental deaths and whatnot.
	{
		decl String:szWeaponLogClassname[64];
		GetValueFromConfig(iKiller, g_iTheWeaponSlotIWasLastHitBy[client], "logname", szWeaponLogClassname, sizeof(szWeaponLogClassname));
		if (szWeaponLogClassname[0] != '\0')
		{
			SetEventString(event, "weapon_logclassname", szWeaponLogClassname);
		}

		// SetEventString(event, "weapon", szKill_Icon); // Not a recommended method, as things like sniper rifles can have multiple kill icons
	}

	g_iTheWeaponSlotIWasLastHitBy[client] = -1;

	if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER) return Plugin_Continue;
	
	if (!GetConVarBool(cvarKillWearablesOnDeath)) return Plugin_Continue;

	new i = -1;
	while ((i = FindEntityByClassname(i, "tf_wearable*")) != -1)
	{
		if (!tiedEntity[i]) continue;
		if (client != GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity")) continue;
		if (GetEntProp(i, Prop_Send, "m_bDisguiseWearable")) continue;
		TF2_RemoveWearable(client, i);
	}
	
	if(IsValidClient(iKiller))
	{
		DisplayDeathMenu(iKiller, client, TF2_GetPlayerClass(iKiller), g_iTheWeaponSlotIWasLastHitBy[client]);
	}

	return Plugin_Continue;
}

public MenuHandler_Null(Handle:hMenu, MenuAction:iAction, iClient, iParam)
{
    if (iAction == MenuAction_End)
    {
        CloseHandle(hMenu);
    }
}

public Action:Timer_ReplaceWeapons(Handle:timer, any:client)
{
	if (!client) return;
	if (!GetConVarBool(cvarEnabled)) return;
	if (!IsPlayerAlive(client)) return;
	
	new Handle:hWeapon = INVALID_HANDLE;
	new weapon = -1;
	new iItemDefinitionIndex = -1;
	new bool:replacedWeapon = false;
	
	for(int j = 0; j < 7; j++)
	{
		replacedWeapon = false;
		
		weapon = GetPlayerWeaponSlot(client, j);
		
		if(weapon != -1 && !CW3_IsCustom(weapon))
		{
			for (int i = 0; i < 256; i++)
			{
				if(ReplacementWeapons[i] != INVALID_HANDLE && !replacedWeapon)
				{
					hWeapon = ReplacementWeapons[i];
					
					iItemDefinitionIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"); // This should always be above 0 if we get this far.
					
					new String:buffer[128];
					
					KvRewind(hWeapon);
					KvGetString(hWeapon, "replacement", buffer, sizeof(buffer));
					
					if(buffer[0] == '\0')
					{
						KvRewind(hWeapon);
						KvGetString(hWeapon, "replace", buffer, sizeof(buffer));
					}
					
					new String:replaceIDs[10][9];
					ExplodeString(buffer, " ", replaceIDs, sizeof(replaceIDs), sizeof(replaceIDs[]));
					
					for(int k = 0; k < 10; k++)
					{
						if(replaceIDs[k][0] != '\0' && StringToInt(replaceIDs[k]) >= 0 && !replacedWeapon)
						{
							if(StringToInt(replaceIDs[k]) == iItemDefinitionIndex)
							{
								CW3_EquipItem(client, hWeapon, false);
								
								replacedWeapon = true;
							}
						}
					}
				}
			}
		}
	}
}

public Action:Timer_OneSecond(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		if (IsFakeClient(client)) continue; // DON'T show hint text to bot players.
		if (!IsPlayerAlive(client)) continue;
		if (GetEntProp(client, Prop_Send, "m_nNumHealers") > 0)
		{
			new String:customHealers[256], numCustomHealers;
			for (new i = 1; i <= MaxClients; i++)
			{
				if (client == i) continue;
				if (!IsClientInGame(i)) continue;
				if (!IsPlayerAlive(i)) continue;
				if (client != GetMediGunPatient(i)) continue;
				new medigun = GetPlayerWeaponSlot(i, 1);
				if (!CW3_IsCustom(medigun)) continue;
				KvRewind(CustomConfig[medigun]);
				new String:name[64];
				KvGetSectionName(CustomConfig[medigun], name, sizeof(name));
				Format(customHealers, sizeof(customHealers), "%s%s%N is using: %s", customHealers, numCustomHealers++ ? "\n" : "", i, name);
			}
			if (numCustomHealers) PrintHintText(client, customHealers);
		}
	}
}

public Action:Command_ReloadSelf(iClient, iArgC)
{
	g_bPluginReloaded = true;
	ReplyToCommand(iClient, "[SM] The plugin has been reloaded.");
	//PrintToChatAll("[SM] All custom weapons have been reset, the plugin reloaded!");
	ServerCommand("sm plugins reload customweaponstf");
	return Plugin_Handled;
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
	
	if (!NativeCheck_IsClientValid(client)) return false;
	if (weapon == -1) return false;
	
	return bool:AddAttribute(weapon, client, attrib, atPlugin, value);
}

public Native_GetClientWeapon(Handle:plugin, args)
{
	new client = GetNativeCell(1), slot = GetNativeCell(2);
	if (!NativeCheck_IsClientValid(client)) return (_:INVALID_HANDLE);
	
	new wep = GetPlayerWeaponSlot(client, slot);
	return CW3_IsCustom(wep) ? (_:CustomConfig[wep]) : (_:INVALID_HANDLE);
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
	
	new String:name[namelen];
	KvRewind(CustomConfig[wep]);
	KvGetSectionName(CustomConfig[wep], name, namelen);
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

// Code copied from weapon spawning code, better to do this in a stock so we can call it without adding ~30 lines to this file.
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

stock SuperPrecacheModel(String:strModel[], bool:bRequiredOnServer = false, bool:bMdlOnly = false)
{
	decl String:strBase[PLATFORM_MAX_PATH];
	decl String:strPath[PLATFORM_MAX_PATH];
	Format(strBase, sizeof(strBase), strModel);
	SplitString(strBase, ".mdl", strBase, sizeof(strBase));
	
	if(!bMdlOnly)
	{
		Format(strPath, sizeof(strPath), "%s.phy", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
		
		Format(strPath, sizeof(strPath), "%s.sw.vtx", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
		
		Format(strPath, sizeof(strPath), "%s.vvd", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
		
		Format(strPath, sizeof(strPath), "%s.dx80.vtx", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
		
		Format(strPath, sizeof(strPath), "%s.dx90.vtx", strBase);
		if(FileExists(strPath)) AddFileToDownloadsTable(strPath);
	}
	
	AddFileToDownloadsTable(strModel);
	
	if(HasFastDownload())
	{
		if(bRequiredOnServer && !FileExists(strModel) && !FileExists(strModel, true))
		{
			LogError("PRECACHE ERROR: Unable to precache REQUIRED model '%s'. File is not on the server.", strModel);
		}
	}
	
	return PrecacheModel(strModel, true);
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

stock GetReplacementWeapons()
{
	new weaponID = 0;
	
	new String:Root[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Root, sizeof(Root), "configs/customweapons");
	new Handle:hDir = OpenDirectory(Root), String:FileName[PLATFORM_MAX_PATH], FileType:type;
	
	while ((ReadDirEntry(hDir, FileName, sizeof(FileName), type)))
	{
		if (FileType_File != type) continue;
		Format(FileName, sizeof(FileName), "%s/%s", Root, FileName);
		new Handle:hFile = CreateKeyValues("Whyisthisneeded");
		if (!FileToKeyValues(hFile, FileName))
		{
			continue; // We don't need to log an error, as one will have already been printed from the map load/config reloads.
		}
		
		KvRewind(hFile);
		if(KvJumpToKey(hFile, "replacement") || KvJumpToKey(hFile, "replace"))
		{
			ReplacementWeapons[weaponID] = hFile; // Save the weapon config, we will use it to change default weapons.
			
			weaponID++; // We only want this incrementing when there is a valid weapon.
		}
	}
	
	CloseHandle(hDir);
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

stock SetAmmo_Weapon(weapon, newAmmo)
{
	new owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner == -1) return;
	new iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
	new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
	SetEntData(owner, iAmmoTable+iOffset, newAmmo, 4, true);
}

stock SetClip_Weapon(weapon, newClip)
{
	new iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
	SetEntData(weapon, iAmmoTable, newClip, 4, true);
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

stock RemoveAllCustomWeapons() // const String:reason[]
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			TF2_RegeneratePlayer(client);
		}

		/*new bool:removed, bool:removedSlot[5];
		for (new slot = 0; slot <= 4; slot++)
		{
			new wep = GetPlayerWeaponSlot(client, slot);
			if (wep == -1) continue;
			if (!IsCustom[wep]) continue;
			TF2_RemoveWeaponSlot(client, slot);
			removed = true;
		}
		if (!removed) continue;
		for (new slot = 0; slot <= 4; slot++)
		{
			if (removedSlot[slot]) continue;
			ClientCommand(client, "slot%i", slot+1);
			break;
		}*/
		//if (removed) PrintToChat(client, reason);
	}
}

stock GetMediGunPatient(client)
{
	new wep = GetPlayerWeaponSlot(client, 1);
	if (wep == -1 || wep != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")) return -1;
	new String:class[15];
	GetEdictClassname(wep, class, sizeof(class));
	if (StrContains(class, "tf_weapon_med", false)) return -1;
	return GetEntProp(wep, Prop_Send, "m_bHealing") ? GetEntPropEnt(wep, Prop_Send, "m_hHealingTarget") : -1;
}

// Kinda bad stock name...
stock bool:DoesClientAlreadyHaveCustomWeapon(client, Handle:weapon)
{
	new i = -1;
	while ((i = FindEntityByClassname(i, "tf_weapon*")) != -1)
	{
		if (!IsCustom[i]) continue;
		if (CustomConfig[i] != weapon) continue;
		if (client != GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity")) continue;
		if (GetEntProp(i, Prop_Send, "m_bDisguiseWeapon")) continue;
		return true;
	}
	
	i = -1;
	while ((i = FindEntityByClassname(i, "tf_wearable*")) != -1)
	{
		if (!IsCustom[i]) continue;
		if (CustomConfig[i] != weapon) continue;
		if (client != GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity")) continue;
		if (GetEntProp(i, Prop_Send, "m_bDisguiseWearable")) continue;
		return true;
	}
	
	return false;
}

stock IsArenaActive()
	return FindEntityByClassname(-1, "tf_logic_arena") != -1;

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






// Wearable crap, ripped out of my bad private wearables plugin
// TODO: Create a nice public plugin to make this into a native which all plugins can use.

stock EquipWearable(client, String:Mdl[], bool:vm, weapon = 0, bool:visactive = true)
{ // ^ bad name probably
	new wearable = CreateWearable(client, Mdl, vm);
	if (wearable == -1) return -1;
	wearableOwner[wearable] = client;
	if (weapon > MaxClients)
	{
		tiedEntity[wearable] = weapon;
		hasWearablesTied[weapon] = true;
		onlyVisIfActive[wearable] = visactive;
		
		new effects = GetEntProp(wearable, Prop_Send, "m_fEffects");
		if (weapon == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")) SetEntProp(wearable, Prop_Send, "m_fEffects", effects & ~32);
		else SetEntProp(wearable, Prop_Send, "m_fEffects", effects |= 32);
	}
	return wearable;
}

stock CreateWearable(client, String:model[], bool:vm) // Randomizer code :3
{
	new ent = CreateEntityByName(vm ? "tf_wearable_vm" : "tf_wearable");
	if (!IsValidEntity(ent)) return -1;
	SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel(model));
	SetEntProp(ent, Prop_Send, "m_fEffects", 129);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(ent);
	SetVariantString("!activator");
	ActivateEntity(ent);
	TF2_EquipWearable(client, ent); // urg
	return ent;
}

// *sigh*
stock TF2_EquipWearable(client, Ent)
{
	if (g_bSdkStarted == false || g_hSdkEquipWearable == INVALID_HANDLE)
	{
		TF2_SdkStartup();
		LogMessage("Error: Can't call EquipWearable, SDK functions not loaded! If it continues to fail, reload plugin or restart server. Make sure your gamedata is intact!");
	}
	else
	{
		SDKCall(g_hSdkEquipWearable, client, Ent);
	}
}

stock CleanString(String:strBuffer[])
{
	// Cleanup any illegal characters
	new Length = strlen(strBuffer);
	for (new iPos=0; iPos<Length; iPos++)
	{
		switch(strBuffer[iPos])
		{
			case '\r': strBuffer[iPos] = ' ';
			case '\n': strBuffer[iPos] = ' ';
			case '\t': strBuffer[iPos] = ' ';
		}
	}

	// Trim string
	TrimString(strBuffer);
}

stock bool:TF2_SdkStartup()
{
	new Handle:hGameConf = LoadGameConfigFile("tf2items.randomizer");
	if (hGameConf == INVALID_HANDLE)
	{
		LogMessage("Couldn't load SDK functions (GiveWeapon). Make sure tf2items.randomizer.txt is in your gamedata folder! Restart server if you want wearable weapons.");
		return false;
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();

	CloseHandle(hGameConf);
	g_bSdkStarted = true;
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

/*
	Is a valid entity, but guaranteed not to be the world, or a player.

	"Entity, Non-Player"
*/
stock bool:IsValidEnp(iEnt)
{
	return iEnt > MaxClients && IsValidEntity(iEnt);
}
