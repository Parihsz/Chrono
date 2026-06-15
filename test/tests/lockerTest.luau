local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Chrono = ReplicatedStorage.Packages.chrono
local Config = require(Chrono.Shared.Config)
local Entity = require(Chrono.Shared.Entity)
local Holder = require(Chrono.Shared.Holder)
local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = p.Character or p.CharacterAdded:Wait()

return {
	init = function() end,
	server = function()
		RunService.Heartbeat:Connect(function()
			for i, v in Holder.idMap do
				local part = Entity.GetPrimaryPart(v)
				if part then
					local existing = v.__location
					if not existing then
						local debugPart = Instance.new("Part", workspace)
						debugPart.Anchored = true
						debugPart.CanCollide = false
						debugPart.CanQuery = false
						debugPart.CanTouch = false
						debugPart.Transparency = 0.5
						debugPart.Size = Vector3.new(1, 6, 1)
						debugPart.Color = Color3.new(1, 0, 0)
						v.__location = debugPart
					end
					v.__location.CFrame = part.CFrame
				end
			end
		end)
	end,
	client = function() end,
}
