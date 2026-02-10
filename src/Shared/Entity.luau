local Entity = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)
local Config = require(script.Parent.Config)
local Snapshot = require(script.Parent.Snapshots)
local InterpolationMath = require(script.Parent.InterpolationMath)
local ClientClock = require(script.Parent.Parent.Client.ClientClock)
local Holder = require(script.Parent.Holder)
local Signal = require(script.Parent.Signal)
local Events = require(script.Parent.Events)
local ModelHelper = require(script.Parent.ModelHelper)
local VelocityAt = InterpolationMath.VelocityAt

local Changes = {}

local clientOwned = Holder._clientOwned
local IS_SERVER = RunService:IsServer()
local LOCAL_PLAYER = if IS_SERVER then nil else Players.LocalPlayer

local CENTER_PART = Instance.new("Part")
CENTER_PART.Size = Vector3.new(0.1, 0.1, 0.1)
CENTER_PART.Name = "__CHRONO_CENTER"
CENTER_PART.Anchored = true
CENTER_PART.Transparency = 1
CENTER_PART.CanCollide = false
CENTER_PART.CanTouch = false
CENTER_PART.CanQuery = false

type Entity = Types.Entity

local function SafeDestroy(instance: Instance?)
	if instance then
		pcall(function()
			instance:Destroy()
		end)
	end
end

local function SafeSetNetworkOwner(part: BasePart, player: Player?)
	pcall(function()
		part:SetNetworkOwner(player)
	end)
end

local function LockCFReplication(part: BasePart?)
	if not part then
		return
	end
	local initCF = part.CFrame
	local previousLocker = part:FindFirstChild("__CHRONO_LOCKER")
	if previousLocker then
		local weld = previousLocker:FindFirstChild("__CHRONO_WELD") :: Motor6D
		if weld then
			weld.Part1 = part
			part.CFrame = initCF
			return
		else
			SafeDestroy(previousLocker)
		end
	end
	local camera = Instance.new("Camera", part)
	camera.Name = "__CHRONO_LOCKER"
	local weld = Instance.new("Motor6D", camera)
	weld.Name = "__CHRONO_WELD"
	local aPart = Instance.new("Part", camera)
	aPart.Name = "__CHRONO_LOCKER_PART"
	aPart.CanCollide = false
	aPart.CanQuery = false
	aPart.CanTouch = false
	aPart.Color = Color3.new(1, 0, 0)
	aPart.Anchored = true
	weld.Part0 = aPart
	weld.Part1 = part
	part.CFrame = initCF
end

local function SetPartCFrame(entity, cframe: CFrame)
	local primaryPart = Entity.GetPrimaryPart(entity)
	if not primaryPart then
		return
	end

	if IS_SERVER and entity._lockedCFReplication then
		local locker = primaryPart:FindFirstChild("__CHRONO_LOCKER")

		if not locker then
			return
		end
		local lockerPart = locker:FindFirstChild("__CHRONO_LOCKER_PART") :: BasePart?
		if not lockerPart or not lockerPart:IsA("BasePart") then
			return
		end

		lockerPart.CFrame = cframe
	else
		primaryPart.CFrame = cframe
	end
end

local function UnlockCFReplication(part: BasePart?)
	if not part then
		return
	end
	local locker = part:FindFirstChild("__CHRONO_LOCKER")
	if locker then
		local weld = locker:FindFirstChild("__CHRONO_WELD") :: Motor6D
		if weld then
			weld.Part1 = nil
		else
			SafeDestroy(locker)
		end
	end
end

local function GetPart(model: Model | BasePart?): BasePart?
	if not model then
		return nil
	end
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") then
		return model.PrimaryPart
	end
	return nil
end

local function SetValue(entity: Entity, key: string, value: any, bypass: boolean?, specialValue: any)
	if not bypass and entity[key] == value then
		return
	end
	entity[key] = value
	if not IS_SERVER then
		return
	end
	if not Changes[entity] then
		Changes[entity] = {}
	end
	Changes[entity][key] = specialValue or false
end

