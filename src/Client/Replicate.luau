const Shared = script.Parent.Parent.Shared

const RunService = game:GetService("RunService")

const Ticker = require(Shared.Ticker)
const Warn = require(Shared.Warn)
const StatsALL = require(script.Parent.Parent.Shared.Stats)
const ApplyMounts = require(script.Parent.Parent.Shared.ApplyMounts)
const RenderCache = require(script.Parent.ClientClock)
const ModelResolver = require(script.Parent.ModelResolver)
const Entity = require(Shared.Entity)
const Holder = require(Shared.Holder)
const Config = require(Shared.Config)
const Types = require(Shared.Types)
const Sender = require(script.Parent.Sender)
const Stats = require(Shared.Stats).CLIENT

const CLIENT_CLOCK_SYNC_RATE = 15 -- should be fine having lower then server
require(script.Parent.Player)
require(script.Parent.Receiver)

const idMap = Holder.idMap

local FrustumLookVector = vector.create(0, 0, -1)
local FrustumRightVector = vector.create(1, 0, 0)
local FrustumUpVector = vector.create(0, 1, 0)
local FrustumPosition = vector.create(0, 0, 0)
local TanHorizontal = 0
local TanVertical = 0

const function PrepareFrustumCheck()
	const cframe: CFrame = workspace.CurrentCamera.CFrame
	FrustumLookVector = cframe.LookVector :: any
	FrustumRightVector = cframe.RightVector :: any
	FrustumUpVector = cframe.UpVector :: any

	FrustumPosition = cframe.Position :: any

	const cam = workspace.CurrentCamera
	const halfFov = math.rad(cam.FieldOfView / 2)
	const aspectRatio = cam.ViewportSize.X / cam.ViewportSize.Y
	TanHorizontal = math.tan(halfFov) * aspectRatio
	TanVertical = math.tan(halfFov)
end

const function CheckPointInFrustum(pos: vector)
	const diff = pos - FrustumPosition

	const magnitude = vector.magnitude(diff)

	if magnitude == 0 then
		return true
	end

	const forwardDis = vector.dot(diff, FrustumLookVector)

	const forwardDot = forwardDis / magnitude
	if forwardDot < 0 then
		return false
	end
	if forwardDis < 1 then
		return true
	end
	const unit = diff / magnitude
	const rightDot = vector.dot(unit, FrustumRightVector)

	if math.abs(rightDot) > forwardDot * TanHorizontal then
		return false
	end

	const upDot = vector.dot(unit, FrustumUpVector)
	if math.abs(upDot) > forwardDot * TanVertical then
		return false
	end
	return true
end

const function CheckBroadPhaseInFrustum(center: vector, size: vector)
	if size == vector.zero then
		return CheckPointInFrustum(center)
	end
	const halfSize = size * 0.5
	const halfX = halfSize.x
	const halfY = halfSize.y
	const halfZ = halfSize.z
	const negX = -halfX
	const negY = -halfY
	const negZ = -halfZ

	return CheckPointInFrustum(center + vector.create(halfX, halfY, halfZ))
		or CheckPointInFrustum(center + vector.create(negX, halfY, halfZ))
		or CheckPointInFrustum(center + vector.create(halfX, negY, halfZ))
		or CheckPointInFrustum(center + vector.create(negX, negY, halfZ))
		or CheckPointInFrustum(center + vector.create(halfX, halfY, negZ))
		or CheckPointInFrustum(center + vector.create(negX, halfY, negZ))
		or CheckPointInFrustum(center + vector.create(halfX, negY, negZ))
		or CheckPointInFrustum(center + vector.create(negX, negY, negZ))
end
const Ticks = 4
local OutOfBroadPhaseTick = 0
local CurrentTick = 0
local TotalInterpolationTime = 0
local AmtInterpolations = 0

local CheckedThisFrame = 0
local TotalCulled = 0
local MovedThisFrame = 0

