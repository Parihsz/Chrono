const RunService = game:GetService("RunService")

const IS_SERVER = RunService:IsServer()
const Config = require(script.Shared.Config)
const HTTPS = game:GetService("HttpService")
const Stats = require(script.Shared.Stats)
const Player = require(script.Server.Player)
const Receiver = require(script.Server.Receiver)
const ServerClock = require(script.Server.ServerClock)
const Entity = require(script.Shared.Entity)
const Events = require(script.Shared.Events)
const Holder = require(script.Shared.Holder)
const ReplicationRules = require(script.Shared.ReplicationRules)
const Snapshots = require(script.Shared.Snapshots)
const Types = require(script.Shared.Types)
const EntityGrid = require(script.Server.EntityGrid)

export type SnapshotData<Value, Velocity> = Types.SnapshotData<Value, Velocity>
export type Signal<fx, T...> = Types.Signal<fx, T...>
export type ClientEntitiesStats = Types.ClientEntitiesStats
export type ServerEntitiesStats = Types.ServerEntitiesStats
export type Connection = Types.Connection
export type Event<fx, T...> = Types.Event<fx, T...>
export type Snapshot<Value, Velocity> = Types.Snapshot<Value, Velocity>
export type MODEL_REPLICATION_MODE = Types.MODEL_REPLICATION_MODE
export type EntityConfig = Types.EntityConfig
export type EntityConfigInput = Types.EntityConfigInput
export type Ticker = Types.Ticker
export type InterpolationBuffer = Types.InterpolationBuffer
export type ClientClock = Types.ClientClock
export type ReplicationRule = Types.ReplicationRule
export type EntityReceivePacket = Types.EntityReceivePacket
export type Entity = Types.Entity
export type PlayerEntityHolder = Types.PlayerEntityHolder

const function CheckVersion()
	task.spawn(function()
		pcall(function()
			const url = "https://api.github.com/repos/Parihsz/Chrono/releases/latest"
			const success, result = pcall(function()
				return HTTPS:GetAsync(url)
			end)
			if not success then
				return
			end
			const data = HTTPS:JSONDecode(result)
			const latestVersion = data.tag_name
			const currentVersion = Config._GetConfig("__VERSION")
			if latestVersion ~= currentVersion then
				warn(
					("Chrono: A new version is available! You are using version %s, but the latest version is %s."):format(
						currentVersion,
						latestVersion
					)
				)
			end
		end)
	end)
end
local STARTED = false
return {
	Start = function(config: ModuleScript?)
		if STARTED then
			warn("Chrono: Already Started. Ignoring subsequent calls.")
			return
		end
		STARTED = true
		if config then
			(require)(config)
		end
		if IS_SERVER then
			require(script.Server.Replicate)
		else
			require(script.Client.Replicate)
		end
		Config._Lock()
		if IS_SERVER and Config._GetConfig("CHECK_NEW_VERSION") then
			CheckVersion()
		end
		const currentVersion = Config._GetConfig("__VERSION")
		print(`Chrono {currentVersion} Started.`)
	end,

	Holder = Holder,
	Entity = Entity,
	Stats = Stats,
	Config = Config,
	ReplicationRules = ReplicationRules,
	Events = Events,
	Snapshots = Snapshots,

	ServerClock = ServerClock,
	Player = Player,
	ServerReceiver = Receiver,
	EntityGrid = EntityGrid,
}