local function FireEvent(entity: Entity, eventName: string, ...: any)
	local events = entity._events
	if not events then
		return
	end
	local signal = events[eventName]
	if signal then
		signal:Fire(entity, ...)
	end
end

local function CheckNetworkOwner(self: Entity, prev: Player?)
	self.isContextOwner = self.networkOwner == LOCAL_PLAYER
	local isSameOwner = self.networkOwner == prev
	if not isSameOwner then
		self.latestTime = 0
	end
	if IS_SERVER then
		local part = GetPart(self.model)
		if part then
			local locked = self._lockedCFReplication

			if locked then
				UnlockCFReplication(part)
			end
			SafeSetNetworkOwner(part, self.networkOwner)
			if locked then
				LockCFReplication(part)
			end
		end

		if self.isContextOwner and not self.entityConfig.STORE_SNAPSHOTS then
			self.snapshot = nil
		else
			self.snapshot = Snapshot(InterpolationMath.Hermite)
		end
	elseif not isSameOwner then
		if self._clientClock then
			self._clientClock:Destroy()
			self._clientClock = nil
		end
		if self.networkOwner then
			self._clientClock =
				ClientClock.new(self.entityConfig.TICK_RATE, `Entity id: {self.id} plr: {self.networkOwner.Name}`)
		end
	end

	if isSameOwner then
		return
	elseif self.snapshot then
		self.snapshot:Clear()
	end

	FireEvent(self, "NetworkOwnerChanged", self.networkOwner, prev)

	if prev then
		local ownedEntities = clientOwned[prev]

		if ownedEntities then
			ownedEntities[self] = nil

			Events._Signals.PlayerOwnedRemoved:Fire(prev, self)
		end
	end
	if self.networkOwner then
		local ownedEntities = clientOwned[self.networkOwner]
		if not ownedEntities then
			return
		end
		ownedEntities[self] = true

		Events._Signals.PlayerOwnedAdded:Fire(self.networkOwner, self)
	end
end

local function CheckModelReplicationMode(entity: Entity, mode: Types.MODEL_REPLICATION_MODE?): "NATIVE" | "CUSTOM"
	if not mode then
		local config = entity.entityConfig
		mode = config.MODEL_REPLICATION_MODE
	end
	mode = (mode :: any):upper()
	if mode ~= "NATIVE" and mode ~= "CUSTOM" and mode ~= "NATIVE_WITH_LOCK" then
		warn(`Invalid model replication mode {mode} for entity id {entity.id}, defaulting to NATIVE`)
		mode = "NATIVE"
	end
	if mode == "NATIVE_WITH_LOCK" then
		mode = "NATIVE"
		entity._lockedCFReplication = true
	end
	return mode :: any
end

local function SetModel(
	self: Entity,
	model: Model | BasePart | string?,
	modelReplicationMode: Types.MODEL_REPLICATION_MODE?,
	noDestroy: boolean?
): ()
	local isCustom = self.modelReplicationMode == "CUSTOM"
	if IS_SERVER then
		if not noDestroy then
			SafeDestroy(self.model)
		end
		self.model = nil
	elseif not IS_SERVER and isCustom then
		SafeDestroy(self.model)
		self.model = nil
	end
	local locked = self._lockedCFReplication
	local modelString
	local initCFrame
	if type(model) == "string" then
		modelString = model
		model = Config._GetEntityModel(model :: string)
		if model then
			model = (model :: any):Clone()
		end

		if model then
			(model :: any).Parent = workspace
		end
	elseif typeof(model) == "Instance" and (model:IsA("Model") or model:IsA("BasePart")) then
		local part = GetPart(model :: Model | BasePart)
		if part then
			initCFrame = part.CFrame
		end
	end
	local _model: Model? = model :: any
	local primaryPart = GetPart(_model)
	local broadPhase = Config._GetBroadPhase(modelString :: string)
	if _model and not primaryPart then
		warn(`{_model:GetFullName()} must have a PrimaryPart set for things like autoReplication and movement.`)
	elseif _model and not _model.Archivable then
		warn(
			`{_model:GetFullName()} is not Archivable. It is recommended to set Archivable to true for entity models to prevent potential issues when cloning. Archivable has been set to true automatically.`
		)
		_model.Archivable = true
	end

	local replicationMode: "NATIVE" | "CUSTOM" = CheckModelReplicationMode(self, modelReplicationMode)
	self.modelString = modelString
	self.model = _model

	if IS_SERVER or not self.broadPhase then
		self.broadPhase = broadPhase
	end

	if _model and not primaryPart then
		warn("No primary part found for entity model.", _model:GetFullName())
		return
	end

	if _model then
		self.modelReplicationMode = replicationMode

		if replicationMode == "CUSTOM" then
			_model.Parent = Holder.GetEntityStorageInstance()
		end
	end
	if not primaryPart then
		return
	end
	if not IS_SERVER and not self.isContextOwner and replicationMode == "CUSTOM" then
		primaryPart.Anchored = true
	end
	if not self.latestCFrame then
		Entity.SetCFrame(self, initCFrame or primaryPart.CFrame)
	end
	if self.latestCFrame then
		primaryPart.CFrame = self.latestCFrame
	end
	if locked then
		LockCFReplication(primaryPart)
	end
