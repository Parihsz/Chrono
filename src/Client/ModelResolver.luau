const CollectionService = game:GetService("CollectionService")

const Warn = require(script.Parent.Parent.Shared.Warn)
const Config = require(script.Parent.Parent.Shared.Config)
const Types = require(script.Parent.Parent.Shared.Types)
const Entity = require(script.Parent.Parent.Shared.Entity)
const ModelHelper = require(script.Parent.Parent.Shared.ModelHelper)
const TAG = ModelHelper.TAG
const CHRONO_META_NAME = ModelHelper.CHRONO_META_NAME

const RegisteredModels = {}

const function OnInstanceAdded(instance: Instance)
	const metaStringValue: string? = instance:GetAttribute(CHRONO_META_NAME) :: any
	if metaStringValue then
		RegisteredModels[metaStringValue] = instance.Parent :: any
		Warn.low(
			`Model with meta {metaStringValue} was added to the game. Entities using this model will now be able to resolve it.`
		)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(OnInstanceAdded)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
	const attribute: string? = instance:GetAttribute(CHRONO_META_NAME) :: any
	if attribute then
		RegisteredModels[attribute] = nil
		Warn.low(
			`Model with meta {attribute} was removed from the game. Entities using this model will no longer be able to resolve it.`
		)
	end
end)
for _, instance in CollectionService:GetTagged(TAG) do
	OnInstanceAdded(instance)
end

return function(entity: Types.Entity)
	const model = entity.model

	if model and model.Parent then
		return
	end

	const metaData = entity._modelMetaData
	if not metaData then
		return
	end
	const registered = RegisteredModels[metaData] :: Model | BasePart?
	if registered and registered ~= model then
		Entity.SetModel(entity, registered)
		Warn.low(`Model with meta {metaData} was resolved for entity {entity.id}.`)
	end
end
