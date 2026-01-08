local Types = require(script.Parent.Types)
local Ticker = require(script.Parent.Ticker)

local IS_SERVER = game:GetService("RunService"):IsServer()

export type Configs =
	"MIN_BUFFER"
	| "MAX_BUFFER"
	| "SHOW_WARNINGS"
	| "MAX_SNAPSHOT_COUNT"
	| "CHECK_NEW_VERSION"
	| "QUERY_RADIUS"
	| "DEFAULT_NORMAL_TICK_DISTANCE"
	| "DEFAULT_HALF_TICK_DISTANCE"
	| "DEFAULT_MODEL_REPLICATION_MODE"
	| "PLAYER_REPLICATION"
	| "__VERSION"

export type SetConfig =
	("MIN_BUFFER", number) -> ()
	& ("MAX_BUFFER", number) -> ()
	& ("QUERY_RADIUS", number) -> ()
	& ("DEFAULT_NORMAL_TICK_DISTANCE", number) -> ()
	& ("DEFAULT_HALF_TICK_DISTANCE", number) -> ()
	& ("SHOW_WARNINGS", boolean) -> ()
	& ("MAX_SNAPSHOT_COUNT", number) -> ()
	& ("CHECK_NEW_VERSION", boolean) -> ()
	& ("DEFAULT_MODEL_REPLICATION_MODE", "NATIVE" | "MIRRORED" | "CUSTOM") -> ()
	& ("PLAYER_REPLICATION", "AUTOMATIC" | "CUSTOM") -> ()

local LOCKED = false
local BASE_CONFIG = {
	__VERSION = "2.0.0",
	CHECK_NEW_VERSION = true,

	MIN_BUFFER = 0.09,
	MAX_BUFFER = 0.5,
	QUERY_RADIUS = 100,

	DEFAULT_NORMAL_TICK_DISTANCE = 50,
	DEFAULT_HALF_TICK_DISTANCE = 100, -- Anything beyond this distance will not be replicated

	PLAYER_REPLICATION = "AUTOMATIC",
	--[[
		- Custom
			+ More control over how replication is handled
			- More work to set up
		- Automatic Will automatically register player models as entities
			+ Easy to use
			- Less control over replication

	]]
	DEFAULT_MODEL_REPLICATION_MODE = "NATIVE",
	--[[
		-NATIVE = Use Roblox's built in model replication.
			+ Easy to use
			- More bandwidth
		-MIRRORED = Mirror the model. Actual Model in ReplicatedStorage on the server that client move to workspace. Changes done to it replicates. Which also means default replication gets disabled.
			+ Less bandwidth
			- More memory
			- Have to modify actual model to replicate changes
		-CUSTOM = Client and Server have separate cloned models.
			+ Less bandwidth
			- Have to write custom code to replicate stuff like animations
	]]
	SEND_FULL_ROTATION = false,
	--note that warnings are mostly non fatal
	--this will be set to false to optimize output by default, only enable if you're experiencing bugs with the system
	SHOW_WARNINGS = false,
	MAX_SNAPSHOT_COUNT = 30,
}
local ENTITY_TYPES: { [string]: Types.EntityConfig } = {
	DEFAULT = {
		NAME = "DEFAULT",
		TICK_RATE = 1 / 30,
		BUFFER = 0.1,
	},
	WITH_ROT = {
		NAME = "WITH_ROT",
		TICK_RATE = 1 / 60,
		BUFFER = 0.1,
		FULL_ROTATION = true,
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

--Model can be registered after LOCKED FYI
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
	if not ENTITY_MODELS[name] then
		warn(`Entity model {name} not found in Config.`)
		return nil
	end
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

local function lock()
	if BASE_CONFIG.SHOW_WARNINGS then
		warn("Config is now locked")
	end
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
		cloned.MODEL_REPLICATION_MODE = cloned.MODEL_REPLICATION_MODE
			or BASE_CONFIG.DEFAULT_MODEL_REPLICATION_MODE :: any
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

	_EntityConfigs = ENTITY_TYPES,
	_GetEntityType = getEntityType,
	_GetEntityModel = getEntityModel,
	_GetConfig = getConfig,
	_Lock = lock,
	_WaitForLock = waitForLock,
}
