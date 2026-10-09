const Shared = script.Parent.Parent.Shared

const Types = require(Shared.Types)
const Stats = require(Shared.Stats).CLIENT

const TICKS = 4

local FrustumLookVector = vector.create(0, 0, -1)
local FrustumRightVector = vector.create(1, 0, 0)
local FrustumUpVector = vector.create(0, 1, 0)
local FrustumPosition = vector.create(0, 0, 0)
local TanHorizontal = 0
local TanVertical = 0

local CurrentTick = 0
local OutOfBroadPhaseTick = 0
local TotalCulled = 0

const Frustum = {}

const function Prepare()
	const cframe: CFrame = workspace.CurrentCamera.CFrame
	FrustumLookVector = cframe.LookVector :: any
	FrustumRightVector = cframe.RightVector :: any
	FrustumUpVector = cframe.UpVector :: any

	FrustumPosition = cframe.Position :: any

	const cam = workspace.CurrentCamera
	const halfFov = math.rad(cam.FieldOfView / 2)
	const aspectRatio = cam.ViewportSize.X / cam.ViewportSize.Y
	TanHorizontal = math.tan(halfFov) * aspectRatio
	TanVertical = math.tan(halfFov)
end

const function CheckPoint(pos: vector)
	const diff = pos - FrustumPosition

	const magnitude = vector.magnitude(diff)

	if magnitude == 0 then
		return true
	end

	const forwardDis = vector.dot(diff, FrustumLookVector)

	const forwardDot = forwardDis / magnitude
	if forwardDot < 0 then
		return false
	end
	if forwardDis < 1 then
		return true
	end
	const unit = diff / magnitude
	const rightDot = vector.dot(unit, FrustumRightVector)

	if math.abs(rightDot) > forwardDot * TanHorizontal then
		return false
	end

	const upDot = vector.dot(unit, FrustumUpVector)
	if math.abs(upDot) > forwardDot * TanVertical then
		return false
	end
	return true
end

const function CheckBroadPhase(center: vector, size: vector)
	if size == vector.zero then
		return CheckPoint(center)
	end
	const halfSize = size * 0.5
	const halfX = halfSize.x
	const halfY = halfSize.y
	const halfZ = halfSize.z
	const negX = -halfX
	const negY = -halfY
	const negZ = -halfZ

	return CheckPoint(center + vector.create(halfX, halfY, halfZ))
		or CheckPoint(center + vector.create(negX, halfY, halfZ))
		or CheckPoint(center + vector.create(halfX, negY, halfZ))
		or CheckPoint(center + vector.create(negX, negY, halfZ))
		or CheckPoint(center + vector.create(halfX, halfY, negZ))
		or CheckPoint(center + vector.create(negX, halfY, negZ))
		or CheckPoint(center + vector.create(halfX, negY, negZ))
		or CheckPoint(center + vector.create(negX, negY, negZ))
end

-- Runs every 4 frames at 60hz so this runs at ~15hz
const function Update()
	CurrentTick += 1
	if CurrentTick % TICKS == 0 then
		Stats.TOTAL_ENTITIES_CULLED = TotalCulled
		TotalCulled = 0
		CurrentTick = 0
	end
end

const function IsThrottled(entity: Types.Entity): boolean
	const slot = entity._outofBroadPhaseTick
	return slot ~= nil and slot ~= CurrentTick
end

const function IsCulled(entity: Types.Entity, targetCFrame: CFrame): boolean
	const broadPhase = entity.broadPhase :: vector
	const toCheck = targetCFrame :: any
	const lastCheckedCFrame = entity.lastCheckedCFrame
	debug.profilebegin("Prepare Frustum")
	const passed = CheckBroadPhase(toCheck.Position, broadPhase)
	debug.profileend()
	if not passed then
		if lastCheckedCFrame and lastCheckedCFrame.Position ~= toCheck.Position then
			debug.profilebegin("Check Last CFrame")
			const passLast = CheckBroadPhase(lastCheckedCFrame.Position :: any, broadPhase)
			debug.profileend()
			if not passLast then
				TotalCulled += 1
				return true
			end
		else
			if not lastCheckedCFrame then
				entity.lastCheckedCFrame = toCheck
			end
			if not entity._outofBroadPhaseTick then
				entity._outofBroadPhaseTick = OutOfBroadPhaseTick
				OutOfBroadPhaseTick += 1
				if OutOfBroadPhaseTick % TICKS == 0 then
					OutOfBroadPhaseTick = 0
				end
			end
			TotalCulled += 1
			return true
		end
	end
	entity.lastCheckedCFrame = nil
	entity._outofBroadPhaseTick = nil
	return false
end

Frustum.Prepare = Prepare
Frustum.CheckPoint = CheckPoint
Frustum.CheckBroadPhase = CheckBroadPhase
Frustum.Update = Update
Frustum.IsThrottled = IsThrottled
Frustum.IsCulled = IsCulled

return Frustum
