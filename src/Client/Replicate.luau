local Shared = script.Parent.Parent.Shared
local RunService = game:GetService("RunService")
local RenderCache = require(script.Parent.RenderCache)
local Entity = require(Shared.Entity)
local Holder = require(Shared.Holder)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
require(script.Parent.Receiver)

local idMap = Holder.idMap

local function Interpolate(entity: Types.Entity)
	local model = entity.model
	if not model or not model.PrimaryPart then
		return
	end
	if entity.isContextOwner then
		return
	end
	local primaryPart = model.PrimaryPart
	local snapshot = entity.snapshot
	if not snapshot then
		warn("No snapshot for entity", entity)
		return
	end

	debug.profilebegin("Get and Set CFrame")
	local targetTime = Entity.GetTargetRenderTime(entity)

	local targetCFrame = snapshot:GetAt(targetTime)

	if targetCFrame then
		primaryPart.CFrame = targetCFrame
	end

	debug.profileend()
end

Config._WaitForLock(function()
	RunService.PreRender:Connect(function(deltaTime: number)
		RenderCache.UpdateAll(deltaTime)
		for _, entity in idMap do
			Interpolate(entity)
		end
	end)
	Shared.Remotes.ClientLoaded:FireServer()
end)

return nil
