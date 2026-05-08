local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("PetSystemEvents")
local openEggEvent = remoteEvents:WaitForChild("OpenEgg")
local equipPetEvent = remoteEvents:WaitForChild("EquipPet")
local unequipPetEvent = remoteEvents:WaitForChild("UnequipPet")
local upgradePetLevelEvent = remoteEvents:WaitForChild("UpgradePetLevel")
local upgradePetModifierEvent = remoteEvents:WaitForChild("UpgradePetModifier")
local getPetsDataEvent = remoteEvents:WaitForChild("GetPetsData")
local giveTestEggEvent = remoteEvents:WaitForChild("GiveTestEgg")

-- НОВЫЕ УДАЛЕННЫЕ СОБЫТИЯ
local purchasePetEvent = remoteEvents:WaitForChild("PurchasePet")
local sellPetEvent = remoteEvents:WaitForChild("SellPet")
local purchaseEggEvent = remoteEvents:WaitForChild("PurchaseEgg")
local givePetEvent = remoteEvents:WaitForChild("GivePet")
local getPetSellPriceEvent = remoteEvents:WaitForChild("GetPetSellPrice")

-- Инициализация клиентской части системы питомцев
local petsFolder = workspace:WaitForChild("Player_Pets")
if ReplicatedStorage:FindFirstChild("PetClient") then
    local PetClient = require(ReplicatedStorage:WaitForChild("PetClient"))
    PetClient:Init(petsFolder)
end

-- Создание интерфейса
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetSystemUI"
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 500, 0, 600) -- Увеличили размер для новых функций
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -300)
mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Система Питомцев"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -30, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 16
closeButton.Parent = mainFrame

closeButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, 0, 0, 40)
tabsFrame.Position = UDim2.new(0, 0, 0, 40)
tabsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
tabsFrame.BorderSizePixel = 0
tabsFrame.Parent = mainFrame

-- Добавляем новую вкладку для магазина
local inventoryTab = Instance.new("TextButton")
inventoryTab.Size = UDim2.new(0.33, 0, 1, 0)
inventoryTab.Position = UDim2.new(0, 0, 0, 0)
inventoryTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
inventoryTab.TextColor3 = Color3.fromRGB(255, 255, 255)
inventoryTab.Text = "Инвентарь"
inventoryTab.Font = Enum.Font.SourceSans
inventoryTab.TextSize = 16
inventoryTab.Parent = tabsFrame

local equippedTab = Instance.new("TextButton")
equippedTab.Size = UDim2.new(0.33, 0, 1, 0)
equippedTab.Position = UDim2.new(0.33, 0, 0, 0)
equippedTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
equippedTab.TextColor3 = Color3.fromRGB(255, 255, 255)
equippedTab.Text = "Экипированные"
equippedTab.Font = Enum.Font.SourceSans
equippedTab.TextSize = 16
equippedTab.Parent = tabsFrame

-- Новая вкладка магазина
local shopTab = Instance.new("TextButton")
shopTab.Size = UDim2.new(0.34, 0, 1, 0)
shopTab.Position = UDim2.new(0.66, 0, 0, 0)
shopTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
shopTab.TextColor3 = Color3.fromRGB(255, 255, 255)
shopTab.Text = "Магазин"
shopTab.Font = Enum.Font.SourceSans
shopTab.TextSize = 16
shopTab.Parent = tabsFrame

local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Size = UDim2.new(1, -10, 1, -90)
contentFrame.Position = UDim2.new(0, 5, 0, 85)
contentFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
contentFrame.BorderSizePixel = 0
contentFrame.ScrollBarThickness = 8
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.Parent = mainFrame

-- Панель быстрых действий
local quickActionsFrame = Instance.new("Frame")
quickActionsFrame.Size = UDim2.new(0, 320, 0, 120)
quickActionsFrame.Position = UDim2.new(0, 10, 0, 60)
quickActionsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
quickActionsFrame.BorderSizePixel = 0
quickActionsFrame.Parent = screenGui

local openEggButton = Instance.new("TextButton")
openEggButton.Size = UDim2.new(0, 150, 0, 40)
openEggButton.Position = UDim2.new(0, 10, 0, 10)
openEggButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
openEggButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openEggButton.Text = "Открыть яйцо"
openEggButton.Font = Enum.Font.SourceSans
openEggButton.TextSize = 16
openEggButton.Parent = quickActionsFrame

