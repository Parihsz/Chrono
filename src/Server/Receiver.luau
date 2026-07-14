const RunService = game:GetService("RunService")
const Players = game:GetService("Players")
const Receiver = {}

const MiddleMans = {}
local SortedMiddleMans = {}
const Shared = script.Parent.Parent.Shared
const Ticker = require(Shared.Ticker)
const InterpolationMath = require(Shared.InterpolationMath)
const Warn = require(Shared.Warn)
const ServerClock = require(script.Parent.ServerClock)
const Types = require(Shared.Types)
const Holder = require(Shared.Holder)
const Entity = require(Shared.Entity)
const Config = require(Shared.Config)
const ClockUnwrap = require(Shared.ClockUnwrap)
const Stats = require(Shared.Stats).SERVER

const ClientClockWrap: ClockUnwrap.Store = {}
local BASE_MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = 300

Config._WaitForLock(function()
	BASE_MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = Config._GetConfig("MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER")
end)

local BytesReceived = 0

const UnreliableEvent = Shared.Remotes.Replicate
const SafeReplicateEvent = Shared.Remotes.SafeReplicate

const FULL_BYTES = 4 * 3 + 2 * 3
const YAW_BYTES = 4 * 3 + 2
const BASE_TELEPORT_TIME_THRESHOLD = 0.5

const function FireMiddleMans(player: Player, entity: Types.Entity, cframe: CFrame, arriveTime: number): boolean
	if #SortedMiddleMans == 0 then
		return false
	end
	debug.profilebegin("FireMiddleMans")
	for _, mmData: any in SortedMiddleMans do
		const block = mmData.func(player, entity, cframe, arriveTime)
		if block then
			return true
		end
	end
	debug.profileend()
	return false
end
const function UnmapRotation(x: number): number
	return (x / 65535) * (2 * math.pi) - math.pi
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

const function DeserializeEntityPacket(b: buffer, index: number): (number, CFrame, number, boolean)
	const id = buffer.readu16(b, index)
	index += 2
	const packed = buffer.readu8(b, index)
	index += 1
	const isFull = bit32.band(packed, 1) == 1
	const isTeleport = bit32.band(packed, 4) == 4

	local cframe: CFrame
	if isFull then
		cframe = DeserializeFull(b, index)
		index += FULL_BYTES
	else
		cframe = DeserializeYaw(b, index)
		index += YAW_BYTES
	end

	return id, cframe, index, isTeleport
end

const function CalculateMaxThroughputForPlayer(player: Player): number
	local numberOfEntities = 0
	for _ in Holder._clientOwned[player] or {} do
		numberOfEntities += 1
	end
	return BASE_MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER + numberOfEntities * (FULL_BYTES + 3)
end

const function HandleEntity(
	player: Player,
	id: number,
	serverClock: number,
	clientClock: number,
	cframe: CFrame,
	copyB: buffer,
	isTeleport: boolean
)
	const entity = Holder.GetEntityFromId(id)
	if not entity or entity.networkOwner ~= player then
		return
	end

	const teleportTime = entity._teleport
	const ping = math.max(player:GetNetworkPing(), 0) + 0.05

	const withinTeleportThreshold = teleportTime and os.clock() - teleportTime < (BASE_TELEPORT_TIME_THRESHOLD + ping)
	if isTeleport then
		if withinTeleportThreshold then
			entity._teleport = nil
		else
			const packed = buffer.readu8(copyB, 2)
			buffer.writeu8(copyB, 2, bit32.band(packed, bit32.bnot(4)))
		end
	elseif withinTeleportThreshold then
		return
	end

	if entity.lastClientClock and clientClock < entity.lastClientClock then
		return
	end

	debug.profilebegin("HandleEntity.FireMiddleMans")
	if FireMiddleMans(player, entity, cframe, serverClock) then
		debug.profileend()
		return
	end
	debug.profileend()
	local velocity = nil
	if Config.FLAGS.SERVER_VELOCITY_FIX and entity.snapshot then
		const latest = entity.snapshot:GetLatest()
		const lastClientClock = entity.lastClientClock or clientClock
		local tickrate = entity.entityConfig.TICK_RATE
		if entity.isHalfTicked then
			tickrate = tickrate * 2
		end
		if latest then
			velocity = InterpolationMath.CalculateVelocity(
				latest.value.Position,
				lastClientClock,
				cframe.Position,
				clientClock,
				tickrate
			)
		end
	end
	if Entity.Push(entity, serverClock, cframe, velocity) then
		entity.arriveFrame = Ticker.GetGlobalTick()

		entity.lastClientClock = clientClock
		entity.cframeBuffer = copyB
		if entity.modelReplicationMode == "NATIVE" and not entity._lockedCFReplication then
			return
		end
		Entity._SetPartCFrame(entity, cframe)
	end
