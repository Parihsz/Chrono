local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerLocal = Players.LocalPlayer

local ENABLED = false

if not ENABLED then
	return
end

task.wait(2)
local direction = Random.new():NextUnitVector()
RunService.RenderStepped:Connect(function()
	PlayerLocal:Move(direction)
end)

while task.wait(1) do
	direction = -direction
end
