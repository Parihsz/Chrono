const RunService = game:GetService("RunService")

const IS_SERVER = RunService:IsServer()
const LOCKER_NAME = "__CHRONO_LOCKER"

const function SafeSetNetworkOwner(part: BasePart, player: Player?)
	if part:CanSetNetworkOwnership() then
		part:SetNetworkOwner(player)
	end
end

const function GetLockedRoot(part: BasePart): BasePart?
	const locker = part:FindFirstChild(LOCKER_NAME)
	if not locker then
		return nil
	end
	return locker:FindFirstChildWhichIsA("BasePart") or part
end

const function LockCFReplication(part: BasePart?): BasePart?
	if not part then
		return
	end
	const initCF = part.CFrame
	const previousLocker = part:FindFirstChild(LOCKER_NAME)
	if previousLocker then
		const weld = previousLocker:FindFirstChild("__CHRONO_WELD") :: Motor6D
		if weld then
			weld.Part1 = part
			part.CFrame = initCF
			return weld.Part0
		else
			pcall(previousLocker.Destroy, previousLocker)
		end
	end
	--[[
		This trick helps disable roblox's cf replication by create a part that
		take priority and acts like the root part which we call the locker.
		The locker part will be hidden on the server in a camera which will
		cause roblox to not replicate the locker to the client which will
		disable roblox's cf replication.
	]]
	const camera = Instance.new("Camera", part)
	camera.Archivable = false
	camera.Name = LOCKER_NAME
	const weld = Instance.new("Weld", camera)
	weld.Name = "__CHRONO_WELD"
	const locker = Instance.new("Part")
	locker.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0, 0, 0, 0)
	locker.Name = "__CHRONO_LOCKER_PART"
	locker.Parent = camera
	locker.CanCollide = false
	locker.CanQuery = false
	locker.CanTouch = false
	locker.Transparency = if IS_SERVER then 0 else 1
	locker.Color = Color3.new(1, 0, 0)
	locker.Massless = false
	locker.RootPriority = 126
	locker.Size = Vector3.zero
	weld.Part0 = locker
	weld.Part1 = part
	part.CFrame = initCF
	return locker
end

const function UnlockCFReplication(part: BasePart?)
	if not part then
		return
	end
	const cf = part.CFrame
	const locker = part:FindFirstChild(LOCKER_NAME)
	if locker then
		-- Safer to destroy and recreate than to reuse the weld
		locker:Destroy()
		part.CFrame = cf
	end
end

return {
	Lock = LockCFReplication,
	Unlock = UnlockCFReplication,
	GetLockedRoot = GetLockedRoot,
	SafeSetNetworkOwner = SafeSetNetworkOwner,
}
