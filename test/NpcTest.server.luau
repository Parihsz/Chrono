local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcRegistry = require(ReplicatedStorage.Packages.chrono.Shared.NpcRegistry)

local ENABLED = true

if not ENABLED then
	return
end

local model1 = Instance.new("Model", workspace)
local part = Instance.new("Part", model1)
model1.PrimaryPart = part
part.Size = Vector3.new(2, 5, 2)
part.Position = Vector3.new(10, 10, 10)
local id2 = NpcRegistry.Register(model1, "DEFAULT", nil, true)

local player = game:GetService("Players").PlayerAdded:Wait()
task.wait(1)
local model = player.Character or player.CharacterAdded:Wait()
model.Archivable = true

local clone = model:Clone()
clone.Parent = workspace

local id = NpcRegistry.Register(clone, "DEFAULT", nil, true)

NpcRegistry.SetNetworkOwner(id, player)

NpcRegistry.SetPosition(id2, CFrame.new(4, 15, 0))
NpcRegistry.SetPosition(id, CFrame.new(0, 10, 0))

task.wait(4)
print("Starting Toggle Loop")
while true do
	task.wait(4)
	print("Set Player")
	NpcRegistry.SetNetworkOwner(id, player)
	task.wait(4)
	print("Set Server")
	NpcRegistry.SetNetworkOwner(id, nil)
end
