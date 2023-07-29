#include <sourcemod>
#include <cstrike>
#include <sdktools>

#include "include/c5.inc"
#include "c5/util.sp"

#pragma semicolon 1
#pragma newdecls required

ConVar g_MessagePrefix;

#include "c5/natives.sp"

public Plugin myinfo =
{
	name = "C5",
	author = "Bone",
	description = ".",
	version = "1.0",
	url = "https://bonetm.github.io/"
};

public void OnPluginStart()
{
	g_MessagePrefix = CreateConVar("sm_c5_message_prefix", "[{GREEN}C5{NORMAL}]", "message prefix");
  	AutoExecConfig(true, "c5", "sourcemod/c5");
}
