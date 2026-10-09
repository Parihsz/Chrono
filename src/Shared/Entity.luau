const Entity = {}

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const Types = require(script.Parent.Types)
const Config = require(script.Parent.Config)
const Snapshot = require(script.Parent.Snapshots)
const InterpolationMath = require(script.Parent.InterpolationMath)
const ClientClock = require(script.Parent.Parent.Client.ClientClock)
const Holder = require(script.Parent.Holder)
const Signal = require(script.Parent.Signal)
const Events = require(script.Parent.Events)
const ModelHelper = require(script.Parent.ModelHelper)
const AlignDriver = require(script.Parent.Parent.Client.AlignDriver)
const Warn = require(script.Parent.Warn)
const HumanoidState = require(script.Parent.HumanoidState)
const CFrameLock = require(script.Parent.CFrameLock)
const VelocityAt = InterpolationMath.VelocityAt

const clientOwned = Holder._clientOwned
const IS_SERVER = RunService:IsServer()
const LOCAL_PLAYER = if IS_SERVER then nil else Players.LocalPlayer

const CHRONO_PRIMARY = "__CHRONO_PRIMARY"

type Entity = Types.Entity

local READY = false

Config._WaitForLock(function()
	READY = true
end)

const RegisterChange = Holder.RegisterChange

--// Part helpers
const function SafeDestroy(instance: Instance?)
	if instance then
		pcall(instance.Destroy, instance)
	end
end

const function GetPart(self: Types.Entity): BasePart?
	const model = self.model
	if not model then
		return nil
	end
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") then
		const chronoPrimary = self._chronoPrimary
		if chronoPrimary then
			const primary = model:FindFirstChild(chronoPrimary)
			if primary and primary:IsA("BasePart") then
				return primary
			else
				Warn.low(
					`Chrono primary part {chronoPrimary} not found or not a BasePart in model {model:GetFullName()} for entity id {self.id}. Falling back to default PrimaryPart.`
				)
			end
		end
		const primaryPart = model.PrimaryPart
		if primaryPart then
			return primaryPart
		end
	end
	return nil
end

const function GetRootPart(entity: Entity): BasePart?
	const primaryPart = Entity.GetPrimaryPart(entity)
	if primaryPart and IS_SERVER and entity._lockedCFReplication then
		return CFrameLock.GetLockedRoot(primaryPart)
	end
	return primaryPart
end

const function SetPartCFrame(entity, cframe: CFrame)
	const part = GetRootPart(entity)
	if part then
		part.CFrame = cframe
	end
end

--// Events
const function FireEvent(entity: Entity, eventName: string, ...: any)
	const events = entity._events
	if not events then
		return
	end
	const signal = events[eventName]
	if signal then
		signal:Fire(entity, ...)
	end
end

const function GetEvent(self: Entity, eventName: string): Types.Event<any>
	if not self._events then
		self._events = {}
	end
	const events = self._events :: { [string]: Types.Signal<any, any> }
	if not events[eventName] then
		events[eventName] = Signal.new()
	end
	return events[eventName].Event
end

--// Ownership & clock
-- If buffer is given then it will create a client clock for the entity as well.
const function SetClock(self: Entity, buffer: number | false?)
	if self._clientClock then
		self._clientClock:Destroy()
		self._clientClock = nil
	end
	if buffer == false then
		self._clockBuffer = nil
		buffer = nil
	end
	buffer = buffer or self._clockBuffer
	self._clockBuffer = buffer :: any
	const entityBuffer = buffer or self.entityConfig.BUFFER or 0
	if self.networkOwner or buffer then
		const networkOwner = self.networkOwner
		self._clientClock = ClientClock.new(
			self.entityConfig.TICK_RATE,
			`Entity id: {self.id} plr: {networkOwner and networkOwner.Name or "SERVER"}`,
			entityBuffer,
			networkOwner
		)
	end
end

