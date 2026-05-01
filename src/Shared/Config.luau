local Types = require(script.Parent.Types)

local IS_SERVER = game:GetService("RunService"):IsServer()
local CHRONO_PRIMARY = "__CHRONO_PRIMARY"

export type WarningLevels = "NONE" | "LOW" | "MEDIUM" | "HIGH"

export type Configs =
	"MIN_BUFFER"
	| "MAX_BUFFER"
	| "MAX_SNAPSHOT_COUNT"
	| "CHECK_NEW_VERSION"
	| "DEFAULT_NORMAL_TICK_DISTANCE"
	| "DEFAULT_HALF_TICK_DISTANCE"
	| "DEFAULT_MODEL_REPLICATION_MODE"
	| "PLAYER_REPLICATION"
	| "REPLICATE_DEATHS"
	| "REPLICATE_CFRAME_SETTERS"
	| "__VERSION"
	| "MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER"
	| "WARNING_SEVERITY"
	| "GRID_UPDATE_INTERVAL"
	| "GRID_MAX_UPDATE_TIME"

export type SetConfig =
	("MIN_BUFFER", number) -> ()
	& ("MAX_BUFFER", number) -> ()
	& ("DEFAULT_NORMAL_TICK_DISTANCE", number) -> ()
	& ("DEFAULT_HALF_TICK_DISTANCE", number) -> ()
	& ("MAX_SNAPSHOT_COUNT", number) -> ()
	& ("CHECK_NEW_VERSION", boolean) -> ()
	& ("DEFAULT_MODEL_REPLICATION_MODE", Types.MODEL_REPLICATION_MODE) -> ()
	& ("PLAYER_REPLICATION", "AUTOMATIC" | "CUSTOM") -> ()
	& ("REPLICATE_DEATHS", "NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS") -> ()
	& ("REPLICATE_CFRAME_SETTERS", "NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS") -> ()
	& ("MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER", number) -> ()
	& ("WARNING_SEVERITY", WarningLevels) -> ()
	& ("GRID_UPDATE_INTERVAL", number) -> ()
	& ("GRID_MAX_UPDATE_TIME", number) -> ()
local LOCKED = false
local BASE_CONFIG = {
	__VERSION = "v2.0.6",
	CHECK_NEW_VERSION = true,
	MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = 3000,
	MIN_BUFFER = 0.09,
	MAX_BUFFER = 0.5,

	GRID_UPDATE_INTERVAL = 0.1,
	GRID_MAX_UPDATE_TIME = 0.0005,

	WARNING_SEVERITY = "MEDIUM", -- "NONE", "LOW", "MEDIUM", "HIGH"
	DEFAULT_NORMAL_TICK_DISTANCE = 50,
	DEFAULT_HALF_TICK_DISTANCE = 100, -- Anything beyond this distance will not be replicated

	REPLICATE_DEATHS = "PLAYER_CHARACTERS",
	--[[
		- This requires PLAYER_REPLICATION to be set to AUTOMATIC
		-NONE = No deaths are replicated
		-PLAYER_ENTITIES = Only deaths where player has entity ownership are replicated to players
		-PLAYER_CHARACTERS= Only replicate deaths for player characters
	]]
	REPLICATE_CFRAME_SETTERS = "PLAYER_ENTITIES",
	--[[
		- This requires PLAYER_REPLICATION to be set to AUTOMATIC
		-NONE = No deaths are replicated
		-PLAYER_ENTITIES = Only deaths where player has entity ownership are replicated to players
		-PLAYER_CHARACTERS= Only replicate deaths for player characters
	]]

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
		-NATIVE_WITH_LOCK = Use Roblox's built in model replication, but disable server CFrame replication.
			+ Less bandwidth than NATIVE as roblox's cframe replication is disabled.
			- Server side roblox physics is disabled acting as if it was anchored.
			+ Good for characters or client owned entities as physics will be client sided
		-CUSTOM = Client and Server have separate cloned models.
			+ Less bandwidth
			- Have to write custom code to replicate stuff like animations
	]]
	SEND_FULL_ROTATION = false,
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
		TICK_RATE = 1 / 20,
		BUFFER = 0.1,
		FULL_ROTATION = true,
	},
	PLAYER = {
		NAME = "PLAYER",
		MODEL_REPLICATION_MODE = "NATIVE",
		BUFFER = 0, -- handled dynamically for players
		TICK_RATE = 1 / 20,
	},
}
local ENTITY_MODELS = {}
local MODEL_BROAD_PHASES = {}

