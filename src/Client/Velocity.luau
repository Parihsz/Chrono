const Types = require(script.Parent.Parent.Shared.Types)

const MAX_GAP = 0.5 -- seconds between frames before the estimate restarts
const MAX_SPEED = 1000 

const ZERO = Vector3.zero

const Velocity = {}

const function Estimate(
	entity: Types.Entity,
	cframe: CFrame,
	renderTime: number,
	withAngular: boolean
): (Vector3, Vector3, boolean)
	local state = entity._velocity
	if not state then
		const newState: Types.VelocityState = { cframe = cframe, time = renderTime, linear = ZERO, angular = ZERO }
		state = newState
		entity._velocity = state
		return ZERO, ZERO, false
	end
	const dt = renderTime - state.time
	if dt <= 0 then
		return state.linear, state.angular, false
	end
	const last = state.cframe
	state.cframe = cframe
	state.time = renderTime
	if dt > MAX_GAP then
		state.linear = ZERO
		state.angular = ZERO
		return ZERO, ZERO, false
	end

	local linear = (cframe.Position - last.Position) / dt
	local valid = true
	if linear.Magnitude > MAX_SPEED then
		linear = ZERO
		valid = false
	end
	local angular = ZERO
	if withAngular then
		const axis, angle = (cframe.Rotation * last.Rotation:Inverse()):ToAxisAngle()
		if angle == angle and angle > 1e-6 then
			angular = axis * (angle / dt)
		end
	end
	state.linear = linear
	state.angular = angular
	return linear, angular, valid
end

const function Step(
	entity: Types.Entity,
	part: BasePart,
	cframe: CFrame,
	renderTime: number,
	settled: boolean,
	mode: Types.ESTIMATE_VELOCITY
)
	local linear, angular = Estimate(entity, cframe, renderTime, mode ~= "LINEAR")
	if settled then
		const state = entity._velocity :: Types.VelocityState
		state.linear = ZERO
		state.angular = ZERO
		linear, angular = ZERO, ZERO
	end

	if mode ~= "ANGULAR" then
		part.AssemblyLinearVelocity = linear
	end
	if mode ~= "LINEAR" then
		part.AssemblyAngularVelocity = angular
	end
end

const function Clear(entity: Types.Entity, part: BasePart?)
	if not entity._velocity then
		return
	end
	entity._velocity = nil
	if part and part.Anchored then
		part.AssemblyLinearVelocity = ZERO
		part.AssemblyAngularVelocity = ZERO
	end
end

Velocity.Estimate = Estimate
Velocity.Step = Step
Velocity.Clear = Clear

return Velocity
