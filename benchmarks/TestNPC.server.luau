local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Models = {}

local ENABLED = false

local USE_CHRONO = true
local NUM_MODELS = 20
local MODE: "FOLLOW" | "RANDOM" = "FOLLOW"
local RATE = 0

if not ENABLED then
	return
end

local Player = game:GetService("Players").PlayerAdded:Wait()
local Character = Player.Character or Player.CharacterAdded:Wait()
Character.Archivable = true

local Chrono = require(ReplicatedStorage.Packages.chrono)
local NpcRegistry = Chrono.NpcRegistry
local ServerChrono = Chrono.ChronoServer

print("Starting test...")

local function createModel()
	local model
	if MODE == "RANDOM" then
		model = Instance.new("Model")
		model.Name = "TestNPC_" .. #Models + 1
		model.Parent = workspace
		local part = Instance.new("Part")
		part.Name = "HumanoidRootPart"
		part.Size = Vector3.new(2, 5, 2)
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
		model.PrimaryPart = part
	else
		model = Character:Clone()
		model.Parent = workspace
		model.Name = "TestNPC_" .. #Models + 1
		model.Humanoid.DisplayName = model.Name
	end

	if USE_CHRONO then
		NpcRegistry.Register(model, "DEFAULT", nil, true)
		do
			local rule = ServerChrono.GetReplicationRule(model)
			rule.filterType = "include" -- This will only replicate to the first player
			rule.filterPlayers = { Player }
		end
		-- task.delay(10, function()
		-- 	NpcRegistry.UnRegister(model)
		-- end	)
	end
	table.insert(Models, model)
end

for i = 1, NUM_MODELS do
	createModel()
end

local function move()
	for i, v in Models do
		if MODE == "RANDOM" then
			v.PrimaryPart.Anchored = true
			v:PivotTo(CFrame.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)))
		elseif MODE == "FOLLOW" then
			v.Humanoid:MoveTo(Player.Character.HumanoidRootPart.Position)
		end
	end
end

task.spawn(function()
	while true do
		move()
		task.wait(RATE)
	end
end)

return nil
