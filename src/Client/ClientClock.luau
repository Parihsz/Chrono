local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.Shared.Config)
local Types = require(script.Parent.Parent.Shared.Types)
local BufferTracker = require(script.Parent.InterpolationBuffer)

local ClientClocks = {}

local SHOW_WARNINGS
Config._WaitForLock(function()
	SHOW_WARNINGS = Config._GetConfig("SHOW_WARNINGS")
end)

local function GetBuffer(clientClock: Types.ClientClock): number
	if clientClock.buffer then
		return BufferTracker.GetBuffer(clientClock.buffer, clientClock.tickRate)
	else
		return clientClock.bufferConst or 0
	end
end

local function Clear(clientClock: Types.ClientClock)
	clientClock.lastClockAt = nil
	clientClock.lastClockDuration = 0
	clientClock.renderAt = nil

	if clientClock.buffer then
		clientClock.buffer.init = false
	end
end

local function GetTargetRenderTime(clientClock: Types.ClientClock): number
	if not clientClock.renderAt then
		if SHOW_WARNINGS then
			warn("ClientClock: Render time not yet established for", clientClock.name)
		end
		return 0
	end

	return clientClock.renderAt
end

local function GetEstimatedServerTime(clientClock: Types.ClientClock): number
	if not clientClock.lastClockAt then
		if SHOW_WARNINGS then
			warn("ClientClock: Estimated server time not yet established for", clientClock.name)
		end
		return 0
	end

	return clientClock.lastClockAt + (os.clock() - clientClock.lastClockDuration)
end

local function OnSnapShot(clientClock: Types.ClientClock, currentSendTime: number)
	local now = os.clock()
	if clientClock.buffer then
		BufferTracker.Register(clientClock.buffer, currentSendTime)
	end

	if not clientClock.lastClockAt then
		clientClock.lastClockAt = currentSendTime
		clientClock.lastClockDuration = now
		clientClock.renderAt = nil
		return
	end

	if currentSendTime > clientClock.lastClockAt then
		clientClock.lastClockAt = currentSendTime
		clientClock.lastClockDuration = now

		if not clientClock.renderAt then
			local delay = GetBuffer(clientClock)
			clientClock.renderAt = currentSendTime - delay
		end
	end
end

local function SetTickRate(clientClock: Types.ClientClock, tickRate: number)
	if clientClock.tickRate == tickRate then
		return
	end
	clientClock.tickRate = tickRate
	--//Do something here maybe?
end

local function Destroy(clientClock: Types.ClientClock)
	ClientClocks[clientClock] = nil
end

local function Update(clientClock: Types.ClientClock, dt: number)
	local now = os.clock()
	local delay = GetBuffer(clientClock)
	if not clientClock.lastClockAt then
		return
	end
	local estimatedServerTime = clientClock.lastClockAt + (now - clientClock.lastClockDuration)
	local renderAt = (clientClock.renderAt or (estimatedServerTime - delay)) + dt

	local renderTimeError = delay - (estimatedServerTime - renderAt)

	if math.abs(renderTimeError) > 0.1 then
		renderAt = estimatedServerTime - delay
	elseif renderTimeError > 0.01 then
		renderAt = math.max(estimatedServerTime - delay, renderAt - 0.1 * dt)
	elseif renderTimeError < -0.01 then
		renderAt = math.min(estimatedServerTime - delay, renderAt + 0.1 * dt)
	end

	clientClock.renderAt = renderAt
end

local function new(tickRate: number, name: string, bufferNumber: number?): Types.ClientClock
	local self: Types.ClientClock = {
		name = name,
		lastClockAt = nil,
		lastClockDuration = 0,
		renderAt = nil,
		tickRate = tickRate,
		_baseTickRate = tickRate,
		buffer = nil,
		bufferConst = bufferNumber,

		OnSnapShot = OnSnapShot,
		GetEstimatedServerTime = GetEstimatedServerTime,
		GetTargetRenderTime = GetTargetRenderTime,
		Clear = Clear,
		SetTickRate = SetTickRate,
		Destroy = Destroy,
	}
	if not bufferNumber then
		self.buffer = BufferTracker.new(self)
	end

	ClientClocks[self] = true
	return self
end

local function UpdateAll(dt: number)
	for clientClock, _ in ClientClocks do
		Update(clientClock, dt)
	end
end

Config._WaitForLock(function()
	if RunService:IsServer() then
		return
	end
	for name, config in Config._EntityConfigs do
		local clientClocks = config.CLIENT_CLOCK
		if not clientClocks then
			warn(name, "is missing client clocks")
			return
		end
		clientClocks.NORMAL = new(config.TICK_RATE, name .. "_NORMAL", config.BUFFER)
		if config.HALF_TICK_DISTANCE < math.huge then
			clientClocks.HALF = new(config.TICK_RATE * 2, name .. "_HALF", config.BUFFER)
		end
	end
end)

return {
	_getBuffer = GetBuffer,
	new = new,
	clientClocks = ClientClocks,
	UpdateAll = UpdateAll,
}
