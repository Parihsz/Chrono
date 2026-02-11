local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Chrono = ReplicatedStorage.Packages.chrono
local Shared = Chrono.Shared
local Config = require(Shared.Config)
local Stats = require(Shared.Stats)
local Types = require(Shared.Types)
local Iris = require(ReplicatedStorage.DevPackages.iris)
local PAUSE_KEY = Enum.KeyCode.E

local ClientStats = Stats.CLIENT

Iris.Init()

local function displayServerEntityStats(entity: Types.ServerEntitiesStats)
	Iris.Text({ "ID: " .. tostring(entity.id) })
	Iris.Text({ "Network Owner: " .. tostring(entity.networkOwner) })
	Iris.Text({ "Is Character: " .. tostring(entity.isCharacter) })
	Iris.Text({ "Config: " .. tostring(entity.config) })
	Iris.Text({ "Tick Rate: " .. tostring(entity.tickRate) })
	Iris.Text({ "Last Ticked: " .. tostring(entity.lastTicked) })
	Iris.Text({ "Last Position: " .. tostring(entity.lastPosition) })
	Iris.Text({ "Model Type: " .. tostring(entity.modelType) })
end

local function displayVector3(vec: Vector3)
	return string.format("X: %.2f, Y: %.2f, Z: %.2f", vec.X, vec.Y, vec.Z)
end

local function cframeToString(cf: CFrame)
	local rx, ry, rz = cf:ToEulerAnglesXYZ()
	rx, ry, rz = math.deg(rx), math.deg(ry), math.deg(rz)
	return displayVector3(cf.Position) ..` | rot: {displayVector3(Vector3.new(rx, ry, rz))}`
end
local function displaySnapShots(snapshots: { t: number, value: CFrame, velocity: Vector3 })
	Iris.Text({ "Snapshots:" })
	for _, snap in snapshots do
		Iris.Text({ `t: {snap.t}, value: {snap.value and cframeToString(snap.value)} | velocity: {snap.velocity and displayVector3(snap.velocity)}` })
	end
end

local function displayClientEntityStats(entity: Types.ClientEntitiesStats)
	Iris.Text({ "ID: " .. tostring(entity.id) })
	Iris.Text({ "Network Owner: " .. tostring(entity.networkOwner) })
	Iris.Text({ "Is Character: " .. tostring(entity.isCharacter) })
	Iris.Text({ "Config: " .. tostring(entity.config) })

	Iris.Text({ "Last Received Time: " .. tostring(entity.lastReceivedTime) })
	Iris.Text({ "Last Replicated Time: " .. tostring(entity.lastReplicatedTime) })
	Iris.Text({ "Current Position: " .. tostring(entity.currentPosition) })

	Iris.Text({ "Average Latency: " .. tostring(entity.averageLatency) })
	Iris.Text({ "Target Time: " .. tostring(entity.targetTime) })
	Iris.Text({ "Deviation: " .. tostring(entity.deviation) })
	Iris.Text({ "Buffered Time: " .. tostring(entity.bufferedTime) })
	if Iris.Tree({ "Snapshots" }).state.isUncollapsed.value then
		displaySnapShots(entity.snapshots)
	end
	Iris.End()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == PAUSE_KEY then
		Stats.CLIENT._PAUSE = not Stats.CLIENT._PAUSE
	end
end)

