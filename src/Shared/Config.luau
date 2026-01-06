local Types = require(script.Parent.Types)
local Ticker = require(script.Parent.Ticker)

local IS_SERVER = game:GetService("RunService"):IsServer()

export type Configs =
	"MIN_BUFFER"
	| "MAX_BUFFER"
	| "ENABLE_CUSTOM_CHARACTERS"
	| "DISABLE_DEFAULT_REPLICATION"
	| "SHOW_WARNINGS"
	| "MAX_SNAPSHOT_COUNT"
	| "QUERY_RADIUS"
	| "DEFAULT_NORMAL_TICK_DISTANCE"
	| "DEFAULT_HALF_TICK_DISTANCE"

export type SetConfig =
	("MIN_BUFFER", number) -> ()
	& ("MAX_BUFFER", number) -> ()
	& ("QUERY_RADIUS", number) -> ()
	& ("DEFAULT_NORMAL_TICK_DISTANCE", number) -> ()
	& ("DEFAULT_HALF_TICK_DISTANCE", number) -> ()
	& ("ENABLE_CUSTOM_CHARACTERS", boolean) -> ()
	& ("DISABLE_DEFAULT_REPLICATION", boolean) -> ()
	& ("SHOW_WARNINGS", boolean) -> ()
	& ("MAX_SNAPSHOT_COUNT", number) -> ()

local LOCKED = false
local BASE_CONFIG = {
	MIN_BUFFER = 0.09,
	MAX_BUFFER = 0.5,
	QUERY_RADIUS = 100,

	DEFAULT_NORMAL_TICK_DISTANCE = 50,
	DEFAULT_HALF_TICK_DISTANCE = 100, -- Anything beyond this distance will not be replicated
	
	ENABLE_CUSTOM_CHARACTERS = false, -- this will disable default roblox replication as well.
	DISABLE_DEFAULT_REPLICATION = false, -- this is if you want to disable the default roblox replication, but still use their controller

	SEND_FULL_ROTATION = false,

	--note that warnings are mostly non fatal
	--this will be set to false to optimize output by default, only enable if you're experiencing bugs with the system
	SHOW_WARNINGS = true,
	MAX_SNAPSHOT_COUNT = 30,
}
local ENTITY_TYPES: { [string]: Types.EntityConfig } = {
	DEFAULT = {
		NAME = "DEFAULT",
		TICK_RATE = 1 / 30,
		BUFFER = 0.1,
	},
	PLAYER = {
		NAME = "PLAYER",
		BUFFER = 0, -- handled dynamically for players
		TICK_RATE = 1 / 20,
	},
}
local ENTITY_MODELS = {}

local function registerEntityType(name, config: Types.EntityConfigInput)
	assert(not LOCKED, "Config is locked and cannot be modified after startup.")
	ENTITY_TYPES[name] = config :: any
end

local function registerEntityModel(name: string, model: Model)
	if not model.PrimaryPart then
		error(name .. " must have a PrimaryPart to be registered as an entity model.")
	end
	ENTITY_MODELS[name] = model
end

local setConfig = function(name, value)
	assert(not LOCKED, "Config is locked and cannot be modified after startup.")
	BASE_CONFIG[name] = value
end :: SetConfig

local function getEntityType(name: string): Types.EntityConfig
	return ENTITY_TYPES[name] or ENTITY_TYPES["DEFAULT"]
end

local function getEntityModel(name: string): Model?
	return ENTITY_MODELS[name]
end

local function getConfig(name: Configs)
	return BASE_CONFIG[name]
end

local waiting = {}
local function waitForLock(fx: () -> ())
	if LOCKED then
		fx()
	else
		table.insert(waiting, fx)
	end
end

local function getEntityStorageInstance(): Camera
	if workspace:FindFirstChild("Chrono_EntityStorage") then
		return workspace:FindFirstChild("Chrono_EntityStorage") :: Camera
	else
		local folder = Instance.new("Camera")
		folder.Name = "Chrono_EntityStorage"
		folder.Parent = workspace
		return folder
	end
end

local function lock()
	LOCKED = true
	local DEFAULT_NORMAL_TICK_DISTANCE = BASE_CONFIG.DEFAULT_NORMAL_TICK_DISTANCE
	local DEFAULT_HALF_TICK_DISTANCE = BASE_CONFIG.DEFAULT_HALF_TICK_DISTANCE
	for i, v in ENTITY_TYPES do
		local cloned = table.clone(v)
		cloned.NAME = i
		cloned.AUTO_UPDATE_POS = cloned.AUTO_UPDATE_POS ~= false
		cloned.FULL_ROTATION = cloned.FULL_ROTATION or false
		cloned.NORMAL_TICK_DISTANCE = cloned.NORMAL_TICK_DISTANCE or DEFAULT_NORMAL_TICK_DISTANCE
		cloned.HALF_TICK_DISTANCE = cloned.HALF_TICK_DISTANCE or DEFAULT_HALF_TICK_DISTANCE

		if IS_SERVER then
			cloned.TICKER = Ticker.new(cloned)
		else
			cloned.RENDER_CACHE = {} :: any
		end

		ENTITY_TYPES[i] = table.freeze(cloned)
	end
	for _, fx in waiting do
		fx()
	end
end

return {
	SetConfig = setConfig,
	RegisterEntityType = registerEntityType,
	RegisterEntityModel = registerEntityModel,

	_GetEntityStorageInstance = getEntityStorageInstance,
	_EntityConfigs = ENTITY_TYPES,
	_GetEntityType = getEntityType,
	_GetEntityModel = getEntityModel,
	_GetConfig = getConfig,
	_Lock = lock,
	_WaitForLock = waitForLock,
}