local purchaseEggButton = Instance.new("TextButton")
purchaseEggButton.Size = UDim2.new(0, 150, 0, 40)
purchaseEggButton.Position = UDim2.new(0, 10, 0, 60)
purchaseEggButton.BackgroundColor3 = Color3.fromRGB(120, 80, 40)
purchaseEggButton.TextColor3 = Color3.fromRGB(255, 255, 255)
purchaseEggButton.Text = "Купить яйцо (100 Coins)"
purchaseEggButton.Font = Enum.Font.SourceSans
purchaseEggButton.TextSize = 14
purchaseEggButton.Parent = quickActionsFrame

local toggleUIButton = Instance.new("TextButton")
toggleUIButton.Size = UDim2.new(0, 150, 0, 40)
toggleUIButton.Position = UDim2.new(0, 170, 0, 10)
toggleUIButton.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
toggleUIButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleUIButton.Text = "Открыть меню"
toggleUIButton.Font = Enum.Font.SourceSans
toggleUIButton.TextSize = 16
toggleUIButton.Parent = quickActionsFrame

local givePetButton = Instance.new("TextButton")
givePetButton.Size = UDim2.new(0, 150, 0, 40)
givePetButton.Position = UDim2.new(0, 170, 0, 60)
givePetButton.BackgroundColor3 = Color3.fromRGB(80, 60, 120)
givePetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
givePetButton.Text = "Выдать питомца"
givePetButton.Font = Enum.Font.SourceSans
givePetButton.TextSize = 14
givePetButton.Parent = quickActionsFrame

local currentView = "inventory"
local createPetCard, updatePetsUI, createShopItem

