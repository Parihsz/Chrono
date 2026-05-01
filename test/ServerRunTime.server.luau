local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage.Packages.chrono.Shared.Stats)
Players.PlayerAdded:Connect(function(plr)
	Stats.ReplicateStatsForPlayer(plr)
end)

require(script.Parent.tests)
require(ReplicatedStorage.Packages.chrono).Start()
