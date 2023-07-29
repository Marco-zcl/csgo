#include <clientprefs>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <sourcemod>

#include "include/c5.inc"
#include "include/c5_pug.inc"
#include "include/restorecvars.inc"
#include "c5/util.sp"

#define ALIAS_LENGTH 64
#define COMMAND_LENGTH 64
#define LIVE_TIMER_INTERVAL 0.3

#pragma semicolon 1
#pragma newdecls required

/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/** ConVar handles **/
ConVar g_AdminFlagCvar;
ConVar g_AnnounceCountdownCvar;
ConVar g_AutoRandomizeCaptainsCvar;
ConVar g_AutoSetupCvar;
ConVar g_DemoNameFormatCvar;
ConVar g_DemoTimeFormatCvar;
ConVar g_DoVoteForKnifeRoundDecisionCvar;
ConVar g_EchoReadyMessagesCvar;
ConVar g_ExcludedMaps;
ConVar g_ForceDefaultsCvar;
ConVar g_LiveCfgCvar;
ConVar g_MapVoteTimeCvar;
ConVar g_MutualUnpauseCvar;
ConVar g_PauseCountLimitCvar;
ConVar g_PauseTimeCvar;
ConVar g_PausingEnabledCvar;
ConVar g_PostGameCfgCvar;
ConVar g_RandomizeMapOrderCvar;
ConVar g_RandomOptionInMapVoteCvar;
ConVar g_SetupEnabledCvar;
ConVar g_SnakeCaptainsCvar;
ConVar g_StartDelayCvar;
ConVar g_WarmupCfgCvar;
ConVar g_WarmupMoneyOnSpawnCvar;

/** Setup menu options **/
bool g_DisplayMapType = true;
bool g_DisplayTeamType = true;
bool g_DisplayKnifeRound = true;
bool g_DisplayTeamSize = true;
bool g_DisplayRecordDemo = true;
bool g_DisplayMapChange = false;

/** Setup info **/
int g_Leader = -1;
ArrayList g_MapList;
ArrayList g_PastMaps;
bool g_ForceEnded = false;

/** Specific choices made when setting up **/
int g_PlayersPerTeam = 5;
TeamType g_TeamType = TeamType_Captains;
MapType g_MapType = MapType_Vote;
bool g_RecordGameOption = false;
bool g_DoKnifeRound = false;

/** Other important variables about the state of the game **/
TeamBalancerFunction g_BalancerFunction = INVALID_FUNCTION;
Handle g_BalancerFunctionPlugin = INVALID_HANDLE;

GameState g_GameState = GameState_None;
bool g_SwitchingMaps = false;  // if we're in the middle of a map change
bool g_OnDecidedMap = false;   // whether we're on the map that is going to be used

bool g_Recording = true;
char g_DemoFileName[PLATFORM_MAX_PATH];
bool g_LiveTimerRunning = false;
int g_CountDownTicks = 0;
bool g_ForceStartSignal = false;

#define CAPTAIN_COMMAND_HINT_TIME 15
#define START_COMMAND_HINT_TIME 15
#define READY_COMMAND_HINT_TIME 19
int g_LastCaptainHintTime = 0;
int g_LastReadyHintTime = 0;

/** Pause information **/
bool g_ctUnpaused = false;
bool g_tUnpaused = false;
int g_PauseCount[4];

/** Chat aliases loaded **/
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;
ArrayList g_ChatAliasesModes;

/** Permissions **/
StringMap g_PermissionsMap;
ArrayList g_Commands;  // just a list of all known pugsetup commands

/** Map-choosing variables **/
ArrayList g_MapVetoed;
ArrayList g_MapVotePool;

/** Data about team selections **/
int g_capt1 = -1;
int g_capt2 = -1;
int g_Teams[MAXPLAYERS + 1];
bool g_Ready[MAXPLAYERS + 1];
bool g_PlayerAtStart[MAXPLAYERS + 1];


/** Auth variables **/
ArrayList g_auths;

/** Clan tag data **/
#define CLANTAG_LENGTH 16
bool g_SavedClanTag[MAXPLAYERS + 1];
char g_ClanTag[MAXPLAYERS + 1][CLANTAG_LENGTH];

/** Knife round data **/
int g_KnifeWinner = -1;
enum KnifeDecision {
  KnifeDecision_None,
  KnifeDecision_Stay,
  KnifeDecision_Swap,
};
KnifeDecision g_KnifeRoundVotes[MAXPLAYERS + 1];
int g_KnifeNumVotesNeeded = 0;

/** Forwards **/
Handle g_OnForceEnd = INVALID_HANDLE;
Handle g_hOnGoingLive = INVALID_HANDLE;
Handle g_hOnHelpCommand = INVALID_HANDLE;
Handle g_hOnKnifeRoundDecision = INVALID_HANDLE;
Handle g_hOnLive = INVALID_HANDLE;
Handle g_hOnLiveCfg = INVALID_HANDLE;
Handle g_hOnLiveCheck = INVALID_HANDLE;
Handle g_hOnMatchOver = INVALID_HANDLE;
Handle g_hOnNotPicked = INVALID_HANDLE;
Handle g_hOnPermissionCheck = INVALID_HANDLE;
Handle g_hOnPlayerAddedToCaptainMenu = INVALID_HANDLE;
Handle g_hOnPostGameCfg = INVALID_HANDLE;
Handle g_hOnReady = INVALID_HANDLE;
Handle g_hOnReadyToStart = INVALID_HANDLE;
Handle g_hOnSetup = INVALID_HANDLE;
Handle g_hOnSetupMenuOpen = INVALID_HANDLE;
Handle g_hOnSetupMenuSelect = INVALID_HANDLE;
Handle g_hOnStartRecording = INVALID_HANDLE;
Handle g_hOnStateChange = INVALID_HANDLE;
Handle g_hOnUnready = INVALID_HANDLE;
Handle g_hOnWarmupCfg = INVALID_HANDLE;

#include "c5_pug/captainpickmenus.sp"
#include "c5_pug/configs.sp"
#include "c5_pug/consolecommands.sp"
#include "c5_pug/kniferounds.sp"
#include "c5_pug/leadermenus.sp"
#include "c5_pug/livebegin.sp"
#include "c5_pug/maps.sp"
#include "c5_pug/mapveto.sp"
#include "c5_pug/mapvote.sp"
#include "c5_pug/friendlyfirevote.sp"
#include "c5_pug/overtime.sp"
#include "c5_pug/natives.sp"
#include "c5_pug/pause.sp"
#include "c5_pug/setupmenus.sp"

/***********************
 *                     *
 * Sourcemod forwards  *
 *                     *
 ***********************/

public Plugin myinfo = {
    name = "C5: PUG",
    author = "Bone, splewis",
    description = "Tools for setting up pugs",
    version = "1.0",
	  url = "https://bonetm.github.io/"
};

