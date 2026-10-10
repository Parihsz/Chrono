--!native
const Players = game:GetService("Players")

const RunService = game:GetService("RunService")

const Events = require(script.Parent.Parent.Shared.Events)
const Config = require(script.Parent.Parent.Shared.Config)
const ReplicationRules = require(script.Parent.Parent.Shared.ReplicationRules)
const RuleAllows = ReplicationRules.Allows
const Stats = require(script.Parent.Parent.Shared.Stats)
const Warn = require(script.Parent.Parent.Shared.Warn)

const Shared = script.Parent.Parent.Shared
const Types = require(Shared.Types)
const Holder = require(Shared.Holder)
const Ticker = require(Shared.Ticker)
const Entity = require(Shared.Entity)
const Signal = require(Shared.Signal)

const SetTickMode = Entity._SetTickMode

type Entity = Types.Entity

local UPDATE_INTERVAL = 0.1
local MAX_TIME_PER_UPDATE = 0.0005

local lastUpdate = 0

Config._WaitForLock(function()
	UPDATE_INTERVAL = Config._GetConfig("GRID_UPDATE_INTERVAL") or UPDATE_INTERVAL
	MAX_TIME_PER_UPDATE = Config._GetConfig("GRID_MAX_UPDATE_TIME") or MAX_TIME_PER_UPDATE
end)

local FULL_TICKED = 0
local HALF_TICKED = 0
local UN_TICKED = 0

type PlayerEntityHolder = Types.PlayerEntityHolder

const entities = Holder.idMap
const playerTablePositionPair: { [PlayerEntityHolder]: vector } = {}
const playerToHolder: { [Player]: PlayerEntityHolder } = {}

const function Check(entity: Entity)
	const part = Entity.GetPrimaryPart(entity)
	const cframe = part and part.CFrame or entity.latestCFrame
	if not cframe or entity.destroyed then
		return
	end
	if entity.id < 1 then
		Warn.high(entity, " has invalid id, cannot check for proximity")
		return
	end
	const position: vector = cframe.Position :: any
	const entityConfig = entity.entityConfig
	local hasNormalTickers = false
	local hasHalfTickers = false
	const halfTickDistance = entityConfig.HALF_TICK_DISTANCE or math.huge
	const normalTickDistance = entityConfig.NORMAL_TICK_DISTANCE or math.huge
	const networkOwner = entity.networkOwner
	const ownedHolder = networkOwner and playerToHolder[networkOwner]

	const isLocked = entity._lockedCFReplication
	const isNotNative = isLocked or entity.modelReplicationMode ~= "NATIVE"
	for holder, playerPos in playerTablePositionPair do
		const viewer = holder.PLAYER
		const allowed = RuleAllows(entity, viewer)
		if not allowed then
			continue
		end

		const distance = vector.magnitude(position - playerPos)

		-- if entity is native then we keep it half ticked else remove it
		if distance > halfTickDistance and isNotNative then
			if holder == ownedHolder then -- always replicate to the owner
				table.insert(holder._TEMP_NORMAL, entity)
			end
			continue
		end

		if distance <= normalTickDistance then
			hasNormalTickers = true
			table.insert(holder._TEMP_NORMAL, entity)
		else
			hasHalfTickers = true
			table.insert(holder._TEMP_HALF, entity)
		end
	end

	const configTicker = entityConfig.TICKER
	if not configTicker then
		return
	end

	const currentTicker = entity._ticker
	if hasHalfTickers and not hasNormalTickers then
		SetTickMode(entity, true)
		HALF_TICKED += 1
	elseif hasNormalTickers then
		SetTickMode(entity, false)
		FULL_TICKED += 1
	else
		UN_TICKED += 1
	end
	if (hasNormalTickers or hasHalfTickers) and entity._ticker ~= configTicker then
		Ticker.move(entity, configTicker)
	elseif not (hasNormalTickers or hasHalfTickers) and currentTicker then
		SetTickMode(entity, nil)
		Ticker.Remove(currentTicker, entity)
	end
