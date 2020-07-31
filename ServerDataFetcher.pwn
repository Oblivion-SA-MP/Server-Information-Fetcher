/*

       Server Data Fetcher Copyrights 2020
             Script by Oblivion


Notes:
Script uses MySQL r39-6(also Latest Version) and foreach.
Please edit the mysql_connect under OnFilterScriptInit
Tables will be automatically created when script is loaded for first time.
Load the Script along with the gamemode.(No /rcon loadfs bla bla).
  Script will print a console message after 10 seconds of server start that "Server Information Has been Updated/Inserted"
  which means it's succcess.

Issues regarding Script? You can contact me at Discord: Oblivion#6693
*/
  
#include <a_samp> 
#include <foreach> 


#define MySQL_VER_Latest (false) // make this true , if you are using latest mysql version.

#if MySQL_VER_Latest == true
  #include <a_mysql41>
#else 
  #include <a_mysql>
#endif



new svrinfo, query[150];

enum sinfo
{
  hostname[80],
  mapname[50],
  gamemodetext[100],
  version[20],
  worldtime[10],
  language[30],
  max_players,
  onlineplayers
}
new ServerInfo[sinfo];

enum pinfo
{
   score,
   name[MAX_PLAYER_NAME],
   ping,
   timer
}
new pInfo[MAX_PLAYERS][pinfo];
public OnFilterScriptInit()
{

    print("=================================== ");
    print("  Mumbai Gaming Server Data Fetcher ");
    print("          by Oblivion  - Loaded     ");
    print("=================================== ");

    #if MySQL_VER_Latest == true
     svrinfo = mysql_connect("localhost", "root", "", "configdb");
    #else 
       svrinfo = mysql_connect("localhost", "root", "configdb", "");
    #endif


    //Create tables
    CreateServerTables();
    
    ServerInfo[onlineplayers] = 0; 

    SetTimer("ExecuteQuery", 10000, false); // execute query after 10 seconds (For gameemode to load and get data from it)
    return 1;
}



public OnFilterScriptExit()
{
    print("===================================");
    print(" Mumbai Gaming Server Data Fetcher ");
    print("     by Oblivion - Unloaded        ");
    print("===================================");

    // Kill the Player Timer
    foreach(new i : Player) if(IsPlayerConnected(i)) KillTimer(pInfo[i][timer]);
    
    // Make the Online Players to default 0 and update it
    ServerInfo[onlineplayers] = 0;
    UpdatePlayerBase(ServerInfo[onlineplayers]);
    

    // Deleting all the rows in playerinfos is a good choice when script exit.
    mysql_tquery(svrinfo, "DELETE FROM `playerinfos`", " ","");
    
    // close connection
    mysql_close(svrinfo);
	  return 1;
}


// Executes 10 seconds
forward ExecuteQuery();
public ExecuteQuery()
{
  return mysql_tquery(svrinfo, "SELECT * FROM `serverconfig`", "SaveServerInfo", "" "");
}

// Insert/Update Player Info into the database
forward SaveServerInfo();
public SaveServerInfo()
{ 

    GetConsoleVarAsString("hostname", ServerInfo[hostname], sizeof(ServerInfo[hostname]));

    GetConsoleVarAsString("mapname", ServerInfo[mapname], sizeof(ServerInfo[mapname]));


    GetConsoleVarAsString("version", ServerInfo[version], sizeof(ServerInfo[version]));
    

    GetConsoleVarAsString("worldtime",ServerInfo[worldtime], sizeof(ServerInfo[worldtime]));
  
    ServerInfo[max_players] = GetConsoleVarAsInt("maxplayers");

    GetConsoleVarAsString("gamemodetext", ServerInfo[gamemodetext], sizeof(ServerInfo[gamemodetext]));

    GetConsoleVarAsString("language",ServerInfo[language], sizeof(ServerInfo[language]));

    new insertquery[800];
    if(cache_num_rows() == 0)
    {
        format(insertquery, sizeof(insertquery), "INSERT INTO `serverconfig`(`hostname`,`gameodetext`,`playersonline`, `maxplayers`, `map`, `language`, `time`, `version`)  VALUES ('%s', '%s' , %d , %d , '%s','%s','%s','%s')", ServerInfo[hostname],ServerInfo[gamemodetext],ServerInfo[onlineplayers],ServerInfo[max_players],
        ServerInfo[mapname], ServerInfo[language],ServerInfo[worldtime],ServerInfo[version]);
    } 
    else 
    { 

       format(insertquery, sizeof(insertquery), "UPDATE `serverconfig` SET `hostname`='%s',`gameodetext`='%s' ,`playersonline`=%d, `maxplayers`=%d, `map`='%s', `language`='%s', `time`='%s', `version`='%s'", 
       ServerInfo[hostname],ServerInfo[gamemodetext],ServerInfo[onlineplayers],ServerInfo[max_players],
       ServerInfo[mapname], ServerInfo[language],ServerInfo[worldtime],ServerInfo[version]);
    }
    mysql_tquery(svrinfo, insertquery,"", "");
    printf("Server Information has been Updated/Inserted!");
    return 1; 
}


