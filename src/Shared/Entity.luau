local Entity = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Types)
local Config = require(script.Parent.Config)
local Snapshot = require(script.Parent.Snapshots)
local InterpolationMath = require(script.Parent.InterpolationMath)
local RenderCache = require(script.Parent.Parent.Client.RenderCache)
local Holder = require(script.Parent.Holder)
local VelocityAt = InterpolationMath.VelocityAt

local clientOwned = Holder._clientOwned
local IS_SERVER = RunService:IsServer()
local LOCAL_PLAYER = if IS_SERVER then nil else Players.LocalPlayer

local function CheckNetworkOwner(self: Types.Entity, prev: Player?)
	self.isContextOwner = self.networkOwner == LOCAL_PLAYER
	if IS_SERVER then
		if self.isContextOwner and not self.entityConfig.STORE_SNAPSHOTS then
			self.snapshot = nil
		else
			self.snapshot = Snapshot(InterpolationMath.Hermite)
		end
	elseif self.networkOwner ~= prev then
		if self._renderCache then
			self._renderCache:Destroy()
			self._renderCache = nil
		end
		if self.networkOwner then
			self._renderCache =
				RenderCache.new(self.entityConfig.TICK_RATE, `Entity id: {self.id} plr: {self.networkOwner.Name}`)
		end
	end
	if self.networkOwner == prev then
		return
	elseif self.snapshot then
		self.snapshot:Clear()
	end
	if self.networkOwner then
		local ownedEntities = clientOwned[self.networkOwner]
		if not ownedEntities then
			return
		end
		ownedEntities[self] = true
	elseif prev then
		local ownedEntities = clientOwned[prev]
		if ownedEntities then
			ownedEntities[self] = nil
		end
	end
end

--[=[
    Creates a New Entity

    @param entityConfig string The name of the entity config to use
    @param model Model | string? The model or model string to use for the entity. The model will be cloned and stored internally. If a string is provided, the model will be looked up from Config.
    @param player Player? Only provide this if this is going to be the players character entity. If you just want to set the network owner, use :SetNetworkOwner after creation.
    @return Entity The created entity
]=]
function Entity.new(entityConfig: string?, model: Model | string?, player: Player?): Types.Entity
	local config = Config._GetEntityType(entityConfig or "DEFAULT")
	local modelString

	if type(model) == "string" then
		modelString = model
		model = Config._GetEntityModel(model :: string)
		if not model and not IS_SERVER then
			warn(`Entity model string {modelString} not found in Config when creating entity. Using default model.`)
		end
	end
	local _model: Model? = model :: any
	if _model and not _model.PrimaryPart then
		error(`{_model:GetFullName()} must have a PrimaryPart set to be used as an Entity model.`)
	elseif _model and not _model.Archivable then
		warn(
			`{_model:GetFullName()} is not Archivable. It is recommended to set Archivable to true for entity models to prevent potential issues when cloning.`
		)
		_model.Archivable = true
	end

	if _model then
		_model = _model:Clone()
		_model.Parent = Config._GetEntityStorageInstance()
	end

	local self: Types.Entity = {
		id = -1,

		registered = false,
		autoUpdatePos = config.AUTO_UPDATE_POS ~= false,
		isContextOwner = false,
		networkOwner = player,
		plrCharacter = player,
		paused = false,

		entityConfig = config,
		model = _model,
		modelString = modelString,
		destroyed = false,
	}
	if LOCAL_PLAYER then
		self.snapshot = Snapshot(InterpolationMath.Hermite)
	end
	CheckNetworkOwner(self, nil)
	return self
end

function Entity.SetNetworkOwner(self: Types.Entity, player: Player?)
	if IS_SERVER and player ~= self.networkOwner then
		local prev = self.networkOwner
		self.networkOwner = player
		CheckNetworkOwner(self, prev)
	elseif not IS_SERVER then
		warn("setNetworkOwner can only be called on the server")
	end
end

function Entity.Clear(self: Types.Entity)
	local snapshot = self.snapshot
	self.latestCFrame = nil
	self.latestTime = nil
	if snapshot then
		snapshot:Clear()
	end
end

function Entity.Push(self: Types.Entity, time: number, value: CFrame): boolean
	local snapshot = self.snapshot
	local newer = not self.latestTime or time > self.latestTime
	if newer then
		self.latestTime = time
		self.latestCFrame = value
	end
	if snapshot then
		local latest = snapshot:GetLatest()
		if newer and latest and time - latest.t < 5 then
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
	return newer
end

function Entity.GetAt(self: Types.Entity, time: number): CFrame?
	local snapshot = self.snapshot
	if snapshot then
		return snapshot:GetAt(time)
	else
		return self.latestCFrame
	end
end

function Entity.GetTargetRenderTime(self: Types.Entity): number
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

function Entity.Destroy(self: Types.Entity)
	self.destroyed = true
	Holder._UnregisterEntity(self)

	if self._renderCache then
		self._renderCache:Destroy()
	end
	if self.model then
		pcall(function()
			self.model:Destroy()
		end)
	end
	--//TODO: add more
end

Players.PlayerAdded:Connect(function(player)
	clientOwned[player] = {}
end)

if Players.LocalPlayer then
	clientOwned[Players.LocalPlayer] = {}
end

Players.PlayerRemoving:Connect(function(player)
	clientOwned[player] = nil
end)

return Entity
