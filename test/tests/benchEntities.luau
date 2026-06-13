local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Chrono = ReplicatedStorage.Packages.chrono
local Holder = require(ReplicatedStorage.Packages.chrono.Shared.Holder)
local Config = require(Chrono.Shared.Config)
local Entity = require(Chrono.Shared.Entity)

local IS_SERVER = RunService:IsServer()
local REMOTE = (IS_SERVER and Instance.new("RemoteEvent", script) or script:WaitForChild("RemoteEvent")) :: RemoteEvent

if IS_SERVER then
	PhysicsService:RegisterCollisionGroup("ChronoTest")
	PhysicsService:CollisionGroupSetCollidable("ChronoTest", "ChronoTest", false)
end

local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = (p.Character or p.CharacterAdded:Wait())
task.wait(3)
for i, v in pairs(char:GetDescendants()) do
	if v:IsA("BasePart") then
		v.CollisionGroup = "ChronoTest"
	end
end

local modelBounds = char:GetExtentsSize()
char.Archivable = true
char = char:Clone()

local primaryPart = char.PrimaryPart
primaryPart.CFrame = CFrame.new(math.random(-50, 50), 20, math.random(-50, 50))

-- if primaryPart.Parent:FindFirstChild("Humanoid") then
-- 	primaryPart.Parent.Humanoid:Destroy()
-- end

for i, v in char:GetChildren() do
	if v:IsA("BaseScript") then
		v.Disabled = true
	end
end

local USE_MOVE_TO = true
local AMT = 150
local BENCHFOR = 60
local CHRONO_TICK_RATE = 1 / 10
local FULL_ROTATION = false
local NORMAL_TICK_DISTANCE = math.huge -- Disables half tick
local Modes = {
	"NATIVE",
	"ROBLOX",
	"NATIVE_WITH_LOCK",
	"CUSTOM",
}
local MODE: "NATIVE" | "NATIVE_WITH_LOCK" | "CUSTOM" | "ROBLOX" | "ALL" = "ALL"
local CLIENT_TEST = nil -- true - test client, false - test server, nil - test both
local random = Random.new(0)

local models = {}

local function GetRandomVector()
	return Vector3.new(random:NextNumber(-30, 30), random:NextNumber(5, 10), random:NextNumber(-30, 30))
end

local function PrintSettings()
	if MODE == "ROBLOX" then
		print("Testing Roblox replication", "AMT:", AMT, "USE_MOVE_TO:", USE_MOVE_TO)
		return
	end
	print(
		`Settings: MODE: {MODE} AMT: {AMT} CHRONO_TICK_RATE: {CHRONO_TICK_RATE} FULL_ROTATION: {FULL_ROTATION} NORMAL_TICK_DISTANCE: {NORMAL_TICK_DISTANCE} USE_MOVE_TO: {USE_MOVE_TO}`
	)
end

local function TrackSend()
	local function getOutgoing()
		return Stats.DataSendKbps + Stats.PhysicsSendKbps
	end

	local start = os.clock()
	local obucket = {}
	while os.clock() - start < BENCHFOR do
		task.wait(0.1)
		table.insert(obucket, getOutgoing())
	end

	local osum = 0
	for i, v in obucket do
		osum += v
	end

	return osum / #obucket
end

local function Start()
	warn(`Found {#models}`)
	local alignPoses = {}
	local slignOri = {}
	if not USE_MOVE_TO then
		for i, v in models do
			local primaryPart = v.PrimaryPart
			local camera = Instance.new("Camera", primaryPart) -- IF we did not do this then setting align position would be replicating to clients
			local alignPos = Instance.new("AlignPosition")
			alignPos.MaxForce = math.huge
			alignPos.Responsiveness = 10
			alignPos.Parent = camera
			alignPos.Attachment0 = Instance.new("Attachment", primaryPart)
			alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
			table.insert(alignPoses, alignPos)
			local alignOri = Instance.new("AlignOrientation")
			alignOri.MaxTorque = math.huge
			alignOri.Responsiveness = 10
			alignOri.Parent = camera
			alignOri.Attachment0 = Instance.new("Attachment", primaryPart)
			alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
			table.insert(slignOri, alignOri)
		end
	end
	task.spawn(function()
		while task.wait(0.5) and #models > 0 do
			if USE_MOVE_TO then
				for _, model in models do
					local humanoid: Humanoid = model:FindFirstChildWhichIsA("Humanoid")
					humanoid:MoveTo(GetRandomVector() * Vector3.new(1, 0, 1))
				end
				continue
			end
			for _, alignPos in alignPoses do
				alignPos.Position = GetRandomVector()
			end
			for _, alignOri in slignOri do
				alignOri.CFrame = CFrame.lookAlong(vector.zero, GetRandomVector())
			end
		end
	end)
