local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(script.Parent.Parent.shared.config)
local Snapshots = require(script.Parent.Parent.shared.snapshots)
local Grid = require(script.Parent.Parent.shared.grid)
local Events = require(script.Parent.Parent.events.server)
local config = require(script.Parent.Parent.shared.config)
local Networkables = require(script.Parent.Parent.shared.makeNetworkable)

local ClientReplicateCFrame = Instance.new("UnreliableRemoteEvent")
ClientReplicateCFrame.Name = "ClientReplicateCFrame"
ClientReplicateCFrame.Parent = ReplicatedStorage

local MAX_UNRELIABLE_BYTES = 900
local SNAPSHOT_SIZE = 18 + 2 -- assume worst cast for id (uInt)
local HEADER_SIZE = 2
local MAX_BATCH = (MAX_UNRELIABLE_BYTES - HEADER_SIZE) // SNAPSHOT_SIZE

local ServerReplicateCFrame = Instance.new("UnreliableRemoteEvent")
ServerReplicateCFrame.Name = "ServerReplicateCFrame"
ServerReplicateCFrame.Parent = ReplicatedStorage

local idStack = {} :: { number }
local playerIdMap = {} :: { [Player]: number }

export type ReplicationRule = {
	filterType: "include" | "exclude",
	filterPlayers: {Player},
}

local idMap = {} :: {
	[number]: {
		player: Player?,
		snapshot: Snapshots.Snapshot<CFrame>,
		clientLastTick: number?,
		serverOwned: boolean?,
		npcType: string?,
		model: Model?,
		_charAdded: RBXScriptConnection?,
		_charRemoving: RBXScriptConnection?,
		replicationRule: ReplicationRule?,
	},
}
local pausedPlayers = {} :: { [number]: boolean }

local lastReplicatedTimes = {} :: { [number]: number }
local playerTickRates = {} :: { [number]: number }
local replicators = {} :: { [number]: Model }

local MAX_ID = 2 ^ 16 - 1
local IncrementalFactoryUID = 0

local function PackSnapshotData(
	buff: buffer,
	offset: number,
	timestamp: number,
	cframe: { Position: Vector3, RotationY: number },
	id: number
)
	buffer.writef32(buff, offset + 0, timestamp)

	buffer.writef32(buff, offset + 4, cframe.Position.X)
	buffer.writef32(buff, offset + 8, cframe.Position.Y)
	buffer.writef32(buff, offset + 12, cframe.Position.Z)

	local mappedRotationY = math.map(cframe.RotationY, -math.pi, math.pi, 0, 2 ^ 16 - 1)
	buffer.writeu16(buff, offset + 16, mappedRotationY)
	buffer.writeu16(buff, offset + 18, id)
end

local function UnpackSnapshotData(
	buff: buffer,
	offset: number
): { timestamp: number, cframe: { Position: Vector3, RotationY: number } }
	local value = {}
	value.timestamp = buffer.readf32(buff, offset + 0)

	local x = buffer.readf32(buff, offset + 4)
	local y = buffer.readf32(buff, offset + 8)
	local z = buffer.readf32(buff, offset + 12)

	local rotationY = buffer.readu16(buff, offset + 16)
	local remappedRotationY = math.map(rotationY, 0, 2 ^ 16 - 1, -math.pi, math.pi)

	value.cframe = {
		Position = Vector3.new(x, y, z),
		RotationY = remappedRotationY,
	}

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

local function GetIdFrom(input:Player|Model|number):number?
	if typeof(input) == "Instance" then
		if input:IsA("Player") then
			return playerIdMap[input]
		elseif input:IsA("Model") then
			return input:GetAttribute("NPC_ID")::any
		end
	elseif typeof(input) == "number" then
		return input
	end

	return nil
end

local function newReplicationRule(): ReplicationRule
	return {
		filterType = "exclude",
		filterPlayers = {},
	}
end

local function GetReplicationRule(input: Player | Model | number): ReplicationRule
	local id = GetIdFrom(input)
	if not id then
		return newReplicationRule()
	end

	local data = idMap[id]
	if not data then
		return newReplicationRule()
	end

	if not idMap[id].replicationRule then
		idMap[id].replicationRule = newReplicationRule()
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

local function GetNPCConfig(npcType: string?): any
	npcType = npcType or "DEFAULT"
	return Config.NPC_TYPES[npcType] or Config.NPC_TYPES.DEFAULT
end

local function OnCharacterAdded(player: Player, character: Model, id: number)
	if Config.DISABLE_DEFAULT_REPLICATION then
		if StarterPlayer:FindFirstChild("Replicator") then
			local clone: Model = StarterPlayer.Replicator:Clone()
			clone.Name = player.Name
			clone.Parent = workspace.CurrentCamera

			replicators[id] = clone
		end
	end

	if Config.ENABLE_CUSTOM_CHARACTERS then
		character.Parent = workspace.CurrentCamera
	end

	Grid.AddEntity(character, "player")
	Events.InitializePlayer.FireAll({
		id = id,
		player = player.Name,
	})
end

