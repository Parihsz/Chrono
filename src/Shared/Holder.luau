local Types = require(script.Parent.Types)
local IS_SERVER = game:GetService("RunService"):IsServer()

local currentId = 0 -- First Id will start at 1
local idStack = {}
local playerChars = {}
local idMap: { [number]: Types.Entity } = {}
local clientOwned: { [Player]: { [Types.Entity]: true } } = {}

local MAX_ID = 2 ^ 16 - 1

local function GetNextId(): number
	local reusedId = table.remove(idStack)
	if reusedId then
		return reusedId
	else
		if currentId >= MAX_ID then
			error("Max ID reached, please investigate.")
		end
		currentId += 1
		return currentId
	end
end

local RandomOffset = Random.new()
local function ReleaseId(id: number)
	-- Delay the reuse of the id to avoid immediate collisions
	task.delay(RandomOffset:NextNumber(5, 10), table.insert, idStack, id)
end

local function RegisterEntity(entity: Types.Entity)
	if entity.plrCharacter then
		if playerChars[entity.plrCharacter] then
			warn("Player already has an entity registered", entity, "overwriting")
		end
		playerChars[entity.plrCharacter] = entity
	end
	if IS_SERVER then
		local id = GetNextId()
		entity.id = id
		idMap[id] = entity
	else
		local id = entity.id
		if idMap[id] then
			warn("Entity ID collision detected for ID:", id)
		end
		idMap[id] = entity
	end
	entity.registered = true
end

local function UnregisterEntity(entity: Types.Entity)
	if not idMap[entity.id] then
		return
	end

	local plrCharacter = entity.plrCharacter
	if plrCharacter then
		if playerChars[plrCharacter] == entity then
			playerChars[plrCharacter] = nil
		else
			warn("Entity being unregistered does not match player mapping", entity, "ignoring")
		end
	end
	local id = entity.id
	if IS_SERVER then
		idMap[id] = nil
		ReleaseId(id)
		entity.id = -1
	else
		idMap[id] = nil
	end
	entity._lastId = id
	entity.registered = false
end

local function GetEntityFromPlayer(player: Player): Types.Entity?
	local plrCharacter = playerChars[player]
	return plrCharacter
end

local function GetEntityFromId(id): Types.Entity?
	return idMap[id]
end

return {
	idMap = idMap,
	_clientOwned = clientOwned,
	_playerChars = playerChars,
	_RegisterEntity = RegisterEntity,
	_UnregisterEntity = UnregisterEntity,
	GetEntityFromPlayer = GetEntityFromPlayer,
	GetEntityFromId = GetEntityFromId,
}
