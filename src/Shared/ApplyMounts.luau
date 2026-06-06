--!native

local Entity = require(script.Parent.Entity)
local Events = require(script.Parent.Events)
local Holder = require(script.Parent.Holder)
local Types = require(script.Parent.Types)

local timestamp = 0
local visited = {} :: { [Types.Entity]: number }
local dp = {} :: { [Types.Entity]: number }
local world = {} :: { [Types.Entity]: CFrame }

local path = {} :: { Types.Entity }
local mountedEntities = {} :: { [Types.Entity]: true }

local function SetCFrame(entity: Types.Entity, cframe: CFrame)
	local root = Entity._GetRootPart(entity)
	if root then
		root.CFrame = cframe
		if entity.isContextOwner then
			root.AssemblyAngularVelocity = Vector3.zero
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end
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
			SetCFrame(current, rootCFrame)
			break
		end

		visited[current] = currentTime

		local parentId = current.mountParentId
		if not parentId then
			if current.isContextOwner then
				local part = Entity.GetPrimaryPart(current)
				rootCFrame = if part then part.CFrame else (current.latestCFrame or CFrame.identity)
			else
				rootCFrame = Entity.GetAt(current, Entity.GetTargetRenderTime(current))
					or current.latestCFrame
					or CFrame.identity
			end
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
			SetCFrame(current, rootCFrame)
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
		SetCFrame(child, out)
		path[i] = nil
	end

	if dp[entity] ~= currentTime then
		dp[entity] = currentTime
		world[entity] = out
		SetCFrame(entity, out)
	end

	return world[entity]
end

Events.EntityAdded:Connect(function(entity: Types.Entity)
	if entity.mountParentId then
		mountedEntities[entity] = true
	end
end, true)

Events.EntityMountChanged:Connect(function(entity: Types.Entity, mountParentId: number?)
	if mountParentId then
		mountedEntities[entity] = true
	else
		mountedEntities[entity] = nil
	end
end, true)

Events.EntityRemoved:Connect(function(entity: Types.Entity)
	dp[entity] = nil
	world[entity] = nil
	mountedEntities[entity] = nil
end, true)

local function ApplyMounts()
	debug.profilebegin("ApplyMounts")
	for entity in mountedEntities do
		if entity.destroyed or dp[entity] == timestamp then
			continue
		end
		ResolveWorldCFrame(entity)
	end
	timestamp += 1
	debug.profileend()
end

return ApplyMounts