end

function Entity._new(
	entityConfig: string?,
	model: Model | BasePart | string?,
	modelReplicationMode: Types.MODEL_REPLICATION_MODE?,
	initCFrame: CFrame?
): Entity
	local config = Config._GetEntityType(entityConfig or "DEFAULT")
	if not config then
		warn(`Entity config {entityConfig} not found. Using DEFAULT config.`)
		config = Config._GetEntityType("DEFAULT")
	end

	local self: Entity = {
		id = -1,

		registered = false,
		autoUpdatePosition = config.AUTO_UPDATE_POSITION ~= false,
		isContextOwner = false,
		networkOwner = nil,
		latestCFrame = initCFrame,
		paused = false,

		entityConfig = config,
		destroyed = false,
	}

	if LOCAL_PLAYER then
		self.snapshot = Snapshot(InterpolationMath.Hermite)
	end
	SetModel(self, model, modelReplicationMode)
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
	local self = Entity._new(entityConfig, model, modelReplicationMode, initCFrame)
	Holder.RegisterEntity(self)
	return self
end

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
	local old = self.model
	SetModel(self, model, modelReplicationMode, noDestroy)
	if IS_SERVER then
		local toReplicate = ModelHelper.ReadyModelFromRep(self, nil)
		SetValue(self, "model", self.model, true, toReplicate)
		CheckNetworkOwner(self, self.networkOwner)
	end
	FireEvent(self, "ModelChanged", self.model, old)
end

Entity._FireEvent = FireEvent

local function GetEvent(self: Entity, eventName: string): Types.Event<any>
	if not self._events then
		self._events = {}
	end
	local events = self._events :: { [string]: Types.Signal<any, any> }
	if not events[eventName] then
		events[eventName] = Signal.new()
	end
	return events[eventName].Event
end

--[=[
	Sets the entity configuration for the entity.

	@param entityConfig The entity configuration name to set.
]=]
function Entity.SetConfig(self: Entity, entityConfig: string)
	local config = Config._GetEntityType(entityConfig)
	if not config then
		warn(`Entity config {entityConfig} not found. Using Default config.`)
		config = Config._GetEntityType("DEFAULT")
	end
	SetValue(self, "entityConfig", config, false, config.NAME)
end

--[=[
	Sets the broad phase vector for the entity.

	@param broadPhase The broad phase vector to set.
]=]
function Entity.SetBroadPhase(self: Entity, broadPhase: vector?)
	SetValue(self, "broadPhase", broadPhase)
end

--[=[
	Gets the user associated data with the entity.

	@return The data associated with the entity.
]=]
function Entity.GetData(self: Entity): any
	return self._data
end

--[=[
	Gets the model associated with the entity.

	@return The model associated with the entity.
]=]
function Entity.GetModel(self: Entity): Model | BasePart?
	return self.model
end