const function CheckNetworkOwner(self: Entity, prev: Player?)
	self.isContextOwner = self.networkOwner == LOCAL_PLAYER
	const isSameOwner = self.networkOwner == prev
	if not isSameOwner then
		self.latestTime = 0
		self.lastClientClock = 0
	end
	if IS_SERVER then
		const part = GetPart(self)
		if part then
			const locked = self._lockedCFReplication

			if locked then
				CFrameLock.Unlock(part)
			end
			CFrameLock.SafeSetNetworkOwner(part, self.networkOwner)
			if locked then
				CFrameLock.Lock(part)
				const root = GetRootPart(self)
				if root then
					CFrameLock.SafeSetNetworkOwner(root, self.networkOwner)
					root.Anchored = not isSameOwner
				end
			end
		end

		if self.isContextOwner and not self.entityConfig.STORE_SNAPSHOTS then
			self.snapshot = nil
		elseif not self.snapshot then
			self.snapshot = Snapshot(InterpolationMath.Hermite)
		end
	else
		if self.isContextOwner then
			AlignDriver.Clear(self)
		end
		const locked = self._lockedCFReplication

		if locked and self.isContextOwner then
			const part = GetPart(self)
			if part then
				CFrameLock.Lock(part)
				self._cfLockFailed = nil
			else
				self._cfLockFailed = true
			end
			if self._player then
				CFrameLock.Unlock(part)
			end
		end
	end

	if isSameOwner then
		return
	elseif self.snapshot then
		self.snapshot:Clear()
	end

	if not IS_SERVER then
		SetClock(self)
	end

	FireEvent(self, "NetworkOwnerChanged", self.networkOwner, prev)

	if prev then
		const ownedEntities = clientOwned[prev]

		if ownedEntities then
			ownedEntities[self] = nil

			Events._Signals.PlayerOwnedRemoved:Fire(prev, self)
		end
	end
	if self.networkOwner then
		const ownedEntities = clientOwned[self.networkOwner]

		if not ownedEntities then
			return
		end
		ownedEntities[self] = true

		Events._Signals.PlayerOwnedAdded:Fire(self.networkOwner, self)
	end
end

const function SetEntityNetworkOwner(self: Entity, player: Player?)
	if player ~= self.networkOwner then
		const prev = self.networkOwner
		RegisterChange(self, "networkOwner", player)
		CheckNetworkOwner(self, prev)
		Entity.Clear(self)
	end
	self.lastCheckedCFrame = nil
	if not IS_SERVER and self.modelReplicationMode == "CUSTOM" then
		const primaryPart = Entity.GetPrimaryPart(self)
		if primaryPart then
			primaryPart.Anchored = not self.isContextOwner
		end
	end
end

--// Model
const function CheckModelReplicationMode(entity: Entity, mode: Types.MODEL_REPLICATION_MODE?): "NATIVE" | "CUSTOM"
	if not mode then
		mode = entity.modelReplicationMode
	end
	if not mode then
		const config = entity.entityConfig
		mode = config.MODEL_REPLICATION_MODE
	end
	mode = (mode :: any):upper()
	if mode ~= "NATIVE" and mode ~= "CUSTOM" and mode ~= "NATIVE_WITH_LOCK" then
		Warn.medium(`Invalid model replication mode {mode} for entity id {entity.id}, defaulting to NATIVE`)
		mode = "NATIVE"
	end
	entity._lockedCFReplication = false
	if mode == "NATIVE_WITH_LOCK" then
		mode = "NATIVE"
		entity._lockedCFReplication = true
	end
	return mode :: any
end

