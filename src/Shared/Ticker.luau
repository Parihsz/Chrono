local Ticker = {}

--//TODO: this should be in server since client don't use it, maybe move later

local function popSwap(t, item, index)
	local lastIndex = #t
	if index ~= lastIndex then
		t[index] = t[lastIndex]
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
		config = config,
	}
	return ticker
end

function Ticker.add(ticker: Ticker, object: Entity)
	table.insert(ticker.objects, object)
	object._ticker = ticker
	object._tickerIndex = #ticker.objects
end

function Ticker.remove(ticker: Ticker, object: Entity)
	local index = object._tickerIndex
	if not index then
		warn("Ticker.remove called on object not in ticker", object.id)
		return
	end
	popSwap(ticker.objects, object, index)
	object._ticker = nil
	object._tickerIndex = nil
end

function Ticker.move(object: Entity, newTicker: Ticker)
	local oldTicker = object._ticker
	if oldTicker then
		Ticker.remove(oldTicker, object)
	end
	Ticker.add(newTicker, object)
end

function Ticker.checkUpdate(ticker: Ticker): boolean
	if os.clock() - ticker.lastTicked >= ticker.tickRate then
		ticker.lastTicked = os.clock()
		ticker.tickedFrame = time() 
		ticker.tickedHalf = not ticker.tickedHalf
		return true
	end
	return false
end

return Ticker
