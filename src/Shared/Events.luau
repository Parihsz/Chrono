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

Signals._DO_NOT_USE_INTERNAL_SET_VALUE_PLEASE_THANKS_HI_THIS_IS_A_BIT_LONG_YEAH_OKAY_BYE_NVM_THIS_IS_USED_CAUSE_RECURSIVE_ERROR_AND_I_AM_TO_LAZY_TO_SOLVE_THAT_SO_THIS_IS_A_BAND_AID_FIX_THAT_WORKS_OKAY =
	Signal.new() :: Signal<(entity: Types.Entity, key: string, value: any) -> (), Types.Entity, string, any>

Events._Signals = Signals
return Events
