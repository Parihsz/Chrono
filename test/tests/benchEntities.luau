local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Chrono = ReplicatedStorage.Packages.chrono
local Holder = require(ReplicatedStorage.Packages.chrono.Shared.Holder)
local Config = require(Chrono.Shared.Config)
local Entity = require(Chrono.Shared.Entity)

local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = (p.Character or p.CharacterAdded:Wait())
char.Archivable = true
char = char:Clone()
task.wait(1)
local primaryPart = char.PrimaryPart
primaryPart.CFrame = CFrame.new(math.random(-50, 50), 20, math.random(-50, 50))
local alignPos = Instance.new("AlignPosition")
alignPos.MaxForce = math.huge
alignPos.Responsiveness = math.huge
alignPos.Parent = primaryPart
alignPos.Attachment0 = Instance.new("Attachment", primaryPart)
alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment

local alignOri = Instance.new("AlignOrientation")
alignOri.MaxTorque = math.huge
alignOri.Responsiveness = math.huge
alignOri.Parent = primaryPart
alignOri.Attachment0 = Instance.new("Attachment", primaryPart)
alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment

-- if primaryPart.Parent:FindFirstChild("Humanoid") then
-- 	primaryPart.Parent.Humanoid:Destroy()
-- end
for i, v in pairs(primaryPart.Parent:GetDescendants()) do
	if v:IsA("BasePart") then
		v.CanCollide = false
	end
end

for i, v in char:GetChildren() do
	if v:IsA("BaseScript") then
		v.Disabled = true
	end
end

local AMT = 150
local BENCHFOR = 30
local MODE: "NATIVE" | "CUSTOM" | "ROBLOX" | "NATIVE_WITH_LOCK" = "ROBLOX"
local CLIENT_TEST = true
warn(if CLIENT_TEST then "Client" else "Server", "benchmark with mode:", MODE, "and entity count:", AMT)
local entities = {}
local function RunInterpolation()
	warn(`Found {#entities}`)
	RunService.Heartbeat:Connect(function()
		for _, alignPos in entities do
			alignPos.Enabled = false
			alignPos.Parent.Position = Vector3.new(math.random(-50, 50), math.random(5, 30), math.random(-50, 50))
		end
	end)

	task.delay(5, function()
		print("Start bench")

		local function getIncomming()
			if MODE == "ROBLOX" then
				return Stats.PhysicsSendKbps
			elseif MODE == "NATIVE" then
				return Stats.DataSendKbps + Stats.PhysicsSendKbps
			end
			return Stats.DataSendKbps
		end

		local start = os.clock()
		local bucket = {}
		while os.clock() - start < BENCHFOR do
			task.wait(1)
			table.insert(bucket, getIncomming())
		end

		local sum = 0
		for _, v in bucket do
			sum += v
		end
		local average = sum / #bucket
		warn(`Average incoming bandwidth: {average} Kbps Over {BENCHFOR} seconds with {AMT} entities in {MODE} mode`)
	end)
end

return {
	init = function()
		char.Archivable = true
		local char = char:Clone()
		char.Name = "TestChar"

		if MODE == "ROBLOX" then
			return
		end
		Config.RegisterEntityModel("TestChar", char)
		Config.RegisterEntityType("TEST", {
			TICK_RATE = 1 / 20,
			FULL_ROTATION = false,
			BUFFER = 0.1,
			MODEL_REPLICATION_MODE = MODE,
			HALF_TICK_DISTANCE = math.huge,
		})
	end,
	server = function()
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
				local custom = Entity.new("TEST", "TestChar", nil)
				Entity.SetNetworkOwner(custom, plr)
				primaryPart = Entity.GetPrimaryPart(custom)
			end
			assert(primaryPart)

			table.insert(entities, primaryPart:FindFirstChildWhichIsA("AlignPosition"))
		end
		if not CLIENT_TEST then
			RunInterpolation()
		end
	end,
	client = function()
		if CLIENT_TEST then
			task.wait(6)
			for i, v in Holder.idMap do
				local primaryPart = Entity.GetPrimaryPart(v)
				local alignPos = primaryPart and primaryPart:FindFirstChildWhichIsA("AlignPosition")
				table.insert(entities, alignPos)
			end
			if MODE == "ROBLOX" then
				for _, model in workspace:GetChildren() do
					if model.Name:find("TestChar") then
						local primaryPart = model.PrimaryPart
						local alignPos = primaryPart and primaryPart:FindFirstChildWhichIsA("AlignPosition")
						table.insert(entities, alignPos)
					end
				end
			end
			RunInterpolation()
		end
	end,
}
