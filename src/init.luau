local RunService = game:GetService("RunService")

local NpcCache = require(script.shared.npcCache)
local ServerReplicate
local ClientReplicate
local InterpolationBuffer
local RenderCache
local TogglePlayerReplication
local Character

local Snapshots = require(script.shared.snapshots)
export type SnapshotData<T> = Snapshots.SnapshotData<T>
export type Snapshot<T> = Snapshots.Snapshot<T>

local function LoadFolder(folder: Folder)
	for _, moduleScript in folder:GetDescendants() do
		if moduleScript:IsA("ModuleScript") then
			local yielded = true
			local success, message

			task.spawn(function()
				success, message = pcall(require, moduleScript)

				yielded = false
			end)

			if not success then
				error(`{moduleScript:GetFullName()}: {message}`)
			end

			if yielded then
				warn("Yielded while requiring" .. moduleScript:GetFullName())
			end
		end
	end
end

local Modules = {
	ChronoClient = true,
	ChronoServer = true,
	NpcRegistry = true,
	Snapshots = true,
	InterpolationBuffer = true,
	RenderCache = true,
	TogglePlayerReplication = true,
	Character = true,
}

local Chrono = {}

local started = false
function Chrono.Start()
	if started then
		return
	end
	started = true

	LoadFolder(if RunService:IsServer() then script.server else script.client)
	LoadFolder(script.shared)

	if RunService:IsServer() then
		ServerReplicate = require(script.server.replicate)
		TogglePlayerReplication = ServerReplicate.TogglePlayerReplication
	else
		ClientReplicate = require(script.client.replicate)
		InterpolationBuffer = require(script.client.interpolationBuffer)
		RenderCache = require(script.client.renderCache)
	end
	Character = require(script.shared.character)

	Chrono.Character = Character
	Chrono.ChronoClient = ClientReplicate
	Chrono.ChronoServer = ServerReplicate
	Chrono.NpcRegistry = NpcCache
	Chrono.Snapshots = require(script.shared.snapshots)
	Chrono.InterpolationBuffer = InterpolationBuffer
	Chrono.RenderCache = RenderCache
	Chrono.TogglePlayerReplication = TogglePlayerReplication
	setmetatable(Chrono :: any, nil)
	local config = require(script.shared.config)
	if config.DISABLE_DEFAULT_REPLICATION and config.ENABLE_CUSTOM_CHARACTERS then
		warn("DISABLE_DEFAULT_REPLICATION and ENABLE_CUSTOM_CHARACTERS are both enabled. Disabling DISABLE_DEFAULT_REPLICATION since its not needed.")
		config.DISABLE_DEFAULT_REPLICATION = false
	end
	Chrono.Config = setmetatable({}, {
		__index = function(_, key)
			return config[key]
		end,
		__newindex = function(_, key, value)
			error(`Attempt to modify Config.{key} after Chrono.Start()`, 2)
		end,
	}) :: any
end

Chrono.Config = require(script.shared.config)
return (
	setmetatable(Chrono, {
		__index = function(_, key)
			if Modules[key] then
				error(`Attempt to access Chrono.{key} before calling Chrono.Start()`, 2)
			end
		end,
	}) :: any
) :: typeof(Chrono)
