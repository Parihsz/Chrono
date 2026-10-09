const Shared = script.Parent.Parent.Shared

const RunService = game:GetService("RunService")

const Ticker = require(Shared.Ticker)
const Warn = require(Shared.Warn)
const ApplyMounts = require(script.Parent.Parent.Shared.ApplyMounts)
const AlignDriver = require(script.Parent.AlignDriver)
const RenderCache = require(script.Parent.ClientClock)
const ModelResolver = require(script.Parent.ModelResolver)
const Entity = require(Shared.Entity)
const Holder = require(Shared.Holder)
const Config = require(Shared.Config)
const Types = require(Shared.Types)
const Sender = require(script.Parent.Sender)
const Frustum = require(script.Parent.Frustum)
const UpdateEntityStats = require(script.Parent.EntityStats)
const Stats = require(Shared.Stats).CLIENT

const CLIENT_CLOCK_SYNC_RATE = 15 -- should be fine having lower then server
require(script.Parent.Player)
require(script.Parent.Receiver)

const idMap = Holder.idMap

local TotalInterpolationTime = 0
local AmtInterpolations = 0

local CheckedThisFrame = 0
local MovedThisFrame = 0

local LastClockUpdate = os.clock()

const function GetMode(entity: Types.Entity): Types.INTERPOLATION_MODE?
	const config = entity.entityConfig
	const mode: Types.INTERPOLATION_MODE? = entity._interpolationMode or config.INTERPOLATION_MODE

	if not mode or not entity.interpolation or config.CUSTOM_INTERPOLATION or mode == "NONE" then
		return nil
	end
	return mode
end

const function CanInterpolate(entity: Types.Entity, primaryPart: BasePart): boolean
	if entity.isContextOwner then
		return false
	end

	if entity.entityConfig.ASSEMBLY_ROOT_PART_CHECK and not entity._alignDriver then
		if primaryPart.AssemblyRootPart ~= primaryPart then
			Warn.low(
				"Primary part for entity "
					.. entity.id
					.. " is not the assembly root part. Skipping interpolation for this entity."
			)
			return false
		end
	end

	if Frustum.IsThrottled(entity) then
		return false
	end

	if not entity.snapshot then
		Warn.medium("No snapshot for entity", entity)
		return false
	end
	return true
end

const function Interpolate(entity: Types.Entity, mode: Types.INTERPOLATION_MODE)
	const primaryPart = Entity.GetPrimaryPart(entity)
	if not primaryPart or not CanInterpolate(entity, primaryPart) then
		return
	end
	const snapshot = entity.snapshot :: Types.Snapshot<CFrame, Vector3>
	CheckedThisFrame += 1
	debug.profilebegin("Get Render CFrame")
	local targetTime = Entity.GetTargetRenderTime(entity)
	if mode == "ALIGN" then
		targetTime += os.clock() - LastClockUpdate
	end
	const targetCFrame = snapshot:GetAt(targetTime)
	debug.profileend()
	if not targetCFrame then
		return
	end
	if entity.broadPhase and Frustum.IsCulled(entity, targetCFrame) then
		return
	end
	debug.profilebegin("Set CFrame")
	if targetCFrame == targetCFrame then
		if mode == "ALIGN" then
			AlignDriver.Step(entity, primaryPart, targetCFrame, targetTime)
		else
			AlignDriver.Clear(entity)
			primaryPart.CFrame = targetCFrame
		end
	end
	MovedThisFrame += 1
	debug.profileend()
end

Config._WaitForLock(function()
	local steppedEntities = {}
	RunService.Heartbeat:Connect(function(deltaTime: number)
		steppedEntities = {}
		Frustum.Update()
		RenderCache.UpdateAll(deltaTime)
		LastClockUpdate = os.clock()
		debug.profilebegin("Prepare Frustum Check")
		Frustum.Prepare()
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
			const mode: Types.INTERPOLATION_MODE? = GetMode(entity)
			if mode == "ALIGN" then
				if not entity._alignDriver then
					Interpolate(entity, mode)
				end
				table.insert(steppedEntities, entity)
			elseif mode then
				Interpolate(entity, mode)
			elseif entity._alignDriver then
				AlignDriver.Clear(entity)
			end
		end
		debug.profileend()
		const endTime = os.clock()
		debug.profilebegin("Update Entity Stats")
		UpdateEntityStats()
		debug.profileend()
		debug.profilebegin("Apply Velocities")
		AlignDriver.ApplyVelocities()
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

	RunService.PreSimulation:Connect(function()
		-- for align pos
		debug.profilebegin("Interpolate Align Entities")
		Frustum.Prepare()
		for _, entity in steppedEntities do
			if entity.destroyed or entity.paused or entity.mountParentId then
				continue
			end
			if GetMode(entity) == "ALIGN" then
				Interpolate(entity, "ALIGN")
			end
		end
		debug.profileend()
	end)

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
