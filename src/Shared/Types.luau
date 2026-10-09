export type SnapshotData<Value = CFrame, Velocity = Vector3> = {
	t: number,
	value: Value,
	velocity: Velocity,
}

--// FX is the function template for the events.
export type Signal<fx, T...> = {
	Fire: (self: any, T...) -> (),
	DisconnectAll: (self: any) -> (),
	Event: Event<fx, T...>,
	_binCleanup: (self: any) -> (),
}

export type ClientEntitiesStats = {
	id: number,
	entity: Entity,
	networkOwner: Player?,
	isCharacter: boolean,
	config: string,
	lastReceivedTime: number?,
	lastReplicatedTime: number?,

	averageLatency: number?,
	targetTime: number?,
	deviation: number?,
	bufferedTime: number?,
	currentPosition: Vector3?,
	snapshots: {
		t: number,
		value: CFrame,
	},
}

export type ServerEntitiesStats = {
	id: number,
	isPaused: boolean,
	networkOwner: Player?,
	isCharacter: boolean,
	config: string,
	tickRate: number?,
	lastTicked: number?,
	lastPosition: Vector3?,
	modelType: MODEL_REPLICATION_MODE?,
	interpolationMode: INTERPOLATION_MODE?,
}
export type Connection = {
	Disconnect: (self: any) -> (),
	Connected: boolean,
	_binCleanup: (self: any) -> (),
}

export type Event<fx, T...> = {
	Connect: (self: any, FN: fx, defer: boolean?) -> Connection,
	Once: (self: any, FN: fx, defer: boolean?) -> Connection,
	Wait: (self: any, defer: boolean?) -> T...,
	_binCleanup: () -> (),
}

export type Snapshot<Value, Velocity> = {
	cache: { SnapshotData<Value, Velocity> },
	head: number,
	count: number,
	lockedTime: number,
	Lerp: (p0: Vector3, p1: Vector3, v0: Velocity, v1: Velocity, t: number, dt: number) -> Vector3,

	Push: (self: Snapshot<Value, Velocity>, t: number, value: Value, velocity: Velocity) -> (),
	PushWithCheck: (
		self: Snapshot<Value, Velocity>,
		t: number,
		value: Value,
		velocity: Velocity,
		tickrate: number
	) -> (),

	GetLatest: (self: Snapshot<Value, Velocity>) -> SnapshotData<Value, Velocity>?,
	GetAt: (self: Snapshot<Value, Velocity>, t: number, bypassLock: boolean?) -> Value?,
	Clear: (self: Snapshot<Value, Velocity>) -> (),
}

export type PlayerEntityHolder = {
	PLAYER: Player,
	HALF: { Entity },
	NORMAL: { Entity },
	_TEMP_HALF: { Entity },
	_TEMP_NORMAL: { Entity },
	REPLICATED: { [Entity]: true },
	EntityAdded: Signal<(Entity) -> (), Entity>,
	EntityRemoving: Signal<(Entity) -> (), Entity>,
}

export type MODEL_REPLICATION_MODE = "NATIVE" | "NATIVE_WITH_LOCK" | "CUSTOM"

export type INTERPOLATION_MODE = "CFRAME" | "ALIGN" | "NONE"

export type AlignDriver = {
	part: BasePart,
	container: Camera,
	driverPart: BasePart,
	alignPosition: AlignPosition,
	alignOrientation: AlignOrientation,
	velocity: Vector3?,
	lastPosition: Vector3?,
	lastTime: number?,
}

export type EntityConfig = {
	NAME: string,
	TICKER: Ticker?,
	CLIENT_CLOCK: {
		NORMAL: ClientClock?,
		HALF: ClientClock?,
	}?,

	BUFFER: number,
	TICK_RATE: number,
	FULL_ROTATION: boolean?, -- defaults to false
	AUTO_UPDATE_POSITION: boolean?, -- defaults to true
	STORE_SNAPSHOTS: boolean?, -- defaults to false
	MODEL_REPLICATION_MODE: MODEL_REPLICATION_MODE?,
	NORMAL_TICK_DISTANCE: number?,
	HALF_TICK_DISTANCE: number?,
	CUSTOM_INTERPOLATION: boolean?,
	ASSEMBLY_ROOT_PART_CHECK: boolean?,
	INTERPOLATION_MODE: INTERPOLATION_MODE?, -- defaults to DEFAULT_INTERPOLATION_MODE
	UpdateBuffer: (self: EntityConfig, buffer: number) -> ()?,
}

