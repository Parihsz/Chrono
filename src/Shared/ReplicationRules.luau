const Shared = script.Parent.Parent.Shared
const Warn = require(script.Parent.Warn)
const Types = require(Shared.Types)
const Holder = require(Shared.Holder)

export type RuleFn = (entity: Types.Entity, viewer: Player, viewerEntityId: number?) -> boolean

export type ReplicationRule = {
	filterType: "include" | "exclude",
	filterPlayers: { Player }?,
}

const ruleById = {} :: { [number]: RuleFn }

const function GetIdFrom(input: Player | Model | number | Types.Entity): number?
	if typeof(input) == "number" then
		return input
	end

	if typeof(input) == "table" then
		return (input :: Types.Entity).id
	end

	if typeof(input) ~= "Instance" then
		return nil
	end

	if input:IsA("Player") then
		const entity = Holder.GetEntityFromPlayer(input)
		return entity and entity.id or nil
	end

	if input:IsA("Model") then
		const entity = Holder.GetEntityFromModel(input)
		return entity and entity.id or nil
	end

	return nil
end

const function CompileRule(rule: ReplicationRule): RuleFn
	const filterType = rule.filterType
	const list: { Player } = rule.filterPlayers or {}
	const set = {} :: { [Player]: true }

	for _, player in list do
		set[player] = true
	end

	if filterType == "exclude" then
		if next(set) == nil then
			return function()
				return true
			end
		end

		return function(_, viewer: Player)
			return set[viewer] ~= true
		end
	else
		if next(set) == nil then
			return function()
				return false
			end
		end

		return function(_, viewer: Player)
			return set[viewer] == true
		end
	end
end

const function SetReplicationRule(
	target: Player | Model | number | Types.Entity,
	rule: ReplicationRule | RuleFn | nil
): ()
	const id = GetIdFrom(target)
	if not id then
		Warn.low("no id", target)
		return
	end

	if rule == nil then
		ruleById[id] = nil
		return
	end

	if typeof(rule) == "function" then
		ruleById[id] = rule :: any
		return
	end

	ruleById[id] = CompileRule(rule :: ReplicationRule)
end

const function Allows(entity: Types.Entity, viewer: Player): boolean
	const fn = ruleById[entity.id]
	if not fn then
		return true
	end

	const viewerEntity = Holder.GetEntityFromPlayer(viewer)
	const viewerEntityId = viewerEntity and viewerEntity.id or nil

	return fn(entity, viewer, viewerEntityId)
end

const function Include(players: { Player }): RuleFn
	return CompileRule({ filterType = "include", filterPlayers = players })
end

const function Exclude(players: { Player }): RuleFn
	return CompileRule({ filterType = "exclude", filterPlayers = players })
end

return {
	SetReplicationRule = SetReplicationRule,
	Allows = Allows,

	Include = Include,
	Exclude = Exclude,
}
