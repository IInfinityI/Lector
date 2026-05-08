local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Получение событий
local eventsFolder = ReplicatedStorage:WaitForChild("AccessoryEvents")
local EquipEvent = eventsFolder:WaitForChild("Equip")
local UnequipEvent = eventsFolder:WaitForChild("Unequip")
local UpgradeLevelEvent = eventsFolder:WaitForChild("UpgradeLevel")
local UpgradeModifierEvent = eventsFolder:WaitForChild("UpgradeModifier")
local PurchaseEvent = eventsFolder:WaitForChild("Purchase")
local GetAccessoryInfoEvent = eventsFolder:WaitForChild("GetAccessoryInfo")
local GetPlayerAccessoriesEvent = eventsFolder:WaitForChild("GetPlayerAccessories")
local GetSlotInfoEvent = eventsFolder:WaitForChild("GetSlotInfo")
local GetAccessoryDataFunction = eventsFolder:WaitForChild("GetAccessoryData")

-- Создание основного GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AccessorySystemGUI"
screenGui.Parent = playerGui

-- Основной фрейм
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 900, 0, 650)
mainFrame.Position = UDim2.new(0.5, -450, 0.5, -325)
mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

-- Заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.Text = "ACCESSORY SYSTEM"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Parent = mainFrame

-- Кнопка закрытия
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -45, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextScaled = true
closeButton.Font = Enum.Font.SourceSansBold
closeButton.Parent = mainFrame

-- Контейнер для вкладок
local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(1, 0, 0, 40)
tabContainer.Position = UDim2.new(0, 0, 0, 50)
tabContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
tabContainer.BorderSizePixel = 0
tabContainer.Parent = mainFrame

-- Вкладки
local tabs = {"Inventory", "Shop", "Equipment", "Upgrade"}
local currentTab = "Inventory"

-- Контентная область
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 1, -90)
contentFrame.Position = UDim2.new(0, 0, 0, 90)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Левая панель (список аксессуаров)
local leftPanel = Instance.new("ScrollingFrame")
leftPanel.Name = "LeftPanel"
leftPanel.Size = UDim2.new(0.4, 0, 1, 0)
leftPanel.Position = UDim2.new(0, 0, 0, 0)
leftPanel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
leftPanel.BorderSizePixel = 0
leftPanel.ScrollBarThickness = 8
leftPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
leftPanel.Parent = contentFrame

local leftPanelLayout = Instance.new("UIListLayout")
leftPanelLayout.Name = "LeftPanelLayout"
leftPanelLayout.Padding = UDim.new(0, 5)
leftPanelLayout.Parent = leftPanel

-- Правая панель (детали)
local rightPanel = Instance.new("Frame")
rightPanel.Name = "RightPanel"
rightPanel.Size = UDim2.new(0.6, 0, 1, 0)
rightPanel.Position = UDim2.new(0.4, 0, 0, 0)
rightPanel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
rightPanel.BorderSizePixel = 0
rightPanel.Parent = contentFrame

-- Детальная информация об аксессуаре
local detailsFrame = Instance.new("Frame")
detailsFrame.Name = "DetailsFrame"
detailsFrame.Size = UDim2.new(1, -20, 1, -20)
detailsFrame.Position = UDim2.new(0, 10, 0, 10)
detailsFrame.BackgroundTransparency = 1
detailsFrame.Parent = rightPanel

local accessoryNameLabel = Instance.new("TextLabel")
accessoryNameLabel.Name = "AccessoryNameLabel"
accessoryNameLabel.Size = UDim2.new(1, 0, 0, 40)
accessoryNameLabel.Position = UDim2.new(0, 0, 0, 0)
accessoryNameLabel.BackgroundTransparency = 1
accessoryNameLabel.Text = "Select an accessory"
accessoryNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
accessoryNameLabel.TextScaled = true
accessoryNameLabel.Font = Enum.Font.SourceSansBold
accessoryNameLabel.Parent = detailsFrame

