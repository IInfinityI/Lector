-- DailyRewardsClient - Клиентский скрипт для ежедневных наград
-- Использует EventSystem для взаимодействия с сервером
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- GUI элементы
local dailyRewardsGui = playerGui:WaitForChild("DailyRewardsGui")
local mainFrame = dailyRewardsGui:WaitForChild("MainFrame")
local header = mainFrame:WaitForChild("Header")
local closeButton = header:WaitForChild("CloseButton")
local contentContainer = mainFrame:WaitForChild("ContentContainer")
local defaultSection = contentContainer:WaitForChild("DefaultSection")
local premiumSection = contentContainer:WaitForChild("PremiumSection")
local claimButton = contentContainer:WaitForChild("ClaimButton")
local timerLabel = contentContainer:WaitForChild("TimerLabel")
local dayTemplate = contentContainer:WaitForChild("Day_template")

-- Загрузка EventSystem
local EventSystem
local maxWaitTime = 15
local waitTime = 0

while waitTime < maxWaitTime do
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
	warn("[DailyRewardsClient] EventSystem не удалось загрузить")
	return
end

EventSystem.Init()

-- Состояние
local rewardsData = nil
local isGuiOpen = false
local timerRunning = false
local nextRewardTime = nil -- os.time() когда награда станет доступна

-- Цвета
local COLORS = {
	background = Color3.fromRGB(25, 34, 48),
	cardBackground = Color3.fromRGB(25, 34, 48),
	cardClaimed = Color3.fromRGB(20, 25, 40),
	cardCurrent = Color3.fromRGB(18, 30, 55),
	cardLocked = Color3.fromRGB(25, 34, 48),
	strokeDefault = Color3.fromRGB(44, 47, 56),
	strokeClaimed = Color3.fromRGB(80, 80, 80),
	strokeCurrent = Color3.fromRGB(62, 255, 158),
	strokeLocked = Color3.fromRGB(44, 47, 56),
	textPrimary = Color3.fromRGB(200, 211, 230),
	textSecondary = Color3.fromRGB(126, 136, 168),
	textGold = Color3.fromRGB(255, 206, 0),
	textGreen = Color3.fromRGB(62, 255, 158),
	textGray = Color3.fromRGB(100, 100, 100),
	buttonActive = Color3.fromRGB(255, 206, 0),
	buttonInactive = Color3.fromRGB(44, 47, 56),
	buttonPremium = Color3.fromRGB(100, 80, 200),
}

-- Функция форматирования оставшегося времени
local function formatTimeRemaining(seconds)
	if seconds <= 0 then return "00:00:00" end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Функция форматирования чисел
local function formatNumber(num)
	if num >= 1000000 then
		return string.format("%.1fM", num / 1000000)
	elseif num >= 1000 then
		return string.format("%.1fK", num / 1000)
	end
	return tostring(math.floor(num))
end

-- Функция описания награды
local function getRewardDescription(reward)
	if not reward then return "—" end
	local parts = {}
	for key, value in pairs(reward) do
		if key ~= "Modifiers" then
			if type(value) == "number" then
				if key == "Gold" then
					table.insert(parts, "💰" .. formatNumber(value))
				elseif key == "PurchaseBanTickets" then
					table.insert(parts, "🎫" .. formatNumber(value))
				else
					table.insert(parts, key .. ": " .. formatNumber(value))
				end
			end
		end
	end
	if reward.Modifiers then
		for _, mod in ipairs(reward.Modifiers) do
			table.insert(parts, "+" .. string.format("%.0f", (mod.Value - 1) * 100) .. "% " .. mod.Type)
		end
	end
	return table.concat(parts, ", ")
end

-- Функция сбора всех числовых наград
local function getRewardEntries(reward)
	if not reward then return {} end
	local entries = {}
	for key, value in pairs(reward) do
		if key ~= "Modifiers" and type(value) == "number" then
			table.insert(entries, {key = key, value = value})
		end
	end
	table.sort(entries, function(a, b) return a.key < b.key end)
	return entries
end

