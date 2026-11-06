const Ticker = {}

const function popSwap(t, item, index)
	const lastIndex = #t
	if index ~= lastIndex then
		const lastItem = t[lastIndex]
		t[index] = lastItem
		lastItem._tickerIndex = index
	end
	t[lastIndex] = nil
end

const Types = require(script.Parent.Types)
const Warn = require(script.Parent.Warn)
const Signal = require(script.Parent.Signal)
type Entity = Types.Entity
type Ticker = Types.Ticker

local GlobalTick = 0

function Ticker._IncrementGlobalTick()
	GlobalTick += 1
end

function Ticker.GetGlobalTick()
	return GlobalTick
end

function Ticker.new(config: Types.EntityConfig): Ticker
	-- Tickers holds full and half tick rate so entities don't constantly swap 
	const ticked: Types.Signal<(ticker: Ticker, dt: number) -> (), Ticker, number> = Signal.new()
	const ticker = {
		isHalf = false,
		tickHalfRate = config.TICK_RATE * 2,
		tickRate = config.TICK_RATE,
		lastTicked = os.clock(),
		tickedFrame = 0,
		objects = {},
		Ticked = ticked.Event,
		_tickedSignal = ticked,
		config = config,
		dt = 0,
		halfdt = 0,
	}
	return ticker
end

function Ticker.Add(ticker: Ticker, object: Entity)
	table.insert(ticker.objects, object)
	object._ticker = ticker
	object._tickerIndex = #ticker.objects
end

function Ticker.Remove(ticker: Ticker, object: Entity)
	const index = object._tickerIndex
	if not index then
		Warn.low("Ticker.remove called on object not in ticker", object.id)
		return
	end

	popSwap(ticker.objects :: any, object, index)

	object._ticker = nil
	object._tickerIndex = nil
end

function Ticker.move(object: Entity, newTicker: Ticker)
	const oldTicker = object._ticker
	if oldTicker then
		Ticker.Remove(oldTicker, object)
	end
	Ticker.Add(newTicker, object)
end

function Ticker.CheckUpdate(ticker: Ticker): boolean
	const now = os.clock()
	if not next(ticker.objects) and not ticker._tickedSignal:HasListeners() then
		ticker.lastTicked = now
		ticker.dt = 0
		ticker.halfdt = 0
		return false
	end
	const difference = now - ticker.lastTicked

	if difference >= ticker.tickRate then
		ticker.lastTicked = now
		ticker.tickedFrame = GlobalTick
		ticker.isHalf = not ticker.isHalf

		if ticker.isHalf then
			ticker.halfdt = difference + ticker.dt
		else
			ticker.halfdt = difference
		end

		ticker.dt = difference
		ticker._tickedSignal:Fire(ticker, difference)

		return true
	end

	return false
end

return Ticker
