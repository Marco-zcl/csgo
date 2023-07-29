#include <cstrike>
#include <sourcemod>

#include "include/c5_pug.inc"
#include "include/c5.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

int g_DamageDone[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_DamageDoneHits[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_GotKill[MAXPLAYERS + 1][MAXPLAYERS + 1];

public Plugin myinfo = {
    name = "C5: pug - damageprint",
    author = "Bone",
    description = "Writes out player damage on round end or when .dmg is used",
    version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart() {
  LoadTranslations("c5.pug.damageprint.phrases");

  HookEvent("round_start", Event_RoundStart);
  HookEvent("player_hurt", Event_DamageDealt, EventHookMode_Pre);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
}

static void PrintDamageInfo(int client) {
  if (!IsValidClient(client))
    return;

  int team = GetClientTeam(client);
  if (team != CS_TEAM_T && team != CS_TEAM_CT)
    return;

  char message[256];

  int otherTeam = (team == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && GetClientTeam(i) == otherTeam) {
      int health = IsPlayerAlive(i) ? GetClientHealth(i) : 0;
      char name[64];
      GetClientName(i, name, sizeof(name));

      Format(message, sizeof(message), "%T", "DamageprintFormat", client);

      ReplaceStringWithColoredInt(message, sizeof(message), "{DMG_TO}", g_DamageDone[client][i], "GREEN");
      ReplaceStringWithColoredInt(message, sizeof(message), "{HITS_TO}", g_DamageDoneHits[client][i], "GREEN");
      ReplaceStringWithColoredInt(message, sizeof(message), "{DMG_FROM}", g_DamageDone[i][client], "GREEN");
      ReplaceStringWithColoredInt(message, sizeof(message), "{HITS_FROM}", g_DamageDoneHits[i][client], "GREEN");
      ReplaceStringWithColoredInt(message, sizeof(message), "{HEALTH}", health, "GREEN");
      ReplaceStringWithColored(message, sizeof(message), "{NAME}", name, g_GotKill[client][i] ? "DARK_RED" : "GREEN");

      C5_Message(client, message);
    }
  }
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  if (!C5_PUG_IsMatchLive())
    return;

  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i)) {
      PrintDamageInfo(i);
    }
  }
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  for (int i = 1; i <= MaxClients; i++) {
    for (int j = 1; j <= MaxClients; j++) {
      g_DamageDone[i][j] = 0;
      g_DamageDoneHits[i][j] = 0;
      g_GotKill[i][j] = false;
    }
  }
}

public Action Event_DamageDealt(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));
  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);

  if (validAttacker && validVictim) {
    int preDamageHealth = GetClientHealth(victim);
    int damage = event.GetInt("dmg_health");
    int postDamageHealth = event.GetInt("health");

    // this maxes the damage variables at 100,
    // so doing 50 damage when the player had 2 health
    // only counts as 2 damage.
    if (postDamageHealth == 0) {
      damage += preDamageHealth;
    }

    g_DamageDone[attacker][victim] += damage;
    g_DamageDoneHits[attacker][victim]++;
  }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));
  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);

  if (validAttacker && validVictim) {
    g_GotKill[attacker][victim] = true;
  }
}
