local Ticker = {}

local Types = require(script.Parent.Types)
type Entity = Types.Entity
type Ticker = Types.Ticker
function Ticker.new(tickRate: number,config:Types.EntityConfig,isHalf:boolean): Ticker
    local ticker = {
        isHalf = isHalf,
        tickRate = tickRate,
        lastTicked = 0,
        tickedTime = 0,
        objects = {},
        config = config,
    }
    return ticker
end

function Ticker.add(ticker: Ticker, object: Entity)
    ticker.objects[object] = true
    object._ticker = ticker
end

function Ticker.remove(ticker: Ticker, object: Entity)
    ticker.objects[object] = nil
    object._ticker = nil
end

function Ticker.move(object: Entity, newTicker: Ticker)
    if object._ticker then
        Ticker.remove(object._ticker, object)
    end
    Ticker.add(newTicker, object)
end

function Ticker.checkUpdate(ticker: Ticker): boolean
    if os.clock() - ticker.lastTicked >= ticker.tickRate then
        ticker.lastTicked = os.clock()
        ticker.tickedTime = time() 
        return true

    end
    return false
end


return Ticker