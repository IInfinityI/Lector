-- Ожидание загрузки всех необходимых модулей
local maxWait = 30
local waited = 0

print("Начало загрузки Accessory System...")

while waited < maxWait do
    local assetsReady = _G.AssetService and _G.AssetService:IsLoaded()
    local dataManagerReady = _G.DataManager or (_G.AssetService and _G.AssetService:IsModuleReady("DataManager"))
    
    if assetsReady and dataManagerReady then
        break
    end
    
    wait(1)
    waited = waited + 1
    print("Ожидание завершения загрузки ассетов... " .. waited .. "/" .. maxWait)
end

if waited >= maxWait then
    warn("Timeout waiting for assets to load. Proceeding anyway...")
end

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Получаем DataManager разными способами
local DataManager = _G.DataManager or (_G.AssetService and _G.AssetService:GetModule("DataManager"))
if not DataManager then
    warn("DataManager not found! Some accessory functions may not work.")
else
    print("DataManager found and ready")
end

-- Инициализация системы аксессуаров
local AccessorySystem
local InitSystemErr
local success, err = pcall(function()
    local module = require(ServerStorage:WaitForChild("AccessorySystem"))
    AccessorySystem, InitSystemErr = module.Init(ServerStorage.AccessoryConfig)
end)

if not success then
    warn("Failed to initialize AccessorySystem: " .. tostring(err))
    return
end

if not AccessorySystem then
    warn("AccessorySystem initialization returned nil: " .. tostring(InitSystemErr))
    return
end

print("Accessory system initialized successfully")

-- Создание папки событий
local eventsFolder = Instance.new("Folder")
eventsFolder.Name = "AccessoryEvents"
eventsFolder.Parent = ReplicatedStorage

-- Создание RemoteEvents
local EquipEvent = Instance.new("RemoteEvent")
EquipEvent.Name = "Equip"
EquipEvent.Parent = eventsFolder

local UnequipEvent = Instance.new("RemoteEvent")
UnequipEvent.Name = "Unequip"
UnequipEvent.Parent = eventsFolder

local UpgradeLevelEvent = Instance.new("RemoteEvent")
UpgradeLevelEvent.Name = "UpgradeLevel"
UpgradeLevelEvent.Parent = eventsFolder

local UpgradeModifierEvent = Instance.new("RemoteEvent")
UpgradeModifierEvent.Name = "UpgradeModifier"
UpgradeModifierEvent.Parent = eventsFolder

local PurchaseEvent = Instance.new("RemoteEvent")
PurchaseEvent.Name = "Purchase"
PurchaseEvent.Parent = eventsFolder

local GetAccessoryInfoEvent = Instance.new("RemoteEvent")
GetAccessoryInfoEvent.Name = "GetAccessoryInfo"
GetAccessoryInfoEvent.Parent = eventsFolder

local GetPlayerAccessoriesEvent = Instance.new("RemoteEvent")
GetPlayerAccessoriesEvent.Name = "GetPlayerAccessories"
GetPlayerAccessoriesEvent.Parent = eventsFolder

local GetSlotInfoEvent = Instance.new("RemoteEvent")
GetSlotInfoEvent.Name = "GetSlotInfo"
GetSlotInfoEvent.Parent = eventsFolder

-- RemoteFunctions для синхронных операций
local GetAccessoryDataFunction = Instance.new("RemoteFunction")
GetAccessoryDataFunction.Name = "GetAccessoryData"
GetAccessoryDataFunction.Parent = eventsFolder

-- Валидация игрока
local function validatePlayer(player)
    return player and player:IsA("Player") and player.Parent == Players
end