end

const TotalBytes = {}
const function OnReceive(player: Player, data: buffer)
	if not data then
		return
	end
	TotalBytes[player] = (TotalBytes[player] or 0) + buffer.len(data)
	BytesReceived += buffer.len(data)
	const maxBytes = CalculateMaxThroughputForPlayer(player)
	if TotalBytes[player] > maxBytes then
		Warn.medium("Player", player.Name, "exceeded max bytes per frame:", TotalBytes[player], "max:", maxBytes)
		return
	end
	debug.profilebegin("Receiver.OnReceive")
	local index = 0
	const clientClock = ClockUnwrap.unwrapFor(ClientClockWrap, player, buffer.readu32(data, index))
	index += 4
	const serverClock = os.clock()
	const dataLength = buffer.len(data)

	ServerClock.Store(player, clientClock)

	while index < dataLength do
		const id, cframe, newIndex, isTeleport = DeserializeEntityPacket(data, index)
		const copy = buffer.create(newIndex - index)
		buffer.copy(copy, 0, data, index, newIndex - index)
		index = newIndex
		HandleEntity(player, id, serverClock, clientClock, cframe, copy, isTeleport)
	end
	debug.profileend()
end

--[=[
	Registers a middle man function that can intercept incoming entity updates.

	@param name The unique name of the middle man
	@param priority The priority of the middle man ( higher priority runs first )
	@param func The function to call. Should return true to block the update, else allow it.
]=]
function Receiver.RegisterMiddleMan(
	name: string,
	priority: number,
	func: (
		player: Player,
		entity: Types.Entity,
		cframe: CFrame,
		arriveTime: number
	) -> boolean
)
	MiddleMans[name] = { priority = priority, func = func }
	SortedMiddleMans = {}
	for mm, data in MiddleMans do
		table.insert(SortedMiddleMans, data)
	end
	table.sort(SortedMiddleMans, function(a, b)
		return a.priority > b.priority
	end)
end

--[=[
	Unregisters a middle man function.
	@param name The unique name of the middle man
]=]
function Receiver.UnregisterMiddleMan(name: string)
	MiddleMans[name] = nil
	SortedMiddleMans = {}
	for mm, data in MiddleMans do
		table.insert(SortedMiddleMans, data)
	end
	table.sort(SortedMiddleMans, function(a, b)
		return a.priority > b.priority
	end)
end

if RunService:IsServer() then
	local lastByteCheckTime = 0
	RunService.Heartbeat:Connect(function(a0: number)
		table.clear(TotalBytes)

		if os.clock() - lastByteCheckTime > 1 then
			Stats.BYTES_RECEIVED_PER_SEC = BytesReceived
			BytesReceived = 0
			lastByteCheckTime = os.clock()
		end
	end)
	UnreliableEvent.OnServerEvent:Connect(OnReceive)
	SafeReplicateEvent.OnServerEvent:Connect(OnReceive)

	Shared.Remotes.ClientHeartbeat.OnServerEvent:Connect(function(player: Player, seconds: number)
		if type(seconds) ~= "number" then
			return
		end
		const clientClock = ClockUnwrap.seatFullFor(ClientClockWrap, player, seconds)
		ServerClock.Store(player, clientClock)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ClientClockWrap[player] = nil
	end)
end

function Receiver._GetClientClockRaws(): { { player: Player, raw: number, offset: number } }
	const out = {}
	for player, state in ClientClockWrap do
		if state.lastRaw then
			table.insert(out, { player = player, raw = state.lastRaw, offset = state.offset })
		end
	end
	return out
end

return Receiver
