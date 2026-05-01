local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Entity = require(script.Parent.Entity)
local Holder = require(script.Parent.Holder)
local Types = require(script.Parent.Types)

local ShowEntityLocations = true
local HasDebuggerOpened = {}
local Stats = {
	REPLICATE_PERMISSIONS = {
		--[123456789] = true,
	} :: { [number]: boolean },

	--// Client
	CLIENT = {
		_PAUSE = false,
		TOTAL_ENTITIES_CULLED = 0,
		ENTITIES_MOVED_THIS_FRAME = 0,
		TOTAL_CLIENT_ENTITIES_CHECKED_THIS_FRAME = 0,
		TOTAL_CLIENT_ENTITIES = 0,
		AVG_INTERPOLATION_TIME_MS = 0,

		BYTES_RECEIVED_PER_SEC = 0,
		NEW_ENTITIES_PER_SEC = 0,
		ENTITY_CHANGES_PER_SEC = 0,
		ENTITY_REMOVALS_PER_SEC = 0,

		CLIENT_ENTITIES = {} :: { [number]: Types.ClientEntitiesStats },
	},
	--// Server
	SERVER = {
		_SHOULD_REPLICATE = false,
		AVG_TICKER_TIME_MS = 0,
		ENTITY_GRID_UPDATE_TIME_MS = 0,
		GRID_UPDATE_SECTIONS = 0,
		NUMBER_OF_ENTITIES = 0,
		NON_TICKED = 0,
		ENTITIES_FULL_TICKED = 0,
		ENTITIES_HALF_TICKED = 0,

		REPLICATE_PLAYER_TIME_MS = 0,
		BYTES_RECEIVED_PER_SEC = 0,
		BYTES_SENT_PER_SEC = 0,
		PACKETS_SENT_PER_SEC = 0,

		SERVER_ENTITIES = {} :: { [number]: Types.ServerEntitiesStats },
	},
}

local function processID(id: number, replicate)
	script:SetAttribute(tostring(id), replicate)
end

function Stats.HasPermissionToReplicate(userId: number | Player)
	if typeof(userId) == "Instance" and userId:IsA("Player") then
		userId = userId.UserId
	end
	return script:GetAttribute(tostring(userId)) == true
end

function Stats.ReplicateStatsForPlayer(userId: number | Player)
	if RunService:IsClient() then
		warn("Stats.ReplicateStatsForPlayer should only be called on the server.")
		return
	end
	if typeof(userId) == "Instance" and userId:IsA("Player") then
		userId = userId.UserId
	end
	Stats.REPLICATE_PERMISSIONS[userId] = true
	processID(userId, true)
end

function Stats.StopReplicatingStatsForPlayer(userId: number | Player)
	if RunService:IsClient() then
		warn("Stats.StopReplicatingStatsForPlayer should only be called on the server.")
		return
	end
	if typeof(userId) == "Instance" and userId:IsA("Player") then
		userId = userId.UserId
	end
	Stats.REPLICATE_PERMISSIONS[userId] = nil
	processID(userId, false)
end

for i, v in Stats.REPLICATE_PERMISSIONS do
	processID(i, v)
end

local function updateStat(type: string, name: string, value: any)
	if name == "WARNING_SEVERITY" then
		Config.SetWarningSeverity(value)
	end
	if type == "FFLAG" then
		Config.FLAGS[name] = value
	end
end

local StatsRemoteHeaders = {
	REPLICATE_SERVER_STATS = "REPLICATE_SERVER_STATS",
	UPDATE_STAT = "UPDATE_STAT",
	DEBUGGER_OPENED = "DEBUGGER_OPENED",
	CLIENT_STATS_ACTION = "CLIENT_STATS_ACTION",
}

if RunService:IsServer() then
	local statsRemote = Instance.new("RemoteEvent", script)
	statsRemote.Name = "Stats"

	RunService.Heartbeat:Connect(function()
		local should = false
		if next(Stats.REPLICATE_PERMISSIONS) then
			for i, v in Players:GetPlayers() do
				if Stats.REPLICATE_PERMISSIONS[v.UserId] and HasDebuggerOpened[v.UserId] then
					should = true
					statsRemote:FireClient(v, StatsRemoteHeaders.REPLICATE_SERVER_STATS, Stats.SERVER)
				end
			end
		end

		Stats.SERVER._SHOULD_REPLICATE = should
	end)

	statsRemote.OnServerEvent:Connect(function(plr: Player, header: string, ...)
		if header == StatsRemoteHeaders.DEBUGGER_OPENED then
			local opened = ...
			HasDebuggerOpened[plr.UserId] = opened
			return
		end

		if Stats.REPLICATE_PERMISSIONS and not Stats.REPLICATE_PERMISSIONS[plr.UserId] then
			return
		end

		if header == StatsRemoteHeaders.UPDATE_STAT then
			local type, name, value = ...
			updateStat(type, name, value)
			statsRemote:FireAllClients(StatsRemoteHeaders.UPDATE_STAT, type, name, value)
		elseif header == StatsRemoteHeaders.CLIENT_STATS_ACTION then
			local actionType, id = ...
			local entity = Holder.GetEntityFromId(id)
			if not entity then
				return
			end
			if actionType == "CHANGE_NATIVE" then
				local mode = Entity.GetModelReplicationType(entity)
				if mode == "NATIVE" then
					Entity.LockNativeServerCFrameReplication(entity)
				elseif mode == "NATIVE_WITH_LOCK" then
					Entity.UnlockNativeServerCFrameReplication(entity)
				end
			elseif actionType == "TOGGLE_PAUSE" then
				if entity.paused then
					Entity.ResumeReplication(entity)
				else
					Entity.PauseReplication(entity)
				end
			elseif actionType == "CHANGE_CONFIG" then
				local configName = select(3, ...)
				Entity.SetConfig(entity, configName)
			end
		end
	end)
else
	local statsRemote = script:WaitForChild("Stats") :: RemoteEvent

	local function handleServerEvent(header: string, ...)
		if header == StatsRemoteHeaders.REPLICATE_SERVER_STATS then
			local serverStats = ...
			if Stats.CLIENT._PAUSE then
				return
			end
			for statName, value in serverStats do
				Stats.SERVER[statName] = value
			end
		elseif header == StatsRemoteHeaders.UPDATE_STAT then
			local type, name, value = ...
			updateStat(type, name, value)
		end
	end

	statsRemote.OnClientEvent:Connect(handleServerEvent)

	Stats._openedDebugger = function()
		Stats.SERVER._SHOULD_REPLICATE = true
		statsRemote:FireServer(StatsRemoteHeaders.DEBUGGER_OPENED, true)
	end
	Stats._closedDebugger = function()
		Stats.SERVER._SHOULD_REPLICATE = false
		statsRemote:FireServer(StatsRemoteHeaders.DEBUGGER_OPENED, false)
	end

	Stats._updateStat = function(type: string, name: string, value: any)
		statsRemote:FireServer(StatsRemoteHeaders.UPDATE_STAT, type, name, value)
	end

	Stats._fireClientStatsEvent = function(...)
		statsRemote:FireServer(StatsRemoteHeaders.CLIENT_STATS_ACTION, ...)
	end
end

return Stats
