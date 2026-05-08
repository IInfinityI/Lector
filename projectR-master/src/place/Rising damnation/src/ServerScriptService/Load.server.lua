local AssetsFolder = game.ServerScriptService:WaitForChild("Assets")
local AssetsReplicatedFolder = game.ReplicatedStorage:WaitForChild("Assets")
local LocalAssetsFolder = game.ServerScriptService:WaitForChild("LocalAssets")
local ConfigsFolder = game.ServerScriptService:WaitForChild("Configs")

local DataManager = require(AssetsFolder:WaitForChild("DataManager"))
local TagBehaviorSystem = require(AssetsFolder:WaitForChild("TagBehaviorSystem"))
local EventSystem = require(AssetsReplicatedFolder:WaitForChild("EventSystem"))
local ToolsSystem = require(AssetsFolder:WaitForChild("ToolsSystem"))
local accessorySystem = require(AssetsFolder:WaitForChild("AccessorySystem"))

-- Local system
local EssenceSpawnSystem = require(LocalAssetsFolder:WaitForChild("EssenceSpawnSystem"))

-- Initialize systems
DataManager.Init(ConfigsFolder.DataConfig)
EventSystem.Init(ConfigsFolder.EventConfig)
ToolsSystem.Init(ConfigsFolder.ToolConfig)
local AccessorySystem = accessorySystem.Init(ConfigsFolder.AccessoryConfig)
TagBehaviorSystem.Init(ConfigsFolder.TagConfig)

local function equipPlayerItemsOnJoin(player)
    wait(3) -- переделать под ожидание параметра указывающий на готовность системы
    local playerData = DataManager.GetData(player)
    if not playerData then return end
    
    local equippedItems = playerData.EquippedItem or {}
    local inventory = playerData.Inventory or {}
    if #equippedItems == 0 then return end
    
    for _, equippedItem in ipairs(equippedItems) do
        -- Находим соответствующий предмет в инвентаре
        local inventoryItem
        for _, item in ipairs(inventory) do
            if item.name == equippedItem.name then
                inventoryItem = item
                break
            end
        end
        
        if inventoryItem then
            -- Получаем уровни из инвентаря
            local globalLevel = inventoryItem.level
            local modifierLevels = inventoryItem.modifierLevels
            
            -- Экипируем с правильными уровнями
            local success = AccessorySystem:equipAccessory(player, equippedItem.name, globalLevel, modifierLevels)
            if not success then
                warn("Failed to equip accessory " .. equippedItem.name .. " for player " .. player.Name)
            end
        else
            warn("Equipped item " .. equippedItem.name .. " not found in inventory for player " .. player.Name)
        end
    end
end

