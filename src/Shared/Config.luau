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
	|  "REPLICATE_DEATHS"
	| "REPLICATE_CFRAME_SETTERS"
	| "__VERSION"
	| "MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER"

export type SetConfig =
	("MIN_BUFFER", number) -> ()
	& ("MAX_BUFFER", number) -> ()
	& ("QUERY_RADIUS", number) -> ()
	& ("DEFAULT_NORMAL_TICK_DISTANCE", number) -> ()
	& ("DEFAULT_HALF_TICK_DISTANCE", number) -> ()
	& ("SHOW_WARNINGS", boolean) -> ()
	& ("MAX_SNAPSHOT_COUNT", number) -> ()
	& ("CHECK_NEW_VERSION", boolean) -> ()
	& ("DEFAULT_MODEL_REPLICATION_MODE", Types.MODEL_REPLICATION_MODE) -> ()
	& ("PLAYER_REPLICATION", "AUTOMATIC" | "CUSTOM") -> ()
	& ("REPLICATE_DEATHS", "NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS") -> ()
	& ("REPLICATE_CFRAME_SETTERS", "NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS") -> ()
	& ("MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER", number) -> ()

local LOCKED = false
local BASE_CONFIG = {
	__VERSION = "2.0.0",
	CHECK_NEW_VERSION = true,
	MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = 3000,
	MIN_BUFFER = 0.09,
	MAX_BUFFER = 0.5, 
	QUERY_RADIUS = 100,

	DEFAULT_NORMAL_TICK_DISTANCE = 50,
	DEFAULT_HALF_TICK_DISTANCE = 100, -- Anything beyond this distance will not be replicated

	REPLICATE_DEATHS = "PLAYER_ENTITIES", 
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
		TICK_RATE = 1 / 2,
		BUFFER = 0.1,
		FULL_ROTATION = true,
	},
	PLAYER = {
		NAME = "PLAYER",
		MODEL_REPLICATION_MODE = "NATIVE_WITH_LOCK",
		BUFFER = 0, -- handled dynamically for players
		TICK_RATE = 1 / 20,
	},
}
local ENTITY_MODELS = {}

local function RegisterEntityType(name, config: Types.EntityConfigInput)
	assert(not LOCKED, "Config is locked and cannot be modified after startup.")
	ENTITY_TYPES[name] = config :: any
end

--Model can be registered after LOCKED FYI
local function RegisterEntityModel(name: string, model: Model|BasePart)
	if model:IsA("Model") and not model.PrimaryPart then
		error(name .. " must have a PrimaryPart to be registered as an entity model.")
	end
	ENTITY_MODELS[name] = model
end


local SetConfig = function(name, value)
	assert(not LOCKED, "Config is locked and cannot be modified after startup.")
	BASE_CONFIG[name] = value
end :: SetConfig

local function GetEntityType(name: string): Types.EntityConfig
	return ENTITY_TYPES[name] or ENTITY_TYPES["DEFAULT"]
end

local function GetEntityModel(name: string): Model|BasePart?
	if not ENTITY_MODELS[name] then
		warn(`Entity model {name} not found in Config.`)
		return nil
	end
	return ENTITY_MODELS[name]
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

local function Lock()
	if BASE_CONFIG.SHOW_WARNINGS then
		warn("Config is now locked")
	end
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
			cloned.TICKER = Ticker.new(cloned)
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

	_EntityConfigs = ENTITY_TYPES,
	_GetEntityType = GetEntityType,
	_GetEntityModel = GetEntityModel,
	_GetConfig = GetConfig,
	_Lock = Lock,
	_WaitForLock = WaitForLock,
}
