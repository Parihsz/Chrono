local Sender = {}

local EntityGrid = require(script.Parent.EntityGrid)
local Types = require(script.Parent.Parent.Shared.Types)
local Shared = script.Parent.Parent.Shared

local TickerHeaderBytes = 4 + 1
local FULL_BYTES = 4 * 3 + 2 * 3 + 2
local YAW_BYTES = 4 * 3 + 2 + 2
local MAX_BUFFER_SIZE = 900

type BufferHolder = { [Types.Ticker]: { buffer } }
local UnreliableEvent = Shared.Remotes.Replicate
local ReliableEvent = Shared.Remotes.ReplicateFull

local function writeTickerHeader(b: buffer, index: number, ticker: Types.Ticker, isHalf: boolean?): number
	local lastTicked = ticker.lastTicked
	print("Server", lastTicked)
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

local BUFFER = buffer.create(MAX_BUFFER_SIZE + 51)
local function flush(player, index: number, id)
	local copy = buffer.create(index)
	buffer.copy(copy, 0, BUFFER, 0, index)
	print("Flushing", id, "to", player.Name, "size", index)
	UnreliableEvent:FireClient(player, id, copy)
end

local function flushClientOwned(player, buffers: { buffer })
	local index = 0
	for _, buf in buffers do
		local length = buffer.len(buf)
		if index + length > MAX_BUFFER_SIZE then
			flush(player, index, "O")
			index = 0
		end
		buffer.copy(BUFFER, index, buf, 0, length)
		index += length
	end
	if index > 0 then
		flush(player, index, "O")
	end
end

local function flushEntities(player, buffers: BufferHolder, isHalf: boolean?)
	local index = 0
	local BUFFER = BUFFER
	for ticker, bufferT in buffers do
		local sizeOffset = ticker.config.FULL_ROTATION and FULL_BYTES or YAW_BYTES
		index = writeTickerHeader(BUFFER, index, ticker, isHalf)
		for _, buf in bufferT do
			if index + sizeOffset > MAX_BUFFER_SIZE then
				flush(player, index, "X")
				index = writeTickerHeader(BUFFER, 0, ticker, isHalf)
			end
			buffer.copy(BUFFER, index, buf, 0, sizeOffset)
			index += sizeOffset
		end
		buffer.writeu8(BUFFER, index, 0) -- NULL TERMINATOR, ids always start at 1 so this is safe
		index += 1
	end
	if index > 0 then
		flush(player, index, "X")
	end
end

--//honestly tables should beeeee fine for nowww, could buffer it later if reallllly needed
local function GetEntityFullData(player: Player, entity: Types.Entity): Types.EntityReceivePacket?
	if entity.destroyed then
		return nil
	end
	local PlayerGui = player.PlayerGui
	local ModelReplicator = PlayerGui:FindFirstChild("_ChronoModels") :: Instance
	if not PlayerGui:FindFirstChild("_ChronoModels") then
		ModelReplicator = Instance.new("Folder")
		ModelReplicator.Name = "_ChronoModels"
		ModelReplicator.Parent = PlayerGui
	end

	local modelClone
	if entity.model and not entity.modelString then
		modelClone = entity.model:Clone()
		if not modelClone then
			warn(`Cloned model for {entity.model:GetFullName()} is not Archivable. Failed to replicate model.`)
			modelClone = Instance.new("Model")
			local part = Instance.new("Part")
			part.Size = Vector3.new(1, 1, 1);
			(modelClone :: any).PrimaryPart = part
		end
		modelClone.Parent = ModelReplicator
		task.delay(1, function()
			modelClone:Destroy()
		end)
	end

	local configName: string? = entity.entityConfig.NAME
	if configName == "DEFAULT" then
		configName = nil
	end

	return {
		id = entity.id,
		plrCharacter = entity.plrCharacter,
		networkOwner = entity.networkOwner,
		cframe = entity.latestCFrame or CFrame.new(),
		time = entity.latestTime or 0,
		config = configName,
		modelString = entity.modelString,
		model = modelClone,
		paused = entity.paused,
	}
end

local function ReplicatePlayer(player: Player)
	local holder = EntityGrid.GetEntityHolder(player)
	if not holder then
		return
	end
	local replicatedOLD = holder.REPLICATED -- Leftovers will be removed
	local replicated = table.clone(replicatedOLD)
	holder.REPLICATED = replicated
	local all = holder.ALL

	local toSendFull = {}
	local toRemove = {}
	local clientOwned = {}

	local normalBuffers: BufferHolder = {}
	local halfBuffers: BufferHolder = {}
	local frameTimeNow = time()

	local function handleClientEntities(entity: Types.Entity)
		if entity.arriveTime ~= frameTimeNow then -- (time will be the same during the same frame)
			return
		end
		table.insert(clientOwned, entity.cframeBuffer :: buffer)
	end

	local function handle(entity: Types.Entity)
		if entity.destroyed then
			return
		end

		replicated[entity] = true
		if not replicatedOLD[entity] then
			table.insert(toSendFull, GetEntityFullData(player, entity))
			return
		end
		replicatedOLD[entity] = nil
		local isServerOwned = entity.isContextOwner
		if not isServerOwned and not entity.isContextOwner then
			handleClientEntities(entity)
			return
		end
		local ticker = entity._ticker
		if not (ticker and ticker.tickedFrame == frameTimeNow and entity.cframeBuffer) then
			return
		end

		local isHalf = entity.isHalfTicked

		if entity.isHalfTicked and not ticker.tickedHalf then
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

	for _, entity in all do
		handle(entity)
	end

	for entity, _ in replicatedOLD do
		replicated[entity] = nil
		table.insert(toRemove, entity._lastId or entity.id)
	end

	flushClientOwned(player, clientOwned)
	flushEntities(player, normalBuffers)
	flushEntities(player, halfBuffers, true)
	if #toRemove > 0 or #toSendFull > 0 then
		print("Sending full data to", player.Name, #toSendFull, "entities, removing", #toRemove)
		ReliableEvent:FireClient(player, toSendFull, toRemove)
	end
end

return {
	ReplicatePlayer = ReplicatePlayer,
}
