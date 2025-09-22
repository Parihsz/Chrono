local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(script.Parent.Parent.Shared.Config)
local Snapshots = require(script.Parent.Parent.Shared.Snapshots)
local Grid = require(script.Parent.Parent.Shared.Grid)
local Events = require(script.Parent.Parent.Events.Server)
local Networkables = require(script.Parent.Parent.Shared.MakeNetworkable)
local Character = require(script.Parent.Parent.Shared.Character)

local ClientReplicateCFrame = Instance.new("UnreliableRemoteEvent")
ClientReplicateCFrame.Name = "ClientReplicateCFrame"
ClientReplicateCFrame.Parent = ReplicatedStorage

local CUSTOM_CHARACTERS = Config.ENABLE_CUSTOM_CHARACTERS
local MAX_UNRELIABLE_BYTES = 900
local SNAPSHOT_SIZE = if Config.SEND_FULL_ROTATION then 22 + 2 else 18 + 2 -- assume worst cast for id (uInt)
local HEADER_SIZE = 2
local MAX_BATCH = (MAX_UNRELIABLE_BYTES - HEADER_SIZE) // SNAPSHOT_SIZE

local ServerReplicateCFrame = Instance.new("UnreliableRemoteEvent")
ServerReplicateCFrame.Name = "ServerReplicateCFrame"
ServerReplicateCFrame.Parent = ReplicatedStorage

local new_Players = {}
local idStack = {} :: { number }
local playerIdMap = {} :: { [Player]: number }

export type ReplicationRule = {
	filterType: "include" | "exclude",
	filterPlayers: { Player },
}

local idMap = {} :: {
	[number]: {
		player: Player?,
		snapshot: Snapshots.Snapshot<CFrame>,
		clientLastTick: number?,

		serverOwned: boolean?,
		npcType: string?,
		model: Model?,

		_characterAdded: RBXScriptConnection?,
		_characterRemoving: RBXScriptConnection?,
		replicationRule: ReplicationRule?,
	},
}
local pausedPlayers = {} :: { [number]: boolean }

local lastReplicatedTimes = {} :: { [number]: number }
local playerTickRates = {} :: { [number]: number }
local replicators = {} :: { [number]: Model }

local MAX_ID = 2 ^ 16 - 1
local IncrementalFactoryUID = 0

local function GetCharacter(player: Player): Model?
	if CUSTOM_CHARACTERS then
		return Character.GetCharacter(player)
	else
		return player.Character
	end
end

local function PackSnapshotData(buff: buffer, offset: number, timestamp: number, cframe: CFrame, id: number)
	buffer.writef32(buff, offset + 0, timestamp)
	buffer.writef32(buff, offset + 4, cframe.Position.X)
	buffer.writef32(buff, offset + 8, cframe.Position.Y)
	buffer.writef32(buff, offset + 12, cframe.Position.Z)

	if Config.SEND_FULL_ROTATION then
		local networkable = Networkables.MakeNetworkable(cframe)

		local mappedX = math.map(networkable.Rotation.x, -1, 1, 0, 2 ^ 16 - 1)
		local mappedY = math.map(networkable.Rotation.y, -1, 1, 0, 2 ^ 16 - 1)
		local mappedZ = math.map(networkable.Rotation.z, -1, 1, 0, 2 ^ 16 - 1)

		buffer.writeu16(buff, offset + 16, mappedX)
		buffer.writeu16(buff, offset + 18, mappedY)
		buffer.writeu16(buff, offset + 20, mappedZ)
		buffer.writeu16(buff, offset + 22, id)
	else
		local networkable = Networkables.MakeYawNetworkable(cframe)
		local mappedRotationY = math.map(networkable.RotationY, -math.pi, math.pi, 0, 2 ^ 16 - 1)
		buffer.writeu16(buff, offset + 16, mappedRotationY)
		buffer.writeu16(buff, offset + 18, id)
	end
end

