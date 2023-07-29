#define CHAT_ALIAS_FILE "configs/c5_pug/chataliases.cfg"
#define SETUP_OPTIONS_FILE "configs/c5_pug/setupoptions.cfg"
#define PERMISSIONS_FILE "configs/c5_pug/permissions.cfg"

public void FillMapList(const char[] fileName, ArrayList list) {
  list.Clear();

  // it's a regular map list
  GetMapList(fileName, list);

  if (list.Length == 0) {
    AddBackupMaps(list);
  }
}

/**
 * Dealing with the chat alias config file.
 */
stock void ReadChatConfig() {
  char configFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, configFile, sizeof(configFile), CHAT_ALIAS_FILE);
  KeyValues kv = new KeyValues("ChatAliases");
  if (kv.ImportFromFile(configFile) && kv.GotoFirstSubKey(false)) {
    do {
      char alias[ALIAS_LENGTH];
      char command[COMMAND_LENGTH];
      kv.GetSectionName(alias, sizeof(alias));
      kv.GetString(NULL_STRING, command, sizeof(command));
      C5_PUG_AddChatAlias(alias, command);
    } while (kv.GotoNextKey(false));
  }
  delete kv;
}

stock bool C5_PUG_AddChatAliasToFile(const char[] alias, const char[] command) {
  char configFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, configFile, sizeof(configFile), CHAT_ALIAS_FILE);
  KeyValues kv = new KeyValues("ChatAliases");
  kv.ImportFromFile(configFile);
  kv.SetString(alias, command);
  kv.Rewind();
  bool success = kv.ExportToFile(configFile);
  delete kv;
  return success;
}

stock bool RemoveChatAliasFromFile(const char[] alias) {
  char configFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, configFile, sizeof(configFile), CHAT_ALIAS_FILE);
  KeyValues kv = new KeyValues("ChatAliases");
  kv.ImportFromFile(configFile);
  kv.DeleteKey(alias);
  kv.Rewind();
  bool success = kv.ExportToFile(configFile);
  delete kv;
  return success;
}

/**
 * Dealing with the setup options config file.
 */

stock bool CheckEnabledFromString(const char[] value) {
  char strs[][] = {"true", "enabled", "1", "yes", "on", "y"};
  for (int i = 0; i < sizeof(strs); i++) {
    if (StrEqual(value, strs[i], false)) {
      return true;
    }
  }
  return false;
}

stock void ReadSetupOptions() {
  char configFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, configFile, sizeof(configFile), SETUP_OPTIONS_FILE);
  KeyValues kv = new KeyValues("SetupOptions");
  if (kv.ImportFromFile(configFile) && kv.GotoFirstSubKey()) {
    do {
      char setting[128];
      char buffer[128];
      kv.GetSectionName(setting, sizeof(setting));
      bool display = !!kv.GetNum("display_setting", 1);

      if (StrEqual(setting, "maptype", false)) {
        kv.GetString("default", buffer, sizeof(buffer), "vote");
        MapTypeFromString(buffer, g_MapType, true);
        g_DisplayMapType = display;

      } else if (StrEqual(setting, "teamtype", false)) {
        kv.GetString("default", buffer, sizeof(buffer), "captains");
        TeamTypeFromString(buffer, g_TeamType, true);
        g_DisplayTeamType = display;

      }  else if (StrEqual(setting, "kniferound", false)) {
        kv.GetString("default", buffer, sizeof(buffer), "0");
        g_DoKnifeRound = CheckEnabledFromString(buffer);
        g_DisplayKnifeRound = display;

      } else if (StrEqual(setting, "teamsize", false)) {
        g_PlayersPerTeam = kv.GetNum("default", 5);
        g_DisplayTeamSize = display;

      } else if (StrEqual(setting, "record", false)) {
        kv.GetString("default", buffer, sizeof(buffer), "0");
        g_RecordGameOption = CheckEnabledFromString(buffer);
        g_DisplayRecordDemo = display;

      } else if (StrEqual(setting, "mapchange", false)) {
        g_DisplayMapChange = display;

      } else {
        LogError("Unknown section name in %s: \"%s\"", configFile, setting);
      }

    } while (kv.GotoNextKey());
  }
  delete kv;
}

stock bool SetDefaultInFile(const char[] setting, const char[] newValue) {
  char configFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, configFile, sizeof(configFile), SETUP_OPTIONS_FILE);
  KeyValues kv = new KeyValues("SetupOptions");
  kv.ImportFromFile(configFile);
  kv.JumpToKey(setting, true);
  kv.SetString("default", newValue);
  kv.Rewind();
  bool success = kv.ExportToFile(configFile);
  delete kv;
  return success;
}

stock bool SetDisplayInFile(const char[] setting, bool display) {
  char configFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, configFile, sizeof(configFile), SETUP_OPTIONS_FILE);
  KeyValues kv = new KeyValues("SetupOptions");
  kv.ImportFromFile(configFile);
  kv.JumpToKey(setting, true);
  kv.SetNum("display_setting", display);
  kv.Rewind();
  bool success = kv.ExportToFile(configFile);
  delete kv;
  return success;
}

/**
 * Dealing with (optionally set) command permissions.
 */
stock void ReadPermissions() {
  char configFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, configFile, sizeof(configFile), PERMISSIONS_FILE);
  KeyValues kv = new KeyValues("Permissions");
  kv.ImportFromFile(configFile);

  if (kv.ImportFromFile(configFile) && kv.GotoFirstSubKey(false)) {
    do {
      char command[128];
      char permission[128];
      kv.GetSectionName(command, sizeof(command));
      kv.GetString(NULL_STRING, permission, sizeof(permission));
      if (C5_PUG_IsValidCommand(command)) {
        Permission p = Permission_All;
        if (PermissionFromString(permission, p, true)) {
          C5_PUG_SetPermissions(command, p);
        }
      } else {
        LogError("Can't assign permissions to invalid command: %s", command);
      }
    } while (kv.GotoNextKey(false));
  }

  delete kv;
}
