--!native
local Players = game:GetService("Players")
local Config = require(script.Parent.Parent.Shared.Config)
local Entity = require(script.Parent.Parent.Shared.Entity)
local Holder = require(script.Parent.Parent.Shared.Holder)
local Types = require(script.Parent.Parent.Shared.Types)

local playerEntities = {} :: { [Player]: Types.Entity }

local function RegisterPlayer(
	player: Player,
	character: Model,
	configuration: {
		config: string?,
		modelRepMode: "NATIVE" | "MIRRORED" | "CUSTOM"?,
	}
): Types.Entity
	local entity = playerEntities[player]
	if entity then
		playerEntities[player] = nil
		Entity.Destroy(entity)
	end

	local config = configuration.config or "PLAYER"
	local modelRepMode = configuration.modelRepMode or "NATIVE"

	local newEntity = Entity.new(config, character, modelRepMode :: "NATIVE" | "MIRRORED" | "CUSTOM")
	newEntity._plrCharacter = player

	Holder.RegisterEntity(newEntity)
	Holder.SetAsCharacter(player, newEntity)
	Entity._SetNetworkOwner(newEntity, player)

	playerEntities[player] = newEntity
	return newEntity
end

local function UnregisterPlayer(player: Player)
	local entity = playerEntities[player]
	if entity then
		playerEntities[player] = nil
		Entity.Destroy(entity)
	end
end

local function OnCharacterAdded(character: Model, player: Player)
	if Config._GetConfig("PLAYER_REPLICATION") == "AUTOMATIC" then
		RegisterPlayer(player, character, {
			config = "PLAYER",
			modelRepMode = Config._GetConfig("DEFAULT_MODEL_REPLICATION_MODE"),
		})
	else
		print("automatic player replication is disabled")
	end
end

local function OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		OnCharacterAdded(character, player)
	end)
	if player.Character then
		OnCharacterAdded(player.Character, player)
	end
end

Config._WaitForLock(function()
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