local function UnpackSnapshotData(buff: buffer, offset: number): { timestamp: number, cframe: CFrame, id: number }
	local value = {}
	value.timestamp = buffer.readf32(buff, offset + 0)

	local x = buffer.readf32(buff, offset + 4)
	local y = buffer.readf32(buff, offset + 8)
	local z = buffer.readf32(buff, offset + 12)

	if Config.SEND_FULL_ROTATION then
		local mappedX = buffer.readu16(buff, offset + 16)
		local mappedY = buffer.readu16(buff, offset + 18)
		local mappedZ = buffer.readu16(buff, offset + 20)

		local rx = math.map(mappedX, 0, 2 ^ 16 - 1, -1, 1)
		local ry = math.map(mappedY, 0, 2 ^ 16 - 1, -1, 1)
		local rz = math.map(mappedZ, 0, 2 ^ 16 - 1, -1, 1)

		value.cframe = Networkables.DecodeCFrame({
			Position = vector.create(x, y, z) :: any,
			Rotation = { x = rx, y = ry, z = rz },
		})
		value.id = buffer.readu16(buff, offset + 22)
	else
		local rotationY = buffer.readu16(buff, offset + 16)
		local remapped = math.map(rotationY, 0, 2 ^ 16 - 1, -math.pi, math.pi)

		value.cframe = Networkables.DecodeYawCFrame({
			Position = vector.create(x, y, z) :: any,
			RotationY = remapped,
		})
		value.id = buffer.readu16(buff, offset + 18)
	end

	return value
end

local function GetNextID(): number
	local reusedID = table.remove(idStack)
	if reusedID then
		return reusedID
	end

	if IncrementalFactoryUID + 1 == MAX_ID then
		error("Max ID reached, please investigate.")
	end
	IncrementalFactoryUID += 1

	return IncrementalFactoryUID
end

local function ReturnID(id: number)
	table.insert(idStack, id)
end

local function GetIdFrom(input: Player | Model | number): number?
	if typeof(input) == "Instance" then
		if input:IsA("Player") then
			return playerIdMap[input]
		elseif input:IsA("Model") then
			return input:GetAttribute("NPC_ID") :: any
		end
	elseif typeof(input) == "number" then
		return input
	end

	return nil
end

local function NewReplicationRule(): ReplicationRule
	return {
		filterType = "exclude",
		filterPlayers = {},
	}
end

local function GetReplicationRule(input: Player | Model | number): ReplicationRule
	local id = GetIdFrom(input)
	if not id then
		return NewReplicationRule()
	end

	local data = idMap[id]
	if not data then
		return NewReplicationRule()
	end

	if not idMap[id].replicationRule then
		idMap[id].replicationRule = NewReplicationRule()
	end

	return idMap[id].replicationRule :: any
end

local function SetReplicationRule(input: Player | Model | number, rule: ReplicationRule)
	local id = GetIdFrom(input)
	if not id then
		warn("ID not found for input", input)
		return
	end

	local data = idMap[id]
	if not data then
		warn("Data not found for ID", id)
		return
	end

	data.replicationRule = rule
end

local function GetNpcConfig(npcType: string?): any
	npcType = npcType or "DEFAULT"
	return Config.NPC_TYPES[npcType :: any] or Config.NPC_TYPES.DEFAULT
end

local function OnCharacterAdded(player: Player, character: Model, id: number)
	if Config.DISABLE_DEFAULT_REPLICATION then
		return
	end
	Grid.AddEntity(character, "player")
end

local function OnCharacterRemoving(character: Model)
	if Config.DISABLE_DEFAULT_REPLICATION then
		return
	end
	Grid.RemoveEntity(character)
end

local function InitExistingPlayers(player: Player)
	local playerData = {}

	for existingPlayer, _ in playerIdMap do
		if existingPlayer == player then
			continue
		end

		table.insert(playerData, {
			id = playerIdMap[existingPlayer],
			player = existingPlayer.Name,
		})
	end

	if #playerData == 0 then
		warn("No existing players found to initialize for player", player)
		return
	end

	Events.InitializeExistingPlayers.Fire(player, playerData)
end

