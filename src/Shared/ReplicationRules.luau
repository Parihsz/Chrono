local Shared = script.Parent.Parent.Shared
local Types = require(Shared.Types)
local Holder = require(Shared.Holder)

export type RuleFn = (entity: Types.Entity, viewer: Player, viewerEntityId: number?) -> boolean

export type ReplicationRule = {
	filterType: "include" | "exclude",
	filterPlayers: { Player }?,
}

local ruleById = {} :: { [number]: RuleFn }

local function GetIdFrom(input: Player | Model | number | Types.Entity): number?
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
		local entity = Holder.GetEntityFromPlayer(input)
		return entity and entity.id or nil
	end

	if input:IsA("Model") then
		local entity = Holder.GetEntityFromModel(input)
		return entity and entity.id or nil
	end

	return nil
end

local function CompileRule(rule: ReplicationRule): RuleFn
	local filterType = rule.filterType
	local list: { Player } = rule.filterPlayers or {}
	local set = {} :: { [Player]: true }

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

local function SetReplicationRule(
	target: Player | Model | number | Types.Entity,
	rule: ReplicationRule | RuleFn | nil
): ()
	local id = GetIdFrom(target)
	if not id then
		warn("no id", target)
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

local function Allows(entity: Types.Entity, viewer: Player): boolean
	local fn = ruleById[entity.id]
	if not fn then
		return true
	end

	local viewerEntity = Holder.GetEntityFromPlayer(viewer)
	local viewerEntityId = viewerEntity and viewerEntity.id or nil

	return fn(entity, viewer, viewerEntityId)
end

local function Include(players: { Player }): RuleFn
	return CompileRule({ filterType = "include", filterPlayers = players })
end

local function Exclude(players: { Player }): RuleFn
	return CompileRule({ filterType = "exclude", filterPlayers = players })
end

return {
	SetReplicationRule = SetReplicationRule,
	Allows = Allows,

	Include = Include,
	Exclude = Exclude,
}
