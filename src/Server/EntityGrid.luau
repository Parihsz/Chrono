--!native
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicationRules = require(script.Parent.Parent.Shared.ReplicationRules)
local Stats = require(script.Parent.Parent.Shared.Stats)
--[[
	We just need to track entities with players near them

	Track how far an entity is from a player
	Fast query to get entities near a player
	Far away entities could be checked less frequently

	Ideas:
	   1. give each player their own hashgird that stores other npcs
	      - expensive so no
	   2. idk-

	cause when we do like um
	for i,entity in queryEntitiesNear(location,100) -- this range is constant
	
	but for far away entities we have to query again

	maybe have two grids, one for close and one for far? 
	actually maybe just do
   player:{
		closeEntities = {},
		farEntities = {},
   }
	changed to 
	player:{
		normalEntities = {},
		halfTick = {},
		lowTick = {},
   }
]]
for id, entity in { "ALL_ENTITIES" } do
	--[[
	--we could now give entities a proxy of how far they are for removal 
	--we could do 
		EntityConfig: {
			Normal: 100,
			HalfTick: 200,
			LowTick: 300,
			--don't need a removal one since we can just not replicate it
		}
	--loop thru players and get range
	--insert into the players close and far table


	-- Changed it so the ticker system keeps track of it now 
	]]
end
--[[
	-- the old has grid had a system where it was 
	local UPDATE_INTERVAL = 2
	so there really wasn't a point to query again until it updated
	but ig we still need to check for when an npc was removed from proxy
	could create another table to store removed entities

]]

local Shared = script.Parent.Parent.Shared
local Types = require(Shared.Types)
local Holder = require(Shared.Holder)
local Ticker = require(Shared.Ticker)
local Entity = require(Shared.Entity)

local SetTickMode = Entity._SetTickMode

type Entity = Types.Entity

local UPDATE_INTERVAL = 0.1
local MAX_TIME_PER_UPDATE = 0.0005

local lastUpdate = 0

local FULL_TICKED = 0
local HALF_TICKED = 0
local UN_TICKED = 0

type PlayerEntityHolder = {
	PLAYER: Player,
	HALF: { Entity },
	NORMAL: { Entity },
	_TEMP_HALF: { Entity },
	_TEMP_NORMAL: { Entity },
	REPLICATED: { [Entity]: true },
}

local entities = Holder.idMap
local playerTablePositionPair: { [PlayerEntityHolder]: vector } = {}
local playerToHolder: { [Player]: PlayerEntityHolder } = {}

local function Check(entity: Entity)
	local part = Entity.GetPrimaryPart(entity)
	local cframe = part and part.CFrame or entity.latestCFrame
	if not cframe or entity.destroyed then
		return
	end
	if entity.id < 1 then
		warn(entity, " has invalid id, cannot check for proximity")
		return
	end
	local position: vector = cframe.Position :: any
	local entityConfig = entity.entityConfig
	local hasNormalTickers = false
	local hasHalfTickers = false
	local halfTickDistance = entityConfig.HALF_TICK_DISTANCE or math.huge
	local normalTickDistance = entityConfig.NORMAL_TICK_DISTANCE or math.huge
	local networkOwner = entity.networkOwner
	local ownedHolder = networkOwner and playerToHolder[networkOwner]

	local isNotNative = entity.modelReplicationMode ~= "NATIVE"
	for holder, playerPos in playerTablePositionPair do
		local viewer = holder.PLAYER
		local allowed = ReplicationRules.Allows(entity, viewer)
		if not allowed then
			continue
		end

		local distance = vector.magnitude(position - playerPos)

		if distance > halfTickDistance and isNotNative then
			if holder == ownedHolder then
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

	local configTicker = entityConfig.TICKER
	if not configTicker then
		return
	end

	local currentTicker = entity._ticker
	if hasHalfTickers and not hasNormalTickers then
		if entity.isHalfTicked == false then
			--warn("Entity is now half ticked", entity.id)
		end
		SetTickMode(entity, true)
		HALF_TICKED += 1
	elseif hasNormalTickers then
		if entity.isHalfTicked then
			--warn("Entity is normal ticked", entity.id)
		end
		SetTickMode(entity, false)
		FULL_TICKED += 1
	else
		UN_TICKED += 1
	end
	if (hasNormalTickers or hasHalfTickers) and entity._ticker ~= configTicker then
		Ticker.move(entity, configTicker)
		--warn("Adding entity to ticker", entity.id)
	elseif not (hasNormalTickers or hasHalfTickers) and currentTicker then
		SetTickMode(entity, nil)
		--warn("Removing entity from ticker", entity.id,currentTicker)
		Ticker.Remove(currentTicker, entity)
	end
end

local yielded: thread? = nil
local totalTime = 0
local function DoLoop()
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
	for _, entity in entities do
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
		local tempNormal = holder._TEMP_NORMAL
		local tempHalf = holder._TEMP_HALF
		table.clear(holder.HALF)
		table.clear(holder.NORMAL)
		for _, entity in tempNormal do
			table.insert(holder.NORMAL, entity)
		end
		for _, entity in tempHalf do
			table.insert(holder.HALF, entity)
		end
	end
end

-- this might be able to be optimized more later
local function Update()
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

local function UpdatePlayerPosition(player: Player, position: vector)
	local holder = playerToHolder[player]
	if not holder then
		return
	end
	playerTablePositionPair[holder] = position
end

local function GetEntityHolder(Player: Player): PlayerEntityHolder?
	return playerToHolder[Player]
end

local function PlayerAdded(player: Player)
	if playerToHolder[player] then
		return
	end
	local t = {
		PLAYER = player,
		HALF = {},
		NORMAL = {},
		REPLICATED = {},
		_TEMP_HALF = {},
		_TEMP_NORMAL = {},
	}
	playerToHolder[player] = t
	playerTablePositionPair[t] = vector.zero
end
if RunService:IsServer() then
	Shared.Remotes.ClientLoaded.OnServerEvent:Connect(PlayerAdded)

	Players.PlayerRemoving:Connect(function(player: Player)
		local holder = playerToHolder[player]
		if not holder then
			return
		end
		playerTablePositionPair[holder] = nil
		playerToHolder[player] = nil
	end)
end
-- Players.PlayerAdded:Connect(PlayerAdded)

return {
	Update = Update,
	UpdatePlayerPosition = UpdatePlayerPosition,
	GetEntityHolder = GetEntityHolder,
}
