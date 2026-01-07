--!native
local Players = game:GetService("Players")
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

type Entity = Types.Entity

local UPDATE_INTERVAL = 1

local lastUpdate = 0

type PlayerEntityHolder = {
	PLAYER: Player,
	HALF: { Entity },
	NORMAL: { Entity },
	REPLICATED: { [Entity]: true },
}

local entities = Holder.idMap
local playerTablePositionPair: { [PlayerEntityHolder]: vector } = {}
local playerToHolder: { [Player]: PlayerEntityHolder } = {}

local function Check(entity: Entity)
	local cframe = entity.model and entity.model.PrimaryPart and entity.model.PrimaryPart.CFrame or entity.latestCFrame
	if not cframe then
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
	local halfTickDist = entityConfig.HALF_TICK_DISTANCE or math.huge
	local normalTickDist = entityConfig.NORMAL_TICK_DISTANCE or math.huge
	local networkOwner = entity.networkOwner
	local ownedHolder = networkOwner and playerToHolder[networkOwner]
	for holder, playerPos in playerTablePositionPair do
		local dist = vector.magnitude(position - playerPos)

		if dist > halfTickDist then
			if holder == ownedHolder then
				table.insert(holder.NORMAL, entity)
			end
			continue
		end

		if dist <= normalTickDist then
			hasNormalTickers = true
			table.insert(holder.NORMAL, entity)
		else
			hasHalfTickers = true
			table.insert(holder.HALF, entity)
		end
	end
	local configTicker = entityConfig.TICKER
	if not configTicker then
		return
	end
	local currentTicker = entity._ticker
	if hasHalfTickers then
		if entity.isHalfTicked ~= false then
			warn("Entity is now half ticked", entity)
		end
		entity.isHalfTicked = true
	else
		if entity.isHalfTicked then
			warn("Entity is normal ticked", entity)
		end
		entity.isHalfTicked = false
	end
	if (hasNormalTickers or hasHalfTickers) and entity._ticker ~= configTicker then
		Ticker.move(entity, configTicker)
		warn("Adding entity to ticker", entity)
	elseif not (hasNormalTickers or hasHalfTickers) and currentTicker then
		warn("Removing entity from ticker", entity)
		Ticker.remove(currentTicker, entity)
		entity.isHalfTicked = nil
	end
end

-- this might be able to be optimized more later
local function Update()
	if os.clock() - lastUpdate < UPDATE_INTERVAL then
		return
	end
	lastUpdate = os.clock()
	for holder, pos in playerTablePositionPair do
		table.clear(holder.HALF)
		table.clear(holder.NORMAL)
	end
	debug.profilebegin("EntityGrid.Update")
	for id, entity in entities do
		Check(entity)
	end
	debug.profileend()
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
	}
	playerToHolder[player] = t
	playerTablePositionPair[t] = vector.zero
end

-- Players.PlayerAdded:Connect(PlayerAdded)
Shared.Remotes.ClientLoaded.OnServerEvent:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player: Player)
	local holder = playerToHolder[player]
	playerTablePositionPair[holder] = nil
	playerToHolder[player] = nil
end)

return {
	Update = Update,
	UpdatePlayerPosition = UpdatePlayerPosition,
	GetEntityHolder = GetEntityHolder,
}
