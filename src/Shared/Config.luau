const Types = require(script.Parent.Types)

const IS_SERVER = game:GetService("RunService"):IsServer()
const CHRONO_PRIMARY = "__CHRONO_PRIMARY"

export type WarningLevels = "NONE" | "LOW" | "MEDIUM" | "HIGH"

export type Configs =
	"MIN_BUFFER"
	| "MAX_BUFFER"
	| "MAX_SNAPSHOT_COUNT"
	| "CHECK_NEW_VERSION"
	| "DEFAULT_NORMAL_TICK_DISTANCE"
	| "DEFAULT_HALF_TICK_DISTANCE"
	| "DEFAULT_MODEL_REPLICATION_MODE"
	| "DEFAULT_INTERPOLATION_MODE"
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
	& ("DEFAULT_INTERPOLATION_MODE", Types.INTERPOLATION_MODE) -> ()
	& ("PLAYER_REPLICATION", "AUTOMATIC" | "CUSTOM") -> ()
	& ("REPLICATE_DEATHS", "NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS") -> ()
	& ("REPLICATE_CFRAME_SETTERS", "NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS") -> ()
	& ("MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER", number) -> ()
	& ("WARNING_SEVERITY", WarningLevels) -> ()
	& ("GRID_UPDATE_INTERVAL", number) -> ()
	& ("GRID_MAX_UPDATE_TIME", number) -> ()
