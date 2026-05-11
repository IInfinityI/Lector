local SoundConfig = require(script.Parent.SoundConfig)
local Players = game:GetService("Players")

local SoundManager = {}
SoundManager.__index = SoundManager

-- Сигнал изменения настроек (простая реализация через BindableEvent)
local settingsChangedEvent = Instance.new("BindableEvent")
SoundManager.OnSettingsChanged = settingsChangedEvent.Event

local instance = nil

function SoundManager.new()
	local self = setmetatable({}, SoundManager)

	self._player = Players.LocalPlayer
	self._playerGui = self._player:WaitForChild("PlayerGui")

	-- Текущие настройки
	self._settings = {
		musicEnabled = SoundConfig.Defaults.musicEnabled,
		sfxEnabled = SoundConfig.Defaults.sfxEnabled,
		musicVolume = SoundConfig.Defaults.musicVolume,
		sfxVolume = SoundConfig.Defaults.sfxVolume,
	}

	-- Sound объекты
	self._musicPlayer = nil
	self._musicPlayerFade = nil -- второй плеер для кроссфейда
	self._sfxPool = {}
	self._sfxIndex = 1

	-- Текущий трек
	self._currentTrack = nil

	-- Загрузить сохранённые настройки
	self:_loadSettings()

	-- Создать Sound объекты
	self:_createSounds()

	return self
end

function SoundManager:GetInstance()
	if not instance then
		instance = SoundManager.new()
	end
	return instance
end

-- Создание Sound объектов
function SoundManager:_createSounds()
	local soundsFolder = Instance.new("Folder")
	soundsFolder.Name = "Sounds"
	soundsFolder.Parent = self._playerGui

	-- Основной плеер музыки
	self._musicPlayer = Instance.new("Sound")
	self._musicPlayer.Name = "MusicPlayer"
	self._musicPlayer.Looped = true
	self._musicPlayer.Volume = self._settings.musicEnabled and self._settings.musicVolume or 0
	self._musicPlayer.Parent = soundsFolder

	-- Второй плеер для кроссфейда
	self._musicPlayerFade = Instance.new("Sound")
	self._musicPlayerFade.Name = "MusicPlayerFade"
	self._musicPlayerFade.Looped = true
	self._musicPlayerFade.Volume = 0
	self._musicPlayerFade.Parent = soundsFolder

	-- Пул SFX
	for i = 1, SoundConfig.SFXPoolSize do
		local sfx = Instance.new("Sound")
		sfx.Name = "SFXPlayer_" .. i
		sfx.Volume = self._settings.sfxVolume
		sfx.Parent = soundsFolder
		table.insert(self._sfxPool, sfx)
	end
end

-- Загрузка настроек из UserSettings
function SoundManager:_loadSettings()
	local success, result = pcall(function()
		local userSettings = UserSettings()
		local gameSettings = userSettings:GetService("UserGameSettings")
		return gameSettings
	end)

	if not success then
		return
	end

	-- Используем атрибуты на PlayerGui для хранения настроек (простой способ)
	local savedMusicEnabled = self._playerGui:GetAttribute("SoundMusicEnabled")
	local savedSfxEnabled = self._playerGui:GetAttribute("SoundSfxEnabled")
	local savedMusicVolume = self._playerGui:GetAttribute("SoundMusicVolume")
	local savedSfxVolume = self._playerGui:GetAttribute("SoundSfxVolume")

	if savedMusicEnabled ~= nil then
		self._settings.musicEnabled = savedMusicEnabled
	end
	if savedSfxEnabled ~= nil then
		self._settings.sfxEnabled = savedSfxEnabled
	end
	if savedMusicVolume ~= nil then
		self._settings.musicVolume = savedMusicVolume
	end
	if savedSfxVolume ~= nil then
		self._settings.sfxVolume = savedSfxVolume
	end
end

-- Загрузка настроек с сервера (вызывается из SoundManagerClient)
function SoundManager:LoadFromServer(serverSettings)
	if type(serverSettings) ~= "table" then return end

	if serverSettings.musicEnabled ~= nil then
		self._settings.musicEnabled = serverSettings.musicEnabled
	end
	if serverSettings.sfxEnabled ~= nil then
		self._settings.sfxEnabled = serverSettings.sfxEnabled
	end
	if serverSettings.musicVolume ~= nil then
		self._settings.musicVolume = math.clamp(serverSettings.musicVolume, 0, 1)
	end
	if serverSettings.sfxVolume ~= nil then
		self._settings.sfxVolume = math.clamp(serverSettings.sfxVolume, 0, 1)
	end

	-- Обновляем громкость звуков
	if self._musicPlayer and self._settings.musicEnabled then
		self._musicPlayer.Volume = self._settings.musicVolume
	end
	for _, sfx in self._sfxPool do
		sfx.Volume = self._settings.sfxVolume
	end

	self:_saveSettings()
	settingsChangedEvent:Fire(self._settings)
end

-- Сохранение настроек
function SoundManager:_saveSettings()
	self._playerGui:SetAttribute("SoundMusicEnabled", self._settings.musicEnabled)
	self._playerGui:SetAttribute("SoundSfxEnabled", self._settings.sfxEnabled)
	self._playerGui:SetAttribute("SoundMusicVolume", self._settings.musicVolume)
	self._playerGui:SetAttribute("SoundSfxVolume", self._settings.sfxVolume)
end

-- Плавное изменение громкости
function SoundManager:_tweenVolume(sound, targetVolume, duration)
	if not sound then return end

	local startVolume = sound.Volume
	local startTime = tick()

	task.spawn(function()
		while true do
			local elapsed = tick() - startTime
			local alpha = math.clamp(elapsed / duration, 0, 1)

			sound.Volume = startVolume + (targetVolume - startVolume) * alpha

			if alpha >= 1 then
				break
			end

			task.wait(0.03)
		end

		-- Если целевая громкость 0 — остановить звук
		if targetVolume <= 0 then
			sound:Stop()
		end
	end)
