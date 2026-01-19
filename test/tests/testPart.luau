local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chrono = ReplicatedStorage.Packages.chrono
local Config = require(Chrono.Shared.Config)
local Entity = require(Chrono.Shared.Entity)
local Holder = require(Chrono.Shared.Holder)

-- You should see a part in workspace (might need to disable streaming enabled)
return {
	init = function()
		local p = Instance.new("Part")
		p.Position = Vector3.new(0, 100, 0)
		p.Name = "TestPart"
		Config.RegisterEntityModel("TestPart", p)
		Config.SetConfig("REPLICATE_CFRAME_SETTERS", "PLAYER_ENTITIES")
	end,
	server = function()
		local native = Entity.new(nil, "TestPart", "NATIVE")

		local part = Entity.GetPrimaryPart(native)

		if part then
			part.Name = "NativeTestPart"
			part.Color = Color3.new(1, 0, 0)
		end

		local mirrored = Entity.new(nil, "TestPart")
		Entity.LockNativeServerCFrameReplication(mirrored)

		local part = mirrored.model :: BasePart?
		if part then
			part.Name = "MirroredTestPart"
			part.Color = Color3.new(0.478431, 0.180392, 0.180392)
		end

		local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()

		local custom = Entity.new(nil, "TestPart", "CUSTOM")

		local part = custom.model :: BasePart?
		if part then
			part.Color = Color3.new(0, 1, 0)
		end
		print(p, " has control")
		while true do
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
