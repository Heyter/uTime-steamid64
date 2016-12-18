-- Written by Team Ulysses, http://ulyssesmod.net/
-- uniqueid in steamid64 by hikka v1.42
module("Utime", package.seeall)
if !SERVER then return end

utime_welcome = CreateConVar("utime_welcome", "1", FCVAR_ARCHIVE)

if !sql.TableExists( "utime" ) then
	sql.Query("CREATE TABLE IF NOT EXISTS utime ( id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, player INTEGER NOT NULL, totaltime INTEGER NOT NULL, lastvisit INTEGER NOT NULL );")
	sql.Query("CREATE INDEX IDX_UTIME_PLAYER ON utime ( player DESC );")
end

function onJoin( ply )
	local uid = ply:UniqueID()
	local sid = ply:SteamID64()
	local row = sql.QueryRow("SELECT player, totaltime, lastvisit FROM utime WHERE player = " ..uid.. ";")
	local result = sql.QueryRow("SELECT player, totaltime, lastvisit FROM utime WHERE player = " ..sid.. ";")
	local time = 0 

	if row then
		sql.Query("UPDATE utime SET lastvisit = " ..os.time().. ", player = "..sid.." WHERE player = " ..uid.. ";")
		time = row.totaltime
	elseif result then
		if utime_welcome:GetBool() then
			ULib.tsay(ply, "[UTime] Welcome back " ..ply:Nick().. ", you last played on this server " ..os.date("%c", result.lastvisit))
		end
		sql.Query( "UPDATE utime SET lastvisit = " ..os.time().. " WHERE player = " ..sid.. ";" )
		time = result.totaltime
	else
		if utime_welcome:GetBool() then
			ULib.tsay( ply, "[UTime] Welcome to our server " ..ply:Nick().. "!" )
		end
		sql.Query("INSERT into utime ( player, totaltime, lastvisit ) VALUES ( " ..sid.. ", 0, " ..os.time().. " );")
	end
	ply:SetUTime(time)
	ply:SetUTimeStart(CurTime())
	print("uniqueid converted in "..uid)
end
hook.Add("PlayerInitialSpawn", "UTimeInitialSpawn", onJoin)

function updatePlayer(ply)
	sql.Query( "UPDATE utime SET totaltime = " ..math.floor(ply:GetUTimeTotalTime()).. " WHERE player = " ..ply:SteamID64().. ";" )
end
hook.Add("PlayerDisconnected", "UTimeDisconnect", updatePlayer)

function updateAll()
	for _, ply in ipairs(player.GetAll()) do
		if ply && ply:IsConnected() then
			updatePlayer( ply )
		end
	end
end
timer.Create("UTimeTimer", 60, 0, updateAll)