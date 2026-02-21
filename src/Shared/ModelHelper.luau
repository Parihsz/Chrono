local Shared = script.Parent
local Holder = require(Shared.Holder)
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local TAG = "CHRONO_MODEL_REPLICATOR"
local CHRONO_ATTRIBUTE = "CHRONO_MODEL_META"

local ids = 0
local function ReadyModelFromRep(entity: Types.Entity, playerSpecific: Player?): (Model | string | BasePart?, string?)
	local model = entity.model
	local modelString = entity.modelString
	local replicationMode: "NATIVE" | "CUSTOM" = (entity.modelReplicationMode or "NATIVE") :: any

	if replicationMode == "NATIVE" and model then
		local metaString = `{ids}|{entity.id}`
		model:AddTag(TAG)
		local old = model:GetAttribute(CHRONO_ATTRIBUTE) :: string
		if old then
			local entityFromOld = tonumber(old:split("|")[2])
			if entityFromOld ~= entity.id then
				old = nil
			end
		end
		if not old then
			ids += 1
			model:SetAttribute(CHRONO_ATTRIBUTE, metaString)
		else
			metaString = old
		end
		return model, metaString
	elseif replicationMode == "CUSTOM" then
		if modelString then
			return modelString
		end
		local ModelReplicator = script.Parent.Parent.Shared._CUSTOM_MODEL_REP

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
				part.Size = Vector3.one;
				(modelClone :: any).PrimaryPart = part
			end
			(modelClone :: any).Parent = ModelReplicator

			task.delay(2, function()
				modelClone:Destroy()
			end)
			return modelClone
		end
	elseif modelString then
		warn(`{modelString} is not a valid model string for entity {entity.id}`)
	end
	return nil, nil
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

local function CreateModelFromData(model: Model | string | BasePart?): (Model | string | BasePart?, string?)
	if not model then
		return
	end

	if type(model) == "string" then
		return model, nil
	end

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
			(clone :: any).Parent = Holder.GetEntityStorageInstance()
			return clone, "CUSTOM"
		end
		return CreateTempModel()
	end

	return model, "NATIVE"
end

return {
	TAG = TAG,
	CHRONO_ATTRIBUTE = CHRONO_ATTRIBUTE,
	ReadyModelFromRep = ReadyModelFromRep,
	CreateModelFromData = CreateModelFromData,
}