--[=[
	Sets the user associated data with the entity.

	@param data The data to associate with the entity.
]=]
function Entity.SetData(self: Entity, data: any)
	SetValue(self, "_data", data, true)
	FireEvent(self, "DataChanged", data)
end

function Entity._SetTickMode(self: Entity, isHalfTicked: boolean?)
	if self.isHalfTicked == isHalfTicked then
		return
	end
	if not self.isContextOwner then
		SetValue(self, "isHalfTicked", isHalfTicked)
	else
		self.isHalfTicked = isHalfTicked
	end
	FireEvent(self, "TickChanged", isHalfTicked == nil and "NONE" or if isHalfTicked then "HALF" else "NORMAL")
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

	SetValue(self, "mountParentId", nil)
	SetValue(self, "mountOffset", nil)
end

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
		warn("An entity cannot mount itself")
		return
	end

	if not parent.id then
		warn("Parent entity must be registered before mounting")
		return
	end

	SetValue(self, "mountParentId", parent.id)
	SetValue(self, "mountOffset", offset)
end

Entity["设置网络主控玩家"] = function(self: Entity, player: Player?)
	if player ~= self.networkOwner then
		local prev = self.networkOwner
		SetValue(self, "networkOwner", player)
		CheckNetworkOwner(self, prev)
		if self.snapshot then
			self.snapshot:Clear()
		end
	end
	self.lastCheckedCFrame = nil
	if not IS_SERVER and self.modelReplicationMode == "CUSTOM" then
		local primaryPart = Entity.GetPrimaryPart(self)
		if primaryPart then
			primaryPart.Anchored = not self.isContextOwner
		end
	end
end

--[=[
	Sets the network owner of the entity. Does nothing if called on the client.

	@param player The player to set as the network owner. If nil, will clear the network owner.
]=]
function Entity.SetNetworkOwner(self: Entity, player: Player?)
	if IS_SERVER and player ~= self.networkOwner then
		Entity["设置网络主控玩家"](self, player)
		SetValue(self, "isHalfTicked", self.isHalfTicked, true)
	elseif not IS_SERVER then
		error("SetNetworkOwner can only be called on the server")
	end
end

--[=[
	Clears the entity's snapshot and latest CFrame/time.
]=]
function Entity.Clear(self: Entity)
	local snapshot = self.snapshot
	self.latestCFrame = nil
	self.latestTime = nil
	if snapshot then
		snapshot:Clear()
	end
end

--[=[
	Pauses replication for the entity.
]=]
function Entity.PauseReplication(self: Entity)
	SetValue(self, "paused", true)
end

--[=[
	Resumes replication for the entity.
]=]
function Entity.ResumeReplication(self: Entity)
	SetValue(self, "paused", false)
end

--[=[
	Pushes a new CFrame value into the entity's snapshot.

	@param time The time associated with the CFrame value.
	@param value The CFrame value to push.

	@return Whether the pushed value is the newest.
]=]
function Entity.Push(self: Entity, time: number, value: CFrame): boolean
	local snapshot = self.snapshot
	local newer = not self.latestTime or time > self.latestTime
	if newer then
		self.latestTime = time
		self.latestCFrame = value
	end
	if snapshot then
		local latest = snapshot:GetLatest()
		if not IS_SERVER and newer and latest and time - latest.t < 5 then
			local targetTime = Entity.GetTargetRenderTime(self)
			if math.abs(targetTime - latest.t) > 5 then
				snapshot:Clear()
				if Config._GetConfig("SHOW_WARNINGS") then
					warn(`Clearing Snapshot due to large time difference`)
				end
			end
		end
		snapshot:Push(time, value, VelocityAt(snapshot:GetLatest(), time, value))
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
	local snapshot = self.snapshot
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
		local RenderCaches = self.entityConfig.CLIENT_CLOCK
		if not RenderCaches then
			return 0
		end
		renderCache = self.isHalfTicked and RenderCaches.HALF or RenderCaches.NORMAL
	end
	if not renderCache then
		return 0
	end
	return renderCache:GetTargetRenderTime()
end

