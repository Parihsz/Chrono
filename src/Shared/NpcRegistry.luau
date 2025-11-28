local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
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
	ClientReplicate = require(script.Parent.Parent.Client.Replicate)
else
	ServerReplicate = require(script.Parent.Parent.Server.Replicate)
end

local Config = require(script.Parent.Config)
local Signal = require(script.Parent.Signal)

local NpcAdded: Signal.Signal<number, Model, any> = Signal.new()
local NpcRemoved: Signal.Signal<number, Model> = Signal.new()

local CAMERA = Instance.new("Camera", workspace)
CAMERA.Name = "NpcRegistryCamera"
local NPC_MODEL_CACHE
local NpcRegistryRemote: RemoteEvent

if IS_SERVER then
	NpcRegistryRemote = Instance.new("RemoteEvent", script)
	NpcRegistryRemote.Name = "OwnerChanged"
	NPC_MODEL_CACHE = Instance.new("Folder", ReplicatedStorage)
	NPC_MODEL_CACHE.Name = "NPC_MODEL_CACHE"
elseif IS_CLIENT then
	NpcRegistryRemote = script:WaitForChild("OwnerChanged") :: RemoteEvent
	NPC_MODEL_CACHE = ReplicatedStorage:WaitForChild("NPC_MODEL_CACHE") :: any
end

local NPC_MODELS = Config.NPC_MODELS

local ClientOwners = {} :: { [any]: any }

local function removeOwner(client, id)
	if not ClientOwners[client] then
		return
	end
	ClientOwners[client][id] = nil
	if not next(ClientOwners[client]) then
		ClientOwners[client] = nil
	end
end

local function ClientRegister(id, model: Model, data: { type: string, initData: any? })
	local npcType = data.type
	if not id then
		warn("NPC model does not have an NPC_ID attribute:", model:GetFullName())
		return
	end

	local clone = model:Clone()
	clone.Name = tostring(id)
	clone.Parent = CAMERA
	--(clone.PrimaryPart :: any).Anchored = true

	Cache[id] = clone
	clone:PivotTo(CFrame.new(0, 1000000, 0))

	ClientReplicate.RegisterClientNPC(id, clone, npcType)
	NpcAdded:Fire(id, clone, data.initData)

	NPC_MODEL_CACHE:SetAttribute(tostring(id), true) -- Mark as registered
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
	local defaultModel = NPC_MODELS[npcModelType or ""]

	local folder_: string = npcModelType or "DEFAULT"
	local folder: Folder = (CAMERA:FindFirstChild(folder_) or Instance.new("Folder", CAMERA)) :: any
	folder.Name = folder_

	local id = ServerReplicate.RegisterNPC(model, npcType)
	Cache[id] = model
	model.Parent = folder
	if model and model.PrimaryPart then
		ServerReplicate.PushNPCTransform(id, model.PrimaryPart.CFrame, os.clock())
	end

	pcall(function()
		(model.PrimaryPart :: any):SetNetworkOwner(nil)
	end)

	if not defaultModel then
		if not model.Archivable then
			warn("NPC model is not archivable:", model:GetFullName(), "Archivable will now be set to true.")
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
	) -- Could use remotes instead in the future but this works aaaaaaaaaaaaa

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
	local id = type(idOrModel) == "number" and idOrModel or (idOrModel :: Model):GetAttribute("NPC_ID") :: any
	if not id then
		error("Npc cache requires a valid NPC_ID to unregister.")
	end

	Cache[id] = nil
	AutomaticNpc[id] = nil
	local data = ServerReplicate.idMap[id]
	local owner = data.networkOwner

	removeOwner(owner, id)

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

function Npc.SetPosition(id: number, cframe: CFrame)
	if IS_CLIENT then
		local model = Cache[id]
		if model and model:IsA("Model") then
			model:PivotTo(cframe)
		end
	else
		local data = ServerReplicate.idMap[id]
		if not data then
			return
		end
		if data.networkOwner then
			NpcRegistryRemote:FireClient(data.networkOwner, "m", id, cframe)
			return
		end
		local model = Cache[id]
		if AutomaticNpc[id] and model and model:IsA("Model") then
			model:PivotTo(cframe)
		end
		ServerReplicate.PushNPCTransform(id, cframe, os.clock())
	end
end

