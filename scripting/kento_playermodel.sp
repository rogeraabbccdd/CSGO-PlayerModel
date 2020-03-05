#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <cstrike>
#include <n_arms_fix>

#pragma newdecls required

#define MAX_SKINS_COUNT 1000

Handle sc_cookie_t;
Handle sc_cookie_ct;

int TSelected[MAXPLAYERS + 1];
int CTSelected[MAXPLAYERS + 1];

int TSkins_Count;
int CTSkins_Count;
char TerrorSkin[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];
char TerrorArms[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];
char TerrorName[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];
char CTerrorSkin[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];
char CTerrorArms[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];
char CTerrorName[MAX_SKINS_COUNT][PLATFORM_MAX_PATH];

Handle t_skins_menu = INVALID_HANDLE;
Handle ct_skins_menu = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "Player models",
	author = "Kento",
	description = "Player models.",
	version = "1.0",
	url = "http://steamcommunity.com/id/kentomatoryoshika/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_skins", CMD_Skins);
	RegConsoleCmd("sm_skin", CMD_Skins);
	RegConsoleCmd("sm_model", CMD_Skins);
	RegConsoleCmd("sm_models", CMD_Skins);

	sc_cookie_t = RegClientCookie("player_model_t", "Player model T", CookieAccess_Private);
	sc_cookie_ct = RegClientCookie("player_model_ct", "Player model CT", CookieAccess_Private);

	for(int i = 1; i <= MaxClients; i++)
	{ 
		if(IsValidClient(i) && !IsFakeClient(i) && !AreClientCookiesCached(i))	OnClientCookiesCached(i);
	}
}

public void OnClientPutInServer(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))	OnClientCookiesCached(client);
}

public void OnClientCookiesCached(int client)
{
	if(!IsValidClient(client) && IsFakeClient(client))	return;
	
	TSelected[client] = -1;
	CTSelected[client] = -1;

	char scookie[64];
	GetClientCookie(client, sc_cookie_t, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		TSelected[client] = FindModelIDByName(scookie, 1);
		if(TSelected[client] < 0)	SetClientCookie(client, sc_cookie_t, "");
	}
	GetClientCookie(client, sc_cookie_ct, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		CTSelected[client] = FindModelIDByName(scookie, 2);
		if(CTSelected[client] < 0)	SetClientCookie(client, sc_cookie_ct, "");
	}
}

public void OnMapStart() 
{
	InitDownloadsList();
	PrepareMenus();
	LoadConfig();
}

void PrepareMenus()
{
  // Firstly zero out amount of avalible skins
  TSkins_Count = CTSkins_Count = 0;

  // Then safely close menu handles
  if (t_skins_menu != INVALID_HANDLE)
  {
    CloseHandle(t_skins_menu);
    t_skins_menu = INVALID_HANDLE;
  }
  if (ct_skins_menu != INVALID_HANDLE)
  {
    CloseHandle(ct_skins_menu);
    ct_skins_menu = INVALID_HANDLE;
  }

  // Create specified menus depends on client teams
  t_skins_menu  = CreateMenu(MenuHandler_ChooseSkin_T, MenuAction_Select);
  ct_skins_menu = CreateMenu(MenuHandler_ChooseSkin_CT, MenuAction_Select);

  // And dont forget to set the menu's titles
  SetMenuTitle(t_skins_menu,  "Choose your Terrorist skin:");
  SetMenuTitle(ct_skins_menu, "Choose your Counter-Terrorist skin:");
}

public int MenuHandler_ChooseSkin_T(Menu menu, MenuAction action, int client,int param)
{
  // Called when player pressed something in a menu
  if (action == MenuAction_Select)
  {
    // Don't use any other value than 10, otherwise you may crash clients and a server
    char skin_id[10];
    GetMenuItem(menu, param, skin_id, sizeof(skin_id));

    // Get skin number
    int skin = StringToInt(skin_id, sizeof(skin_id));

    // Correct. So lets save the selected skin
    TSelected[client] = skin;
    SetClientCookie(client, sc_cookie_t, TerrorName[skin]);

    if(skin > -1 && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_T)
		{	
			SetEntityModel(client, TerrorSkin[skin]);
			SetEntPropString(client, Prop_Send, "m_szArmsModel", TerrorArms[skin]);
		}
  }
}