const function SetModel(
	self: Entity,
	model: Model | BasePart | string?,
	modelReplicationMode: Types.MODEL_REPLICATION_MODE?,
	noDestroy: boolean?
): ()
	const wasCustom = self.modelReplicationMode == "CUSTOM"

	if IS_SERVER then
		if self.modelReplicationMode == "NATIVE" and self._lockedCFReplication then
			const part = GetPart(self)
			self._lockedCFReplication = false
			CFrameLock.Unlock(part)
		end
		if not noDestroy then
			SafeDestroy(self.model)
		end
		self.model = nil
	elseif not IS_SERVER and wasCustom then
		SafeDestroy(self.model)
		self.model = nil
	elseif not IS_SERVER and self._lockedCFReplication then
		const part = GetPart(self)
		self._lockedCFReplication = false
		CFrameLock.Unlock(part)
	end
	local modelString
	if type(model) == "string" then
		modelString = model
		model = Config._GetEntityModel(model :: string) :: any
		if model then
			model = (model :: any):Clone()
		end

		if model then
			(model :: any).Parent = workspace
		end
	end
	const _model: Model? = model :: any
	const broadPhase = Config._GetBroadPhase(modelString :: string)

	const replicationMode: "NATIVE" | "CUSTOM" = CheckModelReplicationMode(self, modelReplicationMode)
	self.modelString = modelString
	self.model = _model

	if IS_SERVER or not self.broadPhase then
		self.broadPhase = broadPhase
	end

	if _model then
		if replicationMode == "CUSTOM" then
			_model.Parent = Holder.GetEntityStorageInstance()
		end

		const chronoPrimary = _model:GetAttribute(CHRONO_PRIMARY)
		if chronoPrimary and type(chronoPrimary) == "string" then
			self._chronoPrimary = chronoPrimary
		end
	end

	self.modelReplicationMode = replicationMode

	const primaryPart = GetPart(self)
	if _model and not primaryPart then
		const warn = IS_SERVER and Warn.high or Warn.low
		warn(`{_model:GetFullName()} must have a PrimaryPart set for things like autoReplication and movement.`)
	elseif _model and not _model.Archivable then
		Warn.low(
			`{_model:GetFullName()} is not Archivable. It is recommended to set Archivable to true for entity models to prevent potential issues when cloning. Archivable has been set to true automatically.`
		)
		_model.Archivable = true
	end

	if not primaryPart then
		return
	end

	if not self.latestCFrame then
		Entity.SetCFrame(self, primaryPart.CFrame)
	end
	if self.latestCFrame then
		primaryPart.CFrame = self.latestCFrame
	end

	self.modelReplicationMode = Entity.GetModelReplicationType(self) :: any
	if self.modelReplicationMode :: any == "NATIVE_WITH_LOCK" then
		self._lockedCFReplication = true
		self.modelReplicationMode = "NATIVE"
	end
	if not IS_SERVER and not self.isContextOwner and (replicationMode == "CUSTOM" or self._lockedCFReplication) then
		primaryPart.Anchored = true
	end
end

--// Construction
function Entity._new(
	entityConfig: string?,
	model: Model | BasePart | string?,
	modelReplicationMode: Types.MODEL_REPLICATION_MODE?,
	initCFrame: CFrame?
): Entity
	local config = Config._GetEntityType(entityConfig)
	if not config then
		Warn.medium(`Entity config {entityConfig} not found. Using DEFAULT config.`)
		config = Config._GetEntityType("DEFAULT")
	end

	-- If the model doesn't exist and there's no init cframe then it won't be able to find a starting cframe
	if initCFrame == nil and typeof(model) == "string" then
		const _model = Config._GetEntityModel(model :: string)
		if _model == false then
			Warn.medium(`Entity's model doesn't exist, initCFrame is required. DEFAULTING to CFrame.new(0, 0, 0)`)
			initCFrame = CFrame.new(0, 0, 0)
		end
	end

	const self: Entity = {
		id = -1,

		registered = false,
		autoUpdatePosition = config.AUTO_UPDATE_POSITION ~= false,
		isContextOwner = false,
		networkOwner = nil,
		latestCFrame = initCFrame,
		paused = false,

		entityConfig = config,
		destroyed = false,

		interpolation = not IS_SERVER and true,
	}

	if LOCAL_PLAYER then
		self.snapshot = Snapshot(InterpolationMath.Hermite)
	end
	SetModel(self, model, modelReplicationMode)
	HumanoidState.Refresh(self, true)
	CheckNetworkOwner(self, nil)

	return self
end

--[=[
	Creates a new Entity instance and registers.

	@param entityConfig The entity configuration name to use. Defaults to "DEFAULT" if not provided or invalid.
	@param model The model to use for the entity. Can be a Model, BasePart, or a string representing a registered model name.
	@param modelReplicationMode The model replication mode to use. Will default of the entity config if not provided.
	@param initCFrame The initial CFrame for the entity. Optional.

	@return The newly created Entity instance.
]=]
function Entity.new(
	entityConfig: string?,
	model: Model | BasePart | string?,
	modelReplicationMode: Types.MODEL_REPLICATION_MODE?,
	initCFrame: CFrame?
): Entity
	if not READY then
		error("Entity.new cannot be called until Chrono.Start() is called.")
	end
	const self = Entity._new(entityConfig, model, modelReplicationMode, initCFrame)
	Holder.RegisterEntity(self)
	return self
end

