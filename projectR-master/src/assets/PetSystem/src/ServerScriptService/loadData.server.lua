while not _G.AssetService or not _G.AssetService:IsLoaded() or not _G.DataManager or not _G.AssetService:IsModuleReady("DataManager") do
    wait(1)
    print("Ожидание завершения загрузки ассетов...")
end

local TestSystem = require(game:GetService("ServerScriptService"):WaitForChild("TestSystem"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Получаем DataManager через функцию
local DataManager = _G.DataManager

local PetsSystem = require(game.ServerStorage.PetSystem)
local Config = require(game.ServerStorage.PetConfig)
local petSystem, initError = PetsSystem.Init(Config)

local remoteEvents = Instance.new("Folder")
remoteEvents.Name = "PetSystemEvents"
remoteEvents.Parent = ReplicatedStorage

local openEggEvent = Instance.new("RemoteEvent")
openEggEvent.Name = "OpenEgg"
openEggEvent.Parent = remoteEvents

local equipPetEvent = Instance.new("RemoteEvent")
equipPetEvent.Name = "EquipPet"
equipPetEvent.Parent = remoteEvents

local unequipPetEvent = Instance.new("RemoteEvent")
unequipPetEvent.Name = "UnequipPet"
unequipPetEvent.Parent = remoteEvents

local upgradePetLevelEvent = Instance.new("RemoteEvent")
upgradePetLevelEvent.Name = "UpgradePetLevel"
upgradePetLevelEvent.Parent = remoteEvents

local upgradePetModifierEvent = Instance.new("RemoteEvent")
upgradePetModifierEvent.Name = "UpgradePetModifier"
upgradePetModifierEvent.Parent = remoteEvents

local getPetsDataEvent = Instance.new("RemoteFunction")
getPetsDataEvent.Name = "GetPetsData"
getPetsDataEvent.Parent = remoteEvents

local giveTestEggEvent = Instance.new("RemoteEvent")
giveTestEggEvent.Name = "GiveTestEgg"
giveTestEggEvent.Parent = remoteEvents

local purchasePetEvent = Instance.new("RemoteEvent")
purchasePetEvent.Name = "PurchasePet"
purchasePetEvent.Parent = remoteEvents

local sellPetEvent = Instance.new("RemoteEvent")
sellPetEvent.Name = "SellPet"
sellPetEvent.Parent = remoteEvents

local purchaseEggEvent = Instance.new("RemoteEvent")
purchaseEggEvent.Name = "PurchaseEgg"
purchaseEggEvent.Parent = remoteEvents

local givePetEvent = Instance.new("RemoteEvent")
givePetEvent.Name = "GivePet"
givePetEvent.Parent = remoteEvents

local getPetSellPriceEvent = Instance.new("RemoteFunction")
getPetSellPriceEvent.Name = "GetPetSellPrice"
getPetSellPriceEvent.Parent = remoteEvents

-- Автоматическое восстановление экипированных питомцев при входе
Players.PlayerAdded:Connect(function(player)
    -- PetSystem автоматически восстановит экипированных питомцев при создании папки игрока
    print("Player joined: " .. player.Name)
end)

openEggEvent.OnServerEvent:Connect(function(player, eggName)
    if not petSystem then
        openEggEvent:FireClient(player, false, "Система питомцев не инициализирована")
        return
    end

    local playerData = DataManager.GetData(player)
    if not playerData then 
        openEggEvent:FireClient(player, false, "Данные игрока не загружены")
        return 
    end

    -- Проверяем наличие яйца в инвентаре
    if not playerData.Inventory or not playerData.Inventory[eggName] or playerData.Inventory[eggName] <= 0 then
        openEggEvent:FireClient(player, false, "У вас нет этого яйца")
        return
    end

    -- Уменьшаем количество яиц
    playerData.Inventory[eggName] = playerData.Inventory[eggName] - 1
    if playerData.Inventory[eggName] <= 0 then
        playerData.Inventory[eggName] = nil
    end

    -- Открываем яйцо
    local petData, err = petSystem:ChoosePetFromEgg(eggName)
    if not petData then
        openEggEvent:FireClient(player, false, err or "Не удалось открыть яйцо")
        return
    end

    -- Добавляем питомца в инвентарь
    local instanceId, addErr = petSystem:AddPetToInventory(player, petData)
    if not instanceId then
        openEggEvent:FireClient(player, false, addErr or "Не удалось добавить питомца в инвентарь")
        return
    end

    -- Сохраняем обновленный инвентарь
    DataManager.UpdateData(player, playerData)
    openEggEvent:FireClient(player, true, petData, instanceId)
end)

equipPetEvent.OnServerEvent:Connect(function(player, instanceId)
    if not petSystem then
        equipPetEvent:FireClient(player, false, "Система питомцев не инициализирована")
        return
    end

    -- Экипируем питомца через систему
    local success, err = petSystem:EquipPet(player, instanceId)
    
    if not success then
        equipPetEvent:FireClient(player, false, err or "Ошибка экипировки")
        return
    end

    equipPetEvent:FireClient(player, true, "Питомец экипирован")
end)

unequipPetEvent.OnServerEvent:Connect(function(player, instanceId)
    if not petSystem then
        unequipPetEvent:FireClient(player, false, "Система питомцев не инициализирована")
        return
    end

    -- Снимаем питомца через систему
    local success, err = petSystem:UnequipPet(player, instanceId)
    
    if not success then
        unequipPetEvent:FireClient(player, false, err or "Ошибка снятия питомца")
        return
    end

    unequipPetEvent:FireClient(player, true, "Питомец снят")
end)

upgradePetLevelEvent.OnServerEvent:Connect(function(player, instanceId)
    if not petSystem then
        upgradePetLevelEvent:FireClient(player, false, "Система питомцев не инициализирована")
        return
    end

    -- Улучшаем уровень питомца через систему
    local upgradeCost, err = petSystem:UpgradePetLevel(player, instanceId)
    
    if not upgradeCost then
        upgradePetLevelEvent:FireClient(player, false, err or "Ошибка улучшения уровня")
        return
    end

    upgradePetLevelEvent:FireClient(player, true, "Уровень питомца улучшен", upgradeCost)
end)

upgradePetModifierEvent.OnServerEvent:Connect(function(player, instanceId, modifierIndex)
    if not petSystem then
        upgradePetModifierEvent:FireClient(player, false, "Система питомцев не инициализирована")
        return
    end

    -- Улучшаем модификатор питомца через систему
    local upgradeCost, err = petSystem:UpgradePetModifier(player, instanceId, modifierIndex)
    
    if not upgradeCost then
        upgradePetModifierEvent:FireClient(player, false, err or "Ошибка улучшения модификатора")
        return
    end

    upgradePetModifierEvent:FireClient(player, true, "Модификатор улучшен", upgradeCost)
end)

-- НОВЫЕ ОБРАБОТЧИКИ ДЛЯ НОВОГО ФУНКЦИОНАЛА
purchasePetEvent.OnServerEvent:Connect(function(player, petName)
    if not petSystem then
        purchasePetEvent:FireClient(player, false, "Система питомцев не инициализирована")
        return
    end

    -- Покупаем питомца через систему
    local instanceId, err = petSystem:PurchasePet(player, petName)
    
    if not instanceId then
        purchasePetEvent:FireClient(player, false, err or "Ошибка покупки питомца")
        return
    end

    purchasePetEvent:FireClient(player, true, "Питомец куплен", instanceId)
end)

sellPetEvent.OnServerEvent:Connect(function(player, instanceId)
    if not petSystem then
        sellPetEvent:FireClient(player, false, "Система питомцев не инициализирована")
        return
    end

    -- Продаем питомца через систему
    local sellPrice, err = petSystem:SellPet(player, instanceId)
    
    if not sellPrice then
        sellPetEvent:FireClient(player, false, err or "Ошибка продажи питомца")
        return
    end

    sellPetEvent:FireClient(player, true, "Питомец продан", sellPrice)
end)

purchaseEggEvent.OnServerEvent:Connect(function(player, eggName)
    if not petSystem then
        purchaseEggEvent:FireClient(player, false, "Система питомцев не инициализирована")
        return
    end

    -- Покупаем яйцо через систему
    local instanceId, err = petSystem:PurchaseEgg(player, eggName)
    
    if not instanceId then
        purchaseEggEvent:FireClient(player, false, err or "Ошибка покупки яйца")
        return
    end

    purchaseEggEvent:FireClient(player, true, "Яйцо куплено", instanceId)
end)

givePetEvent.OnServerEvent:Connect(function(player, petName)
    if not petSystem then
        givePetEvent:FireClient(player, false, "Система питомцев не инициализирована")
        return
    end

    -- Выдаем питомца через систему
    local instanceId, err = petSystem:GivePet(player, petName)
    
    if not instanceId then
        givePetEvent:FireClient(player, false, err or "Ошибка выдачи питомца")
        return
    end

    givePetEvent:FireClient(player, true, "Питомец выдан", instanceId)
end)

getPetSellPriceEvent.OnServerInvoke = function(player, instanceId)
    if not petSystem then
        return nil
    end

    -- Получаем цену продажи питомца через систему
    local sellInfo, err = petSystem:GetPetSellPrice(player, instanceId)
    
    if not sellInfo then
        return nil
    end

    return sellInfo
end

local function getLeveledValue(value, level)
    if type(value) == "table" then
        return value[level] or value[#value]
    end
    return value
end

getPetsDataEvent.OnServerInvoke = function(player)
    if not petSystem then
        return {inventory = {}, equipped = {}}
    end

    -- Получаем всех питомцев игрока через систему
    local ownedPets, ownedErr = petSystem:GetOwnedPets(player)
    local equippedPets, equippedErr = petSystem:GetEquippedPets(player)
    
    if ownedErr ~= "" then
        warn("Error getting owned pets: " .. ownedErr)
    end
    
    if equippedErr ~= "" then
        warn("Error getting equipped pets: " .. equippedErr)
    end

    -- Форматируем данные для клиента
    local petsData = {
        inventory = {},
        equipped = {}
    }

    -- Добавляем питомцев из инвентаря
    if ownedPets then
        for i = 1, #ownedPets do
            local petInfo = ownedPets[i]
            local petConfig = petSystem:GetPetConfig(petInfo.name)
            if petConfig then
                local enhancedPetData = {
                    id = petInfo.id,
                    name = petInfo.name,
                    level = petInfo.level,
                    modifierLevels = {},
                    obtainedTime = petInfo.obtainedTime,
                    obtainedMethod = petInfo.obtainedMethod,
                    isEquipped = petInfo.isEquipped,
                    hasGlobalLevel = petConfig.level ~= nil,
                    price = petConfig.price,
                    currency = petConfig.currency,
                    sellPercentage = petConfig.sellPercentage
                }
                
                -- Добавляем информацию о модификаторах
                if petConfig.modifiers then
                    for j = 1, #petConfig.modifiers do
                        local modifier = petConfig.modifiers[j]
                        local currentLevel = petInfo.modifierLevels and petInfo.modifierLevels[j] or modifier.initial or 1
                        enhancedPetData.modifierLevels[j] = {
                            level = currentLevel,
                            maxLevel = modifier.maxLevel or 1,
                            canUpgrade = modifier.upgradeCost ~= nil and currentLevel < (modifier.maxLevel or 1),
                            type = modifier.type,
                            value = getLeveledValue(modifier.value, currentLevel)
                        }
                    end
                end
                
                petsData.inventory[petInfo.id] = enhancedPetData
            end
        end
    end

    -- Добавляем информацию об экипированных питомцах
    if equippedPets then
        for i = 1, #equippedPets do
            local petInfo = equippedPets[i]
            table.insert(petsData.equipped, petInfo.id)
        end
    end

    return petsData
end

giveTestEggEvent.OnServerEvent:Connect(function(player, eggName)
    local playerData = DataManager.GetData(player)
    if not playerData then 
        giveTestEggEvent:FireClient(player, false, "Данные игрока не загружены")
        return 
    end
    
    if not playerData.Inventory then
        playerData.Inventory = {}
    end
    
    playerData.Inventory[eggName] = (playerData.Inventory[eggName] or 0) + 1
    DataManager.UpdateData(player, playerData)
    giveTestEggEvent:FireClient(player, true, "Яйцо добавлено в инвентарь")
end)


-------------------- Тесты -----------------------------------------------------
local tester = TestSystem.new()

-- Таблица для хранения исходного состояния экипированных питомцев по игрокам
local originalEquippedPets = {}
-- Таблица для хранения исходного состояния валюты игроков
local originalCurrency = {}

local function saveEquippedPets(player)
    if not petSystem then return {} end
    
    local equippedPets, _ = petSystem:GetEquippedPets(player)
    local equippedIds = {}
    
    if equippedPets then
        for i = 1, #equippedPets do
            local pet = equippedPets[i]
            table.insert(equippedIds, pet.id)
        end
    end
    
    originalEquippedPets[player] = equippedIds
    return equippedIds
end

local function restoreEquippedPets(player)
    if not petSystem then return end
    
    local equippedIds = originalEquippedPets[player]
    if not equippedIds then return end
    
    -- Сначала снимаем всех текущих питомцев
    petSystem:UnequipAllPets(player)
    
    -- Затем экипируем исходных питомцев
    for i = 1, #equippedIds do
        local petId = equippedIds[i]
        local success, err = petSystem:EquipPet(player, petId)
        if not success then
            warn("Не удалось восстановить питомца " .. petId .. " для игрока " .. player.Name .. ": " .. (err or "неизвестная ошибка"))
        end
    end
    
    -- Очищаем сохраненные данные
    originalEquippedPets[player] = nil
end

local function savePlayerCurrency(player)
    local playerData = DataManager.GetData(player)
    if not playerData then return {} end
    
    originalCurrency[player] = {
        Coins = playerData.Coins or 0,
        Gems = playerData.Gems or 0
    }
    
    return originalCurrency[player]
end

local function restorePlayerCurrency(player)
    local savedCurrency = originalCurrency[player]
    if not savedCurrency then return end
    
    DataManager.UpdateData(player, function(currentData)
        currentData.Coins = savedCurrency.Coins
        currentData.Gems = savedCurrency.Gems
        return currentData
    end)
    
    originalCurrency[player] = nil
end

local function setupTestCurrency(player)
    DataManager.UpdateData(player, function(currentData)
        currentData.Coins = 1000
        currentData.Gems = 500
        return currentData
    end)
end

local function runPetTests(player)
    -- Сохраняем исходное состояние экипированных питомцев и валюты
    local originalPets = saveEquippedPets(player)
    savePlayerCurrency(player)
    print("Сохранено " .. #originalPets .. " экипированных питомцев для игрока " .. player.Name)
    
    -- Устанавливаем тестовую валюту
    setupTestCurrency(player)
    
    tester:describe("Pet System Tests - " .. player.Name, function()
        
        it("Система питомцев инициализирована корректно", function()
            expect(petSystem).toBeNotNil()
            expect(initError).toEqual("")
        end)
        
        it("Получение конфигов всех питомцев", function()
            local bearConfig, bearError = petSystem:GetPetConfig("Bear")
            local bunnyConfig, bunnyError = petSystem:GetPetConfig("Bunny")
            local foxConfig, foxError = petSystem:GetPetConfig("Fox")
            
            expect(bearConfig).toBeNotNil()
            expect(bearError).toEqual("")
            expect(bearConfig.modelPath).toEqual("ServerStorage/Pets/Bear")
            expect(bearConfig.walks).toEqual(true)
            expect(bearConfig.price).toEqual(200)
            expect(bearConfig.currency).toEqual("Coins")
            expect(bearConfig.sellPercentage).toEqual(0.5)
            expect(bearConfig.level).toBeNotNil()
            expect(bearConfig.level.initial).toEqual(1)
            expect(bearConfig.level.max).toEqual(4)
            expect(bearConfig.level.upgradeCost[1]).toEqual(60)
            expect(bearConfig.modifiers).toBeNotNil()
            expect(#bearConfig.modifiers).toEqual(2)
            expect(bearConfig.modifiers[1].type).toEqual("JumpHeight")
            expect(bearConfig.modifiers[1].operation).toEqual("Add")
            expect(bearConfig.modifiers[1].value[1]).toEqual(15)
            expect(#bearConfig.level.upgradeCost).toEqual(3)

            expect(bunnyConfig).toBeNotNil()
            expect(bunnyError).toEqual("")
            expect(bunnyConfig.price).toEqual(150)
            expect(bunnyConfig.currency).toEqual("Coins")
            expect(bunnyConfig.sellPercentage).toEqual(0.6)
            expect(bunnyConfig.level).toBeNil()
            expect(bunnyConfig.modifiers).toBeNotNil()
            expect(#bunnyConfig.modifiers).toEqual(2)
            expect(bunnyConfig.modifiers[1].initial).toEqual(1)
            expect(bunnyConfig.modifiers[1].maxLevel).toEqual(3)
            expect(bunnyConfig.modifiers[1].upgradeCost[1]).toEqual(100)

            expect(foxConfig).toBeNotNil()
            expect(foxError).toEqual("")
            expect(foxConfig.price).toEqual(300)
            expect(foxConfig.currency).toEqual("Gems")
            expect(foxConfig.sellPercentage).toEqual(0.4)
        end)
        
        it("Выбор питомца из BasicEgg", function()
            local PetNames = {"Bear", "Bunny", "Fox"}    
            local petData, PetError = petSystem:ChoosePetFromEgg("BasicEgg")
            local isValidPetName = false

            expect(petData).toBeNotNil()
            expect(PetError).toEqual("")
            expect(petData.level).toEqual(1)
            expect(PetNames[1] == petData.name or
                   PetNames[2] == petData.name or 
                   PetNames[3] == petData.name ).toBeTrue()

        end)
        
        it("Добавление питомца в инвентарь", function()
            local testPet = {
                name = "Bear",
                level = 1,
                modifierLevels = {}
            }
            
            local instanceId, addError = petSystem:AddPetToInventory(player, testPet)
            
            expect(instanceId).toBeNotNil()
            expect(addError).toEqual("")
            
            -- Проверяем, что питомец добавлен в инвентарь
            local ownedPets, ownedError = petSystem:GetOwnedPets(player)
            expect(ownedPets).toBeNotNil()
            expect(ownedError).toEqual("")
            
            local found = false
            for i = 1, #ownedPets do
                local pet = ownedPets[i]
                if pet.id == instanceId then
                    found = true
                    expect(pet.name).toEqual("Bear")
                    expect(pet.level).toEqual(1)
                    expect(pet.isEquipped).toEqual(false)
                    expect(pet.obtainedMethod).toEqual("given")
                    break
                end
            end
            expect(found).toBeTrue()
        end)
        
        it("Покупка питомца за валюту", function()
            local playerDataBefore = DataManager.GetData(player)
            local initialCoins = playerDataBefore.Coins or 0
            
            -- Покупаем питомца
            local instanceId, purchaseError = petSystem:PurchasePet(player, "Bear")
            
            expect(instanceId).toBeNotNil()
            expect(purchaseError).toEqual("")
            
            -- Проверяем списание валюты
            local playerDataAfter = DataManager.GetData(player)
            expect(playerDataAfter.Coins).toEqual(initialCoins - 200) -- Bear стоит 200 монет
            
            -- Проверяем, что питомец добавлен в инвентарь с правильным методом получения
            local ownedPets, _ = petSystem:GetOwnedPets(player)
            local found = false
            for i = 1, #ownedPets do
                local pet = ownedPets[i]
                if pet.id == instanceId then
                    found = true
                    expect(pet.obtainedMethod).toEqual("purchased")
                    break
                end
            end
            expect(found).toBeTrue()
        end)
        
        it("Покупка питомца без достаточной валюты", function()
            -- Устанавливаем недостаточно валюты
            DataManager.UpdateData(player, function(currentData)
                currentData.Coins = 10  -- Bear стоит 200 монет
                return currentData
            end)
            
            local instanceId, purchaseError = petSystem:PurchasePet(player, "Bear")
            
            expect(instanceId).toBeNil()
            expect(purchaseError).toContain("Not enough")
            
            -- Восстанавливаем тестовую валюту
            setupTestCurrency(player)
        end)
        
        it("Продажа питомца с возвратом валюты", function()
            -- Сначала добавляем питомца через выдачу
            local instanceId, giveError = petSystem:GivePet(player, "Bear")
            expect(instanceId).toBeNotNil()
            expect(giveError).toEqual("")
            
            local playerDataBefore = DataManager.GetData(player)
            local initialCoins = playerDataBefore.Coins or 0
            
            -- Продаем питомца
            local sellPrice, sellError = petSystem:SellPet(player, instanceId)
            
            expect(sellPrice).toBeNotNil()
            expect(sellError).toEqual("")
            expect(sellPrice).toEqual(100) -- 200 * 0.5 = 100
            
            -- Проверяем начисление валюты
            local playerDataAfter = DataManager.GetData(player)
            expect(playerDataAfter.Coins).toEqual(initialCoins + sellPrice)
            
            -- Проверяем, что питомец удален из инвентаря
            local ownedPets, _ = petSystem:GetOwnedPets(player)
            local found = false
            for i = 1, #ownedPets do
                if ownedPets[i].id == instanceId then
                    found = true
                    break
                end
            end
            expect(found).toBeFalse()
        end)
        
        it("Получение цены продажи питомца", function()
            -- Добавляем питомца
            local instanceId, _ = petSystem:GivePet(player, "Bear")
            expect(instanceId).toBeNotNil()
            
            -- Получаем информацию о цене продажи
            local sellInfo, sellInfoError = petSystem:GetPetSellPrice(player, instanceId)
            
            expect(sellInfo).toBeNotNil()
            expect(sellInfoError).toEqual("")
            expect(sellInfo.currency).toEqual("Coins")
            expect(sellInfo.amount).toEqual(100) -- 200 * 0.5
            expect(sellInfo.basePrice).toEqual(200)
            expect(sellInfo.upgradeCost).toEqual(0)
            expect(sellInfo.sellPercentage).toEqual(0.5)
        end)
        
        it("Покупка яйца за валюту", function()
            local playerDataBefore = DataManager.GetData(player)
            local initialCoins = playerDataBefore.Coins or 0
            
            -- Покупаем яйцо
            local instanceId, purchaseError = petSystem:PurchaseEgg(player, "BasicEgg")
            
            expect(instanceId).toBeNotNil()
            expect(purchaseError).toEqual("")
            
            -- Проверяем списание валюты
            local playerDataAfter = DataManager.GetData(player)
            expect(playerDataAfter.Coins).toEqual(initialCoins - 100) -- BasicEgg стоит 100 монет
            
            -- Проверяем, что питомец добавлен в инвентарь
            local ownedPets, _ = petSystem:GetOwnedPets(player)
            local found = false
            for i = 1, #ownedPets do
                local pet = ownedPets[i]
                if pet.id == instanceId then
                    found = true
                    expect(pet.obtainedMethod).toEqual("egg")
                    break
                end
            end
            expect(found).toBeTrue()
        end)
        
        it("Выдача питомца администратором", function()
            local instanceId, giveError = petSystem:GivePet(player, "Fox")
            
            expect(instanceId).toBeNotNil()
            expect(giveError).toEqual("")
            
            -- Проверяем, что питомец добавлен в инвентарь
            local ownedPets, _ = petSystem:GetOwnedPets(player)
            local found = false
            for i = 1, #ownedPets do
                local pet = ownedPets[i]
                if pet.id == instanceId then
                    found = true
                    expect(pet.obtainedMethod).toEqual("given")
                    expect(pet.name).toEqual("Fox")
                    break
                end
            end
            expect(found).toBeTrue()
        end)
        
        it("Продажа улучшенного питомца с учетом стоимости улучшений", function()
            -- Добавляем и улучшаем питомца
            local instanceId, _ = petSystem:GivePet(player, "Bear")
            expect(instanceId).toBeNotNil()
            
            -- Улучшаем уровень питомца
            local upgradeCost1, _ = petSystem:UpgradePetLevel(player, instanceId)
            expect(upgradeCost1).toEqual(60)
            
            -- Получаем информацию о цене продажи после улучшения
            local sellInfo, _ = petSystem:GetPetSellPrice(player, instanceId)
            
            expect(sellInfo).toBeNotNil()
            expect(sellInfo.basePrice).toEqual(200)
            expect(sellInfo.upgradeCost).toEqual(60) -- стоимость первого улучшения
            expect(sellInfo.amount).toEqual(130) -- (200 + 60) * 0.5 = 130
        end)
        
        it("Экипировка питомца из инвентаря", function()
            -- Сначала получаем питомцев из инвентаря
            local ownedPets, _ = petSystem:GetOwnedPets(player)
            expect(ownedPets).toBeNotNil()
            
            if #ownedPets > 0 then
                local petToEquip = ownedPets[1]
                
                -- Экипируем питомца
                local success, equipError = petSystem:EquipPet(player, petToEquip.id)
                expect(success).toBeNotNil()
                expect(equipError).toEqual("")
                
                -- Проверяем, что питомец экипирован
                local equippedPets, _ = petSystem:GetEquippedPets(player)
                expect(equippedPets).toBeNotNil()
                
                local found = false
                for i = 1, #equippedPets do
                    local pet = equippedPets[i]
                    if pet.id == petToEquip.id then
                        found = true
                        break
                    end
                end
                expect(found).toBeTrue()
                
                -- Проверяем, что в инвентаре отмечено как экипированный
                local updatedOwnedPets, _ = petSystem:GetOwnedPets(player)
                for j = 1, #updatedOwnedPets do
                    local pet = updatedOwnedPets[j]
                    if pet.id == petToEquip.id then
                        expect(pet.isEquipped).toBeTrue()
                        break
                    end
                end
            end
        end)
        
        it("Применение модификаторов при экипировке", function()
            local playerDataBefore = DataManager.GetComputedData(player)
            expect(playerDataBefore).toBeNotNil()
            
            -- Добавляем и экипируем нового питомца
            local testPet = {
                name = "Bear",
                level = 1,
                modifierLevels = {}
            }
            
            local instanceId, _ = petSystem:AddPetToInventory(player, testPet)
            local success, _ = petSystem:EquipPet(player, instanceId)
            expect(success).toBeNotNil()
            
            -- Проверяем изменения в вычисляемых данных
            wait(1) -- Даем время на применение модификаторов
            local playerDataAfter = DataManager.GetComputedData(player)
            expect(playerDataAfter).toBeNotNil()
        end)
        
        it("Улучшение уровня питомца с общей системой уровней", function()
            -- Добавляем Bear в инвентарь
            local testPet = {
                name = "Bear",
                level = 1,
                modifierLevels = {}
            }
            
            local instanceId, _ = petSystem:AddPetToInventory(player, testPet)
            
            -- Улучшаем уровень
            local upgradeCost, upgradeError = petSystem:UpgradePetLevel(player, instanceId)
            
            expect(upgradeCost).toBeNotNil()
            expect(upgradeError).toEqual("")
            expect(upgradeCost).toEqual(60) -- Стоимость улучшения с 1 до 2 уровня
            
            -- Проверяем, что уровень увеличился
            local ownedPets, _ = petSystem:GetOwnedPets(player)
            for i = 1, #ownedPets do
                local pet = ownedPets[i]
                if pet.id == instanceId then
                    expect(pet.level).toEqual(2)
                    break
                end
            end
        end)
        
        it("Улучшение модификатора питомца с индивидуальными уровнями", function()
            -- Добавляем Bunny в инвентарь
            local testPet = {
                name = "Bunny",
                level = nil,
                modifierLevels = {1, 1}
            }
            
            local instanceId, _ = petSystem:AddPetToInventory(player, testPet)
            
            -- Улучшаем первый модификатор
            local upgradeCost, upgradeError = petSystem:UpgradePetModifier(player, instanceId, 1)
            
            expect(upgradeCost).toBeNotNil()
            expect(upgradeError).toEqual("")
            expect(upgradeCost).toEqual(100) -- Стоимость улучшения первого модификатора
            
            -- Проверяем, что уровень модификатора увеличился
            local ownedPets, _ = petSystem:GetOwnedPets(player)
            for i = 1, #ownedPets do
                local pet = ownedPets[i]
                if pet.id == instanceId then
                    expect(pet.modifierLevels[1]).toEqual(2)
                    break
                end
            end
        end)
        
        it("Снятие питомца", function()
            local ownedPets, _ = petSystem:GetOwnedPets(player)
            expect(ownedPets).toBeNotNil()
            
            -- Ищем экипированного питомца
            local equippedPet = nil
            for i = 1, #ownedPets do
                local pet = ownedPets[i]
                if pet.isEquipped then
                    equippedPet = pet
                    break
                end
            end
            
            if equippedPet then
                -- Снимаем питомца
                local success, unequipError = petSystem:UnequipPet(player, equippedPet.id)
                expect(success).toBeTrue()
                expect(unequipError).toEqual("")
                
                -- Проверяем, что питомец снят
                local equippedPets, _ = petSystem:GetEquippedPets(player)
                local found = false
                for i = 1, #equippedPets do
                    local pet = equippedPets[i]
                    if pet.id == equippedPet.id then
                        found = true
                        break
                    end
                end
                expect(found).toBeFalse()
                
                -- Проверяем, что в инвентаре отмечено как неэкипированный
                local updatedOwnedPets, _ = petSystem:GetOwnedPets(player)
                for j = 1, #updatedOwnedPets do
                    local pet = updatedOwnedPets[j]
                    if pet.id == equippedPet.id then
                        expect(pet.isEquipped).toBeFalse()
                        break
                    end
                end
            end
        end)
        
        it("Проверка лимита питомцев", function()
            local hasReachedLimit, error = petSystem:HasReachedPetLimit(player)
            expect(hasReachedLimit).toBeType("boolean")
            expect(error).toEqual("")
        end)
        
        it("Получение количества питомцев", function()
            local ownedCount, ownedError = petSystem:GetOwnedPetsCount(player)
            local equippedCount, equippedError = petSystem:GetEquippedPetsCount(player)
            
            expect(ownedCount).toBeType("number")
            expect(ownedError).toEqual("")
            expect(equippedCount).toBeType("number")
            expect(equippedError).toEqual("")
            
            expect(equippedCount).toBeLessThan(ownedCount)
        end)
        
        it("Удаление питомца из инвентаря", function()
            local ownedPets, _ = petSystem:GetOwnedPets(player)
            expect(ownedPets).toBeNotNil()
            
            if #ownedPets > 0 then
                local petToRemove = ownedPets[1]
                
                -- Удаляем питомца
                local success, removeError = petSystem:RemovePetFromInventory(player, petToRemove.id)
                expect(success).toBeTrue()
                expect(removeError).toEqual("")
                
                -- Проверяем, что питомец удален
                local updatedOwnedPets, _ = petSystem:GetOwnedPets(player)
                local found = false
                for i = 1, #updatedOwnedPets do
                    local pet = updatedOwnedPets[i]
                    if pet.id == petToRemove.id then
                        found = true
                        break
                    end
                end
                expect(found).toBeFalse()
            end
        end)
        
        it("Обработка ошибок при экипировке несуществующего питомца", function()
            local success, error = petSystem:EquipPet(player, "non_existent_id")
            expect(success).toBeNil()
            expect(error).toContain("not found")
        end)
        
        it("Обработка ошибок при снятии неэкипированного питомца", function()
            local success, error = petSystem:UnequipPet(player, "non_existent_id")
            expect(success).toBeNil()
            expect(error).toContain("not equipped")
        end)
    end)
    
    -- Запускаем все тесты
    tester:runAll()
    
    -- Снимаем всех питомцев после тестов
    petSystem:UnequipAllPets(player)
    
    -- Восстанавливаем исходное состояние экипированных питомцев и валюты
    restoreEquippedPets(player)
    restorePlayerCurrency(player)
    print("Восстановлено экипированных питомцев и валюты для игрока " .. player.Name)
end

-- Функция для запуска тестов при подключении игрока
local function setupPlayerTests(player)
    if not player then return end

    if player:GetAttribute("DataLoaded") then
        runPetTests(player)
    else
        player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
            if player:GetAttribute("DataLoaded") then
                runPetTests(player)
            end
        end)
    end
end

-- Обработка подключения игроков
game.Players.PlayerAdded:Connect(setupPlayerTests)

-- Обработка уже подключенных игроков
for _, player in ipairs(game.Players:GetPlayers()) do
    setupPlayerTests(player)
end