public void OnPluginStart() {
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");
  LoadTranslations("c5.pug.phrases");

  /** ConVars **/
  g_AdminFlagCvar = CreateConVar(
      "sm_c5_pug_admin_flag", "b",
      "Admin flag to mark players as having elevated permissions - e.g. can always pause,setup,end the game, etc.");
  g_AnnounceCountdownCvar =
      CreateConVar("sm_c5_pug_announce_countdown_timer", "1",
                   "Whether to announce how long the countdown has left before the lo3 begins.");
  g_AutoRandomizeCaptainsCvar = CreateConVar(
      "sm_c5_pug_auto_randomize_captains", "0",
      "When games are using captains, should they be automatically randomized once? Note you can still manually set them or use .rand/!rand to redo the randomization.");
  g_AutoSetupCvar =
      CreateConVar("sm_c5_pug_autosetup", "1",
                   "Whether a pug is automatically setup using the default setup options or not.");
  g_DemoNameFormatCvar = CreateConVar(
      "sm_c5_pug_demo_name_format", "c5_pug_{TIME}_{MAP}",
      "Naming scheme for demos. You may use {MAP}, {TIME}, and {TEAMSIZE}. Make sure there are no spaces or colons in this.");
  g_DemoTimeFormatCvar = CreateConVar(
      "sm_c5_pug_time_format", "%Y-%m-%d_%H%M",
      "Time format to use when creating demo file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");
  g_DoVoteForKnifeRoundDecisionCvar = CreateConVar(
      "sm_c5_pug_vote_for_knife_round_decision", "1",
      "If 0, the first player to type .stay/.swap/.t/.ct will decide the round round winner decision - otherwise a majority vote will be used");
  g_EchoReadyMessagesCvar = CreateConVar("sm_c5_pug_echo_ready_messages", "1",
                                         "Whether to print to chat when clients ready/unready.");
  g_ExcludedMaps = CreateConVar(
      "sm_c5_pug_excluded_maps", "0",
      "Number of past maps to exclude from map votes. Setting this to 0 disables this feature.");
  g_ForceDefaultsCvar = CreateConVar(
      "sm_c5_pug_force_defaults", "0",
      "Whether the default setup options are forced as the setup options (note that admins can override them still).");
  g_LiveCfgCvar = CreateConVar("sm_c5_pug_live_cfg", "sourcemod/c5_pug/live.cfg",
                               "Config to execute when the game goes live");
  g_MapVoteTimeCvar =
      CreateConVar("sm_c5_pug_mapvote_time", "25",
                   "How long the map vote should last if using map-votes.", _, true, 10.0);
  g_MutualUnpauseCvar = CreateConVar(
      "sm_c5_pug_mutual_unpausing", "1",
      "Whether an unpause command requires someone from both teams to fully unpause the match. Note that this forces the pause/unpause commands to be unrestricted (so anyone can use them).");
  g_PauseCountLimitCvar = CreateConVar(
      "sm_c5_pug_pause_count_limit", "2", "");
  g_PauseTimeCvar = CreateConVar(
      "sm_c5_pug_pause_time", "120", "");
  g_PausingEnabledCvar =
      CreateConVar("sm_c5_pug_pausing_enabled", "1", "Whether pausing is allowed.");
  g_PostGameCfgCvar =
      CreateConVar("sm_c5_pug_postgame_cfg", "sourcemod/c5_pug/warmup.cfg",
                   "Config to execute after games finish; should be in the csgo/cfg directory.");
  g_RandomizeMapOrderCvar =
      CreateConVar("sm_c5_pug_randomize_maps", "1",
                   "When maps are shown in the map vote/veto, whether their order is randomized.");
  g_RandomOptionInMapVoteCvar =
      CreateConVar("sm_c5_pug_random_map_vote_option", "1",
                   "Whether option 1 in a mapvote is the random map choice.");
  g_SetupEnabledCvar = CreateConVar("sm_c5_pug_setup_enabled", "1",
                                    "Whether the sm_setup commands are enabled");
  g_SnakeCaptainsCvar = CreateConVar(
      "sm_c5_pug_snake_captain_picks", "1",
      "If set to 0: captains pick players in a ABABABAB order. If set to 1, in a ABBAABBA order. If set to 2, in a ABBABABA order. If set to 3, in a ABBABAAB order.");
  g_StartDelayCvar =
      CreateConVar("sm_c5_pug_start_delay", "5",
                   "How many seconds of a countdown phase right before the lo3 process begins.", _,
                   true, 0.0, true, 60.0);
  g_WarmupCfgCvar =
      CreateConVar("sm_c5_pug_warmup_cfg", "sourcemod/c5_pug/warmup.cfg",
                   "Config file to run before/after games; should be in the csgo/cfg directory.");
  g_WarmupMoneyOnSpawnCvar = CreateConVar(
      "sm_c5_pug_money_on_warmup_spawn", "1",
      "Whether clients recieve 16,000 dollars when they spawn. It's recommended you use mp_death_drop_gun 0 in your warmup config if you use this.");

  /** Create and exec plugin's configuration file **/
  AutoExecConfig(true, "c5_pug", "sourcemod/c5");

  /** Commands **/
  g_Commands = new ArrayList(COMMAND_LENGTH);
  LoadTranslatedAliases();
  AddPugSetupCommand("ready", Command_Ready, "Marks the client as ready", Permission_All,
                     ChatAlias_WhenSetup);
  AddPugSetupCommand("notready", Command_NotReady, "Marks the client as not ready", Permission_All,
                     ChatAlias_WhenSetup);
  AddPugSetupCommand("setup", Command_Setup,
                     "Starts pug setup (.ready, .capt commands become avaliable)", Permission_All);
  AddPugSetupCommand("rand", Command_Rand, "Sets random captains", Permission_Captains,
                     ChatAlias_WhenSetup);
  AddPugSetupCommand("pause", Command_Pause, "Pauses the game", Permission_All,
                     ChatAlias_WhenSetup);
  AddPugSetupCommand("unpause", Command_Unpause, "Unpauses the game", Permission_All,
                     ChatAlias_WhenSetup);
  AddPugSetupCommand("endgame", Command_EndGame, "Pre-emptively ends the match", Permission_Leader);
  AddPugSetupCommand("forceend", Command_ForceEnd,
                     "Pre-emptively ends the match, without any confirmation menu",
                     Permission_Leader);
  AddPugSetupCommand("forceready", Command_ForceReady, "Force-readies a player", Permission_Admin,
                     ChatAlias_WhenSetup);
  AddPugSetupCommand("leader", Command_Leader, "Sets the pug leader", Permission_Leader);
  AddPugSetupCommand("capt", Command_Capt, "Gives the client a menu to pick captains",
                     Permission_Leader);
  AddPugSetupCommand("stay", Command_Stay,
                     "Elects to stay on the current team after winning a knife round",
                     Permission_All, ChatAlias_WhenSetup);
  AddPugSetupCommand("swap", Command_Swap,
                     "Elects to swap the current teams after winning a knife round", Permission_All,
                     ChatAlias_WhenSetup);
  AddPugSetupCommand("t", Command_T, "Elects to start on T side after winning a knife round",
                     Permission_All, ChatAlias_WhenSetup);
  AddPugSetupCommand("ct", Command_Ct, "Elects to start on CT side after winning a knife round",
                     Permission_All, ChatAlias_WhenSetup);
  AddPugSetupCommand("forcestart", Command_ForceStart, "Force starts the game", Permission_Admin,
                     ChatAlias_WhenSetup);
  AddPugSetupCommand("addalias", Command_AddAlias,
                     "Adds a pugsetup alias, and saves it to the chatalias.cfg file",
                     Permission_Admin);
  AddPugSetupCommand("removealias", Command_RemoveAlias, "Removes a pugsetup alias",
                     Permission_Admin);
  LoadExtraAliases();

  RegConsoleCmd("pugstatus", Command_Pugstatus, "Dumps information about the pug game status");
  RegConsoleCmd("pugsetup_status", Command_Pugstatus,
                "Dumps information about the pug game status");
  RegConsoleCmd("pugsetup_permissions", Command_ShowPermissions,
                "Dumps pugsetup command permissions");
  RegConsoleCmd("pugsetup_chataliases", Command_ShowChatAliases,
                "Dumps registered pugsetup chat aliases");

  /** Hooks **/
  HookEvent("cs_win_panel_match", Event_MatchOver);
  HookEvent("round_start", Event_RoundStart);
  HookEvent("round_freeze_end", Event_RoundFreezeEnd);
  HookEvent("round_end", Event_RoundEnd);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
  HookEvent("player_connect", Event_PlayerConnect);
  HookEvent("player_disconnect", Event_PlayerDisconnect);

  g_OnForceEnd = CreateGlobalForward("C5_PUG_OnForceEnd", ET_Ignore, Param_Cell);
  g_hOnGoingLive = CreateGlobalForward("C5_PUG_OnGoingLive", ET_Ignore);
  g_hOnHelpCommand = CreateGlobalForward("C5_PUG_OnHelpCommand", ET_Ignore, Param_Cell,
                                         Param_Cell, Param_Cell, Param_CellByRef);
  g_hOnKnifeRoundDecision =
      CreateGlobalForward("C5_PUG_OnKnifeRoundDecision", ET_Ignore, Param_Cell);
  g_hOnLive = CreateGlobalForward("C5_PUG_OnLive", ET_Ignore);
  g_hOnLiveCfg = CreateGlobalForward("C5_PUG_OnLiveCfgExecuted", ET_Ignore);
  g_hOnLiveCheck =
      CreateGlobalForward("C5_PUG_OnReadyToStartCheck", ET_Ignore, Param_Cell, Param_Cell);
  g_hOnMatchOver = CreateGlobalForward("C5_PUG_OnMatchOver", ET_Ignore, Param_Cell, Param_String);
  g_hOnNotPicked = CreateGlobalForward("C5_PUG_OnNotPicked", ET_Ignore, Param_Cell);
  g_hOnPermissionCheck = CreateGlobalForward("C5_PUG_OnPermissionCheck", ET_Ignore, Param_Cell,
                                             Param_String, Param_Cell, Param_CellByRef);
  g_hOnPlayerAddedToCaptainMenu =
      CreateGlobalForward("C5_PUG_OnPlayerAddedToCaptainMenu", ET_Ignore, Param_Cell, Param_Cell,
                          Param_String, Param_Cell);
  g_hOnPostGameCfg = CreateGlobalForward("C5_PUG_OnPostGameCfgExecuted", ET_Ignore);
  g_hOnReady = CreateGlobalForward("C5_PUG_OnReady", ET_Ignore, Param_Cell);
  g_hOnReadyToStart = CreateGlobalForward("C5_PUG_OnReadyToStart", ET_Ignore);
  g_hOnSetup = CreateGlobalForward("C5_PUG_OnSetup", ET_Ignore, Param_Cell, Param_Cell,
                                   Param_Cell, Param_Cell);
  g_hOnSetupMenuOpen =
      CreateGlobalForward("C5_PUG_OnSetupMenuOpen", ET_Event, Param_Cell, Param_Cell, Param_Cell);
  g_hOnSetupMenuSelect = CreateGlobalForward("C5_PUG_OnSetupMenuSelect", ET_Ignore, Param_Cell,
                                             Param_Cell, Param_String, Param_Cell);
  g_hOnStartRecording = CreateGlobalForward("C5_PUG_OnStartRecording", ET_Ignore, Param_String);
  g_hOnStateChange =
      CreateGlobalForward("C5_PUG_OnGameStateChanged", ET_Ignore, Param_Cell, Param_Cell);
  g_hOnUnready = CreateGlobalForward("C5_PUG_OnUnready", ET_Ignore, Param_Cell);
  g_hOnWarmupCfg = CreateGlobalForward("C5_PUG_OnWarmupCfgExecuted", ET_Ignore);

  g_LiveTimerRunning = false;
  ReadSetupOptions();

  g_MapVotePool = new ArrayList(PLATFORM_MAX_PATH);
  g_PastMaps = new ArrayList(PLATFORM_MAX_PATH);
  
  g_auths = new ArrayList(64);

  // hook for friendlyfire
  for (int i = 1; i <= MaxClients; i++)
  {
      HookOnTakeDamage(i);
  }
}

