local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcRegistry = require(ReplicatedStorage.Packages.chrono.Shared.NpcRegistry)

do
	return
end

local player = game:GetService("Players").PlayerAdded:Wait()
task.wait(1)
local model = player.Character or player.CharacterAdded:Wait()
model.Archivable = true

local clone = model:Clone()
clone.Parent = workspace

NpcRegistry.Register(clone, "DEFAULT", "TestNPCs", true)
