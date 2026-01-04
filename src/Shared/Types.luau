export type SnapshotData<Value, Velocity> = {
	t: number,
	value: Value,
	velocity: Velocity,
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
    _TICKERS :{
        NORMAL : Ticker,
        HALF : Ticker,
    }?,

	BUFFER: number,
	TICK_RATE: number,
	FULL_ROTATION: boolean?, -- defaults to false
    AUTO_UPDATE_POS: boolean?, -- defaults to true
    STORE_SNAPSHOTS: boolean?,
    
    NORMAL_TICK_DISTANCE: number?, 
    HALF_TICK_DISTANCE: number?, 
}

export type EntityConfigInput = {
	BUFFER: number,
	TICK_RATE: number,
	FULL_ROTATION: boolean?,
    AUTO_UPDATE_POS: boolean?,
    STORE_SNAPSHOTS: boolean?,
 
    NORMAL_TICK_DISTANCE: number?, 
    HALF_TICK_DISTANCE: number?,
}

export type Ticker = {
    isHalf : boolean,
    tickRate: number,
    lastTicked: number,
    tickedTime: number,
    objects: {[Entity]: true},
    config: EntityConfig,
}


export type ReplicationRule = {

}

export type Entity = {
    --Client

    --Server
    autoUpdatePos : boolean,
    replicationRules : {ReplicationRule}?,
    _ticker: Ticker?,
    
    --NetworkOwner
    latestTime: number?,
    isNetworkOwner: boolean,
    networkOwner: Player?,
    plrCharacter: Player?,

    snapshot: Snapshot<CFrame, Vector3>?,
    latestCFrame: CFrame?,
    

    id: number,
    entityConfig : EntityConfig,-- defaults to DEFAULT config
    modelString: string?,
    model: Model?,

    lastCheckedCFrame: CFrame?,

    lastReplicatedTime: number?, -- This is only for client owned on the server
    arriveTime: number?, -- This is only for client owned on the server

    cframeBuffer: buffer?,
    destroyed : boolean,
    

    _characterAdded: RBXScriptConnection?,
    _characterRemoving: RBXScriptConnection?,
}

return nil
