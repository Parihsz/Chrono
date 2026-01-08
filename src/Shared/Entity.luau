local Entity = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)
local Config = require(script.Parent.Config)
local Snapshot = require(script.Parent.Snapshots)
local InterpolationMath = require(script.Parent.InterpolationMath)
local RenderCache = require(script.Parent.Parent.Client.RenderCache)
local Holder = require(script.Parent.Holder)
local Signal = require(script.Parent.Signal)
local Events = require(script.Parent.Events)
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
	if IS_SERVER then
		if not isSameOwner then
			if self.model and self.model.PrimaryPart then
				SafeSetNetworkOwner(self.model.PrimaryPart, self.networkOwner)
			end
		end
		if self.isContextOwner and not self.entityConfig.STORE_SNAPSHOTS then
			self.snapshot = nil
		else
			self.snapshot = Snapshot(InterpolationMath.Hermite)
		end
	elseif not isSameOwner then
		if self._renderCache then
			self._renderCache:Destroy()
			self._renderCache = nil
		end
		if self.networkOwner then
			self._renderCache =
				RenderCache.new(self.entityConfig.TICK_RATE, `Entity id: {self.id} plr: {self.networkOwner.Name}`)
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

local function CheckModelReplicationMode(
	entity: Entity,
	mode: "NATIVE" | "MIRRORED" | "CUSTOM"?
): "NATIVE" | "MIRRORED" | "CUSTOM"
	if not mode then
		local config = entity.entityConfig
		mode = config.MODEL_REPLICATION_MODE
	end
	mode = (mode :: any):upper()
	if mode ~= "NATIVE" and mode ~= "MIRRORED" and mode ~= "CUSTOM" then
		warn(`Invalid model replication mode {mode} for entity id {entity.id}, defaulting to NATIVE`)
		mode = "NATIVE"
	end
	return mode :: any
end

function Entity.new(
	entityConfig: string?,
	model: Model | string?,
	modelReplicationMode: "NATIVE" | "MIRRORED" | "CUSTOM"?
): Entity
	local config = Config._GetEntityType(entityConfig or "DEFAULT")
	if not config then
		warn(`Entity config {entityConfig} not found. Using DEFAULT config.`)
		config = Config._GetEntityType("DEFAULT")
	end

	local modelString

	if type(model) == "string" then
		modelString = model
		model = Config._GetEntityModel(model :: string)
	end
	local _model: Model? = model :: any
	if _model and not _model.PrimaryPart then
		warn(`{_model:GetFullName()} must have a PrimaryPart set for things like autoReplication and movement.`)
	elseif _model and not _model.Archivable then
		warn(
			`{_model:GetFullName()} is not Archivable. It is recommended to set Archivable to true for entity models to prevent potential issues when cloning. Archivable has been set to true automatically.`
		)
		_model.Archivable = true
	end

	local self: Entity = {
		id = -1,

		registered = false,
		autoUpdatePos = config.AUTO_UPDATE_POS ~= false,
		isContextOwner = false,
		networkOwner = nil,

		paused = false,

		entityConfig = config,
		model = _model,
		modelString = modelString,
		destroyed = false,
	}
	local modelRepMode: "NATIVE" | "MIRRORED" | "CUSTOM" = CheckModelReplicationMode(self, modelReplicationMode)

	if IS_SERVER then
		self.modelRepMode = modelRepMode
		if modelRepMode == "MIRRORED" and _model then
			local fakeModel = _model:Clone()
			_model.Parent = workspace -- ensure it's in workspace to set network ownership
			if _model.PrimaryPart then
				pcall(function()
					_model.PrimaryPart:SetNetworkOwnershipAuto()
				end)
			end
			_model.Parent = script.Parent._MIRRORED_MODELS
			self.actualModel = _model
			self.model = fakeModel
			fakeModel.Parent = Holder.GetEntityStorageInstance()
		elseif modelRepMode == "CUSTOM" and _model then
			_model.Parent = Holder.GetEntityStorageInstance()
		end
	end

	if LOCAL_PLAYER then
		self.snapshot = Snapshot(InterpolationMath.Hermite)
	end
	CheckNetworkOwner(self, nil)
	return self
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

