local RunService = game:GetService("RunService")
local Receiver = {}

local Shared = script.Parent.Parent.Shared
local ServerClock = require(script.Parent.ServerClock)
local Holder = require(Shared.Holder)
local Entity = require(Shared.Entity)

local UnreliableEvent = Shared.Remotes.Replicate

local FULL_BYTES = 4 * 3 + 2 * 3
local YAW_BYTES = 4 * 3 + 2

local function UnmapRotation(x: number): number
	return (x / 65535) * (2 * math.pi) - math.pi
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

local function DeserializeEntityPacket(b: buffer, index: number): (number, CFrame, number)
	local id = buffer.readu16(b, index)
	index += 2
	local packed = buffer.readu8(b, index)
	index += 1
	local isFull = bit32.band(packed, 1) == 1

	local cframe: CFrame
	if isFull then
		cframe = DeserializeFull(b, index)
		index += FULL_BYTES
	else
		cframe = DeserializeYaw(b, index)
		index += YAW_BYTES
	end

	return id, cframe, index
end

local function HandleEntity(player: Player, id: number, clock: number, cframe: CFrame, copyB: buffer)
	local entity = Holder.GetEntityFromId(id)
	if not entity or entity.networkOwner ~= player then
		return
	end

	if Entity.Push(entity, clock, cframe) then
		task.spawn(function()
			RunService.PreAnimation:Wait()
			entity.arriveFrame = time()
		end)

		entity.cframeBuffer = copyB
		if entity.modelReplicationMode == "NATIVE" and not entity._lockedCFReplication then
			return
		end
		Entity._SetPartCFrame(entity, cframe)
	end
end

local function OnReceive(player: Player, data: buffer)
	local index = 0
	local clock = buffer.readf32(data, index)
	index += 4
	local dataLength = buffer.len(data)

	ServerClock.Store(player, clock)

	while index < dataLength do
		local id, cframe, newIndex = DeserializeEntityPacket(data, index)
		local copy = buffer.create(newIndex - index)
		buffer.copy(copy, 0, data, index, newIndex - index)
		index = newIndex
		HandleEntity(player, id, clock, cframe, copy)
	end
end

UnreliableEvent.OnServerEvent:Connect(OnReceive)
return Receiver