-- Функция для создания карточки товара в магазине
createShopItem = function(itemName, itemType, price, currency)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -10, 0, 80)
    card.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    card.BorderSizePixel = 0
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.6, 0, 0, 30)
    nameLabel.Position = UDim2.new(0, 10, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Text = itemName
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 18
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = card
    
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Size = UDim2.new(0.6, 0, 0, 20)
    priceLabel.Position = UDim2.new(0, 10, 0, 40)
    priceLabel.BackgroundTransparency = 1
    priceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    priceLabel.Text = "Цена: " .. price .. " " .. currency
    priceLabel.Font = Enum.Font.SourceSans
    priceLabel.TextSize = 14
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.Parent = card
    
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Size = UDim2.new(0, 120, 0, 40)
    purchaseButton.Position = UDim2.new(1, -130, 0, 20)
    purchaseButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseButton.Text = "Купить"
    purchaseButton.Font = Enum.Font.SourceSans
    purchaseButton.TextSize = 14
    purchaseButton.Parent = card
    
    purchaseButton.MouseButton1Click:Connect(function()
        if itemType == "pet" then
            purchasePetEvent:FireServer(itemName)
        elseif itemType == "egg" then
            purchaseEggEvent:FireServer(itemName)
        end
        wait(0.5)
        updatePetsUI()
    end)
    
    return card
end

-- Функция для создания карточки питомца
createPetCard = function(petData, instanceId, isEquipped)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -10, 0, 140) -- Увеличили высоту для новых кнопок
    card.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    card.BorderSizePixel = 0
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.7, 0, 0, 30)
    nameLabel.Position = UDim2.new(0, 10, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Text = petData.name
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 18
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = card
    
    -- Отображение метода получения
    local methodLabel = Instance.new("TextLabel")
    methodLabel.Size = UDim2.new(0.7, 0, 0, 20)
    methodLabel.Position = UDim2.new(0, 10, 0, 40)
    methodLabel.BackgroundTransparency = 1
    methodLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    
    local methodText = "Получен: "
    if petData.obtainedMethod == "purchased" then
        methodText = methodText .. "покупка"
    elseif petData.obtainedMethod == "egg" then
        methodText = methodText .. "яйцо"
    else
        methodText = methodText .. "выдача"
    end
    
    methodLabel.Text = methodText
    methodLabel.Font = Enum.Font.SourceSans
    methodLabel.TextSize = 12
    methodLabel.TextXAlignment = Enum.TextXAlignment.Left
    methodLabel.Parent = card
    
    -- Отображение уровня питомца (если есть)
    if petData.level then
        local levelLabel = Instance.new("TextLabel")
        levelLabel.Size = UDim2.new(0.7, 0, 0, 20)
        levelLabel.Position = UDim2.new(0, 10, 0, 60)
        levelLabel.BackgroundTransparency = 1
        levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        levelLabel.Text = "Уровень: " .. petData.level
        levelLabel.Font = Enum.Font.SourceSans
        levelLabel.TextSize = 14
        levelLabel.TextXAlignment = Enum.TextXAlignment.Left
        levelLabel.Parent = card
    end
    
    -- Кнопки действий
    local actionButton = Instance.new("TextButton")
    actionButton.Size = UDim2.new(0, 100, 0, 30)
    actionButton.Position = UDim2.new(1, -110, 0, 10)
    actionButton.Font = Enum.Font.SourceSans
    actionButton.TextSize = 14
    
    if isEquipped then
        actionButton.Text = "Снять"
        actionButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    else
        actionButton.Text = "Экипировать"
        actionButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    end
    actionButton.Parent = card
    
    actionButton.MouseButton1Click:Connect(function()
        if isEquipped then
            unequipPetEvent:FireServer(instanceId)
        else
            equipPetEvent:FireServer(instanceId)
        end
        wait(0.5)
        updatePetsUI()
    end)
    
    -- Кнопка продажи (только если питомец можно продать)
    if petData.price and petData.currency and petData.sellPercentage then
        local sellButton = Instance.new("TextButton")
        sellButton.Size = UDim2.new(0, 100, 0, 30)
        sellButton.Position = UDim2.new(1, -110, 0, 45)
        sellButton.BackgroundColor3 = Color3.fromRGB(160, 80, 40)
        sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        sellButton.Text = "Продать"
        sellButton.Font = Enum.Font.SourceSans
        sellButton.TextSize = 14
        sellButton.Parent = card
        
        sellButton.MouseButton1Click:Connect(function()
            -- Запрашиваем цену продажи
            local sellInfo = getPetSellPriceEvent:InvokeServer(instanceId)
            if sellInfo then
                local confirm = Instance.new("TextButton")
                confirm.Size = UDim2.new(0, 100, 0, 30)
                confirm.Position = UDim2.new(1, -110, 0, 80)
                confirm.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                confirm.TextColor3 = Color3.fromRGB(255, 255, 255)
                confirm.Text = "Подтвердить"
                confirm.Font = Enum.Font.SourceSans
                confirm.TextSize = 12
                confirm.Parent = card
                
                local priceLabel = Instance.new("TextLabel")
                priceLabel.Size = UDim2.new(0.7, 0, 0, 20)
                priceLabel.Position = UDim2.new(0, 10, 0, 100)
                priceLabel.BackgroundTransparency = 1
                priceLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                priceLabel.Text = "Цена продажи: " .. sellInfo.amount .. " " .. sellInfo.currency
                priceLabel.Font = Enum.Font.SourceSans
                priceLabel.TextSize = 12
                priceLabel.TextXAlignment = Enum.TextXAlignment.Left
                priceLabel.Parent = card
                
                confirm.MouseButton1Click:Connect(function()
                    sellPetEvent:FireServer(instanceId)
                    wait(0.5)
                    updatePetsUI()
                end)
            end
        end)
    end
    
    -- Кнопка улучшения общего уровня (только для питомцев с общей системой уровней)
    if petData.hasGlobalLevel then
        local upgradeButton = Instance.new("TextButton")
        upgradeButton.Size = UDim2.new(0, 100, 0, 30)
        upgradeButton.Position = UDim2.new(1, -220, 0, 10)
        upgradeButton.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
        upgradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        upgradeButton.Text = "Улучшить"
        upgradeButton.Font = Enum.Font.SourceSans
        upgradeButton.TextSize = 14
        upgradeButton.Parent = card
        
        upgradeButton.MouseButton1Click:Connect(function()
            upgradePetLevelEvent:FireServer(instanceId)
            wait(0.5)
            updatePetsUI()
        end)
    end
    
    -- Отображение и кнопки улучшения для модификаторов с индивидуальными уровнями
    if petData.modifierLevels then
        local yOffset = 80
        for i, modifierData in pairs(petData.modifierLevels) do
            if type(modifierData) == "table" then
                local modifierLabel = Instance.new("TextLabel")
                modifierLabel.Size = UDim2.new(0.7, 0, 0, 20)
                modifierLabel.Position = UDim2.new(0, 10, 0, yOffset)
                modifierLabel.BackgroundTransparency = 1
                modifierLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                
                if modifierData.maxLevel then
                    modifierLabel.Text = "Мод. " .. i .. ": Ур. " .. modifierData.level .. "/" .. modifierData.maxLevel
                else
                    modifierLabel.Text = "Мод. " .. i .. ": Ур. " .. modifierData.level
                end
                
                modifierLabel.Font = Enum.Font.SourceSans
                modifierLabel.TextSize = 12
                modifierLabel.TextXAlignment = Enum.TextXAlignment.Left
                modifierLabel.Parent = card
                
                -- Кнопка улучшения модификатора (только если у модификатора есть система уровней)
                if modifierData.canUpgrade then
                    local modUpgradeButton = Instance.new("TextButton")
                    modUpgradeButton.Size = UDim2.new(0, 80, 0, 20)
                    modUpgradeButton.Position = UDim2.new(1, -220, 0, yOffset)
                    modUpgradeButton.BackgroundColor3 = Color3.fromRGB(80, 120, 180)
                    modUpgradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                    modUpgradeButton.Text = "Улучшить"
                    modUpgradeButton.Font = Enum.Font.SourceSans
                    modUpgradeButton.TextSize = 10
                    modUpgradeButton.Parent = card
                    
                    modUpgradeButton.MouseButton1Click:Connect(function()
                        upgradePetModifierEvent:FireServer(instanceId, i)
                        wait(0.5)
                        updatePetsUI()
                    end)
                end
                
                yOffset = yOffset + 25
            end
        end
    end
    
    return card
end

-- Функция для обновления интерфейса питомцев
updatePetsUI = function()
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local petsData = getPetsDataEvent:InvokeServer()
    
    if currentView == "inventory" then
        inventoryTab.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        equippedTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        shopTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        
        if petsData.inventory then
            local yOffset = 5
            for instanceId, petData in pairs(petsData.inventory) do
                local isEquipped = false
                if petsData.equipped then
                    for _, equippedId in ipairs(petsData.equipped) do
                        if equippedId == instanceId then
                            isEquipped = true
                            break
                        end
                    end
                end
                
                local card = createPetCard(petData, instanceId, isEquipped)
                card.Position = UDim2.new(0, 5, 0, yOffset)
                card.Parent = contentFrame
                
                yOffset = yOffset + card.Size.Y.Offset + 10
            end
        end
    elseif currentView == "equipped" then
        inventoryTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        equippedTab.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        shopTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        
        if petsData.equipped and petsData.inventory then
            local yOffset = 5
            for _, instanceId in ipairs(petsData.equipped) do
                local petData = petsData.inventory[instanceId]
                if petData then
                    local card = createPetCard(petData, instanceId, true)
                    card.Position = UDim2.new(0, 5, 0, yOffset)
                    card.Parent = contentFrame
                    
                    yOffset = yOffset + card.Size.Y.Offset + 10
                end
            end
        end
    elseif currentView == "shop" then
        inventoryTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        equippedTab.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        shopTab.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        
        -- Создаем карточки для покупки питомцев
        local yOffset = 5
        
        -- Питомец Bear
        local bearCard = createShopItem("Bear", "pet", 200, "Coins")
        bearCard.Position = UDim2.new(0, 5, 0, yOffset)
        bearCard.Parent = contentFrame
        yOffset = yOffset + bearCard.Size.Y.Offset + 10
        
        -- Питомец Bunny
        local bunnyCard = createShopItem("Bunny", "pet", 150, "Coins")
        bunnyCard.Position = UDim2.new(0, 5, 0, yOffset)
        bunnyCard.Parent = contentFrame
        yOffset = yOffset + bunnyCard.Size.Y.Offset + 10
        
        -- Питомец Fox
        local foxCard = createShopItem("Fox", "pet", 300, "Gems")
        foxCard.Position = UDim2.new(0, 5, 0, yOffset)
        foxCard.Parent = contentFrame
        yOffset = yOffset + foxCard.Size.Y.Offset + 10
        
        -- Яйцо BasicEgg
        local eggCard = createShopItem("BasicEgg", "egg", 100, "Coins")
        eggCard.Position = UDim2.new(0, 5, 0, yOffset)
        eggCard.Parent = contentFrame
    end
end

-- Обработчики событий кнопок
inventoryTab.MouseButton1Click:Connect(function()
    currentView = "inventory"
    updatePetsUI()
end)

equippedTab.MouseButton1Click:Connect(function()
    currentView = "equipped"
    updatePetsUI()
end)

shopTab.MouseButton1Click:Connect(function()
    currentView = "shop"
    updatePetsUI()
end)

openEggButton.MouseButton1Click:Connect(function()
    openEggEvent:FireServer("BasicEgg")
end)

purchaseEggButton.MouseButton1Click:Connect(function()
    purchaseEggEvent:FireServer("BasicEgg")
end)

toggleUIButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
    if mainFrame.Visible then
        updatePetsUI()
    end
end)

