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
local SNAPSHOT_SIZE = 18 + 3 -- assume worst cast for id (uInt)
local HEADER_SIZE = 2
local MAX_BATCH = (MAX_UNRELIABLE_BYTES - HEADER_SIZE) // SNAPSHOT_SIZE

local ServerReplicateCFrame = Instance.new("UnreliableRemoteEvent")
ServerReplicateCFrame.Name = "ServerReplicateCFrame"
ServerReplicateCFrame.Parent = ReplicatedStorage

local idStack = {} :: { number }
local playerIdMap = {} :: { [Player]: number }
local idMap = {} :: {
	[number]: {
		player: Player?,
		snapshot: Snapshots.CircularSnapshot<CFrame>,
		clientLastTick: number?,
		serverOwned: boolean?,
		npcType: string?,
		model: Model?,
	},
}
local pausedPlayers = {} :: { [number]: boolean }

local lastReplicatedTimes = {} :: { [number]: number }
local playerTickRates = {} :: { [number]: number }
local replicators = {} :: { [number]: Model }

local MAX_ID = 2 ^ 16 - 1
local IncrementalFactoryUID = 0

local function PackF16(float: number): number
	if float > 65504 then
		return 0b0_11111_0000000000
	end
	if float < -65504 then
		return 0b1_11111_0000000000
	end
	if float ~= float then
		return 0b1_11111_0000000001
	end
	if float == 0 then
		return 0
	end

	local absolute = math.abs(float)
	local interval = math.ldexp(1, math.floor(math.log(absolute, 2)) - 10)
	local rounded = (absolute // interval) * interval
	local fraction, exponent = math.frexp(rounded)
	exponent += 14

	local mantissa = math.round(
		if exponent <= 0 then fraction * 0x400 / math.ldexp(1, math.abs(exponent)) else fraction * 0x800
	) % 0x400

	local result = mantissa + math.max(exponent, 0) * 0x400 + if float < 0 then 0x8000 else 0

	return result
end

local function WriteVlqRaw(b: buffer, index: number, value: number): number
	value += 1
	repeat
		local byte = bit32.band(value, 0x7F)
		value = bit32.rshift(value, 7)

		if value > 0 then
			byte = bit32.bor(byte, 0x80)
		end

		buffer.writeu8(b, index, byte)
		index += 1
	until value == 0
	return index
end

local function PackSnapshotData(
	buff: buffer,
	offset: number,
	timestamp: number,
	cframe: { Position: Vector3, RotationY: number },
	id: number
): number
	buffer.writef32(buff, offset + 0, timestamp)

	buffer.writef32(buff, offset + 4, cframe.Position.X)
	buffer.writef32(buff, offset + 8, cframe.Position.Y)
	buffer.writef32(buff, offset + 12, cframe.Position.Z)

	local mappedRotationY = math.map(cframe.RotationY, -math.pi, math.pi, 0, 2^16 - 1)
	buffer.writeu16(buff, offset + 16, mappedRotationY)
	return WriteVlqRaw(buff, offset + 18, id)
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
	local remappedRotationY = math.map(rotationY, 0, 2^16 - 1, -math.pi, math.pi)

	value.cframe = {
		Position = Vector3.new(x, y, z),
		RotationY = remappedRotationY
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

local function GetNPCConfig(npcType: string?): any
	npcType = npcType or "DEFAULT"
	return Config.NPC_TYPES[npcType] or Config.NPC_TYPES.DEFAULT
end

local function OnCharacterAdded(player: Player, character: Model, id: number)
	if Config.DISABLE_DEFAULT_REPLICATION then
		if StarterPlayer:FindFirstChild("Startercharacter") then
			local clone: Model = StarterPlayer.StarterCharacter:Clone()
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
	}
	lastReplicatedTimes[id] = 0

	InitExistingPlayers(player)

	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character, id)
	end)
	player.CharacterRemoving:Connect(OnCharacterRemoving)
end)

Players.PlayerRemoving:Connect(function(player)
	local id = playerIdMap[player]
	if id then
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
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
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
	if id == 10 then
		print("UpdateTick", tickRate)
	end
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

local function Flush(cframes, lastTicks, ids)
	local count = math.min(#cframes, MAX_BATCH)
	if count == 0 then
		return false
	end

	local buff = buffer.create(count * SNAPSHOT_SIZE)
	local offset = WriteVlqRaw(buff, 0, count)
	for i = 1, count do
		local index = #cframes
		offset = PackSnapshotData(buff, offset, lastTicks[index], cframes[index], ids[index])

		cframes[index] = nil
		lastTicks[index] = nil
		ids[index] = nil
	end

	ServerReplicateCFrame:FireAllClients(buff)
	Flush(cframes, lastTicks, ids)

	return true
end

RunService.PostSimulation:Connect(function(deltaTime)
	Grid.UpdateGrid()

	local cframes = {}
	local lastTicks = {}
	local ids = {}
	debug.profilebegin("ReplicateNPCs")
	for id, data in idMap do
		local character = data.player and data.player.Character or nil
		local isNPC = data.serverOwned == true

		if
			not isNPC
			and (not character or not character.PrimaryPart or not data.clientLastTick)
		then
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

		table.insert(cframes, cframe)
		table.insert(lastTicks, data.clientLastTick or now)
		table.insert(ids, id)
	end
	debug.profileend()

	debug.profilebegin("FlushNPCs")
	Flush(Networkables.NetworkableYawCFrameTable(cframes), lastTicks, ids)
	debug.profileend()
	if not Config.DISABLE_DEFAULT_REPLICATION then
		return
	end

	--Since we disabled roblox replication, we won't be able to easily do collision detections on the server
	--This module has each player be represented as a dummy parented to the camera (will not replicate)
	--and i simply bulkmoveto them to the latest character CFrame
	local staged = {}
	local targets = {}
	for id, clone in replicators do
		local data = idMap[id]
		local primaryPart = clone.PrimaryPart :: BasePart?
		if data and data.snapshot and primaryPart then
			local latestSnapshot = data.snapshot:GetLatest()

			if latestSnapshot then
				table.insert(staged, primaryPart)
				table.insert(targets, latestSnapshot.value)
			end
		end
	end

	if #staged > 0 then
		workspace:BulkMoveTo(staged, targets)
	end
end)

--Exposes a function for other scripts to get the most up to date CFrame of a player or npc
--for my personal usecase, I am using it to bypass the physics buffer for hitbox calculation

--Since npc visuals is decoupled from the logic, the npc is never moved on the server
--PushNPCTransform doesnt move the rig, it updates the snapshots and fires the clients to interpolate the rig
--if someone wants the rig to actually move, they can just cframe the rig themselves, but that will be double replicated
local function GetLatestCFrame(target: Player | number): CFrame?
	local id: number?

	if typeof(target) == "Instance" and target:IsA("Player") then
		id = playerIdMap[target]
	elseif typeof(target) == "number" then
		id = target
	else
		return nil
	end

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

local function PushNPCTransform(id: number, cframe: CFrame, t: number?)
	local data = idMap[id]
	if data and data.serverOwned then
		local stamp = t or os.clock()
		data.snapshot:Push(stamp, cframe)
		data.clientLastTick = stamp
	end
end

return {
	GetLatestCFrame = GetLatestCFrame,
	RegisterNPC = RegisterNPC,
	PushNPCTransform = PushNPCTransform,
	UnregisterNPC = UnregisterNPC,

	TogglePlayerReplication = TogglePlayerReplication,
}
