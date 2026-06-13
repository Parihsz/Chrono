local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chrono = ReplicatedStorage.Packages.chrono
local Config = require(Chrono.Shared.Config)
local Entity = require(Chrono.Shared.Entity)
local Holder = require(Chrono.Shared.Holder)
local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = p.Character or p.CharacterAdded:Wait()
task.wait(2)
-- You should see a part in workspace (might need to disable streaming enabled)
local function movePart(part: BasePart)
	local dir = 1
	local dist = 20
	while true do
		local delta = task.wait()
		part.CFrame *= CFrame.new(0, 0, dir * delta * 10)
		dist -= delta * 10
		if dist <= 0 then
			dir *= -1
			dist = 10
		end
	end
end
return {
	init = function()
		char.Archivable = true
		local char = char:Clone()
		char.Name = "TestChar"

		Config.RegisterEntityModel("TestChar", char)
		Config.SetConfig("REPLICATE_CFRAME_SETTERS", "PLAYER_CHARACTERS")
	end,
	server = function()
		local native = Entity.new(nil, "TestChar", "NATIVE")
		local part = Entity.GetPrimaryPart(native)

		if part then
			part.Parent.Name = "NativeTestPart"
			part.Color = Color3.new(1, 0, 0)
			task.spawn(movePart, part)
		end

		local mirrored = Entity.new(nil, "TestChar", "NATIVE_WITH_LOCK")

		local part = Entity.GetPrimaryPart(mirrored) :: BasePart?
		if part then
			part.Parent.Name = "MirroredTestPart"
			part.Color = Color3.new(0.478431, 0.180392, 0.180392)
			task.spawn(movePart, part)
		end

		local custom = Entity.new(nil, "TestChar", "CUSTOM")
		local part = Entity.GetPrimaryPart(custom) :: BasePart?
		if part then
			part.Parent.Name = "CustomTestPart"
			part.Color = Color3.new(0, 1, 0)

			task.spawn(movePart, part)
		end

		--	Entity.SetNetworkOwner(mirrored, p)
		print(p, " has control")

		while false do
			task.wait(5)
			warn("Give player owner")
			Entity.SetNetworkOwner(native, p)
			Entity.SetNetworkOwner(mirrored, p)
			Entity.SetNetworkOwner(custom, p)
			task.wait(10)
			warn("Remove player owner")
			Entity.SetNetworkOwner(native, nil)
			Entity.SetNetworkOwner(mirrored, nil)
			Entity.SetNetworkOwner(custom, nil)
		end
	end,
	client = function()
		workspace.ChildAdded:Connect(print)
	end,
}
