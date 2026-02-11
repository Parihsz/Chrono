local ServerClockData = {} :: { [Player]: {
	clockOffset: number,
	oneWayDelay: number,
} }

local function Store(player: Player, clientClockTime: number, clientServerTimeNow: number?)
	local data = ServerClockData[player]
	if not data then
		data = { clockOffset = 0, oneWayDelay = 0.05 }
		ServerClockData[player] = data
	end

	if clientServerTimeNow then
		local latency = workspace:GetServerTimeNow() - clientServerTimeNow
		if latency > 0 and latency <= player:GetNetworkPing() + 0.05 then
			data.oneWayDelay = latency
		end
	end

	local measuredClockOffset = os.clock()
		- clientClockTime
		- math.clamp(data.oneWayDelay, 0, player:GetNetworkPing() + 0.05)

	data.clockOffset = data.clockOffset + 0.2 * (measuredClockOffset - data.clockOffset)
end

local function ConvertTo(player: Player, clock: number, environment: "Server" | "Client")
	local data = ServerClockData[player]
	if not data then
		return clock
	end

	if environment == "Server" then
		return clock + data.clockOffset
	else
		return clock - data.clockOffset
	end
end

local function Remove(player: Player)
	ServerClockData[player] = nil
end

return {
	Store = Store,
	ConvertTo = ConvertTo,
	Remove = Remove,
}
