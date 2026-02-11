local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Chrono = ReplicatedStorage.Packages.chrono
local Config = require(Chrono.Shared.Config)
local Entity = require(Chrono.Shared.Entity)
local Holder = require(Chrono.Shared.Holder)
local Stats = require(Chrono.Shared.Stats)
local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = p.Character or p.CharacterAdded:Wait()
local AMT = 500
local SHOW_DEBUG = false
return {
	init = function()
		char.Archivable = true
		local char = char:Clone()
		char.Name = "TestChar"

		if RunService:IsServer() then
			Config.RegisterEntityModel("TestChar", Instance.new("Part")) -- Dummy part to test server vs client model loading
		else
			local char = char:Clone()
			char.Name = "TestChar"

			Config.RegisterEntityModel("TestChar", char, Vector3.new(5, 6, 5)) -- Larger char for client
		end
		Config.RegisterEntityType("TEST", {
			TICK_RATE = 1 / 20,
			FULL_ROTATION = false,
			BUFFER = 0.1,
			MODEL_REPLICATION_MODE = "CUSTOM",
			HALF_TICK_DISTANCE = math.huge,
		})
	end,
	server = function()
		local entities = {}
		for i = 1, AMT do
			local custom = Entity.new("TEST", "TestChar", nil, CFrame.new(0, 10, 0))
			table.insert(entities, custom)
			if SHOW_DEBUG then
				local p = Instance.new("Part")
				p.Color = Color3.new(1, 0, 1)
				p.Size = Vector3.new(0.5, 2, 0.5)
				p.Anchored = true
				p.Parent = workspace
				custom.a = p
			end
		end
		RunService.Heartbeat:Connect(function()
			for _, entity in entities do
				local part = Entity.GetPrimaryPart(entity) :: BasePart?
				if part then
					part.Anchored = true
					part.CFrame *= CFrame.new(math.random(-1, 1), 0, math.random(-1, 1))
				end
				if entity.a then
					if entity.isHalfTicked == false then
						entity.a.Color = Color3.new(0.482353, 1, 0)
					elseif entity.isHalfTicked == true then
						entity.a.Color = Color3.new(1, 0.482353, 0)
					else
						entity.a.Color = Color3.new(0, 0, 0)
					end
					entity.a.CFrame = entity.latestCFrame or CFrame.new()
				end
			end
		end)
	end,
	client = function()
		local playerGui = p:WaitForChild("PlayerGui")
	end,
}
