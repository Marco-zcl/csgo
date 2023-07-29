bool g_EnableFriendlyFire = true;

public int FriendlyFireMenuHandler(Menu menu, MenuAction action, int param1, int selection)
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
        C5_MessageToAll("%T", "FriendlyFireVoteOn", LANG_SERVER, client);
      }
      else if(StrEqual(info, "off"))
      {
        C5_MessageToAll("%T", "FriendlyFireVoteOff", LANG_SERVER, client);
      }
    }
    case MenuAction_VoteCancel, MenuAction_VoteEnd:
    {
      int res = 1;
      if (action == MenuAction_VoteCancel)
      {
        C5_MessageToAll("%T", "FriendlyFireRandomly", LANG_SERVER);
        res = GetRandomInt(0, 1);
      }
      else
      {
        int result = param1;
        char info[5];
        menu.GetItem(result, info, sizeof(info));
        res = StrEqual(info, "on") ? 1 : 0;
      }

      if (res == 1)
      {
        C5_MessageToAll("%T", "FriendlyFireEndOn", LANG_SERVER);
        g_EnableFriendlyFire = true;
      }
      else
      {
        C5_MessageToAll("%T", "FriendlyFireEndOff", LANG_SERVER);
        g_EnableFriendlyFire = false;
      }
      // getting start
      CreateCountDown();
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}

	return 0;
}

void DisplayFriendlyFireVoteMenu()
{
  Menu menu = new Menu(FriendlyFireMenuHandler);
  menu.SetTitle("请选择是否需要队友伤害");
  menu.AddItem("on", "需要队友伤害");
  menu.AddItem("off", "不需要队友伤害");
  menu.ExitButton = false;

  VoteMenuToMatchPlayer(menu, 10);
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  if (!g_EnableFriendlyFire)
  {
    if (IsValidClient(attacker) || attacker == victim || weapon < 1)
    {
      return Plugin_Continue;
    }
    
    if (GetClientTeam(victim) == GetClientTeam(attacker))
    {
      return Plugin_Handled;
    }
    
    return Plugin_Continue;
  }

  return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
  UnHookOnTakeDamage(client);
}

public void OnClientPutInServer(int client)
{
  HookOnTakeDamage(client);
}

void HookOnTakeDamage(int client)
{
  if (!IsValidClient(client)) return;
  SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

void UnHookOnTakeDamage(int client)
{
  if (!IsValidClient(client)) return;
  SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}