--[=[
	Destroys the entity, unregistering it and cleaning up resources.
]=]
function Entity.Destroy(self: Entity)
	self.destroyed = true
	FireEvent(self, "Destroying")
	Holder.UnregisterEntity(self)
	if self._clientClock then
		self._clientClock:Destroy()
	end

	HumanoidState.Stop(self)

	AlignDriver.Clear(self)

	if not IS_SERVER then
		const modeType = self.modelReplicationMode
		const primaryPart = GetPart(self)
		if modeType == "CUSTOM" then
			SafeDestroy(self.model)
		elseif primaryPart then
			if self._lockedCFReplication then
				CFrameLock.Unlock(primaryPart)
			end
			primaryPart.CFrame = CFrame.new(0, 1000000, 0)
		end
	else
		SafeDestroy(self.model)
	end

	for _, signal: Types.Signal<any> in (self._events or {}) :: any do
		signal:DisconnectAll()
	end
	self.model = nil
end

--// Model API
--[=[
	Sets the model for the entity.

	@param model The model to set for the entity. Can be a Model, BasePart, or a string representing a registered model name.
	@param modelReplicationMode The model replication mode to use. Will default to the last used mode or the entity config if not provided.
	@param noDestroy If true, will not destroy the previous model. Defaults to false.
]=]
function Entity.SetModel(
	self: Entity,
	model: Model | BasePart | string?,
	modelReplicationMode: Types.MODEL_REPLICATION_MODE?,
	noDestroy: boolean?
)
	const old = self.model
	SetModel(self, model, modelReplicationMode, noDestroy)
	if IS_SERVER then
		const toReplicate = ModelHelper.ReadyModelFromRep(self, nil)
		RegisterChange(self, "model", self.model, true, toReplicate or false)
		CheckNetworkOwner(self, self.networkOwner)
	end
	HumanoidState.Refresh(self, true)
	FireEvent(self, "ModelChanged", self.model, old)
end

--[=[
	Gets the model associated with the entity.

	@return The model associated with the entity.
]=]
function Entity.GetModel(self: Entity): Model | BasePart?
	return self.model
end

--[=[
	Gets the primary part of the entity's model. If the model is a BasePart, returns the model itself.

	@return The primary part of the entity's model, or nil if no model or primary part exists.
]=]
function Entity.GetPrimaryPart(self: Entity): BasePart?
	if self.model then
		return GetPart(self)
	end
	return nil
end

--[=[
	Returns the current model replication type of the entity, which can be "NATIVE", "CUSTOM", or "NATIVE_WITH_LOCK".

]=]
function Entity.GetModelReplicationType(self: Entity): "NATIVE" | "CUSTOM" | "NATIVE_WITH_LOCK"
	local mode = self.modelReplicationMode

	if not mode then
		mode = self.entityConfig.MODEL_REPLICATION_MODE
	end
	if mode == "CUSTOM" then
		return "CUSTOM"
	end
	if self._lockedCFReplication then
		return "NATIVE_WITH_LOCK"
	end
	return "NATIVE"
end

--[=[
	Locks the native server CFrame replication for the entity.

	Only works if the entity's model replication mode is "NATIVE".

	Throws an error if called on the client or if the model replication mode is not "NATIVE".
]=]
function Entity.LockNativeServerCFrameReplication(self: Entity)
	if IS_SERVER then
		if self.modelReplicationMode ~= "NATIVE" then
			error("LockNativeServerCFrameReplication can only be called on NATIVE model replication mode entities")
		end
		if self._lockedCFReplication then
			return
		end
		RegisterChange(self, "_lockedCFReplication", true)

		CheckNetworkOwner(self, self.networkOwner)

		FireEvent(self, "LockChanged", true)
	else
		error("LockNativeServerCFrameReplication can only be called on the server")
	end
end

--[=[
	Unlocks the native server CFrame replication for the entity.

	Only works if the entity's model replication mode is "NATIVE".

	Throws an error if called on the client or if the model replication mode is not "NATIVE".
]=]
function Entity.UnlockNativeServerCFrameReplication(self: Entity)
	if IS_SERVER then
		if self.modelReplicationMode ~= "NATIVE" then
			error("UnlockNativeServerCFrameReplication can only be called on NATIVE model replication mode entities")
		end
		if not self._lockedCFReplication then
			return
		end
		RegisterChange(self, "_lockedCFReplication", false)
		const part = GetPart(self)
		CFrameLock.Unlock(part)
		CheckNetworkOwner(self, self.networkOwner)
		FireEvent(self, "LockChanged", false)
	else
		error("UnlockNativeServerCFrameReplication can only be called on the server")
	end
