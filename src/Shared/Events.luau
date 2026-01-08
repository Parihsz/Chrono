local Types = require(script.Parent.Types)
local Signal = require(script.Parent.Signal)
type Signal<fx, T...> = Types.Signal<fx, T...>

local Signals = {}
local Events = {}

Signals.EntityAdded = Signal.new() :: Signal<(entity: Types.Entity) -> (), Types.Entity>
Events.EntityAdded = Signals.EntityAdded.Event

Signals.EntityRemoved = Signal.new() :: Signal<(entity: Types.Entity) -> (), Types.Entity>
Events.EntityRemoved = Signals.EntityRemoved.Event

Signals.PlayerCharacterRegistered =
	Signal.new() :: Signal<(player: Player, entity: Types.Entity) -> (), Player, Types.Entity>
Events.PlayerCharacterRegistered = Signals.PlayerCharacterRegistered.Event

Signals.PlayerCharacterUnregistered =
	Signal.new() :: Signal<(player: Player, entity: Types.Entity) -> (), Player, Types.Entity>
Events.PlayerCharacterUnregistered = Signals.PlayerCharacterUnregistered.Event

Signals.PlayerOwnedAdded = Signal.new() :: Signal<(player: Player, entity: Types.Entity) -> (), Player, Types.Entity>
Events.PlayerOwnedAdded = Signals.PlayerOwnedAdded.Event

Signals.PlayerOwnedRemoved =
	Signal.new() :: Signal<(PrevOwner: Player, entity: Types.Entity) -> (), Player, Types.Entity>
Events.PlayerOwnedRemoved = Signals.PlayerOwnedRemoved.Event

Signals["请不要使用_内部_设置值_拜托谢谢_嗨_这个名字有点长_好吧_再见_算了_这个确实被用了_因为递归错误_而我懒得去解决_所以这是一个能用的_创可贴式修复_好吧"] =
	Signal.new() :: Signal<(entity: Types.Entity, key: string, value: any) -> (), Types.Entity, string, any>

Events._Signals = Signals
return Events