local accessoryDescriptionLabel = Instance.new("TextLabel")
accessoryDescriptionLabel.Name = "AccessoryDescriptionLabel"
accessoryDescriptionLabel.Size = UDim2.new(1, 0, 0, 60)
accessoryDescriptionLabel.Position = UDim2.new(0, 0, 0, 45)
accessoryDescriptionLabel.BackgroundTransparency = 1
accessoryDescriptionLabel.Text = "Description will appear here"
accessoryDescriptionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
accessoryDescriptionLabel.TextWrapped = true
accessoryDescriptionLabel.TextScaled = false
accessoryDescriptionLabel.Font = Enum.Font.SourceSans
accessoryDescriptionLabel.Parent = detailsFrame

local accessoryStatsLabel = Instance.new("TextLabel")
accessoryStatsLabel.Name = "AccessoryStatsLabel"
accessoryStatsLabel.Size = UDim2.new(1, 0, 0, 150)
accessoryStatsLabel.Position = UDim2.new(0, 0, 0, 110)
accessoryStatsLabel.BackgroundTransparency = 1
accessoryStatsLabel.Text = "Stats:\n- No stats available"
accessoryStatsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
accessoryStatsLabel.TextWrapped = true
accessoryStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
accessoryStatsLabel.Parent = detailsFrame

-- Кнопки действий
local actionButtonsFrame = Instance.new("Frame")
actionButtonsFrame.Name = "ActionButtonsFrame"
actionButtonsFrame.Size = UDim2.new(1, 0, 0, 170)
actionButtonsFrame.Position = UDim2.new(0, 0, 1, -170)
actionButtonsFrame.BackgroundTransparency = 1
actionButtonsFrame.Parent = detailsFrame

local equipButton = Instance.new("TextButton")
equipButton.Name = "EquipButton"
equipButton.Size = UDim2.new(0.45, 0, 0, 40)
equipButton.Position = UDim2.new(0, 0, 0, 0)
equipButton.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
equipButton.Text = "EQUIP"
equipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
equipButton.TextScaled = true
equipButton.Font = Enum.Font.SourceSansBold
equipButton.Visible = false
equipButton.Parent = actionButtonsFrame

local unequipButton = Instance.new("TextButton")
unequipButton.Name = "UnequipButton"
unequipButton.Size = UDim2.new(0.45, 0, 0, 40)
unequipButton.Position = UDim2.new(0, 0, 0, 0)
unequipButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
unequipButton.Text = "UNEQUIP"
unequipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
unequipButton.TextScaled = true
unequipButton.Font = Enum.Font.SourceSansBold
unequipButton.Visible = false
unequipButton.Parent = actionButtonsFrame

local upgradeButton = Instance.new("TextButton")
upgradeButton.Name = "UpgradeButton"
upgradeButton.Size = UDim2.new(0.45, 0, 0, 40)
upgradeButton.Position = UDim2.new(0.55, 0, 0, 0)
upgradeButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
upgradeButton.Text = "UPGRADE"
upgradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeButton.TextScaled = true
upgradeButton.Font = Enum.Font.SourceSansBold
upgradeButton.Visible = false
upgradeButton.Parent = actionButtonsFrame

local purchaseButton = Instance.new("TextButton")
purchaseButton.Name = "PurchaseButton"
purchaseButton.Size = UDim2.new(1, 0, 0, 40)
purchaseButton.Position = UDim2.new(0, 0, 0, 50)
purchaseButton.BackgroundColor3 = Color3.fromRGB(200, 160, 60)
purchaseButton.Text = "PURCHASE"
purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
purchaseButton.TextScaled = true
purchaseButton.Font = Enum.Font.SourceSansBold
purchaseButton.Visible = false
purchaseButton.Parent = actionButtonsFrame

-- Кнопки удаления/продажи
local deleteButton = Instance.new("TextButton")
deleteButton.Name = "DeleteButton"
deleteButton.Size = UDim2.new(0.45, 0, 0, 40)
deleteButton.Position = UDim2.new(0, 0, 0, 100)
deleteButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
deleteButton.Text = "DELETE"
deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deleteButton.TextScaled = true
deleteButton.Font = Enum.Font.SourceSansBold
deleteButton.Visible = false
deleteButton.Parent = actionButtonsFrame

