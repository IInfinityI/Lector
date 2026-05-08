-- Клиентский скрипт для управления HelpGui (Справка)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadingScreen = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LoadingScreen"))
LoadingScreen.WaitForLoad()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local HelpGui = PlayerGui:WaitForChild("HelpGui")
HelpGui.Enabled = false

local TutorialGui = PlayerGui:WaitForChild("TutorialGui")
TutorialGui.Enabled = false

local MainContainer = HelpGui:WaitForChild("MainContainer")
local Header = MainContainer:WaitForChild("Header")
local CloseButton = Header:WaitForChild("CloseButton")

local ContentContainer = MainContainer:WaitForChild("ContentContainer")
local TOCPanel = ContentContainer:WaitForChild("TOCPanel")
local PagePanel = ContentContainer:WaitForChild("PagePanel")

local PageTitle = PagePanel:WaitForChild("PageTitle")
local PageContent = PagePanel:WaitForChild("PageContent")

-- Кнопка справки в TopBar
local TopBar = PlayerGui:WaitForChild("TopBar")
local RightButtons = TopBar:WaitForChild("RightButtons")
local HelpButton = RightButtons:WaitForChild("HelpButton")

-- === ССЫЛКИ НА UI ТУТОРИАЛА (из TutorialGui) ===
local TutorialFrame = TutorialGui:WaitForChild("TutorialFrame")
local overlayTop = TutorialFrame:WaitForChild("OverlayTop")
local overlayBottom = TutorialFrame:WaitForChild("OverlayBottom")
local overlayLeft = TutorialFrame:WaitForChild("OverlayLeft")
local overlayRight = TutorialFrame:WaitForChild("OverlayRight")
local highlightBorder = TutorialFrame:WaitForChild("HighlightBorder")
local arrowLabel = TutorialFrame:WaitForChild("ArrowLabel")
local messageBox = TutorialFrame:WaitForChild("MessageBox")
local messageText = messageBox:WaitForChild("MessageText")
local nextButton = messageBox:WaitForChild("NextButton")
local stepIndicator = messageBox:WaitForChild("StepIndicator")

-- === СОСТОЯНИЕ ТУТОРИАЛА ===
local tutorialActive = false
local currentStepIndex = 1
local tutorialConnections = {}
local highlightRenderConnection = nil
local pollingThread = nil -- Для отслеживания потока опроса
local activeStepId = nil   -- ID текущего активного шага (используется для остановки потоков)

-- === ЦВЕТА ===
local TUTORIAL_BG = Color3.fromRGB(25, 34, 48)
local TUTORIAL_GOLD = Color3.fromRGB(255, 205, 0)
local TUTORIAL_TEXT = Color3.fromRGB(200, 210, 230)
local TUTORIAL_DIM = Color3.fromRGB(126, 136, 168)
local TUTORIAL_OVERLAY = Color3.new(0, 0, 0)

local advanceStep
local rollbackToStep


-- === ДАННЫЕ СПРАВКИ ===
local helpData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("HelpData"))

-- === СОСТОЯНИЕ ===
local currentSection = nil

-- === ФУНКЦИИ ===
local function toggleHelpGui()
	if tutorialActive then return end -- Блокируем во время обучения

	HelpGui.Enabled = not HelpGui.Enabled
	if HelpGui.Enabled then
		MainContainer.Visible = true
		if not currentSection then
			-- Показываем обзор по умолчанию
			currentSection = "overview"
			PageTitle.Text = helpData.overview.title
			PageContent.Text = helpData.overview.content
			PagePanel.CanvasPosition = Vector2.new(0, 0)
		end
	else
		MainContainer.Visible = false
	end
end

