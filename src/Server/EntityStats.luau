const Shared = script.Parent.Parent.Shared

const Types = require(Shared.Types)
const Entity = require(Shared.Entity)
const Holder = require(Shared.Holder)
const Stats = require(Shared.Stats).SERVER

const idMap = Holder.idMap

const function UpdateEntityStats()
	const hasOwned = Stats._SHOULD_REPLICATE
	if not hasOwned then
		Stats.SERVER_ENTITIES = {}
		return
	end
	const entities: { Types.ServerEntitiesStats } = {}

	for _, entity in idMap do
		const networkOwner = entity.networkOwner
		const isCharacter = entity._player ~= nil
		const config = entity.entityConfig
		const configName = config and config.NAME or "DEFAULT"
		const configTickRate = 1 / config.TICK_RATE
		const isHalfTicked = entity.isHalfTicked
		local tickRate = configTickRate
		const lastPosition = entity.latestCFrame and entity.latestCFrame.Position or nil
		if isHalfTicked == true then
			tickRate = tickRate / 2
		elseif isHalfTicked == nil then
			tickRate = 0
		end
		tickRate //= 1
		if tickRate ~= tickRate or tickRate == math.huge then
			tickRate = 0
		end
		const lastTicked = entity.latestTime
		const interpolationMode: Types.INTERPOLATION_MODE = entity._interpolationMode
			or entity.entityConfig.INTERPOLATION_MODE
			or "CFRAME"
		const data = {
			isPaused = entity.paused,
			id = entity.id,
			networkOwner = networkOwner,
			isCharacter = isCharacter,
			config = configName,
			tickRate = tickRate,
			lastTicked = lastTicked,
			lastPosition = lastPosition,
			modelType = Entity.GetModelReplicationType(entity),
			interpolationMode = interpolationMode,
		}
		table.insert(entities, data)
	end
	Stats.SERVER_ENTITIES = entities
end

return UpdateEntityStats