public int MenuHandler_ChooseSkin_CT(Menu menu, MenuAction action, int client,int param)
{
  // Called when player pressed something in a menu
  if (action == MenuAction_Select)
  {
    // Don't use any other value than 10, otherwise you may crash clients and a server
    char skin_id[10];
    GetMenuItem(menu, param, skin_id, sizeof(skin_id));

    // Get skin number
    int skin = StringToInt(skin_id, sizeof(skin_id));

    // Correct. So lets save the selected skin
    CTSelected[client] = skin;
    SetClientCookie(client, sc_cookie_ct, CTerrorName[skin]);

    if(skin > -1 && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_CT)
		{	
			SetEntityModel(client, CTerrorSkin[skin]);
			SetEntPropString(client, Prop_Send, "m_szArmsModel", CTerrorArms[skin]);
		}
  }
}

void LoadConfig()
{
	char Configfile[1024]
	BuildPath(Path_SM, Configfile, sizeof(Configfile), "configs/skins/skins.cfg");
	
	if(!FileExists(Configfile))
		SetFailState("Can not find config file \"%s\"!", Configfile);
	
	
	KeyValues kv = CreateKeyValues("Models");
	kv.ImportFromFile(Configfile);
	
	// Get 'Terrorists' section
	if (kv.JumpToKey("Terrorists"))
	{
		char section[PLATFORM_MAX_PATH]; 
		char skin[PLATFORM_MAX_PATH];
		char arms[PLATFORM_MAX_PATH];
		char skin_id[3];	

		// Sets the current position in the KeyValues tree to the first sub key
		kv.GotoFirstSubKey();
		
		AddMenuItem(t_skins_menu, "-1", "Random");
		TSkins_Count = 0;

		do
		{
			// Get current section name
			kv.GetSectionName(section, sizeof(section));

			// Also make sure we've got 'skin' and 'arms' sections
			if (kv.GetString("skin", skin, sizeof(skin)))
			{
				kv.GetString("arms", arms, sizeof(arms));				
				if (StrEqual(arms, ""))
				{
					arms = "models/weapons/t_arms_leet.mdl";
					PrecacheModel("models/weapons/t_arms_leet.mdl", true);
				} 
			
				// Copy the full path of skin from config and save it
				strcopy(TerrorSkin[TSkins_Count], sizeof(TerrorSkin[]), skin);
				strcopy(TerrorArms[TSkins_Count], sizeof(TerrorArms[]), arms);
				strcopy(TerrorName[TSkins_Count], sizeof(TerrorName[]), section);

				Format(skin_id, sizeof(skin_id), "%d", TSkins_Count++);

				AddMenuItem(t_skins_menu, skin_id, section);

				// Precache every model (before mapchange) to prevent client crashes
				if (! IsModelPrecached(skin)) PrecacheModel(skin, true);
				
				// Precache arms too. Those will not crash client, but arms will not be shown at all
				if (! IsModelPrecached(arms)) PrecacheModel(arms, true);
			}
			else LogError("Player model for \"%s\" is incorrect!", section);
		}

		// Because we need to process all keys
		while (kv.GotoNextKey());
	}
	else SetFailState("Fatal error: Missing \"Terrorists\" section!");

	// Get back to the top
	kv.Rewind();

	// Check CT config right now
	if (kv.JumpToKey("Counter-Terrorists"))
	{
		char section[PLATFORM_MAX_PATH]; 
		char skin[PLATFORM_MAX_PATH];
		char arms[PLATFORM_MAX_PATH];
		char skin_id[3];
		
		kv.GotoFirstSubKey();
		
		AddMenuItem(ct_skins_menu, "-1", "Random");
		TSkins_Count = 0;

		// Lets begin
		do
		{
			kv.GetSectionName(section, sizeof(section));

			if (kv.GetString("skin", skin, sizeof(skin)))
			{
				kv.GetString("arms", arms, sizeof(arms));			
				if (StrEqual(arms, "")) 
				{
					arms = "models/weapons/ct_arms_st6.mdl";
					PrecacheModel("models/weapons/ct_arms_st6.mdl", true);
				}
				
				strcopy(CTerrorSkin[CTSkins_Count], sizeof(CTerrorSkin[]), skin);
				strcopy(CTerrorArms[CTSkins_Count], sizeof(CTerrorArms[]), arms);
				strcopy(CTerrorName[CTSkins_Count], sizeof(CTerrorName[]), section);

				// Calculate number of avalible CT skins
				Format(skin_id, sizeof(skin_id), "%d", CTSkins_Count++);

				// Add every section as a menu item
				AddMenuItem(ct_skins_menu, skin_id, section);

				// Precache every model (before mapchange) to prevent client crashes
				if (! IsModelPrecached(skin)) PrecacheModel(skin, true);
				
				// Precache arms too. Those will not crash client, but arms will not be shown at all
				if (! IsModelPrecached(arms)) PrecacheModel(arms, true);
			}

			// Something is wrong
			else LogError("Player model for \"%s\" is incorrect!", section);
		}
		while (kv.GotoNextKey());
	}
}

