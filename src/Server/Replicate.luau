--!native
const Players = game:GetService("Players")

const RunService = game:GetService("RunService")

const Shared = script.Parent.Parent.Shared

const ApplyMounts = require(Shared.ApplyMounts)
const Warn = require(Shared.Warn)
const Bin = require(Shared.Bin)
const Holder = require(Shared.Holder)
const Events = require(Shared.Events)
const Ticker = require(Shared.Ticker)
const Config = require(Shared.Config)
const Types = require(Shared.Types)
const Entity = require(Shared.Entity)
const EntityGrid = require(script.Parent.EntityGrid)
const _Player = require(script.Parent.Player)
const Sender = require(script.Parent.Sender)
const _Receiver = require(script.Parent.Receiver)
const Stats = require(Shared.Stats).SERVER

const HeartbeatRemote = Shared.Remotes.Heartbeat
const ClientClockRelayRemote = Shared.Remotes.ClientClockRelay

const HEARTBEAT_RATE = 1 / 10
local lastHeartbeat = 0

const CLIENT_CLOCK_SYNC_RATE = 60
local lastClientClockRelay = 0

const tickers: { Types.Ticker } = {}

Config._WaitForLock(function()
	for _, entityConfig in Config._EntityConfigs do
		if entityConfig.TICKER then
			table.insert(tickers, entityConfig.TICKER)
		else
			Warn.high(entityConfig, "TICKERS not found on server config load")
		end
	end
end)

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

const FULL_BYTES = 4 * 3 + 2 * 3 + 2
const YAW_BYTES = 4 * 3 + 2 + 2

const TAU = math.pi * 2

const function MapRotation(x: number): number
	return math.round((x + math.pi) / (TAU / 65535))
end

const function SerializeFull(b: buffer, cf: CFrame, index: number)
	const x, y, z = cf.X, cf.Y, cf.Z
	const rx, ry, rz = cf:ToOrientation()
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

const function SerializeYaw(b: buffer, cf: CFrame, index: number)
	const x, y, z = cf.X, cf.Y, cf.Z
	const _, ry, _ = cf:ToOrientation()
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

const function CFrameChanged(cframe1: CFrame?, cframe2: CFrame?): boolean
	if cframe1 == cframe2 then
		return false
	end
	if cframe1 == nil or cframe2 == nil then
		return true
	end
	return cframe1:FuzzyEq(cframe2, 0.0001) == false
end

const function PushLatest(entity: Types.Entity, time: number)
	if entity.autoUpdatePosition and entity.isContextOwner and entity.model then
		const primaryPart = Entity.GetPrimaryPart(entity)
		if not primaryPart then
			Warn.low("Entity", entity, "has no primary part")
			return
		end
		const cframe = primaryPart.CFrame
		Entity.Push(entity, time, cframe)
	end
end

const function CheckForChanges(entity: Types.Entity): CFrame?
	const lastCFrame = entity.lastCheckedCFrame
	const currentCFrame = entity.latestCFrame

	if CFrameChanged(lastCFrame, currentCFrame) then
		entity.lastCheckedCFrame = currentCFrame
		return currentCFrame
	end
	return nil
end

const function CheckEntity(entity: Types.Entity, ticker: Types.Ticker, useFull: boolean, isHalfTick: boolean)
	if entity.destroyed then
		Ticker.Remove(ticker, entity)
		return
	end

	if not entity.isContextOwner then
		return
	end

	const entityIsHalf = entity.isHalfTicked
	if (entityIsHalf and not isHalfTick) or entity.paused then
		entity.cframeBuffer = nil
		return
	end
	if entityIsHalf then
		FireEvent(entity, "Ticked", ticker.halfdt)
	else
		FireEvent(entity, "Ticked", ticker.dt)
	end

	PushLatest(entity, ticker.lastTicked)
	const changes = CheckForChanges(entity)

	if changes then
		if entity.id == 0 then
			error("Entity Should not have and id of 0")
		end
		if useFull then
			const b = buffer.create(FULL_BYTES)
			buffer.writeu16(b, 0, entity.id)
			SerializeFull(b, changes, 2)
			entity.cframeBuffer = b
		else
			const b = buffer.create(YAW_BYTES)
			buffer.writeu16(b, 0, entity.id)
			SerializeYaw(b, changes, 2)
			entity.cframeBuffer = b
		end
	else
		entity.cframeBuffer = nil
	end
end

const Changes: { Types.Entity } = {}

--In the future we can optimize this so it uses buffers if really needed
const function CheckEntityChanges()
	for entity, changes in Entity._Changes do
		const newChanges = { id = entity.id, data = {} }
		for key, data in changes do
			data = data or entity[key]
			table.insert(newChanges.data, { key, data })
		end
		Entity._Changes[entity] = nil
		entity._changes = newChanges
		table.insert(Changes, entity)
	end
end

local TotalTickerTime = 0
local CountTicker = 0

const function UpdateTickers()
	debug.profilebegin("UpdateTickers")
	const starts = os.clock()
	for _, ticker in tickers do
		if not next(ticker.objects) then
			continue
		end
		debug.profilebegin(`{ticker.config.NAME}`)
		if Ticker.CheckUpdate(ticker) then
			--[[ Using the ticker's config instead can help protect if entity configs change mid-game since that
                could potentially create a desync between the buffer serialization and deserialization
            ]]
			--// thought idk if we want to allow that (better to be safe ig for now)
			const useFull = ticker.config.FULL_ROTATION == true
			const isHalfTick = ticker.tickedHalf
			for _, object in ticker.objects do
				CheckEntity(object, ticker, useFull, isHalfTick)
			end
		end
		debug.profileend()
	end
	debug.profileend()
	const diff = os.clock() - starts
	TotalTickerTime += diff
	CountTicker += 1
	Stats.AVG_TICKER_TIME_MS = (TotalTickerTime / CountTicker) * 1000
	if CountTicker >= 60 then
		TotalTickerTime = 0
		CountTicker = 0
	end
