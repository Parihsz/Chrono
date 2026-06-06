local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Chrono = ReplicatedStorage.Packages.chrono
local Holder = require(ReplicatedStorage.Packages.chrono.Shared.Holder)
local Config = require(Chrono.Shared.Config)
local Entity = require(Chrono.Shared.Entity)

local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = p.Character or p.CharacterAdded:Wait()

local p2, char2

task.spawn(function()
	p2 = Players:GetPlayers()[2] or Players.PlayerAdded:Wait()
	char2 = p2.Character or p2.CharacterAdded:Wait()
end)

return {
	init = function()
		char.Archivable = true

		local function CreateTestPart(color: Color3, name: string)
			local part = Instance.new("Part")
			part.Size = Vector3.new(2, 2, 2)
			part.Color = color
			part.Name = name
			return part
		end

		Config.RegisterEntityModel("RootEntity", CreateTestPart(Color3.new(1, 0, 0), "Root"))
		Config.RegisterEntityModel("ChildEntity", CreateTestPart(Color3.new(0, 1, 0), "Child"))
		Config.RegisterEntityModel("GrandchildEntity", CreateTestPart(Color3.new(0, 0, 1), "Grandchild"))

		Config.RegisterEntityType("MOUNT_TEST", {
			TICK_RATE = 1 / 20,
			FULL_ROTATION = true,
			BUFFER = 0.1,
			MODEL_REPLICATION_MODE = "CUSTOM",
		})
	end,

	server = function()
		local root = Entity.new("MOUNT_TEST", "RootEntity", nil, CFrame.new(0, 10, 0))
		local child1 = Entity.new("MOUNT_TEST", "ChildEntity", nil, CFrame.new(0, 10, 0))
		local child2 = Entity.new("MOUNT_TEST", "ChildEntity", nil, CFrame.new(0, 10, 0))

		Entity.SetMount(child1, root, CFrame.new(5, 0, 0))
		Entity.SetMount(child2, root, CFrame.new(-5, 0, 0))

		local grandchild = Entity.new("MOUNT_TEST", "GrandchildEntity", nil, CFrame.new(0, 10, 0))
		Entity.SetMount(grandchild, child1, CFrame.new(0, 3, 0))

		local orphan = Entity.new("MOUNT_TEST", "ChildEntity", nil, CFrame.new(10, 10, 0))
		task.delay(15, function()
			warn("remounting orphan to child2")
			Entity.SetMount(orphan, child2, CFrame.new(0, 0, 5))
		end)

		task.delay(20, function()
			warn("clearing child2's mount")
			Entity.ClearMount(child2)
		end)

		local t = 0
		RunService.Heartbeat:Connect(function(dt)
			t += dt
			local plrEntity = Holder.GetEntityFromPlayer(p)
			local part = Entity.GetPrimaryPart(root)
			if part then
				part.Anchored = true
				local cf = CFrame.new(math.cos(t) * 10, 10 + math.sin(t * 2) * 3, math.sin(t) * 10)
					* CFrame.Angles(0, t, 0)
				Entity.SetMount(root, plrEntity, cf)
				--part.CFrame = cf
			end

			if p2 then
				local plr2Entity = Holder.GetEntityFromPlayer(p2)
				local t = t + 32
				if plr2Entity then
					local cf = CFrame.new(math.cos(t) * 5, 10 + math.sin(t * 2) * 3, math.sin(t) * 10)
						* CFrame.Angles(0, t, 0)
					Entity.SetMount(plr2Entity, plrEntity, cf)
				end
			end

			for _, entity in { root, child1, child2, grandchild, orphan } do
				if entity.destroyed then
					continue
				end
			end
		end)
	end,

	client = function()
		print("observe mounted entities moving together")
	end,
}
