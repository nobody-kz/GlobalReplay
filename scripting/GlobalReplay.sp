#include <sourcemod>
#include <gokz/core>
#include <gokz/global>
#include <gokz/replays>
#include <json>
#include <SteamWorks>

// TODO: bonuses

#pragma newdecls required
#pragma tabsize 0
#pragma semicolon 1

#define BATCH_SIZE 100

char gC_CurrentMap[64];
static int selectedReplayMode[MAXPLAYERS + 1];

methodmap API3Record < APIRecord {
    property int ReplayId {
		public get() { return this.GetInt("replay_id"); }
	}
}

public Plugin myinfo = {
	name = "Global Replay",
	author = "nobody",
	description = "Fetches and plays global records",
	version = "0.0.1",
	url = "https://kiwisclub.co/"
};

static void UpdateCurrentMap() {
	GetCurrentMapDisplayName(gC_CurrentMap, sizeof(gC_CurrentMap));
}

public void OnPluginStart() {
	LoadTranslations("gokz-replays.phrases");
	UpdateCurrentMap();
    RegConsoleCmd("sm_greplay", CommandGlobalReplay, "[KZ] Open the global replay loading menu.");
	RegConsoleCmd("sm_globalreplay", CommandGlobalReplay, "[KZ] Open the global replay loading menu.");
}

public void OnMapStart() {
	UpdateCurrentMap();
}

public Action CommandGlobalReplay(int client, int args)
{
	DisplayReplayModeMenu(client);

	return Plugin_Handled;
}

void DisplayReplayModeMenu(int client)
{	
	Menu menu = new Menu(MenuHandler_ReplayMode);
	menu.SetTitle("%T", "Replay Menu (Mode) - Title", client, gC_CurrentMap);
	GOKZ_MenuAddModeItems(client, menu, false);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ReplayMode(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		selectedReplayMode[param1] = param2;
		DisplayReplayMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

static void DisplayReplayMenu(int client) {
	char modeStr[32];
	GOKZ_GL_GetModeString(selectedReplayMode[client], modeStr, sizeof(modeStr));
	
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientUserId(client));
	
	GlobalAPI_GetRecordsTop(
		DisplayReplayMenuCallback,
		dp,
		DEFAULT_STRING,
		DEFAULT_STRING,
		DEFAULT_INT,
		gC_CurrentMap,
		128,
		0, // TODO: pass in stage number
		modeStr,
		DEFAULT_BOOL,
		DEFAULT_STRING,
		0,
		BATCH_SIZE
	);
}

static void DisplayReplayMenuCallback(JSON_Object top, GlobalAPIRequestData request, DataPack dp)
{
	dp.Reset();
	int client = GetClientOfUserId(dp.ReadCell());
	delete dp;

	if (request.Failure)
	{
		LogError("Failed to get top records with Global API.");
		return;
	}
	if (!top.IsArray)
	{
		LogError("GlobalAPI returned a malformed response while looking up the top records.");
		return;
	}
	if (!IsValidClient(client))
	{
		return;
	}

	Menu menu = new Menu(MenuHandler_Replay);
	menu.SetTitle("%T", "Replay Menu - Title", client, gC_CurrentMap, gC_ModeNames[selectedReplayMode[client]]);
	if (ReplayMenuAddItems(menu, top) > 0)
	{
		menu.Pagination = 5;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		GOKZ_PrintToChat(client, true, "%t", "No Replays Found (Mode)", gC_ModeNames[selectedReplayMode[client]]);
		GOKZ_PlayErrorSound(client);
		DisplayReplayModeMenu(client);
	}
}

// Returns the number of replay menu items added
static int ReplayMenuAddItems(Menu menu, JSON_Object records)
{
	int replaysAdded = 0;
	char playerName[MAX_NAME_LENGTH];
	char display[128];
	char replayIdString[8];
	
	for (int i = 0; i < records.Length; i++)
	{
		API3Record record = view_as<API3Record>(records.GetObjectIndexed(i));
		
		if (record.ReplayId != 0) {
			record.GetPlayerName(playerName, sizeof(playerName));
			
			FormatEx(display, sizeof(display), "#%-2d   %11s   %s", i + 1, GOKZ_FormatTime(record.Time), playerName);

			IntToString(record.ReplayId, replayIdString, sizeof(replayIdString));
			menu.AddItem(replayIdString, display, ITEMDRAW_DEFAULT);

			replaysAdded++;
		}
	}

	records.Cleanup();
	
	return replaysAdded;
}

stock void buildReplayPath(int replayId, char[] replayPath, int replayPathLength) {
	BuildPath(Path_SM, replayPath, replayPathLength,
			"%s/%s/%d.%s",
			RP_DIRECTORY_RUNS, gC_CurrentMap, replayId, RP_FILE_EXTENSION);
}

public int MenuHandler_Replay(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char replayIdString[8];
		menu.GetItem(param2, replayIdString, sizeof(replayIdString));
		int replayId = StringToInt(replayIdString);

		char replayPath[PLATFORM_MAX_PATH];
		buildReplayPath(replayId, replayPath, sizeof(replayPath));
		
		if (FileExists(replayPath)) {
			GOKZ_RP_LoadJumpReplay(param1, replayPath);
		}
		else {
			char url[100];
			Format(url, sizeof(url), "https://kztimerglobal.com/api/v2.0/records/replay/%d", replayId);

			DataPack dp = new DataPack();
			dp.WriteCell(GetClientUserId(param1));
			dp.WriteCell(replayId);

			Handle handle = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
			SteamWorks_SetHTTPRequestContextValue(handle, dp);
			SteamWorks_SetHTTPCallbacks(handle, MenuHandler_ReplayCompleted);
			SteamWorks_SendHTTPRequest(handle);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		DisplayReplayModeMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuHandler_ReplayCompleted(Handle HTTPRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack dp) {
	dp.Reset();
	int client = GetClientOfUserId(dp.ReadCell());
	int replayId = dp.ReadCell();
	delete dp;

	if (!bFailure && bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK) {
		char replayPath[PLATFORM_MAX_PATH];
		buildReplayPath(replayId, replayPath, sizeof(replayPath));

        SteamWorks_WriteHTTPResponseBodyToFile(HTTPRequest, replayPath);

		GOKZ_RP_LoadJumpReplay(client, replayPath);
    }
	else {
		PrintToServer("GlobalReplay: Could not fetch global replay %d with error code %d.", replayId, eStatusCode);
		GOKZ_PrintToChatAll(true, "Could not fetch global replay %d with error code %d. Contact administrator.", replayId, eStatusCode);
	}
}
