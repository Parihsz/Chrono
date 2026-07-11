--!native
const Players = game:GetService("Players")

const RunService = game:GetService("RunService")

const Warn = require(script.Parent.Parent.Shared.Warn)
const Config = require(script.Parent.Parent.Shared.Config)
const Entity = require(script.Parent.Parent.Shared.Entity)
const Holder = require(script.Parent.Parent.Shared.Holder)
const Types = require(script.Parent.Parent.Shared.Types)

const playerEntities = Holder._playerChars

const function RegisterPlayer(
	player: Player,
	character: Model,
	configuration: {
		config: string?,
		modelRepMode: Types.MODEL_REPLICATION_MODE?,
	}
): Types.Entity
	const entity = playerEntities[player]

	if entity then
		Entity.Destroy(entity)
	end

	const config = configuration.config or "PLAYER"
	local modelRepMode: Types.MODEL_REPLICATION_MODE? = configuration.modelRepMode
	const configData = Config._EntityConfigs[config] or {} :: any
	modelRepMode = modelRepMode or configData.MODEL_REPLICATION_MODE
	character.Archivable = true

	const humanoid = character:FindFirstChildWhichIsA("Humanoid")
	const hrp = character:FindFirstChild("HumanoidRootPart")
	if humanoid and hrp then
		const rigType = humanoid.RigType
		if rigType == Enum.HumanoidRigType.R6 and character.PrimaryPart == character:FindFirstChild("Head") then
			Config.SetModelPrimaryForChrono(character, "HumanoidRootPart")
		end
	end

	const newEntity = Entity.new(config, character, modelRepMode :: any)

	Holder.SetAsCharacter(player, newEntity)
	Entity.SetNetworkOwner(newEntity, player)

	-- task.delay(7, function()
	-- 	Entity.SetModel(newEntity, character, "NATIVE", true)
	-- 	task.wait(5)
	-- 	Entity.SetModel(newEntity, character, "CUSTOM", true)
	-- end)

	return newEntity
end

const function UnregisterPlayer(player: Player)
	const entity = playerEntities[player]
	if entity then
		Entity.Destroy(entity)
	end
end

const function OnCharacterAdded(character: Model, player: Player)
	task.wait(0.1)
	RegisterPlayer(player, character, {
		config = "PLAYER",
	})
end

const function OnPlayerAdded(player: Player)
	const connection = player.CharacterAdded:Connect(function(character: Model)
		OnCharacterAdded(character, player)
	end)
	if player.Character then
		OnCharacterAdded(player.Character, player)
	end
	local connection2
	connection2 = player.AncestryChanged:Connect(function()
		if not player:IsDescendantOf(game) then
			connection:Disconnect()
			connection2:Disconnect()
		end
	end)
end

Config._WaitForLock(function()
	if not RunService:IsServer() then
		return
	end
	if Config._GetConfig("PLAYER_REPLICATION") ~= "AUTOMATIC" then
		Warn.low("automatic player replication is disabled")
		return
	end
	const deathRemote = script.Parent.Parent.Shared.Remotes.Death
	const ReplicateMode: "NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS" = Config._GetConfig("REPLICATE_DEATHS")
	deathRemote.OnServerEvent:Connect(function(plr, id)
		if ReplicateMode == "NONE" then
			return
		end
		const entity = Holder.GetEntityFromId(id)
		if not entity then
			return
		end

		if entity.networkOwner ~= plr then
			return
		end
		if ReplicateMode == "PLAYER_CHARACTERS" and not entity._player then
			return
		end

		const model = entity.model
		if model then
			const humanoid: Humanoid? = model:FindFirstChildWhichIsA("Humanoid")
			task.wait()
			if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
				humanoid.Health = 0
				task.delay(0, function()
					if humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
						humanoid.Health = 0
						humanoid.Health = 10
						humanoid.Health = 0
					end
				end)
			end
		end
		deathRemote:FireAllClients(id)
	end)
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(UnregisterPlayer)

	for _, player in Players:GetPlayers() do
		OnPlayerAdded(player)
	end
end)

return {
	RegisterPlayer = RegisterPlayer,
	UnregisterPlayer = UnregisterPlayer,
}
