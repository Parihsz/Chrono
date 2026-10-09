const Shared = script.Parent.Parent.Shared

const ClientClock = require(script.Parent.ClientClock)
const StatsALL = require(Shared.Stats)
const Entity = require(Shared.Entity)
const Holder = require(Shared.Holder)
const Stats = StatsALL.CLIENT

const idMap = Holder.idMap


const function UpdateEntityStats()
	if not StatsALL.SERVER._SHOULD_REPLICATE or Stats._PAUSE then
		return
	end
	const entities = {}
	for _, entity in idMap do
		const id = entity.id
		const config = entity.entityConfig
		const configName = config and config.NAME or "DEFAULT"
		const networkOwner = entity.networkOwner
		const isCharacter = entity._player ~= nil

		const lastRecvTime = entity.latestTime or 0
		const lastReplicatedTime = entity.lastReplicatedTime or 0

		local renderCache = entity._clientClock

		if not renderCache then
			const RenderCaches = entity.entityConfig.CLIENT_CLOCK
			if RenderCaches then
				renderCache = entity.isHalfTicked and RenderCaches.HALF or RenderCaches.NORMAL
			end
		end

		local targetRender = 0
		local averageLatency = 0
		local deviation = 0
		local bufferedTime = 0

		if renderCache then
			targetRender = renderCache:GetTargetRenderTime()
			const interpolationBuff = renderCache.buffer
			if interpolationBuff then
				averageLatency = interpolationBuff.averageLatency
				deviation = interpolationBuff.deviation
			end
			bufferedTime = ClientClock._getBuffer(renderCache)
		end
		const primaryPart = Entity.GetPrimaryPart(entity)
		const snapshot = entity.snapshot
		const currentPosition = primaryPart and primaryPart.Position
		const snapshots = {}
		if snapshot then
			for _, snap in snapshot.cache do
				table.insert(snapshots, { t = snap.t, value = snap.value, velocity = snap.velocity })
			end
			table.sort(snapshots, function(a, b)
				return a.t > b.t
			end)
		end
		const data = {
			id = id,
			entity = entity,
			networkOwner = networkOwner,
			isCharacter = isCharacter,
			config = configName,
			lastReceivedTime = lastRecvTime,
			lastReplicatedTime = lastReplicatedTime,
			targetTime = targetRender,
			averageLatency = averageLatency,
			deviation = deviation,
			bufferedTime = bufferedTime,
			currentPosition = currentPosition,
			snapshots = snapshots,
		}
		table.insert(entities, data)
	end
	Stats.CLIENT_ENTITIES = entities :: any
end

return UpdateEntityStats