export type EntityConfigInput = {
	BUFFER: number,
	TICK_RATE: number,
	FULL_ROTATION: boolean?,
	AUTO_UPDATE_POSITION: boolean?, -- If false have to manually call Entity.push
	STORE_SNAPSHOTS: boolean?, -- Should snapshots be stored on the server. Excludes client owned
	MODEL_REPLICATION_MODE: MODEL_REPLICATION_MODE?,
	ASSEMBLY_ROOT_PART_CHECK: boolean?, -- If true, will check if the primary part is the root part of the model or inside the model.

	NORMAL_TICK_DISTANCE: number?,
	HALF_TICK_DISTANCE: number?,
	CUSTOM_INTERPOLATION: boolean?,
	INTERPOLATION_MODE: INTERPOLATION_MODE?, -- "CFRAME" sets CFrame directly, "ALIGN" drives AlignPosition/AlignOrientation
	-- Might consider giving a config level replication rules instead of just entity
}

export type Ticker = {
	tickedHalf: boolean,
	tickRate: number,
	tickHalfRate: number,
	lastTicked: number,
	tickedFrame: number,
	objects: { Entity },
	callbacks: { (ticker: Ticker, dt: number) -> () },
	config: EntityConfig,
	dt: number,
	halfdt: number,
}

export type InterpolationBuffer = {
	init: boolean,
	averageLatency: number,
	deviation: number,
	lastLatency: number,
	clientClock: ClientClock,
}

export type ClientClock = {
	name: string,
	lastClockAt: number?,
	lastClockDuration: number,
	renderAt: number?,
	tickRate: number,
	_baseTickRate: number,
	_owner: Player?,
	buffer: InterpolationBuffer?,
	bufferConst: number?,

	Clear: (self: ClientClock) -> (),
	GetTargetRenderTime: (self: ClientClock) -> number,
	GetEstimatedServerTime: (self: ClientClock) -> number,
	OnSnapShot: (self: ClientClock, currentTime: number) -> (),
	Refresh: (self: ClientClock, currentTime: number) -> boolean,
	SetTickRate: (self: ClientClock, tickRate: number) -> (),
	UpdateBuffer: (self: ClientClock, time: number?) -> (),
	Destroy: (self: ClientClock) -> (),
}

export type ReplicationRule = {}

export type EntityReceivePacket = {
	id: number,
	_player: Player?,
	networkOwner: Player?,
	time: number,
	cframe: CFrame,
	config: string?,
	model: string | Model | BasePart | InstanceHandle?,
	paused: boolean?,
	autoUpdatePosition: boolean?,
	isHalfTicked: boolean?,
	_data: any,
	mountParentId: number?,
	mountOffset: CFrame?,
	broadPhase: vector?,
	_lockedCFReplication: boolean?,
	_interpolationMode: INTERPOLATION_MODE?,
	_humanoidState: number?,
	_humanoidDisabledStates: number?,
}

export type Entity = {
	-- Identity
	id: number,
	_lastId: number?, -- id before it was released
	entityConfig: EntityConfig, -- defaults to DEFAULT config
	registered: boolean,
	destroyed: boolean,
	paused: boolean,
	_data: any,
	_events: { [string]: Signal<any, any> }?,
	_changes: { { string | any } }?, -- (Server) field changes queued for this frame

	-- Ownership
	networkOwner: Player?,
	isContextOwner: boolean, -- true if this machine owns it
	_player: Player?, -- set when the entity is a player's character

	-- Model
	model: Model | BasePart?,
	modelString: string?,
	modelReplicationMode: "NATIVE" | "CUSTOM"?,
	_chronoPrimary: string?,
	_modelHandle: InstanceHandle?, -- (Client) resolves NATIVE models that stream in late
	_lockedCFReplication: boolean?,
	_cfLockFailed: boolean?, -- (Client) retry the lock once the part exists
	broadPhase: vector?,

	-- CFrame & snapshots
	snapshot: Snapshot<CFrame, Vector3>?,
	latestCFrame: CFrame?,
	latestTime: number?,
	lastCheckedCFrame: CFrame?,
	lastReplicatedTime: number?,
	lastClientClock: number?,
	_teleport: number?,

	-- Ticking (Server)
	autoUpdatePosition: boolean,
	replicationRules: { ReplicationRule }?,
	isHalfTicked: boolean?,
	_ticker: Ticker?,
	_tickerIndex: number?,
	cframeBuffer: buffer?, -- serialized cframe to send this frame
	arriveFrame: number?, -- tick a client owned update arrived on

	-- Interpolation (Client)
	interpolation: boolean,
	_interpolationMode: INTERPOLATION_MODE?,
	_alignDriver: AlignDriver?,
	_clockBuffer: number?, -- per entity buffer override from SetClockBuffer
	_clientClock: ClientClock?, -- own clock for player owned or custom buffered entities
	_outofBroadPhaseTick: number?,

	-- Humanoid state replication
	_humanoidState: number?,
	_humanoidDisabledStates: number?,
	_humanoidStateConn: RBXScriptConnection?,
	_humanoidStateEnabledConn: RBXScriptConnection?,

	-- Mounting
	mountParentId: number?,
	mountOffset: CFrame?,
}

return nil
