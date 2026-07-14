const RunService = game:GetService("RunService")
const Players = game:GetService("Players")
const Shared = script.Parent.Parent.Shared

const Warn = require(Shared.Warn)
const Entity = require(Shared.Entity)
const Events = require(Shared.Events)
const Holder = require(Shared.Holder)
const ModelHelper = require(Shared.ModelHelper)
const Types = require(Shared.Types)
const ClockUnwrap = require(Shared.ClockUnwrap)
const Stats = require(Shared.Stats).CLIENT
const ClientClock = require(script.Parent.ClientClock)

local BytesReceived = 0
local NewPerSec = 0
local RemovedPerSec = 0
local ChangesPerSec = 0

const SetTickMode = Entity._SetTickMode

const UnreliableEvent = Shared.Remotes.Replicate
const ReliableEvent = Shared.Remotes.ReplicateFull
const HeartbeatRemote = Shared.Remotes.Heartbeat
const ClientClockRelayRemote = Shared.Remotes.ClientClockRelay

const ServerWrap = ClockUnwrap.new()
const ClientOwnedWrap: ClockUnwrap.Store = {}

const TickerHeaderBytes = 4 + 1
const FULL_BYTES = 4 * 3 + 2 * 3
const YAW_BYTES = 4 * 3 + 2

const TAU = 2 * math.pi

const function UnmapRotation(u16: number): number
	return (u16 / 65535) * TAU - math.pi
end

const function ReadTickerHeader(b: buffer, index: number): (number, boolean, boolean)
	const lastTicked = ClockUnwrap.unwrap(ServerWrap, buffer.readu32(b, index))
	const packed = buffer.readu8(b, index + 4)

	const isHalfTickRate = bit32.band(packed, 1) == 1
	const isFull = bit32.band(packed, 2) == 2

	return lastTicked, isFull, isHalfTickRate
end

const function DeserializeFull(b: buffer, index: number): CFrame
	const x = buffer.readf32(b, index)
	index += 4
	const y = buffer.readf32(b, index)
	index += 4
	const z = buffer.readf32(b, index)
	index += 4

	const rx = UnmapRotation(buffer.readu16(b, index))
	index += 2
	const ry = UnmapRotation(buffer.readu16(b, index))
	index += 2
	const rz = UnmapRotation(buffer.readu16(b, index))
	index += 2

	return CFrame.new(x, y, z) * CFrame.fromOrientation(rx, ry, rz)
end

const function DeserializeYaw(b: buffer, index: number): CFrame
	const x = buffer.readf32(b, index)
	index += 4
	const y = buffer.readf32(b, index)
	index += 4
	const z = buffer.readf32(b, index)
	index += 4

	const ry = UnmapRotation(buffer.readu16(b, index))
	index += 2

	return CFrame.new(x, y, z) * CFrame.fromOrientation(0, ry, 0)
end

const function HandleRemoved(id: number)
	const entity = Holder.GetEntityFromId(id)
	if entity then
		Entity.Destroy(entity)
		return
	end
	Warn.high("Tried to remove non existent entity with id", id)
end

const function SetMountId(entity: Types.Entity, mountParentId: number?)
	entity.mountParentId = mountParentId
	Events._Signals.EntityMountChanged:Fire(entity, mountParentId)
end

const function SetMountOffset(entity: Types.Entity, mountOffset: CFrame?)
	entity.mountOffset = mountOffset or CFrame.identity
end

const ValueChanges = {
	networkOwner = Entity["设置网络主控玩家"],
	isHalfTicked = SetTickMode,
	_data = Entity.SetData,
	entityConfig = Entity.SetConfig,
	autoUpdatePos = Entity.SetAutoUpdatePos,
	mountParentId = SetMountId,
	mountOffset = SetMountOffset,
	broadPhase = Entity.SetBroadPhase,
}

const function HandleChanges(changes: { id: number, data: { { any } } })
	const entity = Holder.GetEntityFromId(changes.id)
	if not entity then
		return
	end
	local hasMetadata
	local modelData
	for _, pair in changes.data do
		const key = pair[1]
		const value = pair[2]

		const handler = ValueChanges[key]
		if handler then
			handler(entity, value)
		elseif key == "latestCFrame" then
			Entity.SetCFrame(entity, value)
		elseif key == "_modelMetaData" then
			hasMetadata = value
		elseif key == "model" then
			modelData = value
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
		elseif key == "_lockedCFReplication" then
			entity._lockedCFReplication = value
			if not value then
				const part = Entity._GetPart(entity)
				if part then
					Entity._UnlockPartPhysicsReplication(part)
				end
			else
				Entity.SyncOwnerShip(entity)
			end
		else
			Warn.high("Unhandled entity change key:", key)
		end
	end

	if modelData ~= nil then
		const model, modelType = ModelHelper.CreateModelFromData(modelData)
		Entity.SetModel(entity, model, modelType :: any)
		entity._modelMetaData = hasMetadata
	end
end

