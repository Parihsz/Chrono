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

const function noop(...: any) end
const warnAny: (...any) -> () = warn

-- Designed it this way so the first message leads to the place the function was called.
return (
	setmetatable({}, {
		__index = function(_, level: level): (...any) -> ()
			if not checkLevel(level:upper() :: any) then
				return noop
			end
			return warnAny
		end,
	}) :: any
) :: {
	low: (...any) -> (),
	medium: (...any) -> (),
	high: (...any) -> (),
}