local function selectSection(sectionId)
	local data = helpData[sectionId]
	if not data then return end

	currentSection = sectionId
	PageTitle.Text = data.title
	PageContent.Text = data.content
	PagePanel.CanvasPosition = Vector2.new(0, 0)

	-- Подсвечиваем активный раздел в содержании (стиль как levelTab)
	local BG_TAB = Color3.fromRGB(25, 34, 48)
	local GOLD = Color3.fromRGB(255, 205, 0)
	local TEXT_DIM = Color3.fromRGB(126, 136, 168)

	for _, child in ipairs(TOCPanel:GetChildren()) do
		if child:IsA("TextButton") and child.Name:find("^TOC_") then
			local id = child.Name:sub(5) -- убираем "TOC_"
			if id == sectionId then
				child.TextColor3 = GOLD
			else
				child.TextColor3 = TEXT_DIM
			end
		end
	end
end

-- === ОБРАБОТЧИКИ СОБЫТИЙ ===

-- Кнопка справки в TopBar
HelpButton.MouseButton1Click:Connect(function()
	toggleHelpGui()
end)

-- Кнопка закрытия
CloseButton.MouseButton1Click:Connect(function()
	if tutorialActive then return end -- Блокируем во время обучения
	HelpGui.Enabled = false
	MainContainer.Visible = false
end)

-- Кнопки содержания
for _, child in ipairs(TOCPanel:GetChildren()) do
	if child:IsA("TextButton") and child.Name:find("^TOC_") then
		local sectionId = child.Name:sub(5)
		child.MouseButton1Click:Connect(function()
			selectSection(sectionId)
		end)
	end
end

-- Горячая клавиша H
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.H then
		if tutorialActive then return end -- Блокируем во время обучения
		toggleHelpGui()
	end
end)

print("[HelpGui] Клиентский скрипт загружен")

-- ================================================================
-- === СИСТЕМА ОБУЧЕНИЯ (TUTORIAL) ===
-- ================================================================

local RunService = game:GetService("RunService")

-- Загрузка TutorialModule
local TutorialModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TutorialModule"))

-- Загрузка EventSystem для туториала
local TutorialEventSystem
local tutorialEventSystemLoaded = false

task.spawn(function()
	local maxWait = 15
	local waited = 0
	while waited < maxWait do
		local success, module = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("EventSystem"))
		end)
		if success and module then
			TutorialEventSystem = module
			TutorialEventSystem.Init()
			tutorialEventSystemLoaded = true
			break
		end
		task.wait(0.5)
		waited = waited + 0.5
	end
	if not tutorialEventSystemLoaded then
		warn("[Tutorial] EventSystem не загружен для туториала")
	end
end)

local stepsData = TutorialModule.steps

-- Создаём точки-индикаторы динамически по количеству шагов
local stepDots = {}

local function createStepDots()
	-- Удаляем старые точки
	for _, child in ipairs(stepIndicator:GetChildren()) do
		if child:IsA("Frame") and child.Name:find("^Dot%d+$") then
			child:Destroy()
		end
	end
	table.clear(stepDots)

	-- Создаём новые точки по количеству шагов
	for i = 1, #stepsData do
		local dot = Instance.new("Frame")
		dot.Name = "Dot" .. i
		dot.Size = UDim2.new(0, 8, 0, 8)
		dot.BorderSizePixel = 0
		dot.ZIndex = 107
		dot.BackgroundColor3 = TUTORIAL_DIM

		local corner = Instance.new("UICorner")
		corner.Parent = dot

		dot.Parent = stepIndicator
		stepDots[i] = dot
	end
end

createStepDots()

-- === ФУНКЦИИ ТУТОРИАЛА ===

-- Очистка подключений туториала
local function clearTutorialConnections()
	for _, conn in ipairs(tutorialConnections) do
		if conn then
			pcall(function() conn:Disconnect() end)
		end
	end
	tutorialConnections = {}

	-- Сброс ID активного шага остановит все потоки опроса и наблюдения
	activeStepId = nil
	pollingThread = nil
end

-- Найти GUI-элемент по пути в PlayerGui
local function findGuiElementByPath(path)
	if not path or path == "" then return nil end
	local parts = string.split(path, ".")
	if #parts == 0 then return nil end
	local current = PlayerGui
	for _, part in ipairs(parts) do
		if not current then return nil end
		current = current:FindFirstChild(part)
	end
	return current
end

