--!strict
--!native
--!optimize 2

local function duplicator(...)
	coroutine.yield()
	coroutine.yield(...)
	duplicator(coroutine.yield(...))
end

local function popper(_, ...)
	return ...
end

local function shouldpush(...)
	return (...) ~= nil or not pcall(bit32.bor, 0, ...)
end

local dthread = coroutine.create(duplicator)
local n = 0
local function dupe(...)
	n += 1
	if n >= 0xEA5A then
		local new = coroutine.create(duplicator)
		dthread = new
		n = 0
	end
	return popper(coroutine.resume(dthread, ...))
end

local function storage_fun(...)
	dupe(coroutine.yield(...))
	if shouldpush(dupe()) then
		local top = dupe()
		storage_fun(top, ...) --
	end
	dupe()
	storage_fun(...)
end

function create(...)
	local tthread = coroutine.create(storage_fun)
	local n = 0
	local function push(...)
		n += 1
		if n >= 0x4E1C then
			local new = coroutine.create(storage_fun)
			coroutine.resume(new, popper(coroutine.resume(tthread, ...)))
			tthread = new
			n = 0
		end
		return popper(coroutine.resume(tthread, ...))
	end
	push(...)
	return push
end

return function(fun: "create"): typeof(create)
	if fun == "create" then
		return create
	end
	return error("unknown prop")
end
