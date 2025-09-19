export type NPC_CONFIG = {
	BUFFER: number,
	TICK_RATE: number,
}

return {
	MIN_BUFFER = 0.09,
	MAX_BUFFER = 0.5,
	TICK_RATE = 1 / 20,

	PROXIMITY = 100,

	ENABLE_CUSTOM_CHARACTERS = false, -- this will disable default roblox replication as well.
	DISABLE_DEFAULT_REPLICATION = true, -- this is if you want to disable the default roblox replication, but still use their controller

	SEND_FULL_ROTATION = false,

	NPC_MODELS = {},

	NPC_TYPES = {
		DEFAULT = {
			TICK_RATE = 1 / 30,
			BUFFER = 0.1,
		},
	},

	PLAYER_MODELS = {},

	--note that warnings are mostly non fatal
	--this will be set to false to optimize output by default, only enable if you're experiencing bugs with the system
	SHOW_WARNINGS = false,
} :: {
	MIN_BUFFER: number,
	MAX_BUFFER: number,
	TICK_RATE: number,

	PROXIMITY: number,

	ENABLE_CUSTOM_CHARACTERS: boolean,
	DISABLE_DEFAULT_REPLICATION: boolean,

	SEND_FULL_ROTATION: boolean,

	NPC_MODELS: { [string]: Model },
	NPC_TYPES: {
		[string]: NPC_CONFIG,
		DEFAULT: NPC_CONFIG,
	},

	PLAYER_MODELS: { [string]: Model },

	SHOW_WARNINGS: boolean,
}
