#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <clientprefs>

#pragma semicolon 1

int g_iMusic[MAXPLAYERS+1] = {1,...};
Menu menuMusic;
Cookie g_cookieMusic;

public Plugin:myinfo =
{
	name = "Music Kits",
	author = "Bone",
	description = "Music Kits Changer",
	version = "1.0.0",
	url = "",
}

public OnPluginStart()
{
	LoadTranslations("musickit.phrases");

	g_cookieMusic = new Cookie("music_kit", "Music Kits Changer", CookieAccess_Private);

	ReadConfig();

	HookEvent("player_spawn", Event_Player_Spawn, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_Disc);
	
	RegConsoleCmd("sm_music", CommandMusic, "Set Music Kit in Game");

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}

}

public OnClientCookiesCached(client)
{
	new String:value[16];
	g_cookieMusic.Get(client, value, sizeof(value));
	if(strlen(value) > 0) g_iMusic[client] = StringToInt(value);

	if (!(0 < client <= MaxClients)) return;
	if (!IsClientInGame(client)) return;
	if( IsFakeClient(client) ) return;
	if(g_iMusic[client] != 1)
	{
		EquipMusic(client);
	}
}

stock bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
    {
        return false;
    }
    return true;
}

public Action Event_Player_Spawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client))
	{
		if(g_iMusic[client] != 1)
		{
			EquipMusic(client);
		}
	}
}

public Action Event_Disc(Event event, char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client)
	{
		g_iMusic[client] = 1;
	}
}

public Action CommandMusic(int client, int args)
{
	menuMusic.Display(client, MENU_TIME_FOREVER);
}

public int MusicMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char musicKitIdStr[20];
			menu.GetItem(selection, musicKitIdStr, sizeof(musicKitIdStr));
			int music = StringToInt(musicKitIdStr);
			g_iMusic[client] = music;
				
			UpdatePlayerData(client, music);
			EquipMusic(client);

			DataPack pack;
			CreateDataTimer(0.5, MusicMenuTimer, pack);
			pack.WriteCell(menu);
			pack.WriteCell(client);
			pack.WriteCell(GetMenuSelectionPosition());
		}
		case MenuAction_DisplayItem:
		{
			if(IsClientInGame(client))
			{
				char info[32];
				char display[64];
				menu.GetItem(selection, info, sizeof(info));
				
				if (StrEqual(info, "1"))
				{
					Format(display, sizeof(display), "%T", "Default", client);
					return RedrawMenuItem(display);
				}
				else if (StrEqual(info, "-1"))
				{
					Format(display, sizeof(display), "%T", "Random", client);
					return RedrawMenuItem(display);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(IsClientInGame(client) && selection == MenuCancel_ExitBack)
			{
				ClientCommand(client, "sm_diy");
			}
		}
	}

	return 0;
}

public Action MusicMenuTimer(Handle timer, DataPack pack)
{
	ResetPack(pack);
	Menu menu = pack.ReadCell();
	int clientIndex = pack.ReadCell();
	int menuSelectionPosition = pack.ReadCell();
	
	if(IsClientInGame(clientIndex))
	{
		menu.DisplayAt(clientIndex, menuSelectionPosition, MENU_TIME_FOREVER);
	}
}

public void EquipMusic(int client)
{
	if(GetEntProp(client, Prop_Send, "m_unMusicID"))
	{
		if (g_iMusic[client] == -1)
		{
			SetEntProp(client, Prop_Send, "m_unMusicID", GetRandomMusic(client));
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusic[client]);
		}
	}
}

void UpdatePlayerData(int client, int index = 1)
{
	char temp[4];
	IntToString(index, temp, sizeof(temp));
	g_cookieMusic.Set(client, temp);
}

public void ReadConfig()
{
	char configPath[PLATFORM_MAX_PATH];

	char code[4];
	char language[32];
	GetLanguageInfo(GetServerLanguage(), code, sizeof(code), language, sizeof(language));
	
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/musickit/musickit_%s.cfg", language);
	
	if(!FileExists(configPath))
	{
		BuildPath(Path_SM, configPath, sizeof(configPath), "configs/musickit/musickit_english.cfg");
	}
	if(!FileExists(configPath))
	{
		SetFailState("Could not find a config file for any languages.");
	}


	KeyValues kv = CreateKeyValues("Musickit");
	FileToKeyValues(kv, configPath);
	
	if (!KvGotoFirstSubKey(kv, false))
	{
		SetFailState("CFG File not found: %s", configPath);
		CloseHandle(kv);
	}
	
	if(menuMusic != null)
	{
		delete menuMusic;
	}
	menuMusic = new Menu(MusicMenuHandler, MENU_ACTIONS_DEFAULT | MenuAction_DisplayItem);
	menuMusic.SetTitle("%T", "MusicMenuTitle", LANG_SERVER);
	menuMusic.AddItem("1", "Default");
	menuMusic.AddItem("-1", "Random");
	if(LibraryExists("diy"))
	{
		menuMusic.ExitBackButton = true;
	}

	
	do {
		char name[255];
		char index[4];
		
		KvGetSectionName(kv, index, sizeof(index));
		KvGetString(kv, NULL_STRING, name, sizeof(name));
		menuMusic.AddItem(index, name);
	} while (KvGotoNextKey(kv, false));
	
	CloseHandle(kv);
}

stock int GetRandomMusic(int client)
{
	int random;
	char output[4];

	random = GetRandomInt(2, menuMusic.ItemCount - 1);
	menuMusic.GetItem(random, output, sizeof(output));
	return StringToInt(output);
}