game.Players.PlayerAdded:Connect(function(player)
    equipPlayerItemsOnJoin(player)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
    equipPlayerItemsOnJoin(player)
end

------------ Event ----------------

EventSystem.RegisterServerOnlyRPC("EssenceTouched", function(player, object)
    if not object or not object.Parent then return end
    
    local originalParent = object.Parent
    local rarityName = object:GetAttribute("Rarity")
    local weight = EssenceSpawnSystem.GetEssenceWeight(rarityName)
    local playerComputedData = DataManager.GetComputedData(player)

    -- Предварительная проверка веса
    local currentWeight = 0
    local playerData = DataManager.GetData(player)
    
    -- Вычисляем текущий вес
    currentWeight = currentWeight + (playerData.CommonEssence or 0) * EssenceSpawnSystem.GetEssenceWeight("Common")
    currentWeight = currentWeight + (playerData.IncommonEssence or 0) * EssenceSpawnSystem.GetEssenceWeight("Incommon")
    currentWeight = currentWeight + (playerData.RareEssence or 0) * EssenceSpawnSystem.GetEssenceWeight("Rare")
    currentWeight = currentWeight + (playerData.EpicEssence or 0) * EssenceSpawnSystem.GetEssenceWeight("Epic")
    currentWeight = currentWeight + (playerData.LegendaryEssence or 0) * EssenceSpawnSystem.GetEssenceWeight("Legendary")
    currentWeight = currentWeight + (playerData.MythicalEssence or 0) * EssenceSpawnSystem.GetEssenceWeight("Mythical")
    
    -- Добавляем вес новой эссенции
    local newWeight = currentWeight + weight
    
    -- Если превышает лимит - не собираем
    if newWeight >= (playerComputedData.MaxWeight or 20) then
        -- Применяем модификаторы перегруза
        DataManager.AddModifier(player, "JumpHeight", "Overloading", 0.3, "MultiplyTotal", "")
        DataManager.AddModifier(player, "MovementSpeed", "Overloading", 0.3, "MultiplyTotal", "")
        EventSystem.FireClient(player, "ShowOverloadNotification", true)
        return  -- Прекращаем выполнение, объект не удаляется
    end
    
    -- Если вес в пределах нормы - собираем
    DataManager.UpdateData(player, function(playerData)
        local data = table.clone(playerData)

        -- Добавляем эссенцию
        if rarityName == "Common" then
            data.CommonEssence = (data.CommonEssence or 0) + 1
        elseif rarityName == "Incommon" then
            data.IncommonEssence = (data.IncommonEssence or 0) + 1
        elseif rarityName == "Rare" then
            data.RareEssence = (data.RareEssence or 0) + 1
        elseif rarityName == "Epic" then
            data.EpicEssence = (data.EpicEssence or 0) + 1
        elseif rarityName == "Legendary" then
            data.LegendaryEssence = (data.LegendaryEssence or 0) + 1
        elseif rarityName == "Mythical" then
            data.MythicalEssence = (data.MythicalEssence or 0) + 1
        end
        
        return data
    end)

    EventSystem.FireClient(player, "ShowEssenceCollection", rarityName, 1)
    EssenceSpawnSystem.RespawnEssence(object, originalParent)
end)

-- Функция для продажи всех эссенций
EventSystem.RegisterServerOnlyRPC("SellAllEssences", function(player)
    DataManager.UpdateData(player, function(playerData)
        local data = table.clone(playerData)
        local totalCoins = 0
        
        if data.CommonEssence and data.CommonEssence > 0 then
            local value = EssenceSpawnSystem.GetEssenceValue("Common")
            totalCoins = totalCoins + (value * data.CommonEssence)
            data.CommonEssence = 0
        end
        
        if data.IncommonEssence and data.IncommonEssence > 0 then
            local value = EssenceSpawnSystem.GetEssenceValue("Incommon")
            totalCoins = totalCoins + (value * data.IncommonEssence)
            data.IncommonEssence = 0
        end
        
        if data.RareEssence and data.RareEssence > 0 then
            local value = EssenceSpawnSystem.GetEssenceValue("Rare")
            totalCoins = totalCoins + (value * data.RareEssence)
            data.RareEssence = 0
        end
        
        if data.EpicEssence and data.EpicEssence > 0 then
            local value = EssenceSpawnSystem.GetEssenceValue("Epic")
            totalCoins = totalCoins + (value * data.EpicEssence)
            data.EpicEssence = 0
        end
        
        if data.LegendaryEssence and data.LegendaryEssence > 0 then
            local value = EssenceSpawnSystem.GetEssenceValue("Legendary")
            totalCoins = totalCoins + (value * data.LegendaryEssence)
            data.LegendaryEssence = 0
        end
        
        if data.MythicalEssence and data.MythicalEssence > 0 then
            local value = EssenceSpawnSystem.GetEssenceValue("Mythical")
            totalCoins = totalCoins + (value * data.MythicalEssence)
            data.MythicalEssence = 0
        end
        
        if totalCoins > 0 then
            data.Coins = (data.Coins or 0) + totalCoins
        end
        
        DataManager.RemoveModifier(player, "JumpHeight", "Overloading")
        DataManager.RemoveModifier(player, "MovementSpeed", "Overloading")
        EventSystem.FireClient(player, "ShowOverloadNotification", false)

        return data
    end)
end)

EventSystem.RegisterRPC("GetShopData", function(player)
    local categories = {"Boots", "Backpack", "Amulet" }
    local shopData = {}
    for _, category in ipairs(categories) do
        shopData[category] = AccessorySystem:GetAccessoriesByCategory(category)
    end
    return shopData
end)

-- Обработчик запроса информации об экипированных улучшениях предметов
EventSystem.RegisterRPC("GetEquippedUpgradesInfo", function(player)
    local playerData = DataManager.GetData(player)
    if not playerData or not playerData.EquippedItem then
        return {}
    end
    
    local allAccessories = AccessorySystem:GetAllAccessoriesInfo()
    local equippedUpgrades = {}
    
    local equippedMap = {}
    for _, equippedItem in ipairs(playerData.EquippedItem) do
        equippedMap[equippedItem.name] = true
    end
    
    for _, accessory in ipairs(allAccessories) do
        if equippedMap[accessory.name] then
            local upgradeData = {
                name = accessory.name,
                category = accessory.category,
                accessoryType = accessory.accessoryType,
                description = accessory.description,
                imageId = accessory.imageId,
                maxLevel = accessory.maxLevel or 1,
                baseCost = accessory.cost or 0,
                modifiers = {}
            }
            
            if accessory.modifiers then
                for _, modifier in ipairs(accessory.modifiers) do
                    local modifierData = {
                        type = modifier.type,
                        operation = modifier.operation,
                        initial = modifier.initial or 1,
                        maxLevel = modifier.maxLevel or 1,
                        upgradeCost = modifier.upgradeCost or {},
                        values = modifier.value or {}
                    }
                    
                    table.insert(upgradeData.modifiers, modifierData)
                end
            end
            
            table.insert(equippedUpgrades, upgradeData)
        end
    end
    
    return equippedUpgrades
end)

EventSystem.OnServer("BuyAccessory", function(player, name)
    local itemData = AccessorySystem:GetAccessoryInfo(name)
    
    if not itemData then return end

    local success, err = DataManager.UpdateData(player, function(playerData)
        local newData = table.clone(playerData)
        
        if (newData.Coins or 0) < itemData.cost then
            return nil, "Not enough Coins"
        end

        if itemData.purchaseLimit then
            local alreadyPurchased = 0
            for _, item in ipairs(newData.Inventory or {}) do
                if item.name == name then
                    alreadyPurchased = alreadyPurchased + (item.count or 1)
                end
            end
            
            if alreadyPurchased >= itemData.purchaseLimit then
                return nil, "You have already purchased the maximum amount of this item"
            end
        end

        newData.Coins = newData.Coins - itemData.cost

        local foundItem
        for _, item in ipairs(newData.Inventory or {}) do
            if item.name == name then
                foundItem = item
                break
            end
        end

        if foundItem then
            foundItem.count = (foundItem.count or 1) + 1
        else
            local newItem = {
                name = name,
                count = 1
            }
            
            -- Добавляем уровень аксессуара если есть глобальная прокачка
            if itemData.level then
                newItem.level = itemData.level.initial or 1
            end
            
            -- Добавляем уровни модификаторов если есть индивидуальная прокачка
            if itemData.modifiers then
                newItem.modifierLevels = {}
                for i, modifier in ipairs(itemData.modifiers) do
                    if modifier.individualUpgrade then
                        newItem.modifierLevels[i] = modifier.initial or 1
                    end
                end
            end
            
            table.insert(newData.Inventory, newItem)
        end

        return newData
    end)
    if not success then
        warn("Failed to buy accessory: " .. tostring(err))
    end
end)

EventSystem.OnServer("UpgradeAccessory", function(player, name, modifierType)
    local itemData = AccessorySystem:GetAccessoryInfo(name)
    if not itemData then return end

    local success, err = DataManager.UpdateData(player, function(playerData)
        local newData = table.clone(playerData)
        
        -- Находим предмет в инвентаре
        local foundItem
        for _, item in ipairs(newData.Inventory or {}) do
            if item.name == name then
                foundItem = item
                break
            end
        end

        if not foundItem then
            return nil, "Item not found in inventory"
        end

        local upgradeCost
        local currentLevel
        
        -- Определяем стоимость улучшения и текущий уровень
        if modifierType then
            -- Улучшение конкретного модификатора
            if not itemData.modifiers or not foundItem.modifierLevels then
                return nil, "This item doesn't support modifier upgrades"
            end
            
            local modifierIndex
            for i, modifier in ipairs(itemData.modifiers) do
                if modifier.type == modifierType then
                    modifierIndex = i
                    break
                end
            end
            
            if not modifierIndex then
                return nil, "Modifier type not found"
            end
            
            currentLevel = foundItem.modifierLevels[modifierIndex] or 1
            local modifierData = itemData.modifiers[modifierIndex]
            
            if currentLevel >= (modifierData.maxLevel or 1) then
                return nil, "Modifier already at maximum level"
            end
            
            upgradeCost = modifierData.upgradeCost[currentLevel] or modifierData.upgradeCost[#modifierData.upgradeCost]
        else
            -- Глобальное улучшение аксессуара
            if not itemData.level then
                return nil, "This item doesn't support global upgrades"
            end
            
            currentLevel = foundItem.level or 1
            
            if currentLevel >= (itemData.level.max or 1) then
                return nil, "Item already at maximum level"
            end
            
            upgradeCost = itemData.level.upgradeCost[currentLevel] or itemData.level.upgradeCost[#itemData.level.upgradeCost]
        end

        -- Проверяем достаточно ли денег
        if (newData.Coins or 0) < upgradeCost then
            return nil, "Not enough coins for upgrade"
        end

        -- Вычитаем стоимость улучшения
        newData.Coins = newData.Coins - upgradeCost

        -- Применяем улучшение
        if modifierType then
            local modifierIndex
            for i, modifier in ipairs(itemData.modifiers) do
                if modifier.type == modifierType then
                    modifierIndex = i
                    break
                end
            end
            
            foundItem.modifierLevels[modifierIndex] = currentLevel + 1
        else
            foundItem.level = currentLevel + 1
        end

        -- Обновляем экипированный аксессуар если он надет
        local isEquipped = false
        for _, equippedItem in ipairs(newData.EquippedItem or {}) do
            if equippedItem.name == name then
                isEquipped = true
                break
            end
        end

        if isEquipped then
            -- Снимаем и заново экипируем для применения улучшений
            AccessorySystem:unequipAccessory(player, name)
            
            local globalLevel = foundItem.level
            local modifierLevels = foundItem.modifierLevels
            
            local equipSuccess = AccessorySystem:equipAccessory(player, name, globalLevel, modifierLevels)
            if not equipSuccess then
                warn("Failed to re-equip upgraded accessory: " .. name)
            end
        end

        return newData
    end)

    if not success then
        warn("Failed to upgrade accessory: " .. tostring(err))
    end
end)

EventSystem.RegisterRPC("GetAccessoryState", function(player, name)
    local playerData = DataManager.GetData(player)
    if not playerData then return "not_owned" end
    
    -- Ищем аксессуар в инвентаре
    local inventoryItem
    for _, item in ipairs(playerData.Inventory or {}) do
        if item.name == name then
            inventoryItem = item
            break
        end
    end
    
    if not inventoryItem then return "not_owned" end
    
    -- Проверяем экипирован ли предмет
    for _, item in ipairs(playerData.EquippedItem or {}) do
        if item.name == name then
            return "equipped"
        end
    end
    
    return "can_equip"
end)

EventSystem.OnServer("EquipAccessory", function(player, name)
    local itemData = AccessorySystem:GetAccessoryInfo(name)
    if not itemData then return end

    local success, err = DataManager.UpdateData(player, function(playerData)
        local newData = table.clone(playerData)
        
        local itemInInventory
        for _, item in ipairs(newData.Inventory or {}) do
            if item.name == name then
                itemInInventory = item
                break
            end
        end

        if not itemInInventory then
            return nil, "You don't have this accessory in your inventory"
        end

        for _, equippedItem in ipairs(newData.EquippedItem or {}) do
            if equippedItem.name == name then
                return nil, "This accessory is already equipped"
            end
        end

        -- Получаем уровни из инвентаря
        local globalLevel = itemInInventory.level
        local modifierLevels = itemInInventory.modifierLevels
        
        local equipSuccess = AccessorySystem:equipAccessory(player, name, globalLevel, modifierLevels)
        if not equipSuccess then
            return nil, "error"
        end

        local equippedItem = {
            name = name
        }
        table.insert(newData.EquippedItem or {}, equippedItem)

        return newData
    end)

    if not success then
        warn("Failed to equip accessory (data error): " .. tostring(err))
    end
end)

EventSystem.OnServer("UnequipAccessory", function(player, name)
    local itemData = AccessorySystem:GetAccessoryInfo(name)
    if not itemData then return end

    local success, err = DataManager.UpdateData(player, function(playerData)
        local newData = table.clone(playerData)
        
        local equippedIndex
        for i, item in ipairs(newData.EquippedItem or {}) do
            if item.name == name then
                equippedIndex = i
                break
            end
        end
        
        if not equippedIndex then
            return nil, "This accessory is not equipped"
        end

        local unequipSuccess = AccessorySystem:unequipAccessory(player, name)
        if not unequipSuccess then
            return nil, "error"
        end

        table.remove(newData.EquippedItem, equippedIndex)
        return newData
    end)

    if not success then
        warn("Failed to unequip accessory (data error): " .. tostring(err))
    end
end)