-- Обновить позиции оверлеев для подсветки элемента
local function positionHighlight(targetElement)
	if not targetElement or not targetElement:IsA("GuiObject") then
		overlayTop.Visible = false
		overlayBottom.Visible = false
		overlayLeft.Visible = false
		overlayRight.Visible = false
		highlightBorder.Visible = false
		return
	end

	local absPos = targetElement.AbsolutePosition
	local absSize = targetElement.AbsoluteSize
	local framePos = TutorialFrame.AbsolutePosition
	local padding = 6

	local left = absPos.X - framePos.X - padding
	local top = absPos.Y - framePos.Y - padding
	local right = absPos.X + absSize.X - framePos.X + padding
	local bottom = absPos.Y + absSize.Y - framePos.Y + padding
	local screenW = TutorialFrame.AbsoluteSize.X
	local screenH = TutorialFrame.AbsoluteSize.Y

	-- Верхний оверлей (от верха экрана до верха элемента)
	overlayTop.Size = UDim2.new(1, 0, 0, math.max(0, top))
	overlayTop.Position = UDim2.new(0, 0, 0, 0)
	overlayTop.Visible = true

	-- Нижний оверлей (от низа элемента до низа экрана)
	overlayBottom.Size = UDim2.new(1, 0, 0, math.max(0, screenH - bottom))
	overlayBottom.Position = UDim2.new(0, 0, 0, bottom)
	overlayBottom.Visible = true

	-- Левый оверлей (между верхним и нижним, слева от элемента)
	overlayLeft.Size = UDim2.new(0, math.max(0, left), 0, bottom - top)
	overlayLeft.Position = UDim2.new(0, 0, 0, top)
	overlayLeft.Visible = true

	-- Правый оверлей (между верхним и нижним, справа от элемента)
	overlayRight.Size = UDim2.new(0, math.max(0, screenW - right), 0, bottom - top)
	overlayRight.Position = UDim2.new(0, right, 0, top)
	overlayRight.Visible = true

	-- Рамка подсветки
	highlightBorder.Size = UDim2.new(0, absSize.X + padding * 2, 0, absSize.Y + padding * 2)
	highlightBorder.Position = UDim2.new(0, left, 0, top)
	highlightBorder.Visible = true
end

-- Разместить стрелку рядом с подсвеченным элементом
local function positionArrow(targetElement, direction)
	if not targetElement or not targetElement:IsA("GuiObject") or not direction then
		arrowLabel.Visible = false
		return
	end

	local absPos = targetElement.AbsolutePosition
	local absSize = targetElement.AbsoluteSize
	local framePos = TutorialFrame.AbsolutePosition

	local arrowSymbols = {
		down = "▼",
		up = "▲",
		left = "◀",
		right = "▶",
	}

	arrowLabel.Text = arrowSymbols[direction] or "▼"

	if direction == "down" then
		arrowLabel.Position = UDim2.new(0, absPos.X + absSize.X / 2 - 20 - framePos.X, 0, absPos.Y - 45 - framePos.Y)
	elseif direction == "up" then
		arrowLabel.Position = UDim2.new(0, absPos.X + absSize.X / 2 - 20 - framePos.X, 0, absPos.Y + absSize.Y + 5 - framePos.Y)
	elseif direction == "left" then
		arrowLabel.Position = UDim2.new(0, absPos.X - 50 - framePos.X, 0, absPos.Y + absSize.Y / 2 - 20 - framePos.Y)
	elseif direction == "right" then
		arrowLabel.Position = UDim2.new(0, absPos.X + absSize.X + 10 - framePos.X, 0, absPos.Y + absSize.Y / 2 - 20 - framePos.Y)
	end

	arrowLabel.Visible = true
end

-- Скрыть всю подсветку
local function clearHighlight()
	overlayTop.Visible = false
	overlayBottom.Visible = false
	overlayLeft.Visible = false
	overlayRight.Visible = false
	highlightBorder.Visible = false
	arrowLabel.Visible = false

	if highlightRenderConnection then
		highlightRenderConnection:Disconnect()
		highlightRenderConnection = nil
	end
end