end

local yielded: thread? = nil
local totalTime = 0
const function DoLoop()
	totalTime = 0
	FULL_TICKED = 0
	HALF_TICKED = 0
	UN_TICKED = 0
	for holder, _ in playerTablePositionPair do
		table.clear(holder._TEMP_HALF)
		table.clear(holder._TEMP_NORMAL)
	end
	debug.profilebegin("EntityGrid.Update")
	local count = 0
	local start = os.clock()
	local sections = 1
	-- clone as the table could be mutated
	for _, entity in table.clone(entities) do
		debug.profilebegin(`Check One`)
		Check(entity)
		count += 1
		debug.profileend()
		if os.clock() - start > MAX_TIME_PER_UPDATE then
			sections += 1
			debug.profileend()
			totalTime += os.clock() - start
			yielded = coroutine.running()
			coroutine.yield()
			yielded = nil
			start = os.clock()
			debug.profilebegin("EntityGrid.ResumeUpdate")
		end
	end
	debug.profileend()
	totalTime += os.clock() - start
	Stats.SERVER.GRID_UPDATE_SECTIONS = sections
	Stats.SERVER.ENTITY_GRID_UPDATE_TIME_MS = totalTime * 1000
	Stats.SERVER.NUMBER_OF_ENTITIES = count
	Stats.SERVER.ENTITIES_FULL_TICKED = FULL_TICKED
	Stats.SERVER.ENTITIES_HALF_TICKED = HALF_TICKED
	Stats.SERVER.NON_TICKED = UN_TICKED

	for _, holder in playerToHolder do
		table.clear(holder.HALF)
		table.clear(holder.NORMAL)
		for _, entity in holder._TEMP_NORMAL do
			table.insert(holder.NORMAL, entity)
		end
		for _, entity in holder._TEMP_HALF do
			table.insert(holder.HALF, entity)
		end
	end

	if Stats.SERVER._SHOULD_REPLICATE then
		const gridStats = {}
		for _, holder in playerToHolder do
			const entry = { HALF = {}, NORMAL = {} }
			for _, entity in holder.NORMAL do
				table.insert(entry.NORMAL, entity.id)
			end
			for _, entity in holder.HALF do
				table.insert(entry.HALF, entity.id)
			end
			gridStats[holder.PLAYER.Name] = entry
		end
		Stats.SERVER.GRID_STATS = gridStats
	end
end

-- this might be able to be optimized more later
const function Update()
	if yielded then
		task.spawn(yielded)
		return
	end
	if os.clock() - lastUpdate < UPDATE_INTERVAL then
		return
	end
	lastUpdate = os.clock()
	task.spawn(DoLoop)
end

const function UpdatePlayerPosition(player: Player, position: vector)
	const holder = playerToHolder[player]
	if not holder then
		return
	end
	playerTablePositionPair[holder] = position
end

const function GetEntityHolder(Player: Player): PlayerEntityHolder?
	return playerToHolder[Player]
end

const function PlayerAdded(player: Player)
	if playerToHolder[player] then
		return
	end
	const t = {
		PLAYER = player,
		HALF = {},
		NORMAL = {},
		REPLICATED = {},
		_TEMP_HALF = {},
		_TEMP_NORMAL = {},
		EntityAdded = Signal.new(),
		EntityRemoving = Signal.new(),
	}
	playerToHolder[player] = t
	playerTablePositionPair[t] = vector.zero

	Events._Signals.PlayerLoaded:Fire(player)
end
if RunService:IsServer() then
	Shared.Remotes.ClientLoaded.OnServerEvent:Connect(PlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		const holder = playerToHolder[player]
		if not holder then
			return
		end
		holder.EntityAdded:DisconnectAll()
		holder.EntityRemoving:DisconnectAll()
		playerTablePositionPair[holder] = nil
		playerToHolder[player] = nil
	end)
end

return {
	Update = Update,
	UpdatePlayerPosition = UpdatePlayerPosition,
	GetEntityHolder = GetEntityHolder,
}
