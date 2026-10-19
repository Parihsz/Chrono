const Types = require(script.Parent.Types)
const Config = require(script.Parent.Config)

const function Hermite(p0: Vector3, p1: Vector3, v0: Vector3, v1: Vector3, t: number, dt: number): Vector3
	v0 = v0 or Vector3.zero
	v1 = v1 or Vector3.zero
	if not dt or dt == 0 then
		return p0:Lerp(p1, t)
	end

	-- Cap tangent at 3x the segment length to reduce overshoot.
	-- https://en.wikipedia.org/wiki/Monotone_cubic_interpolation

	const maxTangent = (p1 - p0).Magnitude * 3
	const t0Length = v0.Magnitude * dt
	if t0Length > maxTangent then
		v0 *= maxTangent / t0Length
	end
	const t1Length = v1.Magnitude * dt
	if t1Length > maxTangent then
		v1 *= maxTangent / t1Length
	end

	const t2 = t * t
	const t3 = t2 * t
	const h00 = 2 * t3 - 3 * t2 + 1
	const h10 = t3 - 2 * t2 + t
	const h01 = -2 * t3 + 3 * t2
	const h11 = t3 - t2

	return p0 * h00 + v0 * dt * h10 + p1 * h01 + v1 * dt * h11
end

const function CalculateVelocity(lP: Vector3, lT: number, cP: Vector3, cT: number, tickrate: number?): Vector3
	local rate = tickrate or 1 / 20
	local dt = cT - lT
	if dt <= 1e-6 then
		return Vector3.zero
	elseif dt > rate * 3 and Config.FLAGS.SNAPSHOT_INTERPOLATION_FIX then
		dt = rate
	end
	if Config.FLAGS.VELOCITY_CALC_FIX then
		dt = math.max(dt, rate) -- ensures that velocity is not calculated with a dt that is too small
	end
	return (cP - lP) / dt
end

const function CheckIdle(
	latest: Types.SnapshotData<CFrame, Vector3>,
	t: number,
	position: Vector3,
	tickrate: number,
	peakSpeed: number?
): boolean
	const gap = t - latest.t
	if gap <= tickrate * 3 or not Config.FLAGS.SNAPSHOT_INTERPOLATION_FIX then
		return false
	end
	const velocity = latest.velocity
	const latestSpeed = if velocity then velocity.Magnitude else 0
	const moved = position - latest.value.Position
	const speed = math.max(latestSpeed, peakSpeed or 0)
	
	const predictedTravel = latestSpeed * gap
	if predictedTravel > speed * tickrate * 1.5 and (moved - velocity * gap).Magnitude < predictedTravel * 0.15 then
		return false
	end
	if speed < 1e-3 then
		return true
	end

	return moved.Magnitude < speed * (gap + tickrate) * 0.5
end

const function VelocityAt(
	latest: Types.SnapshotData<CFrame, Vector3>?,
	t: number,
	cframe: CFrame,
	tickrate: number?,
	peakSpeed: number?
): Vector3
	if not latest then
		return Vector3.zero
	end
	const rate = tickrate or 1 / 20
	const position = cframe.Position
	if t - latest.t > rate * 3 and not CheckIdle(latest, t, position, rate, peakSpeed) then
		return (position - latest.value.Position) / (t - latest.t)
	end
	return CalculateVelocity(latest.value.Position, latest.t, position, t, rate)
end

return {
	Hermite = Hermite,
	VelocityAt = VelocityAt,
	CheckIdle = CheckIdle,
	CalculateVelocity = CalculateVelocity,
}
