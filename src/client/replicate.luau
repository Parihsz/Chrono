local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.shared.config)
local Snapshots = require(script.Parent.Parent.shared.snapshots)
local Events = require(script.Parent.Parent.events.client)
local InterpolationBuffer = require(script.Parent.interpolationBuffer)
local Networkables = require(script.Parent.Parent.shared.makeNetworkable)
local RenderCache = require(script.Parent.renderCache)
local Rig = require(script.Parent.Parent.shared.rigs.createCharacter)
local Character = require(script.Parent.Parent.shared.character)

local CUSTOM_CHARACTERS = Config.ENABLE_CUSTOM_CHARACTERS
local MAX_UNRELIABLE_BYTES = 900
local SNAPSHOT_SIZE = if Config.SEND_FULL_ROTATION then 24 else 20
local HEADER_SIZE = 2
local MAX_BATCH = (MAX_UNRELIABLE_BYTES - HEADER_SIZE) // SNAPSHOT_SIZE

local outgoingSnapshots = {} :: { { timestamp: number, cframe: CFrame } }

local ClientReplicateCFrame: UnreliableRemoteEvent = ReplicatedStorage:WaitForChild("ClientReplicateCFrame") :: any
local ServerReplicateCFrame: UnreliableRemoteEvent = ReplicatedStorage:WaitForChild("ServerReplicateCFrame") :: any

local idMap = {} :: {
	[number]: {
		snapshot: Snapshots.Snapshot<CFrame>,
		character: Model?,
		lastCFrame: CFrame?,
		isNPC: boolean?,
		npcType: string?,
		player: Player?,
		_characterAdded: RBXScriptConnection?,
	},
}

local playerToId = {} :: { [Player]: number }
local player = Players.LocalPlayer
local characters = {} :: { [Player]: Model }
local playerTickRates = {} :: { [number]: number }
local pausedPlayers = {} :: { [number]: boolean }

local bufferTracker = InterpolationBuffer(Config.MIN_BUFFER, Config.MAX_BUFFER, 0.1)
RenderCache.Init({
	playerTickRates = playerTickRates,
	bufferTracker = bufferTracker,
})

local function GetCharacter(player: Player): Model?
	if CUSTOM_CHARACTERS then
		return Character.GetCharacter(player)
	else
		return player.Character
	end
end

local function WaitForCharacter(player: Player): Model
	if CUSTOM_CHARACTERS then
		local _player, character
		repeat
			_player, character = Character.CharacterAdded:Wait()
		until _player == player
		return character
	else
		return player.CharacterAdded:Wait()
	end
end

local playerNetworkId = 300

local function UnpackSnapshotData(buff: buffer, offset: number): any
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
		local remappedRotationY = math.map(rotationY, 0, 2 ^ 16 - 1, -math.pi, math.pi)
		value.cframe = Networkables.DecodeYawCFrame({
			Position = vector.create(x, y, z) :: any,
			RotationY = remappedRotationY,
		})
		value.id = buffer.readu16(buff, offset + 18)
	end

	return value
end

local function PackSnapshotData(buff: buffer, offset: number, timestamp: number, cframe: CFrame)
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
	else
		local networkable = Networkables.MakeYawNetworkable(cframe)
		local mappedRotationY = math.map(networkable.RotationY, -math.pi, math.pi, 0, 2 ^ 16 - 1)
		buffer.writeu16(buff, offset + 16, mappedRotationY)
	end
end

