local Config = require(script.Parent.Parent.Shared.Config)
local Types = require(script.Parent.Parent.Shared.Types)

local SHOW_WARNINGS
local MIN_BUFFER
local MAX_BUFFER
local ALPHA = 0.1

Config._WaitForLock(function()
	MIN_BUFFER = Config._GetConfig("MIN_BUFFER")
	MAX_BUFFER = Config._GetConfig("MAX_BUFFER")
	SHOW_WARNINGS = Config._GetConfig("SHOW_WARNINGS")
end)
local Buffer = {}

function Buffer.new(renderCache: Types.RenderCache)
	return {
		init = false,
		averageLatency = 0,
		deviation = 0,
		lastLatency = 0,
		renderCache = renderCache,
	}
end

function Buffer.Register(data: Types.InterpolationBuffer, time: number)
	local renderCache = data.renderCache
	local clientNow = renderCache:GetEstimatedServerTime()
	local latency = clientNow - time
	if math.abs(latency) > 1 then
		renderCache:Clear()
		if SHOW_WARNINGS then
			warn(data.renderCache.name, ` latency too high, cleared cache to repredict in case of error:! {latency}`)
		end
	end
	if not data.init then
		--using the difference between current and last latency, i could smooth out the deviation (the variation in latency, which correlates to packet loss)
		--this is using statistics https://en.wikipedia.org/wiki/Moving_average
		data.averageLatency = latency
		data.deviation = 0
		data.lastLatency = latency
		data.init = true
		return
	end

	if data.lastLatency then
		local delta = math.abs(latency - data.lastLatency)
		--deviation is essentially jitter, and we calculate that using RFC 3550 jitter estimation
		--see: https://tech.ebu.ch/docs/tech/tech3337.pdf
		data.deviation = data.deviation + (delta - data.deviation) * ALPHA
	end

	data.averageLatency = data.averageLatency + (latency - data.averageLatency) * ALPHA
	data.lastLatency = latency
end

function Buffer.GetBuffer(data: Types.InterpolationBuffer, tickRate: number)
	if not data then
		return MIN_BUFFER
	end

	local deviationMargin = data.deviation * 2
	local rawBuffer = tickRate + deviationMargin

	local buffer = if rawBuffer < MIN_BUFFER then MIN_BUFFER + (MIN_BUFFER - rawBuffer) * 0.2 else rawBuffer
	if buffer > MAX_BUFFER then
		if SHOW_WARNINGS then
			warn(`Interpolation buffer exceeded max! Was {buffer}, clamped to {MAX_BUFFER} for`, data.renderCache.name)
		end
		buffer = MAX_BUFFER
	end

	return buffer
end

return Buffer
