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
	local modelRepMode = configuration.modelRepMode

	if character.PrimaryPart then
		character.PrimaryPart:SetNetworkOwner(player)
	end
	local newEntity = Entity.new(config, character, modelRepMode :: "NATIVE" | "MIRRORED" | "CUSTOM")
	Holder.RegisterEntity(newEntity)
	Holder.SetAsCharacter(player, newEntity)
	Entity.SetNetworkOwner(newEntity, player)

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
	elseif Config._GetConfig("SHOW_WARNINGS") then
		warn("automatic player replication is disabled")
	end
end

local function OnPlayerAdded(player: Player)
	player.CharacterAppearanceLoaded:Connect(function(character: Model)
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
