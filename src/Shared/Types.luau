export type SnapshotData<Value, Velocity> = {
	t: number,
	value: Value,
	velocity: Velocity,
}

--// FX is the function template for the events.
export type Signal<fx, T...> = {
	Fire: (self: any, T...) -> (),
	DisconnectAll: (self: any) -> (),
	Event: Event<fx, T...>,
}

export type ClientEntitiesStats = {
	id: number,
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
	}
	
}

export type ServerEntitiesStats = {
	id: number,
	isPaused: boolean,
	networkOwner: Player?,
	isCharacter: boolean,
	config: string,
	tickRate: number?,
	lastTicked: number?,
	lastPosition: Vector3,
	modelType: string?,
}
export type Connection = {
	Disconnect: (self: any) -> (),
	Connected: boolean,
	_binCleanup: () -> (),
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
	GetLatest: (self: Snapshot<Value, Velocity>) -> SnapshotData<Value, Velocity>?,
	GetAt: (self: Snapshot<Value, Velocity>, t: number, bypassLock: boolean?) -> Value?,
	Clear: (self: Snapshot<Value, Velocity>) -> (),
}

export type MODEL_REPLICATION_MODE = "NATIVE" | "NATIVE_WITH_LOCK" | "CUSTOM"
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
}

export type EntityConfigInput = {
	BUFFER: number,
	TICK_RATE: number,
	FULL_ROTATION: boolean?,
	AUTO_UPDATE_POSITION: boolean?, -- If false have to manually call Entity.push
	STORE_SNAPSHOTS: boolean?, -- Should snapshots be stored on the server. Excludes client owned
	MODEL_REPLICATION_MODE: MODEL_REPLICATION_MODE?,

	NORMAL_TICK_DISTANCE: number?,
	HALF_TICK_DISTANCE: number?,
	CUSTOM_INTERPOLATION: boolean?,
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
	buffer: InterpolationBuffer?,
	bufferConst: number?,

	Clear: (self: ClientClock) -> (),
	GetTargetRenderTime: (self: ClientClock) -> number,
	GetEstimatedServerTime: (self: ClientClock) -> number,
	OnSnapShot: (self: ClientClock, currentTime: number) -> (),
	SetTickRate: (self: ClientClock, tickRate: number) -> (),
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
	model: string | Model | BasePart?,
	paused: boolean?,
	isHalfTicked: boolean?,
	_data: any,
	mountParentId: number?,
	mountOffset: CFrame?,
	broadPhase: vector?,
	_modelMetaData:string?
}

export type Entity = {
	--Client
	-- this is for non server owned
	_clientClock: ClientClock?,
	broadPhase: vector?,
	_outofBroadPhaseTick: number?,
	--Server
	autoUpdatePosition: boolean,
	replicationRules: { ReplicationRule }?,
	_ticker: Ticker?,
	_tickerIndex: number?,

	--NetworkOwner
	isContextOwner: boolean,
	networkOwner: Player?,
	_player: Player?,

	snapshot: Snapshot<CFrame, Vector3>?,
	latestCFrame: CFrame?,
	latestTime: number?,

	isHalfTicked: boolean?,
	id: number,
	entityConfig: EntityConfig, -- defaults to DEFAULT config
	modelString: string?,
	model: Model | BasePart?,
	paused: boolean,

	modelReplicationMode: "NATIVE" | "CUSTOM"?,

	lastCheckedCFrame: CFrame?,

	lastReplicatedTime: number?,
	arriveFrame: number?, -- This is only for client owned on the server

	cframeBuffer: buffer?,
	registered: boolean,
	destroyed: boolean,

	_lockedCFReplication: boolean?,
	_data: any,
	_changes: { { string | any } }?,
	_events: { [string]: Signal<any, any> }?,
	_lastId: number?,

	mountParentId: number?,
	mountOffset: CFrame?,
}

return nil
