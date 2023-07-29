#define CHECK_CLIENT(%1)  \
  if (!IsValidClient(%1)) \
  ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", %1)
#define CHECK_CAPTAIN(%1)  \
  if (%1 != 1 && %1 != 2) \
  ThrowNativeError(SP_ERROR_PARAM, "Captain number %d is not valid", %1)
#define CHECK_COMMAND(%1)           \
  if (!C5_PUG_IsValidCommand(%1)) \
  ThrowNativeError(SP_ERROR_PARAM, "C5_PUG command %s is not valid", %1)

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  g_ChatAliases = new ArrayList(ALIAS_LENGTH);
  g_ChatAliasesCommands = new ArrayList(COMMAND_LENGTH);
  g_ChatAliasesModes = new ArrayList();

  g_MapList = new ArrayList(PLATFORM_MAX_PATH);
  g_PermissionsMap = new StringMap();

  CreateNative("C5_PUG_SetupGame", Native_SetupGame);
  CreateNative("C5_PUG_SetSetupOptions", Native_SetSetupOptions);
  CreateNative("C5_PUG_GetSetupOptions", Native_GetSetupOptions);
  CreateNative("C5_PUG_ReadyPlayer", Native_ReadyPlayer);
  CreateNative("C5_PUG_UnreadyPlayer", Native_UnreadyPlayer);
  CreateNative("C5_PUG_IsReady", Native_IsReady);
  CreateNative("C5_PUG_IsSetup", Native_IsSetup);
  CreateNative("C5_PUG_GetTeamType", Native_GetTeamType);
  CreateNative("C5_PUG_GetMapType", Native_GetMapType);
  CreateNative("C5_PUG_GetGameState", Native_GetGameState);
  CreateNative("C5_PUG_IsMatchLive", Native_IsMatchLive);
  CreateNative("C5_PUG_IsPendingStart", Native_IsPendingStart);
  CreateNative("C5_PUG_IsWarmup", Native_IsWarmup);
  CreateNative("C5_PUG_SetLeader", Native_SetLeader);
  CreateNative("C5_PUG_GetLeader", Native_GetLeader);
  CreateNative("C5_PUG_GetCaptain", Native_GetCaptain);
  CreateNative("C5_PUG_SetCaptain", Native_SetCaptain);
  CreateNative("C5_PUG_GetPugMaxPlayers", Native_GetPugMaxPlayers);
  CreateNative("C5_PUG_PlayerAtStart", Native_PlayerAtStart);
  CreateNative("C5_PUG_IsPugAdmin", Native_IsPugAdmin);
  CreateNative("C5_PUG_HasPermissions", Native_HasPermissions);
  CreateNative("C5_PUG_SetRandomCaptains", Native_SetRandomCaptains);
  CreateNative("C5_PUG_AddChatAlias", Native_AddChatAlias);
  CreateNative("C5_PUG_GiveSetupMenu", Native_GiveSetupMenu);
  CreateNative("C5_PUG_GiveMapChangeMenu", Native_GiveMapChangeMenu);
  CreateNative("C5_PUG_IsValidCommand", Native_IsValidCommand);
  CreateNative("C5_PUG_GetPermissions", Native_GetPermissions);
  CreateNative("C5_PUG_SetPermissions", Native_SetPermissions);
  CreateNative("C5_PUG_IsTeamBalancerAvaliable", Native_IsTeamBalancerAvaliable);
  CreateNative("C5_PUG_SetTeamBalancer", Native_SetTeamBalancer);
  CreateNative("C5_PUG_ClearTeamBalancer", Native_ClearTeamBalancer);
  CreateNative("C5_PUG_IsDecidedMap", Native_IsDecidedMap);
  CreateNative("C5_PUG_IsClientInAuths", Native_IsClientInAuths);
  CreateNative("C5_PUG_ClearAuths", Native_ClearAuths);
  RegPluginLibrary("c5_pug");
  return APLRes_Success;
}

public int Native_SetupGame(Handle plugin, int numParams) {
  g_TeamType = view_as<TeamType>(GetNativeCell(1));
  g_MapType = view_as<MapType>(GetNativeCell(2));
  g_PlayersPerTeam = GetNativeCell(3);

  // optional parameters added, checking is they were
  // passed for backwards compatibility
  if (numParams >= 4) {
    g_RecordGameOption = GetNativeCell(4);
  }

  if (numParams >= 5) {
    g_DoKnifeRound = GetNativeCell(5);
  }

  SetupFinished();
}

public int Native_GetSetupOptions(Handle plugin, int numParams) {
  if (!C5_PUG_IsSetup()) {
    ThrowNativeError(SP_ERROR_ABORTED, "Cannot get setup options when a match is not setup.");
  }

  SetNativeCellRef(1, g_TeamType);
  SetNativeCellRef(2, g_MapType);
  SetNativeCellRef(3, g_PlayersPerTeam);
  SetNativeCellRef(4, g_RecordGameOption);
  SetNativeCellRef(5, g_DoKnifeRound);
}

