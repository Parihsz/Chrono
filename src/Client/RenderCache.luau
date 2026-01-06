local Config = require(script.Parent.Parent.Shared.Config)
local Types = require(script.Parent.Parent.Shared.Types)
local BufferTracker = require(script.Parent.InterpolationBuffer)

local RenderCaches = {}

local SHOW_WARNINGS
Config._WaitForLock(function()
	SHOW_WARNINGS = Config._GetConfig("SHOW_WARNINGS")
end)

local function GetBuffer(renderCache: Types.RenderCache): number
	if renderCache.buffer then
		return BufferTracker.GetBuffer(renderCache.buffer, renderCache.tickRate)
	else
		return renderCache.bufferConst or 0
	end
end

local function Clear(renderCache: Types.RenderCache)
	renderCache.lastClockAt = nil
	renderCache.lastClockDuration = 0
	renderCache.renderAt = nil
	if renderCache.buffer then
		renderCache.buffer.init = false
	end
end

local function GetTargetRenderTime(renderCache: Types.RenderCache): number
	if not renderCache.renderAt then
		if SHOW_WARNINGS then
			warn("RenderCache: Render time not yet established for", renderCache.name)
		end
		return 0
	end
	return renderCache.renderAt
end

local function GetEstimatedServerTime(renderCache: Types.RenderCache): number
	if not renderCache.lastClockAt then
		if SHOW_WARNINGS then
			warn("RenderCache: Estimated server time not yet established for", renderCache.name)
		end
		return 0
	end
	return renderCache.lastClockAt + (os.clock() - renderCache.lastClockDuration)
end

local function OnSnapShot(renderCache: Types.RenderCache, currentSendTime: number)
	local now = os.clock()
	if renderCache.buffer then
		BufferTracker.Register(renderCache.buffer, currentSendTime)
	end
	if not renderCache.lastClockAt then
		renderCache.lastClockAt = currentSendTime
		renderCache.lastClockDuration = now
		renderCache.renderAt = nil
		return
	end
	if currentSendTime > renderCache.lastClockAt then
		renderCache.lastClockAt = currentSendTime
		renderCache.lastClockDuration = now

		if not renderCache.renderAt then
			local delay = GetBuffer(renderCache)
			renderCache.renderAt = currentSendTime - delay
		end
	end
end

local function SetTickRate(renderCache: Types.RenderCache, tickRate: number)
	if renderCache.tickRate == tickRate then
		return
	end
	renderCache.tickRate = tickRate
	--//Do something here maybe?
end

local function Destroy(renderCache: Types.RenderCache)
	RenderCaches[renderCache] = nil
end

local function Update(renderCache: Types.RenderCache, dt: number)
	local now = os.clock()
	local delay = GetBuffer(renderCache)
	if not renderCache.lastClockAt then
		return
	end
	local estimatedServerTime = renderCache.lastClockAt + (now - renderCache.lastClockDuration)
	local renderAt = (renderCache.renderAt or (estimatedServerTime - delay)) + dt

	local renderTimeError = delay - (estimatedServerTime - renderAt)

	if math.abs(renderTimeError) > 0.1 then
		renderAt = estimatedServerTime - delay
	elseif renderTimeError > 0.01 then
		renderAt = math.max(estimatedServerTime - delay, renderAt - 0.1 * dt)
	elseif renderTimeError < -0.01 then
		renderAt = math.min(estimatedServerTime - delay, renderAt + 0.1 * dt)
	end

	renderCache.renderAt = renderAt
end

local function new(tickRate: number, name: string, bufferNumber: number?): Types.RenderCache
	local self = {
		name = name,
		lastClockAt = nil,
		lastClockDuration = 0,
		renderAt = nil,
		tickRate = tickRate,
		_baseTickRate = tickRate,
		OnSnapShot = OnSnapShot,
		GetEstimatedServerTime = GetEstimatedServerTime,
		GetTargetRenderTime = GetTargetRenderTime,
		Clear = Clear,
		SetTickRate = SetTickRate,
		Destroy = Destroy,
	}
	if not bufferNumber then
		self.buffer = BufferTracker.new(self)
	else
		self.bufferConst = bufferNumber
	end
	RenderCaches[self] = true
	return self
end

local function UpdateAll(dt: number)
	for renderCache, _ in RenderCaches do
		Update(renderCache, dt)
	end
end

Config._WaitForLock(function()
	for name, config in Config._EntityConfigs do
		local renderCaches = config.RENDER_CACHE
		if not renderCaches then
			warn(name, "is missing render caches")
			return
		end
		renderCaches.NORMAL = new(config.TICK_RATE, name .. "_NORMAL", config.BUFFER)
		if config.HALF_TICK_DISTANCE < math.huge then
			renderCaches.HALF = new(config.TICK_RATE * 2, name .. "_HALF", config.BUFFER)
		end
	end
end)

return {
	new = new,
	renderCaches = RenderCaches,
	UpdateAll = UpdateAll,
}
