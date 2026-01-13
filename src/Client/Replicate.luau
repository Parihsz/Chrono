local Shared = script.Parent.Parent.Shared
local RunService = game:GetService("RunService")
local ApplyMounts = require(script.Parent.Parent.Shared.ApplyMounts)
local RenderCache = require(script.Parent.ClientClock)
local Entity = require(Shared.Entity)
local Holder = require(Shared.Holder)
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Sender = require(script.Parent.Sender)
local Stats = require(Shared.Stats).CLIENT
require(script.Parent.Player)
require(script.Parent.Receiver)

local idMap = Holder.idMap

local FrustumLookVector = vector.create(0, 0, -1)
local FrustumRightVector = vector.create(1, 0, 0)
local FrustumUpVector = vector.create(0, 1, 0)
local FrustumPosition = vector.create(0, 0, 0)
local TanHorizontal = 0
local TanVertical = 0

local function PrepareFrustumCheck()
	local cframe: CFrame = workspace.CurrentCamera.CFrame
	FrustumLookVector = cframe.LookVector :: any
	FrustumRightVector = cframe.RightVector :: any
	FrustumUpVector = cframe.UpVector :: any

	FrustumPosition = cframe.Position :: any

	local cam = workspace.CurrentCamera
	local halfFov = math.rad(cam.FieldOfView / 2)
	local aspectRatio = cam.ViewportSize.X / cam.ViewportSize.Y
	TanHorizontal = math.tan(halfFov) * aspectRatio
	TanVertical = math.tan(halfFov)
end

local function CheckPointInFrustum(pos: vector)
	local diff = pos - FrustumPosition

	local magnitude = vector.magnitude(diff)

	if magnitude == 0 then
		return true
	end

	local forwardDis = vector.dot(diff, FrustumLookVector)

	local forwardDot = forwardDis / magnitude
	if forwardDot < 0 then
		return false
	end
	if forwardDis < 1 then
		return true
	end
	local unit = diff / magnitude
	local rightDot = vector.dot(unit, FrustumRightVector)

	if math.abs(rightDot) > forwardDot * TanHorizontal then
		return false
	end

	local upDot = vector.dot(unit, FrustumUpVector)
	if math.abs(upDot) > forwardDot * TanVertical then
		return false
	end
	return true
end

local function CheckBroadPhaseInFrustum(center: vector, size: vector)
	if size == vector.zero then
		return CheckPointInFrustum(center)
	end
	local halfSize = size * 0.5
	local halfX = halfSize.x
	local halfY = halfSize.y
	local halfZ = halfSize.z
	local negX = -halfX
	local negY = -halfY
	local negZ = -halfZ

	return CheckPointInFrustum(center + vector.create(halfX, halfY, halfZ))
		or CheckPointInFrustum(center + vector.create(negX, halfY, halfZ))
		or CheckPointInFrustum(center + vector.create(halfX, negY, halfZ))
		or CheckPointInFrustum(center + vector.create(negX, negY, halfZ))
		or CheckPointInFrustum(center + vector.create(halfX, halfY, negZ))
		or CheckPointInFrustum(center + vector.create(negX, halfY, negZ))
		or CheckPointInFrustum(center + vector.create(halfX, negY, negZ))
		or CheckPointInFrustum(center + vector.create(negX, negY, negZ))
end
local Ticks = 4
local OutOfBroadPhaseTick = 0
local CurrentTick = 0
local TotalInterpolationTime = 0
local AmtInterpolations = 0

local CheckedThisFrame = 0
local TotalCulled = 0
local MovedThisFrame = 0

local function Interpolate(entity: Types.Entity)
	if entity.entityConfig.CUSTOM_INTERPOLATION then
		return
	end
	local primaryPart = Entity.GetPrimaryPart(entity)

	if not primaryPart then
		return
	end
	if entity.isContextOwner then
		return
	end

	local currentEntityTick = entity._outofBroadPhaseTick 
	if currentEntityTick and currentEntityTick~=CurrentTick then
		return
	end
	
	local snapshot = entity.snapshot
	if not snapshot then
		warn("No snapshot for entity", entity)
		return
	end
	CheckedThisFrame += 1
	debug.profilebegin("Get Render CFrame")
	local targetTime = Entity.GetTargetRenderTime(entity)
	local targetCFrame = snapshot:GetAt(targetTime)
	debug.profileend()
	if not targetCFrame then
		return
	end
	local broadPhase: vector? = entity.broadPhase

	if broadPhase then
		local toCheck = targetCFrame :: any
		local lastCheckedCFrame = entity.lastCheckedCFrame
		debug.profilebegin("Prepare Frustum")
		local passed = CheckBroadPhaseInFrustum(toCheck.Position, broadPhase)
		debug.profileend()
		if not passed then
			if lastCheckedCFrame and lastCheckedCFrame.Position ~= toCheck.Position then
				debug.profilebegin("Check Last CFrame")
				local passLast = CheckBroadPhaseInFrustum(lastCheckedCFrame.Position :: any, broadPhase)
				debug.profileend()
				if not passLast then
					TotalCulled += 1
					return
				end
			else
				if not lastCheckedCFrame then
					entity.lastCheckedCFrame = toCheck
				end
				if not entity._outofBroadPhaseTick then
					entity._outofBroadPhaseTick = OutOfBroadPhaseTick
					OutOfBroadPhaseTick += 1
					if OutOfBroadPhaseTick%Ticks == 0 then
						OutOfBroadPhaseTick = 0
					end
				end
				TotalCulled += 1
				return
			end
		end
		entity.lastCheckedCFrame = nil
		entity._outofBroadPhaseTick = nil
	end
	debug.profilebegin("Set CFrame")
	primaryPart.CFrame = targetCFrame
	MovedThisFrame += 1
	debug.profileend()
end

Config._WaitForLock(function()
	RunService.Heartbeat:Connect(function(deltaTime: number)
		CurrentTick += 1
		if CurrentTick%Ticks == 0 then -- Runs every 4 frames at 60hz this is 15hz
			Stats.TOTAL_ENTITIES_CULLED = TotalCulled
			TotalCulled = 0
			CurrentTick = 0
		end
		RenderCache.UpdateAll(deltaTime)
		PrepareFrustumCheck()
		local total = 0
		local startTime = os.clock()
		for _, entity in idMap do
			if entity.destroyed then
				continue
			end
			if entity.mountParentId then
				continue
			end
			total += 1
			Interpolate(entity)
		end
		local endTime = os.clock()
		TotalInterpolationTime += (endTime - startTime)
		AmtInterpolations += 1

		ApplyMounts()
		Stats.TOTAL_CLIENT_ENTITIES_CHECKED_THIS_FRAME = total
		Stats.ENTITIES_MOVED_THIS_FRAME = MovedThisFrame
		Stats.TOTAL_CLIENT_ENTITIES = total
		Stats.AVG_INTERPOLATION_TIME_MS = (TotalInterpolationTime / AmtInterpolations) * 1000
		MovedThisFrame = 0
		CheckedThisFrame = 0
		if AmtInterpolations > 60 then
			TotalInterpolationTime = 0
			AmtInterpolations = 0
		end
	end)
	RunService.Heartbeat:Connect(Sender.Update)

	Shared.Remotes.ClientLoaded:FireServer()
end)

return nil