function Entity.SetConfig(self: Entity, entityConfig: string)
	local config = Config._GetEntityType(entityConfig)
	if not config then
		warn(`Entity config {entityConfig} not found. Using Default config.`)
		config = Config._GetEntityType("DEFAULT")
	end
	SetValue(self, "entityConfig", config, false, config.NAME)
end

function Entity.GetData(self: Entity): any
	return self._data
end

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

function Entity._SetNetworkOwner(self: Entity, player: Player?)
	if player ~= self.networkOwner then
		local prev = self.networkOwner
		SetValue(self, "networkOwner", player)
		CheckNetworkOwner(self, prev)
		if self.snapshot then
			self.snapshot:Clear()
		end
	end
end

function Entity.SetNetworkOwner(self: Entity, player: Player?)
	if IS_SERVER and player ~= self.networkOwner then
		Entity._SetNetworkOwner(self, player)
	elseif not IS_SERVER then
		warn("SetNetworkOwner can only be called on the server")
	end
end

function Entity.Clear(self: Entity)
	local snapshot = self.snapshot
	self.latestCFrame = nil
	self.latestTime = nil
	if snapshot then
		snapshot:Clear()
	end
end

function Entity.PauseReplication(self: Entity)
	SetValue(self, "paused", true)
end

function Entity.ResumeReplication(self: Entity)
	SetValue(self, "paused", false)
end

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

function Entity.GetAt(self: Entity, time: number): CFrame?
	local snapshot = self.snapshot
	if snapshot then
		return snapshot:GetAt(time)
	else
		return self.latestCFrame
	end
end

function Entity.GetTargetRenderTime(self: Entity): number
	local renderCache = self._renderCache

	if not renderCache then
		local RenderCaches = self.entityConfig.RENDER_CACHE
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

function Entity.SetAutoUpdatePos(self: Entity, autoUpdate: boolean)
	SetValue(self, "autoUpdatePos", autoUpdate)
end

function Entity.SetCFrame(self: Entity, cframe: CFrame)
	Entity.Push(self, os.clock(), cframe)
	SetValue(self, "latestCFrame", cframe, true)
	if self.model and self.model.PrimaryPart then
		self.model.PrimaryPart.CFrame = cframe
	end
end

function Entity.Destroy(self: Entity)
	self.destroyed = true
	Holder.UnregisterEntity(self)

	if self._renderCache then
		self._renderCache:Destroy()
	end
	FireEvent(self, "Destroying")
	if not IS_SERVER then
		local modeType = self.modelRepMode
		if modeType == "MIRRORED" then
			if self.model then
				self.model.Parent = script.Parent._MIRRORED_MODELS
			end
		elseif modeType == "CUSTOM" then
			SafeDestroy(self.model)
		elseif self.model and self.model.PrimaryPart then
			self.model.PrimaryPart.CFrame = CFrame.new(0, 1000000, 0)
		end
	else
		SafeDestroy(self.model)
	end

	SafeDestroy(self.actualModel)

	--//TODO: add more
end

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
) -> Types.Event<(entity: Entity, dt: number) -> (), Entity, number>)

Players.PlayerAdded:Connect(function(player)
	clientOwned[player] = {}
end)

if Players.LocalPlayer then
	clientOwned[Players.LocalPlayer] = {}
end

Players.PlayerRemoving:Connect(function(player)
	clientOwned[player] = nil
end)

Events._Signals._DO_NOT_USE_INTERNAL_SET_VALUE_PLEASE_THANKS_HI_THIS_IS_A_BIT_LONG_YEAH_OKAY_BYE_NVM_THIS_IS_USED_CAUSE_RECURSIVE_ERROR_AND_I_AM_TO_LAZY_TO_SOLVE_THAT_SO_THIS_IS_A_BAND_AID_FIX_THAT_WORKS_OKAY.Event:Connect(
	SetValue
)
Entity._Changes = Changes
return Entity