end

--// CFrame & snapshots
--[=[
	Pushes a new CFrame value into the entity's snapshot.

	@param time The time associated with the CFrame value.
	@param value The CFrame value to push.
	@param velocity Optional velocity to push with the snapshot. If not provided, will be calculated based on the latest snapshot value.

	@return Whether the pushed value is the newest.
]=]
function Entity.Push(self: Entity, time: number, value: CFrame, velocity: Vector3?): boolean
	const snapshot = self.snapshot
	const newer = not self.latestTime or time > self.latestTime
	if newer then
		self.latestTime = time
		self.latestCFrame = value
	end
	if snapshot then
		const latest = snapshot:GetLatest()
		if not IS_SERVER and newer and latest and time - latest.t < 5 and not self.isContextOwner then
			const targetTime = Entity.GetTargetRenderTime(self)
			if math.abs(targetTime - latest.t) > 5 then
				snapshot:Clear()
				Warn.low(`Clearing Snapshot due to large time difference`)
			end
		end
		const baseTickRate = self.entityConfig.TICK_RATE
		const tickrate = if self.isHalfTicked then baseTickRate * 2 else baseTickRate
		snapshot:PushWithCheck(
			time,
			value,
			velocity or VelocityAt(snapshot:GetLatest(), time, value, tickrate),
			tickrate
		)
	end
	FireEvent(self, "PushedSnapShot", time, value, newer)
	return newer
end

--[=[
	Gets the CFrame value at a specific time from the entity's snapshot.

	@param time The time to get the CFrame value for.

	@return The CFrame value at the specified time, or the latest CFrame if no snapshot exists.
]=]
function Entity.GetAt(self: Entity, time: number): CFrame?
	const snapshot = self.snapshot
	if snapshot then
		return snapshot:GetAt(time)
	else
		return self.latestCFrame
	end
end

--[=[
	Gets the target render time from the entity's client clock.

	@return The target render time.
]=]
function Entity.GetTargetRenderTime(self: Entity): number
	local renderCache = self._clientClock

	if not renderCache then
		const RenderCaches = self.entityConfig.CLIENT_CLOCK
		if not RenderCaches then
			return -1
		end
		renderCache = self.isHalfTicked and RenderCaches.HALF or RenderCaches.NORMAL
	end
	if not renderCache then
		return -1
	end
	return renderCache:GetTargetRenderTime()
end

--[=[
	Gets the current CFrame of the entity.

	@return The current CFrame of the entity.
]=]
function Entity.GetCFrame(self: Entity): CFrame?
	const part = GetPart(self)
	return self.latestCFrame or (part and part.CFrame)
end

--[=[
	Sets the current CFrame of the entity and locks the snapshot to the new time.

	@param cframe The CFrame to set for the entity.
]=]
function Entity.SetCFrame(self: Entity, cframe: CFrame)
	const latestTime = (self.latestTime or 0) + 0.00002
	if Config.FLAGS.SET_CFRAME_FIX then
		if IS_SERVER or self.networkOwner then
			self._teleport = os.clock()
		end
		if not IS_SERVER and not self.isContextOwner then
			Entity.Clear(self)
		end
	end
	if self.snapshot and Config.FLAGS.FIX_TELEPORT_JITTER then
		self.snapshot.lockedTime = latestTime
	end
	Entity.Push(self, latestTime, cframe)
	RegisterChange(self, "latestCFrame", cframe, true)

	if self.isContextOwner or not IS_SERVER then
		SetPartCFrame(self, cframe)
	end
end

--[=[
	Clears the entity's snapshot and latest CFrame/time.
]=]
function Entity.Clear(self: Entity)
	const snapshot = self.snapshot
	self.latestTime = nil
	self.lastClientClock = nil
	if snapshot then
		snapshot:Clear()
	end
end

--[=[
	Sets whether the entity should auto update its position to the model's primary part CFrame.

	@param autoUpdate Whether to auto update the entity's position.
]=]
function Entity.SetAutoUpdatePos(self: Entity, autoUpdate: boolean)
	RegisterChange(self, "autoUpdatePosition", autoUpdate)