end

-- Воспроизведение фоновой музыки (с кроссфейдом)
function SoundManager:PlayMusic(trackName)
	local trackConfig = SoundConfig.Music[trackName]
	if not trackConfig then
		warn("[SoundManager] Трек не найден: " .. tostring(trackName))
		return
	end

	-- Если тот же трек уже играет — ничего не делать
	if self._currentTrack == trackName and self._musicPlayer.IsPlaying then
		return
	end

	self._currentTrack = trackName

	local targetVolume = self._settings.musicEnabled and self._settings.musicVolume or 0

	-- Кроссфейд: текущий плеер затухает, новый на втором плеере нарастает
	if self._musicPlayer.IsPlaying then
		-- Переключаем роли плееров
		self._musicPlayer, self._musicPlayerFade = self._musicPlayerFade, self._musicPlayer

		-- Затухание старого трека
		self:_tweenVolume(self._musicPlayerFade, 0, SoundConfig.CrossfadeDuration)
	end

	-- Настройка и запуск нового трека
	self._musicPlayer.SoundId = trackConfig.SoundId
	self._musicPlayer.Looped = trackConfig.Looped ~= false
	self._musicPlayer.Volume = 0
	self._musicPlayer:Play()

	-- Нарастание громкости
	self:_tweenVolume(self._musicPlayer, targetVolume, SoundConfig.CrossfadeDuration)
end

-- Остановка музыки
function SoundManager:StopMusic()
	self._currentTrack = nil

	if self._musicPlayer.IsPlaying then
		self:_tweenVolume(self._musicPlayer, 0, SoundConfig.FadeDuration)
	end
	if self._musicPlayerFade.IsPlaying then
		self:_tweenVolume(self._musicPlayerFade, 0, SoundConfig.FadeDuration)
	end
end

-- Воспроизведение звукового эффекта
function SoundManager:PlaySFX(soundName)
	if not self._settings.sfxEnabled then return end

	local sfxConfig = SoundConfig.SFX[soundName]
	if not sfxConfig then
		warn("[SoundManager] Звук не найден: " .. tostring(soundName))
		return
	end

	-- Берём следующий Sound из пула (round-robin)
	local sfx = self._sfxPool[self._sfxIndex]
	self._sfxIndex = (self._sfxIndex % SoundConfig.SFXPoolSize) + 1

	-- Если текущий Sound занят — создаём временный
	if sfx.IsPlaying then
		sfx = Instance.new("Sound")
		sfx.Name = "SFX_Temp"
		sfx.Parent = self._musicPlayer.Parent

		sfx.Ended:Once(function()
			sfx:Destroy()
		end)
	end

	sfx.SoundId = sfxConfig.SoundId
	sfx.Volume = self._settings.sfxVolume
	sfx:Play()
end

-- Включение/выключение музыки
function SoundManager:SetMusicEnabled(enabled)
	self._settings.musicEnabled = enabled

	if enabled then
		-- Возобновить музыку если трек был установлен
		if self._currentTrack and not self._musicPlayer.IsPlaying then
			self._musicPlayer.Volume = 0
			self._musicPlayer:Play()
			self:_tweenVolume(self._musicPlayer, self._settings.musicVolume, SoundConfig.FadeDuration)
		elseif self._musicPlayer.IsPlaying then
			self:_tweenVolume(self._musicPlayer, self._settings.musicVolume, SoundConfig.FadeDuration)
		else
			-- Музыка была выключена при загрузке, трек не установлен — запускаем первый доступный
			local firstTrack = next(SoundConfig.Music)
			if firstTrack then
				self:PlayMusic(firstTrack)
			end
		end
	else
		-- Затухание
		if self._musicPlayer.IsPlaying then
			self:_tweenVolume(self._musicPlayer, 0, SoundConfig.FadeDuration)
		end
		if self._musicPlayerFade.IsPlaying then
			self:_tweenVolume(self._musicPlayerFade, 0, SoundConfig.FadeDuration)
		end
	end

	self:_saveSettings()
	settingsChangedEvent:Fire(self._settings)
end

-- Включение/выключение звуков
function SoundManager:SetSFXEnabled(enabled)
	self._settings.sfxEnabled = enabled

	if not enabled then
		-- Остановить все текущие SFX
		for _, sfx in self._sfxPool do
			if sfx.IsPlaying then
				sfx:Stop()
			end
		end
	end

	self:_saveSettings()
	settingsChangedEvent:Fire(self._settings)
end

-- Установка громкости музыки
function SoundManager:SetMusicVolume(volume)
	self._settings.musicVolume = math.clamp(volume, 0, 1)

	if self._settings.musicEnabled and self._musicPlayer.IsPlaying then
		self._musicPlayer.Volume = self._settings.musicVolume
	end

	self:_saveSettings()
	settingsChangedEvent:Fire(self._settings)
end

-- Установка громкости звуков
function SoundManager:SetSFXVolume(volume)
	self._settings.sfxVolume = math.clamp(volume, 0, 1)

	-- Обновить громкость для будущих SFX
	for _, sfx in self._sfxPool do
		sfx.Volume = self._settings.sfxVolume
	end

	self:_saveSettings()
	settingsChangedEvent:Fire(self._settings)
end

-- Получить текущие настройки
function SoundManager:GetSettings()
	return {
		musicEnabled = self._settings.musicEnabled,
		sfxEnabled = self._settings.sfxEnabled,
		musicVolume = self._settings.musicVolume,
		sfxVolume = self._settings.sfxVolume,
	}
end

return SoundManager