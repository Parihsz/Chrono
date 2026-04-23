local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chrono = ReplicatedStorage.Packages.chrono
local Config = require(Chrono.Shared.Config)
local Entity = require(Chrono.Shared.Entity)
local Holder = require(Chrono.Shared.Holder)
local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = p.Character or p.CharacterAdded:Wait()
-- You should see a part in workspace (might need to disable streaming enabled)
return {
	init = function()
		char.Archivable = true
		local char = char:Clone()
		char.Name = "TestChar"
		char.PrimaryPart.Anchored = true

		Config.RegisterEntityModel("TestChar", char)
	end,
	server = function()
		local native = Entity.new(nil, "TestChar", "NATIVE")
		local p = Holder.GetEntityFromPlayer(p)
		local part = Entity.GetPrimaryPart(native)

		if part then
			part.Name = "NativeTestPart"
			part.Color = Color3.new(1, 0, 0)
		end
		local paused = false
		task.spawn(function()
			while true do
				local dt = task.wait()
				if paused then
					continue
				end
				part.CFrame *= CFrame.new(0, 0, -50 * dt)
			end
		end)
		task.spawn(function()
			while task.wait(2) do
				Entity.SetCFrame(native, CFrame.new(0,5,0))
				Entity.SetCFrame(p, CFrame.new(8, 5, -5))
				-- paused = true
				-- task.wait(1)
				-- paused = false
			end
		end)
	end,
	client = function()
	
	end,
}
