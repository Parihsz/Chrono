--!native
local Entity = require(script.Parent.Entity)
local Holder = require(script.Parent.Holder)
local Types = require(script.Parent.Types)
local FastStack = require(script.Parent.FastStackPlus)
local new = FastStack("create")

local timestamp = 0
local visited = {} :: { [Types.Entity]: number }
local dp = {} :: { [Types.Entity]: number }
local world = {} :: { [Types.Entity]: CFrame }

local function ResolveWorldCFrame(entity: Types.Entity): CFrame
	local currentTime = timestamp
	if dp[entity] == currentTime then
		return world[entity]
	end

	local path = new()
	local current = entity
	local rootCFrame = CFrame.identity

	while true do
		if dp[current] == currentTime then
			rootCFrame = world[current]
			break
		end

		if visited[current] == currentTime then
			--cycle detected
			rootCFrame = Entity.GetAt(current, Entity.GetTargetRenderTime(current))
				or current.latestCFrame
				or CFrame.identity
			dp[current] = currentTime
			world[current] = rootCFrame
			break
		end

		visited[current] = currentTime

		local parentId = current.mountParentId
		if not parentId then
			rootCFrame = Entity.GetAt(current, Entity.GetTargetRenderTime(current))
				or current.latestCFrame
				or CFrame.identity
			dp[current] = currentTime
			world[current] = rootCFrame
			break
		end

		local parent = Holder.GetEntityFromId(parentId)
		if not parent or parent.destroyed then
			rootCFrame = Entity.GetAt(current, Entity.GetTargetRenderTime(current))
				or current.latestCFrame
				or CFrame.identity
			dp[current] = currentTime
			world[current] = rootCFrame
			break
		end

		path(current)
		current = parent
	end

	local out = rootCFrame or CFrame.identity
	local packed = table.pack(path())
	for i = 1, packed.n do
		local child = packed[i] :: Types.Entity
		out = out * (child.mountOffset or CFrame.identity)
		dp[child] = currentTime
		world[child] = out
	end

	if dp[entity] ~= currentTime then
		dp[entity] = currentTime
		world[entity] = out
	end

	return world[entity]
end

return function()
	timestamp += 1
	for _, entity: Types.Entity in Holder.idMap do
		if entity.destroyed then
			continue
		end
		if not entity.mountParentId then
			continue
		end

		local newCFrame = ResolveWorldCFrame(entity)
		Entity._SetPartCFrame(entity, newCFrame)
	end
end