--[=[
	Sets whether the entity should auto update its position to the model's primary part CFrame.

	@param autoUpdate Whether to auto update the entity's position.
]=]
function Entity.SetAutoUpdatePos(self: Entity, autoUpdate: boolean)
	SetValue(self, "autoUpdatePos", autoUpdate)
end

--[=[
	Gets the current CFrame of the entity.

	@return The current CFrame of the entity.
]=]
function Entity.GetCFrame(self: Entity): CFrame?
	local part = GetPart(self.model)
	return self.latestCFrame or (part and part.CFrame)
end

--[=[
	Sets the current CFrame of the entity and locks the snapshot to the new time.

	@param cframe The CFrame to set for the entity. 
]=]
function Entity.SetCFrame(self: Entity, cframe: CFrame)
	local latestTime = (self.latestTime or 0) + 0.02
	if self.snapshot then
		self.snapshot.lockedTime = latestTime
	end
	Entity.Push(self, latestTime, cframe)
	SetValue(self, "latestCFrame", cframe, true)
	SetPartCFrame(self, cframe)
end

--[=[
	Gets the primary part of the entity's model. If the model is a BasePart, returns the model itself.

	@return The primary part of the entity's model, or nil if no model or primary part exists.
]=]
function Entity.GetPrimaryPart(self: Entity): BasePart?
	if self.model then
		return GetPart(self.model)
	end
	return nil
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
		self._lockedCFReplication = true
		local part = GetPart(self.model)
		LockCFReplication(part)
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
			error("LockNativeServerCFrameReplication can only be called on NATIVE model replication mode entities")
		end
		if not self._lockedCFReplication then
			return
		end
		self._lockedCFReplication = false
		local part = GetPart(self.model)
		UnlockCFReplication(part)
		FireEvent(self, "LockChanged", false)
	else
		error("LockNativeServerCFrameReplication can only be called on the server")
	end
end


--[=[
	Returns the current model replication type of the entity, which can be "NATIVE", "CUSTOM", or "NATIVE_WITH_LOCK".
	NATIVE_WITH_LOCK may appear as native on the client.	
]=]
function Entity.GetModelReplicationType(self: Entity): "NATIVE" | "CUSTOM" | "NATIVE_WITH_LOCK"
	local mode = self.modelReplicationMode
	if not mode then
		mode = self.entityConfig.MODEL_REPLICATION_MODE
	end
	if mode == "NATIVE" then
		if self._lockedCFReplication then
			return "NATIVE_WITH_LOCK"
		end
		return "NATIVE"
	end
	return "CUSTOM"
end

--[=[
	Destroys the entity, unregistering it and cleaning up resources.
]=]
function Entity.Destroy(self: Entity)
	self.destroyed = true
	Holder.UnregisterEntity(self)

	if self._clientClock then
		self._clientClock:Destroy()
	end
	FireEvent(self, "Destroying")
	if not IS_SERVER then
		local modeType = self.modelReplicationMode
		local primaryPat = GetPart(self.model)
		if modeType == "CUSTOM" then
			SafeDestroy(self.model)
		elseif primaryPat then
			primaryPat.CFrame = CFrame.new(0, 1000000, 0)
		end
	else
		SafeDestroy(self.model)
	end

	for eventName, signal: Types.Signal<any> in (self._events or {}) :: any do
		signal:DisconnectAll()
	end
	--//TODO: add more
end

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

Players.PlayerAdded:Connect(function(player)
	clientOwned[player] = {}
end)

if Players.LocalPlayer then
	clientOwned[Players.LocalPlayer] = {}
end

Players.PlayerRemoving:Connect(function(player)
	clientOwned[player] = nil
end)

Events._Signals["请不要使用_内部_设置值_拜托谢谢_嗨_这个名字有点长_好吧_再见_算了_这个确实被用了_因为递归错误_而我懒得去解决_所以这是一个能用的_创可贴式修复_好吧"].Event:Connect(
	SetValue
)
Entity._Changes = Changes
Entity._GetPart = GetPart
Entity._SetPartCFrame = SetPartCFrame
return Entity