local function OnCharacterRemoving(character: Model)
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
	idMap[id] = {
		player = player,
		snapshot = Snapshots(CFrame.identity.Lerp),
		clientLastTick = nil,
		--clientLastTick:
		--players: last tick received from that client
		--NPCs: last tick generated on the server (acts as serverLastTick)

		serverOwned = false,
		npcType = nil,
		_charAdded = nil,
		_charRemoving = nil,
	}
	lastReplicatedTimes[id] = 0

	InitExistingPlayers(player)

	idMap[id]._charAdded = player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character, id)
	end)
	idMap[id]._charRemoving = player.CharacterRemoving:Connect(OnCharacterRemoving)
end)

Players.PlayerRemoving:Connect(function(player)
	local id = playerIdMap[player]
	if id then
		local _charAdded = idMap[id]._charAdded
		if _charAdded then
			_charAdded:Disconnect()
		end

		local _charRemoving = idMap[id]._charRemoving
		if _charRemoving then
			_charRemoving:Disconnect()
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

	local SNAPSHOT_SIZE = 18

	local offset = 0
	for i = 1, buffer.len(snapshotBuffer) // SNAPSHOT_SIZE do
		local snapshot = UnpackSnapshotData(snapshotBuffer, offset)
		offset += SNAPSHOT_SIZE

		local cframe = CFrame.new(snapshot.cframe.Position) * CFrame.Angles(0, snapshot.cframe.RotationY, 0)

		data.clientLastTick = snapshot.timestamp
		data.snapshot:Push(snapshot.timestamp, cframe)
	end

	local character = player.Character
	local hrp = character and character.PrimaryPart :: BasePart?
	if config.DISABLE_DEFAULT_REPLICATION and hrp then
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
		return GetNPCConfig(data.npcType).TICK_RATE
	end

	local baseTick = Config.TICK_RATE
	if not character then
		return baseTick
	end

	local nearbyPlayers = Grid.GetNearbyEntities(character, Config.PROXIMITY, { "player" })
	local newTickRate = if #nearbyPlayers > 1 then baseTick else baseTick * 2

	if newTickRate ~= playerTickRates[id] then
		playerTickRates[id] = newTickRate
		UpdateTick(id, newTickRate)
	end

	return newTickRate
end

local function Flush(buffers:{buffer},specificPlayer:Player?)
	local count = math.min(#buffers, MAX_BATCH)
	if count == 0 then
		return false
	end

	local buff = buffer.create(count * SNAPSHOT_SIZE)
	local offset = 0
	for i = 1, count do
		local b:any = table.remove(buffers)
		buffer.copy(buff, offset, b, 0, SNAPSHOT_SIZE)
		offset += SNAPSHOT_SIZE
	end

	if specificPlayer then
		ServerReplicateCFrame:FireClient(specificPlayer, buff)
	else
		ServerReplicateCFrame:FireAllClients(buff)
	end

	Flush(buffers,specificPlayer)

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
	for id, data in idMap do
		local character = data.player and data.player.Character or nil
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
		end

		local lastSentCFrame = (data :: any).lastCFrame or CFrame.identity
		local changed = vector.magnitude(lastSentCFrame.Position - cframe.Position :: any) >= 0.1
			or not lastSentCFrame.Rotation:FuzzyEq(cframe.Rotation :: any, 0.0001);
		(data :: any).lastCFrame = cframe

		if not changed then
			continue
		end
		local buff = buffer.create(SNAPSHOT_SIZE)
		PackSnapshotData(buff, 0, data.clientLastTick or now, Networkables.MakeYawNetworkable(cframe), id)
		
		local replicationRule = data.replicationRule
		if not replicationRule or (#replicationRule.filterPlayers == 0 and replicationRule.filterType == "exclude") then
			table.insert(allPlayers, buff)
		else
			if replicationRule.filterType ==  'include' then
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
	debug.profileend()
	debug.profilebegin("FlushNPCs")

	Flush(allPlayers)

	debug.profileend()
	debug.profilebegin("FlushPlayers")

	for player, list in playerSpecific do
		Flush(list,player)
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
local function GetLatestCFrame(input:Player|Model|number): CFrame?
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

local function GetLatestTime(input:Player|Model|number):number?
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

	local npcConfig = GetNPCConfig(npcType)

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
	if data.model then
		Grid.RemoveEntity(data.model)
	end
	return data.model
end

local function PushNPCTransform(target: number|Model, cframe: CFrame, t: number?)
	local id = GetIdFrom(target) or math.huge
	local data = idMap[id]
	if data and data.serverOwned then
		local stamp = t or os.clock()
		data.snapshot:Push(stamp, cframe)
		data.clientLastTick = stamp
	end
end

return {
	GetReplicationRule =GetReplicationRule,
	SetReplicationRule = SetReplicationRule,
	GetId = GetIdFrom,
	GetLatestCFrame = GetLatestCFrame,
	RegisterNPC = RegisterNPC,
	PushNPCTransform = PushNPCTransform,
	UnregisterNPC = UnregisterNPC,
	GetLatestTime = GetLatestTime,
	TogglePlayerReplication = TogglePlayerReplication,
	Replicators = replicators,
	GetAllNetworkIds = function()
		local ids = {}
		for id, _ in idMap do
			table.insert(ids, id)
		end
		return ids
	end,
}
