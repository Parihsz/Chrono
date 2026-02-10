--!native
local Entity = require(script.Parent.Entity)
local Holder = require(script.Parent.Holder)
local Types = require(script.Parent.Types)

local timestamp = 0
local visited = {} :: { [Types.Entity]: number }
local dp = {} :: { [Types.Entity]: number }
local world = {} :: { [Types.Entity]: CFrame }

local path = {} :: { Types.Entity }

local function ResolveWorldCFrame(entity: Types.Entity): CFrame
	local currentTime = timestamp
	if dp[entity] == currentTime then
		return world[entity]
	end

	local n = 0
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
			Entity._SetPartCFrame(current, rootCFrame)
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
			Entity._SetPartCFrame(current, rootCFrame)
			break
		end

		local parent = Holder.GetEntityFromId(parentId)
		if not parent or parent.destroyed then
			rootCFrame = Entity.GetAt(current, Entity.GetTargetRenderTime(current))
				or current.latestCFrame
				or CFrame.identity
			dp[current] = currentTime
			world[current] = rootCFrame
			Entity._SetPartCFrame(current, rootCFrame)
			break
		end

		n += 1
		path[n] = current
		current = parent
	end

	local out = rootCFrame or CFrame.identity
	for i = n, 1, -1 do
		local child = path[i]
		out = out * (child.mountOffset or CFrame.identity)
		dp[child] = currentTime
		world[child] = out
		Entity._SetPartCFrame(child, out)
		path[i] = nil
	end

	if dp[entity] ~= currentTime then
		dp[entity] = currentTime
		world[entity] = out
		Entity._SetPartCFrame(entity, out)
	end

	return world[entity]
end

return function()
	timestamp += 1

	for _, entity in Holder.idMap do
		if entity.destroyed or entity.mountParentId then
			continue
		end

		local cframe = Entity.GetAt(entity, Entity.GetTargetRenderTime(entity)) or entity.latestCFrame
		if cframe then
			Entity._SetPartCFrame(entity, cframe)
			dp[entity] = timestamp
			world[entity] = cframe
		end
	end

	for _, entity in Holder.idMap do
		if entity.destroyed or not entity.mountParentId or dp[entity] == timestamp then
			continue
		end
		ResolveWorldCFrame(entity)
	end
end
