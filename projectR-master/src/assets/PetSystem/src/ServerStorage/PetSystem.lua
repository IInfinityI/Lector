local PetSystem = {}

-- Сервисы
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Глобальная переменная для экземпляра системы
local systemInstance = nil

-- Локальные функции
local function getLeveledValue(value, level)
    if type(value) == "table" then
        return value[level] or value[#value]
    end
    return value
end

local function validatePetConfig(petName, petConfig)
    if not petName then
        return false, "Pet name is missing"
    end
    
    if not petConfig then
        return false, "Pet config is missing for pet: " .. petName
    end
    
    if not petConfig.modelPath then
        return false, "Model path is missing for pet: " .. petName
    end
    
    return true
end

local function applyModifiers(player, petName, instanceId, petConfig, petLevel, modifierLevels, isEquip)
    if not petConfig or not petConfig.modifiers then return end
    
    local dataManager = _G.AssetService:GetModule("DataManager")
    if not dataManager then
        warn("DataManager not available for applying modifiers")
        return
    end
    
    if isEquip then
        for i, modifier in ipairs(petConfig.modifiers) do
            local levelToUse = 1
            
            if petConfig.level then
                levelToUse = petLevel
            elseif modifier.initial then
                levelToUse = modifierLevels and modifierLevels[i] or modifier.initial
            end
            
            local value = getLeveledValue(modifier.value, levelToUse)
            local paramName = modifier.type
            local modifierId = "Pet_"..petName.."_"..i.."_"..instanceId
            
            dataManager.AddModifier(player, paramName, modifierId, value, modifier.operation or "add", "PetSystem")
        end
    else
        for i in ipairs(petConfig.modifiers) do
            local modifierId = "Pet_"..petName.."_"..i.."_"..instanceId
            local paramName = petConfig.modifiers[i].type
            
            dataManager.RemoveModifier(player, paramName, modifierId)
        end
    end
end

local function getPlayerPetData(player)
    local dataManager = _G.AssetService:GetModule("DataManager")
    if not dataManager then return nil end
    
    local playerData = dataManager.GetData(player)
    if not playerData then return nil end
    
    -- Инициализируем структуру данных для питомцев, если её нет
    if not playerData.PetSystem then
        playerData.PetSystem = {
            ownedPets = {},    -- Все питомцы игрока
            equippedPets = {}  -- Экипированные питомцы (только instanceId)
        }
    end
    
    return playerData.PetSystem
end

local function savePlayerPetData(player, petData)
    local dataManager = _G.AssetService:GetModule("DataManager")
    if not dataManager then return false end
    
    return dataManager.UpdateData(player, function(currentData)
        currentData.PetSystem = petData
        return currentData
    end)
end

local function getOwnedPetByInstanceId(player, instanceId)
    local petData = getPlayerPetData(player)
    if not petData then return nil end
    
    return petData.ownedPets[instanceId]
end

local function saveOwnedPet(player, instanceId, petInfo)
    local petData = getPlayerPetData(player)
    if not petData then return false end
    
    petData.ownedPets[instanceId] = petInfo
    return savePlayerPetData(player, petData)
end

local function removeOwnedPet(player, instanceId)
    local petData = getPlayerPetData(player)
    if not petData then return false end
    
    petData.ownedPets[instanceId] = nil
    return savePlayerPetData(player, petData)
end

local function addToEquippedPets(player, instanceId)
    local petData = getPlayerPetData(player)
    if not petData then return false end
    
    table.insert(petData.equippedPets, instanceId)
    return savePlayerPetData(player, petData)
end

local function removeFromEquippedPets(player, instanceId)
    local petData = getPlayerPetData(player)
    if not petData then return false end
    
    for i, equippedId in ipairs(petData.equippedPets) do
        if equippedId == instanceId then
            table.remove(petData.equippedPets, i)
            return savePlayerPetData(player, petData)
        end
    end
    return false
end

local function isPetEquipped(player, instanceId)
    local petData = getPlayerPetData(player)
    if not petData then return false end
    
    for _, equippedId in ipairs(petData.equippedPets) do
        if equippedId == instanceId then
            return true
        end
    end
    return false
end

local function calculateTotalUpgradeCost(petInfo, petConfig)
    local totalCost = 0
    
    -- Добавляем стоимость улучшений глобального уровня
    if petConfig.level and petInfo.level and petInfo.level > 1 then
        for level = 1, petInfo.level - 1 do
            if petConfig.level.upgradeCost[level] then
                totalCost += petConfig.level.upgradeCost[level]
            end
        end
    end
    
    -- Добавляем стоимость улучшений индивидуальных модификаторов
    if petInfo.modifierLevels then
        for modifierIndex, currentLevel in pairs(petInfo.modifierLevels) do
            local modifier = petConfig.modifiers[modifierIndex]
            if modifier and modifier.upgradeCost and modifier.initial then
                for level = modifier.initial, currentLevel - 1 do
                    if modifier.upgradeCost[level] then
                        totalCost += modifier.upgradeCost[level]
                    end
                end
            end
        end
    end
    
    return totalCost
end

local function getPlayerCurrency(player, currencyName)
    local dataManager = _G.AssetService:GetModule("DataManager")
    if not dataManager then return 0 end
    
    local playerData = dataManager.GetData(player)
    if not playerData then return 0 end
    
    return playerData[currencyName] or 0
end

local function updatePlayerCurrency(player, currencyName, amount)
    local dataManager = _G.AssetService:GetModule("DataManager")
    if not dataManager then return false end
    
    return dataManager.UpdateData(player, function(currentData)
        currentData[currencyName] = (currentData[currencyName] or 0) + amount
        return currentData
    end)
end

-- Публичные методы
function PetSystem.Init(config)
    if systemInstance then return systemInstance, "" end
    
    -- Проверяем доступность DataManager
    local dataManager = _G.AssetService:GetModule("DataManager")
    if not dataManager then
        return nil, "DataManager not found. Please ensure DataManager is initialized via AssetService first."
    end
    
    for petName, petConfig in pairs(config.pets) do
        local isValid, errorMsg = validatePetConfig(petName, petConfig)
        if not isValid then
            return nil, "Invalid config for pet '" .. petName .. "': " .. errorMsg
        end
        
        if petConfig.level then
            if petConfig.modifiers then
                for i, modifier in ipairs(petConfig.modifiers) do
                    if modifier.initial or modifier.maxLevel or modifier.upgradeCost then
                        warn("Pet '"..petName.."' has global level system but modifier #"..i.." has individual level properties. Individual properties will be ignored.")
                    end
                end
            end
        else
            if petConfig.modifiers then
                local hasIndividualLevels = false
                local hasNoLevels = false
                
                for i, modifier in ipairs(petConfig.modifiers) do
                    if modifier.initial or modifier.maxLevel or modifier.upgradeCost then
                        hasIndividualLevels = true
                        if not (modifier.initial and modifier.maxLevel and modifier.upgradeCost) then
                            warn("Modifier #"..i.." for pet '"..petName.."' has incomplete individual level configuration")
                        end
                    else
                        hasNoLevels = true
                    end
                end
                
                if hasIndividualLevels and hasNoLevels then
                    warn("Pet '"..petName.."' has mixed modifier level types. This may cause unexpected behavior.")
                end
            end
        end
    end
    
    local self = {
        config = config,
        petsFolder = Instance.new("Folder"),
        playerPetFolders = {},
        equippedPets = {}, -- Локальный кеш экипированных питомцев
        dataManager = dataManager
    }
    
    self.petsFolder.Name = "Player_Pets"
    self.petsFolder.Parent = workspace
    
    local function getPetModel(petName)
        if not self.config.pets[petName] then
            return nil, "Pet '"..petName.."' not found in config"
        end
        
        local petConfig = self.config.pets[petName]
        if not petConfig.modelPath then 
            return nil, "No model path specified for pet '"..petName.."'"
        end
        
        local fullPath = petConfig.modelPath
        local current = game
        for part in fullPath:gmatch("[^/]+") do
            current = current:FindFirstChild(part)
            if not current then 
                return nil, "Could not find part '"..part.."' in model path for pet '"..petName.."'"
            end
        end
        
        return current, nil
    end

    local function equipPetInstance(player, petInfo, instanceId)
        local petConfig = self.config.pets[petInfo.name]
        if not petConfig then return false end
        
        local petModel, err = getPetModel(petInfo.name)
        if not petModel then return false, err end
        
        local clonedPet = petModel:Clone()
        if petConfig.walks then
            local walksValue = Instance.new("BoolValue")
            walksValue.Name = "Walks"
            walksValue.Value = true
            walksValue.Parent = clonedPet
        end
        
        clonedPet:SetAttribute("PetName", petInfo.name)
        clonedPet:SetAttribute("InstanceId", instanceId)
        clonedPet:SetAttribute("Owner", player.UserId)
        clonedPet.Parent = self.playerPetFolders[player]
        
        applyModifiers(player, petInfo.name, instanceId, petConfig, petInfo.level, petInfo.modifierLevels, true)
        
        self.equippedPets[player][instanceId] = {
            name = petInfo.name,
            level = petInfo.level,
            modifierLevels = petInfo.modifierLevels or {}
        }
        
        return true
    end

    local function playerAdded(player)
        local folder = Instance.new("Folder")
        folder.Name = player.Name
        folder.Parent = self.petsFolder
        self.playerPetFolders[player] = folder
        self.equippedPets[player] = {}
        
        -- Ждем загрузки данных игрока
        if not self.dataManager.IsDataLoaded(player) then
            local dataLoaded = player:GetAttribute("DataLoaded")
            while not dataLoaded do
                task.wait(0.1)
                dataLoaded = player:GetAttribute("DataLoaded")
            end
        end
        
        -- Экипируем питомцев из сохраненных данных
        local petData = getPlayerPetData(player)
        if petData and petData.equippedPets then
            for _, instanceId in ipairs(petData.equippedPets) do
                local ownedPet = petData.ownedPets[instanceId]
                if ownedPet then
                    local success = equipPetInstance(player, ownedPet, instanceId)
                    if not success then
                        warn("Failed to equip pet " .. instanceId .. " for player " .. player.Name)
                    end
                end
            end
        end
    end
    
    local function playerRemoving(player)
        if self.petsFolder:FindFirstChild(player.Name) then
            self.petsFolder:FindFirstChild(player.Name):Destroy()
            self.playerPetFolders[player] = nil
        end
        
        self:RemoveAllPetModifiers(player)
        self.equippedPets[player] = nil
    end
    
    Players.PlayerAdded:Connect(playerAdded)
    Players.PlayerRemoving:Connect(playerRemoving)
    
    for _, player in pairs(Players:GetPlayers()) do
        task.spawn(playerAdded, player)
    end
    
    function self:ChoosePetFromEgg(eggName)
        if not self.config.eggs[eggName] then
            return nil, "Egg '"..eggName.."' not found in config"
        end
        
        local eggConfig = self.config.eggs[eggName]
        local chance = math.random(1, 100)
        local counter = 0
        
        for petName, rarity in pairs(eggConfig.pets) do
            if not self.config.pets[petName] then
                warn("Pet '"..petName.."' from egg '"..eggName.."' not found in pets config")
                return nil, "Configuration error: pet '"..petName.."' not found"
            end
            
            counter = counter + rarity
            if chance <= counter then
                local petConfig = self.config.pets[petName]
                local initialLevel = 1
                local initialModifierLevels = {}
                
                if petConfig.level then
                    initialLevel = petConfig.level.initial or 1
                elseif petConfig.modifiers then
                    for i, modifier in ipairs(petConfig.modifiers) do
                        if modifier.initial then
                            initialModifierLevels[i] = modifier.initial
                        end
                    end
                end
                
                return {
                    name = petName,
                    level = initialLevel,
                    modifierLevels = initialModifierLevels
                }, ""
            end
        end
        
        return nil, "No pet was selected from egg '"..eggName.."'"
    end
    
    function self:AddPetToInventory(player, petInfo)
        if not player then
            return nil, "Player is nil"
        end
        
        if not self.dataManager.IsDataLoaded(player) then
            return nil, "Player data not loaded yet"
        end
        
        if not petInfo or not petInfo.name then
            return nil, "Invalid pet info"
        end
        
        if not self.config.pets[petInfo.name] then
            return nil, "Pet '"..petInfo.name.."' not found in config"
        end
        
        local instanceId = HttpService:GenerateGUID(false)
        local petData = {
            name = petInfo.name,
            level = petInfo.level or 1,
            modifierLevels = petInfo.modifierLevels or {},
            obtainedTime = os.time(),
            obtainedMethod = petInfo.obtainedMethod or "given" -- "purchased", "egg", "given"
        }
        
        local success = saveOwnedPet(player, instanceId, petData)
        if not success then
            return nil, "Failed to save pet to inventory"
        end
        
        return instanceId, ""
    end
    
    function self:EquipPet(player, instanceId)
        if not player then
            return nil, "Player is nil"
        end
        
        if not self.dataManager.IsDataLoaded(player) then
            return nil, "Player data not loaded yet"
        end
        
        local ownedPet = getOwnedPetByInstanceId(player, instanceId)
        if not ownedPet then
            return nil, "Pet not found in inventory"
        end
        
        if isPetEquipped(player, instanceId) then
            return nil, "Pet is already equipped"
        end
        
        local maxPets = self.config.settings.defaultMaxPetsEquipped
        local currentPets = #self.playerPetFolders[player]:GetChildren()
        
        if currentPets >= maxPets then 
            return nil, "Player has reached max equipped pets limit ("..maxPets..")"
        end
        
        local petConfig = self.config.pets[ownedPet.name]
        if not petConfig then
            return nil, "Pet config not found"
        end
        
        -- Проверяем уровни
        if petConfig.level then
            if not ownedPet.level then
                return nil, "Global level pet requires level"
            end
        end
        
        -- Экипируем питомца
        local success, err = equipPetInstance(player, ownedPet, instanceId)
        if not success then
            return nil, err or "Failed to equip pet instance"
        end
        
        -- Сохраняем в список экипированных
        local saveSuccess = addToEquippedPets(player, instanceId)
        if not saveSuccess then
            -- Откатываем экипировку если не удалось сохранить
            self:UnequipPet(player, instanceId)
            return nil, "Failed to save equipped pet data"
        end
        
        return instanceId, ""
    end
    
    function self:UnequipPet(player, instanceId)
        if not player then
            return nil, "Player is nil"
        end
        
        local petFolder = self.playerPetFolders[player]
        if not petFolder then
            return nil, "Player does not have pet folder"
        end
        
        local petToRemove = nil
        for _, pet in pairs(petFolder:GetChildren()) do
            if pet:GetAttribute("InstanceId") == instanceId then
                petToRemove = pet
                break
            end
        end
        
        if not petToRemove then
            return nil, "Pet with ID '"..instanceId.."' is not equipped"
        end
        
        local petName = petToRemove:GetAttribute("PetName")
        local petInfo = self.equippedPets[player][instanceId]
        if not petInfo then
            return nil, "Pet info not found for ID: " .. instanceId
        end
        
        -- Снимаем модификаторы
        applyModifiers(player, petName, instanceId, self.config.pets[petName], petInfo.level, petInfo.modifierLevels, false)
        
        -- Удаляем из сцены
        petToRemove:Destroy()
        self.equippedPets[player][instanceId] = nil
        
        -- Удаляем из списка экипированных
        removeFromEquippedPets(player, instanceId)
        
        return true, ""
    end
    
    function self:UnequipAllPets(player)
        if not player then
            return nil, "Player is nil"
        end
        
        local petFolder = self.playerPetFolders[player]
        if not petFolder then
            return nil, "Player does not have pet folder"
        end
        
        local petsToRemove = {}
        for _, pet in pairs(petFolder:GetChildren()) do
            table.insert(petsToRemove, pet)
        end
        
        for _, pet in ipairs(petsToRemove) do
            local instanceId = pet:GetAttribute("InstanceId")
            self:UnequipPet(player, instanceId)
        end
        
        return true, ""
    end
    
    function self:GetEquippedPets(player)
        if not player then
            return nil, "Player is nil"
        end
        
        if not self.equippedPets[player] then
            return {}
        end
        
        local pets = {}
        for instanceId, petInfo in pairs(self.equippedPets[player]) do
            table.insert(pets, {
                id = instanceId,
                name = petInfo.name,
                level = petInfo.level,
                modifierLevels = petInfo.modifierLevels
            })
        end
        return pets, ""
    end
    
    function self:GetOwnedPets(player)
        if not player then
            return nil, "Player is nil"
        end
        
        if not self.dataManager.IsDataLoaded(player) then
            return nil, "Player data not loaded yet"
        end
        
        local petData = getPlayerPetData(player)
        if not petData then return {} end
        
        local pets = {}
        for instanceId, petInfo in pairs(petData.ownedPets) do
            local petData = {
                id = instanceId,
                name = petInfo.name,
                level = petInfo.level,
                modifierLevels = petInfo.modifierLevels,
                obtainedTime = petInfo.obtainedTime,
                obtainedMethod = petInfo.obtainedMethod,
                isEquipped = isPetEquipped(player, instanceId)
            }
            table.insert(pets, petData)
        end
        return pets, ""
    end
    
    function self:RemovePetFromInventory(player, instanceId)
        if not player then
            return nil, "Player is nil"
        end
        
        -- Сначала снимаем питомца если он экипирован
        if isPetEquipped(player, instanceId) then
            local success, err = self:UnequipPet(player, instanceId)
            if not success then
                return nil, "Failed to unequip pet: " .. (err or "unknown error")
            end
        end
        
        -- Удаляем из инвентаря
        local success = removeOwnedPet(player, instanceId)
        if not success then
            return nil, "Failed to remove pet from inventory"
        end
        
        return true, ""
    end
    
    function self:UpgradePetLevel(player, instanceId)
        if not player then
            return nil, "Player is nil"
        end
        
        local ownedPet = getOwnedPetByInstanceId(player, instanceId)
        if not ownedPet then
            return nil, "Pet not found in inventory"
        end
        
        local petConfig = self.config.pets[ownedPet.name]
        if not petConfig then
            return nil, "Pet config not found"
        end
        
        if not petConfig.level then
            return nil, "Pet does not support global level upgrades"
        end
        
        if ownedPet.level >= petConfig.level.max then
            return nil, "Pet is already at maximum level"
        end
        
        local upgradeCost = petConfig.level.upgradeCost[ownedPet.level]
        if not upgradeCost then
            return nil, "Upgrade cost not defined for level "..ownedPet.level
        end
        
        -- Обновляем уровень в данных
        ownedPet.level = ownedPet.level + 1
        local saveSuccess = saveOwnedPet(player, instanceId, ownedPet)
        if not saveSuccess then
            return nil, "Failed to save upgraded pet level"
        end
        
        -- Если питомец экипирован, обновляем модификаторы
        if isPetEquipped(player, instanceId) then
            local petInfo = self.equippedPets[player][instanceId]
            if petInfo then
                -- Сначала удаляем старые модификаторы
                applyModifiers(player, ownedPet.name, instanceId, petConfig, petInfo.level, petInfo.modifierLevels, false)
                
                -- Обновляем локальные данные
                petInfo.level = ownedPet.level
                
                -- Применяем новые модификаторы
                applyModifiers(player, ownedPet.name, instanceId, petConfig, petInfo.level, petInfo.modifierLevels, true)
            end
        end
        
        return upgradeCost, ""
    end
    
    function self:UpgradePetModifier(player, instanceId, modifierIndex)
        if not player then
            return nil, "Player is nil"
        end
        
        local ownedPet = getOwnedPetByInstanceId(player, instanceId)
        if not ownedPet then
            return nil, "Pet not found in inventory"
        end
        
        local petConfig = self.config.pets[ownedPet.name]
        if not petConfig then
            return nil, "Pet config not found"
        end
        
        if not petConfig.modifiers or not petConfig.modifiers[modifierIndex] then
            return nil, "Modifier not found"
        end
        
        local modifier = petConfig.modifiers[modifierIndex]
        
        if not modifier.initial or not modifier.maxLevel or not modifier.upgradeCost then
            return nil, "Modifier does not support individual upgrades"
        end
        
        local currentLevel = ownedPet.modifierLevels[modifierIndex] or modifier.initial
        
        if currentLevel >= modifier.maxLevel then
            return nil, "Modifier is already at maximum level"
        end
        
        local upgradeCost = modifier.upgradeCost[currentLevel]
        if not upgradeCost then
            return nil, "Upgrade cost not defined for modifier level "..currentLevel
        end
        
        -- Обновляем уровень модификатора в данных
        ownedPet.modifierLevels[modifierIndex] = currentLevel + 1
        local saveSuccess = saveOwnedPet(player, instanceId, ownedPet)
        if not saveSuccess then
            return nil, "Failed to save upgraded modifier level"
        end
        
        -- Если питомец экипирован, обновляем модификаторы
        if isPetEquipped(player, instanceId) then
            local petInfo = self.equippedPets[player][instanceId]
            if petInfo then
                -- Сначала удаляем старые модификаторы
                applyModifiers(player, ownedPet.name, instanceId, petConfig, petInfo.level, petInfo.modifierLevels, false)
                
                -- Обновляем локальные данные
                petInfo.modifierLevels[modifierIndex] = ownedPet.modifierLevels[modifierIndex]
                
                -- Применяем новые модификаторы
                applyModifiers(player, ownedPet.name, instanceId, petConfig, petInfo.level, petInfo.modifierLevels, true)
            end
        end
        
        return upgradeCost, ""
    end
    
    function self:GetPetsFolder()
        return self.petsFolder, ""
    end
    
    function self:RemoveAllPetModifiers(player)
        if not player then return nil, "Player is nil" end
        
        -- Получаем все экипированные питомцы и снимаем их модификаторы
        if self.equippedPets[player] then
            for instanceId, petInfo in pairs(self.equippedPets[player]) do
                local petConfig = self.config.pets[petInfo.name]
                if petConfig then
                    applyModifiers(player, petInfo.name, instanceId, petConfig, petInfo.level, petInfo.modifierLevels, false)
                end
            end
        end
        
        return true, ""
    end
    
    function self:ReapplyPetModifiers(player)
        if not player or not self.equippedPets[player] then 
            return nil, "Player is nil or has no pets"
        end
        
        -- Снимаем все модификаторы
        self:RemoveAllPetModifiers(player)
        
        -- Применяем заново все модификаторы экипированных питомцев
        for instanceId, petInfo in pairs(self.equippedPets[player]) do
            applyModifiers(
                player, 
                petInfo.name, 
                instanceId, 
                self.config.pets[petInfo.name], 
                petInfo.level, 
                petInfo.modifierLevels, 
                true
            )
        end
        
        return true, ""
    end
    
    function self:GetPetConfig(petName)
        if not self.config.pets[petName] then
            return nil, "Pet not found"
        end
        return self.config.pets[petName], ""
    end
    
    function self:HasReachedPetLimit(player)
        if not player then
            return nil, "Player is nil"
        end
        local maxPets = self.config.settings.defaultMaxPetsEquipped
        local currentPets = self.playerPetFolders[player] and #self.playerPetFolders[player]:GetChildren() or 0
        return currentPets >= maxPets, ""
    end
    
    function self:GetEquippedPetsCount(player)
        if not player then
            return nil, "Player is nil"
        end
        return self.playerPetFolders[player] and #self.playerPetFolders[player]:GetChildren() or 0, ""
    end
    
    function self:GetPetUpgradeInfo(petName)
        local petConfig = self.config.pets[petName]
        if not petConfig then
            return nil, "Pet not found"
        end
        
        if petConfig.level then
            return {
                type = "global",
                currentLevel = nil,
                maxLevel = petConfig.level.max,
                upgradeCosts = petConfig.level.upgradeCost
            }, ""
        else
            local modifiersInfo = {}
            
            if petConfig.modifiers then
                for i, modifier in ipairs(petConfig.modifiers) do
                    if modifier.initial and modifier.maxLevel and modifier.upgradeCost then
                        modifiersInfo[i] = {
                            type = "individual",
                            initial = modifier.initial,
                            maxLevel = modifier.maxLevel,
                            upgradeCosts = modifier.upgradeCost
                        }
                    else
                        modifiersInfo[i] = {
                            type = "fixed",
                            value = modifier.value
                        }
                    end
                end
            end
            
            return {
                type = "mixed",
                modifiers = modifiersInfo
            }, ""
        end
    end
    
    function self:GetOwnedPetsCount(player)
        if not player then
            return nil, "Player is nil"
        end
        
        if not self.dataManager.IsDataLoaded(player) then
            return nil, "Player data not loaded yet"
        end
        
        local petData = getPlayerPetData(player)
        if not petData then return 0 end
        
        local count = 0
        for _ in pairs(petData.ownedPets) do
            count = count + 1
        end
        return count, ""
    end
    
    function self:PurchasePet(player, petName)
        if not player then
            return nil, "Player is nil"
        end
        
        if not self.dataManager.IsDataLoaded(player) then
            return nil, "Player data not loaded yet"
        end
        
        local petConfig = self.config.pets[petName]
        if not petConfig then
            return nil, "Pet '"..petName.."' not found in config"
        end
        
        -- Проверяем, есть ли цена у питомца
        if not petConfig.price then
            return nil, "Pet '"..petName.."' is not available for purchase"
        end
        
        -- Проверяем валюту
        if not petConfig.currency then
            return nil, "Currency not specified for pet '"..petName.."'"
        end
        
        -- Проверяем баланс игрока
        local currentBalance = getPlayerCurrency(player, petConfig.currency)
        if currentBalance < petConfig.price then
            return nil, "Not enough "..petConfig.currency.." to purchase pet '"..petName.."'"
        end
        
        -- Списываем валюту
        local success = updatePlayerCurrency(player, petConfig.currency, -petConfig.price)
        if not success then
            return nil, "Failed to deduct currency for pet purchase"
        end
        
        -- Создаем информацию о питомце
        local petInfo = {
            name = petName,
            level = petConfig.level and petConfig.level.initial or 1,
            modifierLevels = {},
            obtainedMethod = "purchased"
        }
        
        if not petConfig.level and petConfig.modifiers then
            for i, modifier in ipairs(petConfig.modifiers) do
                if modifier.initial then
                    petInfo.modifierLevels[i] = modifier.initial
                end
            end
        end
        
        -- Добавляем питомца в инвентарь
        local instanceId, err = self:AddPetToInventory(player, petInfo)
        if not instanceId then
            -- Возвращаем валюту в случае ошибки
            updatePlayerCurrency(player, petConfig.currency, petConfig.price)
            return nil, "Failed to add pet to inventory: " .. err
        end
        
        return instanceId, ""
    end
    
    function self:SellPet(player, instanceId)
        if not player then
            return nil, "Player is nil"
        end
        
        local ownedPet = getOwnedPetByInstanceId(player, instanceId)
        if not ownedPet then
            return nil, "Pet not found in inventory"
        end
        
        local petConfig = self.config.pets[ownedPet.name]
        if not petConfig then
            return nil, "Pet config not found"
        end
        
        -- Проверяем, можно ли продать этого питомца
        if not petConfig.price or not petConfig.currency or not petConfig.sellPercentage then
            return nil, "Pet '"..ownedPet.name.."' cannot be sold"
        end
        
        -- Рассчитываем стоимость продажи
        local basePrice = petConfig.price
        local upgradeCost = calculateTotalUpgradeCost(ownedPet, petConfig)
        local totalInvestment = basePrice + upgradeCost
        local sellPrice = math.floor(totalInvestment * petConfig.sellPercentage)
        
        -- Удаляем питомца из инвентаря
        local success, err = self:RemovePetFromInventory(player, instanceId)
        if not success then
            return nil, "Failed to remove pet from inventory: " .. (err or "unknown error")
        end
        
        -- Начисляем валюту
        if sellPrice > 0 then
            local currencySuccess = updatePlayerCurrency(player, petConfig.currency, sellPrice)
            if not currencySuccess then
                warn("Failed to add currency after selling pet, but pet was removed from inventory")
            end
        end
        
        return sellPrice, ""
    end
    
    function self:PurchaseEgg(player, eggName)
        if not player then
            return nil, "Player is nil"
        end
        
        if not self.dataManager.IsDataLoaded(player) then
            return nil, "Player data not loaded yet"
        end
        
        local eggConfig = self.config.eggs[eggName]
        if not eggConfig then
            return nil, "Egg '"..eggName.."' not found in config"
        end
        
        -- Проверяем, есть ли цена у яйца
        if not eggConfig.price then
            return nil, "Egg '"..eggName.."' is not available for purchase"
        end
        
        -- Проверяем валюту
        if not eggConfig.currency then
            return nil, "Currency not specified for egg '"..eggName.."'"
        end
        
        -- Проверяем баланс игрока
        local currentBalance = getPlayerCurrency(player, eggConfig.currency)
        if currentBalance < eggConfig.price then
            return nil, "Not enough "..eggConfig.currency.." to purchase egg '"..eggName.."'"
        end
        
        -- Списываем валюту
        local success = updatePlayerCurrency(player, eggConfig.currency, -eggConfig.price)
        if not success then
            return nil, "Failed to deduct currency for egg purchase"
        end
        
        -- Открываем яйцо
        local petInfo, err = self:ChoosePetFromEgg(eggName)
        if not petInfo then
            -- Возвращаем валюту в случае ошибки
            updatePlayerCurrency(player, eggConfig.currency, eggConfig.price)
            return nil, "Failed to open egg: " .. err
        end
        
        petInfo.obtainedMethod = "egg"
        
        -- Добавляем питомца в инвентарь
        local instanceId, addErr = self:AddPetToInventory(player, petInfo)
        if not instanceId then
            -- Возвращаем валюту в случае ошибки
            updatePlayerCurrency(player, eggConfig.currency, eggConfig.price)
            return nil, "Failed to add pet to inventory: " .. addErr
        end
        
        return instanceId, ""
    end
    
    function self:GivePet(player, petName)
        if not player then
            return nil, "Player is nil"
        end
        
        if not self.config.pets[petName] then
            return nil, "Pet '"..petName.."' not found in config"
        end
        
        local petConfig = self.config.pets[petName]
        local petInfo = {
            name = petName,
            level = petConfig.level and petConfig.level.initial or 1,
            modifierLevels = {},
            obtainedMethod = "given"
        }
        
        if not petConfig.level and petConfig.modifiers then
            for i, modifier in ipairs(petConfig.modifiers) do
                if modifier.initial then
                    petInfo.modifierLevels[i] = modifier.initial
                end
            end
        end
        
        local instanceId, err = self:AddPetToInventory(player, petInfo)
        if not instanceId then
            return nil, "Failed to add pet to inventory: " .. err
        end
        
        return instanceId, ""
    end
    
    function self:GiveEgg(player, eggName)
        if not player then
            return nil, "Player is nil"
        end
        
        local petInfo, err = self:ChoosePetFromEgg(eggName)
        if not petInfo then
            return nil, "Failed to open egg: " .. err
        end
        
        petInfo.obtainedMethod = "egg"
        
        local instanceId, addErr = self:AddPetToInventory(player, petInfo)
        if not instanceId then
            return nil, "Failed to add pet to inventory: " .. addErr
        end
        
        return instanceId, ""
    end
    
    function self:GetPetSellPrice(player, instanceId)
        if not player then
            return nil, "Player is nil"
        end
        
        local ownedPet = getOwnedPetByInstanceId(player, instanceId)
        if not ownedPet then
            return nil, "Pet not found in inventory"
        end
        
        local petConfig = self.config.pets[ownedPet.name]
        if not petConfig then
            return nil, "Pet config not found"
        end
        
        if not petConfig.price or not petConfig.currency or not petConfig.sellPercentage then
            return nil, "Pet '"..ownedPet.name.."' cannot be sold"
        end
        
        local basePrice = petConfig.price
        local upgradeCost = calculateTotalUpgradeCost(ownedPet, petConfig)
        local totalInvestment = basePrice + upgradeCost
        local sellPrice = math.floor(totalInvestment * petConfig.sellPercentage)
        
        return {
            currency = petConfig.currency,
            amount = sellPrice,
            basePrice = basePrice,
            upgradeCost = upgradeCost,
            sellPercentage = petConfig.sellPercentage
        }, ""
    end
    
    systemInstance = self
    return self, ""
end

return PetSystem