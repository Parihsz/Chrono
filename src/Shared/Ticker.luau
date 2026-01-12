local Ticker = {}

--//TODO: this should be in server since client don't use it, maybe move later

local function popSwap(t, item, index)
	local lastIndex = #t
	if index ~= lastIndex then
		local lastItem = t[lastIndex]
		t[index] = lastItem
		lastItem._tickerIndex = index
	end
	t[lastIndex] = nil
end

local Types = require(script.Parent.Types)
type Entity = Types.Entity
type Ticker = Types.Ticker

function Ticker.new(config: Types.EntityConfig): Ticker
	local ticker = {
		tickedHalf = false,
		tickHalfRate = config.TICK_RATE * 2,
		tickRate = config.TICK_RATE,
		lastTicked = 0,
		tickedFrame = 0,
		objects = {},
		callbacks = {},
		config = config,
		dt = 0,
		halfdt = 0,
	}
	return ticker
end

function Ticker.AddCallback(ticker: Ticker, callback: (ticker: Ticker, dt: number) -> ())
	table.insert(ticker.callbacks, callback)
end

function Ticker.RemoveCallback(ticker: Ticker, callback: (ticker: Ticker, dt: number) -> ())
	local index = table.find(ticker.callbacks, callback)
	if index then
		table.remove(ticker.callbacks, index)
	end
end

function Ticker.Add(ticker: Ticker, object: Entity)
	table.insert(ticker.objects, object)
	object._ticker = ticker
	object._tickerIndex = #ticker.objects
end

function Ticker.Remove(ticker: Ticker, object: Entity)
	local index = object._tickerIndex
	if not index then
		warn("Ticker.remove called on object not in ticker", object.id)
		return
	end

	popSwap(ticker.objects::any, object, index)

	object._ticker = nil
	object._tickerIndex = nil
end

function Ticker.move(object: Entity, newTicker: Ticker)
	local oldTicker = object._ticker
	if oldTicker then
		Ticker.Remove(oldTicker, object)
	end
	Ticker.Add(newTicker, object)
end

function Ticker.CheckUpdate(ticker: Ticker): boolean
	local difference = os.clock() - ticker.lastTicked

	if difference >= ticker.tickRate then
		ticker.lastTicked = os.clock()
		ticker.tickedFrame = time()
		ticker.tickedHalf = not ticker.tickedHalf

		if ticker.tickedHalf then
			ticker.halfdt = difference + ticker.dt
		else
			ticker.halfdt = difference
		end

		ticker.dt = difference
		if #ticker.callbacks > 0 then
			for _, callback in ticker.callbacks do
				callback(ticker, difference)
			end
		end

		return true
	end

	return false
end

return Ticker
