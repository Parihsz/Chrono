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

local MAX_UNRELIABLE_BYTES = 900
local SNAPSHOT_SIZE = 19
local HEADER_SIZE = 2
local MAX_BATCH = (MAX_UNRELIABLE_BYTES - HEADER_SIZE) // SNAPSHOT_SIZE

local outgoingSnapshots = {} :: { { timestamp: number, cframe: { Position: Vector3, RotationY: number } } }

local ClientReplicateCFrame: UnreliableRemoteEvent = ReplicatedStorage:WaitForChild("ClientReplicateCFrame") :: any
local ServerReplicateCFrame: UnreliableRemoteEvent = ReplicatedStorage:WaitForChild("ServerReplicateCFrame") :: any

local idMap = {} :: {
	[number]: {
		snapshot: Snapshots.CircularSnapshot<CFrame>,
		character: Model?,
		lastCFrame: CFrame?,
		isNPC: boolean?,
		npcType: string?,
	},
}

local player = Players.LocalPlayer
local initializedPlayers = {} :: { [Player]: boolean }
local characters = {} :: { [Player]: Model }
local playerTickRates = {} :: { [number]: number }
local pausedPlayers = {} :: { [number]: boolean }

local bufferTracker = InterpolationBuffer(Config.MIN_BUFFER, Config.MAX_BUFFER, 0.1)
RenderCache.Init({
	playerTickRates = playerTickRates,
	bufferTracker = bufferTracker,
})

local playerNetworkId = 300

local function ReadVlqRaw(b: buffer, index: number): (number, number)
	local value = 0
	local shift = 0
	local byte: number

	repeat
		byte = buffer.readu8(b, index)
		value += bit32.lshift(bit32.band(byte, 0x7F), shift)
		shift += 7
		index += 1
	until byte < 0x80
	return value - 1, index
end

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

local function UnpackSnapshotData(
	buff: buffer,
	offset: number
): (
	{ timestamp: number, cframe: { Position: Vector3, RotationY: number }, id: number },
	number
)
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

	local id, newOffset = ReadVlqRaw(buff, offset + 18)
	value.id = id

	return value, newOffset
end

local function PackSnapshotData(
	buff: buffer,
	offset: number,
	timestamp: number,
	cframe: { Position: Vector3, RotationY: number }
)
	buffer.writef32(buff, offset + 0, timestamp)

	buffer.writef32(buff, offset + 4, cframe.Position.X)
	buffer.writef32(buff, offset + 8, cframe.Position.Y)
	buffer.writef32(buff, offset + 12, cframe.Position.Z)

	local mappedRotationY = math.map(cframe.RotationY, -math.pi, math.pi, 0, 2^16 - 1)
	buffer.writeu16(buff, offset + 16, mappedRotationY)
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

	if not data.character then
		warn("Tried to unregister NPC that hasn't been registered yet")
		return nil
	end

	RenderCache.Remove(id)

	idMap[id] = nil
	return data.character
end

local function PlayerAdded(player: Player, id: number)
	if initializedPlayers[player] then
		warn("Player already initialized", player)
		return
	end

	if player == Players.LocalPlayer then
		playerNetworkId = id
	end

	initializedPlayers[player] = true

	local registeredSnapshots = Snapshots(CFrame.identity.Lerp)

	local initialRenderTime = os.clock()

	if Config.ENABLE_CUSTOM_CHARACTERS then
		local rig = Rig(player, player.UserId)
		if not rig or not rig.Model then
			warn("Failed to create character for player", player)
			return
		end

		rig.Model.Parent = workspace
		characters[player] = rig.Model

		workspace.CurrentCamera.CameraSubject = rig.Model:FindFirstChildOfClass("Humanoid") or rig.Model.PrimaryPart
	else
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
		humanoidRootPart.Anchored = false

		humanoidRootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
			humanoidRootPart.Anchored = false
		end)

		characters[player] = character
	end

	local initialCFrame = CFrame.identity

	if characters[player] and characters[player].PrimaryPart then
		initialCFrame = (characters[player] :: any).PrimaryPart.CFrame
	end

	registeredSnapshots:Push(initialRenderTime, initialCFrame)

	idMap[id] = {
		snapshot = registeredSnapshots,
		character = characters[player],
		lastCFrame = initialCFrame,
	}

	RenderCache.Add(id)

	local humanoid = characters[player]:WaitForChild("Humanoid") :: Humanoid

	humanoid.Died:Connect(function()
		initializedPlayers[player] = nil
	end)
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
--local lastSentCFrame = CFrame.identity

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

		--since CFrames are received in the networkable format, I have to decode it to be actual CFrames. It is nicely done because of the roblox CFrame.new overload for quaternions.
		--same applies on the server as well of course.
		entry.snapshot:Push(clientLastTicks[id], Networkables.DecodeYawCFrame(cframe))
	end
end

ServerReplicateCFrame.OnClientEvent:Connect(function(snapshotBuffer)
	local cframes = {}
	local timestamps = {}
	local count, offset = ReadVlqRaw(snapshotBuffer, 0)
	for i = 1, count do
		local snapshot, offset_ = UnpackSnapshotData(snapshotBuffer, offset)
		offset = offset_

		local id = snapshot.id
		cframes[id] = snapshot.cframe
		timestamps[id] = snapshot.timestamp
	end

	HandleReplicatedData(timestamps, cframes)
end)

-- Events.ServerReplicateCFrame.On(function(serverData: { timestamps: { [number]: number }, cframes: { [number]: any } })
-- 	HandleReplicatedData(serverData.timestamps, serverData.cframes)
-- end)

RunService.PreRender:Connect(function(deltaTime: number)
	RenderCache.Update(deltaTime)

	local parts = {}
	local cframes = {}
	local index = 0
	debug.profilebegin("Calculate CFrames")
	for id, data in idMap do
		if not data.character or data.character == player.Character then
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
				index += 1
				parts[index] = primaryPart
				cframes[index] = targetCFrame
			end
		end
		debug.profileend()
	end
	debug.profileend()
	workspace:BulkMoveTo(parts, cframes)
end)

local lastSentCFrame = CFrame.identity
RunService.PostSimulation:Connect(function()
	if os.clock() - lastSent < (playerTickRates[playerNetworkId] or Config.TICK_RATE) then
		return
	end
	lastSent = os.clock()

	if not player.Character then
		return
	end

	local primaryPart = player.Character.PrimaryPart
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

	local networkable = Networkables.MakeYawNetworkable(currentCFrame)
	table.insert(outgoingSnapshots, {
		timestamp = os.clock(),
		cframe = networkable,
	})

	Flush()
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
