/**
 * Main .setup menu
 */
public void SetupMenu(int client, bool displayOnly, int menuPosition) {
  Menu menu = new Menu(SetupMenuHandler);
  menu.SetTitle("%T", "SetupMenuTitle", client);
  menu.ExitButton = true;

  int style = ITEMDRAW_DEFAULT;
  if ((g_ForceDefaultsCvar.IntValue != 0 && !C5_PUG_IsPugAdmin(client)) || displayOnly) {
    style = ITEMDRAW_DISABLED;
  }

  char buffer[256];

  if (g_GameState == GameState_None) {
    char finishSetupStr[128];
    Format(finishSetupStr, sizeof(finishSetupStr), "%T", "FinishSetup", client);
    AddMenuItem(menu, "finish_setup", finishSetupStr, style);
  } else {
    char finishSetupStr[128];
    Format(finishSetupStr, sizeof(finishSetupStr), "%T", "CancelSetup", client);
    AddMenuItem(menu, "cancel_setup", finishSetupStr, style);
  }

  // first do a sanity check if an autobalancer is avaliable
  if (g_TeamType == TeamType_Autobalanced && !C5_PUG_IsTeamBalancerAvaliable()) {
    g_TeamType = TeamType_Random;
  }

  // 1. team type
  if (g_DisplayTeamType) {
    char teamType[128];
    GetTeamString(teamType, sizeof(teamType), g_TeamType, client);
    Format(buffer, sizeof(buffer), "%T: %s", "TeamTypeOption", client, teamType);
    AddMenuItem(menu, "teamtype", buffer, style);
  }

  // 2. team size
  if (g_DisplayTeamSize) {
    Format(buffer, sizeof(buffer), "%T: %d", "TeamSizeOption", client, g_PlayersPerTeam);
    AddMenuItem(menu, "teamsize", buffer, style);
  }

  // 3. map type
  if (g_DisplayMapType) {
    char mapType[128];
    GetMapString(mapType, sizeof(mapType), g_MapType, client);
    Format(buffer, sizeof(buffer), "%T: %s", "MapTypeOption", client, mapType);
    AddMenuItem(menu, "maptype", buffer, style);
  }

  // 4. demo option
  if (g_DisplayRecordDemo && IsTVEnabled()) {
    char enabledString[128];
    GetEnabledString(enabledString, sizeof(enabledString), g_RecordGameOption, client);
    Format(buffer, sizeof(buffer), "%T: %s", "DemoOption", client, enabledString);
    AddMenuItem(menu, "demo", buffer, style);
  }

  // 5. knife round option
  if (g_DisplayKnifeRound) {
    char enabledString[128];
    GetEnabledString(enabledString, sizeof(enabledString), g_DoKnifeRound, client);
    Format(buffer, sizeof(buffer), "%T: %s", "KnifeRoundOption", client, enabledString);
    AddMenuItem(menu, "knife", buffer, style);
  }

  // 8. set captains
  if (g_GameState == GameState_Warmup && UsingCaptains()) {
    Format(buffer, sizeof(buffer), "%T", "SetCaptainsMenuOption", client);
    AddMenuItem(menu, "set_captains", buffer, style);
  }

  // 10. change map
  if (g_DisplayMapChange) {
    Format(buffer, sizeof(buffer), "%T", "ChangeMapMenuOption", client);
    AddMenuItem(menu, "change_map", buffer, style);
  }

  Action action = Plugin_Continue;
  Call_StartForward(g_hOnSetupMenuOpen);
  Call_PushCell(client);
  Call_PushCell(menu);
  Call_PushCell(displayOnly);
  Call_Finish(action);

  if (action == Plugin_Continue) {
    if (menuPosition == -1) {
      DisplayMenu(menu, client, MENU_TIME_FOREVER);
    } else {
      DisplayMenuAtItem(menu, client, menuPosition, MENU_TIME_FOREVER);
    }

  } else {
    delete menu;
  }
}