static void AddPugSetupCommand(const char[] command, ConCmd callback, const char[] description,
                               Permission p, ChatAliasMode mode = ChatAlias_Always) {
  char smCommandBuffer[64];
  Format(smCommandBuffer, sizeof(smCommandBuffer), "sm_%s", command);
  g_Commands.PushString(smCommandBuffer);
  RegConsoleCmd(smCommandBuffer, callback, description);
  C5_PUG_SetPermissions(smCommandBuffer, p);

  char dotCommandBuffer[64];
  Format(dotCommandBuffer, sizeof(dotCommandBuffer), ".%s", command);
  C5_PUG_AddChatAlias(dotCommandBuffer, smCommandBuffer, mode);
}

public void OnConfigsExecuted() {
  FillMapList("maps.txt", g_MapList);
  ReadPermissions();
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen) {
  g_Ready[client] = false;
  g_SavedClanTag[client] = false;
  CheckAutoSetup();
  return true;
}

public void OnClientDisconnect_Post(int client) {
  int numPlayers = 0;
  for (int i = 1; i <= MaxClients; i++)
    if (IsPlayer(i))
      numPlayers++;

  if (numPlayers == 0 && !g_SwitchingMaps && g_AutoSetupCvar.IntValue == 0) {
    EndMatch(true);
  }
}

public void OnMapStart() {
  if (g_SwitchingMaps) {
    g_SwitchingMaps = false;
  }

  g_ForceEnded = false;
  g_MapVetoed = new ArrayList();
  g_Recording = false;
  g_LiveTimerRunning = false;
  g_ForceStartSignal = false;

  if (g_GameState == GameState_Warmup) {
    ExecWarmupConfigs();
    StartWarmup();
    StartLiveTimer();
  } else {
    g_capt1 = -1;
    g_capt2 = -1;
    g_Leader = -1;
    for (int i = 1; i <= MaxClients; i++) {
      g_Ready[i] = false;
      g_Teams[i] = CS_TEAM_NONE;
    }
  }
}

public void OnMapEnd() {
  CloseHandle(g_MapVetoed);
}

public bool UsingCaptains() {
  return g_TeamType == TeamType_Captains || g_MapType == MapType_Veto;
}

public Action Timer_CheckReady(Handle timer) {
  if (g_GameState != GameState_Warmup || !g_LiveTimerRunning) {
    g_LiveTimerRunning = false;
    return Plugin_Stop;
  }

  int readyPlayers = 0;
  int totalPlayers = 0;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      UpdateClanTag(i);
      int team = GetClientTeam(i);
      if (team == CS_TEAM_CT || team == CS_TEAM_T) {
        totalPlayers++;
        if (g_Ready[i]) {
          readyPlayers++;
        }
      }
    }
  }

  if (totalPlayers >= C5_PUG_GetPugMaxPlayers()) {
    GiveReadyHints();
  }

  // beware: scary spaghetti code ahead
  if ((readyPlayers == totalPlayers && readyPlayers >= 2 * g_PlayersPerTeam) ||
      g_ForceStartSignal) {
    g_ForceStartSignal = false;

    if (g_OnDecidedMap) {
      if (g_TeamType == TeamType_Captains) {
        if (IsPlayer(g_capt1) && IsPlayer(g_capt2) && g_capt1 != g_capt2) {
          g_LiveTimerRunning = false;
          PrintHintTextToAll("%t\n%t", "ReadyStatusPlayers", readyPlayers, totalPlayers, "ReadyStatusAllReadyPick");
          CreateTimer(1.0, StartPicking, _, TIMER_FLAG_NO_MAPCHANGE);
          return Plugin_Stop;
        } else {
          StatusHint(readyPlayers, totalPlayers);
        }
      } else {
        g_LiveTimerRunning = false;

        PrintHintTextToAll("%t\n%t", "ReadyStatusPlayers", readyPlayers, totalPlayers, "ReadyStatusAllReady");

        ReadyToStart();
        return Plugin_Stop;
      }

    } else {
      if (g_MapType == MapType_Veto) {
        if (IsPlayer(g_capt1) && IsPlayer(g_capt2) && g_capt1 != g_capt2) {
          g_LiveTimerRunning = false;
          PrintHintTextToAll("%t\n%t", "ReadyStatusPlayers", readyPlayers, totalPlayers, "ReadyStatusAllReadyVeto");
          C5_MessageToAll("%t", "VetoMessage");
          CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
          return Plugin_Stop;
        } else {
          StatusHint(readyPlayers, totalPlayers);
        }

      } else {
        g_LiveTimerRunning = false;
        PrintHintTextToAll("%t\n%t", "ReadyStatusPlayers", readyPlayers, totalPlayers, "ReadyStatusAllReadyVote");
        C5_MessageToAll("%t", "VoteMessage");
        CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
      }
    }

  } else {
    StatusHint(readyPlayers, totalPlayers);
  }

  Call_StartForward(g_hOnLiveCheck);
  Call_PushCell(readyPlayers);
  Call_PushCell(totalPlayers);
  Call_Finish();

  if (g_TeamType == TeamType_Captains && g_AutoRandomizeCaptainsCvar.IntValue != 0 &&
      totalPlayers >= C5_PUG_GetPugMaxPlayers()) {
    // re-randomize captains if they aren't set yet
    if (!IsPlayer(g_capt1)) {
      g_capt1 = RandomPlayer();
    }

    while (!IsPlayer(g_capt2) || g_capt1 == g_capt2) {
      if (GetRealClientCount() < 2)
        break;
      g_capt2 = RandomPlayer();
    }
  }

  return Plugin_Continue;
}

