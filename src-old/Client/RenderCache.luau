local Config = require(script.Parent.Parent.Shared.Config)

local playerTickRates
local BufferTracker

local clientClockInfo = {} :: {
	[number]: {
		lastClockAt: number,
		lastClockDuration: number,
		renderAt: number?,
	},
}

local isNPCMap = {} :: { [number]: boolean }
local npcTypeMap = {} :: { [number]: string }

local function Init(dependencies: {
	playerTickRates: { [number]: number },
	bufferTracker: any,
})
	playerTickRates = dependencies.playerTickRates
	BufferTracker = dependencies.bufferTracker
end

local function GetBuffer(id: number): number
	if isNPCMap[id] then
		local npcType = npcTypeMap[id] or "DEFAULT"
		local npcConfig = Config.NPC_TYPES[npcType]
		if not npcConfig then
			warn(`RenderCache: No NPC config found for type {npcType}. Make sure to define it in the config`)
			npcConfig = Config.NPC_TYPES["DEFAULT"]
		end
		return npcConfig.BUFFER
	else
		return BufferTracker.GetBuffer(id, playerTickRates[id] or Config.TICK_RATE)
	end
end

local function OnSnapshotUpdate(snapshot: { [number]: number })
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
				local delay = GetBuffer(id)
				info.renderAt = currentSendTime - delay
			end
		end
	end
end

local function Update(deltaTime: number)
	local now = os.clock()

	for id, info in clientClockInfo do
		local delay = GetBuffer(id)

		--predict the current server time based on the last known tick and time difference
		--advance the render at by the delta time and calculate error from the dynamic delay
		--snap if the error is too big, fall slightly behind to correct overshoot and speed up to catch uip

		local estimatedServerTime = info.lastClockAt + (now - info.lastClockDuration)
		local renderAt = (info.renderAt or (estimatedServerTime - delay)) + deltaTime

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

local function GetTargetRenderTime(id: number): number
	local info = clientClockInfo[id]
	if not info or not info.renderAt then
		warn(`RenderCache: No render time for network ID {id}`)
		return 0
	end
	return info.renderAt
end

local function GetEstimatedServerTime(id: number): number
	local info = clientClockInfo[id]
	if not info then
		warn(`RenderCache: No estimated server time for network ID {id}`)
		return 0
	end
	return info.lastClockAt + (os.clock() - info.lastClockDuration)
end

local function Add(id: number, isNPC: boolean?, npcType: string?)
	if not clientClockInfo[id] then
		clientClockInfo[id] = {
			lastClockAt = 0,
			lastClockDuration = 0,
			renderAt = nil,
		}
	end
	isNPCMap[id] = isNPC or false
	if isNPC then
		npcTypeMap[id] = npcType or "DEFAULT"
	end
end

local function Remove(id: number)
	clientClockInfo[id] = nil
	isNPCMap[id] = nil
	npcTypeMap[id] = nil
end

return {
	Init = Init,
	GetBuffer = GetBuffer,
	OnSnapshotUpdate = OnSnapshotUpdate,
	Update = Update,
	GetTargetRenderTime = GetTargetRenderTime,
	GetEstimatedServerTime = GetEstimatedServerTime,
	Add = Add,
	Remove = Remove,
}
