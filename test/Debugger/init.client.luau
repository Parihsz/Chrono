local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PAUSE_KEY = Enum.KeyCode.E
local OPEN_CLOSE_KEY = Enum.KeyCode.F3
local CHRONO = ReplicatedStorage.Packages.chrono
local IRIS = ReplicatedStorage.DevPackages.iris

local Shared = CHRONO.Shared
local Config = require(Shared.Config)
local Stats = require(Shared.Stats)
local Types = require(Shared.Types)
local Iris = require(IRIS)
local Flags = Config.FLAGS

local ClientStats = Stats.CLIENT

local localPlayer = game:GetService("Players").LocalPlayer
local userId = localPlayer.UserId

Iris.Init()

local function displayFlagEditor(name, value)
	local type = typeof(value)
	if type == "boolean" then
		Iris.SameLine()
		Iris.Text({ name .. ": " .. tostring(value) })
		if Iris.Button({ value and "Disable " or "Enable " .. name }).clicked() then
			Stats._updateStat("FFLAG", name, not value)
		end
		Iris.End()
	elseif type == "number" then
		local newValue = value
		Iris.SameLine()
		Iris.Text({ name .. ": " .. tostring(value) })
		newValue = Iris.Input({ tostring(value) }).value
		if newValue and tonumber(newValue) and tonumber(newValue) ~= value then
			Stats._updateStat("FFLAG", name, tonumber(newValue))
		end
		Iris.End()
	end
end

local function displayFlags()
	Iris.Tree({ "Flags" })
	for flagName, flagValue in Flags do
		displayFlagEditor(flagName, flagValue)
	end
	Iris.End()
end

local function displayServerEntityStats(entity: Types.ServerEntitiesStats)
	Iris.Text({ "ID: " .. tostring(entity.id) })
	Iris.Text({ "Network Owner: " .. tostring(entity.networkOwner) })
	Iris.Text({ "Is Character: " .. tostring(entity.isCharacter) })
	Iris.Text({ "Tick Rate: " .. tostring(entity.tickRate) })
	Iris.Text({ "Last Ticked: " .. tostring(entity.lastTicked) })
	Iris.Text({ "Last Position: " .. tostring(entity.lastPosition) })
	do
		Iris.SameLine()
		Iris.Text({ "Is Paused: " .. tostring(entity.isPaused) })
		if Iris.Button({ entity.isPaused and "Unpause" or "Pause" }).clicked() then
			Stats._fireClientStatsEvent("TOGGLE_PAUSE", entity.id)
		end
		Iris.End()
	end
	do
		Iris.SameLine()
		Iris.Text({ "Model Type: " .. tostring(entity.modelType) })
		if entity.modelType == "NATIVE" or entity.modelType == "NATIVE_WITH_LOCK" then
			if Iris.Button({ "Change Model Types" }).clicked() then
				Stats._fireClientStatsEvent("CHANGE_NATIVE", entity.id)
			end
		end
		Iris.End()
	end
	do
		Iris.Text({ "Config: " .. tostring(entity.config) })
		if Iris.Tree({ "Configs" }).state.isUncollapsed.value then
			for configName, config in Config._EntityConfigs do
				if Iris.Button({ "Change to " .. configName }).clicked() then
					Stats._fireClientStatsEvent("CHANGE_CONFIG", entity.id, configName)
				end
			end
		end
		Iris.End()
	end
end

local function displayVector3(vec: Vector3)
	return string.format("X: %.2f, Y: %.2f, Z: %.2f", vec.X, vec.Y, vec.Z)
end

local function cframeToString(cf: CFrame)
	local rx, ry, rz = cf:ToEulerAnglesXYZ()
	rx, ry, rz = math.deg(rx), math.deg(ry), math.deg(rz)
	return displayVector3(cf.Position) .. ` | rot: {displayVector3(Vector3.new(rx, ry, rz))}`
end
local function displaySnapShots(snapshots: { t: number, value: CFrame, velocity: Vector3 })
	Iris.Text({ "Snapshots:" })
	for _, snap in snapshots do
		Iris.Text({
			`t: {snap.t}, value: {snap.value and cframeToString(snap.value)} | velocity: {snap.velocity and displayVector3(
				snap.velocity
			)}`,
		})
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

local function displayLineHeader()
	local level = Config._GetConfig("WARNING_SEVERITY")
	if Iris.Button({ Stats.CLIENT._PAUSE and "Unpause" or "Pause" }).clicked() then
		Stats.CLIENT._PAUSE = not Stats.CLIENT._PAUSE
	end
	Iris.SameLine()
	Iris.Text({ "Warning Severity: " })
	if Iris.Button({ tostring(level) }).clicked() then
		local options = { "NONE", "LOW", "MEDIUM", "HIGH" }
		local currentIndex = table.find(options, level) or 1
		local newIndex = currentIndex % #options + 1
		Stats._updateStat("", "WARNING_SEVERITY", options[newIndex])
	end
	Iris.End()
end

local windowsOpenState = Iris.State(false)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if not Stats.HasPermissionToReplicate(userId) then
		return
	end
	if input.KeyCode == PAUSE_KEY then
		Stats.CLIENT._PAUSE = not Stats.CLIENT._PAUSE
	end
	if input.KeyCode == OPEN_CLOSE_KEY then
		windowsOpenState:set(not windowsOpenState.value)
	end
end)

windowsOpenState:onChange(function(newValue)
	if newValue then
		Stats._openedDebugger()
	else
		Stats._closedDebugger()
	end
end)

Iris:Connect(function()
	if Iris.Window({ `Chrono Debug {Stats.CLIENT._PAUSE and " (Paused)" or ""}` }, { isOpened = windowsOpenState }) then
		Iris.Text({ "Version: " .. tostring(Config._GetConfig("__VERSION")) })

		displayLineHeader()
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
		displayFlags()
		Iris.End()
	end
end)