public void N_ArmsFix_OnClientReady(int client)
{
	if (IsValidClient(client))
	{
		switch (GetClientTeam(client))
		{
			case CS_TEAM_T:
			{
				if(IsFakeClient(client) || TSelected[client] < 0)
				{
					int rand = GetRandomInt(0, TSkins_Count-1);
					SetEntPropString(client, Prop_Send, "m_szArmsModel", TerrorArms[ rand ]);
					SetEntityModel(client, TerrorSkin[ rand ] );
				}
				else 
				{
					if(TSelected[client] > -1) 
					{
						SetEntPropString(client, Prop_Send, "m_szArmsModel", TerrorArms[ TSelected[client] ]);
						SetEntityModel(client, TerrorSkin[ TSelected[client] ]);
					}
				}	
			}
			case CS_TEAM_CT:
			{
				if(IsFakeClient(client) || CTSelected[client] < 0)
				{
					int rand = GetRandomInt(0, CTSkins_Count-1);
					SetEntPropString(client, Prop_Send, "m_szArmsModel", CTerrorArms[ rand ]);
					SetEntityModel(client, CTerrorSkin[ rand ]);
				}
				else 
				{
					if(CTSelected[client] > -1) 
					{
						SetEntPropString(client, Prop_Send, "m_szArmsModel", CTerrorArms[ CTSelected[client] ]);
						SetEntityModel(client, CTerrorSkin[ CTSelected[client] ]);
					}
				}	
			}
		}
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

public Action CMD_Skins(int client, int args)
{
	// Once again make sure that client is valid
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		switch (GetClientTeam(client))
		{
			case CS_TEAM_T:  if (t_skins_menu  != INVALID_HANDLE) DisplayMenu(t_skins_menu,  client, 20);
			case CS_TEAM_CT: if (ct_skins_menu != INVALID_HANDLE) DisplayMenu(ct_skins_menu, client, 20);
		}
	}
}

void InitDownloadsList()
{
	char Configfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Configfile, sizeof(Configfile), "configs/skins/downloads.ini");
	
	if (!FileExists(Configfile))
	{
		LogError("Unable to open download file \"%s\"!", Configfile);
		return;
	}
	
	char line[PLATFORM_MAX_PATH];
	Handle fileHandle = OpenFile(Configfile,"r");

	while(!IsEndOfFile(fileHandle) && ReadFileLine(fileHandle, line, sizeof(line)))
	{
		// Remove whitespaces and empty lines
		TrimString(line);
		ReplaceString(line, sizeof(line), " ", "", false);
	
		// Skip comments
		if (line[0] != '/')
		{
			if (FileExists(line, true))
			{
				AddFileToDownloadsTable(line);
				if(StrContains(line, ".mdl", false))	PrecacheModel(line, true);
			}
		}
	}
	CloseHandle(fileHandle);
}

int FindModelIDByName(char [] name, int team)
{
	int id = -1;
	// T
	if(team == 1)
	{
		for (int i = 0; i < TSkins_Count; i++)
		{
			if(StrEqual(TerrorName[i], name)) id = i;
		}		
	}
	// CT
	else if(team == 2)
	{
		for (int i = 0; i < CTSkins_Count; i++)
		{
			if(StrEqual(CTerrorName[i], name)) id = i;
		}		
	}
	return id;
}