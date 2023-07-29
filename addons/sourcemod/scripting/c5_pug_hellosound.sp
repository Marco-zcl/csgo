#include <sourcemod>
#include <sdktools>

#include "include/c5_pug.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

ArrayList g_list;

public Plugin myinfo =
{
    name = "C5: pug - hello sound",
	author = "Bone",
	description = ".",
	version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_hellosound", Command_Hellosound, ADMFLAG_CONFIG);

	LoadConfig();
}

public Action Command_Hellosound(int client, int args){
	if (args == 0) {
		PlayRandomSound();

	} else {
		char indexStr[10];
		GetCmdArg(1, indexStr, sizeof(indexStr));

		if (StrEqual(indexStr, "list"))
		{
			PrintSoundListToConsole(client);
		}
		else if (StrEqual(indexStr, "reload"))
		{
			ReplyToCommand(client, "reload config");
			LoadConfig();
			PrintSoundListToConsole(client);
		}
		else
		{
			int index = StringToInt(indexStr);

			if (index <= 0 || index > g_list.Length)
			{
				ReplyToCommand(client, "index not exist");
				return Plugin_Handled;
			}

			PlaySound(index - 1);
		}
	}
	
	return Plugin_Handled;
}

void LoadConfig()
{
	if (g_list != null)
	{
		delete g_list;
	}
	char filePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/hellosound.ini");

	char line[192];
	File file = OpenFile(filePath, "r");
	g_list = new ArrayList(ByteCountToCells(255));

	if(file != INVALID_HANDLE) {
		while (!file.EndOfFile()) {
			if(!file.ReadLine(line, sizeof(line))) {
				break;
			}
			
			TrimString(line);
			if(strlen(line) > 0) {
				g_list.PushString(line);
			}
		}

		file.Close();
	} else {
		LogError("[SM] no file found for config (configs/hellosound.ini)");
	}
	
	PrecacheAndAddFileToDownloadsTable();
}

void PrecacheAndAddFileToDownloadsTable()
{
	char sound[255];
	char path[125];
	for (int i = 0; i < g_list.Length; i++)
	{
		g_list.GetString(i, sound, sizeof(sound));

		Format(path, sizeof(path), "sound/%s", sound);
		AddFileToDownloadsTable(path);

		Format(path, sizeof(path), "*/%s", sound);
		PrecacheSound(path);
	}
}

void PlayRandomSound()
{
	int random = GetRandomInt(0, g_list.Length - 1);

	PlaySound(random);
}

void PlaySound(int index)
{
	char sound[255];
	g_list.GetString(index, sound, sizeof(sound));

	char path[255];
	Format(path, sizeof(path), "*/%s", sound);
	
	EmitSoundToAll(path);
}

void PrintSoundListToConsole(int client)
{
	
	PrintToConsole(client, "====================== sound list ======================");
	
	char sound[255];
	for (int i = 0; i < g_list.Length; i++)
	{
		g_list.GetString(i, sound, sizeof(sound));
		PrintToConsole(client, "%d: %s", i + 1, sound);
	}
}

public void OnMapStart()
{
	PrecacheAndAddFileToDownloadsTable();
}

public void C5_PUG_OnLive()
{
	CreateTimer(3.0, Timer_PlaySound, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PlaySound(Handle timer, any data)
{
	PlayRandomSound();
}