--[=[
	Registers an entity type configuration.
	Can only be called before the config is locked.

	@param name The name of the entity type.
	@param config The configuration for the entity type.
]=]
local function RegisterEntityType(name: string, config: Types.EntityConfigInput)
	assert(not LOCKED, "Config is locked and cannot be modified after startup.")
	ENTITY_TYPES[name] = config :: any
end

--[=[
	Registers an entity model. This can be registered after the config is locked. 
	Server and client may have different models registered under the same name.

	@param name The name of the entity model.
	@param model The model or part to use for the entity.
	@param broadPhase Optional broad phase vector or size for frustum culling on the client. If vector is zero then only do 1 check in the center instead of a box check.
]=]
local function RegisterEntityModel(name: string, model: Model | BasePart | false, broadPhase: vector | Vector3?)
	if model ~= false and model:IsA("Model") and not model.PrimaryPart then
		error(name .. " must have a PrimaryPart to be registered as an entity model.")
	end
	ENTITY_MODELS[name] = model
	MODEL_BROAD_PHASES[name] = broadPhase
end

local SetConfig = function(name, value)
	assert(not LOCKED, "Config is locked and cannot be modified after startup.")
	BASE_CONFIG[name] = value
end :: SetConfig

local function GetEntityType(name: string?): Types.EntityConfig
	return name and ENTITY_TYPES[name] or ENTITY_TYPES["DEFAULT"]
end

local function GetEntityModel(name: string): Model | BasePart | false?
	if ENTITY_MODELS[name] == nil then
		warn(`Entity model {name} not found in Config.`)
		return nil
	end
	return ENTITY_MODELS[name]
end

local function GetBroadPhase(name: string): vector?
	return MODEL_BROAD_PHASES[name] :: any
end

local function GetConfig(name: Configs)
	return BASE_CONFIG[name]
end

local waiting = {}
local function WaitForLock(fx: () -> ())
	if LOCKED then
		fx()
	else
		table.insert(waiting, fx)
	end
end

local function SetWarningSeverity(level: WarningLevels)
	if level ~= "NONE" and level ~= "LOW" and level ~= "MEDIUM" and level ~= "HIGH" then
		error("Invalid warning level: " .. tostring(level))
	end
	BASE_CONFIG.WARNING_SEVERITY = level
end

local function Lock()
	(require)(script.Parent.Warn).low("Config is now locked")

	LOCKED = true
	local DEFAULT_NORMAL_TICK_DISTANCE = BASE_CONFIG.DEFAULT_NORMAL_TICK_DISTANCE
	local DEFAULT_HALF_TICK_DISTANCE = BASE_CONFIG.DEFAULT_HALF_TICK_DISTANCE
	for i, v in ENTITY_TYPES do
		local cloned = table.clone(v)
		cloned.NAME = i
		cloned.AUTO_UPDATE_POSITION = cloned.AUTO_UPDATE_POSITION ~= false
		cloned.FULL_ROTATION = cloned.FULL_ROTATION or false
		cloned.NORMAL_TICK_DISTANCE = cloned.NORMAL_TICK_DISTANCE or DEFAULT_NORMAL_TICK_DISTANCE
		cloned.HALF_TICK_DISTANCE = cloned.HALF_TICK_DISTANCE or DEFAULT_HALF_TICK_DISTANCE
		cloned.MODEL_REPLICATION_MODE = cloned.MODEL_REPLICATION_MODE
			or BASE_CONFIG.DEFAULT_MODEL_REPLICATION_MODE :: any
		if IS_SERVER then
			cloned.TICKER = (require)(script.Parent.Ticker).new(cloned)
		else
			cloned.CLIENT_CLOCK = {} :: any
		end

		ENTITY_TYPES[i] = table.freeze(cloned)
	end
	for _, fx in waiting do
		fx()
	end
end

return {
	SetConfig = SetConfig,
	RegisterEntityType = RegisterEntityType,
	RegisterEntityModel = RegisterEntityModel,
	FLAGS = {
		["SNAPSHOT_INTERPOLATION_FIX"] = true,
		["SET_CFRAME_FIX"] = true,
	},

	_EntityConfigs = ENTITY_TYPES,
	_GetEntityType = GetEntityType,
	_GetEntityModel = GetEntityModel,
	_GetConfig = GetConfig,
	_Lock = Lock,
	_WaitForLock = WaitForLock,
	_GetBroadPhase = GetBroadPhase,
	_Base_Config = BASE_CONFIG, --//Modifying this after locking may not change behaviors of some config options.
	SetModelPrimaryForChrono = function(model: Model, primaryName: string)
		model:SetAttribute(CHRONO_PRIMARY, primaryName)
	end,
	SetWarningSeverity = SetWarningSeverity,
}