givePetButton.MouseButton1Click:Connect(function()
    -- Создаем меню выбора питомца для выдачи
    local selectionFrame = Instance.new("Frame")
    selectionFrame.Size = UDim2.new(0, 200, 0, 150)
    selectionFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
    selectionFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    selectionFrame.BorderSizePixel = 0
    selectionFrame.Parent = screenGui
    
    local selectionTitle = Instance.new("TextLabel")
    selectionTitle.Size = UDim2.new(1, 0, 0, 30)
    selectionTitle.Position = UDim2.new(0, 0, 0, 0)
    selectionTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    selectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectionTitle.Text = "Выберите питомца"
    selectionTitle.Font = Enum.Font.SourceSansBold
    selectionTitle.TextSize = 16
    selectionTitle.Parent = selectionFrame
    
    local bearButton = Instance.new("TextButton")
    bearButton.Size = UDim2.new(0.8, 0, 0, 30)
    bearButton.Position = UDim2.new(0.1, 0, 0, 40)
    bearButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    bearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    bearButton.Text = "Выдать Bear"
    bearButton.Font = Enum.Font.SourceSans
    bearButton.TextSize = 14
    bearButton.Parent = selectionFrame
    
    local bunnyButton = Instance.new("TextButton")
    bunnyButton.Size = UDim2.new(0.8, 0, 0, 30)
    bunnyButton.Position = UDim2.new(0.1, 0, 0, 80)
    bunnyButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    bunnyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    bunnyButton.Text = "Выдать Bunny"
    bunnyButton.Font = Enum.Font.SourceSans
    bunnyButton.TextSize = 14
    bunnyButton.Parent = selectionFrame
    
    local closeSelectionButton = Instance.new("TextButton")
    closeSelectionButton.Size = UDim2.new(0.8, 0, 0, 30)
    closeSelectionButton.Position = UDim2.new(0.1, 0, 0, 120)
    closeSelectionButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    closeSelectionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeSelectionButton.Text = "Закрыть"
    closeSelectionButton.Font = Enum.Font.SourceSans
    closeSelectionButton.TextSize = 14
    closeSelectionButton.Parent = selectionFrame
    
    bearButton.MouseButton1Click:Connect(function()
        givePetEvent:FireServer("Bear")
        selectionFrame:Destroy()
        wait(0.5)
        updatePetsUI()
    end)
    
    bunnyButton.MouseButton1Click:Connect(function()
        givePetEvent:FireServer("Bunny")
        selectionFrame:Destroy()
        wait(0.5)
        updatePetsUI()
    end)
    
    closeSelectionButton.MouseButton1Click:Connect(function()
        selectionFrame:Destroy()
    end)
end)