const function HandleNewEntity(data: Types.EntityReceivePacket)
	const model, modelType = ModelHelper.CreateModelFromData(data.model)
	const entity = Entity._new(data.config, model, modelType, data.cframe)

	entity.id = data.id
	entity._player = data._player
	entity._modelMetaData = data._modelMetaData
	entity.paused = data.paused or false
	entity.isHalfTicked = data.isHalfTicked
	entity._data = data._data
	entity.mountParentId = data.mountParentId
	entity.mountOffset = data.mountOffset or CFrame.identity
	entity.broadPhase = data.broadPhase or entity.broadPhase
	entity._lockedCFReplication = data._lockedCFReplication or false

	Entity.Push(entity, data.time, data.cframe)

	Entity["设置网络主控玩家"](entity, data.networkOwner)
	SetTickMode(entity, data.isHalfTicked)
	Holder.RegisterEntity(entity)
end

const function PushCFrameFor(
	id: number,
	clientOwned: boolean,
	cframe: CFrame,
	time: number,
	isHalfTick: boolean,
	teleport: boolean?
): boolean
	const entity = Holder.GetEntityFromId(id)
	if not entity then
		Warn.high("Received update for non existent entity with id", id)
		return false
	end

	const withinTeleportThreshold = entity._teleport and os.clock() - entity._teleport < 0.5
	if withinTeleportThreshold then
		if teleport then
			entity._teleport = nil
		else
			return false
		end
	end

	if clientOwned then
		const renderCache = entity._clientClock
		if renderCache then
			if isHalfTick then
				renderCache:SetTickRate(renderCache._baseTickRate * 2)
			else
				renderCache:SetTickRate(renderCache._baseTickRate)
			end
			renderCache:OnSnapShot(time)
		end
	else
		const renderCaches = entity.entityConfig.CLIENT_CLOCK
		if renderCaches then
			const renderCache = isHalfTick and renderCaches.HALF or renderCaches.NORMAL
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

const function HandleClientOwned(b: buffer)
	BytesReceived += buffer.len(b)
	const bLen = buffer.len(b)
	local index = 0

	while index < bLen do
		const rawTime = buffer.readu32(b, index)
		index += 4
		const length = buffer.readu8(b, index)
		index += 1
		for i = 1, length do
			const id = buffer.readu16(b, index)
			index += 2
			const packed = buffer.readu8(b, index)
			index += 1
			const isFull = bit32.band(packed, 1) == 1
			const isHalfTickRate = bit32.band(packed, 2) == 2
			const teleport = bit32.band(packed, 4) == 4
			local cf: CFrame
			if isFull then
				cf = DeserializeFull(b, index)
				index += FULL_BYTES
			else
				cf = DeserializeYaw(b, index)
				index += YAW_BYTES
			end
			const entity = Holder.GetEntityFromId(id)
			if not entity then
				Warn.medium("Received update for non existent entity with id", id)
				continue
			end
			-- Unwrap in the source player's frame (delta-based, offset-0). Shares state with
			-- this player's other entity packets + the clock relay.
			const time = ClockUnwrap.unwrapFor(ClientOwnedWrap, entity.networkOwner or "__unknown", rawTime)
			PushCFrameFor(id, true, cf, time, isHalfTickRate, teleport)
		end
	end
end

const function HandleServerOwned(b: buffer)
	const bLen = buffer.len(b)
	BytesReceived += bLen
	local index = 0
	while index < bLen do
		const lastTicked, isFull, isHalfTickRate = ReadTickerHeader(b, index)
		index += TickerHeaderBytes
		const length = buffer.readu8(b, index)
		index += 1
		for i = 1, length do
			const id = buffer.readu16(b, index)
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

const function HandleUnreliable(id: string, data: buffer)
	if id == "X" then -- Server Owned
		HandleServerOwned(data)
	elseif id == "O" then -- Client Owned
		HandleClientOwned(data)
	else
		Warn.high("Unknown unreliable replicate id", id)
	end
end

const function HandleReliable(newEntities: {}, removedEntities: { number }, entityChanges: { any })
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

HeartbeatRemote.OnClientEvent:Connect(function(time: number)
	-- Reduce the full-precision server time into the same offset-0 frame as the buffered
	-- server-owned headers, otherwise the two feeds would disagree and freeze the clock.
	const unwrapped = ClockUnwrap.unwrap(ServerWrap, ClockUnwrap.quantize(time))
	for clock in ClientClock.serverOwnedClocks do
		-- Refresh, not OnSnapShot: keep the clock fresh without feeding the heartbeat
		-- cadence into the interpolation buffer's jitter estimate.
		clock:Refresh(unwrapped)
	end
end)

-- Client-clock relay: reseats each source to the server's authoritative wrap offset so every
-- receiver agrees on the source's epoch regardless of join time. max() avoids regressing a wrap
-- this client already witnessed between relays.
ClientClockRelayRemote.OnClientEvent:Connect(function(list: { { player: Player, raw: number, offset: number } })
	if type(list) ~= "table" then
		return
	end
	for _, entry in list do
		const player = entry.player
		const raw = entry.raw
		const offset = entry.offset
		if player and type(raw) == "number" and type(offset) == "number" then
			local state = ClientOwnedWrap[player]
			if not state then
				state = ClockUnwrap.new()
				ClientOwnedWrap[player] = state
			end
			state.lastRaw = raw
			state.offset = math.max(state.offset, offset)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ClientOwnedWrap[player] = nil
end)

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