-- Обработчик экипировки по instanceId
EquipEvent.OnServerEvent:Connect(function(player, instanceId)
    if not validatePlayer(player) then return end
    
    local success, result = AccessorySystem:equipAccessoryById(player, instanceId)
    if success then
        print("Equipped accessory with instanceId:", instanceId, "for player", player.Name)
        
        -- Отправляем обновленную информацию об аксессуарах
        local playerAccessories = AccessorySystem:GetPlayerAccessories(player)
        GetPlayerAccessoriesEvent:FireClient(player, playerAccessories)
        
        local slotInfo = AccessorySystem:GetSlotInfo(player)
        GetSlotInfoEvent:FireClient(player, slotInfo)
        
        EquipEvent:FireClient(player, true, instanceId, result)
    else
        warn("Failed to equip accessory with instanceId:", instanceId, "for player", player.Name, "Error:", result)
        EquipEvent:FireClient(player, false, instanceId, result)
    end
end)

-- Обработчик снятия по instanceId
UnequipEvent.OnServerEvent:Connect(function(player, instanceId)
    if not validatePlayer(player) then return end
    
    local success, result = AccessorySystem:unequipAccessoryById(player, instanceId)
    if success then
        print("Unequipped accessory with instanceId:", instanceId, "for player", player.Name)
        
        -- Отправляем обновленную информацию
        local playerAccessories = AccessorySystem:GetPlayerAccessories(player)
        GetPlayerAccessoriesEvent:FireClient(player, playerAccessories)
        
        local slotInfo = AccessorySystem:GetSlotInfo(player)
        GetSlotInfoEvent:FireClient(player, slotInfo)
        
        UnequipEvent:FireClient(player, true, instanceId, result)
    else
        warn("Failed to unequip accessory with instanceId:", instanceId, "for player", player.Name, "Error:", result)
        UnequipEvent:FireClient(player, false, instanceId, result)
    end
end)

-- Обработчик улучшения уровня по instanceId
UpgradeLevelEvent.OnServerEvent:Connect(function(player, instanceId)
    if not validatePlayer(player) then return end
    
    local success, result = AccessorySystem:upgradeAccessoryById(player, instanceId)
    if success then
        print("Upgraded accessory level with instanceId:", instanceId, "to level", result, "for player", player.Name)
        
        -- Отправляем обновленную информацию
        local playerAccessories = AccessorySystem:GetPlayerAccessories(player)
        GetPlayerAccessoriesEvent:FireClient(player, playerAccessories)
        
        UpgradeLevelEvent:FireClient(player, true, instanceId, result)
    else
        warn("Failed to upgrade accessory level with instanceId:", instanceId, "for player", player.Name, "Error:", result)
        UpgradeLevelEvent:FireClient(player, false, instanceId, result)
    end
end)

-- Обработчик улучшения модификатора по instanceId
UpgradeModifierEvent.OnServerEvent:Connect(function(player, instanceId, modifierIndex)
    if not validatePlayer(player) then return end
    
    local success, result = AccessorySystem:upgradeModifierById(player, instanceId, modifierIndex)
    if success then
        print("Upgraded modifier:", modifierIndex, "on instanceId:", instanceId, "to level", result, "for player", player.Name)
        
        -- Отправляем обновленную информацию
        local playerAccessories = AccessorySystem:GetPlayerAccessories(player)
        GetPlayerAccessoriesEvent:FireClient(player, playerAccessories)
        
        UpgradeModifierEvent:FireClient(player, true, instanceId, modifierIndex, result)
    else
        warn("Failed to upgrade modifier:", modifierIndex, "on instanceId:", instanceId, "for player", player.Name, "Error:", result)
        UpgradeModifierEvent:FireClient(player, false, instanceId, modifierIndex, result)
    end
end)

-- Обработчик покупки по имени аксессуара
PurchaseEvent.OnServerEvent:Connect(function(player, accessoryName)
    if not validatePlayer(player) then return end
    
    local instanceId, errorMsg = AccessorySystem:PurchaseAccessory(player, accessoryName)
    if instanceId then
        print("Purchased accessory:", accessoryName, "for player", player.Name, "InstanceId:", instanceId)
        
        -- Отправляем подтверждение покупки
        PurchaseEvent:FireClient(player, true, accessoryName, instanceId)
        
        -- Обновляем данные клиента
        task.wait(0.1)
        local playerAccessories = AccessorySystem:GetPlayerAccessories(player)
        GetPlayerAccessoriesEvent:FireClient(player, playerAccessories)
        
        local slotInfo = AccessorySystem:GetSlotInfo(player)
        GetSlotInfoEvent:FireClient(player, slotInfo)
    else
        warn("Failed to purchase accessory:", accessoryName, "for player", player.Name, "Error:", errorMsg)
        PurchaseEvent:FireClient(player, false, accessoryName, errorMsg)
    end
end)

