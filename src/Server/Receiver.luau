local RunService = game:GetService("RunService")
local Receiver = {}

local MiddleMans = {}
local SortedMiddleMans = {}
local Shared = script.Parent.Parent.Shared
local Warn = require(Shared.Warn)
local ServerClock = require(script.Parent.ServerClock)
local Types = require(Shared.Types)
local Holder = require(Shared.Holder)
local Entity = require(Shared.Entity)
local Config = require(Shared.Config)
local Stats = require(Shared.Stats).SERVER
local MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = 3000

local BytesReceived = 0

local UnreliableEvent = Shared.Remotes.Replicate

local FULL_BYTES = 4 * 3 + 2 * 3
local YAW_BYTES = 4 * 3 + 2
local TELEPORT_TIME_THRESHOLD = 0.5 

local function FireMiddleMans(player: Player, entity: Types.Entity, cframe: CFrame, arriveTime: number): boolean
	if #SortedMiddleMans == 0 then
		return false
	end
	debug.profilebegin("FireMiddleMans")
	for _, mmData: any in SortedMiddleMans do
		local block = mmData.func(player, entity, cframe, arriveTime)
		if block then
			return true
		end
	end
	debug.profileend()
	return false
end
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

local function DeserializeEntityPacket(b: buffer, index: number): (number, CFrame, number, boolean)
	local id = buffer.readu16(b, index)
	index += 2
	local packed = buffer.readu8(b, index)
	index += 1
	local isFull = bit32.band(packed, 1) == 1
	local isTeleport = bit32.band(packed, 4) == 4

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

local function HandleEntity(
	player: Player,
	id: number,
	serverClock: number,
	clientClock: number,
	cframe: CFrame,
	copyB: buffer,
	isTeleport: boolean
)
	local entity = Holder.GetEntityFromId(id)
	if not entity or entity.networkOwner ~= player then
		return
	end

	if isTeleport then
		local teleportTime = entity._teleport
		if teleportTime and os.clock() - teleportTime < TELEPORT_TIME_THRESHOLD then
			entity._teleport = nil
		else
			local packed = buffer.readu8(copyB, 2)
			buffer.writeu8(copyB, 2, bit32.band(packed, bit32.bnot(4)))
		end
	end

	if FireMiddleMans(player, entity, cframe, serverClock) then
		return
	end
	if Entity.Push(entity, serverClock, cframe) then
		task.spawn(function()
			RunService.PreAnimation:Wait()
			entity.arriveFrame = time()
		end)

		entity.lastClientClock = clientClock
		entity.cframeBuffer = copyB
		if entity.modelReplicationMode == "NATIVE" and not entity._lockedCFReplication then
			return
		end
		Entity._SetPartCFrame(entity, cframe)
	end
end

local TotalBytes = {}
local function OnReceive(player: Player, data: buffer)
	if not data then
		return
	end
	TotalBytes[player] = (TotalBytes[player] or 0) + buffer.len(data)
	BytesReceived += buffer.len(data)
	if TotalBytes[player] > MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER then
		Warn.medium("Player", player.Name, "exceeded max bytes per frame:", TotalBytes[player],"max:", MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER)
		return
	end
	debug.profilebegin("Receiver.OnReceive")
	local index = 0
	local clientClock = buffer.readf32(data, index)
	index += 4
	local serverClock = os.clock()
	local dataLength = buffer.len(data)

	ServerClock.Store(player, clientClock)

	while index < dataLength do
		local id, cframe, newIndex, isTeleport = DeserializeEntityPacket(data, index)
		local copy = buffer.create(newIndex - index)
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
end

Config._WaitForLock(function()
	MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = Config._GetConfig("MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER")
end)
return Receiver
