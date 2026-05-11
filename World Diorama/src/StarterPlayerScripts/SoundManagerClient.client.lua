local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundManager = require(game.ReplicatedStorage.Modules.SoundManager)
local SoundConfig = require(game.ReplicatedStorage.Modules.SoundConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Инициализация SoundManager
local soundManager = SoundManager:GetInstance()

-- ===== ЗАГРУЗКА EVENTSYSTEM =====
local EventSystem
local maxWaitTime = 15
local waitTime = 0

while (waitTime < maxWaitTime) do
	local success, module = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("EventSystem"))
	end)
	
	if success and module then
		EventSystem = module
		break
	end
	
	task.wait(0.5)
	waitTime = waitTime + 0.5
end

if not EventSystem then
	warn("EventSystem failed to load after waiting " .. maxWaitTime .. " seconds")
	return
end

EventSystem.Init()

-- ===== СЕРВЕРНОЕ СОХРАНЕНИЕ НАСТРОЕК =====
-- Функция отправки текущих настроек на сервер
local function sendSettingsToServer()
	local settings = soundManager:GetSettings()
	EventSystem.FireServer("SaveSettings", {
		musicEnabled = settings.musicEnabled,
		sfxEnabled = settings.sfxEnabled,
		musicVolume = settings.musicVolume,
		sfxVolume = settings.sfxVolume,
	})
end

-- ===== КНОПКА НАСТРОЕК В TOPBAR =====
local topBar = playerGui:WaitForChild("TopBar")
local settingsButton = topBar:WaitForChild("RightButtons"):WaitForChild("SettingsButton")

-- ===== UI ССЫЛКИ =====
local settingsGui = playerGui:WaitForChild("SettingsGui")
local mainContainer = settingsGui:WaitForChild("MainContainer")
local closeButton = mainContainer:WaitForChild("Header"):WaitForChild("CloseButton")

local musicSection = mainContainer:WaitForChild("ContentContainer"):WaitForChild("MusicSection")
local musicToggle = musicSection:WaitForChild("HeaderRow"):WaitForChild("MusicToggle")
local musicSliderBg = musicSection:WaitForChild("SliderRow"):WaitForChild("SliderBg")
local musicSliderFill = musicSliderBg:WaitForChild("SliderFill")
local musicSliderKnob = musicSliderBg:WaitForChild("SliderKnob")
local musicVolumePercent = musicSection:WaitForChild("SliderRow"):WaitForChild("VolumePercent")

local sfxSection = mainContainer:WaitForChild("ContentContainer"):WaitForChild("SFXSection")
local sfxToggle = sfxSection:WaitForChild("HeaderRow"):WaitForChild("SFXToggle")
local sfxSliderBg = sfxSection:WaitForChild("SliderRow"):WaitForChild("SliderBg")
local sfxSliderFill = sfxSliderBg:WaitForChild("SliderFill")
local sfxSliderKnob = sfxSliderBg:WaitForChild("SliderKnob")
local sfxVolumePercent = sfxSection:WaitForChild("SliderRow"):WaitForChild("VolumePercent")

-- ===== ОБНОВЛЕНИЕ UI ИЗ НАСТРОЕК =====
local function updateUI(settings)
	-- Music toggle
	if settings.musicEnabled then
		musicToggle.BackgroundColor3 = Color3.fromRGB(255, 205, 0)
		musicToggle.TextColor3 = Color3.fromRGB(25, 34, 48)
		musicToggle.Text = "ON"
	else
		musicToggle.BackgroundColor3 = Color3.fromRGB(44, 47, 56)
		musicToggle.TextColor3 = Color3.fromRGB(150, 155, 170)
		musicToggle.Text = "OFF"
	end

	-- SFX toggle
	if settings.sfxEnabled then
		sfxToggle.BackgroundColor3 = Color3.fromRGB(255, 205, 0)
		sfxToggle.TextColor3 = Color3.fromRGB(25, 34, 48)
		sfxToggle.Text = "ON"
	else
		sfxToggle.BackgroundColor3 = Color3.fromRGB(44, 47, 56)
		sfxToggle.TextColor3 = Color3.fromRGB(150, 155, 170)
		sfxToggle.Text = "OFF"
	end

	-- Music volume slider
	local musicVol = settings.musicVolume
	musicSliderFill.Size = UDim2.new(musicVol, 0, 1, 0)
	musicSliderKnob.Position = UDim2.new(musicVol, 0, 0.5, 0)
	musicVolumePercent.Text = math.floor(musicVol * 100) .. "%"

	-- SFX volume slider
	local sfxVol = settings.sfxVolume
	sfxSliderFill.Size = UDim2.new(sfxVol, 0, 1, 0)
	sfxSliderKnob.Position = UDim2.new(sfxVol, 0, 0.5, 0)
	sfxVolumePercent.Text = math.floor(sfxVol * 100) .. "%"
end

-- ===== ОТКРЫТИЕ/ЗАКРЫТИЕ МЕНЮ =====
local function openSettings()
	settingsGui.Enabled = true
	updateUI(soundManager:GetSettings())
end

local function closeSettings()
	settingsGui.Enabled = false
end

settingsButton.MouseButton1Click:Connect(openSettings)
closeButton.MouseButton1Click:Connect(closeSettings)

-- ===== TOGGLE КНОПКИ =====
musicToggle.MouseButton1Click:Connect(function()
	local settings = soundManager:GetSettings()
	soundManager:SetMusicEnabled(not settings.musicEnabled)
end)

sfxToggle.MouseButton1Click:Connect(function()
	local settings = soundManager:GetSettings()
	soundManager:SetSFXEnabled(not settings.sfxEnabled)
end)

-- ===== СЛАЙДЕРЫ =====
local function createSliderLogic(sliderBg, sliderKnob, sliderFill, volumePercentLabel, setVolumeCallback)
	local dragging = false

	local function updateSlider(input)
		local relX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
		setVolumeCallback(relX)
	end

	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateSlider(input)
		end
	end)

	sliderBg.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateSlider(input)
		end
	end)
end

createSliderLogic(musicSliderBg, musicSliderKnob, musicSliderFill, musicVolumePercent, function(vol)
	soundManager:SetMusicVolume(vol)
end)

createSliderLogic(sfxSliderBg, sfxSliderKnob, sfxSliderFill, sfxVolumePercent, function(vol)
	soundManager:SetSFXVolume(vol)
end)

-- ===== СЛУШАТЕЛЬ ИЗМЕНЕНИЯ НАСТРОЕК =====
SoundManager.OnSettingsChanged:Connect(function(settings)
	updateUI(settings)
	sendSettingsToServer()
end)

-- ===== ЗАПУСК ФОНОВОЙ МУЗЫКИ =====

-- Загрузка настроек с сервера при запуске
task.spawn(function()
    local serverSettings = nil
    local success = false
    
    -- Запрашиваем пока не получим успешный ответ
    while not success do
        local ok, result = pcall(function()
            return EventSystem.CallRPC("GetSavedSettings")
        end)
        
        if ok and type(result) == "table" then
            success = true
            serverSettings = result
        else
            task.wait(1) -- Ждём 1 секунду перед повторной попыткой
        end
    end
    
    soundManager:LoadFromServer(serverSettings)
    
    -- Остальной код...
    local settings = soundManager:GetSettings()
    if settings.musicEnabled then
        local firstTrack = next(SoundConfig.Music)
        if firstTrack then
            soundManager:PlayMusic(firstTrack)
        end
    end
    
    updateUI(settings)
end)