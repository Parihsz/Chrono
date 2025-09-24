local RenderCache = require(script.Parent.RenderCache)
local Config = require(script.Parent.Parent.Shared.Config)

return function(minBuffer: number, maxBuffer: number, alpha: number)
	--average latency will be the average RTT between the client & server
	local playerLatencies = {} :: { [number]: { averageLatency: number, deviation: number, lastLatency: number? } }
	local fix = 0.2
	local recovery = 0.5

	local function RegisterPacket(networkId: number, serverTime: number, tickRate: number)
		local clientNow = RenderCache.GetEstimatedServerTime(networkId)
		local latency = clientNow - serverTime
		if latency > 1 then
			playerLatencies[networkId] = nil
			RenderCache.Remove(networkId)
			RenderCache.Add(networkId)

			if Config.SHOW_WARNINGS then
				warn(`{networkId} latency too high, cleared cache to repredict in case of error:! {latency}`)
			end
		end
		if not playerLatencies[networkId] then
			--using the difference between current and last latency, i could smooth out the deviation (the variation in latency, which correlates to packet loss)
			--this is using statistics https://en.wikipedia.org/wiki/Moving_average
			playerLatencies[networkId] = { averageLatency = latency, deviation = 0, lastLatency = latency }
			return
		end

		local data = playerLatencies[networkId]
		if data.lastLatency then
			local delta = math.abs(latency - data.lastLatency)
			data.deviation = data.deviation * (1 - fix) + delta * fix
		end

		data.averageLatency = data.averageLatency * (1 - alpha) + latency * alpha
		data.lastLatency = latency
	end

	local function GetBuffer(networkId: number, tickRate: number)
		--calculate the interpolation buffer that accounts for expected latency, possible deviations and recovery from delays
		--the buffer will be per player
		local data = playerLatencies[networkId]
		if not data then
			return minBuffer
		end

		local recoveryMargin = tickRate * recovery
		local rawBuffer = data.averageLatency + data.deviation + recoveryMargin

		local buffer = if rawBuffer < minBuffer then minBuffer + (minBuffer - rawBuffer) * 0.2 else rawBuffer
		if buffer > maxBuffer then
			if Config.SHOW_WARNINGS then
				warn(`Interpolation buffer exceeded max! Was {buffer}, clamped to {maxBuffer}`)
			end
			buffer = maxBuffer
		end

		return buffer
	end

	local function Remove(id: number)
		playerLatencies[id] = nil
		RenderCache.Remove(id)
	end

	local function Clear(id)
		playerLatencies[id] = nil
		RenderCache.Remove(id)
		RenderCache.Add(id)
	end

	return {
		RegisterPacket = RegisterPacket,
		GetBuffer = GetBuffer,
		Remove = Remove,
		PlayerLatencies = playerLatencies,
		Clear = Clear,
	}
end
