--!native

const Types = require(script.Parent.Types)

type SnapshotData<Value, Velocity> = Types.SnapshotData<Value, Velocity>

type Snapshot<Value, Velocity> = Types.Snapshot<Value, Velocity>

const Config = require(script.Parent.Config)
const InterpolationMath = require(script.Parent.InterpolationMath)
const Warn = require(script.Parent.Warn)

local MAX_LENGTH: number
const PEAK_SPEED_DECAY = 0.98

Config._WaitForLock(function()
	MAX_LENGTH = Config._GetConfig("MAX_SNAPSHOT_COUNT")
end)

const function GetBufferIndex(head: number, relativeIndex: number): number
	return (head + relativeIndex - 2) % MAX_LENGTH + 1
end

const function BinarySearchInsertionPoint<Value, Velocity>(self: Snapshot<Value, Velocity>, timeStamp: number): number
	const count = self.count
	if count == 0 then
		return 1
	end

	local left = 1
	local right = count
	const cache = self.cache
	const head = self.head

	while left <= right do
		const mid = (left + right) // 2
		const bufferIndex = GetBufferIndex(head, mid)
		const midTime = cache[bufferIndex].t

		if midTime < timeStamp then
			left = mid + 1
		else
			right = mid - 1
		end
	end

	return left
end

const function ShiftElementsRight<Value, Velocity>(self: Snapshot<Value, Velocity>, startPos: number, endPos: number)
	const cache = self.cache
	const head = self.head

	for i = endPos, startPos, -1 do
		const fromIndex = GetBufferIndex(head, i)
		const toIndex = GetBufferIndex(head, i + 1)
		cache[toIndex] = cache[fromIndex]
	end
end

const function GetLatest<Value, Velocity>(self: Snapshot<Value, Velocity>): SnapshotData<Value, Velocity>?
	if self.count == 0 then
		return nil
	end

	const lastIndex = GetBufferIndex(self.head, self.count)
	return self.cache[lastIndex]
end

const function Push<Value, Velocity>(self: Snapshot<Value, Velocity>, timeStamp: number, value: Value, velocity: Velocity)
	const newData = { t = timeStamp, value = value, velocity = velocity }

	if self.count == 0 then
		self.cache[self.head] = newData
		self.count = 1
		return
	end

	const insertionPos = BinarySearchInsertionPoint(self, timeStamp)

	if insertionPos > self.count then
		if self.count < MAX_LENGTH then
			const newIndex = GetBufferIndex(self.head, self.count + 1)
			self.cache[newIndex] = newData
			self.count += 1
		else
			const newIndex = self.head
			self.cache[newIndex] = newData
			self.head = self.head % MAX_LENGTH + 1
		end
	else
		if self.count < MAX_LENGTH then
			ShiftElementsRight(self, insertionPos, self.count)
			const insertIndex = GetBufferIndex(self.head, insertionPos)
			self.cache[insertIndex] = newData
			self.count += 1
		else
			if insertionPos == 1 then
				return
			end
			for i = 1, insertionPos - 2 do
				const fromIndex = GetBufferIndex(self.head, i + 1)
				const toIndex = GetBufferIndex(self.head, i)
				self.cache[toIndex] = self.cache[fromIndex]
			end
			const insertIndex = GetBufferIndex(self.head, insertionPos - 1)
			self.cache[insertIndex] = newData
		end
	end
end