Players.PlayerAdded:Connect(function(player: Player)
	local id = GetNextID()
	playerIdMap[player] = id
	task.delay(1, function()
		table.insert(new_Players, player)
	end)
	idMap[id] = {
		player = player,
		snapshot = Snapshots(CFrame.identity.Lerp),
		clientLastTick = nil,

		serverOwned = false,
		npcType = nil,
		_characterAdded = nil,
		_characterRemoving = nil,
	}

	lastReplicatedTimes[id] = 0

	if Config.DISABLE_DEFAULT_REPLICATION then
		if StarterPlayer:FindFirstChild("Replicator") then
			local clone: Model = StarterPlayer.Replicator:Clone()
			clone.Name = player.Name
			clone.Parent = workspace.CurrentCamera

			replicators[id] = clone

			Grid.AddEntity(clone, "player")
		else
			warn(
				"No Replicator model found in StarterPlayer, you must add one for fully custom replication to work properly"
			)
		end
	end

	InitExistingPlayers(player)

	Events.InitializePlayer.FireAll({
		id = id,
		player = player.Name,
	})

	idMap[id]._characterAdded = player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character, id)
	end)
	idMap[id]._characterRemoving = player.CharacterRemoving:Connect(OnCharacterRemoving)
end)

Character.CharacterRemoved:Connect(function(player: Player, character: Model)
	OnCharacterRemoving(character)
end)

Character.CharacterAdded:Connect(function(player: Player, character: Model)
	if not Config.DISABLE_DEFAULT_REPLICATION then
		Grid.AddEntity(character, "player")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local id = playerIdMap[player]
	if id then
		local _characterAdded = idMap[id]._characterAdded
		if _characterAdded then
			_characterAdded:Disconnect()
		end

		local _characterRemoving = idMap[id]._characterRemoving
		if _characterRemoving then
			_characterRemoving:Disconnect()
		end

		if replicators[id] then
			Grid.RemoveEntity(replicators[id])
			pcall(workspace.Destroy, replicators[id])
			replicators[id] = nil
		end

		idMap[id] = nil
		lastReplicatedTimes[id] = nil
		playerIdMap[player] = nil

		ReturnID(id)
	end
end)

ClientReplicateCFrame.OnServerEvent:Connect(function(player: Player, snapshotBuffer: buffer)
	local id = playerIdMap[player]
	if not id then
		return
	end

	local data = idMap[id]
	if not data or not data.snapshot then
		return
	end

	SNAPSHOT_SIZE = if Config.SEND_FULL_ROTATION then 24 else 20

	local offset = 0
	for i = 1, buffer.len(snapshotBuffer) // SNAPSHOT_SIZE do
		local snapshot = UnpackSnapshotData(snapshotBuffer, offset)
		offset += SNAPSHOT_SIZE

		data.clientLastTick = snapshot.timestamp
		data.snapshot:Push(snapshot.timestamp, snapshot.cframe)
	end

	lastReplicatedTimes[id] = 0
	local character = player.Character
	local hrp = character and character.PrimaryPart :: BasePart?

	if Config.DISABLE_DEFAULT_REPLICATION and hrp then
		hrp.Anchored = true
	end
end)

local function TogglePlayerReplication(player: Player, on: boolean)
	local id = playerIdMap[player]
	if not id then
		warn("TogglePlayerReplication: Player not found in idMap")
		return
	end

	if on then
		pausedPlayers[id] = nil
		Events.TogglePlayerReplication.FireAll({
			id = id,
			on = true,
		})
	else
		pausedPlayers[id] = true
		Events.TogglePlayerReplication.FireAll({
			id = id,
			on = false,
		})
	end
end

local function UpdateTick(id: number, tickRate: number)
	Events.TickRateChanged.FireAll({
		id = id,
		tickRate = tickRate,
	})
end

local function GetTickInterval(character: Model?, id: number): number
	local data = idMap[id]
	if data and data.serverOwned then
		return GetNpcConfig(data.npcType).TICK_RATE
	end

	local baseTick = Config.TICK_RATE
	if not character then
		return baseTick
	end

	local model = if Config.DISABLE_DEFAULT_REPLICATION then replicators[id] else character
	local nearbyPlayers = Grid.GetNearbyEntities(model, Config.PROXIMITY, { "player" })

	local multiplier = if Config.DISABLE_DEFAULT_REPLICATION then 4 else 50
	local newTickRate = if #nearbyPlayers > 1 then baseTick else baseTick * multiplier

	if newTickRate ~= playerTickRates[id] then
		playerTickRates[id] = newTickRate
		UpdateTick(id, newTickRate)
	end

	return newTickRate