end

--// Ownership API
--[=[
	Sets the network owner of the entity. Does nothing if called on the client.

	@param player The player to set as the network owner. If nil, will clear the network owner.
]=]
function Entity.SetNetworkOwner(self: Entity, player: Player?)
	if IS_SERVER and player ~= self.networkOwner then
		SetEntityNetworkOwner(self, player)
		RegisterChange(self, "isHalfTicked", self.isHalfTicked, true)
	elseif not IS_SERVER then
		error("SetNetworkOwner can only be called on the server")
	end
end

function Entity.SyncOwnerShip(self: Entity)
	CheckNetworkOwner(self, self.networkOwner)
end

--// Config, clock & interpolation
--[=[
	Sets the entity configuration for the entity.

	@param entityConfig The entity configuration name to set.
]=]
function Entity.SetConfig(self: Entity, entityConfig: string)
	local config = Config._GetEntityType(entityConfig)
	if not config then
		Warn.medium(`Entity config {entityConfig} not found. Using Default config.`)
		config = Config._GetEntityType("DEFAULT")
	end
	RegisterChange(self, "entityConfig", config, false, config.NAME)
	HumanoidState.Refresh(self)
	if IS_SERVER then
		return
	end
	const clientClock = self._clientClock
	if clientClock then
		const tickRate = config.TICK_RATE
		clientClock._baseTickRate = tickRate
		clientClock:SetTickRate(if self.isHalfTicked then tickRate * 2 else tickRate)
		clientClock:UpdateBuffer(self._clockBuffer or config.BUFFER or 0)
	else
		SetClock(self)
	end
end

--[=[
	Sets the client clock buffer for the entity. 

	@param buffer? The buffer to set for the client clock. If nil, will use the entity config's buffer. 
]=]
function Entity.SetClockBuffer(self: Entity, buffer: number?)
	if IS_SERVER then
		error("SetClockBuffer can only be called on the client")
	end
	const clientClock = self._clientClock
	if clientClock and (self.networkOwner or buffer ~= nil) then
		self._clockBuffer = buffer
		clientClock:UpdateBuffer(buffer or self.entityConfig.BUFFER or 0)
		return
	end

	const sharedClocks = self.entityConfig.CLIENT_CLOCK
	const sharedClock = sharedClocks and (self.isHalfTicked and sharedClocks.HALF or sharedClocks.NORMAL)
	SetClock(self, buffer ~= nil and buffer or false)

	const newClock = self._clientClock
	if newClock and not self.networkOwner and sharedClock and sharedClock.lastClockAt then
		newClock.lastClockAt = sharedClock.lastClockAt
		newClock.lastClockDuration = sharedClock.lastClockDuration
		newClock.renderAt = sharedClock.renderAt
	end
end

--[=[
	Switches how the client applies interpolated transforms to this entity.

	@param mode "CFRAME" or "ALIGN".
]=]
function Entity.SetInterpolationMode(self: Entity, mode: Types.INTERPOLATION_MODE)
	RegisterChange(self, "_interpolationMode", mode)

	if mode == "ALIGN" then
		HumanoidState.Refresh(self, true)
	else
		HumanoidState.Stop(self)
		AlignDriver.Clear(self)
	end
end

--[=[
	Sets the broad phase vector for the entity.

	@param broadPhase The broad phase vector to set.
]=]
function Entity.SetBroadPhase(self: Entity, broadPhase: vector?)
	RegisterChange(self, "broadPhase", broadPhase)
end

function Entity._SetTickMode(self: Entity, isHalfTicked: boolean?)
	if self.isHalfTicked == isHalfTicked then
		return
	end
	if not self.isContextOwner then
		RegisterChange(self, "isHalfTicked", isHalfTicked)
	else
		self.isHalfTicked = isHalfTicked
	end
	FireEvent(self, "TickChanged", isHalfTicked == nil and "NONE" or if isHalfTicked then "HALF" else "NORMAL")
end

--// Data & replication state
--[=[
	Gets the user associated data with the entity.

	@return The data associated with the entity.
]=]
function Entity.GetData(self: Entity): any
	return self._data
end