public int SetupMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[128];
    menu.GetItem(param2, buffer, sizeof(buffer));
    int pos = GetMenuSelectionPosition();

    if (StrEqual(buffer, "start_match")) {
      FakeClientCommand(client, "sm_start");

    } else if (StrEqual(buffer, "maptype")) {
      MapTypeMenu(client);

    } else if (StrEqual(buffer, "teamtype")) {
      TeamTypeMenu(client);

    } else if (StrEqual(buffer, "teamsize")) {
      TeamSizeMenu(client);

    } else if (StrEqual(buffer, "demo")) {
      DemoHandler(client);

    } else if (StrEqual(buffer, "knife")) {
      g_DoKnifeRound = !g_DoKnifeRound;
      C5_PUG_GiveSetupMenu(client, false, pos);

    } else if (StrEqual(buffer, "set_captains")) {
      FakeClientCommand(client, "sm_capt");

    } else if (StrEqual(buffer, "change_map")) {
      ChangeMapMenu(client);

    } else if (StrEqual(buffer, "finish_setup")) {
      SetupFinished();

    } else if (StrEqual(buffer, "cancel_setup")) {
      FakeClientCommand(client, "sm_endgame");

    }

    Call_StartForward(g_hOnSetupMenuSelect);
    Call_PushCell(menu);
    Call_PushCell(client);
    Call_PushString(buffer);
    Call_PushCell(pos);
    Call_Finish();

  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public void TeamTypeMenu(int client) {
  Menu menu = new Menu(TeamTypeMenuHandler);
  menu.SetTitle("%T", "TeamSetupMenuTitle", client);
  menu.ExitButton = false;
  menu.ExitBackButton = true;
  AddMenuInt(menu, view_as<int>(TeamType_Captains), "%T", "TeamSetupMenuCaptains", client);
  AddMenuInt(menu, view_as<int>(TeamType_Random), "%T", "TeamSetupMenuRandom", client);
  AddMenuInt(menu, view_as<int>(TeamType_Manual), "%T", "TeamSetupMenuManual", client);
  if (C5_PUG_IsTeamBalancerAvaliable())
    AddMenuInt(menu, view_as<int>(TeamType_Autobalanced), "%T", "Autobalanced", client);

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int TeamTypeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    g_TeamType = view_as<TeamType>(GetMenuInt(menu, param2));
    C5_PUG_GiveSetupMenu(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    C5_PUG_GiveSetupMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public void TeamSizeMenu(int client) {
  Menu menu = new Menu(TeamSizeHandler);
  menu.SetTitle("%T", "HowManyPlayers", client);
  menu.ExitButton = false;
  menu.ExitBackButton = true;

  for (int i = 1; i <= 5; i++) {
    char teamSizeStr[32];
    IntToString(i, teamSizeStr, sizeof(teamSizeStr));

    AddMenuInt(menu, i, teamSizeStr);
  }

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int TeamSizeHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    g_PlayersPerTeam = GetMenuInt(menu, param2);
    C5_PUG_GiveSetupMenu(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    C5_PUG_GiveSetupMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

/**
 * Generic map choice-type menu.
 */
public void MapTypeMenu(int client) {
  Menu menu = new Menu(MapTypeHandler);
  menu.SetTitle("%T", "MapChoiceMenuTitle", client);
  menu.ExitButton = false;
  menu.ExitBackButton = true;
  AddMenuInt(menu, view_as<int>(MapType_Current), "%T", "MapChoiceCurrent", client);
  AddMenuInt(menu, view_as<int>(MapType_Vote), "%T", "MapChoiceVote", client);
  AddMenuInt(menu, view_as<int>(MapType_Veto), "%T", "MapChoiceVeto", client);
  DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MapTypeHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    g_MapType = view_as<MapType>(GetMenuInt(menu, param2));
    UpdateMapStatus();
    C5_PUG_GiveSetupMenu(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    C5_PUG_GiveSetupMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public int DemoHandler(int client) {
  g_RecordGameOption = !g_RecordGameOption;
  if (!IsTVEnabled() && g_RecordGameOption) {
    C5_Message(client, "%t", "TVDisabled");
    g_RecordGameOption = false;
  }
  C5_PUG_GiveSetupMenu(client);
}

/**
 * Called when the setup phase is over and the ready-up period should begin.
 */
public void SetupFinished() {
  ExecWarmupConfigs();

  StartWarmup(true);

  for (int i = 1; i <= MaxClients; i++) {
    g_Ready[i] = false;
    if (IsPlayer(i)) {
      PrintSetupInfo(i);
    }
  }

  // reset match state variables
  g_capt1 = -1;
  g_capt2 = -1;
  ChangeState(GameState_Warmup);
  StartLiveTimer();

  if (GetConVarInt(g_AutoRandomizeCaptainsCvar) != 0) {
    C5_PUG_SetRandomCaptains();
  }

  UpdateMapStatus();

  Call_StartForward(g_hOnSetup);
  Call_Finish();
}

public void StartLiveTimer() {
  if (!g_LiveTimerRunning)
    CreateTimer(LIVE_TIMER_INTERVAL, Timer_CheckReady, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
  g_LiveTimerRunning = true;
}

/**
 * Converts enum choice types to strings to show to players.
 */
stock void GetTeamString(char[] buffer, int length, TeamType type, int client = LANG_SERVER) {
  switch (type) {
    case TeamType_Manual:
      Format(buffer, length, "%T", "TeamSetupManualShort", client);
    case TeamType_Random:
      Format(buffer, length, "%T", "TeamSetupRandomShort", client);
    case TeamType_Captains:
      Format(buffer, length, "%T", "TeamSetupCaptainsShort", client);
    case TeamType_Autobalanced:
      Format(buffer, length, "%T", "Autobalanced", client);
    default:
      LogError("unknown teamtype=%d", type);
  }
}

stock void GetMapString(char[] buffer, int length, MapType type, int client = LANG_SERVER) {
  switch (type) {
    case MapType_Current:
      Format(buffer, length, "%T", "MapChoiceCurrentShort", client);
    case MapType_Vote:
      Format(buffer, length, "%T", "MapChoiceVoteShort", client);
    case MapType_Veto:
      Format(buffer, length, "%T", "MapChoiceVetoShort", client);
    default:
      LogError("unknown maptype=%d", type);
  }
}

static void UpdateMapStatus() {
  switch (g_MapType) {
    case MapType_Current:
      g_OnDecidedMap = true;
    case MapType_Vote:
      g_OnDecidedMap = false;
    case MapType_Veto:
      g_OnDecidedMap = false;
    default:
      LogError("unknown maptype=%d", g_MapType);
  }
}

public void ChangeMapMenu(int client) {
  Menu menu = new Menu(ChangeMapHandler);
  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.SetTitle("%T", "ChangeMapMenuTitle", client);

  for (int i = 0; i < g_MapList.Length; i++) {
    AddMapIndexToMenu(menu, g_MapList, i);
  }

  DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ChangeMapHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int choice = GetMenuInt(menu, param2);
    ChangeMap(g_MapList, choice);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    C5_PUG_GiveSetupMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
}
