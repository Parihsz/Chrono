local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Shared = script.Parent.Parent.Shared
local Holder = require(Shared.Holder)
local Types = require(Shared.Types)
local Entity = require(Shared.Entity)
local UnreliableEvent = Shared.Remotes.Replicate

local ClientOwned = Holder._clientOwned
if not ClientOwned[LocalPlayer] then
	ClientOwned[LocalPlayer] = {}
end
local PlayerEntities = ClientOwned[LocalPlayer]

local FULL_BYTES = 4 * 3 + 2 * 3 + 3
local YAW_BYTES = 4 * 3 + 2 + 3
local MAX_BUFFER_SIZE = 900

local BUFFER = buffer.create(MAX_BUFFER_SIZE + 50)
local INDEX = 0

local TAU = math.pi * 2

local clock = 0

local function MapRotation(u16: number): number
	return math.round((u16 + math.pi) / (TAU / 65535))
end

local function FireEvent(entity: Types.Entity, eventName: string, ...: any)
	local events = entity._events
	if not events then
		return
	end
	local signal = events[eventName]
	if signal then
		signal:Fire(entity, ...)
	end
end

local function SerializeFull(b: buffer, cframe: CFrame, index: number)
	local x, y, z = cframe.X, cframe.Y, cframe.Z
	local rx, ry, rz = cframe:ToOrientation()

	buffer.writef32(b, index, x)
	index += 4
	buffer.writef32(b, index, y)
	index += 4
	buffer.writef32(b, index, z)
	index += 4
	buffer.writeu16(b, index, MapRotation(rx))
	index += 2
	buffer.writeu16(b, index, MapRotation(ry))
	index += 2
	buffer.writeu16(b, index, MapRotation(rz))
	index += 2

	return index
end

local function SerializeYaw(b: buffer, cframe: CFrame, index: number)
	local x, y, z = cframe.X, cframe.Y, cframe.Z
	local _, ry, _ = cframe:ToOrientation()

	buffer.writef32(b, index, x)
	index += 4
	buffer.writef32(b, index, y)
	index += 4
	buffer.writef32(b, index, z)
	index += 4
	buffer.writeu16(b, index, MapRotation(ry))
	index += 2

	return index
end

local function Flush()
	if INDEX == 0 then
		return
	end

	local copy = buffer.create(INDEX + 4)
	buffer.writef32(copy, 0, clock)
	buffer.copy(copy, 4, BUFFER, 0, INDEX)
	UnreliableEvent:FireServer(copy)

	INDEX = 0
end

local function WriteEntity(id: number, cf: CFrame, fullCFrame: boolean?, halfTicked: boolean?)
	local length = if fullCFrame then FULL_BYTES else YAW_BYTES

	if INDEX + length > MAX_BUFFER_SIZE then
		Flush()
	end

	buffer.writeu16(BUFFER, INDEX, id)
	INDEX += 2
	local packed = if fullCFrame then 1 else 0

	if halfTicked then
		packed += 2
	end

	buffer.writeu8(BUFFER, INDEX, packed)
	INDEX += 1

	if fullCFrame then
		INDEX = SerializeFull(BUFFER, cf, INDEX)
	else
		INDEX = SerializeYaw(BUFFER, cf, INDEX)
	end
end

local function CFrameChanged(cframe1: CFrame?, cframe2: CFrame?): boolean
	if cframe1 == cframe2 then
		return false
	end
	if cframe1 == nil or cframe2 == nil then
		return true
	end
	return cframe1:FuzzyEq(cframe2, 0.0001) == false
end

local function CheckEntity(entity: Types.Entity)
	if entity.destroyed or entity.paused then
		return
	end

	local config = entity.entityConfig
	local tickRate = config.TICK_RATE

	if entity.isHalfTicked then
		tickRate = tickRate * 2
	elseif entity.isHalfTicked == nil then
		return
	end

	local now = clock
	local lastTime = entity.lastReplicatedTime or 0
	local difference = now - lastTime

	if difference < tickRate then
		return
	end

	entity.lastReplicatedTime = now
	FireEvent(entity, "Ticked", difference)
	local primaryPart = Entity.GetPrimaryPart(entity)

	if entity.autoUpdatePosition and primaryPart then
		entity.latestCFrame = primaryPart.CFrame
	end

	local currentCFrame = entity.latestCFrame
	local lastCFrame = entity.lastCheckedCFrame
	if currentCFrame and CFrameChanged(lastCFrame, currentCFrame) then
		local fullCFrame = config.FULL_ROTATION
		entity.lastCheckedCFrame = currentCFrame

		WriteEntity(entity.id, currentCFrame, fullCFrame, entity.isHalfTicked)
	end
end

local function Update()
	clock = os.clock()
	for entity in PlayerEntities do
		CheckEntity(entity)
	end

	Flush()
end

return {
	Update = Update,
}