local function Flush()
	local count = math.min(#outgoingSnapshots, MAX_BATCH)
	if count == 0 then
		return false
	end

	local offset = 0
	local snapshotBuffer = buffer.create(count * SNAPSHOT_SIZE)
	for i = 1, count do
		local snapshot = outgoingSnapshots[#outgoingSnapshots]
		outgoingSnapshots[#outgoingSnapshots] = nil
		PackSnapshotData(snapshotBuffer, offset, snapshot.timestamp, snapshot.cframe)
		offset += SNAPSHOT_SIZE
	end

	ClientReplicateCFrame:FireServer(snapshotBuffer)
	Flush()

	return true
end

local function RegisterClientNPC(id: number, model: Model, npcType: string?)
	if not idMap[id] then
		npcType = npcType or "DEFAULT"
		idMap[id] = {
			snapshot = Snapshots(CFrame.identity.Lerp),
			character = nil,
			lastCFrame = nil,
			isNPC = true,
			npcType = npcType,
		}
		RenderCache.Add(id, true, npcType)
	end

	idMap[id].character = model

	if npcType then
		idMap[id].npcType = npcType
	end
end

local function UnregisterNPC(id: number): Model?
	local data = idMap[id]
	if not data then
		return nil
	end

	RenderCache.Remove(id)

	idMap[id] = nil
	return data.character
end

local function NewCharacter(idData: typeof(idMap[1]))
	local player = idData.player
	if not player then
		return
	end

	local initializedCharacter = GetCharacter(player) or WaitForCharacter(player)
	if not initializedCharacter.Parent then
		initializedCharacter = WaitForCharacter(player)
	end

	local old = characters[player]
	if old and old ~= initializedCharacter then
		pcall(old.Destroy, old)
	end

	local primaryPart = initializedCharacter.PrimaryPart :: BasePart

	task.spawn(function()
		if not Config.DISABLE_DEFAULT_REPLICATION then
			return
		end
		if not primaryPart then
			task.wait(1) -- for some reason primary part didn't exist immediately?
			primaryPart = initializedCharacter.PrimaryPart :: BasePart
		end
		if not primaryPart then
			warn("Player has no primary part", player, initializedCharacter)
			return
		end
		primaryPart.Anchored = false

		primaryPart:GetPropertyChangedSignal("Anchored"):Connect(function()
			primaryPart.Anchored = false
		end)
	end)

	characters[player] = initializedCharacter

	local initialCFrame = CFrame.identity

	if characters[player] and characters[player].PrimaryPart then
		initialCFrame = (characters[player] :: any).PrimaryPart.CFrame
	end

	idData.character = initializedCharacter
	idData.lastCFrame = initialCFrame
end

local function PlayerAdded(player: Player, id: number)
	local registeredSnapshots = Snapshots(CFrame.identity.Lerp)
	playerToId[player] = id
	idMap[id] = {
		player = player,
		snapshot = registeredSnapshots,
		character = nil,
		lastCFrame = CFrame.identity,
	}

	RenderCache.Add(id)
	if not CUSTOM_CHARACTERS then
		idMap[id]._characterAdded = player.CharacterAdded:Connect(function(char)
			NewCharacter(idMap[id])
		end)
	end
	NewCharacter(idMap[id])
end

Events.InitializePlayer.On(function(data)
	local playerInstance = Players[data.player]

	if playerInstance then
		PlayerAdded(playerInstance, data.id)
	end
end)

Events.InitializeExistingPlayers.On(function(data)
	for _, playerData in data do
		local playerInstance = Players[playerData.player]

		if playerInstance then
			PlayerAdded(playerInstance, playerData.id)
		end
	end
end)

local lastSent = os.clock()

Events.TickRateChanged.On(function(data)
	playerTickRates[data.id] = data.tickRate
end)

Events.TogglePlayerReplication.On(function(data)
	if data.on then
		pausedPlayers[data.id] = nil
	else
		pausedPlayers[data.id] = true
	end
end)

local function HandleReplicatedData(clientLastTicks, cframes)
	for id, serverTime in clientLastTicks do
		if idMap[id] and not idMap[id].isNPC then
			bufferTracker.RegisterPacket(id, serverTime, playerTickRates[id] or Config.TICK_RATE)
		end
	end

	RenderCache.OnSnapshotUpdate(clientLastTicks)

	for id, cframe in cframes do
		local entry = idMap[id]
		if not entry then
			continue
		elseif entry.isNPC and entry.npcType and not RenderCache.GetTargetRenderTime(id) then
			RenderCache.Add(id, true, entry.npcType)
		end

		--cframes are already decoded when unpacking, so we push directly
		entry.snapshot:Push(clientLastTicks[id], cframe, RenderCache.GetBuffer(id))
	end
end

ServerReplicateCFrame.OnClientEvent:Connect(function(snapshotBuffer)
	local cframes = {}
	local timestamps = {}
	local count, offset = buffer.len(snapshotBuffer) // SNAPSHOT_SIZE, 0

	for i = 1, count do
		local snapshot = UnpackSnapshotData(snapshotBuffer, offset)
		offset += SNAPSHOT_SIZE

		local id = snapshot.id
		cframes[id] = snapshot.cframe
		timestamps[id] = snapshot.timestamp
	end

	HandleReplicatedData(timestamps, cframes)
end)

RunService.PreRender:Connect(function(deltaTime: number)
	RenderCache.Update(deltaTime)
	debug.profilebegin("Calculate CFrames")
	for id, data in idMap do
		if not data.character or data.character == (GetCharacter(player)) then
			continue
		end

		if pausedPlayers[id] then
			continue
		end

		local primaryPart = data.character.PrimaryPart
		if not primaryPart then
			continue
		end

		debug.profilebegin("Get Target CFrame")
		local targetRenderTime = RenderCache.GetTargetRenderTime(id)
		local targetCFrame = data.snapshot:GetAt(targetRenderTime)
		debug.profileend()

		debug.profilebegin("Prepare CFrame")
		if targetCFrame then
			data.lastCFrame = targetCFrame

			-- make sure it isn't welded to anything else (e.g. being carried)

			if primaryPart.AssemblyRootPart == primaryPart then
				primaryPart.CFrame = targetCFrame
			end
		end
		debug.profileend()
	end
	debug.profileend()
end)

local lastSentCFrame = CFrame.identity
RunService.PostSimulation:Connect(function()
	if os.clock() - lastSent < (playerTickRates[playerNetworkId] or Config.TICK_RATE) then
		return
	end
	lastSent = os.clock()

	local character = GetCharacter(player)
	if not character then
		return
	end

	local primaryPart = character.PrimaryPart
	if not primaryPart then
		return
	end

	local currentCFrame = primaryPart.CFrame

	local changed = vector.magnitude(lastSentCFrame.Position - currentCFrame.Position :: any) >= 0.1
		or not lastSentCFrame.Rotation:FuzzyEq(currentCFrame.Rotation :: any, 0.0001)

	lastSentCFrame = currentCFrame

	if not changed then
		return
	end

	table.insert(outgoingSnapshots, {
		timestamp = os.clock(),
		cframe = currentCFrame,
	})
	Flush()
end)

Players.PlayerRemoving:Connect(function(player)
	local idToRemove = playerToId[player]
	playerToId[player] = nil

	if idToRemove then
		RenderCache.Remove(idToRemove)
		local data = idMap[idToRemove]
		if data and data._characterAdded then
			data._characterAdded:Disconnect()
		end
		idMap[idToRemove] = nil
	end

	local character = characters[player]
	characters[player] = nil

	if character then
		pcall(character.Destroy, character)
	end
end)

Character.CharacterAdded:Connect(function(player, character)
	local id = playerToId[player]
	if not id then
		return
	end
	local data = idMap[id]
	if not data then
		return
	end
	if data.character then
		character:PivotTo(data.character:GetPivot())
	end
	data.character = character
	characters[player] = character
end)

return {
	idMap = idMap,
	playerTickRates = playerTickRates,
	BufferTracker = bufferTracker,

	RegisterClientNPC = RegisterClientNPC,
	UnregisterNPC = UnregisterNPC,

	GetAllNetworkIds = function()
		local ids = {}
		for id, _ in idMap do
			table.insert(ids, id)
		end
		return ids
	end,
}
