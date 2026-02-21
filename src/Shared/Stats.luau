local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Entity = require(script.Parent.Entity)
local Holder = require(script.Parent.Holder)
local Types = require(script.Parent.Types)

local Stats = {
	REPLICATE_PERMISSIONS = {
		--[123456789] = true,
	} :: { [number]: boolean }?,

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

if RunService:IsServer() then
	local replicateStatsRemote = Instance.new("RemoteEvent", script)
	replicateStatsRemote.Name = "ReplicateStats"
	RunService.Heartbeat:Connect(function()
		if not Stats.REPLICATE_PERMISSIONS then
			Stats.SERVER._SHOULD_REPLICATE = true
			replicateStatsRemote:FireAllClients(Stats.SERVER)
		elseif next(Stats.REPLICATE_PERMISSIONS) then
			for i, v in Players:GetPlayers() do
				if Stats.REPLICATE_PERMISSIONS[v.UserId] then
					Stats.SERVER._SHOULD_REPLICATE = true
					replicateStatsRemote:FireClient(v, Stats.SERVER)
				end
			end
		end
	end)
	replicateStatsRemote.OnServerEvent:Connect(function(plr, type: string, id: number, ...)
		if Stats.REPLICATE_PERMISSIONS and not Stats.REPLICATE_PERMISSIONS[plr.UserId] then
			return
		end
		local entity = Holder.GetEntityFromId(id)
		if not entity then
			return
		end
		if type == "CHANGE_NATIVE" then
			local mode = Entity.GetModelReplicationType(entity)
			if mode == "NATIVE" then
				Entity.LockNativeServerCFrameReplication(entity)
			elseif mode == "NATIVE_WITH_LOCK" then
				Entity.UnlockNativeServerCFrameReplication(entity)
			end
		elseif type == "TOGGLE_PAUSE" then
			if entity.paused then
				Entity.ResumeReplication(entity)
			else
				Entity.PauseReplication(entity)
			end
		elseif type == "CHANGE_CONFIG" then
			local configName = ...
			Entity.SetConfig(entity, configName)
		end
	end)
else
	local remote = script:WaitForChild("ReplicateStats") :: RemoteEvent
	remote.OnClientEvent:Connect(function(serverStats: any)
		if Stats.CLIENT._PAUSE then
			return
		end
		for statName, value in serverStats do
			Stats.SERVER[statName] = value
		end
	end)
	Stats._fireClientStatsEvent = function(...)
		remote:FireServer(...)
	end
end

return Stats