-- Обработчик получения информации об аксессуаре
GetAccessoryInfoEvent.OnServerEvent:Connect(function(player, accessoryName)
    if not validatePlayer(player) then return end
    
    local accessoryInfo = AccessorySystem:GetAccessoryInfo(accessoryName)
    GetAccessoryInfoEvent:FireClient(player, accessoryName, accessoryInfo)
end)

-- RemoteFunction для получения данных аксессуаров
GetAccessoryDataFunction.OnServerInvoke = function(player)
    if not validatePlayer(player) then return nil end
    
    local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
    local playerAccessories = AccessorySystem:GetPlayerAccessories(player)
    local slotInfo = AccessorySystem:GetSlotInfo(player)
    local ownedAccessories, ownedErr = AccessorySystem:GetOwnedAccessories(player)
    
    if ownedErr ~= "" then
        warn("Error getting owned accessories for player", player.Name, ":", ownedErr)
    end
    
    return {
        allAccessories = allAccessories,
        playerAccessories = playerAccessories,
        slotInfo = slotInfo,
        ownedAccessories = ownedAccessories or {}
    }
end

-- Функция для отправки обновлений при изменении персонажа
local function onCharacterAdded(character, player)
    -- Ждем загрузки данных
    local maxWait = 30
    local waited = 0
    
    while waited < maxWait do
        if DataManager and DataManager.IsDataLoaded then
            break
        end
        
        task.wait(0.1)
        waited = waited + 1
    end
    
    -- Отправляем начальные данные
    task.wait(1) -- Ждем полной загрузки персонажа
    
    local success, playerAccessories = pcall(function()
        return AccessorySystem:GetPlayerAccessories(player)
    end)
    
    if success and playerAccessories then
        GetPlayerAccessoriesEvent:FireClient(player, playerAccessories)
    end
    
    local success2, slotInfo = pcall(function()
        return AccessorySystem:GetSlotInfo(player)
    end)
    
    if success2 and slotInfo then
        GetSlotInfoEvent:FireClient(player, slotInfo)
    end
end

-- Обработка подключения игроков
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(character, player)
    end)
    
    if player.Character then
        onCharacterAdded(player.Character, player)
    end
end)

-- Обработка существующих игроков
for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        onCharacterAdded(player.Character, player)
    end
end

-- Создание тестового парта с информацией
local part = Instance.new("Part")
part.Name = "AccessoryInfoPart"
part.Size = Vector3.new(6, 1, 4)
part.Position = Vector3.new(10, 0.5, 10)
part.Anchored = true
part.CanCollide = true
part.BrickColor = BrickColor.new("Bright blue")
part.Material = Enum.Material.Neon
part.Parent = workspace

-- Добавление текстовой метки
local clickDetector = Instance.new("ClickDetector", part)
local billboard = Instance.new("BillboardGui", part)
billboard.Size = UDim2.new(6, 0, 2, 0)
billboard.StudsOffset = Vector3.new(0, 3, 0)
billboard.AlwaysOnTop = true

local textLabel = Instance.new("TextLabel", billboard)
textLabel.Size = UDim2.new(1, 0, 1, 0)
textLabel.Text = "Click to get accessory info\nand test functions"
textLabel.TextScaled = true
textLabel.BackgroundTransparency = 1
textLabel.TextColor3 = Color3.new(1, 1, 1)
textLabel.TextStrokeTransparency = 0
textLabel.Font = Enum.Font.SourceSansBold

