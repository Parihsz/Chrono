local Shared = script.Parent.Parent.Shared
local Holder = require(Shared.Holder)
local Entity = require(Shared.Entity)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local SetTickMode = Entity._SetTickMode

local UnreliableEvent = Shared.Remotes.Replicate
local ReliableEvent = Shared.Remotes.ReplicateFull

local TickerHeaderBytes = 4 + 1
local FULL_BYTES = 4 * 3 + 2 * 3
local YAW_BYTES = 4 * 3 + 2
local function UnmapRotation(x: number): number
	return (x / 65535) * (2 * math.pi) - math.pi
end

local function ReadTickerHeader(b: buffer, index: number): (number, boolean, boolean)
	local lastTicked = buffer.readf32(b, index)
	local packed = buffer.readu8(b, index + 4)
	local isHalfTickRate = bit32.band(packed, 1) == 1
	local isFull = bit32.band(packed, 2) == 2
	return lastTicked, isFull, isHalfTickRate
end

local function DeserializeFull(b: buffer, index: number): CFrame
	local x = buffer.readf32(b, index)
	index += 4
	local y = buffer.readf32(b, index)
	index += 4
	local z = buffer.readf32(b, index)
	index += 4
	local rx = UnmapRotation(buffer.readu16(b, index))
	index += 2
	local ry = UnmapRotation(buffer.readu16(b, index))
	index += 2
	local rz = UnmapRotation(buffer.readu16(b, index))
	index += 2
	return CFrame.new(x, y, z) * CFrame.fromOrientation(rx, ry, rz)
end

local function DeserializeYaw(b: buffer, index: number): CFrame
	local x = buffer.readf32(b, index)
	index += 4
	local y = buffer.readf32(b, index)
	index += 4
	local z = buffer.readf32(b, index)
	index += 4
	local ry = UnmapRotation(buffer.readu16(b, index))
	index += 2
	return CFrame.new(x, y, z) * CFrame.fromOrientation(0, ry, 0)
end
local function HandleRemoved(id: number)
	local entity = Holder.GetEntityFromId(id)
	if entity then
		Entity.Destroy(entity)
	else
		warn("Tried to remove non existent entity with id", id)
	end
end

local function CreateTempModel(): Model
	local model = Instance.new("Model")
	model.Name = "TempModel"
	local part = Instance.new("Part")
	part.Size = Vector3.new(3, 5, 3)
	part.Anchored = true
	part.Parent = model
	part.Name = "Failed To Get Model"
	model.PrimaryPart = part
	model.Parent = workspace
	return model, "CUSTOM"
end

local function HandleModel(model: Model | string?): (Model?, string?)
	if not model then
		return
	end
	if type(model) == "string" then
		local clone = Config._GetEntityModel(model)
		if clone then
			local modelClone = clone:Clone()
			if not modelClone then
				return CreateTempModel()
			end
			clone.Parent = Holder.GetEntityStorageInstance()
		end
		return CreateTempModel()
	end

	if model.Parent == script.Parent.Parent.Shared._MIRRORED_MODELS then
		model.Parent = Holder.GetEntityStorageInstance()
		return model, "MIRRORED"
	elseif
		model.Parent == script.Parent.Parent.Shared._CUSTOM_MODEL_REP
		or (
			model.Parent
			and model.Parent.Name == "_ChronoClientModels"
			and model.Parent.Parent
			and model.Parent.Parent:IsA("PlayerGui")
		)
	then
		local modelClone = model:Clone()
		if not modelClone then
			return CreateTempModel()
		end
		modelClone.Parent = Holder.GetEntityStorageInstance()
		return modelClone, "CUSTOM"
	else
		return model, "NATIVE"
	end
end

local ValueChanges = {
	networkOwner = Entity._SetNetworkOwner,
	isHalfTicked = SetTickMode,
	_data = Entity.SetData,
	entityConfig = Entity.SetConfig,
	latestCFrame = Entity.SetCFrame,
	autoUpdatePos = Entity.SetAutoUpdatePos,
}

local function HandleChanges(changes: { id: number, data: { { any } } })
	local id = changes.id
	local data = changes.data
	local entity = Holder.GetEntityFromId(id)
	if not entity then
		return
	end
	for _, pair in data do
		local key = pair[1]
		local value = pair[2]
		print("Handling change for entity", id, "key", key, "value", value)
		local handler = ValueChanges[key]
		if handler then
			handler(entity, value)
		elseif key == "_plrCharacter" then
			if value then
				Holder.SetAsCharacter(value, entity)
			else
				Holder.RemovePlayerCharacter(entity)
			end
		elseif key == "paused" then
			if value then
				Entity.PauseReplication(entity)
			else
				Entity.ResumeReplication(entity)
			end
		else
			warn("Unhandled entity change key:", key)
		end
	end