end

local function Flush(buffers: { buffer }, specificPlayer: Player?)
	local count = math.min(#buffers, MAX_BATCH)
	if count == 0 then
		return false
	end

	local buff = buffer.create(count * SNAPSHOT_SIZE)
	local offset = 0
	for i = 1, count do
		local b: any = table.remove(buffers)
		buffer.copy(buff, offset, b, 0, SNAPSHOT_SIZE)
		offset += SNAPSHOT_SIZE
	end

	if specificPlayer then
		ServerReplicateCFrame:FireClient(specificPlayer, buff)
	else
		ServerReplicateCFrame:FireAllClients(buff)
	end

	Flush(buffers, specificPlayer)

	return true
end

RunService.PostSimulation:Connect(function(deltaTime)
	Grid.UpdateGrid()
	debug.profilebegin("ReplicateNPCs")

	local players = game:GetService("Players"):GetPlayers()
	local playerSpecific = {}

	for _, player in players do
		playerSpecific[player] = {}
	end

	local allPlayers = {}
	local hasNewPlayers = #new_Players > 0
	for id, data in idMap do
		local character = data.player and GetCharacter(data.player)
		local isNPC = data.serverOwned == true

		if not isNPC and (not character or not character.PrimaryPart or not data.clientLastTick) then
			continue
		end

		local tickInterval = GetTickInterval(character or data.model, id)

		local now = os.clock()
		local lastReplicated = lastReplicatedTimes[id]

		if now - lastReplicated < tickInterval then
			continue
		end
		lastReplicatedTimes[id] = now

		local latestSnapshot = data.snapshot:GetLatest()
		local cframe = CFrame.identity
		if latestSnapshot then
			cframe = latestSnapshot.value
		elseif character and character.PrimaryPart then
			cframe = (character :: any).PrimaryPart.CFrame
		else
			continue
		end

		local lastSentCFrame = (data :: any).lastCFrame or CFrame.identity
		local changed = vector.magnitude(lastSentCFrame.Position - cframe.Position :: any) >= 0.05
			or not lastSentCFrame.Rotation:FuzzyEq(cframe.Rotation :: any, 0.0001);
		(data :: any).lastCFrame = cframe

		if CUSTOM_CHARACTERS and character and character.PrimaryPart then
			character.PrimaryPart.CFrame = cframe
		end

		if not changed then
			if hasNewPlayers then
				for _, newPlayer in new_Players do
					local rule = data.replicationRule
					if not rule or (rule.filterType == "exclude" and not table.find(rule.filterPlayers, newPlayer))
						or (rule.filterType == "include" and table.find(rule.filterPlayers, newPlayer)) then
						local list = playerSpecific[newPlayer]
						if list then
							local buff = buffer.create(SNAPSHOT_SIZE)
							PackSnapshotData(buff, 0, data.clientLastTick or now, cframe, id)
							table.insert(list, buff)
						end
					end
				end
			end
			continue
		end
		
		local buff = buffer.create(SNAPSHOT_SIZE)
		PackSnapshotData(buff, 0, data.clientLastTick or now, cframe, id)

		local replicationRule = data.replicationRule
		if not replicationRule or (#replicationRule.filterPlayers == 0 and replicationRule.filterType == "exclude") then
			table.insert(allPlayers, buff)
		else
			if replicationRule.filterType == "include" then
				local check = {}
				for _, player in replicationRule.filterPlayers do
					if not check[player] and playerSpecific[player] then
						check[player] = true
						table.insert(playerSpecific[player], buff)
					end
				end
			else
				local excluded = {}
				for _, player in replicationRule.filterPlayers do
					excluded[player] = true
				end
				for player, list in playerSpecific do
					if not excluded[player] then
						table.insert(list, buff)
					end
				end
			end
		end
	end
	new_Players = {}
	debug.profileend()
	debug.profilebegin("FlushNPCs")

	Flush(allPlayers)

	debug.profileend()
	debug.profilebegin("FlushPlayers")

	for player, list in playerSpecific do
		Flush(list, player)
	end

	debug.profileend()

	if not Config.DISABLE_DEFAULT_REPLICATION then
		return
	end

	--Since we disabled roblox replication, we won't be able to easily do collision detections on the server
	--This module has each player be represented as a dummy parented to the camera (will not replicate)
	-- ~and i simply bulkmoveto them to the latest character CFrame~ BULK move to didn't work with r6 primary part
	for id, clone in replicators do
		local data = idMap[id]
		local primaryPart = clone.PrimaryPart :: BasePart?
		if data and data.snapshot and primaryPart then
			local latestSnapshot = data.snapshot:GetLatest()

			if latestSnapshot then
				primaryPart.CFrame = latestSnapshot.value
			end
		end
	end
end)

--Exposes a function for other scripts to get the most up to date CFrame of a player or npc
--for my personal usecase, I am using it to bypass the physics buffer for hitbox calculation

--Since npc visuals is decoupled from the logic, the npc is never moved on the server
--PushNPCTransform doesnt move the rig, it updates the snapshots and fires the clients to interpolate the rig
--if someone wants the rig to actually move, they can just cframe the rig themselves, but that will be double replicated
local function GetLatestCFrame(input: Player | Model | number): CFrame?
	local id: number?

	id = GetIdFrom(input)

	if not id then
		return nil
	end

	local data = idMap[id]
	if not data then
		return nil
	end

	local latestSnapshot = data.snapshot:GetLatest()
	if latestSnapshot then
		return latestSnapshot.value
	end

	return nil
end

local function GetLatestTime(input: Player | Model | number): number?
	local id = GetIdFrom(input)
	if not id then
		return nil
	end

	local data = idMap[id]
	if not data then
		return nil
	end

	local latestSnapshot = data.snapshot:GetLatest()
	if latestSnapshot then
		return latestSnapshot.t
	end

	return nil
end

local function RegisterNPC(model: Model?, npcType: string?): number
	local id = GetNextID()

	local npcConfig = GetNpcConfig(npcType)

	idMap[id] = {
		player = nil,
		snapshot = Snapshots(CFrame.identity.Lerp),
		clientLastTick = os.clock(),
		serverOwned = true,
		npcType = npcType or "DEFAULT",
		model = model,
	}
	lastReplicatedTimes[id] = 0

	playerTickRates[id] = npcConfig.TICK_RATE
	UpdateTick(id, playerTickRates[id])

	if model then
		model:SetAttribute("NPC_ID", id)
		if npcType ~= "DEFAULT" then
			model:SetAttribute("NPC_TYPE", npcType)
		end
	end

	return id
end

local function UnregisterNPC(id: number): Model?
	local data = idMap[id]
	if not data then
		return
	end

	idMap[id] = nil
	lastReplicatedTimes[id] = nil
	playerTickRates[id] = nil

	ReturnID(id)

	return data.model
end

local function PushNPCTransform(target: number | Model, cframe: CFrame, t: number?)
	local id = GetIdFrom(target) or math.huge
	local data = idMap[id]

	if data and data.serverOwned then
		local timestamp = t or os.clock()
		data.snapshot:Push(timestamp, cframe)
		data.clientLastTick = timestamp
	end
end

return {
	idMap = idMap,
	Replicators = replicators,

	GetReplicationRule = GetReplicationRule,
	SetReplicationRule = SetReplicationRule,

	GetId = GetIdFrom,
	GetLatestCFrame = GetLatestCFrame,
	GetLatestTime = GetLatestTime,

	RegisterNPC = RegisterNPC,
	UnregisterNPC = UnregisterNPC,

	PushNPCTransform = PushNPCTransform,

	TogglePlayerReplication = TogglePlayerReplication,

	GetAllNetworkIds = function()
		local ids = {}
		for id, _ in idMap do
			table.insert(ids, id)
		end
		return ids
	end,
}