local sellButton = Instance.new("TextButton")
sellButton.Name = "SellButton"
sellButton.Size = UDim2.new(0.45, 0, 0, 40)
sellButton.Position = UDim2.new(0.55, 0, 0, 100)
sellButton.BackgroundColor3 = Color3.fromRGB(200, 120, 60)
sellButton.Text = "SELL"
sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sellButton.TextScaled = true
sellButton.Font = Enum.Font.SourceSansBold
sellButton.Visible = false
sellButton.Parent = actionButtonsFrame

-- Информация о слотах
local slotInfoFrame = Instance.new("Frame")
slotInfoFrame.Name = "SlotInfoFrame"
slotInfoFrame.Size = UDim2.new(0.2, -20, 0, 80)
slotInfoFrame.Position = UDim2.new(-0.3, 10, 0, 10)
slotInfoFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
slotInfoFrame.BorderSizePixel = 0
slotInfoFrame.Parent = contentFrame

local slotInfoLabel = Instance.new("TextLabel")
slotInfoLabel.Name = "SlotInfoLabel"
slotInfoLabel.Size = UDim2.new(1, 0, 1, 0)
slotInfoLabel.Position = UDim2.new(0, 0, 0, 0)
slotInfoLabel.BackgroundTransparency = 1
slotInfoLabel.Text = "Loading slot info..."
slotInfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
slotInfoLabel.TextWrapped = true
slotInfoLabel.Parent = slotInfoFrame

-- Локальные переменные
local accessoryData = {}
local selectedAccessory = nil
local currentAccessories = {}

-- Функция выбора аксессуара
local function selectAccessory(accessory, context)
    selectedAccessory = accessory
    
    -- Обновляем информацию в правой панели
    accessoryNameLabel.Text = accessory.name or accessory.Name
    accessoryDescriptionLabel.Text = accessory.description or "No description available"
    
    -- Обновляем статистику
    local statsText = "Stats:\n"
    
    if accessory.Modifiers then
        for i, modifier in ipairs(accessory.Modifiers) do
            statsText ..= string.format("- %s: %s (%s)\n", 
                modifier.Type or "Unknown", 
                tostring(modifier.Value or "N/A"),
                modifier.Operation or "add")
        end
    elseif accessory.modifiers then
        for i, modifier in ipairs(accessory.modifiers) do
            local valueText = ""
            if type(modifier.value) == "table" then
                valueText = table.concat(modifier.value, "/")
            else
                valueText = tostring(modifier.value)
            end
            statsText ..= string.format("- %s: %s (%s)\n", 
                modifier.type or "Unknown", 
                valueText,
                modifier.operation or "add")
        end
    else
        statsText ..= "- No modifiers"
    end
    
    if accessory.level then
        statsText ..= string.format("\nLevel: %d/%d", accessory.level, accessory.maxLevel or 1)
    end
    
    if accessory.modifierLevels then
        statsText ..= "\nModifier Levels:"
        for i, level in pairs(accessory.modifierLevels) do
            statsText ..= string.format("\n- Mod %d: %d", i, level)
        end
    end
    
    accessoryStatsLabel.Text = statsText
    
    -- Показываем соответствующие кнопки действий
    equipButton.Visible = false
    unequipButton.Visible = false
    upgradeButton.Visible = false
    purchaseButton.Visible = false
    deleteButton.Visible = false
    sellButton.Visible = false
    
    if context == "shop" then
        purchaseButton.Visible = true
        purchaseButton.Text = "PURCHASE - " .. tostring(accessory.cost) .. " " .. (accessory.currency or "Coins")
    elseif context == "inventory" or context == "owned" then
        if accessory.isEquipped then
            unequipButton.Visible = true
        else
            equipButton.Visible = true
        end
        upgradeButton.Visible = true
        sellButton.Visible = true
        if accessory.obtainedMethod ~= "default" then
            deleteButton.Visible = true
        end
    elseif context == "equipped" then
        unequipButton.Visible = true
        upgradeButton.Visible = true
        sellButton.Visible = true
        if accessory.obtainedMethod ~= "default" then
            deleteButton.Visible = true
        end
    elseif context == "upgrade" then
        if accessory.isEquipped then
            unequipButton.Visible = true
        else
            equipButton.Visible = true
        end
        upgradeButton.Visible = true
        sellButton.Visible = true
        if accessory.obtainedMethod ~= "default" then
            deleteButton.Visible = true
        end
    end
    
    -- Обновляем текст кнопок продажи
    if sellButton.Visible then
        if accessory.sellPrice and accessory.sellPrice > 0 then
            sellButton.Text = "SELL - " .. tostring(accessory.sellPrice)
            sellButton.BackgroundColor3 = Color3.fromRGB(200, 120, 60)
        else
            sellButton.Text = "CAN'T SELL"
            sellButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        end
    end
