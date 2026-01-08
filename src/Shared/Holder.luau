local Types = require(script.Parent.Types)
local Signals = require(script.Parent.Events)._Signals
local Config = require(script.Parent.Config)
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

local function RemovePlayerCharacter(entity: Types.Entity)
	local player: Player? = entity._plrCharacter
	entity._plrCharacter = nil
	if player and playerChars[player] == entity then
		playerChars[player] = nil
		Signals._DO_NOT_USE_INTERNAL_SET_VALUE_PLEASE_THANKS_HI_THIS_IS_A_BIT_LONG_YEAH_OKAY_BYE_NVM_THIS_IS_USED_CAUSE_RECURSIVE_ERROR_AND_I_AM_TO_LAZY_TO_SOLVE_THAT_SO_THIS_IS_A_BAND_AID_FIX_THAT_WORKS_OKAY:Fire(
			entity,
			"_plrCharacter",
			nil
		)
		Signals.PlayerCharacterUnregistered:Fire(player, entity)
	end
end

local function SetAsCharacter(player: Player, entity: Types.Entity): Types.Entity
	if not idMap[entity.id] or entity.id < 1 then
		error("Entity must be registered before being set as a player character")
	end
	local old: Types.Entity? = playerChars[player]
	if old then
		RemovePlayerCharacter(old)
	end
	playerChars[player] = entity
	Signals._DO_NOT_USE_INTERNAL_SET_VALUE_PLEASE_THANKS_HI_THIS_IS_A_BIT_LONG_YEAH_OKAY_BYE_NVM_THIS_IS_USED_CAUSE_RECURSIVE_ERROR_AND_I_AM_TO_LAZY_TO_SOLVE_THAT_SO_THIS_IS_A_BAND_AID_FIX_THAT_WORKS_OKAY:Fire(
		entity,
		"_plrCharacter",
		player
	)



	Signals.PlayerCharacterRegistered:Fire(player, entity)
	return entity
end

local function RegisterEntity(entity: Types.Entity)
	if IS_SERVER then
		local id = GetNextId()
		if idMap[id] then
			error(`Entity Collision {id}`)
		end
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

	if entity._plrCharacter then
		if playerChars[entity._plrCharacter] then
			warn("Player already has an entity registered", entity, "overwriting")
		end
		SetAsCharacter(entity._plrCharacter, entity)
	end
	Signals.EntityAdded:Fire(entity)
end

local function UnregisterEntity(entity: Types.Entity)
	if not idMap[entity.id] then
		return
	end
	Signals.EntityRemoved:Fire(entity)
	local plrCharacter = entity._plrCharacter
	if plrCharacter then
		if playerChars[plrCharacter] == entity then
			RemovePlayerCharacter(entity)
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

--Warning: O(n) operation
local function GetEntityFromModel(model: Model): Types.Entity?
	for _, entity in idMap do
		if entity.model == model or entity.actualModel == model then
			return entity
		end
	end
	return nil
end

local function GetEntityFromPlayer(player: Player): Types.Entity?
	local plrCharacter = playerChars[player]
	return plrCharacter
end

local function GetEntityFromId(id: number): Types.Entity?
	return idMap[id]
end

local function getEntityStorageInstance(): Camera
	if workspace:FindFirstChild("Chrono_EntityStorage") then
		return workspace:FindFirstChild("Chrono_EntityStorage") :: Camera
	else
		local folder = Instance.new("Camera")
		folder.Name = "Chrono_EntityStorage"
		folder.Parent = workspace
		return folder
	end
end

return {
	idMap = idMap,
	_clientOwned = clientOwned,
	_playerChars = playerChars,
	RegisterEntity = RegisterEntity,
	UnregisterEntity = UnregisterEntity,
	GetEntityStorageInstance = getEntityStorageInstance,
	SetAsCharacter = SetAsCharacter,
	RemovePlayerCharacter = RemovePlayerCharacter,
	GetEntityFromPlayer = GetEntityFromPlayer,
	GetEntityFromId = GetEntityFromId,
	GetEntityFromModel = GetEntityFromModel,
}