end

const function UpdatePlayerPositions()
	for _, entity: Types.Entity in Holder._playerChars do
		const player = entity.networkOwner
		const primaryPart = Entity.GetPrimaryPart(entity)
		const cframe = primaryPart and primaryPart.CFrame or entity.latestCFrame

		if player and cframe then
			EntityGrid.UpdatePlayerPosition(player, cframe.Position :: any)
		end
	end
end

const function updateEntityStats()
	const hasOwned = Stats._SHOULD_REPLICATE
	if not hasOwned then
		Stats.SERVER_ENTITIES = {}
		return
	end
	const entities: { Types.ServerEntitiesStats } = {}

	for _, entity in Holder.idMap do
		const networkOwner = entity.networkOwner
		const isCharacter = entity._player ~= nil
		const config = entity.entityConfig
		const configName = config and config.NAME or "DEFAULT"
		const configTickRate = 1 / config.TICK_RATE
		const isHalfTicked = entity.isHalfTicked
		local tickRate = configTickRate
		const lastPosition = entity.latestCFrame and entity.latestCFrame.Position or nil
		if isHalfTicked == true then
			tickRate = tickRate / 2
		elseif isHalfTicked == nil then
			tickRate = 0
		end
		tickRate //= 1
		if tickRate ~= tickRate or tickRate == math.huge then
			tickRate = 0
		end
		const lastTicked = entity.latestTime
		const data = {
			isPaused = entity.paused,
			id = entity.id,
			networkOwner = networkOwner,
			isCharacter = isCharacter,
			config = configName,
			tickRate = tickRate,
			lastTicked = lastTicked,
			lastPosition = lastPosition,
			modelType = Entity.GetModelReplicationType(entity),
		}
		table.insert(entities, data)
	end
	Stats.SERVER_ENTITIES = entities
end

const function UpdateHeartbeat()
	const now = os.clock()
	if now - lastHeartbeat >= HEARTBEAT_RATE then
		lastHeartbeat = now
		for _, player in Players:GetPlayers() do
			if not EntityGrid.GetEntityHolder(player) then
				continue
			end
			HeartbeatRemote:FireClient(player, now)
		end
	end
end

const function UpdateClientClockRelay()
	const now = os.clock()
	if now - lastClientClockRelay < CLIENT_CLOCK_SYNC_RATE then
		return
	end
	lastClientClockRelay = now

	const raws = _Receiver._GetClientClockRaws()
	if #raws == 0 then
		return
	end

	ClientClockRelayRemote:FireAllClients(raws)
end

const function Update()
	EntityGrid.Update()
	UpdatePlayerPositions()
	ApplyMounts()
	UpdateTickers()
	CheckEntityChanges()
	UpdateHeartbeat()
	UpdateClientClockRelay()

	for _, player in Players:GetPlayers() do
		Sender.ReplicatePlayer(player)
	end
	for _, entity in Changes do
		entity._changes = nil
	end
	table.clear(Changes)
	updateEntityStats()
	Ticker._IncrementGlobalTick()
end

const function HandleEntity(plr, entity: Types.Entity)
	const add, clear = Bin()

	const function HandleModel(entity: Types.Entity)
		if not entity.model then
			return
		end

		const partToUse = Entity._GetRootPart(entity)

		if not partToUse then
			return
		end

		const function CFrameChanged()
			const cframe = partToUse.CFrame
			if cframe == entity.latestCFrame then
				return
			end

			Entity.SetCFrame(entity, cframe)
		end

		add(partToUse:GetPropertyChangedSignal("CFrame"):Connect(CFrameChanged))
	end
	const add2, clear2 = Bin()
	add2(Entity.GetEvent(entity, "ModelChanged"):Connect(function()
		clear()
		HandleModel(entity)
	end))
	add2(Entity.GetEvent(entity, "LockChanged"):Connect(function()
		clear()
		HandleModel(entity)
	end))
	local destroyEvent
	const event = Entity.GetEvent(entity, "NetworkOwnerChanged"):Once(function()
		clear()
		clear2()
		destroyEvent:Disconnect()
	end)

	destroyEvent = Entity.GetEvent(entity, "Destroying"):Once(function()
		clear()
		clear2()
		event:Disconnect()
	end)

	HandleModel(entity)
end

const function HandleCFrameSetters()
	const mode: "NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS" = Config._GetConfig("REPLICATE_CFRAME_SETTERS")
	if mode == "NONE" then
		return
	end
	if mode == "PLAYER_ENTITIES" then
		Events.PlayerOwnedAdded:Connect(HandleEntity, true)
	else
		Events.PlayerCharacterRegistered:Connect(HandleEntity, true)
	end

	for _, entity in Holder.idMap do
		if mode == "PLAYER_ENTITIES" and entity.networkOwner then
			HandleEntity(entity.networkOwner, entity)
		elseif mode == "PLAYER_CHARACTERS" and entity._player then
			HandleEntity(entity._player, entity)
		end
	end
end

const function PlayerAdded(plr: Player)
	const raws = _Receiver._GetClientClockRaws()
	ClientClockRelayRemote:FireAllClients(raws)
end

Config._WaitForLock(function()
	if not RunService:IsServer() then
		return
	end
	HandleCFrameSetters()
	Events._Signals.PlayerLoaded.Event:Connect(PlayerAdded)
	RunService.PostSimulation:Connect(Update)
end)

return nil
