local RunService = game:GetService("RunService")
local EntityGrid = require(script.Parent.EntityGrid)
local Types = require(script.Parent.Parent.Shared.Types)
local Shared = script.Parent.Parent.Shared
local ModelHelper = require(Shared.ModelHelper)
local Stats = require(Shared.Stats).SERVER

local FULL_BYTES = 4 * 3 + 2 * 3 + 2
local YAW_BYTES = 4 * 3 + 2 + 2
local MAX_BUFFER_SIZE = 900

local BytesSentPerSec = 0
local PacketsSentPerSec = 0

local BUFFER = buffer.create(MAX_BUFFER_SIZE + 51)

type BufferHolder = { [Types.Ticker]: { buffer } }
local UnreliableEvent = Shared.Remotes.Replicate
local ReliableEvent = Shared.Remotes.ReplicateFull

local function WriteTickerHeader(b: buffer, index: number, ticker: Types.Ticker, isHalf: boolean?): number
	local lastTicked = ticker.lastTicked
	local sendFull = ticker.config.FULL_ROTATION

	buffer.writef32(b, index, lastTicked)
	index += 4

	local packed = if isHalf then 1 else 0
	if sendFull then
		packed += 2
	end

	buffer.writeu8(b, index, packed)
	index += 1

	return index
end

local function Flush(player, index: number, id)
	local copy = buffer.create(index)
	buffer.copy(copy, 0, BUFFER, 0, index)

	UnreliableEvent:FireClient(player, id, copy)
	BytesSentPerSec += index
	PacketsSentPerSec += 1
end

local function FlushClientOwned(player, buffersT: { [number]: { buffer } })
	local index = 0
	for time, buffers in buffersT do
		buffer.writef32(BUFFER, index, time)
		index += 4
		local indexToWriteLength = index
		index += 1

		local length = 0
		for _, buf in buffers do
			local sizeOffset = buffer.len(buf)

			if index + sizeOffset > MAX_BUFFER_SIZE then
				buffer.writeu8(BUFFER, indexToWriteLength, length)
				Flush(player, index, "O")
				index = 0
				buffer.writef32(BUFFER, index, time)
				index += 4
				indexToWriteLength = index
				index += 1
				length = 0
			end

			buffer.copy(BUFFER, index, buf, 0, sizeOffset)
			length += 1
			index += sizeOffset
		end

		buffer.writeu8(BUFFER, indexToWriteLength, length)
	end

	if index > 0 then
		Flush(player, index, "O")
	end
end

local function FlushEntities(player, buffers: BufferHolder, isHalf: boolean?)
	local index = 0
	local BUFFER = BUFFER
	for ticker, bufferT in buffers do
		local sizeOffset = ticker.config.FULL_ROTATION and FULL_BYTES or YAW_BYTES
		index = WriteTickerHeader(BUFFER, index, ticker, isHalf)
		local indexToWriteLength = index
		index += 1

		local length = 0
		for _, buf in bufferT do
			if index + sizeOffset > MAX_BUFFER_SIZE then
				buffer.writeu8(BUFFER, indexToWriteLength, length)
				Flush(player, index, "X")
				index = WriteTickerHeader(BUFFER, 0, ticker, isHalf)
				indexToWriteLength = index
				index += 1
				length = 0
			end

			length += 1
			buffer.copy(BUFFER, index, buf, 0, sizeOffset)
			index += sizeOffset
		end

		buffer.writeu8(BUFFER, indexToWriteLength, length)
	end

	if index > 0 then
		Flush(player, index, "X")
	end
end

--//honestly tables should beeeee fine for nowww, could buffer it later if reallllly needed
local function GetEntityFullData(player: Player, entity: Types.Entity): Types.EntityReceivePacket?
	if entity.destroyed then
		return nil
	end
	local modelData = ModelHelper.ReadyModelFromRep(entity, player)

	local configName: string? = entity.entityConfig.NAME
	if configName == "DEFAULT" then
		configName = nil
	end

	return {
		id = entity.id,
		_player = entity._player,
		networkOwner = entity.networkOwner,
		cframe = entity.latestCFrame or CFrame.new(),
		time = entity.latestTime or 0,
		config = configName,

		model = modelData,
		paused = entity.paused,
		isHalfTicked = entity.isHalfTicked,
		_data = entity._data,

		mountParentId = entity.mountParentId,
		mountOffset = entity.mountOffset,
		broadPhase = entity.broadPhase :: any,
	}
