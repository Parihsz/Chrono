const RunService = game:GetService("RunService")

const Types = require(script.Parent.Types)
const Holder = require(script.Parent.Holder)

const IS_SERVER = RunService:IsServer()
const RegisterChange = Holder.RegisterChange

const HUMANOID_STATES: { [number]: Enum.HumanoidStateType } = {}
for _, item in Enum.HumanoidStateType:GetEnumItems() do
	HUMANOID_STATES[item.Value] = item
end

type Entity = Types.Entity

const function GetHumanoid(self: Entity): Humanoid?
	const model = self.model
	if model and model:IsA("Model") then
		return model:FindFirstChildWhichIsA("Humanoid", true)
	end
	return nil
end

const function GetDisabledStateMask(humanoid: Humanoid): number
	local mask = 0
	for value, state in HUMANOID_STATES do
		if state == Enum.HumanoidStateType.None then
			continue
		end
		if not humanoid:GetStateEnabled(state) then
			mask = bit32.bor(mask, bit32.lshift(1, value))
		end
	end
	return mask
end

const function StopHumanoidStateWatch(self: Entity)
	const connection = self._humanoidStateConn
	if connection then
		connection:Disconnect()
		self._humanoidStateConn = nil
	end
	const enabledConnection = self._humanoidStateEnabledConn
	if enabledConnection then
		enabledConnection:Disconnect()
		self._humanoidStateEnabledConn = nil
	end

	if IS_SERVER then
		RegisterChange(self, "_humanoidState", nil)
		RegisterChange(self, "_humanoidDisabledStates", nil)
	end
end

const function StartHumanoidStateWatch(self: Entity)
	if not IS_SERVER then
		return
	end
	StopHumanoidStateWatch(self)

	const humanoid = GetHumanoid(self)
	if not humanoid then
		return
	end

	RegisterChange(self, "_humanoidState", humanoid:GetState().Value, true)
	self._humanoidStateConn = humanoid.StateChanged:Connect(function(_old, new)
		RegisterChange(self, "_humanoidState", new.Value)
	end)

	RegisterChange(self, "_humanoidDisabledStates", GetDisabledStateMask(humanoid), true)
	self._humanoidStateEnabledConn = humanoid.StateEnabledChanged:Connect(function()
		RegisterChange(self, "_humanoidDisabledStates", GetDisabledStateMask(humanoid))
	end)
end

const function RefreshHumanoidStateWatch(self: Entity, force: boolean?)
	if not IS_SERVER then
		return
	end

	const config = self.entityConfig
	const mode = self._interpolationMode or (config and config.INTERPOLATION_MODE)

	if mode ~= "ALIGN" then
		StopHumanoidStateWatch(self)
		return
	end

	if self._humanoidStateConn and not force then
		return
	end
	StartHumanoidStateWatch(self)
end

const function SetHumanoidState(self: Entity, stateValue: number?)
	RegisterChange(self, "_humanoidState", stateValue)

	if IS_SERVER or self.isContextOwner or type(stateValue) ~= "number" then
		return
	end

	const humanoid = GetHumanoid(self)
	if not humanoid then
		return
	end
	local state = HUMANOID_STATES[stateValue]
	if not state then
		return
	end

	if state == Enum.HumanoidStateType.Ragdoll then
		state = Enum.HumanoidStateType.Physics
	end

	humanoid:ChangeState(state)
end

const function SetHumanoidDisabledStates(self: Entity, mask: number?)
	RegisterChange(self, "_humanoidDisabledStates", mask)
	if IS_SERVER or self.isContextOwner or type(mask) ~= "number" then
		return
	end

	const humanoid = GetHumanoid(self)
	if not humanoid then
		return
	end

	for value, state in HUMANOID_STATES do
		if state == Enum.HumanoidStateType.None then
			continue
		end
		humanoid:SetStateEnabled(state, bit32.band(mask, bit32.lshift(1, value)) == 0)
	end
end

return {
	Refresh = RefreshHumanoidStateWatch,
	Stop = StopHumanoidStateWatch,
	SetState = SetHumanoidState,
	SetDisabledStates = SetHumanoidDisabledStates,
}