-- Создание ячейки награды из шаблона
local function createRewardItem(day, reward, status, isCurrentDay)
	local item = dayTemplate:Clone()
	item.Name = "Day_" .. day
	item.LayoutOrder = day
	item.Visible = true

	-- Определяем статус
	local isClaimed = day < (status.currentDay or 1)
	local isAvailable = isCurrentDay and status.canClaim

	-- Фон
	if isClaimed then
		item.BackgroundColor3 = COLORS.cardClaimed
	elseif isAvailable then
		item.BackgroundColor3 = COLORS.cardCurrent
	else
		item.BackgroundColor3 = COLORS.cardLocked
	end

	-- Обводка
	local stroke = item:FindFirstChild("UIStroke")
	if stroke then
		if isClaimed then
			stroke.Color = COLORS.strokeClaimed
			stroke.Thickness = 1
		elseif isAvailable then
			stroke.Color = COLORS.strokeCurrent
			stroke.Thickness = 2
		else
			stroke.Color = COLORS.strokeLocked
			stroke.Thickness = 1
		end
	end

	-- День
	local dayLabel = item:FindFirstChild("DayLabel")
	if dayLabel then
		dayLabel.Text = "День " .. day
		dayLabel.TextColor3 = isClaimed and COLORS.textGray or COLORS.textPrimary
	end

	-- Иконка/значение награды
	local rewardEntries = getRewardEntries(reward)

	local valueLabel = item:FindFirstChild("ValueLabel")
	if valueLabel then
		if #rewardEntries == 0 then
			valueLabel.Text = "🎁"
			valueLabel.TextColor3 = isClaimed and COLORS.textGray or COLORS.textPrimary
		elseif #rewardEntries == 1 then
			local entry = rewardEntries[1]
			if entry.key == "Gold" then
				valueLabel.Text = "💰" .. formatNumber(entry.value)
				valueLabel.TextColor3 = isClaimed and COLORS.textGray or COLORS.textGold
			elseif entry.key == "PurchaseBanTickets" then
				valueLabel.Text = "🎫" .. formatNumber(entry.value)
				valueLabel.TextColor3 = isClaimed and COLORS.textGray or Color3.fromRGB(180, 140, 255)
			else
				valueLabel.Text = formatNumber(entry.value) .. " " .. entry.key
				valueLabel.TextColor3 = isClaimed and COLORS.textGray or COLORS.textPrimary
			end
		else
			valueLabel.Text = getRewardDescription(reward)
			valueLabel.TextColor3 = isClaimed and COLORS.textGray or COLORS.textPrimary
		end
	end

	-- Описание модификатора
	local modLabel = item:FindFirstChild("ModLabel")
	if modLabel then
		if reward and reward.Modifiers and #reward.Modifiers > 0 then
			local modTexts = {}
			for _, mod in ipairs(reward.Modifiers) do
				table.insert(modTexts, "+" .. string.format("%.0f", (mod.Value - 1) * 100) .. "%")
			end
			modLabel.Text = table.concat(modTexts, ", ")
			modLabel.TextColor3 = isClaimed and COLORS.textGray or Color3.fromRGB(150, 180, 255)
			modLabel.Visible = true
		else
			modLabel.Visible = false
		end
	end

	-- Статус индикатор
	local statusIcon = item:FindFirstChild("StatusIcon")
	if statusIcon then
		if isClaimed then
			statusIcon.Text = "✅"
		elseif isAvailable then
			statusIcon.Text = ""
			statusIcon.TextColor3 = COLORS.textGreen
		else
			statusIcon.Text = "🔒"
			statusIcon.TextColor3 = COLORS.textGray
		end
	end

	return item
end

