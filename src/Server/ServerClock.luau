local offsets = {} :: { [Player]: number }

local function Store(player: Player, clientClockTime: number)
	local offset = os.clock() - clientClockTime

	local current = offsets[player]
	if current then
		offsets[player] = current + 0.2 * (offset - current)
	else
		offsets[player] = offset
	end
end

local function ConvertTo(player: Player, clock: number, enviornment: "Server" | "Client")
	local offset = offsets[player]
	if not offset then
		return clock
	end

	if enviornment == "Server" then
		return clock + offset
	else
		return clock - offset
	end
end

local function Remove(player: Player)
	offsets[player] = nil
end

return {
	Store = Store,
	ConvertTo = ConvertTo,
	Remove = Remove,
}
