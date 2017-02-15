#pragma semicolon 1
#include <tf2_stocks>
#include <sdkhooks>
#include <cw3>

#define PLUGIN_VERSION "Beta 1"

public Plugin:myinfo = {
	name = "Custom Weapons 3: CW2 Model Application Module",
	author = "MasterOfTheXP (original plugin), Theray070696 (updating CW2 and porting to CW3 module)",
	description = "Legacy module which uses CW2's model application system for CW3.",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
};

new bool:HasCustomViewmodel[2049];
new ViewmodelOfWeapon[2049];
new bool:HasCustomWorldmodel[2049];
new WorldmodelOfWeapon[2049];

new Handle:cvarKillWearablesOnDeath;

// TODO: Delete this once the wearables plugin is released!
// [
new tiedEntity[2049]; // Entity to tie the wearable to.
new wearableOwner[2049]; // Who owns this wearable.
new bool:onlyVisIfActive[2049]; // NOT "visible weapon". If true, this wearable is only shown if the weapon is active.
new bool:hasWearablesTied[2049]; // If true, this entity has (or did have) at least one wearable tied to it.

new bool:g_bSdkStarted = false;
new Handle:g_hSdkEquipWearable;
// ]

public OnPluginStart()
{
	cvarKillWearablesOnDeath = CreateConVar("sm_cw2models_killwearablesondeath", "1", "Removes custom weapon models when the user dies. Recommended unless bad things start happening.");
	
	HookEvent("player_death", Event_Death, EventHookMode_Pre);
	
	TF2_SdkStartup();
}

public CW3_OnWeaponEntCreated(ent, slot, client, bool:wearable, bool:makeActive)
{
	if(wearable) return;
	
	new TFClassType:class = TF2_GetPlayerClass(client);
	new Handle:hConfig = CW3_GetWeaponConfig(ent);
	
	if(hConfig == INVALID_HANDLE)
	{
		return;
	}
	
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

public OnEntityDestroyed(ent)
{
	if (ent <= 0 || ent > 2048) return;
	HasCustomViewmodel[ent] = false;
	ViewmodelOfWeapon[ent] = 0;
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

public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client)
	{
		return Plugin_Continue;
	}

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

	return Plugin_Continue;
}

// STOCKS

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