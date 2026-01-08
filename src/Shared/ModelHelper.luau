local Shared = script.Parent
local Holder = require(Shared.Holder)
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local function ReadyModelFromRep(entity: Types.Entity, playerSpecific: Player?): Model | string?
	local model = entity.model
	local actualModel = entity.actualModel
	local modelString = entity.modelString
	local replicationMode: "NATIVE" | "CUSTOM" | "MIRRORED" = (entity.modelReplicationMode or "NATIVE") :: any

	if replicationMode == "NATIVE" then
		return model
	elseif replicationMode == "MIRRORED" then
		return actualModel
	elseif replicationMode == "CUSTOM" then
		if modelString then
			return modelString
		end
		local ModelReplicator = script.Parent.Parent.Shared._CUSTOM_MODEL_REP
		print(playerSpecific)
		if playerSpecific then
			local PlayerGui = playerSpecific.PlayerGui
			ModelReplicator = PlayerGui:FindFirstChild("_ChronoClientModels") :: Instance
			if not PlayerGui:FindFirstChild("_ChronoClientModels") then
				ModelReplicator = Instance.new("ScreenGui")
				ModelReplicator.ResetOnSpawn = false
				ModelReplicator.Name = "_ChronoClientModels"
				ModelReplicator.Parent = PlayerGui
			end
		end
		if model then
			local modelClone = model:Clone()
			if not modelClone then
				warn(`Cloned model for {model:GetFullName()} is not Archivable. Failed to replicate model.`)
				modelClone = Instance.new("Model")
				local part = Instance.new("Part")
				part.Size = Vector3.one;(modelClone :: any).PrimaryPart = part
			end
			modelClone.Parent = ModelReplicator

			task.delay(2, function()
				modelClone:Destroy()
			end)
			return modelClone
		end
	else
		warn(`{modelString} is not a valid model string for entity {entity.id}`)
	end
	return nil
end

local function CreateTempModel(): (Model, string)
	local model = Instance.new("Model")
	model.Name = "TempModel"

	local part = Instance.new("Part")
	part.Name = "Failed To Get Model"
	part.Size = Vector3.new(3, 5, 3)
	part.Anchored = true
	part.Parent = model

	model.PrimaryPart = part
	model.Parent = workspace

	return model, "CUSTOM"
end

local function CreateModelFromData(model: Model | string?): (Model?, string?)
	if not model then
		return
	end

	if type(model) == "string" then
		local source = Config._GetEntityModel(model)
		if source then
			local clone = source:Clone()
			if clone then
				clone.Parent = Holder.GetEntityStorageInstance()
				return clone, "CUSTOM"
			end
		end
		return CreateTempModel()
	end

	-- if model.Parent == Shared._MIRRORED_MODELS then
	-- 	model.Parent = Holder.GetEntityStorageInstance()
	-- 	return model, "MIRRORED" -- MIRRORED NO LONGER IS DETECTED ON THE CLIENT 
	-- end

	if
		model.Parent == Shared._CUSTOM_MODEL_REP
		or (
			model.Parent
			and model.Parent.Name == "_ChronoClientModels"
			and model.Parent.Parent
			and model.Parent.Parent:IsA("PlayerGui")
		)
	then
		local clone = model:Clone()
		if clone then
			clone.Parent = Holder.GetEntityStorageInstance()
			return clone, "CUSTOM"
		end
		return CreateTempModel()
	end

	return model, "NATIVE"
end

return {
	ReadyModelFromRep = ReadyModelFromRep,
	CreateModelFromData = CreateModelFromData,
}
