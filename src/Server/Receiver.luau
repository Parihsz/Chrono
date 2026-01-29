local RunService = game:GetService("RunService")
local Receiver = {}

local MiddleMans = {}
local SortedMiddleMans = {}
local Shared = script.Parent.Parent.Shared
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

	if FireMiddleMans(player, entity, cframe, clock) then
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

local TotalBytes = {}
local function OnReceive(player: Player, data: buffer)
	if not data then
		return
	end
	TotalBytes[player] = (TotalBytes[player] or 0) + buffer.len(data)
	BytesReceived += buffer.len(data)
	if TotalBytes[player] > MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER then
		warn("Player", player.Name, "exceeded max bytes per frame:", TotalBytes[player])
		return
	end
	debug.profilebegin("Receiver.OnReceive")
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

Config._WaitForLock(function()
	MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER = Config._GetConfig("MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER")
end)
return Receiver