end

local function CleanUp()
	table.clear(models)
	if IS_SERVER then
		if MODE == "ROBLOX" then
			for _, model in workspace:GetChildren() do
				if model.Name:find("TestChar") then
					model:Destroy()
				end
			end
		else
			for i, entity in Holder.idMap do
				if entity.model == p.Character then
					continue
				end

				Entity.Destroy(entity)
			end
		end
	end
end

local function ServerPreRun()
	warn(`Spawning {AMT} entities...`)
	local plr = CLIENT_TEST and Players:GetPlayers()[1] or nil
	for i = 1, AMT do
		local primaryPart
		if MODE == "ROBLOX" then
			local model = char:Clone()
			model.Name = "TestChar" .. i
			model.Parent = workspace
			primaryPart = model.PrimaryPart
			primaryPart:SetNetworkOwner(plr)
		else
			local custom = Entity.new("TEST", "TestChar", MODE)
			Entity.SetNetworkOwner(custom, plr)
			custom.model.Name = "TestChar" .. custom.id
			primaryPart = Entity.GetPrimaryPart(custom)
		end
		assert(primaryPart)

		table.insert(models, primaryPart.Parent)
	end
	if not CLIENT_TEST then
		Start()
	else
		REMOTE:FireClient(p, "START", MODE)
		REMOTE.OnServerEvent:Wait()
	end
	task.wait(3)
	warn("STARTING TRACKER: ", BENCHFOR, "seconds")
	PrintSettings()
	REMOTE:FireClient(p, "TRACK")
	local serverRecv, _
	task.spawn(function()
		_, serverRecv = REMOTE.OnServerEvent:Wait()
	end)
	local serverSend = TrackSend()
	warn(`Server Send: {serverSend} Kbps. Waiting for client to finish...`)
	repeat
		task.wait()
	until serverRecv
	warn(`Finished tracking. Server Recv: {serverRecv} Kbps.`)
	task.wait(1)
	CleanUp()
	REMOTE:FireClient(p, "CLEANUP")
end

local function ClientPreRun()
	task.wait(5)
	for i, v in Holder.idMap do
		if v.model and v.model.Name:find("TestChar") then
			table.insert(models, v.model)
		end
	end
	if MODE == "ROBLOX" then
		for _, model in workspace:GetChildren() do
			if model.Name:find("TestChar") then
				table.insert(models, model)
			end
		end
	end
	Start()
end

return {
	init = function()
		char.Name = "TestChar"
		Config.SetConfig("WARNING_SEVERITY", "HIGH")
		Config.RegisterEntityModel("TestChar", char, modelBounds)
		Config.RegisterEntityType("TEST", {
			TICK_RATE = CHRONO_TICK_RATE,
			NORMAL_TICK_DISTANCE = NORMAL_TICK_DISTANCE,
			FULL_ROTATION = FULL_ROTATION,
			BUFFER = 0.1,
			HALF_TICK_DISTANCE = math.huge,
		})
	end,

	server = function()
		--task.wait(40) -- uncomment this for two local clients test

		if MODE == "ALL" then
			local function runAll()
				for _, mode in Modes do
					MODE = mode
					ServerPreRun()
					warn("Finished testing mode", mode, "Waiting 10 seconds before next test...")
					task.wait(10)
				end
			end
			if CLIENT_TEST == nil then
				CLIENT_TEST = false
				warn("Running server tests...")
				runAll()
				CLIENT_TEST = true
				warn("Running client tests...")
				runAll()
			else
				runAll()
			end
		else
			ServerPreRun()
		end
		warn("Finished all tests")
	end,
	client = function()
		REMOTE.OnClientEvent:Connect(function(option, arg1)
			if option == "START" then
				task.wait(3)
				MODE = arg1 or MODE
				ClientPreRun()
				REMOTE:FireServer("STARTED")
			elseif option == "CLEANUP" then
				CleanUp()
			elseif option == "TRACK" then
				local clientSend = TrackSend()
				REMOTE:FireServer(clientSend)
			end
		end)
	end,
}
