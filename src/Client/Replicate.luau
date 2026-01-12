local Shared = script.Parent.Parent.Shared
local RunService = game:GetService("RunService")
local ApplyMounts = require(script.Parent.Parent.Shared.ApplyMounts) 
local RenderCache = require(script.Parent.ClientClock)
local Entity = require(Shared.Entity)
local Holder = require(Shared.Holder)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Sender = require(script.Parent.Sender)
require(script.Parent.Player)
require(script.Parent.Receiver)

local idMap = Holder.idMap

local function Interpolate(entity: Types.Entity)
	local primaryPart = Entity.GetPrimaryPart(entity)

	if not primaryPart then
		return
	end
	if entity.isContextOwner then
		return
	end

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
			if entity.destroyed then
				continue
			end
			if entity.mountParentId then
				continue
			end
			Interpolate(entity)
		end
	
		ApplyMounts()
	end)
	RunService.Heartbeat:Connect(Sender.Update)

	Shared.Remotes.ClientLoaded:FireServer()
end)

return nil
