const Players = game:GetService("Players")
const Types = require(script.Parent.Parent.Shared.Types)


const ServerClockData = {} :: { [Player]: {
	arrivalOffset: number,
} }

const SMOOTHING = 0.2
const DEFAULT_MAX_REWIND = 1

const function Store(player: Player, clientClockTime: number)
	const measured = os.clock() - clientClockTime
	const data = ServerClockData[player]
	if not data then
		ServerClockData[player] = { arrivalOffset = measured }
		return
	end
	data.arrivalOffset += SMOOTHING * (measured - data.arrivalOffset)
end

const function ConvertTo(player: Player, clock: number, environment: "Server" | "Client")
	const data = ServerClockData[player]
	if not data then
		return clock
	end

	if environment == "Server" then
		return clock + data.arrivalOffset
	else
		return clock - data.arrivalOffset
	end
end

--[=[
	Converts a client's render time for an entity 
	into the server's timeline, ready for Entity.GetAt. Clamped to the last maxRewind seconds.

	@param maxRewind How far back to allow, in seconds. Defaults to 1.
]=]
const function ToServerTime(entity: Types.Entity?, renderTime: number, maxRewind: number?): number?
	if not entity or type(renderTime) ~= "number" or renderTime ~= renderTime then
		return nil
	end
	local serverTime = renderTime
	const owner = entity.networkOwner
	if owner then
		const data = ServerClockData[owner]
		if not data then
			return nil
		end
		serverTime += data.arrivalOffset
	end
	local window = maxRewind or DEFAULT_MAX_REWIND
	if not (window >= 0) then -- negative or NaN
		window = DEFAULT_MAX_REWIND
	end
	const now = os.clock()
	return math.clamp(serverTime, now - window, now)
end

const function Remove(player: Player)
	ServerClockData[player] = nil
end

Players.PlayerRemoving:Connect(Remove)

return {
	Store = Store,
	ConvertTo = ConvertTo,
	ToServerTime = ToServerTime,
	Remove = Remove,
}
