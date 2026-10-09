const Shared = script.Parent
const Warn = require(script.Parent.Warn)
const Holder = require(Shared.Holder)
const Types = require(Shared.Types)

const function ReadyModelFromRep(entity: Types.Entity, playerSpecific: Player?): Model | string | BasePart | InstanceHandle?
	const model = entity.model
	const modelString = entity.modelString
	const replicationMode: "NATIVE" | "CUSTOM" = (entity.modelReplicationMode or "NATIVE") :: any

	if replicationMode == "NATIVE" and model then
		return InstanceHandle.new(model)
	elseif replicationMode == "CUSTOM" then
		if modelString then
			return modelString
		end
		local ModelReplicator: Instance = Shared._CUSTOM_MODEL_REP

		if playerSpecific then
			const PlayerGui = playerSpecific.PlayerGui
			local clientModels = PlayerGui:FindFirstChild("_ChronoClientModels")
			if not clientModels then
				const screenGui = Instance.new("ScreenGui")
				screenGui.ResetOnSpawn = false
				screenGui.Name = "_ChronoClientModels"
				screenGui.Parent = PlayerGui
				clientModels = screenGui
			end
			ModelReplicator = clientModels :: Instance
		end
		if model then
			const source: Instance = model
			source.Archivable = true
			const modelClone = source:Clone()
			modelClone.Parent = ModelReplicator

			task.delay(2, function()
				modelClone:Destroy()
			end)
			return modelClone :: any
		end
	elseif modelString then
		Warn.medium(`{modelString} is not a valid model string for entity {entity.id}`)
	end
	return nil
end

const function CreateTempModel(): (Model, string)
	const model = Instance.new("Model")
	model.Name = "TempModel"

	const part = Instance.new("Part")
	part.Name = "Failed To Get Model"
	part.Size = Vector3.new(3, 5, 3)
	part.Anchored = true
	part.Parent = model

	model.PrimaryPart = part
	model.Parent = workspace

	return model, "CUSTOM"
end

const function CreateModelFromData(
	model: Model | string | BasePart | InstanceHandle?
): (Model | string | BasePart?, string?, InstanceHandle?)
	if not model then
		return
	end

	if type(model) == "string" then
		return model, "CUSTOM"
	end

	if typeof(model) == "InstanceHandle" then
		return model:Get() :: any, "NATIVE", model
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
		const clone = model:Clone()
		if clone then
			(clone :: any).Parent = Holder.GetEntityStorageInstance()
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
