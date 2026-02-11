local RunService = game:GetService("RunService")
local Shared = script.Parent.Parent.Shared

local Holder = require(Shared.Holder)
local Entity = require(Shared.Entity)
local Types = require(Shared.Types)
local ModelHelper = require(Shared.ModelHelper)
local Stats = require(Shared.Stats).CLIENT

local BytesReceived = 0
local NewPerSec = 0
local RemovedPerSec = 0
local ChangesPerSec = 0

local SetTickMode = Entity._SetTickMode

local UnreliableEvent = Shared.Remotes.Replicate
local ReliableEvent = Shared.Remotes.ReplicateFull

local TickerHeaderBytes = 4 + 1
local FULL_BYTES = 4 * 3 + 2 * 3
local YAW_BYTES = 4 * 3 + 2

local TAU = 2 * math.pi

local function UnmapRotation(u16: number): number
	return (u16 / 65535) * TAU - math.pi
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
		return
	end
	warn("Tried to remove non existent entity with id", id)
end

local function SetMountId(entity: Types.Entity, mountParentId: number?)
	entity.mountParentId = mountParentId
end

local function SetMountOffset(entity: Types.Entity, mountOffset: CFrame?)
	entity.mountOffset = mountOffset or CFrame.identity
end

local ValueChanges = {
	networkOwner = Entity["设置网络主控玩家"],
	isHalfTicked = SetTickMode,
	_data = Entity.SetData,
	entityConfig = Entity.SetConfig,
	latestCFrame = Entity.SetCFrame,
	autoUpdatePos = Entity.SetAutoUpdatePos,
	mountParentId = SetMountId,
	mountOffset = SetMountOffset,
	broadPhase = Entity.SetBroadPhase,
}

local function HandleChanges(changes: { id: number, data: { { any } } })
	local entity = Holder.GetEntityFromId(changes.id)
	if not entity then
		return
	end

	for _, pair in changes.data do
		local key = pair[1]
		local value = pair[2]

		local handler = ValueChanges[key]
		if handler then
			handler(entity, value)
		elseif key == "model" then
			local model, modelType = ModelHelper.CreateModelFromData(value)
			Entity.SetModel(entity, model, modelType :: any)
			entity.modelReplicationMode = modelType :: any
		elseif key == "_player" then
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
	local model, modelType = ModelHelper.CreateModelFromData(data.model)
	local entity = Entity._new(data.config, model, nil, data.cframe)
	entity.id = data.id
	entity._player = data._player
	entity.paused = data.paused or false
	entity.isHalfTicked = data.isHalfTicked
	entity._data = data._data
	entity.modelReplicationMode = modelType :: any
	entity.mountParentId = data.mountParentId
	entity.mountOffset = data.mountOffset or CFrame.identity
	entity.broadPhase = data.broadPhase or entity.broadPhase

	Entity.Push(entity, data.time, data.cframe)

	Entity["设置网络主控玩家"](entity, data.networkOwner)
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
		local renderCache = entity._clientClock
		if renderCache then
			if isHalfTick then
				renderCache:SetTickRate(renderCache._baseTickRate * 2)
			else
				renderCache:SetTickRate(renderCache._baseTickRate)
			end
			renderCache:OnSnapShot(time)
		end
	else
		local renderCaches = entity.entityConfig.CLIENT_CLOCK
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
	BytesReceived += buffer.len(b)
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
	BytesReceived += bLen
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
	--RunService.PreAnimation:Wait() -- was encountering an issues where instances were not replicated prob was streaming endabled?
	if removedEntities then
		for _, id in removedEntities do
			HandleRemoved(id)
		end
		RemovedPerSec += #removedEntities
	end

	if newEntities then
		for _, data: any in newEntities do
			HandleNewEntity(data)
		end
		NewPerSec += #newEntities
	end

	if entityChanges then
		for _, changeData in entityChanges do
			HandleChanges(changeData)
		end
		ChangesPerSec += #entityChanges
	end
end

UnreliableEvent.OnClientEvent:Connect(HandleUnreliable)
ReliableEvent.OnClientEvent:Connect(HandleReliable)

local lastByteCheckTime = 0
RunService.Heartbeat:Connect(function()
	if os.clock() - lastByteCheckTime > 1 then
		if not Stats._PAUSE then
			Stats.BYTES_RECEIVED_PER_SEC = BytesReceived
			Stats.NEW_ENTITIES_PER_SEC = NewPerSec
			Stats.ENTITY_CHANGES_PER_SEC = ChangesPerSec
			Stats.ENTITY_REMOVALS_PER_SEC = RemovedPerSec
		end
		NewPerSec = 0
		RemovedPerSec = 0
		ChangesPerSec = 0
		BytesReceived = 0
		lastByteCheckTime = os.clock()
	end
end)
return nil
