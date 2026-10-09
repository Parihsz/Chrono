export type AlignDriver = {
	part: BasePart,
	container: Camera,
	driverPart: BasePart,
	alignPosition: AlignPosition,
	alignOrientation: AlignOrientation,
	velocity: Vector3?,
	lastPosition: Vector3?,
	lastTime: number?,
}

const Types = require(script.Parent.Parent.Shared.Types)

const CONTAINER_NAME = "__CHRONO_ALIGN"
const DRIVER_PART_NAME = "__CHRONO_ALIGN_PART"

const ROOT_PRIORITY = 127

const MAX_RESPONSIVENESS = 200

const MAX_SPEED = 1000

local velocityUpdates: { AlignDriver } = {}
const AlignDriver = {}

const function Create(part: BasePart): AlignDriver
	const previous = part:FindFirstChild(CONTAINER_NAME)
	if previous then
		previous:Destroy()
	end

	const initCF = part.CFrame

	const container = Instance.new("Camera")
	container.Archivable = false
	container.Name = CONTAINER_NAME
	container.Parent = part

	const driverPart = Instance.new("Part")
	driverPart.Name = DRIVER_PART_NAME

	driverPart.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0, 0, 0, 0)
	driverPart.Massless = false
	driverPart.RootPriority = ROOT_PRIORITY
	driverPart.Size = Vector3.zero
	driverPart.CanCollide = false
	driverPart.CanQuery = false
	driverPart.CanTouch = false
	driverPart.Transparency = 1
	driverPart.Color = Color3.new(0, 1, 0)

	driverPart.CFrame = initCF
	driverPart.Parent = container

	const weld = Instance.new("Weld")
	weld.Name = "__CHRONO_ALIGN_WELD"
	weld.Part0 = driverPart
	weld.Part1 = part
	weld.Parent = container

	const attachment = Instance.new("Attachment")
	attachment.Name = "__CHRONO_ALIGN_ATTACHMENT"
	attachment.Parent = driverPart

	const alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment

	alignPosition.ApplyAtCenterOfMass = false
	alignPosition.ReactionForceEnabled = false

	alignPosition.ForceRelativeTo = Enum.ActuatorRelativeTo.World
	alignPosition.ForceLimitMode = Enum.ForceLimitMode.Magnitude

	alignPosition.MaxForce = math.huge
	alignPosition.MaxVelocity = math.huge
	alignPosition.Responsiveness = MAX_RESPONSIVENESS

	alignPosition.RigidityEnabled = true
	alignPosition.Position = initCF.Position
	alignPosition.Parent = driverPart

	const alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment

	alignOrientation.AlignType = Enum.AlignType.AllAxes
	alignOrientation.PrimaryAxisOnly = false
	alignOrientation.ReactionTorqueEnabled = false
	alignOrientation.MaxTorque = math.huge
	alignOrientation.MaxAngularVelocity = math.huge
	alignOrientation.Responsiveness = MAX_RESPONSIVENESS
	alignOrientation.RigidityEnabled = true
	alignOrientation.CFrame = initCF.Rotation
	alignOrientation.Parent = driverPart

	part.CFrame = initCF

	return {
		part = part,
		container = container,
		driverPart = driverPart,
		alignPosition = alignPosition,
		alignOrientation = alignOrientation,
	}
end

const function Update(driver: AlignDriver, cframe: CFrame)
	driver.alignPosition.Position = cframe.Position
	driver.alignOrientation.CFrame = cframe.Rotation
end

const function Destroy(driver: AlignDriver)
	if driver.container then
		driver.container:Destroy()
	end

	driver.part.AssemblyLinearVelocity = Vector3.zero
end

-- Mimics roblox's replication for velocity
const function UpdateVelocity(driver: AlignDriver, position: Vector3, renderTime: number)
	const lastTime = driver.lastTime
	const lastPosition = driver.lastPosition
	if lastTime and lastPosition and renderTime > lastTime and renderTime - lastTime < 0.5 then
		const velocity = (position - lastPosition) / (renderTime - lastTime)
		if velocity.Magnitude < MAX_SPEED then
			driver.velocity = velocity
			table.insert(velocityUpdates, driver)
		end
	end
	driver.lastPosition = position
	driver.lastTime = renderTime
end

const function Step(entity: Types.Entity, part: BasePart, cframe: CFrame, renderTime: number)
	local existing = entity._alignDriver
	if existing and existing.part ~= part then
		Destroy(existing)
		existing = nil
	end
	if not existing then
		part.CFrame = cframe
	end
	const driver = existing or Create(part)
	entity._alignDriver = driver
	Update(driver, cframe)
	UpdateVelocity(driver, cframe.Position, renderTime)
end

const function Clear(entity: Types.Entity)
	const driver = entity._alignDriver
	if driver then
		Destroy(driver)
		entity._alignDriver = nil
	end
end

const function ApplyVelocities()
	for _, driver in velocityUpdates do
		if driver.velocity and driver.container.Parent then
			driver.part.AssemblyLinearVelocity = driver.velocity
		end
	end
	velocityUpdates = {}
end

AlignDriver.Create = Create
AlignDriver.Update = Update
AlignDriver.Destroy = Destroy
AlignDriver.Step = Step
AlignDriver.Clear = Clear
AlignDriver.ApplyVelocities = ApplyVelocities

return AlignDriver