public void StatusHint(int readyPlayers, int totalPlayers) {
  char rdyCommand[ALIAS_LENGTH];
  FindAliasFromCommand("sm_ready", rdyCommand);
  bool captainsNeeded = (!g_OnDecidedMap && g_MapType == MapType_Veto) ||
                        (g_OnDecidedMap && g_TeamType == TeamType_Captains);

  if (captainsNeeded) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        GiveCaptainHint(i, readyPlayers, totalPlayers);
      }
    }
  } else {
    PrintHintTextToAll("%t", "ReadyStatus", readyPlayers, totalPlayers, rdyCommand);
  }
}

static void GiveReadyHints() {
  int time = GetTime();
  int dt = time - g_LastReadyHintTime;

  if (dt >= READY_COMMAND_HINT_TIME) {
    g_LastReadyHintTime = time;
    char cmd[ALIAS_LENGTH];
    FindAliasFromCommand("sm_ready", cmd);
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && !C5_PUG_IsReady(i) && OnActiveTeam(i)) {
        C5_Message(i, "%t", "ReadyCommandHint", cmd);
      }
    }
  }
}

static void GiveCaptainHint(int client, int readyPlayers, int totalPlayers) {
  char cap1[MAX_NAME_LENGTH];
  char cap2[MAX_NAME_LENGTH];
  const int kMaxNameLength = 14;

  if (IsPlayer(g_capt1)) {
    Format(cap1, sizeof(cap1), "%N", g_capt1);
    if (strlen(cap1) > kMaxNameLength) {
      strcopy(cap1, kMaxNameLength, cap1);
      Format(cap1, sizeof(cap1), "%s...", cap1);
    }
  } else {
    Format(cap1, sizeof(cap1), "%T", "CaptainNotSelected", client);
  }

  if (IsPlayer(g_capt2)) {
    Format(cap2, sizeof(cap2), "%N", g_capt2);
    if (strlen(cap2) > kMaxNameLength) {
      strcopy(cap2, kMaxNameLength, cap2);
      Format(cap2, sizeof(cap2), "%s...", cap2);
    }
  } else {
    Format(cap2, sizeof(cap2), "%T", "CaptainNotSelected", client);
  }

  PrintHintTextToAll("%t", "ReadyStatusCaptains", readyPlayers, totalPlayers, cap1, cap2);

  // if there aren't any captains and we full players, print the hint telling the leader how to set
  // captains
  if (!IsPlayer(g_capt1) && !IsPlayer(g_capt2) && totalPlayers >= C5_PUG_GetPugMaxPlayers()) {
    // but only do it at most every CAPTAIN_COMMAND_HINT_TIME seconds so it doesn't get spammed
    int time = GetTime();
    int dt = time - g_LastCaptainHintTime;
    if (dt >= CAPTAIN_COMMAND_HINT_TIME) {
      g_LastCaptainHintTime = time;
      char cmd[ALIAS_LENGTH];
      FindAliasFromCommand("sm_capt", cmd);
      C5_MessageToAll("%t", "SetCaptainsHint", C5_PUG_GetLeader(), cmd);
    }
  }
}

/***********************
 *                     *
 *     Commands        *
 *                     *
 ***********************/

public bool DoPermissionCheck(int client, const char[] command) {
  Permission p = C5_PUG_GetPermissions(command);
  bool result = C5_PUG_HasPermissions(client, p);
  char cmd[COMMAND_LENGTH];
  GetCmdArg(0, cmd, sizeof(cmd));
  Call_StartForward(g_hOnPermissionCheck);
  Call_PushCell(client);
  Call_PushString(cmd);
  Call_PushCell(p);
  Call_PushCellRef(result);
  Call_Finish();
  return result;
}

public Action Command_Setup(int client, int args) {
  if (g_SetupEnabledCvar.IntValue == 0) {
    return Plugin_Handled;
  }

  if (g_GameState > GameState_Warmup) {
    C5_Message(client, "%t", "AlreadyLive");
    return Plugin_Handled;
  }

  bool allowedToSetup = DoPermissionCheck(client, "sm_setup");
  if (g_GameState == GameState_None && !allowedToSetup) {
    C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  bool allowedToChangeSetup = C5_PUG_HasPermissions(client, Permission_Leader);
  if (g_GameState == GameState_Warmup && !allowedToChangeSetup) {
    C5_PUG_GiveSetupMenu(client, true);
    return Plugin_Handled;
  }

  if (IsPlayer(client)) {
    g_Leader = client;
  }

  if (client == 0) {
    // if we did the setup command from the console just use the default settings
    ReadSetupOptions();
    C5_PUG_SetupGame(g_TeamType, g_MapType, g_PlayersPerTeam, g_RecordGameOption, g_DoKnifeRound);
  } else {
    C5_PUG_GiveSetupMenu(client);
  }

  return Plugin_Handled;
}

public Action Command_Rand(int client, int args) {
  if (g_GameState != GameState_Warmup)
    return Plugin_Handled;

  if (!UsingCaptains()) {
    C5_Message(client, "%t", "NotUsingCaptains");
    return Plugin_Handled;
  }

  if (!DoPermissionCheck(client, "sm_rand")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  C5_PUG_SetRandomCaptains();
  return Plugin_Handled;
}

public Action Command_Capt(int client, int args) {
  if (g_GameState != GameState_Warmup)
    return Plugin_Handled;

  if (!UsingCaptains()) {
    C5_Message(client, "%t", "NotUsingCaptains");
    return Plugin_Handled;
  }

  if (!DoPermissionCheck(client, "sm_capt")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  char buffer[MAX_NAME_LENGTH];
  if (GetCmdArgs() >= 1) {
    GetCmdArg(1, buffer, sizeof(buffer));
    int target = FindTarget(client, buffer, true, false);
    if (IsPlayer(target))
      C5_PUG_SetCaptain(1, target, true);

    if (GetCmdArgs() >= 2) {
      GetCmdArg(2, buffer, sizeof(buffer));
      target = FindTarget(client, buffer, true, false);

      if (IsPlayer(target))
        C5_PUG_SetCaptain(2, target, true);

    } else {
      Captain2Menu(client);
    }

  } else {
    Captain1Menu(client);
  }
  return Plugin_Handled;
}

public Action Command_ForceStart(int client, int args) {
  if (g_GameState != GameState_Warmup)
    return Plugin_Handled;

  if (!DoPermissionCheck(client, "sm_forcestart")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && !C5_PUG_IsReady(i)) {
      C5_PUG_ReadyPlayer(i, false);
    }
  }
  g_ForceStartSignal = true;
  return Plugin_Handled;
}

public void LoadTranslatedAliases() {
  // For each of these sm_x commands, we need the
  // translation phrase sm_x_alias to be present.
  AddTranslatedAlias("sm_capt", ChatAlias_WhenSetup);
  AddTranslatedAlias("sm_endgame", ChatAlias_WhenSetup);
  AddTranslatedAlias("sm_notready", ChatAlias_WhenSetup);
  AddTranslatedAlias("sm_pause", ChatAlias_WhenSetup);
  AddTranslatedAlias("sm_ready", ChatAlias_WhenSetup);
  AddTranslatedAlias("sm_setup");
  AddTranslatedAlias("sm_stay", ChatAlias_WhenSetup);
  AddTranslatedAlias("sm_swap", ChatAlias_WhenSetup);
  AddTranslatedAlias("sm_unpause", ChatAlias_WhenSetup);
  AddTranslatedAlias("sm_start", ChatAlias_WhenSetup);
}

public void LoadExtraAliases() {
  // Read custom user aliases
  ReadChatConfig();

  // Any extra chat aliases we want
  C5_PUG_AddChatAlias(".captain", "sm_capt", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".captains", "sm_capt", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".setcaptains", "sm_capt", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".endmatch", "sm_endgame", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".cancel", "sm_endgame", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".gaben", "sm_ready", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".gs4lyfe", "sm_ready", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".splewis", "sm_ready", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".unready", "sm_notready", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".paws", "sm_pause", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".unpaws", "sm_unpause", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".switch", "sm_swap", ChatAlias_WhenSetup);
  C5_PUG_AddChatAlias(".forcestop", "sm_forceend", ChatAlias_WhenSetup);
}

static void AddTranslatedAlias(const char[] command, ChatAliasMode mode = ChatAlias_Always) {
  char translationName[128];
  Format(translationName, sizeof(translationName), "%s_alias", command);

  char alias[ALIAS_LENGTH];
  Format(alias, sizeof(alias), "%T", translationName, LANG_SERVER);

  C5_PUG_AddChatAlias(alias, command, mode);
}

public bool FindAliasFromCommand(const char[] command, char alias[ALIAS_LENGTH]) {
  int n = g_ChatAliases.Length;
  char tmpCommand[COMMAND_LENGTH];

  for (int i = 0; i < n; i++) {
    g_ChatAliasesCommands.GetString(i, tmpCommand, sizeof(tmpCommand));

    if (StrEqual(command, tmpCommand)) {
      g_ChatAliases.GetString(i, alias, sizeof(alias));
      return true;
    }
  }

  // If we never found one, just use .<command> since it always gets added by AddPugSetupCommand
  Format(alias, sizeof(alias), ".%s", command);
  return false;
}

public bool FindComandFromAlias(const char[] alias, char command[COMMAND_LENGTH]) {
  int n = g_ChatAliases.Length;
  char tmpAlias[ALIAS_LENGTH];

  for (int i = 0; i < n; i++) {
    g_ChatAliases.GetString(i, tmpAlias, sizeof(tmpAlias));

    if (StrEqual(alias, tmpAlias, false)) {
      g_ChatAliasesCommands.GetString(i, command, sizeof(command));
      return true;
    }
  }

  return false;
}

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] chatCommand,
                           const char[] chatArgs, int client, ChatAliasMode mode) {
  if (StrEqual(chatCommand, alias, false)) {
    if (mode == ChatAlias_WhenSetup && g_GameState == GameState_None) {
      return false;
    }

    // Get the original cmd reply source so it can be restored after the fake client command.
    // This means and ReplyToCommand will go into the chat area, rather than console, since
    // *chat* aliases are for *chat* commands.
    ReplySource replySource = GetCmdReplySource();
    SetCmdReplySource(SM_REPLY_TO_CHAT);
    char fakeCommand[256];
    Format(fakeCommand, sizeof(fakeCommand), "%s %s", command, chatArgs);
    FakeClientCommand(client, fakeCommand);
    SetCmdReplySource(replySource);
    return true;
  }
  return false;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
  if (!IsPlayer(client))
    return;

  // splits to find the first word to do a chat alias command check
  char chatCommand[COMMAND_LENGTH];
  char chatArgs[255];
  int index = SplitString(sArgs, " ", chatCommand, sizeof(chatCommand));

  if (index == -1) {
    strcopy(chatCommand, sizeof(chatCommand), sArgs);
  } else if (index < strlen(sArgs)) {
    strcopy(chatArgs, sizeof(chatArgs), sArgs[index]);
  }

  if (chatCommand[0]) {
    char alias[ALIAS_LENGTH];
    char cmd[COMMAND_LENGTH];
    for (int i = 0; i < GetArraySize(g_ChatAliases); i++) {
      GetArrayString(g_ChatAliases, i, alias, sizeof(alias));
      GetArrayString(g_ChatAliasesCommands, i, cmd, sizeof(cmd));
      if (CheckChatAlias(alias, cmd, chatCommand, chatArgs, client, g_ChatAliasesModes.Get(i))) {
        break;
      }
    }
  }

  if (StrEqual(sArgs[0], ".help")) {
    const int msgSize = 128;
    ArrayList msgs = new ArrayList(msgSize);

    msgs.PushString("{LIGHT_GREEN}.setup {NORMAL}begins the setup phase");
    msgs.PushString("{LIGHT_GREEN}.endgame {NORMAL}ends the match");
    msgs.PushString("{LIGHT_GREEN}.leader {NORMAL}allows you to set the pug leader");
    msgs.PushString("{LIGHT_GREEN}.capt {NORMAL}allows you to set team captains");
    msgs.PushString("{LIGHT_GREEN}.rand {NORMAL}selects random captains");
    msgs.PushString("{LIGHT_GREEN}.ready/.notready {NORMAL}mark you as ready");
    msgs.PushString("{LIGHT_GREEN}.pause/.unpause {NORMAL}pause the match");

    bool block = false;
    Call_StartForward(g_hOnHelpCommand);
    Call_PushCell(client);
    Call_PushCell(msgs);
    Call_PushCell(msgSize);
    Call_PushCellRef(block);
    Call_Finish();

    if (!block) {
      char msg[msgSize];
      for (int i = 0; i < msgs.Length; i++) {
        msgs.GetString(i, msg, sizeof(msg));
        C5_Message(client, msg);
      }
    }

    delete msgs;
  }

  // Allow using .map as a map-vote revote alias and as a
  // shortcut to the mapchange menu (if avaliable).
  if (StrEqual(sArgs, ".map") || StrEqual(sArgs, "!revote")) {
    if (IsVoteInProgress() && IsClientInVotePool(client)) {
      RedrawClientVoteMenu(client);
    } else if (C5_PUG_IsPugAdmin(client) && g_DisplayMapChange) {
      C5_PUG_GiveMapChangeMenu(client);
    }
  }
}

