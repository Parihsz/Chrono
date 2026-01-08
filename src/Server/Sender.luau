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
	--print("Server", lastTicked)
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
	--print("Flushing", id, "to", player.Name, "size", index)
	UnreliableEvent:FireClient(player, id, copy)
end

local function flushClientOwned(player, buffersT: { [number]: { buffer } })
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
				flush(player, index, "O")
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
		flush(player, index, "O")
	end
end

local function flushEntities(player, buffers: BufferHolder, isHalf: boolean?)
	local index = 0
	local BUFFER = BUFFER
	for ticker, bufferT in buffers do
		local sizeOffset = ticker.config.FULL_ROTATION and FULL_BYTES or YAW_BYTES
		index = writeTickerHeader(BUFFER, index, ticker, isHalf)
		local indexToWriteLength = index
		index += 1
		local length = 0
		for _, buf in bufferT do
			if index + sizeOffset > MAX_BUFFER_SIZE then
				buffer.writeu8(BUFFER, indexToWriteLength, length)
				flush(player, index, "X")
				index = writeTickerHeader(BUFFER, 0, ticker, isHalf)
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
		flush(player, index, "X")
	end
end

local function ReadyModelFromRep(entity: Types.Entity, playerSpecific: Player): Model | string?
	local model = entity.model
	local actualModel = entity.actualModel
	local modelString = entity.modelString
	local modelRepType: "NATIVE" | "CUSTOM" | "MIRRORED" = (entity.modelRepMode or "NATIVE") :: any
	--print(modelRepType)
	if modelRepType == "NATIVE" then
		return model
	elseif modelRepType == "MIRRORED" then
		return actualModel
	elseif modelRepType == "CUSTOM" then
		if modelString then
			return modelString
		end
		local ModelReplicator = script.Parent.Parent.Shared._CUSTOM_MODEL_REP
		if playerSpecific then
			local PlayerGui = playerSpecific.PlayerGui
			ModelReplicator = PlayerGui:FindFirstChild("_ChronoClientModels") :: Instance
			if not PlayerGui:FindFirstChild("_ChronoClientModels") then
				ModelReplicator = Instance.new("Folder")
				ModelReplicator.Name = "_ChronoClientModels"
				ModelReplicator.Parent = PlayerGui
			end
		end
		if model then
			local modelClone = model:Clone()
			if not modelClone then
				warn(`Cloned model for {model:GetFullName()} is not Archivable. Failed to replicate model.`)
				modelClone = Instance.new("Model")
				local part = Instance.new("Part")
				part.Size = Vector3.new(1, 1, 1);(modelClone :: any).PrimaryPart = part
			end
			modelClone.Parent = ModelReplicator
			task.delay(5, function()
				modelClone:Destroy()
			end)
			return modelClone
		end
	else
		warn(`{modelString} is not a valid model string for entity {entity.id}`)
	end
	return nil
end

--//honestly tables should beeeee fine for nowww, could buffer it later if reallllly needed
local function GetEntityFullData(player: Player, entity: Types.Entity): Types.EntityReceivePacket?
	if entity.destroyed then
		return nil
	end
	local modelData = ReadyModelFromRep(entity, player)

	local configName: string? = entity.entityConfig.NAME
	if configName == "DEFAULT" then
		configName = nil
	end

	return { 
		id = entity.id,
		_plrCharacter = entity._plrCharacter,
		networkOwner = entity.networkOwner,
		cframe = entity.latestCFrame or CFrame.new(),
		time = entity.latestTime or 0,
		config = configName,

		model = modelData,
		paused = entity.paused,
		isHalfTicked = entity.isHalfTicked,
		_data = entity._data,
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
	local normal = holder.NORMAL
	local half = holder.HALF

	local toSendFull = {}
	local toRemove = {}
	local clientOwned = {}
	local entityChanges = {}

	local normalBuffers: BufferHolder = {}
	local halfBuffers: BufferHolder = {}
	local frameTimeNow = time()

	local function handleClientEntities(entity: Types.Entity)
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
		warn("Adding client owned entity", entity.id, "to replicate buffer")
		table.insert(clientOwned[latestTime], entity.cframeBuffer :: buffer)
	end

	local function handle(entity: Types.Entity, isNormal: boolean)
		if entity.destroyed  then
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
			handleClientEntities(entity)
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

	for _, entity in normal do
		handle(entity, true)
	end
	for _, entity in half do
		handle(entity, false)
	end
	
	for entity, _ in replicatedOLD do
		replicated[entity] = nil
		table.insert(toRemove, entity._lastId or entity.id)
	end

	flushClientOwned(player, clientOwned)
	flushEntities(player, normalBuffers)
	flushEntities(player, halfBuffers, true)
	if #toRemove > 0 or #toSendFull > 0 or #entityChanges > 0 then
		print(
			"Sending reliable packet to",
			player.Name,
			"toSendFull:",
			#toSendFull,
			"toRemove:",
			#toRemove,
			"entityChanges:",
			#entityChanges
		)
		ReliableEvent:FireClient(player, toSendFull, toRemove, entityChanges)
	end
end

return {
	ReplicatePlayer = ReplicatePlayer,
}
