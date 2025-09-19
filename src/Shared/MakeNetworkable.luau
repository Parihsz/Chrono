type NetworkableCFrame = {
	Position: Vector3,
	Rotation: { x: number, y: number, z: number },
}
type NetworkableYawCFrame = {
	Position: Vector3,
	RotationY: number,
}

local SERVER_TIME = workspace:GetServerTimeNow()
local RunService = game:GetService("RunService")

if RunService:IsClient() then
	script:GetAttributeChangedSignal("ServerTime"):Connect(function()
		SERVER_TIME = script:GetAttribute("ServerTime") or workspace:GetServerTimeNow()
	end)
	SERVER_TIME = script:GetAttribute("ServerTime") or SERVER_TIME
else
	script:SetAttribute("ServerTime", SERVER_TIME)
end

local function MakeNetworkable(cframe: CFrame): NetworkableCFrame
	local position = cframe.Position
	--AxisAngles very simple way to think about quaternions
	--can convert into quaternions by multiplying sine of the half angle
	local axis, angle = cframe:ToAxisAngle()

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

local function MakeYawNetworkable(cframe: CFrame): NetworkableYawCFrame
	local _, yaw, _ = cframe:ToEulerAnglesYXZ()
	return {
		Position = cframe.Position,
		RotationY = yaw,
	}
end

local function NetworkableCFrameTable(cframes: { CFrame }): { NetworkableCFrame }
	local results = {}
	for index, cframe in cframes do
		results[index] = MakeNetworkable(cframe)
	end
	return results
end

local function NetworkableYawCFrameTable(cframes: { [number]: CFrame }): { [number]: NetworkableYawCFrame }
	local results = {}
	for index, cframe in cframes do
		results[index] = MakeYawNetworkable(cframe)
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

local function DecodeYawCFrame(data: NetworkableYawCFrame): CFrame
	local position = data.Position
	local yaw = data.RotationY
	local c = math.cos(yaw)
	local s = math.sin(yaw)

	return CFrame.fromMatrix(position, Vector3.new(c, 0, -s), Vector3.new(0, 1, 0))
end

local function EncodeTime(time: number): number
	-- return time - SERVER_TIME
	return time
	--return time
end

return {
	MakeNetworkable = MakeNetworkable,
	NetworkableCFrameTable = NetworkableCFrameTable,
	DecodeCFrame = DecodeCFrame,

	NetworkableYawCFrameTable = NetworkableYawCFrameTable,
	MakeYawNetworkable = MakeYawNetworkable,
	DecodeYawCFrame = DecodeYawCFrame,

	EncodeTime = EncodeTime,
}