Iris:Connect(function()
	if Iris.Window({ "Replication Debug" }) then
		Iris.Text({ "Version: " .. tostring(Config._GetConfig("__VERSION")) })
		if Iris.Button({ Stats.CLIENT._PAUSE and "Unpause" or "Pause" }).clicked() then
			Stats.CLIENT._PAUSE = not Stats.CLIENT._PAUSE
		end
		if Iris.Tree({ "Client Network Stats" }).state.isUncollapsed.value then
			Iris.Text({
				"Received (Non-Compressed): " .. tostring(ClientStats.BYTES_RECEIVED_PER_SEC / 1000) .. " KB/s",
			})
			Iris.Text({ "Entities Added: " .. tostring(ClientStats.NEW_ENTITIES_PER_SEC) .. "/s" })
			Iris.Text({ "Entity Changes: " .. tostring(ClientStats.ENTITY_CHANGES_PER_SEC) .. "/s" })
			Iris.Text({ "Entity Removals: " .. tostring(ClientStats.ENTITY_REMOVALS_PER_SEC) .. "/s" })

			Iris.Tree({ "Client Entities" })
			do
				for _, entity in Stats.CLIENT.CLIENT_ENTITIES do
					if Iris.Tree({ "Entity " .. tostring(entity.id) }).state.isUncollapsed.value then
						displayClientEntityStats(entity)
					end
					Iris.End()
				end
			end
			Iris.End()
		end
		Iris.End()
		if Iris.Tree({ "Client Render Stats" }).state.isUncollapsed.value then
			Iris.Text({ "Avg Interpolation Time (ms): " .. tostring(ClientStats.AVG_INTERPOLATION_TIME_MS) })
			Iris.Text({ "Total Entities Culled: " .. tostring(ClientStats.TOTAL_ENTITIES_CULLED) })
			Iris.Text({ "Entities Moved This Frame: " .. tostring(ClientStats.ENTITIES_MOVED_THIS_FRAME) })
			Iris.Text({
				"Total Client Entities Checked This Frame: "
					.. tostring(ClientStats.TOTAL_CLIENT_ENTITIES_CHECKED_THIS_FRAME),
			})
			Iris.Text({ "Total Client Entities: " .. tostring(ClientStats.TOTAL_CLIENT_ENTITIES) })
		end
		Iris.End()
		if Iris.Tree({ "Server Stats" }).state.isUncollapsed.value then
			Iris.Text({ "Avg Ticker Time Per Frame (ms): " .. tostring(Stats.SERVER.AVG_TICKER_TIME_MS) })
			Iris.Text({ "Entity Grid Total Update Time (ms): " .. tostring(Stats.SERVER.ENTITY_GRID_UPDATE_TIME_MS) })
			Iris.Text({
				"Entity Grid Section Time (ms): "
					.. tostring(Stats.SERVER.ENTITY_GRID_UPDATE_TIME_MS / Stats.SERVER.GRID_UPDATE_SECTIONS),
			})
			Iris.Text({ "Grid Update Sections: " .. tostring(Stats.SERVER.GRID_UPDATE_SECTIONS) })
			Iris.Text({ "Number of Entities: " .. tostring(Stats.SERVER.NUMBER_OF_ENTITIES) })
			Iris.Text({ "Entities Non-Ticked: " .. tostring(Stats.SERVER.NON_TICKED) })
			Iris.Text({ "Entities Full-Ticked: " .. tostring(Stats.SERVER.ENTITIES_FULL_TICKED) })
			Iris.Text({ "Entities Half-Ticked: " .. tostring(Stats.SERVER.ENTITIES_HALF_TICKED) })
			Iris.Text({
				"Bytes Received (Non-Compressed): " .. tostring(Stats.SERVER.BYTES_RECEIVED_PER_SEC / 1000) .. " KB/s",
			})
			Iris.Text({ "Bytes Sent (Non-Compressed): " .. tostring(Stats.SERVER.BYTES_SENT_PER_SEC / 1000) .. " KB/s" })
			Iris.Text({ "Packets Sent: " .. tostring(Stats.SERVER.PACKETS_SENT_PER_SEC) .. "/s" })
			Iris.Text({ "Replicate Player Time (ms): " .. tostring(Stats.SERVER.REPLICATE_PLAYER_TIME_MS) })
			Iris.Tree({ "Server Entities" })
			do
				for _, entity in Stats.SERVER.SERVER_ENTITIES do
					if Iris.Tree({ "Entity " .. tostring(entity.id) }).state.isUncollapsed.value then
						displayServerEntityStats(entity)
					end
					Iris.End()
				end
			end
			Iris.End()
		end
		Iris.End()
		Iris.End()
	end
end)