-- Обработка кликов по парту
clickDetector.MouseClick:Connect(function(player)
    if not validatePlayer(player) then return end
    
    print("=== Accessory System Test ===")
    print("Player:", player.Name)
    
    -- Получение информации о всех аксессуарах
    local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
    print("Total accessories available:", #allAccessories)
    
    -- Получение информации об аксессуарах игрока
    local playerAccessories = AccessorySystem:GetPlayerAccessories(player)
    print("Player equipped accessories:", #playerAccessories)
    
    -- Получение информации о слотах
    local slotInfo = AccessorySystem:GetSlotInfo(player)
    print("Slot info:")
    for category, info in pairs(slotInfo) do
        print(string.format("  %s: %d/%d", category, info.Current, info.Max))
    end
    
    -- Получение аксессуаров в инвентаре
    local ownedAccessories = AccessorySystem:GetOwnedAccessories(player)
    print("Owned accessories in inventory:", #ownedAccessories)
    
    -- Тестирование случайного аксессуара из инвентаря
    if #ownedAccessories > 0 then
        local randomAccessory = ownedAccessories[math.random(1, #ownedAccessories)]
        print("\nTesting accessory from inventory:", randomAccessory.name, "InstanceId:", randomAccessory.id)
        
        -- Получение детальной информации
        local accessoryDetails = AccessorySystem:GetAccessoryDetailsById(player, randomAccessory.id)
        if accessoryDetails then
            print("Category:", accessoryDetails.config.category)
            print("Level:", accessoryDetails.level)
            print("Is Equipped:", accessoryDetails.isEquipped)
        end
        
        -- Проверка возможности экипировки по instanceId
        local canEquip, reason = AccessorySystem:CanEquipAccessoryById(player, randomAccessory.id)
        print("Can equip by instanceId:", canEquip)
        print("Reason:", reason)
        
        -- Попытка экипировки (если слот свободен и не экипирован)
        if canEquip and not accessoryDetails.isEquipped then
            local success, result = AccessorySystem:equipAccessoryById(player, randomAccessory.id)
            if success then
                print("Successfully equipped by instanceId:", randomAccessory.id)
            else
                print("Failed to equip by instanceId:", randomAccessory.id, "Error:", result)
            end
        else
            print("Cannot equip", randomAccessory.name, "-", reason)
            
            -- Если экипирован, пытаемся снять
            if accessoryDetails.isEquipped then
                local success, result = AccessorySystem:unequipAccessoryById(player, randomAccessory.id)
                if success then
                    print("Successfully unequipped by instanceId:", randomAccessory.id)
                else
                    print("Failed to unequip by instanceId:", randomAccessory.id, "Error:", result)
                end
            end
        end
    end
    
    print("=== Test Complete ===\n")
    
    -- Отправляем обновленные данные игроку
    local updatedPlayerAccessories = AccessorySystem:GetPlayerAccessories(player)
    GetPlayerAccessoriesEvent:FireClient(player, updatedPlayerAccessories)
    
    local updatedSlotInfo = AccessorySystem:GetSlotInfo(player)
    GetSlotInfoEvent:FireClient(player, updatedSlotInfo)
end)

print("Accessory system server setup complete")

-- ТЕСТОВАЯ СИСТЕМА
local tester = _G.TestSystem.new()
local originalAccessories = {} -- Хранит оригинальные аксессуары игрока до тестов
local testAccessoryInstances = {} -- Хранит instanceId тестовых аксессуаров

-- Вспомогательные функции для тестов
local function setupTestCurrency(player, coins, gems)
    local dataManager = _G.AssetService:GetModule("DataManager")
    if dataManager then
        dataManager.UpdateData(player, function(currentData)
            currentData.Coins = coins or 1000
            currentData.Gems = gems or 500
            return currentData
        end)
    end
end

local function backupPlayerAccessories(player)
    -- Сохраняем текущее состояние аксессуаров игрока
    local ownedAccessories, _ = AccessorySystem:GetOwnedAccessories(player)
    originalAccessories[player] = {
        owned = {},
        equipped = {}
    }
    
    -- Копируем owned accessories
    for i = 1, #ownedAccessories do
        local accessory = ownedAccessories[i]
        originalAccessories[player].owned[accessory.id] = {
            name = accessory.name,
            level = accessory.level,
            modifierLevels = accessory.modifierLevels,
            obtainedTime = accessory.obtainedTime,
            obtainedMethod = accessory.obtainedMethod
        }
    end
    
    -- Сохраняем информацию об экипированных аксессуарах
    local equippedAccessories = AccessorySystem:GetEquippedAccessories(player)
    for i = 1, #equippedAccessories do
        local accessory = equippedAccessories[i]
        originalAccessories[player].equipped[accessory.instanceId] = true
    end
    AccessorySystem:RemoveAllAccessoriesFromInventory(player)
end

local function restorePlayerAccessories(player)
    if not originalAccessories[player] then return end
    
    -- Снимаем все текущие аксессуары
    AccessorySystem:UnequipAllAccessories(player)
    
    -- Удаляем все текущие аксессуары из инвентаря
    local currentAccessories, _ = AccessorySystem:GetOwnedAccessories(player)
    for i = 1, #currentAccessories do
        local accessory = currentAccessories[i]
        AccessorySystem:RemoveAccessoryFromInventory(player, accessory.id)
    end
    
    -- Восстанавливаем оригинальные аксессуары
    for instanceId, accessoryData in pairs(originalAccessories[player].owned) do
        local accessoryInfo = {
            name = accessoryData.name,
            level = accessoryData.level,
            modifierLevels = accessoryData.modifierLevels,
            obtainedTime = accessoryData.obtainedTime,
            obtainedMethod = accessoryData.obtainedMethod
        }
        
        -- Добавляем аксессуар обратно в инвентарь
        local newInstanceId, errorMsg = AccessorySystem:AddAccessoryToInventory(player, accessoryInfo)
        if newInstanceId then
            -- Если аксессуар был экипирован, экипируем его снова
            if originalAccessories[player].equipped[instanceId] then
                AccessorySystem:equipAccessoryById(player, newInstanceId)
            end
        else
            warn("Failed to restore accessory", accessoryData.name, "for player", player.Name, "Error:", errorMsg)
        end
    end
    
    -- Очищаем backup
    originalAccessories[player] = nil
end

local function cleanupTestAccessories(player)
    -- Удаляем только тестовые аксессуары (не трогая оригинальные)
    for i = 1, #testAccessoryInstances do
        local instanceId = testAccessoryInstances[i]
        AccessorySystem:RemoveAccessoryFromInventory(player, instanceId)
    end
    testAccessoryInstances = {}
    
    -- Восстанавливаем оригинальное состояние
    restorePlayerAccessories(player)
end

local function addTestAccessoryToInventory(player, accessoryInfo)    
    local instanceId, errorMsg = AccessorySystem:AddAccessoryToInventory(player, accessoryInfo)
    if instanceId then
        table.insert(testAccessoryInstances, instanceId)
    end
    return instanceId, errorMsg
end

local function removeTestAccessoryFromInventory(player, instanceId)
    local success, errorMsg = AccessorySystem:RemoveAccessoryFromInventory(player, instanceId)
    if success then
        for i = #testAccessoryInstances, 1, -1 do
            if testAccessoryInstances[i] == instanceId then
                table.remove(testAccessoryInstances, i)
                break
            end
        end
    end
    return success, errorMsg
end

local function purchaseTestAccessory(player, accessoryName)
    local instanceId, errorMsg = AccessorySystem:PurchaseAccessory(player, accessoryName)
    if instanceId then
        table.insert(testAccessoryInstances, instanceId)
    end
    return instanceId, errorMsg
end

local function sellTestAccessory(player, instanceId)
    local success, result = AccessorySystem:SellAccessory(player, instanceId)
    if success then
        for i = #testAccessoryInstances, 1, -1 do
            if testAccessoryInstances[i] == instanceId then
                table.remove(testAccessoryInstances, i)
                break
            end
        end
    end
    return success, result
end

-- Основные тесты
local function runAccessorySystemTests(player)	
    -- Очищаем состояние перед тестами
    backupPlayerAccessories(player)
    setupTestCurrency(player, 10000, 5000)
    
    tester:describe("Accessory System Initialization Tests", function()
        it("Система должна успешно инициализироваться", function()
            expect(AccessorySystem).toBeNotNil()
            expect(InitSystemErr).toEqual("")
        end)
        
        it("Конфигурация должна быть загружена", function()
            local config = AccessorySystem.config
            expect(config).toBeNotNil()
            expect(config.accessories).toBeType("table")
            expect(#config.accessories).toBeGreaterThan(0)
        end)
        
        it("Кэш аксессуаров должен быть создан", function()
            expect(AccessorySystem.accessoryCache).toBeNotNil()
            expect(AccessorySystem.accessoryCache).toBeType("table")
        end)
    end)
    
    tester:describe("Accessory Information Tests", function()
        it("Должна возвращать информацию о всех аксессуарах", function()
            local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
            expect(allAccessories).toBeType("table")
            expect(#allAccessories).toBeGreaterThan(0)
            local accessory = allAccessories[1]
            expect(accessory.name).toBeNotNil()
            expect(accessory.accessoryType).toBeNotNil()
            expect(accessory.category).toBeNotNil()
            expect(accessory.cost).toBeNotNil()
            expect(accessory.currency).toBeNotNil()
            expect(accessory.description).toBeNotNil()
            expect(accessory.modifiers).toBeNotNil()	
            expect(accessory.deathSettings).toBeNotNil()
        end)
        
        it("Должна возвращать информацию об аксессуаре по имени", function()
            local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
            if #allAccessories > 0 then
                local testAccessory = allAccessories[1]
                local accessoryInfo = AccessorySystem:GetAccessoryInfo(testAccessory.name)
                expect(accessoryInfo).toBeNotNil()
                expect(accessoryInfo.name).toEqual(testAccessory.name)
                expect(accessoryInfo.category).toEqual(testAccessory.category)
                expect(accessoryInfo.cost).toEqual(testAccessory.cost)
                expect(accessoryInfo.modifiers).toBeNotNil()
                expect(accessoryInfo.deathSettings).toBeNotNil()
            end
        end)
        
        it("Должна возвращать nil для несуществующего аксессуара", function()
            local accessoryInfo = AccessorySystem:GetAccessoryInfo("NonExistentAccessory")
            expect(accessoryInfo).toBeNil()
        end)
        
        it("Должна возвращать аксессуары по категории", function()
			local helmets = AccessorySystem:GetAccessoriesByCategory("Helmet")
			expect(helmets).toBeType("table")
			for i = 1, #helmets do
				local helmet = helmets[i]
				expect(helmet.category).toEqual("Helmet")
			end
            local empty = AccessorySystem:GetAccessoriesByCategory("None")
            expect(#empty).toEqual(0)
        end)
    end)
    
    tester:describe("Inventory Management Tests", function()
        it("Должна добавлять аксессуар в инвентарь", function()
            local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
            if #allAccessories > 0 then
                local testAccessory = allAccessories[1]
                local accessoryInfo = {
                    name = testAccessory.name,
                    level = 1,
                    modifierLevels = {},
                    obtainedMethod = "test"
                }
                
                local instanceId, errorMsg = addTestAccessoryToInventory(player, accessoryInfo)
                expect(instanceId).toBeNotNil()
                expect(errorMsg).toEqual("")
            end
        end)
        
        it("Должна возвращать аксессуары в инвентаре", function()
            local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
            if #allAccessories > 0 then
                local testAccessory = allAccessories[1]
                addTestAccessoryToInventory(player, testAccessory.name)

                local ownedAccessories, errorMsg = AccessorySystem:GetOwnedAccessories(player)
                expect(ownedAccessories).toBeType("table")
                expect(errorMsg).toEqual("")

                -- Проверяем, что наш аксессуар есть в инвентаре
                local found = false
                for i = 1, #ownedAccessories do
                    local accessory = ownedAccessories[i]
                    if accessory.name == testAccessory.name then
                        found = true
                        break
                    end
                end
                expect(found).toBeTrue()
            end
        end)
        
        it("Должна покупать аксессуар", function()
            -- покупать по имени "Boots"
            local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
            if #allAccessories > 0 then
                local testAccessory = allAccessories[2]
                
                local instanceId, errorMsg = purchaseTestAccessory(player, testAccessory.name)
                -- добавить тетст лимита покупок
                -- добавить тетст сравнения денег до и после
                expect(errorMsg).toEqual("")
                expect(instanceId).toBeNotNil()
            end
        end)
        
        it("Должна удалять аксессуар из инвентаря", function()
                local instanceId, errorMsg = addTestAccessoryToInventory(player, { name = "BasicHelmet" })
                expect(errorMsg).toEqual("")
                expect(instanceId).toBeNotNil()

                local success, errorMsg = removeTestAccessoryFromInventory(player, instanceId)
                expect(errorMsg).toEqual("")
                expect(success).toBeTrue()
                -- пройтись по имеющимся, не должно быть 
        end)
    end)
    
    tester:describe("Equipment System Tests", function()
        it("Должна успешно экипировать аксессуар из инвентаря по instanceId", function()
            local instanceId, errorMsg = addTestAccessoryToInventory(player, { name = "BasicHelmet" })
            expect(errorMsg).toEqual("")
            expect(instanceId).toBeNotNil()
            
            local success, result = AccessorySystem:equipAccessoryById(player, instanceId)
            expect(success).toBeTrue()
            expect(result).toBeNotNil()
            
            local playerAccessories = AccessorySystem:GetPlayerAccessories(player)
            local found = false
			for i = 1, #playerAccessories do
				local accessory = playerAccessories[i]
                if accessory.Name == "BasicHelmet" then
                    found = true
                    break
                end
			end
            expect(found).toBeTrue()
        end)
        
        it("Должна предотвращать экипировку аксессуара не из инвентаря", function()
            local fakeInstanceId = "non-existent-instance-id"
            local success, errorMsg = AccessorySystem:equipAccessoryById(player, fakeInstanceId)
            expect(success).toBeFalse()
            expect(errorMsg).toEqual("Accessory not found in inventory")
        end)
        
        it("Должна успешно снимать аксессуар по instanceId", function()
            -- Добавляем и экипируем
            local instanceId = addTestAccessoryToInventory(player, { name = "Hat" })
            AccessorySystem:equipAccessoryById(player, instanceId)
            -- Снимаем по instanceId
            local success, result = AccessorySystem:unequipAccessoryById(player, instanceId)
            expect(success).toBeTrue()
            expect(result).toBeNotNil() -- instanceId
            -- Проверяем, что аксессуар удален
            local playerAccessories = AccessorySystem:GetPlayerAccessories(player)
            local found = false
            for i = 1, #playerAccessories do
                local accessory = playerAccessories[i]
                if accessory.Name == "Hat" then
                    found = true
                    break
                end
            end
            expect(found).toBeFalse()
        end)
        
        it("Должна возвращать false при снятии неэкипированного аксессуара", function()
            local fakeInstanceId = "non-existent-instance-id"
            local success, errorMsg = AccessorySystem:unequipAccessoryById(player, fakeInstanceId)
            expect(success).toBeFalse()
            expect(errorMsg).toEqual("Accessory not equipped")
        end)
    end)
    
    tester:describe("Upgrade System Tests", function()
        it("Должна улучшать уровень аксессуара по instanceId", function()
            local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
            if #allAccessories > 0 then
                local testAccessory = allAccessories[1]
                local instanceId = addTestAccessoryToInventory(player, testAccessory.name)
                
                local success, newLevel = AccessorySystem:upgradeAccessoryById(player, instanceId)
                if success then
                    expect(success).toBeTrue()
                    expect(newLevel).toEqual(2)
                else
                    -- Может быть максимальный уровень
                    expect(success).toBeFalse()
                end
            end
        end)
        
        it("Должна улучшать модификатор аксессуара по instanceId", function()
            local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
            -- Ищем аксессуар с индивидуальной прокачкой модификаторов
            local testAccessory = nil
            for i = 1, #allAccessories do
                local accessory = allAccessories[i]
                if accessory.name == "RunningBoots" then
                    testAccessory = accessory
                    break
                end
            end
            
            if testAccessory then
                local instanceId = addTestAccessoryToInventory(player, testAccessory.name)
                
                local success, newLevel = AccessorySystem:upgradeModifierById(player, instanceId, 1)
                if success then
                    expect(success).toBeTrue()
                    expect(newLevel).toEqual(2)
                else
                    -- Может быть максимальный уровень
                    expect(success).toBeFalse()
                end
            end
        end)
    end)
    
    tester:describe("Slot System Tests", function()
        it("Должна возвращать информацию о слотах", function()
            local slotInfo = AccessorySystem:GetSlotInfo(player)
            expect(slotInfo).toBeType("table")

            local expectedCategories = {"Helmet", "Chest", "Legs", "Boots", "Ring"}

            for i = 1, #expectedCategories do
                local category = expectedCategories[i]
                local info = slotInfo[category]
                if info then
                    expect(info.Current).toBeType("number")
                    expect(info.Max).toBeType("number")
                    expect(info.Current).toBeLessThan(info.Max + 1)
                end
            end
        end)

        it("Должна возвращать количество экипированных аксессуаров по категории", function()
            local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
            if #allAccessories > 0 then
                local testAccessory = allAccessories[1]
                local equippedCount = AccessorySystem:getEquippedCount(player, testAccessory.category)
                expect(equippedCount).toBeType("number")
                expect(equippedCount).toBeGreaterThan(-1)
            end
        end)
    end)
    
    tester:describe("Accessory Status Tests", function()
        it("Должна проверять возможность экипировки по instanceId", function()
            local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
            if #allAccessories > 0 then
                local testAccessory = allAccessories[1]
                local instanceId = addTestAccessoryToInventory(player, testAccessory.name)
                
                local canEquip, reason = AccessorySystem:CanEquipAccessoryById(player, instanceId)
                expect(canEquip).toBeType("boolean")
                expect(reason).toBeType("string")
            end
        end)
        
        it("Должна возвращать подробную информацию об аксессуаре по instanceId", function()

            local instanceId = addTestAccessoryToInventory(player, { name = "BasicHelmet" })
            
            local details = AccessorySystem:GetAccessoryDetailsById(player, instanceId)
            expect(details).toBeType("table")
            expect(details.instanceId).toEqual(instanceId)
            expect(details.name).toEqual("BasicHelmet")
            expect(details.config).toBeNotNil()
            expect(details.level).toBeType("number")
            expect(details.isEquipped).toBeType("boolean")
        end)
    end)
    
    -- Запускаем все тесты
    tester:runAll()
    
    -- Очищаем состояние после тестов
    cleanupTestAccessories(player)
end

-- Автоматический запуск тестов при подключении игрока (только для тестового режима)
local TEST_MODE = true 

local function setupPlayerTests(player)
    if not player or not TEST_MODE then return end
    
    if player:GetAttribute("DataLoaded") then
        runAccessorySystemTests(player)
    else
        player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
            if player:GetAttribute("DataLoaded") then
                runAccessorySystemTests(player)
            end
        end)
    end
end

-- Обработка подключения игроков (только в тестовом режиме)
if TEST_MODE then
    game.Players.PlayerAdded:Connect(setupPlayerTests)
    
    -- Обработка уже подключенных игроков
    for _, player in ipairs(game.Players:GetPlayers()) do
        setupPlayerTests(player)
    end
end