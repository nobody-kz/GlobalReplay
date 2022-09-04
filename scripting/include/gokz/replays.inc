/*
	gokz-replays Plugin Include
	
	Website: https://bitbucket.org/kztimerglobalteam/gokz
*/

#if defined _gokz_replays_included_
#endinput
#endif
#define _gokz_replays_included_

// Bit of a hack, but need it for other plugins that depend on replays to compile
#if defined REQUIRE_PLUGIN
#undef REQUIRE_PLUGIN
#include <gokz/anticheat>
#define REQUIRE_PLUGIN
#else
#include <gokz/anticheat>
#endif


// =====[ CONSTANTS ]=====

#define RP_DIRECTORY "data/gokz-replays" // In Path_SM
#define RP_DIRECTORY_RUNS "data/gokz-replays/_runs" // In Path_SM
#define RP_DIRECTORY_CHEATERS "data/gokz-replays/_cheaters" // In Path_SM
#define RP_DIRECTORY_JUMPS "data/gokz-replays/_jumps" // In Path_SM
#define RP_DIRECTORY_BLOCKJUMPS "blocks"
#define RP_FILE_EXTENSION "replay"
#define RP_MAGIC_NUMBER 0x676F6B7A
#define RP_FORMAT_VERSION 0x02
#define RP_NAV_FILE "maps/gokz-replays.nav"
#define RP_V1_TICK_DATA_BLOCKSIZE 7
#define RP_CACHE_BLOCKSIZE 4
#define RP_MAX_BOTS 2
#define RP_PLAYBACK_BREATHER_TIME 2.0
#define RP_MIN_CHEATER_REPLAY_LENGTH 30 // 30 seconds
#define RP_MAX_CHEATER_REPLAY_LENGTH 120 // 2 minutes
#define RP_MAX_BHOP_GROUND_TICKS 5
#define RP_SKIP_TIME 10 // 10 seconds


#define RP_MOVETYPE_MASK		(0xF)
#define RP_IN_ATTACK			(1 << 4)
#define RP_IN_ATTACK2			(1 << 5)
#define RP_IN_JUMP				(1 << 6)
#define RP_IN_DUCK				(1 << 7)
#define RP_IN_FORWARD			(1 << 8)
#define RP_IN_BACK				(1 << 9)
#define RP_IN_LEFT				(1 << 10)
#define RP_IN_RIGHT				(1 << 11)
#define RP_IN_MOVELEFT			(1 << 12)
#define RP_IN_MOVERIGHT			(1 << 13)
#define RP_IN_RELOAD			(1 << 14)
#define RP_IN_SPEED				(1 << 15)
#define RP_IN_USE				(1 << 16)
#define RP_IN_BULLRUSH			(1 << 17)
#define RP_FL_ONGROUND			(1 << 18)
#define RP_FL_DUCKING			(1 << 19)
#define RP_FL_SWIM				(1 << 20)
#define RP_UNDER_WATER			(1 << 21)
#define RP_TELEPORT_TICK		(1 << 22)
#define RP_TAKEOFF_TICK			(1 << 23)
#define RP_HIT_PERF				(1 << 24)
#define RP_SECONDARY_EQUIPPED	(1 << 25)



// =====[ FORWARDS ]=====

/**
 * Called when a replay of a player is written to disk.
 * This includes replays of cheaters which are saved if
 * the player is marked as a cheater by gokz-localdb.
 *
 * @param client			The client ID of the player who completed the run.
 * @param replayType		The type of the replay (Run/Jump/Cheater).
 * @param map				The name of the map the run was completed on.
 * @param course			The specific course on the map the run was completed on.
 * @param timeType			The type of time (Pro/Nub).
 * @param time				The time the run was completed in.
 * @param filePath			Replay file path.
 */
forward void GOKZ_RP_OnReplaySaved(int client, int replayType, const char[] map, int course, int timeType, float time, const char[] filePath);

/**
 * Called when a currently being recorded replay is discarded from
 * memory and recording has been stopped (without writing it to disk).
 *
 * @param client			Client index.
 */
forward void GOKZ_RP_OnReplayDiscarded(int client);

/**
 * Called when a player has ended their timer, and gokz-replays has
 * processed the time and has possibly written a replay to disk.
 *
 * @param client			Client index.
 * @param filePath			Replay file path, or "" if no replay saved.
 * @param course    		Course number.
 * @param time				Player's end time.
 * @param teleportsUsed		Number of teleports used by player.
 */
forward void GOKZ_RP_OnTimerEnd_Post(int client, const char[] filePath, int course, float time, int teleportsUsed);



// =====[ NATIVES ]====

/**
 * Called by the HUD to get the state of the current replay.
 *
 * @param client			Client index.
 * @param info				Struct to pass the values into.
 * @return					If successful
 */
native int GOKZ_RP_GetPlaybackInfo(int client, any[] info);

/**
 * Called by the LocalDB to initiate a replay of a jump
 *
 * @param client			Client index.
 * @param path				Path to the replay file.
 * @return					The client ID of the bot performing the replay.
 */
native int GOKZ_RP_LoadJumpReplay(int client, char[] path);



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_gokz_replays = 
{
	name = "gokz-replays", 
	file = "gokz-replays.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_gokz_replays_SetNTVOptional()
{
	MarkNativeAsOptional("GOKZ_RP_GetPlaybackInfo");
	MarkNativeAsOptional("GOKZ_RP_LoadJumpReplay");
}
#endif