public int Native_SetSetupOptions(Handle plugin, int numParams) {
  g_TeamType = view_as<TeamType>(GetNativeCell(1));
  g_MapType = view_as<MapType>(GetNativeCell(2));
  g_PlayersPerTeam = GetNativeCell(3);
  g_RecordGameOption = GetNativeCell(4);
  g_DoKnifeRound = GetNativeCell(5);
}

public int Native_ReadyPlayer(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);

  bool replyMessages = true;
  // Backwards compatability check.
  if (numParams >= 2) {
    replyMessages = GetNativeCell(2);
  }

  if (g_GameState != GameState_Warmup || !IsPlayer(client))
    return false;

  if (GetClientTeam(client) == CS_TEAM_SPECTATOR) {
    if (replyMessages)
      C5_Message(client, "%t", "SpecCantReady");
    return false;
  }

  // already ready
  if (g_Ready[client]) {
    return false;
  }

  Call_StartForward(g_hOnReady);
  Call_PushCell(client);
  Call_Finish();

  g_Ready[client] = true;
  UpdateClanTag(client);

  if (g_EchoReadyMessagesCvar.IntValue != 0 && replyMessages) {
    C5_MessageToAll("%t", "IsNowReady", client);
  }

  return true;
}

public int Native_UnreadyPlayer(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);

  if (g_GameState != GameState_Warmup || !IsPlayer(client))
    return false;

  // already un-ready
  if (!g_Ready[client]) {
    return false;
  }

  Call_StartForward(g_hOnUnready);
  Call_PushCell(client);
  Call_Finish();

  g_Ready[client] = false;
  UpdateClanTag(client);

  if (g_EchoReadyMessagesCvar.IntValue != 0) {
    C5_MessageToAll("%t", "IsNoLongerReady", client);
  }

  return true;
}

public int Native_IsReady(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);
  if (!IsClientInGame(client) || IsFakeClient(client))
    return false;

  return g_Ready[client] && OnActiveTeam(client);
}

public int Native_IsSetup(Handle plugin, int numParams) {
  return g_GameState >= GameState_Warmup;
}

public int Native_GetMapType(Handle plugin, int numParams) {
  return view_as<int>(g_MapType);
}

public int Native_GetTeamType(Handle plugin, int numParams) {
  return view_as<int>(g_TeamType);
}

public int Native_GetGameState(Handle plugin, int numParams) {
  return view_as<int>(g_GameState);
}

public int Native_IsMatchLive(Handle plugin, int numParams) {
  return g_GameState == GameState_Live;
}

public int Native_IsPendingStart(Handle plugin, int numParams) {
  return g_GameState >= GameState_PickingPlayers && g_GameState <= GameState_GoingLive;
}

public int Native_IsWarmup(Handle plugin, int numParams) {
  return g_GameState == GameState_Warmup;
}

public int Native_SetLeader(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);

  if (IsPlayer(client)) {
    C5_MessageToAll("%t", "NewLeader", client);
    g_Leader = client;
  }
}

public int Native_GetLeader(Handle plugin, int numParams) {
  // first check if our "leader" is still connected
  if (g_Leader > 0 && IsClientConnected(g_Leader) && !IsFakeClient(g_Leader))
    return g_Leader;

  if (numParams >= 1) {
    bool doReassign = GetNativeCell(1);
    if (!doReassign)
      return -1;
  }

  // then check if we have someone with admin permissions
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && C5_PUG_IsPugAdmin(i)) {
      g_Leader = i;
      return i;
    }
  }

  // otherwise fall back to a random player
  int r = RandomPlayer();
  if (IsPlayer(r))
    g_Leader = r;

  return r;
}

public int Native_SetCaptain(Handle plugin, int numParams) {
  int captainNumber = GetNativeCell(1);
  CHECK_CAPTAIN(captainNumber);

  int client = GetNativeCell(2);
  CHECK_CLIENT(client);

  bool printIfSame = false;
  // backwards compatability
  if (numParams >= 3) {
    printIfSame = GetNativeCell(3);
  }

  if (IsPlayer(client)) {
    int originalCaptain = -1;
    if (captainNumber == 1) {
      originalCaptain = g_capt1;
      g_capt1 = client;
    } else {
      originalCaptain = g_capt2;
      g_capt2 = client;
    }

    // Only printout if it's a different captain
    if (printIfSame || client != originalCaptain) {
      char buffer[64];
      FormatPlayerName(client, client, buffer);
      C5_MessageToAll("%t", "CaptMessage", captainNumber, buffer);
    }
  }
}

public int Native_GetCaptain(Handle plugin, int numParams) {
  int captainNumber = GetNativeCell(1);
  CHECK_CAPTAIN(captainNumber);

  int capt = (captainNumber == 1) ? g_capt1 : g_capt2;

  if (IsValidClient(capt) && !IsFakeClient(capt))
    return capt;
  else
    return -1;
}

public int Native_GetPugMaxPlayers(Handle plugin, int numParams) {
  return 2 * g_PlayersPerTeam;
}

public int Native_PlayerAtStart(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  return IsPlayer(client) && g_PlayerAtStart[client];
}

