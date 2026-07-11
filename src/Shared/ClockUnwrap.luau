--!native

const CLOCK_SCALE = 10000
const TWO32 = 2 ^ 32
const TWO31 = 2 ^ 31
const CLOCK_WRAP = TWO32 / CLOCK_SCALE

export type State = { lastRaw: number?, offset: number }
export type Store = { [any]: State }

const ClockUnwrap = {}
ClockUnwrap.SCALE = CLOCK_SCALE
ClockUnwrap.WRAP = CLOCK_WRAP

function ClockUnwrap.quantize(seconds: number): number
	return math.floor(seconds * CLOCK_SCALE) % TWO32
end

function ClockUnwrap.new(): State
	return { lastRaw = nil, offset = 0 }
end

-- for u32
function ClockUnwrap.unwrap(state: State, raw: number): number
	raw %= TWO32
	const lastRaw = state.lastRaw
	if lastRaw then
		const diff = (raw - lastRaw) % TWO32
		if diff < TWO31 then
			if raw < lastRaw then
				state.offset += CLOCK_WRAP
			end
			state.lastRaw = raw
		else
			return (lastRaw + state.offset * CLOCK_SCALE - (TWO32 - diff)) / CLOCK_SCALE
		end
	else
		state.lastRaw = raw
	end
	return raw / CLOCK_SCALE + state.offset
end

function ClockUnwrap.unwrapFor(store: Store, key: any, raw: number): number
	local state = store[key]
	if not state then
		state = ClockUnwrap.new()
		store[key] = state
	end
	return ClockUnwrap.unwrap(state, raw)
end

-- for f64 syncing
function ClockUnwrap.seatFull(state: State, seconds: number): number
	const scaled = math.floor(seconds * CLOCK_SCALE)
	const raw = scaled % TWO32
	state.lastRaw = raw
	state.offset = (scaled - raw) / CLOCK_SCALE
	return scaled / CLOCK_SCALE
end

function ClockUnwrap.seatFullFor(store: Store, key: any, seconds: number): number
	local state = store[key]
	if not state then
		state = ClockUnwrap.new()
		store[key] = state
	end
	return ClockUnwrap.seatFull(state, seconds)
end

return ClockUnwrap