const function Interpolate(entity: Types.Entity)
	const config = entity.entityConfig
	if not entity.interpolation or config.CUSTOM_INTERPOLATION then
		return
	end
	const primaryPart = Entity.GetPrimaryPart(entity)

	if not primaryPart then
		return
	end

	if entity.isContextOwner then
		return
	end

	if config.ASSEMBLY_ROOT_PART_CHECK then
		if primaryPart.AssemblyRootPart ~= primaryPart then
			Warn.low(
				"Primary part for entity "
					.. entity.id
					.. " is not the assembly root part. Skipping interpolation for this entity."
			)
			return
		end
	end

	const currentEntityTick = entity._outofBroadPhaseTick
	if currentEntityTick and currentEntityTick ~= CurrentTick then
		return
	end

	const snapshot = entity.snapshot
	if not snapshot then
		Warn.medium("No snapshot for entity", entity)
		return
	end
	CheckedThisFrame += 1
	debug.profilebegin("Get Render CFrame")
	const targetTime = Entity.GetTargetRenderTime(entity)
	const targetCFrame = snapshot:GetAt(targetTime)
	debug.profileend()
	if not targetCFrame then
		return
	end
	const broadPhase: vector? = entity.broadPhase

	if broadPhase then
		const toCheck = targetCFrame :: any
		const lastCheckedCFrame = entity.lastCheckedCFrame
		debug.profilebegin("Prepare Frustum")
		const passed = CheckBroadPhaseInFrustum(toCheck.Position, broadPhase)
		debug.profileend()
		if not passed then
			if lastCheckedCFrame and lastCheckedCFrame.Position ~= toCheck.Position then
				debug.profilebegin("Check Last CFrame")
				const passLast = CheckBroadPhaseInFrustum(lastCheckedCFrame.Position :: any, broadPhase)
				debug.profileend()
				if not passLast then
					TotalCulled += 1
					return
				end
			else
				if not lastCheckedCFrame then
					entity.lastCheckedCFrame = toCheck
				end
				if not entity._outofBroadPhaseTick then
					entity._outofBroadPhaseTick = OutOfBroadPhaseTick
					OutOfBroadPhaseTick += 1
					if OutOfBroadPhaseTick % Ticks == 0 then
						OutOfBroadPhaseTick = 0
					end
				end
				TotalCulled += 1
				return
			end
		end
		entity.lastCheckedCFrame = nil
		entity._outofBroadPhaseTick = nil
	end
	debug.profilebegin("Set CFrame")
	if targetCFrame == targetCFrame then
		primaryPart.CFrame = targetCFrame
	end
	MovedThisFrame += 1
	debug.profileend()
end

const function updateEntityStats()
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
			bufferedTime = RenderCache._getBuffer(renderCache)
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
	Stats.CLIENT_ENTITIES = entities
end
Config._WaitForLock(function()
	RunService.Heartbeat:Connect(function(deltaTime: number)
		CurrentTick += 1
		if CurrentTick % Ticks == 0 then -- Runs every 4 frames at 60hz this is 15hz
			Stats.TOTAL_ENTITIES_CULLED = TotalCulled
			TotalCulled = 0
			CurrentTick = 0
		end
		RenderCache.UpdateAll(deltaTime)
		debug.profilebegin("Prepare Frustum Check")
		PrepareFrustumCheck()
		debug.profileend()
		local total = 0
		const startTime = os.clock()
		debug.profilebegin("Interpolate Entities")
		for _, entity in idMap do
			ModelResolver(entity)
			if entity.destroyed or entity.paused then
				continue
			end
			if entity.mountParentId then
				continue
			end
			total += 1
			Interpolate(entity)
		end
		debug.profileend()
		const endTime = os.clock()
		debug.profilebegin("Update Entity Stats")
		updateEntityStats()
		debug.profileend()
		TotalInterpolationTime += (endTime - startTime)
		AmtInterpolations += 1

		ApplyMounts()
		if not Stats._PAUSE then
			Stats.TOTAL_CLIENT_ENTITIES_CHECKED_THIS_FRAME = total
			Stats.ENTITIES_MOVED_THIS_FRAME = MovedThisFrame
			Stats.TOTAL_CLIENT_ENTITIES = total
			Stats.AVG_INTERPOLATION_TIME_MS = (TotalInterpolationTime / AmtInterpolations) * 1000
		end
		MovedThisFrame = 0
		CheckedThisFrame = 0
		if AmtInterpolations > 60 then
			TotalInterpolationTime = 0
			AmtInterpolations = 0
		end
		Sender.Update()
		Ticker._IncrementGlobalTick()
	end)
	-- Client clock heartbeat: sends the FULL os.clock so the server can seat this client's wrap
	-- epoch directly (remotes serialize numbers as f64 anyway, so it's the same bytes as a u32).
	-- Keeps the server's view fresh + correct even for a still (macro/auto-click) player that
	-- sends no entity packets. See ClockUnwrap.
	const ClientHeartbeatRemote = Shared.Remotes.ClientHeartbeat
	ClientHeartbeatRemote:FireServer(os.clock()) -- seed on join
	local clientHeartbeatAcc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		clientHeartbeatAcc += dt
		if clientHeartbeatAcc >= CLIENT_CLOCK_SYNC_RATE then
			clientHeartbeatAcc = 0
			ClientHeartbeatRemote:FireServer(os.clock())
		end
	end)

	Shared.Remotes.ClientLoaded:FireServer()
end)

return nil