end

local function HandleNewEntity(data: Types.EntityReceivePacket)
	local model, type = HandleModel(data.model)

	local entity = Entity.new(data.config, model)
	entity.id = data.id
	entity._plrCharacter = data._plrCharacter
	entity.paused = data.paused or false
	entity.isHalfTicked = data.isHalfTicked
	entity._data = data._data
	entity.modelRepMode = type :: any
	Entity.Push(entity, data.time, data.cframe)

	Entity._SetNetworkOwner(entity, data.networkOwner)
	SetTickMode(entity, data.isHalfTicked)

	Holder.RegisterEntity(entity)
end

local function PushCFrameFor(
	id: number,
	clientOwned: boolean,
	cframe: CFrame,
	time: number,
	isHalfTick: boolean
): boolean
	local entity = Holder.GetEntityFromId(id)
	if not entity then
		warn("Received update for non existent entity with id", id)
		return false
	end
	if clientOwned then
		local renderCache = entity._renderCache
		if renderCache then
			if isHalfTick then
				renderCache:SetTickRate(renderCache._baseTickRate * 2)
			else
				renderCache:SetTickRate(renderCache._baseTickRate)
			end
			renderCache:OnSnapShot(time)
		end
	else
		local renderCaches = entity.entityConfig.RENDER_CACHE
		if renderCaches then
			local renderCache = isHalfTick and renderCaches.HALF or renderCaches.NORMAL
			if renderCache then
				renderCache:OnSnapShot(time)
			end
		end
	end

	if entity.isHalfTicked ~= isHalfTick then
		SetTickMode(entity, isHalfTick)
	end
	entity.isHalfTicked = isHalfTick
	Entity.Push(entity, time, cframe)
	return true
end

local function HandleClientOwned(b: buffer)
	local bLen = buffer.len(b)
	local index = 0
	while index < bLen do
		local time = buffer.readf32(b, index)
		index += 4
		local length = buffer.readu8(b, index)
		index += 1
		for i = 1, length do
			local id = buffer.readu16(b, index)
			index += 2
			local packed = buffer.readu8(b, index)
			index += 1
			local isFull = bit32.band(packed, 1) == 1
			local isHalfTickRate = bit32.band(packed, 2) == 2
			local cf: CFrame
			if isFull then
				cf = DeserializeFull(b, index)
				index += FULL_BYTES
			else
				cf = DeserializeYaw(b, index)
				index += YAW_BYTES
			end
			PushCFrameFor(id, true, cf, time, isHalfTickRate)
		end
	end
end

local function HandleServerOwned(b: buffer)
	local bLen = buffer.len(b)
	local index = 0
	while index < bLen do
		local lastTicked, isFull, isHalfTickRate = ReadTickerHeader(b, index)
		index += TickerHeaderBytes
		local length = buffer.readu8(b, index)
		index += 1
		for i = 1, length do
			local id = buffer.readu16(b, index)
			index += 2
			local cframe
			if isFull then
				cframe = DeserializeFull(b, index)
				index += FULL_BYTES
			else
				cframe = DeserializeYaw(b, index)
				index += YAW_BYTES
			end
			PushCFrameFor(id, false, cframe, lastTicked, isHalfTickRate)
		end
	end
end

local function HandleUnreliable(id: string, data: buffer)
	if id == "X" then -- Server Owned
		HandleServerOwned(data)
	elseif id == "O" then -- Client Owned
		HandleClientOwned(data)
	else
		warn("Unknown unreliable replicate id", id)
	end
end

local function HandleReliable(newEntities: {}, removedEntities: { number }, entityChanges: { any })
	if removedEntities then
		for _, id in removedEntities do
			HandleRemoved(id)
		end
	end
	if newEntities then
		for _, data: any in newEntities do
			HandleNewEntity(data)
		end
	end
	if entityChanges then
		for _, changeData in entityChanges do
			HandleChanges(changeData)
		end
	end
end

UnreliableEvent.OnClientEvent:Connect(HandleUnreliable)
ReliableEvent.OnClientEvent:Connect(HandleReliable)

return nil
