const Warn = require(script.Parent.Parent.Shared.Warn)
const Types = require(script.Parent.Parent.Shared.Types)
const Entity = require(script.Parent.Parent.Shared.Entity)

-- checks if models have been resolved for entities and sets them if they have
return function(entity: Types.Entity)
	const handle = entity._modelHandle
	const model = entity.model
	if not handle or (model and model.Parent) then
		return
	end

	const instance: (Model | BasePart)? = handle:Get() :: any
	if instance and instance.Parent and instance ~= model then
		Entity.SetModel(entity, instance)
		Warn.low(`Model {instance:GetFullName()} was resolved for entity {entity.id}.`)
	end
end