-- Рендер списка наград для группы
local function renderRewardGroup(sectionFrame, groupData)
	local rewardsList = sectionFrame:FindFirstChild("RewardsList")
	if not rewardsList then return end
	
	-- Очищаем старые элементы (кроме UIListLayout и UIAspectRatioConstraint)
	for _, child in ipairs(rewardsList:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIAspectRatioConstraint") then
			child:Destroy()
		end
	end
	
	-- Удаляем старую метку PostCompletion если есть
	local oldPostLabel = sectionFrame:FindFirstChild("PostCompletionLabel")
	if oldPostLabel then
		oldPostLabel.Visible = false
	end
	
	if not groupData then return end
	
	local status = groupData.status
	local rewards = groupData.rewards
	local cycleLength = groupData.cycleLength
	local currentDay = status.currentDay or 1
	
	for day = 1, cycleLength do
		local reward = rewards[day]
		local isCurrentDay = (day == currentDay)
		local item = createRewardItem(day, reward, status, isCurrentDay)
		item.Parent = rewardsList
	end
	
	-- Отображение PostCompletionReward
	local postReward = groupData.postCompletionReward
	local postLabel = sectionFrame:FindFirstChild("PostCompletionLabel")
	if postLabel and postReward then
		local postDesc = getRewardDescription(postReward)
		if postDesc ~= "" and postDesc ~= "—" then
			postLabel.Text = "🎁 Награда за цикл: " .. postDesc
			postLabel.Visible = true
		else
			postLabel.Visible = false
		end
	elseif postLabel then
		postLabel.Visible = false
	end
end

-- Обновление GUI
local function updateGUI(data)
	if not data or not data.groups then
		return
	end
	
	rewardsData = data
	
	-- Рендерим Default группу
	local defaultGroup = data.groups["Default"]
	if defaultGroup then
		renderRewardGroup(defaultSection, defaultGroup)
		defaultSection.Visible = true
	else
		defaultSection.Visible = false
	end
	
	-- Рендерим Premium группу
	local premiumGroup = data.groups["Premium"]
	if premiumGroup then
		renderRewardGroup(premiumSection, premiumGroup)
		premiumSection.Visible = true
	else
		premiumSection.Visible = false
	end
	
	-- Обновляем кнопку клейма
	local canClaimAny = false
	local claimableGroupName = nil
	
	for groupName, groupData in pairs(data.groups) do
		if groupData.status and groupData.status.canClaim then
			canClaimAny = true
			claimableGroupName = groupName
			break
		end
	end
	
	if canClaimAny then
		claimButton.Text = "Забрать награду"
		claimButton.BackgroundColor3 = COLORS.buttonActive
		claimButton.TextColor3 = COLORS.background
		claimButton.Active = true
		claimButton:SetAttribute("ClaimableGroup", claimableGroupName)
		timerLabel.Visible = false
		nextRewardTime = nil
	else
		claimButton.Text = "Награда получена"
		claimButton.BackgroundColor3 = COLORS.buttonInactive
		claimButton.TextColor3 = COLORS.textGray
		claimButton.Active = false
		claimButton:SetAttribute("ClaimableGroup", nil)

		-- Вычисляем время до следующей награды
		local earliestNextTime = nil
		for groupName, groupData in pairs(data.groups) do
			if groupData.status and groupData.status.lastLoginTime and groupData.status.lastLoginTime > 0 then
				local nextTime = groupData.status.lastLoginTime + 86400 -- 24 часа
				if earliestNextTime == nil or nextTime < earliestNextTime then
					earliestNextTime = nextTime
				end
			end
		end

		if earliestNextTime then
			nextRewardTime = earliestNextTime
			local remaining = earliestNextTime - os.time()
			if remaining > 0 then
				timerLabel.Text = "Следующая награда через: " .. formatTimeRemaining(remaining)
				timerLabel.Visible = true
				-- Запускаем цикл обновления таймера
				if not timerRunning then
					timerRunning = true
					task.spawn(function()
						while timerRunning and isGuiOpen and nextRewardTime do
							local rem = nextRewardTime - os.time()
							if rem <= 0 then
								timerLabel.Text = "Награда доступна!"
								timerLabel.Visible = true
								timerRunning = false
								nextRewardTime = nil
								-- Перезагружаем данные
								task.wait(1)
								loadDailyRewards()
								break
							end
							timerLabel.Text = "Следующая награда через: " .. formatTimeRemaining(rem)
							task.wait(1)
						end
						timerRunning = false
					end)
				end
			else
				timerLabel.Text = "Награда доступна!"
				timerLabel.Visible = true
				-- Перезагружаем данные, т.к. время уже вышло
				task.wait(1)
				loadDailyRewards()
			end
		else
			timerLabel.Visible = false
			nextRewardTime = nil
		end
	end
end

-- Загрузка данных
local function loadDailyRewards()
	if not EventSystem then
		return
	end
		
	local data = EventSystem.CallRPC("GetDailyRewardsData")
	
	if not data then
		return
	end
	
	updateGUI(data)
end

-- Открытие/закрытие GUI
local function openDailyRewards()
	if isGuiOpen then return end
	isGuiOpen = true
	dailyRewardsGui.Enabled = true
	loadDailyRewards()
end

local function closeDailyRewards()
	if not isGuiOpen then return end
	isGuiOpen = false
	timerRunning = false
	nextRewardTime = nil
	timerLabel.Visible = false
	dailyRewardsGui.Enabled = false
end

-- Обработчики событий

closeButton.MouseButton1Click:Connect(closeDailyRewards)

claimButton.MouseButton1Click:Connect(function()
	if not claimButton.Active then return end
	if not EventSystem then
		return
	end
	
	local groupName = claimButton:GetAttribute("ClaimableGroup")
	if not groupName then
		return
	end
	
	claimButton.Active = false
	claimButton.Text = "Забираем..."
	
	local result, err = EventSystem.CallRPC("ClaimDailyReward", groupName)
	
	if result then
		-- Перезагружаем данные для обновления UI
		task.wait(0.5)
		loadDailyRewards()
	else
		-- Восстанавливаем кнопку
		claimButton.Active = true
		claimButton.Text = "Забрать награду"
		claimButton.BackgroundColor3 = COLORS.buttonActive
		claimButton.TextColor3 = COLORS.background
	end
end)

-- Закрытие по ESC
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape and isGuiOpen then
		closeDailyRewards()
	end
end)

-- Обработка серверного события о клейме
if EventSystem then
	EventSystem.OnClient("DailyRewardClaimed", function(groupName, result)
		-- Перезагружаем данные
		task.wait(0.3)
		loadDailyRewards()
	end)
end

-- Подключаем кнопку в TopBar
task.wait(1)
local topBar = playerGui:FindFirstChild("TopBar")
if topBar then
	local rightButtons = topBar:FindFirstChild("RightButtons")
	if rightButtons then
		local dailyRewardBtn = rightButtons:FindFirstChild("DailyRewardButton")
		if dailyRewardBtn then
			dailyRewardBtn.MouseButton1Click:Connect(function()
				if isGuiOpen then
					closeDailyRewards()
				else
					openDailyRewards()
				end
			end)
			print("[DailyRewardsClient] DailyRewardButton connected")
		else
			warn("[DailyRewardsClient] DailyRewardButton not found in TopBar.RightButtons")
		end
	end
end

print("[DailyRewardsClient] Initialized successfully")