-- Обработчики ответов от сервера
openEggEvent.OnClientEvent:Connect(function(success, message, petInfo)
    if success then
        print("Получен питомец:", petInfo.name)
    else
        warn("Ошибка открытия яйца:", message)
    end
end)

equipPetEvent.OnClientEvent:Connect(function(success, message)
    if not success then
        warn("Ошибка экипировки:", message)
    end
end)

unequipPetEvent.OnClientEvent:Connect(function(success, message)
    if not success then
        warn("Ошибка снятия питомца:", message)
    end
end)

upgradePetLevelEvent.OnClientEvent:Connect(function(success, message)
    if not success then
        warn("Ошибка улучшения уровня:", message)
    end
end)

upgradePetModifierEvent.OnClientEvent:Connect(function(success, message)
    if not success then
        warn("Ошибка улучшения модификатора:", message)
    end
end)

-- НОВЫЕ ОБРАБОТЧИКИ ДЛЯ НОВОГО ФУНКЦИОНАЛА
purchasePetEvent.OnClientEvent:Connect(function(success, message, instanceId)
    if success then
        print("Питомец куплен:", instanceId)
    else
        warn("Ошибка покупки питомца:", message)
    end
end)

sellPetEvent.OnClientEvent:Connect(function(success, message, sellPrice)
    if success then
        print("Питомец продан за:", sellPrice)
    else
        warn("Ошибка продажи питомца:", message)
    end
end)

purchaseEggEvent.OnClientEvent:Connect(function(success, message, instanceId)
    if success then
        print("Яйцо куплено и открыто:", instanceId)
    else
        warn("Ошибка покупки яйца:", message)
    end
end)

givePetEvent.OnClientEvent:Connect(function(success, message, instanceId)
    if success then
        print("Питомец выдан:", instanceId)
    else
        warn("Ошибка выдачи питомца:", message)
    end
end)

-- Запрос тестового яйца при запуске
giveTestEggEvent:FireServer("BasicEgg")

-- Инициализация интерфейса
updatePetsUI()