-- Обновить индикатор шагов
local function updateStepIndicator()
	for i, dot in ipairs(stepDots) do
		if i == currentStepIndex then
			dot.BackgroundColor3 = TUTORIAL_GOLD
		else
			dot.BackgroundColor3 = TUTORIAL_DIM
		end
	end
end

-- Поиск индекса шага по его id
local function findStepIndexById(id)
	for i, step in ipairs(stepsData) do
		if step.id == id then
			return i
		end
	end
	return nil
end

-- Активировать шаг по его индексу (настраивает UI, подсветку, подписки и вотчеры)
local function activateStep(stepIndex)
	if not tutorialActive then return end
	if stepIndex < 1 or stepIndex > #stepsData then return end

	clearTutorialConnections()
	clearHighlight()

	local step = stepsData[stepIndex]
	activeStepId = step.id

	-- Сообщение и кнопка
	messageText.Text = step.message
	nextButton.Visible = (step.advanceType == "button")
	nextButton.Text = step.nextButtonText or "Далее"

	if step.messagePosition == "top" then
		messageBox.Position = UDim2.new(0.2, 0, 0, 30)
	else
		messageBox.Position = UDim2.new(0.2, 0, 1, -170)
	end

	updateStepIndicator()

	-- Подсветка цели
	if step.highlightPath then
		local targetElement = findGuiElementByPath(step.highlightPath)
		if targetElement then
			positionHighlight(targetElement)
			if step.arrowDirection then
				positionArrow(targetElement, step.arrowDirection)
			end
			highlightRenderConnection = RunService.RenderStepped:Connect(function()
				if not tutorialActive or activeStepId ~= step.id then return end
				local el = findGuiElementByPath(step.highlightPath)
				if el then
					positionHighlight(el)
					positionArrow(el, step.arrowDirection)
				end
			end)
		end
	else
		clearHighlight()
	end

	-- Обработчик перехода в зависимости от advanceType
	if step.advanceType == "event" and tutorialEventSystemLoaded and TutorialEventSystem then
		local eventConn
		eventConn = TutorialEventSystem.OnClient(step.expectedEvent, function(...)
			if not tutorialActive or activeStepId ~= step.id then return end
			local args = {...}
			if step.eventFilter then
				if step.eventFilter(unpack(args)) then
					advanceStep()
				end
			else
				advanceStep()
			end
		end)
		table.insert(tutorialConnections, eventConn)

	elseif step.advanceType == "gui_enabled" then
		pollingThread = task.spawn(function()
			while tutorialActive and activeStepId == step.id do
				local guiObj = PlayerGui:FindFirstChild(step.guiName)
				if guiObj and guiObj:IsA("ScreenGui") and guiObj.Enabled then
					task.wait(0.3)
					if tutorialActive and activeStepId == step.id then
						advanceStep()
					end
					break
				end
				task.wait(0.5)
			end
		end)

	elseif step.advanceType == "gui_disabled" then
		pollingThread = task.spawn(function()
			while tutorialActive and activeStepId == step.id do
				local guiObj = PlayerGui:FindFirstChild(step.guiName)
				if guiObj and guiObj:IsA("ScreenGui") and not guiObj.Enabled then
					task.wait(0.3)
					if tutorialActive and activeStepId == step.id then
						advanceStep()
					end
					break
				end
				task.wait(0.5)
			end
		end)

	elseif step.advanceType == "gui_visible" then
		pollingThread = task.spawn(function()
			while tutorialActive and activeStepId == step.id do
				local guiObj = findGuiElementByPath(step.guiPath)
				if guiObj and guiObj:IsA("GuiObject") and guiObj.Visible then
					task.wait(0.3)
					if tutorialActive and activeStepId == step.id then
						advanceStep()
					end
					break
				end
				task.wait(0.5)
			end
		end)
	end

	-- Наблюдение за видимостью с откатом (если задано)
	if step.watchVisiblePath and step.rollbackStepId then
    local watchPath = step.watchVisiblePath
    local rollbackId = step.rollbackStepId
    task.spawn(function()
        while tutorialActive and activeStepId == step.id do
            local el = findGuiElementByPath(watchPath)
            local isVisible = false
            
            if el then
                -- Проверяем, является ли элемент ScreenGui
                if el:IsA("ScreenGui") then
                    -- Для ScreenGui проверяем Enabled и Visible (если есть)
                    isVisible = el.Enabled
                    if el.Visible ~= nil then
                        isVisible = isVisible and el.Visible
                    end
                elseif el:IsA("GuiObject") then
                    -- Для обычных GuiObject проверяем Visible
                    isVisible = el.Visible
                    
                    -- Дополнительно проверяем, не находится ли элемент в отключенном ScreenGui
                    local parentGui = el:FindFirstAncestorWhichIsA("ScreenGui")
                    if parentGui and parentGui:IsA("ScreenGui") then
                        isVisible = isVisible and parentGui.Enabled
                    end
                end
            end
            
            if not isVisible then
                task.wait(0.1)
                if tutorialActive and activeStepId == step.id then
                    -- Повторная проверка после небольшой задержки
                    el = findGuiElementByPath(watchPath)
                    isVisible = false
                    
                    if el then
                        if el:IsA("ScreenGui") then
                            isVisible = el.Enabled
                            if el.Visible ~= nil then
                                isVisible = isVisible and el.Visible
                            end
                        elseif el:IsA("GuiObject") then
                            isVisible = el.Visible
                            local parentGui = el:FindFirstAncestorWhichIsA("ScreenGui")
                            if parentGui and parentGui:IsA("ScreenGui") then
                                isVisible = isVisible and parentGui.Enabled
                            end
                        end
                    end
                    
                    if not isVisible then
                        rollbackToStep(rollbackId)
                        break
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end
end

rollbackToStep = function(stepId)
	local targetIndex = findStepIndexById(stepId)
	if not targetIndex then
		warn("[Tutorial] Rollback target step not found: " .. tostring(stepId))
		return
	end
	currentStepIndex = targetIndex
	activateStep(currentStepIndex)
end

-- Перейти к следующему шагу
advanceStep = function()
	if not tutorialActive then return end
	clearTutorialConnections()
	clearHighlight()

	currentStepIndex = currentStepIndex + 1
	if currentStepIndex > #stepsData then
		-- Обучение завершено
		tutorialActive = false
		TutorialFrame.Visible = false
		TutorialGui.Enabled = false
		TutorialGui.DisplayOrder = 0

		-- Сохраняем на сервере
		if tutorialEventSystemLoaded and TutorialEventSystem then
			task.spawn(function()
				pcall(function()
					TutorialEventSystem.CallRPC("SetTutorialCompleted")
				end)
			end)
		end
		return
	end

	activateStep(currentStepIndex)
end

-- Запуск туториала
local function startTutorial()
	if tutorialActive then return end
	tutorialActive = true
	currentStepIndex = 1

	-- Включаем TutorialGui для отображения обучения
	TutorialGui.Enabled = true
	TutorialFrame.Visible = true
	TutorialGui.DisplayOrder = 100

	activateStep(1)
end

-- Кнопка «Далее» / «Готово»
nextButton.MouseButton1Click:Connect(function()
	if not tutorialActive then return end
	local step = stepsData[currentStepIndex]
	if step and step.advanceType == "button" then
		advanceStep()
	end
end)

-- Проверка при загрузке: нужно ли запускать туториал?
task.spawn(function()
	-- Ждём загрузки EventSystem
	local maxWait = 20
	local waited = 0
	while not tutorialEventSystemLoaded and waited < maxWait do
		task.wait(0.5)
		waited = waited + 0.5
	end

	if not tutorialEventSystemLoaded then
		warn("[Tutorial] Пропуск: EventSystem не загружен")
		return
	end

	-- Ждём немного для стабилизации GUI
	task.wait(2)

	-- Проверяем, пройден ли туториал
	local success, result = pcall(function()
		return TutorialEventSystem.CallRPC("GetTutorialCompleted")
	end)

	if success and result ~= true then
		print("[Tutorial] Запуск обучения для нового игрока")
		startTutorial()
	else
		print("[Tutorial] Обучение уже пройдено")
	end
end)