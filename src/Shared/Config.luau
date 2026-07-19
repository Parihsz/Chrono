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
const BASE_CONFIG = {
	__VERSION = "v2.1.4",
	CHECK_NEW_VERSION = true,
	MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = 300, -- Base line value
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
		TICK_RATE = 1 / 20,
		BUFFER = 0.1,
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

--[=[
	Registers an entity type configuration.
	Can only be called before the config is locked.

	@param name The name of the entity type.
	@param config The configuration for the entity type.
]=]
const function RegisterEntityType(name: string, config: Types.EntityConfigInput)
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
const function RegisterEntityModel(name: string, model: Model | BasePart | false, broadPhase: vector | Vector3?)
	if model ~= false and model:IsA("Model") and not model.PrimaryPart then
		error(name .. " must have a PrimaryPart to be registered as an entity model.")
	end
	ENTITY_MODELS[name] = model
	MODEL_BROAD_PHASES[name] = broadPhase
end

const SetConfig = function(name, value)
	assert(not LOCKED, "Config is locked and cannot be modified after startup.")
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
	return ENTITY_MODELS[name]
end

const function GetBroadPhase(name: string): vector?
	return MODEL_BROAD_PHASES[name] :: any
end

const function GetConfig(name: Configs)
	return BASE_CONFIG[name]
end

const waiting = {}
const function WaitForLock(fx: () -> ())
	if LOCKED then
		fx()
	else
		table.insert(waiting, fx)
	end
end

const function SetWarningSeverity(level: WarningLevels)
	if level ~= "NONE" and level ~= "LOW" and level ~= "MEDIUM" and level ~= "HIGH" then
		error("Invalid warning level: " .. tostring(level))
	end
	BASE_CONFIG.WARNING_SEVERITY = level
end

const function Lock()
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
		if IS_SERVER then
			cloned.TICKER = (require)(script.Parent.Ticker).new(cloned)
		else
			cloned.CLIENT_CLOCK = {} :: any
			cloned.UpdateBuffer = function(self, buffer: number)
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

				-- Owned entities of this type use their own per-entity clock, so update those too.
				-- Skip any entity that set an explicit per-entity override (_clockBuffer), which wins over the config.
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
		["SERVER_VELOCITY_FIX"] = true, -- Fixes velocity calculation on the server when two packets are received next to each other
		["VELOCITY_CALC_FIX"] = true, -- Fixes velocity calculation when dt is less then tickrate
		["SNAPSHOT_INTERPOLATION_FIX"] = true, -- Fixes interpolation of snapshots when replication is stopped briefly and resumed rapidly which can cause slight jitter due to velocity.
		["SET_CFRAME_FIX"] = true, -- Adds a teleport flag to packets
		["FIX_TELEPORT_JITTER"] = true, -- Resolves jitter issue when clearing snapshots then settings cframe/teleporting can cause a bouncing effect. Uses a locking mechanism when getting the snapshot buffer to prevent old snapshots from being retrieved.
	},

	_EntityConfigs = ENTITY_TYPES,
	_GetEntityType = GetEntityType,
	_GetEntityModel = GetEntityModel,
	_GetConfig = GetConfig, -- keeping for backwards compatibility, but use GetConfig instead
	GetConfig = GetConfig,
	_Lock = Lock,
	_WaitForLock = WaitForLock,
	_GetBroadPhase = GetBroadPhase,
	_Base_Config = BASE_CONFIG, --//Modifying this after locking may not change behaviors of some config options.
	SetModelPrimaryForChrono = function(model: Model, primaryName: string)
		model:SetAttribute(CHRONO_PRIMARY, primaryName)
	end,
	SetWarningSeverity = SetWarningSeverity,
}
