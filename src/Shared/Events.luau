const Types = require(script.Parent.Types)
const Signal = require(script.Parent.Signal)
type Signal<fx, T...> = Types.Signal<fx, T...>

const Signals = {}
const Events = {}

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

Signals.EntityMountChanged =
	Signal.new() :: Signal<(entity: Types.Entity, mountParentId: number?) -> (), Types.Entity, number?>
Events.EntityMountChanged = Signals.EntityMountChanged.Event

Signals.PlayerLoaded = Signal.new() :: Signal<(player: Player) -> (), Player>

Events._Signals = Signals
return Events