local LOCKED = false
const BASE_CONFIG = {
	__VERSION = "v2.2.3",
	CHECK_NEW_VERSION = true,
	MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = 300, -- Base line value
	MIN_BUFFER = 0.09,
	MAX_BUFFER = 0.5,

	GRID_UPDATE_INTERVAL = 0.1,
	GRID_MAX_UPDATE_TIME = 0.0005,

	WARNING_SEVERITY = "MEDIUM", -- "NONE", "LOW", "MEDIUM", "HIGH"
	DEFAULT_NORMAL_TICK_DISTANCE = 50,
	DEFAULT_HALF_TICK_DISTANCE = 100, -- Anything beyond this distance will not be replicated for non-owned entities. 

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
	DEFAULT_INTERPOLATION_MODE = "CFRAME",
	--[[
		How the client applies an interpolated transform to a non-owned entity.
		-CFRAME = Assign primaryPart.CFrame directly.
			+ Exact, cheapest, and what you want for anything not simulated locally.
			- Teleports the assembly each frame
		-ALIGN = Drive an AlignPosition/AlignOrientation toward the target instead.
			+ Physics keeps resolving joints and collisions while still tracking the target.
			- More expensive, and has unknown interactions with other constraints.
		-NONE = Do not apply the transform at all. 
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
	MAX_SNAPSHOT_COUNT = 30,
}
const ENTITY_TYPES: { [string]: Types.EntityConfig } = {
	DEFAULT = {
		NAME = "DEFAULT",
		TICK_RATE = 1 / 20,
		BUFFER = 0.1, --if buffer is 0 or nil for server side entities then it will use an dynamic buffer
	},
	WITH_ROT = {
		NAME = "WITH_ROT",
		MODEL_REPLICATION_MODE = "NATIVE",
		BUFFER = 0,
		HALF_TICK_DISTANCE = math.huge,
		TICK_RATE = 1 / 20,
		ASSEMBLY_ROOT_PART_CHECK = true,
		FULL_ROTATION = true,
	},
	PLAYER = {
		NAME = "PLAYER",
		MODEL_REPLICATION_MODE = "NATIVE",
		BUFFER = 0, -- handled dynamically for players
		HALF_TICK_DISTANCE = math.huge, -- Keep players replicated at all distances to mimic roblox's default behavior
		TICK_RATE = 1 / 20,
		ASSEMBLY_ROOT_PART_CHECK = true,
	},
}
const ENTITY_MODELS = {}
const MODEL_BROAD_PHASES = {}

const MODEL_MODES = { "NATIVE", "NATIVE_WITH_LOCK", "CUSTOM" }
const INTERPOLATION_MODES = { "CFRAME", "ALIGN", "NONE" }
const PLAYER_FILTERS = { "NONE", "PLAYER_ENTITIES", "PLAYER_CHARACTERS" }
const CONFIG_OPTIONS = {
	DEFAULT_MODEL_REPLICATION_MODE = MODEL_MODES,
	DEFAULT_INTERPOLATION_MODE = INTERPOLATION_MODES,
	PLAYER_REPLICATION = { "AUTOMATIC", "CUSTOM" },
	REPLICATE_DEATHS = PLAYER_FILTERS,
	REPLICATE_CFRAME_SETTERS = PLAYER_FILTERS,
	WARNING_SEVERITY = { "NONE", "LOW", "MEDIUM", "HIGH" },
}

const function CheckOption(name: string, value: any, options: { string })
	assert(table.find(options, value), `Chrono: {name} must be {table.concat(options, ", ")}, got {tostring(value)}`)
end

const function CheckEntityType(name: string, config: Types.EntityConfigInput)
	assert(type(name) == "string" and name ~= "", "Chrono: entity type name must be a non-empty string")
	assert(type(config) == "table", `Chrono: entity type "{name}" must be a table`)
	assert(
		type(config.TICK_RATE) == "number" and config.TICK_RATE > 0 and config.TICK_RATE < math.huge,
		`Chrono: entity type "{name}" needs a finite TICK_RATE greater than 0, such as 1 / 20`
	)
	if config.BUFFER ~= nil then
		assert(
			type(config.BUFFER) == "number" and math.abs(config.BUFFER) < math.huge,
			`Chrono: entity type "{name}" BUFFER must be a finite number`
		)
	end
	for _, field in { "NORMAL_TICK_DISTANCE", "HALF_TICK_DISTANCE" } do
		const value = (config :: any)[field]
		assert(
			value == nil or (type(value) == "number" and value >= 0),
			`Chrono: entity type "{name}" {field} must be a non-negative number`
		)
	end
	for _, field in {
		"FULL_ROTATION",
		"AUTO_UPDATE_POSITION",
		"STORE_SNAPSHOTS",
		"ASSEMBLY_ROOT_PART_CHECK",
		"CUSTOM_INTERPOLATION",
	} do
		const value = (config :: any)[field]
		assert(value == nil or type(value) == "boolean", `Chrono: entity type "{name}" {field} must be a boolean`)
	end
	if config.MODEL_REPLICATION_MODE ~= nil then
		CheckOption(`entity type "{name}" MODEL_REPLICATION_MODE`, config.MODEL_REPLICATION_MODE, MODEL_MODES)
	end
	if config.INTERPOLATION_MODE ~= nil then
		CheckOption(`entity type "{name}" INTERPOLATION_MODE`, config.INTERPOLATION_MODE, INTERPOLATION_MODES)
	end
end

--[=[
	Registers an entity type configuration.
	Can only be called before the config is locked.

	@param name The name of the entity type.
	@param config The configuration for the entity type.
]=]
const function RegisterEntityType(name: string, config: Types.EntityConfigInput)
	if LOCKED then
		error("Chrono: Config.RegisterEntityType must be called before Chrono.Start()", 2)
	end
	CheckEntityType(name, config)
	ENTITY_TYPES[name] = config :: any
end

--[=[
	Registers an entity model. This can be registered after the config is locked.
	Server and client may have different models registered under the same name.

	@param name The name of the entity model.
	@param model The model or part to use for the entity.
	@param broadPhase Optional broad phase vector or size for frustum culling on the client. If vector is zero then only do 1 check in the center instead of a box check.
]=]
const function RegisterEntityModel(name: string, model: Model | BasePart | false, broadPhase: vector | Vector3?)
	if model ~= false and model:IsA("Model") and not model.PrimaryPart then
		error(`Chrono: Config.RegisterEntityModel model "{name}" must have a PrimaryPart`, 2)
	end
	ENTITY_MODELS[name] = model
	MODEL_BROAD_PHASES[name] = broadPhase
end

const SetConfig = function(name, value)
	if LOCKED then
		error("Chrono: Config.SetConfig must be called before Chrono.Start()", 2)
	end
	if BASE_CONFIG[name] == nil or name == "__VERSION" then
		error(`Chrono: Config.SetConfig got unknown config "{name}"`, 2)
	end
	assert(type(value) == type(BASE_CONFIG[name]), `Chrono: Config.{name} must be a {type(BASE_CONFIG[name])}`)
	if type(value) == "number" then
		if name == "DEFAULT_NORMAL_TICK_DISTANCE" or name == "DEFAULT_HALF_TICK_DISTANCE" then
			assert(value >= 0, `Chrono: Config.{name} must be 0 or greater (math.huge is allowed)`)
		else
			assert(value >= 0 and value < math.huge, `Chrono: Config.{name} must be a finite number, 0 or greater`)
		end
		if name == "MAX_SNAPSHOT_COUNT" then
			assert(value >= 1 and value % 1 == 0, "Chrono: Config.MAX_SNAPSHOT_COUNT must be a positive integer")
		elseif name == "GRID_MAX_UPDATE_TIME" then
			assert(value > 0, "Chrono: Config.GRID_MAX_UPDATE_TIME must be greater than 0")
		end
	elseif CONFIG_OPTIONS[name] then
		CheckOption(`Config.{name}`, value, CONFIG_OPTIONS[name])
	end
	BASE_CONFIG[name] = value
end :: SetConfig

const function GetEntityType(name: string?): Types.EntityConfig
	return name and ENTITY_TYPES[name] or ENTITY_TYPES["DEFAULT"]
end

const function GetEntityModel(name: string): Model | BasePart | false?
	if ENTITY_MODELS[name] == nil then
		warn(`Entity model {name} not found in Config.`)
		return nil
	end
	return ENTITY_MODELS[name] :: any
end

const function GetBroadPhase(name: string): vector?
	return MODEL_BROAD_PHASES[name] :: any
end

const function GetConfig(name: Configs): any
	return BASE_CONFIG[name]
end

const waiting: { () -> () } = {}
const function WaitForLock(fx: () -> ())
	if LOCKED then
		fx()
	else
		table.insert(waiting, fx)
	end
end

const function SetWarningSeverity(level: WarningLevels)
	if level ~= "NONE" and level ~= "LOW" and level ~= "MEDIUM" and level ~= "HIGH" then
		error(`Chrono: Config.SetWarningSeverity expected "NONE", "LOW", "MEDIUM" or "HIGH", got {level}`, 2)
	end
	BASE_CONFIG.WARNING_SEVERITY = level
end

const function Lock()
	assert(BASE_CONFIG.MIN_BUFFER <= BASE_CONFIG.MAX_BUFFER, "Chrono: Config.MIN_BUFFER must not exceed MAX_BUFFER")
	for name, config in ENTITY_TYPES do
		CheckEntityType(name, config)
	end
	(require)(script.Parent.Warn).low("Config is now locked")

	LOCKED = true
	const DEFAULT_NORMAL_TICK_DISTANCE = BASE_CONFIG.DEFAULT_NORMAL_TICK_DISTANCE
	const DEFAULT_HALF_TICK_DISTANCE = BASE_CONFIG.DEFAULT_HALF_TICK_DISTANCE
	for i, v in ENTITY_TYPES do
		const cloned = table.clone(v)
		cloned.NAME = i
		cloned.AUTO_UPDATE_POSITION = cloned.AUTO_UPDATE_POSITION ~= false
		cloned.FULL_ROTATION = cloned.FULL_ROTATION or false
		cloned.NORMAL_TICK_DISTANCE = cloned.NORMAL_TICK_DISTANCE or DEFAULT_NORMAL_TICK_DISTANCE
		cloned.HALF_TICK_DISTANCE = cloned.HALF_TICK_DISTANCE or DEFAULT_HALF_TICK_DISTANCE
		cloned.MODEL_REPLICATION_MODE = cloned.MODEL_REPLICATION_MODE
			or BASE_CONFIG.DEFAULT_MODEL_REPLICATION_MODE :: any
		cloned.INTERPOLATION_MODE = cloned.INTERPOLATION_MODE or BASE_CONFIG.DEFAULT_INTERPOLATION_MODE :: any
		if IS_SERVER then
			cloned.TICKER = (require)(script.Parent.Ticker).new(cloned)
		else
			cloned.CLIENT_CLOCK = {} :: any
			cloned.UpdateBuffer = function(self: Types.EntityConfig, buffer: number)
				if not self.CLIENT_CLOCK or not next(self.CLIENT_CLOCK :: any) then
					error("Config not initialized yet, cannot update buffer for entity type: " .. self.NAME)
				end
				self.BUFFER = buffer
				if self.CLIENT_CLOCK.NORMAL then
					self.CLIENT_CLOCK.NORMAL:UpdateBuffer(buffer)
				end
				if self.CLIENT_CLOCK.HALF then
					self.CLIENT_CLOCK.HALF:UpdateBuffer(buffer)
				end

				const Holder = (require)(script.Parent.Holder)
				const Entity = (require)(script.Parent.Entity)
				for _, entity in Holder.idMap do
					if entity.entityConfig == self then
						Entity._UpdateClockBuffer(entity)
					end
				end
			end
		end

		ENTITY_TYPES[i] = cloned
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
		["CHARACTER_WAIT_DELAY"] = true, -- Waits for CharacterAppearanceLoaded before loading
		["SERVER_VELOCITY_FIX"] = true, -- Fixes velocity calculation on the server when two packets are received next to each other
		["VELOCITY_CALC_FIX"] = true, -- Fixes velocity calculation when dt is less then tickrate
		["SNAPSHOT_INTERPOLATION_FIX"] = true, -- Fixes interpolation of snapshots when replication is stopped briefly and resumed rapidly which can cause slight jitter due to velocity.
		["SET_CFRAME_FIX"] = true, -- Adds a teleport flag to packets
		["FIX_TELEPORT_JITTER"] = true, -- Resolves jitter issue when clearing snapshots then settings cframe/teleporting can cause a bouncing effect. Uses a locking mechanism when getting the snapshot buffer to prevent old snapshots from being retrieved.
	},

	_EntityConfigs = ENTITY_TYPES,
	_GetEntityType = GetEntityType, --// For internal use only
	GetEntityType = GetEntityType,
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
