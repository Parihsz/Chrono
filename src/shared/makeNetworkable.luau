type NetworkableCFrame = {
	Position: Vector3,
	Rotation: { x: number, y: number, z: number },
}

local function MakeNetworkable(CFrame: CFrame): NetworkableCFrame
	local position = CFrame.Position
	--AxisAngles very simple way to think about quaternions
	--can convert into quaternions by multiplying sine of the half angle
	local axis, angle = CFrame:ToAxisAngle()

	local halfAngle = angle * 0.5
	local sinHalf = math.sin(halfAngle)

	local x = axis.X * sinHalf
	local y = axis.Y * sinHalf
	local z = axis.Z * sinHalf

	return {
		Position = position,
		Rotation = { x = x, y = y, z = z },
	}
end

local function NetworkableCFrameTable(CFrames: { CFrame }): { NetworkableCFrame }
	local results = {}
	for index, CFrame in CFrames do
		local position = CFrame.Position
		local axis, angle = CFrame:ToAxisAngle()

		local halfAngle = angle * 0.5
		local sinHalf = math.sin(halfAngle)
		local x = axis.X * sinHalf
		local y = axis.Y * sinHalf
		local z = axis.Z * sinHalf

		results[index] = {
			Position = position,
			Rotation = { x = x, y = y, z = z },
		}
	end
	return results
end

local function DecodeCFrame(data: NetworkableCFrame): CFrame
	local position = data.Position
	local rotation = data.Rotation

	local x, y, z = rotation.x, rotation.y, rotation.z
	local wSquared = 1 - x * x - y * y - z * z
	local w = if wSquared > 0 then math.sqrt(wSquared) else 0

	return CFrame.new(position.X, position.Y, position.Z, x, y, z, w)
end

return {
	MakeNetworkable = MakeNetworkable,
	NetworkableCFrameTable = NetworkableCFrameTable,
	DecodeCFrame = DecodeCFrame
}