function Npc.SetNetworkOwner(id: number, player: Player?)
	if IS_CLIENT then
		error("SetNetworkOwner can only be called on the server.")
	end
	local data = ServerReplicate.idMap[id]
	if not data then
		warn("Npc cache: SetNetworkOwner failed to find data for ID: " .. id .. " Please Investigate.")
		return
	end
	local existingOwner = data.networkOwner
	if existingOwner == player then
		return
	elseif existingOwner then
		removeOwner(existingOwner, id)

		NpcRegistryRemote:FireClient(existingOwner, "r", id)
	end
	data.networkOwner = player
	NpcRegistryRemote:FireAllClients("c", id, player)
	local idMapData = ServerReplicate.idMap[id]
	if idMapData then
		idMapData.clientLastTick = nil
		local latest = idMapData.snapshot:GetLatest()
		idMapData.snapshot:Clear()
		if latest then
			idMapData.snapshot:Push(0, latest.value)
		end
	end
	if player then
		ClientOwners[player] = ClientOwners[player] or {}
		ClientOwners[player][id] = true
		NpcRegistryRemote:FireClient(player, "a", id)
	end
end

function Npc.GetNetworkOwner(id: number): Player?
	if IS_CLIENT then
		error("GetNetworkOwner can only be called on the server.")
	end
	local data = ServerReplicate.idMap[id]
	if not data then
		return
	end
	return data.networkOwner
end

function Npc.GetNpcsOwnedBy(player: Player): {}?
	if IS_CLIENT then
		error("GetNpcsOwnedBy can only be called on the server.")
	end
	local arr = {}
	if ClientOwners[player] then
		for id in ClientOwners[player] do
			table.insert(arr, id)
		end
	end
	return arr
end

function Npc.GetClientOwned()
	if not IS_CLIENT then
		error("GetClientOwned can only be called on the client.")
	end
	local arr = {}
	for id in ClientOwners do
		table.insert(arr, id)
	end
	return arr
end

if IS_CLIENT then
	task.delay(0.1, function()
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
		NpcRegistryRemote.OnClientEvent:Connect(function(t, id, other)
			if t == "a" then
				ClientOwners[id] = ClientOwners[id] or true
			elseif t == "r" then
				ClientOwners[id] = nil
			elseif t == "i" then
				for v, data in id do
					v = tonumber(v)
					ClientOwners[v] = data

					local idData = ClientReplicate.idMap[v]

					if idData and typeof(data) == "CFrame" then
						idData.snapshot:Push(os.clock(), data)
					end
				end
			elseif t == "c" then
				task.wait(0.1) -- give some time for the server to update
				local idData = ClientReplicate.idMap[id]
				if idData then
					idData.networkOwner = other
					local latest = idData.snapshot:GetLatest()
					idData.snapshot:Clear()
					if latest then
						idData.snapshot:Push(0, latest.value)
					end
					ClientReplicate.BufferTracker.Clear(id)
				end
			elseif t == "m" then
				local model = Cache[id]
				if not model then
					local start = os.clock()
					repeat
						task.wait()
						model = Cache[id]
					until model or os.clock() - start > 5
				end
				if model and model:IsA("Model") and typeof(other) == "CFrame" then
					model:PivotTo(other)
				end
				local idData = ClientReplicate.idMap[id]
				if not idData then
					ClientOwners[id] = other
					return
				end
				idData.snapshot:Push(os.clock(), other)
			end
		end)
		NpcRegistryRemote:FireServer()
	end)
else
	RunService.PostSimulation:Connect(function(dt)
		local now = os.clock()
		debug.profilebegin("Check Npc CFrames")
		for id, model in AutomaticNpc do
			local data = ServerReplicate.idMap[id]
			if not data or data.networkOwner then
				continue
			end
			local primary = model.PrimaryPart
			if not primary then
				continue
			end
			local cf = primary.CFrame
			ServerReplicate.PushNPCTransform(id, cf, now)
		end
		debug.profileend()
	end)
	Players.PlayerAdded:Connect(function(player)
		NpcRegistryRemote.OnServerEvent:Wait()

		table.insert(ServerReplicate._newPlayers, player) -- Allow the replicate module to setup the player
		-- for i,playerO in ClientOwners do
		-- 	local ids = {}
		-- 	for id in playerO do
		-- 		table.insert(ids, id)
		-- 	end
		-- 	NpcRegistryRemote:FireClient(player :: Player,"o" ,playerO,ids)
		-- end
		if not ClientOwners[player] then
			return
		end

		local npcS = {}
		for id in ClientOwners[player] do
			local data = ServerReplicate.idMap[id]
			npcS[tostring(id)] = true :: any
			if not data then
				continue
			end
			local latest = data.snapshot:GetLatest()
			if not latest then
				continue
			end
			npcS[tostring(id)] = latest.value
		end

		NpcRegistryRemote:FireClient(player :: Player, "i", npcS)
	end)
end

Npc._AutomaticNpc = AutomaticNpc
Npc._ClientOwners = ClientOwners

Npc.NpcAdded = NpcAdded.Event
Npc.NpcRemoved = NpcRemoved.Event

return Npc
