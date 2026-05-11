local SoundConfig = {
	-- Фоновая музыка
	Music = {
		MainMenu = {
			SoundId = "rbxassetid://140736591220630", -- Заменить
			Looped = true,
		}
	},

	-- Звуковые эффекты
	SFX = {
		CoinCollect = {
			SoundId = "rbxassetid://0", -- Замените на реальный Audio ID
		},
		ButtonClick = {
			SoundId = "rbxassetid://0", -- Замените на реальный Audio ID
		},
		Purchase = {
			SoundId = "rbxassetid://0", -- Замените на реальный Audio ID
		},
		LevelUp = {
			SoundId = "rbxassetid://140732265875950", -- Замените на реальный Audio ID
		},
		Error = {
			SoundId = "rbxassetid://0", -- Замените на реальный Audio ID
		},
	},

	-- Настройки по умолчанию
	Defaults = {
		musicEnabled = true,
		sfxEnabled = true,
		musicVolume = 0.5,
		sfxVolume = 0.8,
	},

	-- Количество Sound объектов в пуле SFX (для одновременного воспроизведения)
	SFXPoolSize = 5,

	-- Длительность кроссфейда при смене трека (секунды)
	CrossfadeDuration = 1.0,

	-- Длительность fade при mute/unmute (секунды)
	FadeDuration = 0.3,
}

return SoundConfig