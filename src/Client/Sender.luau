local Sender = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Shared = script.Parent.Parent.Shared
local Holder = require(Shared.Holder)
local Types = require(Shared.Types)
local Config = require(Shared.Config)
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
local function MapRotation(x: number): number
	return math.round((x + math.pi) / (2 * math.pi / 65535))
end

local function SerializeFull(b: buffer, cf: CFrame, index: number)
	local x, y, z = cf.X, cf.Y, cf.Z
	local rx, ry, rz = cf:ToOrientation()
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

local function SerializeYaw(b: buffer, cf: CFrame, index: number)
	local x, y, z = cf.X, cf.Y, cf.Z
	local _, ry, _ = cf:ToOrientation()
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

local BUFFER = buffer.create(MAX_BUFFER_SIZE + 50)
local INDEX = 0
local clock = 0


local function flush()
    if INDEX == 0 then
        return
    end
	local copy = buffer.create(INDEX+4)
    buffer.writef32(copy,0, clock)
	buffer.copy(copy, 4, BUFFER, 0, INDEX)
	UnreliableEvent:FireServer(copy)
	INDEX = 0
end


local function WriteEntity(
	id: number,
	cf: CFrame,
	fullCFrame: boolean?,
	halfTicked: boolean?
)

    local length = if fullCFrame then FULL_BYTES else YAW_BYTES

    if INDEX + length > MAX_BUFFER_SIZE then
        flush()
    end

	buffer.writeu16(BUFFER, INDEX, id)
	INDEX += 2
    local packed = if fullCFrame then 1 else 0
    if halfTicked then
        packed += 2
    end
    buffer.writeu8(BUFFER, INDEX, packed)
    INDEX +=1
	if fullCFrame then
		INDEX = SerializeFull(BUFFER, cf, INDEX)
	else
		INDEX = SerializeYaw(BUFFER, cf, INDEX)
	end
    print("Written entity", id, "fullCFrame:", fullCFrame, "halfTicked:", halfTicked)
end

local function CFrameChanged(cf1: CFrame?, cf2: CFrame?): boolean
	if cf1 == cf2 then
		return false
	end
	if cf1 == nil or cf2 == nil then
		return true
	end
	return cf1:FuzzyEq(cf2, 0.0001) == false
end


local function CheckEntity(entity: Types.Entity)
	if entity.destroyed then
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
	if now - lastTime < tickRate then
		return
	end
	entity.lastReplicatedTime = now

	local model = entity.model
	if entity.autoUpdatePos and model and model.PrimaryPart then
		entity.latestCFrame = model.PrimaryPart.CFrame
	end
	local currentCFrame = entity.latestCFrame
	local lastCFrame = entity.lastCheckedCFrame
	if currentCFrame and CFrameChanged(lastCFrame, currentCFrame) then
		local fullCFrame = config.FULL_ROTATION
		entity.lastCheckedCFrame = currentCFrame
         WriteEntity(
            entity.id,
            currentCFrame,
            fullCFrame,
            entity.isHalfTicked
        )
	end
end

local function Update()
    clock = os.clock()
	for entity in PlayerEntities do
		CheckEntity(entity)
	end
    flush()
end

return {
    Update = Update,
}
