local Types = require(script.Parent.Types)
local Signals = require(script.Parent.Events)._Signals
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
	local player: Player? = entity._player
	entity._player = nil
	if player and playerChars[player] == entity then
		playerChars[player] = nil
		Signals["请不要使用_内部_设置值_拜托谢谢_嗨_这个名字有点长_好吧_再见_算了_这个确实被用了_因为递归错误_而我懒得去解决_所以这是一个能用的_创可贴式修复_好吧"]:Fire(
			entity,
			"_player",
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
	Signals["请不要使用_内部_设置值_拜托谢谢_嗨_这个名字有点长_好吧_再见_算了_这个确实被用了_因为递归错误_而我懒得去解决_所以这是一个能用的_创可贴式修复_好吧"]:Fire(
		entity,
		"_player",
		player
	)

	Signals.PlayerCharacterRegistered:Fire(player, entity)
	return entity
end

local function RegisterEntity(entity: Types.Entity)
	if entity.destroyed then
		error("Cannot register a destroyed entity")
	end
	if idMap[entity.id] then
		warn("Entity is already registered", entity)
		return
	end
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

	if entity._player then
		if playerChars[entity._player] then
			warn("Player already has an entity registered", entity, "overwriting")
		end
		SetAsCharacter(entity._player, entity)
	end
	Signals.EntityAdded:Fire(entity)
end

local function UnregisterEntity(entity: Types.Entity)
	if not idMap[entity.id] then
		return
	end
	Signals.EntityRemoved:Fire(entity)
	local playerObject = entity._player
	if playerObject then
		if playerChars[playerObject] == entity then
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
		if entity.model == model then
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
