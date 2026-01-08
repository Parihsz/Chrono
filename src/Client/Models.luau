local Shared = script.Parent.Parent.Shared
local Holder = require(Shared.Holder)
local Config = require(Shared.Config)

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

return function(model: Model | string?): (Model?, string?)
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

	if model.Parent == Shared._MIRRORED_MODELS then
		model.Parent = Holder.GetEntityStorageInstance()
		return model, "MIRRORED"
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
			clone.Parent = Holder.GetEntityStorageInstance()
			return clone, "CUSTOM"
		end
		return CreateTempModel()
	end

	return model, "NATIVE"
end