end

local playerReplicateTotal = 0
local playerReplicateCount = 0
local function ReplicatePlayer(player: Player)
	local holder = EntityGrid.GetEntityHolder(player)
	if not holder then
		return
	end
	debug.profilebegin("ReplicatePlayer")
	local replicatedOLD = holder.REPLICATED -- Leftovers will be removed
	local replicated = table.clone(replicatedOLD)
	holder.REPLICATED = replicated
	local normal = holder.NORMAL
	local half = holder.HALF

	local toSendFull = {}
	local toRemove = {}
	local clientOwned = {}
	local entityChanges = {}

	local normalBuffers: BufferHolder = {}
	local halfBuffers: BufferHolder = {}
	local frameTimeNow = time()

	local function HandleClientEntities(entity: Types.Entity)
		if entity.arriveFrame ~= frameTimeNow then -- (time will be the same during the same frame)
			return
		end
		if entity.networkOwner == player then
			return
		end
		local latestTime = entity.latestTime or 0
		if not clientOwned[latestTime] then
			clientOwned[latestTime] = {}
		end

		table.insert(clientOwned[latestTime], entity.cframeBuffer :: buffer)
	end

	local function Handle(entity: Types.Entity, isNormal: boolean)
		if entity.destroyed then
			return
		end
		replicated[entity] = true
		if not replicatedOLD[entity] then
			table.insert(toSendFull, GetEntityFullData(player, entity))
			return
		end
		if entity._changes then
			table.insert(entityChanges, entity._changes)
		end
		replicatedOLD[entity] = nil
		if entity.paused then
			return
		end

		local isServerOwned = entity.isContextOwner
		if not isServerOwned then
			HandleClientEntities(entity)
			return
		end

		local ticker = entity._ticker
		if not (ticker and ticker.tickedFrame == frameTimeNow and entity.cframeBuffer) then
			return
		end

		local isHalf = entity.isHalfTicked or not isNormal

		if isHalf and not ticker.tickedHalf then
			return
		end

		local buffers = if isHalf then halfBuffers else normalBuffers
		local bufferTable = buffers[ticker]
		if not bufferTable then
			bufferTable = {}
			buffers[ticker] = bufferTable
		end
		table.insert(bufferTable, entity.cframeBuffer)
	end
	local startTime = os.clock()
	for _, entity in normal do
		Handle(entity, true)
	end
	for _, entity in half do
		Handle(entity, false)
	end

	for entity, _ in replicatedOLD do
		replicated[entity] = nil
		table.insert(toRemove, entity._lastId or entity.id)
	end

	FlushClientOwned(player, clientOwned)
	FlushEntities(player, normalBuffers)
	FlushEntities(player, halfBuffers, true)

	if #toRemove > 0 or #toSendFull > 0 or #entityChanges > 0 then
		-- print(
		-- 	"Sending reliable packet to",
		-- 	player.Name,
		-- 	"toSendFull:",
		-- 	#toSendFull,
		-- 	"toRemove:",
		-- 	#toRemove,
		-- 	"entityChanges:",
		-- 	#entityChanges
		-- )
		ReliableEvent:FireClient(player, toSendFull, toRemove, entityChanges)
	end
	debug.profileend()
	local endTime = os.clock()
	playerReplicateTotal += endTime - startTime
	playerReplicateCount += 1
end

local lastStatTime = os.clock()
RunService.Heartbeat:Connect(function()
	Stats.REPLICATE_PLAYER_TIME_MS = playerReplicateTotal / math.max(playerReplicateCount, 1) * 1000
	if os.clock() - lastStatTime > 1 then
		Stats.BYTES_SENT_PER_SEC = BytesSentPerSec
		Stats.PACKETS_SENT_PER_SEC = PacketsSentPerSec
		BytesSentPerSec = 0
		PacketsSentPerSec = 0
		lastStatTime = os.clock()
		playerReplicateTotal = 0
		playerReplicateCount = 0
	end
end)

return {
	ReplicatePlayer = ReplicatePlayer,
}
