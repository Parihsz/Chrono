const Config = require(script.Parent.Config)

type level = Config.WarningLevels

const function checkLevel(level: level): boolean
	const levels: { [level]: number } = {
		NONE = 0,
		LOW = 1,
		MEDIUM = 2,
		HIGH = 3,
	}
	const currentLevel = levels[Config._GetConfig("WARNING_SEVERITY") :: level] or 0
	if currentLevel == 0 then
		return false
	end
	const checkAgainst = levels[level] or 0
	return currentLevel <= checkAgainst
end

return (
	setmetatable({}, {
		__index = function(_, level: level)
			if not checkLevel(level:upper()) then
				return function() end
			end
			return warn
		end,
	}) :: any
) :: {
	low: (...any) -> (),
	medium: (...any) -> (),
	high: (...any) -> (),
}