public OnPlayerConnect(playerid)
{
     // Get Player Name will be usefull for searching player name in playerinfos table
     GetPlayerName(playerid, pInfo[playerid][name], MAX_PLAYER_NAME); 

     mysql_format(svrinfo, query, sizeof query, "SELECT * FROM `playerinfos` WHERE `name`='%s'",  pInfo[playerid][name]);
     mysql_tquery(svrinfo, query, "InsertPlayerInfo", "i", playerid); 
     return 1;
}


forward InsertPlayerInfo(playerid);
public  InsertPlayerInfo(playerid)
{
  
    if(cache_num_rows() == 0)
    { 
        ServerInfo[onlineplayers]++;
        UpdatePlayerBase(ServerInfo[onlineplayers]);


        format(query, sizeof(query), "INSERT INTO `playerinfos`(`id`,`name`)  VALUES (%i, '%s')", playerid, pInfo[playerid][name]);
        mysql_tquery(svrinfo, query,"", "");

        // Start Timer each 2 seconds
        pInfo[playerid][timer] = SetTimerEx("UpdatePlayerInfo", 1000, true, "i", playerid);
        return 1;
    }
   return 1;
}



public OnPlayerDisconnect(playerid, reason)
{
   // detect if player is connected!
   if(IsPlayerConnected(playerid))
   {
      KillTimer(pInfo[playerid][timer]);

      ServerInfo[onlineplayers]--;
      UpdatePlayerBase(ServerInfo[onlineplayers]);

      // We don't need that playerid anymore.
   
      mysql_format(svrinfo, query, sizeof query, "DELETE FROM `playerinfos` WHERE `name`='%s'", pInfo[playerid][name]);
      mysql_tquery(svrinfo, query, "", ""); 
   }
   return 1;
}

forward UpdatePlayerInfo(playerid);
public UpdatePlayerInfo(playerid)
{
    // stop execution if player is not connected!
    if(!IsPlayerConnected(playerid))
    {
       return 1;
    }
    pInfo[playerid][score] = GetPlayerScore(playerid);
    pInfo[playerid][ping] = GetPlayerPing(playerid);

 
    mysql_format(svrinfo, query, sizeof query, "UPDATE  `playerinfos` SET `score`=%d ,`ping`=%d WHERE `name`='%s'", pInfo[playerid][score],  pInfo[playerid][ping], pInfo[playerid][name]);
    mysql_tquery(svrinfo, query, "", ""); 
    return 1;
}

stock CreateServerTables()
{

   // Server Config Table
   new tableconfig[500];
   strcat(tableconfig, "CREATE TABLE IF NOT EXISTS `serverconfig`");
   strcat(tableconfig, "( `hostname` VARCHAR(80) NOT NULL , `gameodetext` VARCHAR(100) NOT NULL , `playersonline` INT(11) NOT NULL,");
   strcat(tableconfig, "`maxplayers` INT(10) NOT NULL , `map` VARCHAR(50) NOT NULL , `language` VARCHAR(30) NOT NULL , `time` VARCHAR(10) NOT NULL ,");
   strcat(tableconfig, "`version` VARCHAR(20) NOT NULL ) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4;");
   mysql_tquery(svrinfo, tableconfig, "", "");

   // player info table
   mysql_tquery(svrinfo,"CREATE TABLE IF NOT EXISTS `playerinfos` (\
  `id` int(11) DEFAULT 0,\
  `name` varchar(24) DEFAULT NULL,\
  `score` int(11)  NOT NULL DEFAULT '0',\
  `ping` int(11) NOT NULL  DEFAULT '0'\
   ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", "","");
   return 1;
}

// Updates onlineplayers count in ServerConfigs
stock UpdatePlayerBase(playerbase)
{
  mysql_format(svrinfo, query, sizeof query, "UPDATE `serverconfig` SET `playersonline`=%d", playerbase);
  mysql_tquery(svrinfo, query, "", ""); 
  return 1;
}