--[=[
	Sets the user associated data with the entity.

	@param data The data to associate with the entity.
]=]
function Entity.SetData(self: Entity, data: any)
	RegisterChange(self, "_data", data, true)
	FireEvent(self, "DataChanged", data)
end

--[=[
	Pauses replication for the entity.
]=]
function Entity.PauseReplication(self: Entity)
	RegisterChange(self, "paused", true)
end

--[=[
	Resumes replication for the entity.
]=]
function Entity.ResumeReplication(self: Entity)
	RegisterChange(self, "paused", false)
end

--// Mounting
--[=[
	Sets the mount of the entity.

	@param parent The parent entity to mount to. If nil, will clear the mount.
	@param offset The CFrame offset from the parent entity.
]=]
function Entity.SetMount(self: Entity, parent: Entity?, offset: CFrame?)
	if not IS_SERVER then
		error("SetMount can only be called on the server")
	end

	if parent == nil then
		return Entity.ClearMount(self)
	end

	if self == parent then
		Warn.medium("An entity cannot mount itself")
		return
	end

	if not parent.registered then
		Warn.high("Parent entity must be registered before mounting")
		return
	end

	RegisterChange(self, "mountParentId", parent.id)
	RegisterChange(self, "mountOffset", offset)
	Events._Signals.EntityMountChanged:Fire(self, parent.id)
end

--[=[
	Clears the mount of the entity.
]=]
function Entity.ClearMount(self: Entity)
	if not IS_SERVER then
		error("ClearMount can only be called on the server")
	end
	if not self.mountParentId then
		return
	end

	RegisterChange(self, "mountParentId", nil)
	RegisterChange(self, "mountOffset", nil)
	Events._Signals.EntityMountChanged:Fire(self, nil)
end

--// Events API
--[=[
	Gets the event signal for the specified event name.

	@param eventName The name of the event to get.

	@return The event signal associated with the specified event name.
]=]
Entity.GetEvent = (GetEvent :: any) :: ((
	self: Entity,
	eventName: "Destroying"
) -> Types.Event<(entity: Entity) -> (), Entity>) & ((
	self: Entity,
	eventName: "NetworkOwnerChanged"
) -> Types.Event<(entity: Entity, newOwner: Player?, prevOwner: Player?) -> (), Entity, Player?, Player?>) & ((
	self: Entity,
	eventName: "PushedSnapShot"
) -> Types.Event<
	(entity: Entity, time: number, value: CFrame, isNewest: boolean) -> (),
	Entity,
	number,
	CFrame,
	boolean
>) & ((
	self: Entity,
	eventName: "TickChanged"
) -> Types.Event<(entity: Entity, newTickType: "NONE" | "HALF" | "NORMAL") -> (), Entity, string>) & ((
	self: Entity,
	eventName: "DataChanged"
) -> Types.Event<(entity: Entity, data: any) -> (), Entity, any>) & ((
	self: Entity,
	eventName: "Ticked"
) -> Types.Event<(entity: Entity, dt: number) -> (), Entity, number>) & ((
	self: Entity,
	eventName: "ModelChanged"
) -> Types.Event<
	(entity: Entity, newModel: Model | BasePart?, oldModel: Model | BasePart?) -> (),
	Entity,
	Model | BasePart?,
	Model | BasePart?
>) & ((
	self: Entity,
	eventName: "LockChanged"
) -> Types.Event<(entity: Entity, isLocked: boolean) -> (), Entity, boolean>)

--// Internal
Players.PlayerAdded:Connect(function(player)
	clientOwned[player] = {}
end)

if Players.LocalPlayer then
	clientOwned[Players.LocalPlayer] = {}
end

Players.PlayerRemoving:Connect(function(player)
	clientOwned[player] = nil
end)

Entity._FireEvent = FireEvent

Entity._GetPart = GetPart
Entity._SetPartCFrame = SetPartCFrame
Entity._GetRootPart = GetRootPart
Entity._LockPartPhysicsReplication = CFrameLock.Lock
Entity._UnlockPartPhysicsReplication = CFrameLock.Unlock
Entity._UpdateClockBuffer = SetClock
Entity._SetHumanoidState = HumanoidState.SetState
Entity._SetHumanoidDisabledStates = HumanoidState.SetDisabledStates
Entity._SetEntityNetworkOwner = SetEntityNetworkOwner

return Entity
