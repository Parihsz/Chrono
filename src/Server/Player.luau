--!native
const Players = game:GetService("Players")

const RunService = game:GetService("RunService")

const Warn = require(script.Parent.Parent.Shared.Warn)
const Config = require(script.Parent.Parent.Shared.Config)
const Entity = require(script.Parent.Parent.Shared.Entity)
const Holder = require(script.Parent.Parent.Shared.Holder)
const Types = require(script.Parent.Parent.Shared.Types)

const playerEntities = Holder._playerChars

const APPEARANCE_TIMEOUT = 3
const loadedAppearance: { [Player]: Model } = {}

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

	return newEntity
end

const function UnregisterPlayer(player: Player)
	const entity = playerEntities[player]
	if entity then
		Entity.Destroy(entity)
	end
end

const function OnCharacterAdded(character: Model, player: Player)
	if Config.FLAGS.CHARACTER_WAIT_DELAY then
		const start = os.clock()
		while
			loadedAppearance[player] ~= character
			and player.Character == character
			and os.clock() - start < APPEARANCE_TIMEOUT
		do
			task.wait()
		end
	end
	if player.Character ~= character or not player.Parent then
		return
	end -- edge case
	const existing = playerEntities[player]
	if existing and existing.model == character then
		return 
	end
	RegisterPlayer(player, character, {
		config = "PLAYER",
	})
end

const function OnPlayerAdded(player: Player)
	const appearanceConnection = player.CharacterAppearanceLoaded:Connect(function(character: Model)
		loadedAppearance[player] = character
	end)
	const connection = player.CharacterAdded:Connect(function(character: Model)
		OnCharacterAdded(character, player)
	end)
	if player.Character then
		if player:HasAppearanceLoaded() then
			loadedAppearance[player] = player.Character
		end
		task.spawn(OnCharacterAdded, player.Character, player)
	end
	local connection2: RBXScriptConnection? = nil
	connection2 = player.AncestryChanged:Connect(function()
		if not player:IsDescendantOf(game) then
			loadedAppearance[player] = nil
			appearanceConnection:Disconnect()
			connection:Disconnect()
			if connection2 then
				connection2:Disconnect()
			end
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
	if ReplicateMode ~= "NONE" then
		deathRemote.OnServerEvent:Connect(function(plr, id)
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
							-- this trick helps force the humanoid to die
							-- since there were some issues we encountered where
							-- the humanoid stayed alive
							humanoid.Health = 0
							humanoid.Health = 10
							humanoid.Health = 0
						end
					end)
				end
			end
			deathRemote:FireAllClients(id)
		end)
	end

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
