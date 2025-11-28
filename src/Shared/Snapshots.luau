export type SnapshotData<Value, Velocity> = {
	t: number,
	value: Value,
	velocity: Velocity,
}

export type Snapshot<Value, Velocity> = {
	cache: { SnapshotData<Value, Velocity> },
	head: number,
	count: number,
	Lerp: (p0: Vector3, p1: Vector3, v0: Velocity, v1: Velocity, t: number, dt: number) -> Vector3,

	Push: (self: Snapshot<Value, Velocity>, t: number, value: Value, velocity: Velocity) -> (),
	GetLatest: (self: Snapshot<Value, Velocity>) -> SnapshotData<Value, Velocity>?,
	GetAt: (self: Snapshot<Value, Velocity>, t: number) -> Value?,
	Clear: (self: Snapshot<Value, Velocity>) -> (),
}

local Config = require(script.Parent.Parent.Shared.Config)

local MAX_LENGTH = 30
local SHOW_WARNINGS = Config.SHOW_WARNINGS

local function WarnIfEnabled(...)
	if SHOW_WARNINGS then
		warn(...)
	end
end

local function GetBufferIndex(head: number, relativeIndex: number): number
	return (head + relativeIndex - 2) % MAX_LENGTH + 1
end

local function BinarySearchInsertionPoint<Value, Velocity>(self: Snapshot<Value, Velocity>, timeStamp: number): number
	local count = self.count
	if count == 0 then
		return 1
	end

	local left = 1
	local right = count
	local cache = self.cache
	local head = self.head

	while left <= right do
		local mid = (left + right) // 2
		local bufferIndex = GetBufferIndex(head, mid)
		local midTime = cache[bufferIndex].t

		if midTime < timeStamp then
			left = mid + 1
		else
			right = mid - 1
		end
	end

	return left
end

local function ShiftElementsRight<Value, Velocity>(self: Snapshot<Value, Velocity>, startPos: number, endPos: number)
	local cache = self.cache
	local head = self.head

	for i = endPos, startPos, -1 do
		local fromIndex = GetBufferIndex(head, i)
		local toIndex = GetBufferIndex(head, i + 1)
		cache[toIndex] = cache[fromIndex]
	end
end

local function Push<Value, Velocity>(self: Snapshot<Value, Velocity>, timeStamp: number, value: Value, velocity: Velocity)
	local newData = { t = timeStamp, value = value, velocity = velocity }

	if self.count == 0 then
		self.cache[self.head] = newData
		self.count = 1
		return
	end

	local insertionPos = BinarySearchInsertionPoint(self, timeStamp)

	if insertionPos > self.count then
		if self.count < MAX_LENGTH then
			local newIndex = GetBufferIndex(self.head, self.count + 1)
			self.cache[newIndex] = newData
			self.count += 1
		else
			local newIndex = self.head
			self.cache[newIndex] = newData
			self.head = self.head % MAX_LENGTH + 1
		end
	else
		if self.count < MAX_LENGTH then
			ShiftElementsRight(self, insertionPos, self.count)
			local insertIndex = GetBufferIndex(self.head, insertionPos)
			self.cache[insertIndex] = newData
			self.count += 1
		else
			for i = 1, insertionPos - 1 do
				local fromIndex = GetBufferIndex(self.head, i + 1)
				local toIndex = GetBufferIndex(self.head, i)
				self.cache[toIndex] = self.cache[fromIndex]
			end
			local insertIndex = GetBufferIndex(self.head, insertionPos)
			self.cache[insertIndex] = newData
		end
	end
end

local function GetLatest<Value, Velocity>(self: Snapshot<Value, Velocity>): SnapshotData<Value, Velocity>?
	if self.count == 0 then
		return nil
	end

	local lastIndex = GetBufferIndex(self.head, self.count)
	return self.cache[lastIndex]
end

local function GetAt<Value, Velocity>(self: Snapshot<Value, Velocity>, at: number): Value?
	local count = self.count
	if count == 0 then
		return nil
	end

	if count == 1 then
		local index = GetBufferIndex(self.head, 1)
		return self.cache[index].value
	end

	local cache = self.cache
	local head = self.head
	local lerpFunction = self.Lerp

	local insertionPos = BinarySearchInsertionPoint(self, at)

	local beforePos = insertionPos - 1
	local afterPos = insertionPos

	local beforeData: SnapshotData<Value, Velocity>?
	local afterData: SnapshotData<Value, Velocity>?

	if beforePos >= 1 and beforePos <= count then
		local beforeIndex = GetBufferIndex(head, beforePos)
		beforeData = cache[beforeIndex]
	end

	if afterPos >= 1 and afterPos <= count then
		local afterIndex = GetBufferIndex(head, afterPos)
		afterData = cache[afterIndex]
	end

	if beforeData and afterData then
		local dt = afterData.t - beforeData.t
		if dt == 0 then
			return beforeData.value
		end
		local alpha = (at - beforeData.t) / dt

		local p0, p1 = (beforeData.value :: any).Position, (afterData.value :: any).Position
		local v0, v1 = beforeData.velocity, afterData.velocity

		local position = lerpFunction(p0, p1, v0, v1, alpha, dt)
		local delta = (afterData.value :: any).Rotation * (beforeData.value :: any).Rotation:Inverse()
		local axis, angle = delta:ToAxisAngle()
		local rotation = (beforeData.value :: any).Rotation * CFrame.fromAxisAngle(axis, angle * alpha)

		return CFrame.new(position) * rotation
	elseif beforeData then
		WarnIfEnabled("Tried to fetch a time that was ahead of snapshot storage!")
		return beforeData.value
	elseif afterData then
		WarnIfEnabled("Tried to fetch a time that was behind snapshot storage!")
		return afterData.value
	end

	return nil
end

local function Clear<Value, Velocity>(self: Snapshot<Value, Velocity>)
	self.head = 1
	self.count = 0
end

local function New<Value, Velocity>(
	lerpFunction: (Vector3, Vector3, Velocity, Velocity, number, number) -> Vector3
): Snapshot<Value, Velocity>
	local cache = table.create(MAX_LENGTH)
	for i = 1, MAX_LENGTH do
		cache[i] = { t = 0, value = (nil :: any) :: Value, velocity = (nil :: any) :: Velocity }
	end

	return {
		cache = cache,
		head = 1,
		count = 0,
		Lerp = lerpFunction,

		Push = Push,
		GetLatest = GetLatest,
		GetAt = GetAt,
		Clear = Clear,
	}
end

return New