const function PushWithCheck<Value, Velocity>(
	self: Snapshot<Value, Velocity>,
	timeStamp: number,
	value: Value,
	velocity: Velocity?,
	tickrate: number,
	stopped: boolean?
)
	const latestData = GetLatest(self)
	const isNewest = not latestData or timeStamp > latestData.t
	if stopped then
		Push(self, timeStamp, value, vector.zero :: any)
		if isNewest then
			self.stoppedAt = timeStamp
		end
		return
	end

	const position = (value :: any).Position
	local teleported = false
	if latestData and isNewest and latestData.t == self.stoppedAt then
		const moved = vector.magnitude(position - (latestData.value :: any).Position)
		const gap = timeStamp - latestData.t
		const travelTime = if self.peakSpeed > 1e-3 then moved / self.peakSpeed else 0

		teleported = travelTime > tickrate * 5
		const startAt = timeStamp - (if teleported then tickrate else math.max(tickrate, travelTime))
		if startAt > latestData.t and gap > tickrate * 1.5 then
			Push(self, startAt, latestData.value, vector.zero :: any)
		end
	elseif
		latestData and InterpolationMath.CheckIdle(latestData :: any, timeStamp, position, tickrate, self.peakSpeed)
	then
		latestData.velocity = vector.zero :: any
		Push(self, timeStamp - tickrate, latestData.value, vector.zero :: any)
	end
	if isNewest then
		self.stoppedAt = nil
	end

	const pushVelocity: Velocity = velocity
		or InterpolationMath.VelocityAt(GetLatest(self) :: any, timeStamp, value :: any, tickrate, self.peakSpeed) :: any

	Push(self, timeStamp, value, pushVelocity)
	if not teleported then
		self.peakSpeed = math.max(vector.magnitude(pushVelocity :: any), self.peakSpeed * PEAK_SPEED_DECAY)
	end
end

const function GetAt<Value, Velocity>(self: Snapshot<Value, Velocity>, at: number, bypassLock: boolean?): Value?
	const count = self.count
	if count == 0 then
		return nil
	end

	if count == 1 then
		const index = GetBufferIndex(self.head, 1)
		return self.cache[index].value
	end

	if at < 0 then
		const latest = GetLatest(self)
		return latest and latest.value or nil
	end

	const cache = self.cache
	const head = self.head
	const lerpFunction = self.Lerp
	const lockedTime = self.lockedTime

	if at < lockedTime and not bypassLock then
		at = lockedTime
	end

	const insertionPos = BinarySearchInsertionPoint(self, at)

	const beforePos = insertionPos - 1
	const afterPos = insertionPos

	local beforeData: SnapshotData<Value, Velocity>?
	local afterData: SnapshotData<Value, Velocity>?

	if beforePos >= 1 and beforePos <= count then
		const beforeIndex = GetBufferIndex(head, beforePos)
		beforeData = cache[beforeIndex]
	end

	if afterPos >= 1 and afterPos <= count then
		const afterIndex = GetBufferIndex(head, afterPos)
		afterData = cache[afterIndex]
	end

	if beforeData and afterData then
		const dt = afterData.t - beforeData.t
		if dt == 0 then
			return beforeData.value
		end
		const alpha = (at - beforeData.t) / dt

		const p0, p1 = (beforeData.value :: any).Position, (afterData.value :: any).Position
		const v0, v1 = beforeData.velocity, afterData.velocity

		const position = lerpFunction(p0, p1, v0, v1, alpha, dt)
		const cf = (beforeData.value :: any):Lerp(afterData.value, alpha)

		return CFrame.new(position) * cf.Rotation
	elseif beforeData then
		Warn.low("Tried to fetch a time that was ahead of snapshot storage!")
		return beforeData.value
	elseif afterData then
		Warn.low("Tried to fetch a time that was behind snapshot storage!")
		return afterData.value
	end

	return nil
end

const function Clear<Value, Velocity>(self: Snapshot<Value, Velocity>)
	self.head = 1
	self.count = 0
	self.lockedTime = 0
	self.peakSpeed = 0
	self.stoppedAt = nil
end

const function New<Value, Velocity>(
	lerpFunction: (Vector3, Vector3, Velocity, Velocity, number, number) -> Vector3
): Snapshot<Value, Velocity>
	const cache: { SnapshotData<Value, Velocity> } = table.create(MAX_LENGTH) :: any
	for i = 1, MAX_LENGTH do
		cache[i] = { t = 0, value = (nil :: any) :: Value, velocity = (nil :: any) :: Velocity }
	end

	return {
		cache = cache,
		head = 1,
		count = 0,
		lockedTime = 0,
		peakSpeed = 0,
		Lerp = lerpFunction,

		Push = Push,
		PushWithCheck = PushWithCheck,
		GetLatest = GetLatest,
		GetAt = GetAt,
		Clear = Clear,
	}
end

return New