end

-- Функция создания кнопки аксессуара
local function createAccessoryButton(accessory, context)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 70)
    button.Position = UDim2.new(0, 5, 0, #leftPanel:GetChildren() * 75)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Text = ""
    button.Parent = leftPanel
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.7, 0, 0.4, 0)
    nameLabel.Position = UDim2.new(0, 5, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = accessory.name or accessory.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Parent = button
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(0.7, 0, 0.3, 0)
    infoLabel.Position = UDim2.new(0, 5, 0.4, 0)
    infoLabel.BackgroundTransparency = 1
    
    if context == "shop" then
        infoLabel.Text = "Cost: " .. tostring(accessory.cost) .. " " .. (accessory.currency or "Coins")
    elseif context == "equipped" or context == "upgrade" then
        infoLabel.Text = "Level: " .. tostring(accessory.Level or accessory.level or 1)
    elseif context == "owned" then
        infoLabel.Text = accessory.isEquipped and "EQUIPPED" or "IN INVENTORY"
    end
    
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Font = Enum.Font.SourceSans
    infoLabel.Parent = button
    
    -- Отображение instanceId для owned accessories
    if accessory.id then
        local idLabel = Instance.new("TextLabel")
        idLabel.Size = UDim2.new(0.7, 0, 0.3, 0)
        idLabel.Position = UDim2.new(0, 5, 0.7, 0)
        idLabel.BackgroundTransparency = 1
        idLabel.Text = "ID: " .. string.sub(accessory.id, 1, 8) .. "..."
        idLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        idLabel.TextXAlignment = Enum.TextXAlignment.Left
        idLabel.Font = Enum.Font.SourceSans
        idLabel.TextSize = 10
        idLabel.Parent = button
    end
    
    button.MouseButton1Click:Connect(function()
        selectAccessory(accessory, context)
    end)
end

-- Функция показа инвентаря
local function showInventory()
    if not accessoryData.ownedAccessories then return end
    
    for _, accessory in ipairs(accessoryData.ownedAccessories) do
        createAccessoryButton(accessory, "owned")
    end
end

-- Функция показа магазина
local function showShop()
    if not accessoryData.allAccessories then return end
    
    for _, accessory in ipairs(accessoryData.allAccessories) do
        createAccessoryButton(accessory, "shop")
    end
end

-- Функция показа экипированных аксессуаров
local function showEquipment()
    if not accessoryData.playerAccessories then return end
    
    for _, accessory in ipairs(accessoryData.playerAccessories) do
        createAccessoryButton(accessory, "equipped")
    end
end

-- Функция показа улучшений
local function showUpgrade()
    if not accessoryData.ownedAccessories then return end
    
    for _, accessory in ipairs(accessoryData.ownedAccessories) do
        createAccessoryButton(accessory, "upgrade")
    end
end

-- Функция обновления контента
local function updateContent()
    leftPanel:ClearAllChildren()
    
    if currentTab == "Inventory" then
        showInventory()
    elseif currentTab == "Shop" then
        showShop()
    elseif currentTab == "Equipment" then
        showEquipment()
    elseif currentTab == "Upgrade" then
        showUpgrade()
    end
end

-- Функция переключения вкладок
local function switchTab(tabName)
    currentTab = tabName
    
    -- Обновляем внешний вид кнопок вкладок
    for _, tab in ipairs(tabs) do
        local tabButton = tabContainer:FindFirstChild(tab .. "Tab")
        if tabButton then
            if tab == tabName then
                tabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            else
                tabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            end
        end
    end
    
    -- Обновляем контент в зависимости от вкладки
    updateContent()
end

-- Создание кнопок вкладок
for i, tabName in ipairs(tabs) do
    local tabButton = Instance.new("TextButton")
    tabButton.Name = tabName .. "Tab"
    tabButton.Size = UDim2.new(1 / #tabs, 0, 1, 0)
    tabButton.Position = UDim2.new((i-1) / #tabs, 0, 0, 0)
    tabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    tabButton.Text = tabName
    tabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    tabButton.TextScaled = true
    tabButton.Parent = tabContainer
    
    tabButton.MouseButton1Click:Connect(function()
        switchTab(tabName)
    end)
end

-- Обработчики кнопок действий
equipButton.MouseButton1Click:Connect(function()
    if selectedAccessory and selectedAccessory.id then
        EquipEvent:FireServer(selectedAccessory.id)
    end
end)

unequipButton.MouseButton1Click:Connect(function()
    if selectedAccessory and selectedAccessory.id then
        UnequipEvent:FireServer(selectedAccessory.id)
    end
end)

upgradeButton.MouseButton1Click:Connect(function()
    if selectedAccessory then
        if selectedAccessory.id then
            -- Для RunningBoots используем улучшение модификатора, для остальных - улучшение уровня
            if selectedAccessory.name == "RunningBoots" then
                UpgradeModifierEvent:FireServer(selectedAccessory.id, 1)
            else
                UpgradeLevelEvent:FireServer(selectedAccessory.id)
            end
        else
            -- Для аксессуаров из магазина (без instanceId)
            warn("Please purchase the accessory first")
        end
    end
end)

purchaseButton.MouseButton1Click:Connect(function()
    if selectedAccessory then
        PurchaseEvent:FireServer(selectedAccessory.name)
    end
end)

deleteButton.MouseButton1Click:Connect(function()
    if selectedAccessory and selectedAccessory.id then
        -- Подтверждение удаления
        local confirmation = Instance.new("TextButton")
        confirmation.Size = UDim2.new(0.8, 0, 0, 100)
        confirmation.Position = UDim2.new(0.1, 0, 0.4, 0)
        confirmation.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
        confirmation.Text = "Are you sure?\nThis will permanently delete the accessory.\n\nClick again to confirm"
        confirmation.TextColor3 = Color3.fromRGB(255, 255, 255)
        confirmation.TextWrapped = true
        confirmation.ZIndex = 10
        confirmation.Parent = detailsFrame
        
        confirmation.MouseButton1Click:Connect(function()
            -- Здесь можно добавить вызов серверной функции для удаления
            confirmation:Destroy()
            warn("Delete functionality not implemented yet")
        end)
        
        -- Автоматическое скрытие через 3 секунды
        delay(3, function()
            if confirmation and confirmation.Parent then
                confirmation:Destroy()
            end
        end)
    end
end)

sellButton.MouseButton1Click:Connect(function()
    if selectedAccessory and selectedAccessory.id and selectedAccessory.sellPrice and selectedAccessory.sellPrice > 0 then
        -- Подтверждение продажи
        local confirmation = Instance.new("TextButton")
        confirmation.Size = UDim2.new(0.8, 0, 0, 100)
        confirmation.Position = UDim2.new(0.1, 0, 0.4, 0)
        confirmation.BackgroundColor3 = Color3.fromRGB(80, 60, 30)
        confirmation.Text = string.format("Sell for %d %s?\n\nClick again to confirm", 
            selectedAccessory.sellPrice, 
            selectedAccessory.currency or "Coins")
        confirmation.TextColor3 = Color3.fromRGB(255, 255, 255)
        confirmation.TextWrapped = true
        confirmation.ZIndex = 10
        confirmation.Parent = detailsFrame
        
        confirmation.MouseButton1Click:Connect(function()
            -- Здесь можно добавить вызов серверной функции для продажи
            confirmation:Destroy()
            warn("Sell functionality not implemented yet")
        end)
        
        -- Автоматическое скрытие через 3 секунды
        delay(3, function()
            if confirmation and confirmation.Parent then
                confirmation:Destroy()
            end
        end)
    end
end)

closeButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

-- Функция обновления информации о слотах
local function updateSlotInfo(slotInfo)
    if not slotInfo then return end
    
    local slotText = "SLOTS:\n"
    for category, info in pairs(slotInfo) do
        slotText ..= string.format("%s: %d/%d\n", category, info.Current, info.Max)
    end
    
    slotInfoLabel.Text = slotText
end

-- Функция загрузки данных
local function loadAccessoryData()
    local success, data = pcall(function()
        return GetAccessoryDataFunction:InvokeServer()
    end)
    
    if success and data then
        accessoryData = data
        updateContent()
        
        if accessoryData.slotInfo then
            updateSlotInfo(accessoryData.slotInfo)
        end
    else
        warn("Failed to load accessory data: " .. tostring(data))
    end
end

-- Обработчики событий от сервера
GetPlayerAccessoriesEvent.OnClientEvent:Connect(function(accessories)
    accessoryData.playerAccessories = accessories
    updateContent()
end)

GetSlotInfoEvent.OnClientEvent:Connect(function(slotInfo)
    updateSlotInfo(slotInfo)
end)

PurchaseEvent.OnClientEvent:Connect(function(success, accessoryName, data)
    if success then
        print("Successfully purchased:", accessoryName, "InstanceId:", data)
        loadAccessoryData() -- Перезагружаем данные
    else
        warn("Purchase failed:", data)
    end
end)

EquipEvent.OnClientEvent:Connect(function(success, instanceId, data)
    if success then
        print("Successfully equipped accessory:", instanceId)
        loadAccessoryData()
    else
        warn("Equip failed:", data)
    end
end)

UnequipEvent.OnClientEvent:Connect(function(success, instanceId, data)
    if success then
        print("Successfully unequipped accessory:", instanceId)
        loadAccessoryData()
    else
        warn("Unequip failed:", data)
    end
end)

UpgradeLevelEvent.OnClientEvent:Connect(function(success, instanceId, newLevel)
    if success then
        print("Successfully upgraded accessory to level:", newLevel)
        loadAccessoryData()
    else
        warn("Upgrade failed:", newLevel)
    end
end)

UpgradeModifierEvent.OnClientEvent:Connect(function(success, instanceId, modifierIndex, newLevel)
    if success then
        print("Successfully upgraded modifier", modifierIndex, "to level:", newLevel)
        loadAccessoryData()
    else
        warn("Modifier upgrade failed:", newLevel)
    end
end)

-- Клавиша для открытия/закрытия интерфейса
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.U then
        mainFrame.Visible = not mainFrame.Visible
        if mainFrame.Visible then
            loadAccessoryData()
        end
    end
end)

-- Инструкция
local instructionLabel = Instance.new("TextLabel")
instructionLabel.Name = "InstructionLabel"
instructionLabel.Size = UDim2.new(0, 300, 0, 40)
instructionLabel.Position = UDim2.new(0, 10, 1, -50)
instructionLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
instructionLabel.Text = "Press U to open Accessory System"
instructionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
instructionLabel.TextScaled = true
instructionLabel.Parent = screenGui

-- Инициализация
print("Accessory System UI loaded. Press U to open.")

-- Загружаем данные при старте
task.wait(2)
loadAccessoryData()

-- Инициализация первой вкладки
switchTab("Inventory")