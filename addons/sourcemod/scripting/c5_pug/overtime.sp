int g_OvertimeMenuCounter;

public int OvertimeMenuHandler(Menu menu, MenuAction action, int param1, int selection)
{
	switch(action)
	{
		case MenuAction_Select:
		{
      int client = param1;
      char info[5];
      menu.GetItem(selection, info, sizeof(info));
      if (StrEqual(info, "on"))
      {
        g_OvertimeMenuCounter++;
        C5_MessageToAll("%T", "OvertimeVoteOn", LANG_SERVER, client, g_OvertimeMenuCounter, g_PlayersPerTeam * 2);
      }
      else if(StrEqual(info, "off"))
      {
        C5_MessageToAll("%T", "OvertimeVoteOff", LANG_SERVER, client, g_OvertimeMenuCounter, g_PlayersPerTeam * 2);
      }
    }
    case MenuAction_VoteCancel, MenuAction_VoteEnd:
    {
      int res = 0;
      if (action == MenuAction_VoteCancel)
      {
        C5_MessageToAll("%T", "OvertimeDefault", LANG_SERVER);
      }
      else
      {
        int result = param1;
        char info[5];
        menu.GetItem(result, info, sizeof(info));
        res = StrEqual(info, "on") ? 1 : 0;
      }
      
      int need;
      switch(g_PlayersPerTeam * 2)
      {
        case 10:
        {
          need = 7;
        }
        case 8:
        {
          need = 6;
        }
        case 6:
        {
          need = 4;
        }
        case 4:
        {
          need = 3;
        }
        case 2:
        {
          need = 2;
        }
      }

      if (res == 1 && g_OvertimeMenuCounter >= need)
      {
        C5_MessageToAll("%T", "OvertimeEndOn", LANG_SERVER);
      }
      else
      {
        C5_MessageToAll("%T", "OvertimeEndOff", LANG_SERVER);

        if (g_GameState == GameState_Live) {
          EndMatch(true, true);

          char map[PLATFORM_MAX_PATH];
          GetCurrentMap(map, sizeof(map));
          g_PastMaps.PushString(map);
        }

        if (g_PastMaps.Length > g_ExcludedMaps.IntValue) {
          g_PastMaps.Erase(0);
        }
      }
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}

	return 0;
}

void DisplayOvertimeVoteMenu()
{
  Menu menu = new Menu(OvertimeMenuHandler);
  menu.SetTitle("请选择是否需要加时");
  menu.AddItem("on", "需要加时");
  menu.AddItem("off", "不需要加时");
  menu.ExitButton = false;
  g_OvertimeMenuCounter = 0;
  VoteMenuToMatchPlayer(menu, 10);
}