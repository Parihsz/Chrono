local Types = require(script.Parent.Types)
local Config = require(script.Parent.Config)

local function Hermite(p0: Vector3, p1: Vector3, v0: Vector3, v1: Vector3, t: number, dt: number): Vector3
	v0 = v0 or Vector3.zero
	v1 = v1 or Vector3.zero
	if not dt or dt == 0 then
		return p0:Lerp(p1, t)
	end

	local t2 = t * t
	local t3 = t2 * t
	local h00 = 2 * t3 - 3 * t2 + 1
	local h10 = t3 - 2 * t2 + t
	local h01 = -2 * t3 + 3 * t2
	local h11 = t3 - t2

	return p0 * h00 + v0 * dt * h10 + p1 * h01 + v1 * dt * h11
end

local function CalculateVelocity(lP: Vector3, lT: number, cP: Vector3, cT: number, tickrate: number?): Vector3
	tickrate = tickrate or 1 / 20
	local dt = cT - lT
	if dt <= 1e-6 then
		return Vector3.zero
	elseif dt > tickrate * 3 and Config.FLAGS.SNAPSHOT_INTERPOLATION_FIX then
		dt = tickrate
	end
	if Config.FLAGS.VELOCITY_CALC_FIX then
		dt = math.max(dt, tickrate) -- ensures that velocity is not calculated with a dt that is too small
	end
	return (cP - lP) / dt
end

local function VelocityAt(
	latest: Types.SnapshotData<CFrame, Vector3>?,
	t: number,
	cframe: CFrame,
	tickrate: number?
): Vector3
	if not latest then
		return Vector3.zero
	end
	return CalculateVelocity(latest.value.Position, latest.t, cframe.Position, t, tickrate)
end

return {
	Hermite = Hermite,
	VelocityAt = VelocityAt,
	CalculateVelocity = CalculateVelocity,
}
