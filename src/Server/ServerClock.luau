const Players = game:GetService("Players")
const ServerClockData = {} :: { [Player]: {
	clockOffset: number,
	oneWayDelay: number,
} }

const function Store(player: Player, clientClockTime: number, clientServerTimeNow: number?)
	local data = ServerClockData[player]
	if not data then
		data = { clockOffset = 0, oneWayDelay = 0.05 }
		ServerClockData[player] = data
	end

	if clientServerTimeNow then
		const latency = workspace:GetServerTimeNow() - clientServerTimeNow
		if latency > 0 and latency <= player:GetNetworkPing() + 0.05 then
			data.oneWayDelay = latency
		end
	end

	const ping = math.max(player:GetNetworkPing(), 0) + 0.05 -- network ping was 0 for some reason
	const measuredClockOffset = os.clock() - clientClockTime - math.clamp(data.oneWayDelay, 0, ping)

	data.clockOffset = data.clockOffset + 0.2 * (measuredClockOffset - data.clockOffset)
end

const function ConvertTo(player: Player, clock: number, environment: "Server" | "Client")
	const data = ServerClockData[player]
	if not data then
		return clock
	end

	if environment == "Server" then
		return clock + data.clockOffset
	else
		return clock - data.clockOffset
	end
end

const function Remove(player: Player)
	ServerClockData[player] = nil
end

Players.PlayerRemoving:Connect(Remove)

return {
	Store = Store,
	ConvertTo = ConvertTo,
	Remove = Remove,
}
