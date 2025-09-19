local RunService = game:GetService("RunService")
export type SnapshotData<T> = {
	t: number,
	value: T,
}

export type Snapshot<T> = {
	cache: { SnapshotData<T> },
	lerp: (T, T, number) -> T,

	Push: (self: Snapshot<T>, t: number, value: T) -> (),
	GetLatest: (self: Snapshot<T>) -> SnapshotData<T>?,
	GetAt: (self: Snapshot<T>, t: number) -> T?,
	Clear: (self: Snapshot<T>) -> (),
}

local Config = require(script.Parent.Parent.Shared.Config)

local MAX_LENGTH = 30
local SHOW_WARNINGS = Config.SHOW_WARNINGS

local warn = function(...)
	if SHOW_WARNINGS then
		warn(...)
	end
end

-- for lune test
local function Search(cache: { SnapshotData<any> }, timeStamp: number): number
	for i, v in cache do
		if v.t >= timeStamp then
			return i
		end
	end
	return #cache + 1
end

local function Push<T>(self: Snapshot<T>, timeStamp: number, value: T): ()
	local cache = self.cache
	local index = Search(cache, timeStamp)
	table.insert(cache, index, { t = timeStamp, value = value })
	if #cache > MAX_LENGTH then
		table.remove(cache, 1)
	end
end

local function GetLatest<T>(self: Snapshot<T>): SnapshotData<T>?
	local cache = self.cache
	if #cache > 0 then
		return cache[#cache]
	end
	return nil
end

local function GetBefore<T>(self: Snapshot<T>, before: number): SnapshotData<T>?
	local cache = self.cache
	for i = #cache, 1, -1 do
		if cache[i].t < before then
			return cache[i]
		end
	end
	return nil
end

local function GetAfter<T>(self: Snapshot<T>, after: number): SnapshotData<T>?
	local cache = self.cache
	for i = 1, #cache do
		if cache[i].t >= after then
			return cache[i]
		end
	end
	return nil
end

local function GetAt<T>(self: Snapshot<T>, at: number): T?
	local cache = self.cache
	if #cache == 0 then
		return nil
	end
	if #cache == 1 then
		return cache[1].value
	end

	local lerp = self.lerp

	local before = GetBefore(self, at)
	local after = GetAfter(self, at)

	if before and after then
		local alpha = (at - before.t) / (after.t - before.t)
		return lerp(before.value, after.value, alpha)
	elseif before then
		warn("Tried to fetch a time that was ahead of snapshot storage!")
		return before.value
	elseif after then
		warn("Tried to fetch a time that was behind  snapshot storage!")
		return after.value
	end

	return nil
end

local function Clear(self: Snapshot<any>): ()
	self.cache = {}
end

local function new<T>(lerp: (T, T, number) -> T): Snapshot<T>
	return {
		cache = {},
		lerp = lerp,

		Push = Push,
		GetLatest = GetLatest,
		GetAt = GetAt,
		Clear = Clear,
	}
end

return new