public int Native_IsPugAdmin(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);

  AdminId admin = GetUserAdmin(client);
  if (admin != INVALID_ADMIN_ID) {
    char flags[8];
    AdminFlag flag;
    g_AdminFlagCvar.GetString(flags, sizeof(flags));
    if (!FindFlagByChar(flags[0], flag)) {
      LogError("Invalid immunity flag: %s", flags[0]);
      return false;
    } else {
      return GetAdminFlag(admin, flag);
    }
  }

  return false;
}

public int Native_HasPermissions(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client == 0)
    return true;

  CHECK_CLIENT(client);

  bool allowLeaderReassignment = true;
  if (numParams >= 3)
    allowLeaderReassignment = GetNativeCell(3);

  Permission p = view_as<Permission>(GetNativeCell(2));
  bool isAdmin = C5_PUG_IsPugAdmin(client);
  bool isLeader = C5_PUG_GetLeader(allowLeaderReassignment) == client;
  bool isCapt = (client == g_capt1) || (client == g_capt2);

  if (p == Permission_Admin)
    return isAdmin;
  else if (p == Permission_Leader)
    return isLeader || isAdmin;
  else if (p == Permission_Captains && UsingCaptains())
    return isCapt || isLeader || isAdmin;
  else if (p == Permission_All)
    return true;
  else if (p == Permission_None)
    return false;
  else
    ThrowNativeError(SP_ERROR_PARAM, "Unknown permission value: %d", p);

  return false;
}

public int Native_SetRandomCaptains(Handle plugin, int numParams) {
  int c1 = -1;
  int c2 = -1;

  c1 = RandomPlayer();
  while (!IsPlayer(c2) || c1 == c2) {
    if (GetRealClientCount() < 2)
      break;

    c2 = RandomPlayer();
  }

  if (IsPlayer(c1))
    C5_PUG_SetCaptain(1, c1, true);

  if (IsPlayer(c2))
    C5_PUG_SetCaptain(2, c2, true);
}

public int Native_AddChatAlias(Handle plugin, int numParams) {
  char alias[ALIAS_LENGTH];
  char command[COMMAND_LENGTH];
  GetNativeString(1, alias, sizeof(alias));
  GetNativeString(2, command, sizeof(command));

  ChatAliasMode mode = ChatAlias_Always;
  if (numParams >= 3) {
    mode = GetNativeCell(3);
  }

  // don't allow duplicate aliases to be added
  if (g_ChatAliases.FindString(alias) == -1) {
    g_ChatAliases.PushString(alias);
    g_ChatAliasesCommands.PushString(command);
    g_ChatAliasesModes.Push(mode);
  }
}

public int Native_GiveSetupMenu(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);
  bool displayOnly = GetNativeCell(2);

  // backwards compatability
  int menuPosition = -1;
  if (numParams >= 3) {
    menuPosition = GetNativeCell(3);
  }

  SetupMenu(client, displayOnly, menuPosition);
}

public int Native_GiveMapChangeMenu(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  CHECK_CLIENT(client);
  ChangeMapMenu(client);
}

public int Native_IsValidCommand(Handle plugin, int numParams) {
  char command[COMMAND_LENGTH];
  GetNativeString(1, command, sizeof(command));
  return g_Commands.FindString(command) != -1;
}

public int Native_GetPermissions(Handle plugin, int numParams) {
  char command[COMMAND_LENGTH];
  GetNativeString(1, command, sizeof(command));
  CHECK_COMMAND(command);

  Permission p;
  g_PermissionsMap.GetValue(command, p);
  return view_as<int>(p);
}

public int Native_SetPermissions(Handle plugin, int numParams) {
  char command[COMMAND_LENGTH];
  GetNativeString(1, command, sizeof(command));
  CHECK_COMMAND(command);

  Permission p = GetNativeCell(2);
  return g_PermissionsMap.SetValue(command, p);
}

public int Native_IsTeamBalancerAvaliable(Handle plugin, int numParams) {
  return g_BalancerFunction != INVALID_FUNCTION &&
         GetPluginStatus(g_BalancerFunctionPlugin) == Plugin_Running;
}

public int Native_SetTeamBalancer(Handle plugin, int numParams) {
  bool override = GetNativeCell(2);
  if (!C5_PUG_IsTeamBalancerAvaliable() || override) {
    g_BalancerFunctionPlugin = plugin;
    g_BalancerFunction = view_as<TeamBalancerFunction>(GetNativeFunction(1));
    return true;
  }
  return false;
}

public int Native_ClearTeamBalancer(Handle plugin, int numParams) {
  bool hadBalancer = C5_PUG_IsTeamBalancerAvaliable();
  g_BalancerFunction = INVALID_FUNCTION;
  g_BalancerFunctionPlugin = INVALID_HANDLE;
  return hadBalancer;
}

public int Native_IsDecidedMap(Handle plugin, int numParams) {
  return g_OnDecidedMap;
}

public int Native_IsClientInAuths(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  char auth[64];
  GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

  return g_auths.FindString(auth) != -1;
}

public int Native_ClearAuths(Handle plugin, int numParams) {
  g_auths.Clear();
}