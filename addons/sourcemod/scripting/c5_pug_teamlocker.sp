#include <cstrike>
#include <sourcemod>

#include "include/c5_pug.inc"
#include "include/c5.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "C5: pug - team locker",
    author = "Bone",
    description = "Blocks team join events to full teams",
    version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart() {
  AddCommandListener(Command_JoinTeam, "jointeam");
}

public Action Command_JoinTeam(int client, const char[] command, int argc) {
  if (!IsValidClient(client))
    return Plugin_Stop;

  // blocks changes during team-selection/lo3-process
  if (C5_PUG_IsPendingStart())
    return Plugin_Stop;

  // don't do anything if not live/not in startup phase
  if (!C5_PUG_IsMatchLive())
    return Plugin_Continue;

  if (GetClientTeam(client) == CS_TEAM_T || GetClientTeam(client) == CS_TEAM_CT)
    return Plugin_Stop;

  char arg[4];
  GetCmdArg(1, arg, sizeof(arg));
  int team_to = StringToInt(arg);

  // don't let someone change to a "none" team (e.g. using auto-select)
  if (team_to == CS_TEAM_NONE || team_to == CS_TEAM_SPECTATOR)
    return Plugin_Stop;

  int playerCount = GetNumHumansOnTeam(team_to);

  if (playerCount >= C5_PUG_GetPugMaxPlayers() / 2) {
    return Plugin_Stop;
  } else {
    return Plugin_Continue;
  }
}

public void OnClientPutInServer(int client) {
	if (!C5_PUG_IsWarmup())
	{
		int count = GetRealClientCount();

		if (count > C5_PUG_GetPugMaxPlayers())
		{
			KickClient(client, "比赛进行中, 人员已满");
		}
	}
}
