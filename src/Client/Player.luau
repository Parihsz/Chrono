const Warn = require(script.Parent.Parent.Shared.Warn)
const Events = require(script.Parent.Parent.Shared.Events)
const Entity = require(script.Parent.Parent.Shared.Entity)
const Holder = require(script.Parent.Parent.Shared.Holder)
const Types = require(script.Parent.Parent.Shared.Types)
const Config = require(script.Parent.Parent.Shared.Config)
const Bin = require(script.Parent.Parent.Shared.Bin)

const LocalPlayer = game:GetService("Players").LocalPlayer
const DeathRemote = script.Parent.Parent.Shared.Remotes.Death

const binClears: { [Types.Entity]: () -> () } = {}

const function IsAutomatic(): boolean
	return Config._GetConfig("PLAYER_REPLICATION") == "AUTOMATIC"
end

const function SetLocalCharacter(model: Model | BasePart?)
	if not model then
		return
	end
	if not model:IsA("Model") then
		Warn.high(`Model for {LocalPlayer} is not a Model instance.`)
		return
	end
	LocalPlayer.Character = model
	const cf = workspace.CurrentCamera.CFrame
	workspace.CurrentCamera.CameraSubject = model:FindFirstChildWhichIsA("Humanoid") or model.PrimaryPart
	workspace.CurrentCamera.CFrame = cf
	for _, v in model:QueryDescendants("LocalScript") do
		if v:IsA("LocalScript") and v.Disabled == false then
			v.Disabled = true
			v.Disabled = false
		end
	end
end

const function OnCharacterRegistered(player: Player, entity: Types.Entity)
	if not IsAutomatic() or Entity.GetModelReplicationType(entity) ~= "CUSTOM" then
		return
	end
	const model = entity.model
	if not model then
		return Warn.high(`No model found for {player}`)
	end
	if not model:IsA("Model") then
		return Warn.high(`Model for {player} is not a Model instance.`)
	end
	player.Character = model

	if player == LocalPlayer then
		Entity.GetEvent(entity, "ModelChanged"):Connect(function(_, newModel)
			SetLocalCharacter(newModel)
		end)
		SetLocalCharacter(model)
	end
end

const function StopWatch(entity: Types.Entity)
	const clear = binClears[entity]
	if clear then
		binClears[entity] = nil
		clear()
	end
end

const function WatchDeath(player: Player, entity: Types.Entity)
	if player ~= LocalPlayer or binClears[entity] then
		return
	end
	const add, clear = Bin()
	const addDied, clearDied = Bin()

	const function CheckHumanoid(_, model: Model | BasePart?)
		clearDied()
		if not model or not entity.isContextOwner or not model:IsA("Model") then
			return
		end
		const humanoid = model:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			addDied(humanoid.Died:Connect(function()
				if entity.isContextOwner then
					DeathRemote:FireServer(entity.id)
				end
			end))
		end
	end

	add(Entity.GetEvent(entity, "ModelChanged"):Connect(CheckHumanoid))
	add(Entity.GetEvent(entity, "Destroying"):Connect(function()
		StopWatch(entity)
	end))
	add(clearDied)
	binClears[entity] = clear
	CheckHumanoid(entity, entity.model)
end

const function Die(id: number)
	const entity = Holder.GetEntityFromId(id)
	if not entity or entity.isContextOwner then
		return
	end
	const model = entity.model
	if not model then
		return
	end
	task.wait()
	const humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
		humanoid.Health = 0
		humanoid.Health = 10
		humanoid.Health = 0
	end
end

Events.PlayerCharacterRegistered:Connect(OnCharacterRegistered)

Config._WaitForLock(function()
	if not IsAutomatic() then
		return
	end
	Events.PlayerOwnedAdded:Connect(WatchDeath)
	Events.PlayerOwnedRemoved:Connect(function(_, entity)
		StopWatch(entity)
	end)
end)

DeathRemote.OnClientEvent:Connect(Die)

return nil
