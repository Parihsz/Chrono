local Snapshots = require(script.Parent.Snapshots)

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

local function VelocityAt(latest: Snapshots.SnapshotData<CFrame, Vector3>?, t: number, cframe: CFrame): Vector3
	if not latest then
		return Vector3.zero
	end
	local dt = t - latest.t
	if dt <= 1e-6 then
		return Vector3.zero
	end
	return (cframe.Position - latest.value.Position) / dt
end

return {
	Hermite = Hermite,
	VelocityAt = VelocityAt,
}
