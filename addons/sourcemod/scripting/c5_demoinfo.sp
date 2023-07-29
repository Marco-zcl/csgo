#include <sourcemod>
#include <c5_pug>
#include <restorecvars>

ConVar gc_DownloadUrl;
Database g_Database = null;
int g_MatchID;

public Plugin myinfo = {
	name = "C5 - Demo Info",
	author = "Xc_ace",	
	description = "Upload demo info",
	version = "1.0",
	url = "https://cncsgo.com.cn"
}

public void OnPluginStart(){
	gc_DownloadUrl = CreateConVar("sm_pugsetup_demo_downloadurl", "", "Download Server Url");
	AutoExecConfig(true, "c5_demo");
	char szError[512];
	g_Database = SQL_Connect("c5_demo", true, szError, sizeof(szError));
	if (g_Database == null)
	{
		SetFailState("Can't connect to database, Error:%s", szError);
	}
	g_Database.SetCharset("utf8mb4");
	
	ExecuteAndSaveCvars("sourcemod/c5_demo.cfg");
}

public void C5_Pug_OnLive(){
	Transaction t = SQL_CreateTransaction();
  	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	char query[256];
  	Format(query, sizeof(query), "INSERT INTO info (start_time, map) VALUES (NOW(), '%s')", map);
  	g_Database.Query(SQL_CheckForErrors, query);

  	g_Database.Execute(t, MatchInitSuccess, MatchInitFailure);
}

public void C5_Pug_OnMatchOver(bool hasDemo, const char [] demoFileName){
	if (hasDemo){
		char query[256];
		char url[256];
		GetConVarString(gc_DownloadUrl, url, sizeof(url));
		Format(query, sizeof(query), "UPDATE info SET end_time=NOW(), demoName='%s', DownloadUrl='%s/%s' WHERE match_id='%i'", demoFileName, url, demoFileName, g_MatchID);
		g_Database.Query(SQL_CheckForErrors, query);
	}
}

public void SQL_CheckForErrors(Database db, DBResultSet results, const char[] error, any data)
{
	if (!StrEqual(error, ""))
	{
		LogError("Database error, %s", error);
		return;
	}
}

public void MatchInitSuccess(Database database, any data, int numQueries, DBResultSet[] results, any[] queryData) {
  	DBResultSet matchidResult = results[1];
  	if (matchidResult.FetchRow()) {
  		g_MatchID = matchidResult.FetchInt(0);
 	} else {
    	LogError("Failed to get matchid from match init query");
  	}
}

public void MatchInitFailure(Database database, any data, int numQueries, const char[] error, int failIndex, any[] queryData) {
  	LogError("Failed match creation query, error = %s", error);
}