public Action Command_EndGame(int client, int args) {
  if (g_GameState == GameState_None) {
    C5_Message(client, "%t", "NotLiveYet");
  } else {
    if (!DoPermissionCheck(client, "sm_endgame")) {
      if (IsValidClient(client))
        C5_Message(client, "%t", "NoPermission");
      return Plugin_Handled;
    }

    // bypass the menu if console does it
    if (client == 0) {
      Call_StartForward(g_OnForceEnd);
      Call_PushCell(client);
      Call_Finish();

      C5_MessageToAll("%t", "ForceEnd", client);
      EndMatch(true);
      g_ForceEnded = true;
    } else {
      Menu menu = new Menu(MatchEndHandler);
      SetMenuTitle(menu, "%T", "EndMatchMenuTitle", client);
      SetMenuExitButton(menu, true);
      AddMenuBool(menu, false, "%T", "ContinueMatch", client);
      AddMenuBool(menu, true, "%T", "EndMatch", client);
      DisplayMenu(menu, client, 20);
    }
  }
  return Plugin_Handled;
}

public int MatchEndHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    bool choice = GetMenuBool(menu, param2);
    if (choice) {
      Call_StartForward(g_OnForceEnd);
      Call_PushCell(client);
      Call_Finish();

      C5_MessageToAll("%t", "ForceEnd", client);
      EndMatch(true);
      g_ForceEnded = true;
    }
  } else if (action == MenuAction_End) {
    CloseHandle(menu);
  }
}

public Action Command_ForceEnd(int client, int args) {
  if (!DoPermissionCheck(client, "sm_forceend")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  Call_StartForward(g_OnForceEnd);
  Call_PushCell(client);
  Call_Finish();

  C5_MessageToAll("%t", "ForceEnd", client);
  EndMatch(true);
  g_ForceEnded = true;
  return Plugin_Handled;
}

public Action Command_ForceReady(int client, int args) {
  if (!DoPermissionCheck(client, "sm_forceready")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  char buffer[MAX_NAME_LENGTH];
  if (args >= 1 && GetCmdArg(1, buffer, sizeof(buffer))) {
    if (StrEqual(buffer, "all")) {
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
          C5_PUG_ReadyPlayer(i);
        }
      }
    } else {
      int target = FindTarget(client, buffer, true, false);
      if (IsPlayer(target)) {
        C5_PUG_ReadyPlayer(target);
      }
    }
  } else {
    C5_Message(client, "Usage: .forceready <player>");
  }

  return Plugin_Handled;
}

static bool Pauseable() {
  return g_GameState >= GameState_KnifeRound && g_PausingEnabledCvar.IntValue != 0;
}

public Action Command_Pause(int client, int args) {
  if (g_GameState == GameState_None)
    return Plugin_Handled;

  if (!Pauseable() || IsPaused())
    return Plugin_Handled;

  if (g_MutualUnpauseCvar.IntValue != 0) {
    C5_PUG_SetPermissions("sm_pause", Permission_All);
  }
  
  if (!DoPermissionCheck(client, "sm_pause")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }
  
  g_ctUnpaused = false;
  g_tUnpaused = false;

  int team = GetClientTeam(client);
  if (g_PauseCountLimitCvar.IntValue > 0)
  {
    if (g_PauseCount[team] <= 0)
    {
      C5_Message(client, "你们已经没有暂停的机会啦!");
      return Plugin_Handled;
    }
    else
    {
      g_PauseCount[team]--;
    }
  }

  if (g_PauseTimeCvar.IntValue > 0 && g_IsInFreezeTime)
  {
    StartPauseCountDown();
  }
  Pause();
  if (IsPlayer(client)) {
    if (g_PauseCountLimitCvar.IntValue > 0)
    {
      C5_MessageToAll("%t, 该队伍还剩 {LIGHT_RED}%d {NORMAL}次暂停机会", "Pause", client, g_PauseCount[team]);
    }
    else
    {
      C5_MessageToAll("%t", "Pause", client);
    }
  }

  return Plugin_Handled;
}

