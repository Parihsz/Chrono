local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cache = {}
local Npc = {}
local AutomaticNpc = {}

local IS_CLIENT = RunService:IsClient()
local IS_SERVER = RunService:IsServer()

local ClientReplicate
local ServerReplicate
if IS_CLIENT then
	ClientReplicate = require(script.Parent.Parent.client.replicate)
else
	ServerReplicate = require(script.Parent.Parent.server.replicate)
end

local Config = require(script.Parent.config)
local Signal = require(script.Parent.signal)

local NpcAdded: Signal.Signal<number, Model, any> = Signal.new()
local NpcRemoved: Signal.Signal<number, Model> = Signal.new()

local CAMERA = Instance.new("Camera", workspace)
CAMERA.Name = "NPCCacheCamera"
local NPC_MODEL_CACHE
if IS_SERVER then
	NPC_MODEL_CACHE = Instance.new("Folder", ReplicatedStorage)
	NPC_MODEL_CACHE.Name = "NPC_MODEL_CACHE"
elseif IS_CLIENT then
	NPC_MODEL_CACHE = ReplicatedStorage:WaitForChild("NPC_MODEL_CACHE") :: any
end

local NPC_MODELS = Config.NPC_MODELS

local function ClientRegister(id, model: Model, data: { type: string, initData: any? })
	local npcType = data.type
	if not id then
		warn("NPC model does not have an NPC_ID attribute:", model:GetFullName())
		return
	end

	local clone = model:Clone()
	clone.Name = tostring(id)
	clone.Parent = CAMERA;
	(clone.PrimaryPart :: any).Anchored = true
	Cache[id] = clone
	clone:PivotTo(CFrame.new(0, 1000000, 0))
	ClientReplicate.RegisterClientNPC(id, clone, npcType)
	NpcAdded:Fire(id, clone, data.initData)
	NPC_MODEL_CACHE:SetAttribute(tostring(id),true) -- Mark as registered
end

local function Check()
	for id, strData in NPC_MODEL_CACHE:GetAttributes() do
		if not tonumber(id) or type(strData) ~= "string" then
			continue
		end
		local data = HttpService:JSONDecode(strData)
		local npc = NPC_MODEL_CACHE:FindFirstChild(tostring(id))
		if data.modelType then
			npc = NPC_MODELS[data.modelType] or npc
		end

		if not npc or not npc:IsA("Model") then
			warn(
				`Npc cache: Invalid NPC Model for ID: {id} TYPE: {data.modelType} MAKE SURE IT IS REGISTERED AS A MODEL IN CONFIG [Chrono/src/shared/config]`
			)
			continue
		end

		ClientRegister(tonumber(id) :: number, npc, data)
	end
end

function Npc.RegisterNpcModel(model: Model, npcModelType: string)
	NPC_MODELS[npcModelType] = model
end

function Npc.Register(model: Model, npcType: string?, npcModelType: string?, automaticUpdate: boolean?, initData: any?)
	if IS_CLIENT then
		error("Register can only be called on the server.")
	end
	if not model then
		error("Npc cache requires a model to register.")
	end
	if npcModelType and not NPC_MODELS[npcModelType] then
		warn(
			"No NPC Model Found ["
				.. tostring(npcModelType)
				.. "] MAKE SURE IT IS REGISTERED IN CONFIG [Chrono/src/shared/config] or using [Npc.RegisterNpcModel]"
		)
	end
	npcType = npcType or "DEFAULT"
	local defaultModel = NPC_MODELS[npcModelType]

	local folder_: string = npcModelType or "DEFAULT"
	local folder: Folder = (CAMERA:FindFirstChild(folder_) or Instance.new("Folder", CAMERA)) :: any
	folder.Name = folder_

	local id = ServerReplicate.RegisterNPC(model, npcType)
	Cache[id] = model
	model.Parent = folder

	pcall(function()
		(model.PrimaryPart :: any):SetNetworkOwner(nil)
	end)

	if not defaultModel then
		if not model.Archivable then
			warn("NPC model is not archivable:", model:GetFullName(),"Archivable will now be set to true.")
		end
		model.Archivable = true
		local clone = model:Clone() --// MAKE SURE Archivable is set to true
		clone:PivotTo(CFrame.new(0, 1000000, 0))
		clone.Name = tostring(id)
		clone.Parent = NPC_MODEL_CACHE
	end
	NPC_MODEL_CACHE:SetAttribute(
		tostring(id),
		HttpService:JSONEncode({ type = npcType, modelType = npcModelType, initData = initData })
	)
	if automaticUpdate then
		AutomaticNpc[id] = model
	end
	NpcAdded:Fire(id, model, initData)
	return id
end

function Npc.UnRegister(idOrModel: number | Model): Model
	if IS_CLIENT then
		error("UnRegister can only be called on the server.")
	end
	local id = type(idOrModel) == "number" and idOrModel or (idOrModel::Model):GetAttribute("NPC_ID")::any
	if not id then
		error("Npc cache requires a valid NPC_ID to unregister.")
	end

	Cache[id] = nil
	AutomaticNpc[id] = nil
	local actualModel = ServerReplicate.UnregisterNPC(id)

	local model = NPC_MODEL_CACHE:FindFirstChild(tostring(id))
	if model then
		model:Destroy()
	end
	NPC_MODEL_CACHE:SetAttribute(tostring(id), nil)
	if not actualModel then
		error("Npc cache: Unregister failed to find model for ID: " .. id .. " Please Investigate.")
	end
	NpcRemoved:Fire(id, actualModel)
	return actualModel
end

function Npc.GetModel(id: number): Model
	return Cache[id]
end

if IS_CLIENT then
	NPC_MODEL_CACHE.AttributeChanged:Connect(function(attribute)
		local id = tonumber(attribute)
		if not id then
			return
		end
		local strData = NPC_MODEL_CACHE:GetAttribute(attribute)
		if not strData then
			ClientReplicate.UnregisterNPC(id)
			local npc = Cache[id]
			Cache[id] = nil
			NpcRemoved:Fire(id, npc)
			npc:Destroy()
		elseif type(strData) == "string" then
			local data = HttpService:JSONDecode(strData)
			local npc = NPC_MODEL_CACHE:FindFirstChild(tostring(id))
			if data.modelType then
				npc = NPC_MODELS[data.modelType] or npc
			end

			if not npc or not npc:IsA("Model") then
				warn(
					`Npc cache: Invalid NPC Model for ID: {id} TYPE: {data.modelType} MAKE SURE IT IS REGISTERED AS A MODEL IN CONFIG [Chrono/src/shared/config]`
				)
				return
			end
			task.defer(ClientRegister, id, npc, data)
		end
	end)
	Check()
else
	RunService.PostSimulation:Connect(function(dt)
		local now = os.clock()
		debug.profilebegin("Check Npc CFrames")
		for id, model in AutomaticNpc do
			if not model.PrimaryPart then
				continue
			end
			local cf = model.PrimaryPart.CFrame
			ServerReplicate.PushNPCTransform(id, cf, now)
		end
		debug.profileend()
	end)
end

Npc.NpcAdded = NpcAdded.Event
Npc.NpcRemoved = NpcRemoved.Event

return Npc
