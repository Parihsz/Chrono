local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.config)

local playerTickRates
local BufferTracker

local clientClockInfo = {} :: {
	[number]: {
		lastClockAt: number,
		lastClockDuration: number,
		renderAt: number?,
	},
}

local RenderCache = {}

function RenderCache.Init(dependencies: {
	playerTickRates: { [number]: number },
	bufferTracker: any,
})
	playerTickRates = dependencies.playerTickRates
	BufferTracker = dependencies.bufferTracker
end

function RenderCache.OnSnapshotUpdate(snapshot: { [number]: number })
	local now = os.clock()

	for id, currentSendTime in snapshot do
		local info = clientClockInfo[id]

		if not info then
			info = {
				lastClockAt = currentSendTime,
				lastClockDuration = now,
				renderAt = nil,
			}
			clientClockInfo[id] = info
		end

		if currentSendTime > info.lastClockAt then
			info.lastClockAt = currentSendTime
			info.lastClockDuration = now

			if not info.renderAt then
				local delay = BufferTracker.GetBuffer(id, playerTickRates[id] or Config.TICK_RATE)
				info.renderAt = currentSendTime - delay
			end
		end
	end
end

function RenderCache.Update(deltaTime: number)
	local now = os.clock()

	for id, info in clientClockInfo do
		local tickRate = playerTickRates[id] or Config.TICK_RATE
		local delay = BufferTracker.GetBuffer(id, tickRate)

		--predict the current server time based on the last known tick and time difference
		--advance the render at by the delta time and calculate error from the dynamic delay
		--snap if the error is too big, fall slightly behind to correct overshoot and speed up to catch uip

		local estimatedServerTime = info.lastClockAt + (now - info.lastClockDuration)
		local renderAt = (info.renderAt or 0) + deltaTime

		local renderTimeError = delay - (estimatedServerTime - renderAt)

		if math.abs(renderTimeError) > 0.1 then
			renderAt = estimatedServerTime - delay
		elseif renderTimeError > 0.01 then
			renderAt = math.max(estimatedServerTime - delay, renderAt - 0.1 * deltaTime)
		elseif renderTimeError < -0.01 then
			renderAt = math.min(estimatedServerTime - delay, renderAt + 0.1 * deltaTime)
		end

		info.renderAt = renderAt
	end
end

function RenderCache.GetTargetRenderTime(id: number): number
	local info = clientClockInfo[id]
	if not info or not info.renderAt then
		warn(`RenderCache: No render time for network ID {id}`)
		return 0
	end
	return info.renderAt
end

function RenderCache.Add(id: number)
	if not clientClockInfo[id] then
		clientClockInfo[id] = {
			lastClockAt = 0,
			lastClockDuration = 0,
			renderAt = nil,
		}
	end
end

function RenderCache.Remove(id: number)
	clientClockInfo[id] = nil
end

return RenderCache
