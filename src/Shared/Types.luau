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

export type Connection = {
	Disconnect: (self: any) -> (),
	Connected: boolean,
}

export type Event<fx, T...> = {
	Connect: (self: any, FN: fx) -> Connection,
	Once: (self: any, FN: fx) -> Connection,
	Wait: (self: any) -> T...,
}

export type Snapshot<Value, Velocity> = {
	cache: { SnapshotData<Value, Velocity> },
	head: number,
	count: number,
	Lerp: (p0: Vector3, p1: Vector3, v0: Velocity, v1: Velocity, t: number, dt: number) -> Vector3,

	Push: (self: Snapshot<Value, Velocity>, t: number, value: Value, velocity: Velocity) -> (),
	GetLatest: (self: Snapshot<Value, Velocity>) -> SnapshotData<Value, Velocity>?,
	GetAt: (self: Snapshot<Value, Velocity>, t: number) -> Value?,
	Clear: (self: Snapshot<Value, Velocity>) -> (),
}

export type EntityConfig = {
	NAME: string,
	TICKER: Ticker?,
	RENDER_CACHE: {
		NORMAL: RenderCache,
		HALF: RenderCache?,
	}?,

	BUFFER: number,
	TICK_RATE: number,
	FULL_ROTATION: boolean?, -- defaults to false
	AUTO_UPDATE_POS: boolean?, -- defaults to true
	STORE_SNAPSHOTS: boolean?, -- defaults to false
	MODEL_REPLICATION_MODE: "NATIVE" | "MIRRORED" | "CUSTOM"?,
	NORMAL_TICK_DISTANCE: number?, 
	HALF_TICK_DISTANCE: number?,
}

export type EntityConfigInput = {
	BUFFER: number,
	TICK_RATE: number,
	FULL_ROTATION: boolean?,
	AUTO_UPDATE_POS: boolean?, -- If false have to manually call Entity.push
	STORE_SNAPSHOTS: boolean?, -- Should snapshots be stored on the server. Excludes client owned
	MODEL_REPLICATION_MODE: "NATIVE" | "MIRRORED" | "CUSTOM"?,

	NORMAL_TICK_DISTANCE: number?,
	HALF_TICK_DISTANCE: number?,
	-- Might consider giving a config level replication rules instead of just entity
}

export type Ticker = {
	tickedHalf: boolean,
	tickRate: number,
	tickHalfRate: number,
	lastTicked: number,
	tickedFrame: number,
	objects: { Entity },
	callbacks: { (ticker: Ticker,dt:number) -> () },
	config: EntityConfig,
	dt: number,
	halfdt: number,
}

export type InterpolationBuffer = {
	init: boolean,
	averageLatency: number,
	deviation: number,
	lastLatency: number,
	renderCache: RenderCache,
}

export type RenderCache = {
	name: string,
	lastClockAt: number?,
	lastClockDuration: number,
	renderAt: number?,
	tickRate: number,
	_baseTickRate: number,
	buffer: InterpolationBuffer?,
	bufferConst: number?,

	Clear: (self: RenderCache) -> (),
	GetTargetRenderTime: (self: RenderCache) -> number,
	GetEstimatedServerTime: (self: RenderCache) -> number,
	OnSnapShot: (self: RenderCache, currentTime: number) -> (),
	SetTickRate: (self: RenderCache, tickRate: number) -> (),
	Destroy: (self: RenderCache) -> (),
}

export type ReplicationRule = {}

export type EntityReceivePacket = {
	id: number,
	_plrCharacter: Player?,
	networkOwner: Player?,
	time: number,
	cframe: CFrame,
	config: string?,
	model: string | Model?,
	paused: boolean?,
	isHalfTicked: boolean?,
	_data: any,
}

export type Entity = {
	--Client
	-- this is for non server owned
	_renderCache: RenderCache?,
	--Server
	autoUpdatePos: boolean,
	replicationRules: { ReplicationRule }?,
	_ticker: Ticker?,
	_tickerIndex: number?,

	--NetworkOwner
	motor6d: Motor6D?,
	isContextOwner: boolean,
	networkOwner: Player?,
	_plrCharacter: Player?,

	snapshot: Snapshot<CFrame, Vector3>?,
	latestCFrame: CFrame?,
	latestTime: number?,

	isHalfTicked: boolean?,
	id: number,
	entityConfig: EntityConfig, -- defaults to DEFAULT config
	modelString: string?,
	model: Model?,
	actualModel: Model?, -- For mirrored models
	paused: boolean,
	modelRepMode: "NATIVE" | "MIRRORED" | "CUSTOM"?,

	lastCheckedCFrame: CFrame?,

	lastReplicatedTime: number?,
	arriveFrame: number?, -- This is only for client owned on the server

	cframeBuffer: buffer?,
	registered: boolean,
	destroyed: boolean,

	_data: any,
	_changes: { { string | any } }?,
	_events: { [string]: Signal<any, any> }?,
	_lastId: number?,
}

return nil