public Action Command_Unpause(int client, int args) {
  if (g_GameState == GameState_None)
    return Plugin_Handled;

  if (!IsPaused())
    return Plugin_Handled;

  if (g_MutualUnpauseCvar.IntValue != 0) {
    C5_PUG_SetPermissions("sm_unpause", Permission_All);
  }

  if (!DoPermissionCheck(client, "sm_unpause")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  char unpauseCmd[ALIAS_LENGTH];
  FindAliasFromCommand("sm_unpause", unpauseCmd);

  if (g_MutualUnpauseCvar.IntValue == 0) {
    UnpauseCountDown();
    if (IsPlayer(client)) {
      C5_MessageToAll("%t", "Unpause", client);
    }
  } else {
    // Let console force unpause
    if (client == 0) {
      UnpauseCountDown();
    } else {
      int team = GetClientTeam(client);
      if (team == CS_TEAM_T)
        g_tUnpaused = true;
      else if (team == CS_TEAM_CT)
        g_ctUnpaused = true;

      if (g_tUnpaused && g_ctUnpaused) {
        UnpauseCountDown();
        if (IsPlayer(client)) {
          C5_MessageToAll("%t", "Unpause", client);
        }
      } else if (g_tUnpaused && !g_ctUnpaused) {
        C5_MessageToAll("%t", "MutualUnpauseMessage", "T", "CT", unpauseCmd);
      } else if (!g_tUnpaused && g_ctUnpaused) {
        C5_MessageToAll("%t", "MutualUnpauseMessage", "CT", "T", unpauseCmd);
      }
    }
  }

  return Plugin_Handled;
}

public Action Command_Ready(int client, int args) {
  if (!DoPermissionCheck(client, "sm_ready")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  C5_PUG_ReadyPlayer(client);
  return Plugin_Handled;
}

public Action Command_NotReady(int client, int args) {
  if (!DoPermissionCheck(client, "sm_notready")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  C5_PUG_UnreadyPlayer(client);
  return Plugin_Handled;
}

public Action Command_Leader(int client, int args) {
  if (g_GameState == GameState_None)
    return Plugin_Handled;

  if (!DoPermissionCheck(client, "sm_leader")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  char buffer[64];
  if (GetCmdArgs() >= 1) {
    GetCmdArg(1, buffer, sizeof(buffer));
    int target = FindTarget(client, buffer, true, false);
    if (IsPlayer(target))
      C5_PUG_SetLeader(target);
  } else if (IsClientInGame(client)) {
    LeaderMenu(client);
  }

  return Plugin_Handled;
}

public Action Command_AddAlias(int client, int args) {
  if (!DoPermissionCheck(client, "sm_addalias")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  char alias[ALIAS_LENGTH];
  char command[COMMAND_LENGTH];

  if (args >= 2 && GetCmdArg(1, alias, sizeof(alias)) && GetCmdArg(2, command, sizeof(command))) {
    // try a lookup to find a valid command, e.g., if command=.ready, replace .ready with sm_ready
    if (!C5_PUG_IsValidCommand(command)) {
      FindComandFromAlias(command, command);
    }

    if (!C5_PUG_IsValidCommand(command)) {
      C5_Message(client, "%s is not a valid pugsetup command.", command);
      C5_Message(client, "Usage: .addalias <alias> <command>");
    } else {
      C5_PUG_AddChatAlias(alias, command);
      if (C5_PUG_AddChatAliasToFile(alias, command))
        C5_Message(client, "Succesfully added %s as an alias of commmand %s", alias, command);
      else
        C5_Message(client, "Failed to add chat alias");
    }
  } else {
    C5_Message(client, "Usage: .addalias <alias> <command>");
  }

  return Plugin_Handled;
}

public Action Command_RemoveAlias(int client, int args) {
  if (!DoPermissionCheck(client, "sm_addalias")) {
    if (IsValidClient(client))
      C5_Message(client, "%t", "NoPermission");
    return Plugin_Handled;
  }

  char alias[ALIAS_LENGTH];
  if (args >= 1 && GetCmdArg(1, alias, sizeof(alias))) {
    int index = -1;  // index of the alias inside g_ChatAliases
    char tmpAlias[ALIAS_LENGTH];
    for (int i = 0; i < g_ChatAliases.Length; i++) {
      g_ChatAliases.GetString(i, tmpAlias, sizeof(tmpAlias));
      if (StrEqual(alias, tmpAlias, false)) {
        index = i;
        break;
      }
    }

    if (index == -1) {
      C5_Message(client, "%s is not currently a chat alias", alias);
    } else {
      g_ChatAliasesCommands.Erase(index);
      g_ChatAliases.Erase(index);
      g_ChatAliasesModes.Erase(index);

      if (RemoveChatAliasFromFile(alias))
        C5_Message(client, "Succesfully removed alias %s", alias);
      else
        C5_Message(client, "Failed to remove chat alias");
    }
  } else {
    C5_Message(client, "Usage: .removealias <alias>");
  }

  return Plugin_Handled;
}

/***********************
 *                     *
 *       Events        *
 *                     *
 ***********************/

public Action Event_MatchOver(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState == GameState_Live) {
    CreateTimer(15.0, Timer_EndMatch);
    ExecCfg(g_WarmupCfgCvar);

    char map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));
    g_PastMaps.PushString(map);
  }

  if (g_PastMaps.Length > g_ExcludedMaps.IntValue) {
    g_PastMaps.Erase(0);
  }

  return Plugin_Continue;
}

/** Helper timer to delay starting warmup period after match is over by a little bit **/
public Action Timer_EndMatch(Handle timer) {
  EndMatch(false, false);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  CheckAutoSetup();
  if (IsPaused() && C5_PUG_IsMatchLive())
  {
    StartPauseCountDown();
  }
  g_IsInFreezeTime = true;
}

public Action Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  g_IsInFreezeTime = false;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState == GameState_KnifeRound) {
    ChangeState(GameState_WaitingForKnifeRoundDecision);
    g_KnifeWinner = GetKnifeRoundWinner();

    char teamString[4];
    if (g_KnifeWinner == CS_TEAM_CT)
      teamString = "CT";
    else
      teamString = "T";

    char stayCmd[ALIAS_LENGTH];
    char swapCmd[ALIAS_LENGTH];
    FindAliasFromCommand("sm_stay", stayCmd);
    FindAliasFromCommand("sm_swap", swapCmd);

    if (g_DoVoteForKnifeRoundDecisionCvar.IntValue != 0) {
      CreateKnifeVoteMenu();
      // CreateTimer(20.0, Timer_HandleKnifeDecisionVote, _, TIMER_FLAG_NO_MAPCHANGE);
      C5_MessageToAll("%t", "KnifeRoundWinnerVote", teamString, stayCmd, swapCmd);
    } else {
      C5_MessageToAll("%t", "KnifeRoundWinner", teamString, stayCmd, swapCmd);
    }
  }

  if (g_GameState == GameState_Live)
  {
    if (CS_GetTeamScore(CS_TEAM_T) == 15 && CS_GetTeamScore(CS_TEAM_CT) == 15)
    {
      DisplayOvertimeVoteMenu();
    }
  }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != GameState_Warmup)
    return;

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(client) && OnActiveTeam(client) && g_WarmupMoneyOnSpawnCvar.IntValue != 0) {
    SetEntProp(client, Prop_Send, "m_iAccount", GetCvarIntSafe("mp_maxmoney"));
  }
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  g_Teams[client] = CS_TEAM_NONE;
  g_PlayerAtStart[client] = false;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  if (g_Leader == client)
    g_Leader = -1;
  if (g_capt1 == client)
    g_capt1 = -1;
  if (g_capt2 == client)
    g_capt2 = -1;
}

/**
 * Silences cvar changes when executing live/knife/warmup configs, *unless* it's sv_cheats.
 */
public Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != GameState_None) {
    char cvarName[128];
    event.GetString("cvarname", cvarName, sizeof(cvarName));
    if (!StrEqual(cvarName, "sv_cheats")) {
      event.BroadcastDisabled = true;
    }
  }

  return Plugin_Continue;
}

/***********************
 *                     *
 *   Pugsetup logic    *
 *                     *
 ***********************/

public void PrintSetupInfo(int client) {
  if (IsPlayer(g_Leader))
    C5_Message(client, "%t", "SetupBy", g_Leader);

  // print each setup option avaliable
  char buffer[128];

  if (g_DisplayMapType) {
    GetMapString(buffer, sizeof(buffer), g_MapType, client);
    C5_Message(client, "%t: {GREEN}%s", "MapTypeOption", buffer);
  }

  if (g_DisplayTeamSize || g_DisplayTeamType) {
    GetTeamString(buffer, sizeof(buffer), g_TeamType, client);
    C5_Message(client, "%t: ({GREEN}%d vs %d{NORMAL}) {GREEN}%s", "TeamTypeOption",
                     g_PlayersPerTeam, g_PlayersPerTeam, buffer);
  }

  if (g_DisplayRecordDemo) {
    GetEnabledString(buffer, sizeof(buffer), g_RecordGameOption, client);
    C5_Message(client, "%t: {GREEN}%s", "DemoOption", buffer);
  }

  if (g_DisplayKnifeRound) {
    GetEnabledString(buffer, sizeof(buffer), g_DoKnifeRound, client);
    C5_Message(client, "%t: {GREEN}%s", "KnifeRoundOption", buffer);
  }
}

public void ReadyToStart() {
  Call_StartForward(g_hOnReadyToStart);
  Call_Finish();

  DisplayFriendlyFireVoteMenu();
}

public void CreateCountDown() {
  ChangeState(GameState_Countdown);
  g_CountDownTicks = g_StartDelayCvar.IntValue;
  CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CountDown(Handle timer) {
  if (g_GameState != GameState_Countdown) {
    // match cancelled
    C5_MessageToAll("%t", "CancelCountdownMessage");
    return Plugin_Stop;
  }

  if (g_CountDownTicks <= 0) {
    StartGame();
    return Plugin_Stop;
  }

  if (g_AnnounceCountdownCvar.IntValue != 0 &&
      (g_CountDownTicks < 5 || g_CountDownTicks % 5 == 0)) {
    C5_MessageToAll("%t", "Countdown", g_CountDownTicks);
  }

  g_CountDownTicks--;

  return Plugin_Continue;
}

public void StartGame() {
  if (g_RecordGameOption && !IsTVEnabled()) {
    LogError("GOTV demo could not be recorded since tv_enable is not set to 1");
  } else if (g_RecordGameOption && IsTVEnabled()) {
    // get the map, with any workshop stuff before removed
    // this is {MAP} in the format string
    char mapName[128];
    GetCurrentMap(mapName, sizeof(mapName));
    int last_slash = 0;
    int len = strlen(mapName);
    for (int i = 0; i < len; i++) {
      if (mapName[i] == '/' || mapName[i] == '\\')
        last_slash = i + 1;
    }

    // get the time, this is {TIME} in the format string
    char timeFormat[64];
    g_DemoTimeFormatCvar.GetString(timeFormat, sizeof(timeFormat));
    int timeStamp = GetTime();
    char formattedTime[64];
    FormatTime(formattedTime, sizeof(formattedTime), timeFormat, timeStamp);

    // get the player count, this is {TEAMSIZE} in the format string
    char playerCount[MAX_INTEGER_STRING_LENGTH];
    IntToString(g_PlayersPerTeam, playerCount, sizeof(playerCount));

    // create the actual demo name to use
    char demoName[PLATFORM_MAX_PATH];
    g_DemoNameFormatCvar.GetString(demoName, sizeof(demoName));

    ReplaceString(demoName, sizeof(demoName), "{MAP}", mapName[last_slash], false);
    ReplaceString(demoName, sizeof(demoName), "{TEAMSIZE}", playerCount, false);
    ReplaceString(demoName, sizeof(demoName), "{TIME}", formattedTime, false);

    Call_StartForward(g_hOnStartRecording);
    Call_PushString(demoName);
    Call_Finish();

    if (Record(demoName)) {
      LogMessage("Recording to %s", demoName);
      Format(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
      g_Recording = true;
    }
  }

  for (int i = 1; i <= MaxClients; i++) {
    g_PlayerAtStart[i] = IsPlayer(i);
  }

  if (g_TeamType == TeamType_Autobalanced) {
    if (!C5_PUG_IsTeamBalancerAvaliable()) {
      LogError(
          "Match setup with autobalanced teams without a balancer avaliable - falling back to random teams");
      g_TeamType = TeamType_Random;
    } else {
      ArrayList players = new ArrayList();
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
          if (C5_PUG_IsReady(i))
            players.Push(i);
          else
            ChangeClientTeam(i, CS_TEAM_SPECTATOR);
        }
      }

      char buffer[128];
      GetPluginFilename(g_BalancerFunctionPlugin, buffer, sizeof(buffer));

      Call_StartFunction(g_BalancerFunctionPlugin, g_BalancerFunction);
      Call_PushCell(players);
      Call_Finish();
      delete players;
    }
  }

  if (g_TeamType == TeamType_Random) {
    C5_MessageToAll("%t", "Scrambling");
    ScrambleTeams();
  }

  CreateTimer(3.0, Timer_BeginMatch);
  ExecGameConfigs();
  if (InWarmup()) {
    EndWarmup();
  }
}

public Action Timer_BeginMatch(Handle timer) {
  // clear pause count
  ResetPauseCount();

  if (g_DoKnifeRound) {
    ChangeState(GameState_KnifeRound);
    CreateTimer(3.0, StartKnifeRound, _, TIMER_FLAG_NO_MAPCHANGE);
  } else {
    ChangeState(GameState_GoingLive);
    CreateTimer(3.0, BeginLive, _, TIMER_FLAG_NO_MAPCHANGE);
  }
}

public void ScrambleTeams() {
  int tCount = 0;
  int ctCount = 0;

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && GetClientTeam(i) != CS_TEAM_SPECTATOR) {
      if (tCount < g_PlayersPerTeam && ctCount < g_PlayersPerTeam) {
        bool ct = (GetRandomInt(0, 1) == 0);
        if (ct) {
          SwitchPlayerTeam(i, CS_TEAM_CT);
          ctCount++;
        } else {
          SwitchPlayerTeam(i, CS_TEAM_T);
          tCount++;
        }

      } else if (tCount < g_PlayersPerTeam && ctCount >= g_PlayersPerTeam) {
        // CT is full
        SwitchPlayerTeam(i, CS_TEAM_T);
        tCount++;

      } else if (ctCount < g_PlayersPerTeam && tCount >= g_PlayersPerTeam) {
        // T is full
        SwitchPlayerTeam(i, CS_TEAM_CT);
        ctCount++;

      } else {
        // both teams full
        SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
        Call_StartForward(g_hOnNotPicked);
        Call_PushCell(i);
        Call_Finish();
      }
    }
  }
}

public void ExecWarmupConfigs() {
  ExecCfg(g_WarmupCfgCvar);
}

public void ExecGameConfigs() {
  ServerCommand("exec gamemode_competitive");

  ExecCfg(g_LiveCfgCvar);
  if (InWarmup())
    EndWarmup();

  ServerCommand("mp_match_can_clinch 1");
}

stock void EndMatch(bool execConfigs = true, bool doRestart = true) {
  if (g_GameState == GameState_None) {
    return;
  }

  if (g_Recording) {
    CreateTimer(4.0, StopDemo, _, TIMER_FLAG_NO_MAPCHANGE);
  } else {
    Call_StartForward(g_hOnMatchOver);
    Call_PushCell(false);
    Call_PushString("");
    Call_Finish();
  }

  g_LiveTimerRunning = false;
  g_Leader = -1;
  g_capt1 = -1;
  g_capt2 = -1;
  g_OnDecidedMap = false;
  ChangeState(GameState_None);

  if (g_KnifeCvarRestore != INVALID_HANDLE) {
    RestoreCvars(g_KnifeCvarRestore);
    CloseCvarStorage(g_KnifeCvarRestore);
    g_KnifeCvarRestore = INVALID_HANDLE;
  }

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      UpdateClanTag(i);
    }
  }

  if (execConfigs) {
    ExecCfg(g_PostGameCfgCvar);
  }
  if (IsPaused()) {
    UnpauseCountDown();
  }
  if (InWarmup()) {
    EndWarmup();
  }
  if (doRestart) {
    RestartGame(1);
  }
}

