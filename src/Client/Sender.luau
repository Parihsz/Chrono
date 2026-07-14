const Players = game:GetService("Players")
const LocalPlayer = Players.LocalPlayer

const Shared = script.Parent.Parent.Shared
const Holder = require(Shared.Holder)
const Types = require(Shared.Types)
const Entity = require(Shared.Entity)
const ClockUnwrap = require(Shared.ClockUnwrap)
const UnreliableEvent = Shared.Remotes.Replicate
const SafeReplicateEvent = Shared.Remotes.SafeReplicate

const ClientOwned = Holder._clientOwned
if not ClientOwned[LocalPlayer] then
	ClientOwned[LocalPlayer] = {}
end
const PlayerEntities = ClientOwned[LocalPlayer]

const FULL_BYTES = 4 * 3 + 2 * 3 + 3
const YAW_BYTES = 4 * 3 + 2 + 3
const MAX_BUFFER_SIZE = 900

const BUFFER = buffer.create(MAX_BUFFER_SIZE + 50)
local INDEX = 0

const TAU = math.pi * 2

local clock = 0
local hasTeleport = false

const function MapRotation(u16: number): number
	return math.round((u16 + math.pi) / (TAU / 65535))
end

const function FireEvent(entity: Types.Entity, eventName: string, ...: any)
	const events = entity._events
	if not events then
		return
	end
	const signal = events[eventName]
	if signal then
		signal:Fire(entity, ...)
	end
end

const function SerializeFull(b: buffer, cframe: CFrame, index: number)
	const x, y, z = cframe.X, cframe.Y, cframe.Z
	const rx, ry, rz = cframe:ToOrientation()

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

const function SerializeYaw(b: buffer, cframe: CFrame, index: number)
	const x, y, z = cframe.X, cframe.Y, cframe.Z
	const _, ry, _ = cframe:ToOrientation()

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

const function Flush()
	if INDEX == 0 then
		return
	end

	const copy = buffer.create(INDEX + 4)
	buffer.writeu32(copy, 0, ClockUnwrap.quantize(clock))
	buffer.copy(copy, 4, BUFFER, 0, INDEX)
	if hasTeleport then
		SafeReplicateEvent:FireServer(copy)
	else
		UnreliableEvent:FireServer(copy)
	end

	INDEX = 0
end

const function WriteEntity(id: number, cf: CFrame, fullCFrame: boolean?, halfTicked: boolean?, teleport: boolean?)
	const length = if fullCFrame then FULL_BYTES else YAW_BYTES

	if INDEX + length > MAX_BUFFER_SIZE then
		Flush()
	end

	buffer.writeu16(BUFFER, INDEX, id)
	INDEX += 2
	local packed = if fullCFrame then 1 else 0

	if halfTicked then
		packed += 2
	end

	if teleport then
		packed += 4
	end

	buffer.writeu8(BUFFER, INDEX, packed)
	INDEX += 1

	if fullCFrame then
		INDEX = SerializeFull(BUFFER, cf, INDEX)
	else
		INDEX = SerializeYaw(BUFFER, cf, INDEX)
	end
end

const function CFrameChanged(cframe1: CFrame?, cframe2: CFrame?): boolean
	if cframe1 == cframe2 then
		return false
	end
	if cframe1 == nil or cframe2 == nil then
		return true
	end
	return cframe1:FuzzyEq(cframe2, 0.0001) == false
end

--//This is to catch an edge case where the primarypart hasn't been replicated
const function CheckLocker(entity: Types.Entity)
	if entity._cfLockFailed then
		if entity._lockedCFReplication and entity.isContextOwner and not entity._player then
			const part = Entity._GetPart(entity)
			if part then
				Entity._LockPartPhysicsReplication(part)
				entity._cfLockFailed = nil
			end
		else
			entity._cfLockFailed = nil
		end
	end
end

const function CheckEntity(entity: Types.Entity)
	if entity.destroyed or entity.paused then
		return
	end

	const config = entity.entityConfig
	local tickRate = config.TICK_RATE

	if entity.isHalfTicked then
		tickRate = tickRate * 2
	elseif entity.isHalfTicked == nil then
		return
	end

	const now = clock
	const lastTime = entity.lastReplicatedTime or 0
	const difference = now - lastTime

	if difference < tickRate then
		return
	end
	CheckLocker(entity)
	FireEvent(entity, "Ticked", difference)
	const primaryPart = Entity.GetPrimaryPart(entity)

	if entity.autoUpdatePosition and primaryPart then
		Entity.Push(entity, now, primaryPart.CFrame)
	end

	const currentCFrame = entity.latestCFrame
	const lastCFrame = entity.lastCheckedCFrame
	if currentCFrame and CFrameChanged(lastCFrame, currentCFrame) then
		entity.lastReplicatedTime = now
		const fullCFrame = config.FULL_ROTATION
		entity.lastCheckedCFrame = currentCFrame
		hasTeleport = hasTeleport or entity._teleport
		WriteEntity(entity.id, currentCFrame, fullCFrame, entity.isHalfTicked, entity._teleport)
		entity._teleport = nil
	end
end

const function Update()
	clock = os.clock()
	for entity in PlayerEntities do
		CheckEntity(entity)
	end

	Flush()
	hasTeleport = false
end

return {
	Update = Update,
}
