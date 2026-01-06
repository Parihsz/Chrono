local Shared = script.Parent.Parent.Shared
local RenderCache = require(script.Parent.RenderCache)
local Holder = require(Shared.Holder)
local Entity = require(Shared.Entity)
local Types = require(Shared.Types)

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

local function HandleNewEntity(data: Types.EntityReceivePacket)
	local entity = Entity.new(data.config, data.model or data.modelString, data.plrCharacter)
	entity.id = data.id
	entity.plrCharacter = data.plrCharacter
	entity.paused = data.paused or false
	Entity.Push(entity, data.time, data.cframe)
	entity.isHalfTicked = data.isHalfTicked
	Entity.SetNetworkOwner(entity, data.networkOwner) 
	Holder._RegisterEntity(entity)
end

local function PushCFrameFor(id: number, clientOwned: boolean, cframe: CFrame, time: number, isHalfTick: boolean)
	local entity = Holder.GetEntityFromId(id)
	if not entity then
		warn("Received update for non existent entity with id", id)
		return
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

	entity.isHalfTicked = isHalfTick
	Entity.Push(entity, time, cframe)
end

local function HandleClientOwned(b: buffer)
	local bLen = buffer.len(b)
	local index = 0
	while index < bLen do
		local time = buffer.readf32(b, index)
		index += 4
		while index < bLen do
			if buffer.readu8(b, index) == 0 then
				index += 1
				break
			end
			local id = buffer.readu16(b, index)
			index += 2
			local packed = buffer.readu8(b, index)
			index +=1
			local isFull = bit32.band(packed, 1) == 1
			local isHalfTickRate = bit32.band(packed, 2) == 2
			local cf:CFrame
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

		while index < bLen do
			--// Check for null terminator
			if buffer.readu8(b, index) == 0 then
				index += 1
				break
			end
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

local function HandleReliable(newEntities: {}, removedEntities: { number })
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
end

UnreliableEvent.OnClientEvent:Connect(HandleUnreliable)
ReliableEvent.OnClientEvent:Connect(HandleReliable)

return nil
