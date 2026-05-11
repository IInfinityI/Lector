-- GoldEffectClient (LocalScript)
-- Показывает анимированный эффект +N золота при любом получении золота игроком

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LoadingScreen = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LoadingScreen"))
LoadingScreen.WaitForLoad()

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Загрузка EventSystem
local EventSystem = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("EventSystem"))
EventSystem.Init()

-- GUI элементы
local GoldEffectGui = PlayerGui:WaitForChild("GoldEffect")
local EffectText = GoldEffectGui:WaitForChild("EffectText")

-- Состояние
local lastKnownGold = nil -- для отслеживания дельты через UpdateGold
local isShowing = false
local pendingAmount = 0
local effectThread = nil

-- Настройки анимации
local FADE_IN_DURATION = 0.25
local HOLD_DURATION = 1.2
local FADE_OUT_DURATION = 0.6
local RISE_OFFSET = 30 -- пикселей подъёма

-- Исходная позиция EffectText
local BASE_POSITION = EffectText.Position
local RISE_POSITION = UDim2.new(
	BASE_POSITION.X.Scale, BASE_POSITION.X.Offset,
	BASE_POSITION.Y.Scale, BASE_POSITION.Y.Offset - RISE_OFFSET
)

-- Функция форматирования чисел
local function formatGoldNumber(num)
	if num >= 1000000 then
		return string.format("%.1fM", num / 1000000)
	elseif num >= 1000 then
		return string.format("%.1fK", num / 1000)
	end
	return tostring(math.floor(num))
end

-- Основная функция показа эффекта
local function showGoldEffect(amount)
	if amount <= 0 then return end

	-- Если эффект уже показывается, суммируем
	if isShowing then
		pendingAmount = pendingAmount + amount
		-- Обновляем текст на лету
		EffectText.Text = string.format("+%s gold!", formatGoldNumber(pendingAmount))
		return
	end

	isShowing = true
	pendingAmount = amount

	-- Запускаем в отдельном потоке, чтобы не блокировать события
	if effectThread then
		task.cancel(effectThread)
	end

	effectThread = task.spawn(function()
		-- Устанавливаем текст
		EffectText.Text = string.format("+%s gold!", formatGoldNumber(pendingAmount))

		-- Сбрасываем позицию и прозрачность
		EffectText.Position = BASE_POSITION
		EffectText.TextTransparency = 1
		EffectText.TextStrokeTransparency = 1

		-- Включаем GUI
		GoldEffectGui.Enabled = true

		-- Fade in
		local fadeInTween = TweenService:Create(EffectText, TweenInfo.new(FADE_IN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 0,
			TextStrokeTransparency = 0,
		})
		fadeInTween:Play()
		fadeInTween.Completed:Wait()

		-- Удержание (продлеваем, если пришло ещё золото)
		local holdStart = os.clock()
		while os.clock() - holdStart < HOLD_DURATION do
			-- Если pendingAmount изменился, обновляем текст и продлеваем
			local currentDisplay = pendingAmount
			EffectText.Text = string.format("+%s gold!", formatGoldNumber(currentDisplay))
			task.wait(0.1)
		end

		-- Fade out + подъём
		local fadeOutTween = TweenService:Create(EffectText, TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Position = RISE_POSITION,
		})
		fadeOutTween:Play()
		fadeOutTween.Completed:Wait()

		-- Сброс
		GoldEffectGui.Enabled = false
		EffectText.Position = BASE_POSITION
		isShowing = false

		-- Если за время анимации накопилось ещё золото — показать
		if pendingAmount > 0 then
			-- pendingAmount уже учтён в текущем показе, сбрасываем
		end
		pendingAmount = 0
	end)
end

-- ================================================================
-- Подписка на все события получения золота
-- ================================================================

-- 1. GoldCollected — сбор накопленного золота из хранилища
EventSystem.OnClient("GoldCollected", function(amount, bonuses)
	if amount and amount > 0 then
		showGoldEffect(amount)
	end
end)

-- 2. ClaimQuestResponse — награда за квест
EventSystem.OnClient("ClaimQuestResponse", function(questId, success, info, reward)
	if success and reward and reward.gold and reward.gold > 0 then
		showGoldEffect(reward.gold)
	end
end)

-- 3. LevelRewardReceived — награда за уровень
EventSystem.OnClient("LevelRewardReceived", function(reward)
	if reward and reward.type == "gold" and reward.amount and reward.amount > 0 then
		showGoldEffect(reward.amount)
	end
end)

-- 4. PrestigeComplete — перерождение
EventSystem.OnClient("PrestigeComplete", function(prestigeLevel, multiplier, goldEarned, dioramaGoldBonus, donationBonus, statsBonus)
	if goldEarned and goldEarned > 0 then
		showGoldEffect(goldEarned)
	end
end)

-- 5. PendingGoldReceived — отложенное золото с проданной диорамы
EventSystem.OnClient("PendingGoldReceived", function(data)
	if data and data.amount and data.amount > 0 then
		showGoldEffect(data.amount)
	end
end)

-- 6. DailyRewardClaimed — ежедневная награда
EventSystem.OnClient("DailyRewardClaimed", function(groupName, result)
	if result then
		local goldAmount = 0
		-- result может быть таблицей с полем Gold или наградой
		if type(result) == "table" then
			goldAmount = result.Gold or result.gold or 0
			-- Если result содержит rewards — ищем Gold там
			if goldAmount == 0 and result.rewards then
				for _, reward in ipairs(result.rewards) do
					if type(reward) == "table" then
						goldAmount = goldAmount + (reward.Gold or reward.gold or 0)
					end
				end
			end
		elseif type(result) == "number" then
			goldAmount = result
		end
		if goldAmount > 0 then
			showGoldEffect(goldAmount)
		end
	end
end)

-- 7. UpdateGold — универсальное обновление золота (отслеживание дельты)
-- Это покрывает CollectIncome с диорам и другие неявные источники
EventSystem.OnClient("UpdateGold", function(newGold)
	if lastKnownGold ~= nil and newGold ~= nil then
		local delta = newGold - lastKnownGold
		if delta > 0 then
			showGoldEffect(delta)
		end
	end
	lastKnownGold = newGold
end)

-- Инициализация начального значения золота
-- Читаем текущее золото из SavedData на игроке
task.spawn(function()
	task.wait(2) -- ждём загрузки
	local savedData = Player:FindFirstChild("SavedData")
	if savedData then
		local goldValue = savedData:FindFirstChild("Gold")
		if goldValue then
			lastKnownGold = goldValue.Value
		end
	end
end)

-- Также обновляем lastKnownGold из GoldGUIInitialData и GoldGUIUpdate,
-- чтобы дельта через UpdateGold не дублировала эффект от уже обработанных событий
EventSystem.OnClient("GoldGUIInitialData", function(guiData)
	if guiData and guiData.gold then
		lastKnownGold = guiData.gold
	end
end)

EventSystem.OnClient("GoldGUIUpdate", function(guiData)
	if guiData and guiData.gold then
		lastKnownGold = guiData.gold
	end
end)

print("[GoldEffectClient] Loaded and subscribed to all gold received events")