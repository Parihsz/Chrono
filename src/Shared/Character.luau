local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local Signal = require(script.Parent.Signal)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local CharacterAdded: Signal.Signal<Player, Model, any> = Signal.new()
local CharacterRemoved: Signal.Signal<Player, Model> = Signal.new()

local CharacterStoredLocation = Instance.new("Camera", workspace)
CharacterStoredLocation.Name = "PlayerCharacterStorage"

local ModelCache

if IS_SERVER then
	ModelCache = Instance.new("Folder", ReplicatedStorage)
	ModelCache.Name = "PLAYER_MODEL_CACHE"
elseif IS_CLIENT then
	ModelCache = ReplicatedStorage:WaitForChild("PLAYER_MODEL_CACHE") :: any
end

local Cache = Config.PLAYER_MODELS
local Characters = {}

local Models = {}

function Characters.GetCharacter(player: Player): Model?
	return Models[player]
end

function Characters.SetCharacter(player: Player, model: Model | string, data: any?)
	if Models[player] == model then
		return
	end

	local model_: Model
	if typeof(model) == "string" then
		local cachedModel = Cache[model]
		if not cachedModel then
			error(`No model found for character: {model}, player: {player.Name}`)
		end
		model_ = cachedModel:Clone()
	else
		model_ = model
	end

	local id = player.UserId
	model_.Parent = CharacterStoredLocation

	if not model_.PrimaryPart then
		warn("Model does not have a PrimaryPart set:", model)
	end

	if Models[player] then
		CharacterRemoved:Fire(player, Models[player])
		pcall(workspace.Destroy, Models[player])
	end

	if IS_CLIENT then
		Models[player] = model_
	else
		Models[player] = model_
		model_.Archivable = true
		local clone = model_:Clone()
		clone.Name = tostring(id)
		clone.Parent = ModelCache
		if data then
			ModelCache:SetAttribute("data", HttpService:JSONEncode({ data }))
		end
	end

	CharacterAdded:Fire(player, model_, data)
end

if IS_CLIENT then
	local function handleChild(child: Instance)
		local id = tonumber(child.Name)
		local data = ModelCache:GetAttribute(child.Name)
		data = data and HttpService:JSONDecode(data)[1]
		ModelCache:SetAttribute(child.Name, nil)

		if not id then
			child:Destroy()
			return
		end

		local player = Players:GetPlayerByUserId(id)
		if not player then
			child:Destroy()
			return
		end

		if child:IsA("StringValue") then
			child = child.Value :: any
			child:Destroy()
		end

		Characters.SetCharacter(player, child :: any, data)
	end

	ModelCache.ChildAdded:Connect(function(child)
		task.defer(handleChild, child)
	end)

	for _, child in ModelCache:GetChildren() do
		task.defer(handleChild, child)
	end
end

Players.PlayerRemoving:Connect(function(player)
	local model = Models[player]
	if model then
		CharacterRemoved:Fire(player, model)
		Models[player] = nil
		pcall(workspace.Destroy, model)
	end
end)

Characters.CharacterAdded = CharacterAdded.Event
Characters.CharacterRemoved = CharacterRemoved.Event

return Characters