public void SetupMapVotePool(bool excludeRecentMaps) {
  g_MapVotePool.Clear();

  char mapNamePrimary[PLATFORM_MAX_PATH];
  char mapNameSecondary[PLATFORM_MAX_PATH];

  for (int i = 0; i < g_MapList.Length; i++) {
    bool mapExists = false;
    FormatMapName(g_MapList, i, mapNamePrimary, sizeof(mapNamePrimary));
    for (int v = 0; v < g_PastMaps.Length; v++) {
      g_PastMaps.GetString(v, mapNameSecondary, sizeof(mapNameSecondary));
      if (StrEqual(mapNamePrimary, mapNameSecondary)) {
        mapExists = true;
      }
    }
    if (!mapExists || !excludeRecentMaps) {
      g_MapVotePool.PushString(mapNamePrimary);
    }
  }
}

public Action MapSetup(Handle timer) {
  if (g_MapType == MapType_Vote) {
    CreateMapVote();
  } else if (g_MapType == MapType_Veto) {
    CreateMapVeto();
  } else {
    LogError("Unexpected map type in MapSetup=%d", g_MapType);
  }
  return Plugin_Handled;
}

public Action StartPicking(Handle timer) {
  ChangeState(GameState_PickingPlayers);
  Pause();
  RestartGame(1);

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      g_Teams[i] = CS_TEAM_SPECTATOR;
      SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
    } else {
      g_Teams[i] = CS_TEAM_NONE;
    }
  }

  // temporary teams
  SwitchPlayerTeam(g_capt2, CS_TEAM_CT);
  g_Teams[g_capt2] = CS_TEAM_CT;

  SwitchPlayerTeam(g_capt1, CS_TEAM_T);
  g_Teams[g_capt1] = CS_TEAM_T;

  CreateTimer(2.0, Timer_InitialChoiceMenu);
  return Plugin_Handled;
}

public Action FinishPicking(Handle timer) {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      if (g_Teams[i] == CS_TEAM_NONE || g_Teams[i] == CS_TEAM_SPECTATOR) {
        SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
        Call_StartForward(g_hOnNotPicked);
        Call_PushCell(i);
        Call_Finish();
      } else {
        SwitchPlayerTeam(i, g_Teams[i]);
      }
    }
  }

  Unpause();
  ReadyToStart();

  return Plugin_Handled;
}

public Action StopDemo(Handle timer) {
  StopRecording();
  g_Recording = false;
  Call_StartForward(g_hOnMatchOver);
  Call_PushCell(true);
  Call_PushString(g_DemoFileName);
  Call_Finish();
  return Plugin_Handled;
}

public void CheckAutoSetup() {
  if (g_AutoSetupCvar.IntValue != 0 && g_GameState == GameState_None && !g_ForceEnded) {
    // Re-fetch the defaults
    ReadSetupOptions();
    SetupFinished();
  }
}

public void ExecCfg(ConVar cvar) {
  char cfg[PLATFORM_MAX_PATH];
  cvar.GetString(cfg, sizeof(cfg));

  // for files that start with configs/c5_pug/* we just
  // read the file and execute each command individually,
  // otherwise we assume the file is in the cfg/ directory and
  // just use the game's exec command.
  if (StrContains(cfg, "configs/c5_pug") == 0) {
    char formattedPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, formattedPath, sizeof(formattedPath), cfg);
    ExecFromFile(formattedPath);
  } else {
    ServerCommand("exec \"%s\"", cfg);
  }

  if (cvar == g_LiveCfgCvar) {
    Call_StartForward(g_hOnLiveCfg);
    Call_Finish();
  } else if (cvar == g_WarmupCfgCvar) {
    Call_StartForward(g_hOnWarmupCfg);
    Call_Finish();
  } else if (cvar == g_PostGameCfgCvar) {
    Call_StartForward(g_hOnPostGameCfg);
    Call_Finish();
  }
}

public void ExecFromFile(const char[] path) {
  if (FileExists(path)) {
    File file = OpenFile(path, "r");
    if (file != null) {
      char buffer[256];
      while (!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer))) {
        ServerCommand(buffer);
      }
      delete file;
    } else {
      LogError("Failed to open config file for reading: %s", path);
    }
  } else {
    LogError("Config file does not exist: %s", path);
  }
}

stock void UpdateClanTag(int client, bool strip = false) {
  if (IsPlayer(client) && GetClientTeam(client) != CS_TEAM_NONE) {
    if (!g_SavedClanTag[client]) {
      CS_GetClientClanTag(client, g_ClanTag[client], CLANTAG_LENGTH);
      g_SavedClanTag[client] = true;
    }

    // don't bother with crazy things when the plugin isn't active
    if (g_GameState == GameState_Live || g_GameState == GameState_None || strip) {
      RestoreClanTag(client);
      return;
    }

    int team = GetClientTeam(client);
    if (team == CS_TEAM_CT || team == CS_TEAM_T) {
      char tag[32];
      if (g_Ready[client]) {
        Format(tag, sizeof(tag), "%T", "Ready", LANG_SERVER);
      } else {
        Format(tag, sizeof(tag), "%T", "NotReady", LANG_SERVER);
      }
      CS_SetClientClanTag(client, tag);
    } else {
      RestoreClanTag(client);
    }
  }
}

// Restores the clan tag to a client's original setting, or the empty string if it was never saved.
public void RestoreClanTag(int client) {
  if (g_SavedClanTag[client]) {
    CS_SetClientClanTag(client, g_ClanTag[client]);
  } else {
    CS_SetClientClanTag(client, "");
  }
}

public void ChangeState(GameState state) {
  Call_StartForward(g_hOnStateChange);
  Call_PushCell(g_GameState);
  Call_PushCell(state);
  Call_Finish();
  g_GameState = state;
}

stock bool TeamTypeFromString(const char[] teamTypeString, TeamType& teamType,
                              bool logError = false) {
  if (StrEqual(teamTypeString, "captains", false) || StrEqual(teamTypeString, "captain", false)) {
    teamType = TeamType_Captains;
  } else if (StrEqual(teamTypeString, "manual", false)) {
    teamType = TeamType_Manual;
  } else if (StrEqual(teamTypeString, "random", false)) {
    teamType = TeamType_Random;
  } else if (StrEqual(teamTypeString, "autobalanced", false) ||
             StrEqual(teamTypeString, "balanced", false)) {
    teamType = TeamType_Autobalanced;
  } else {
    if (logError)
      LogError(
          "Invalid team type: \"%s\", allowed values: \"captains\", \"manual\", \"random\", \"autobalanced\"",
          teamTypeString);
    return false;
  }

  return true;
}

stock bool MapTypeFromString(const char[] mapTypeString, MapType& mapType, bool logError = false) {
  if (StrEqual(mapTypeString, "current", false)) {
    mapType = MapType_Current;
  } else if (StrEqual(mapTypeString, "vote", false)) {
    mapType = MapType_Vote;
  } else if (StrEqual(mapTypeString, "veto", false)) {
    mapType = MapType_Veto;
  } else {
    if (logError)
      LogError("Invalid map type: \"%s\", allowed values: \"current\", \"vote\", \"veto\"",
               mapTypeString);
    return false;
  }

  return true;
}

stock bool PermissionFromString(const char[] permissionString, Permission& p,
                                bool logError = false) {
  if (StrEqual(permissionString, "all", false) || StrEqual(permissionString, "any", false)) {
    p = Permission_All;
  } else if (StrEqual(permissionString, "captains", false) ||
             StrEqual(permissionString, "captain", false)) {
    p = Permission_Captains;
  } else if (StrEqual(permissionString, "leader", false)) {
    p = Permission_Leader;
  } else if (StrEqual(permissionString, "admin", false)) {
    p = Permission_Admin;
  } else if (StrEqual(permissionString, "none", false)) {
    p = Permission_None;
  } else {
    if (logError)
      LogError(
          "Invalid permission type: \"%s\", allowed values: \"all\", \"captain\", \"leader\", \"admin\", \"none\"",
          permissionString);
    return false;
  }

  return true;
}
