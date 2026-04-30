local Config = require(script.Parent.Config)

type level = Config.WarningLevels

local function checkLevel(level: level): boolean
	local levels: { [level]: number } = {
		NONE = 0,
		LOW = 1,
		MEDIUM = 2,
		HIGH = 3,
	}
	local currentLevel = levels[Config._GetConfig("WARNING_SEVERITY") :: level] or 0
	if currentLevel == 0 then
		return false
	end
	local checkAgainst = levels[level] or 0
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
