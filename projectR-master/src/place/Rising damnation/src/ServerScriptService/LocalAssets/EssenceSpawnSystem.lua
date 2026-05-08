-- AssetsFolder/EssenceSpawnSystem.lua
local EssenceSpawnSystem = {}

local RARITIES = {
    {
        name = "Common",
        color = Color3.fromRGB(200, 200, 200), -- серый
        baseChance = 0.5,
        weight = 1,
        value = 1
    },
    {
        name = "Incommon",
        color = Color3.fromRGB(100, 200, 100), -- зеленый
        baseChance = 0.25,
        weight = 2,
        value = 2
    },
    {
        name = "Rare",
        color = Color3.fromRGB(100, 100, 255), -- синий
        baseChance = 0.15,
        weight = 3,
        value = 5
    },
    {
        name = "Epic",
        color = Color3.fromRGB(170, 0, 255), -- фиолетовый
        baseChance = 0.07,
        weight = 5,
        value = 10
    },
    {
        name = "Legendary",
        color = Color3.fromRGB(255, 128, 0), -- оранжевый
        baseChance = 0.025,
        weight = 8,
        value = 25
    },
    {
        name = "Mythical",
        color = Color3.fromRGB(255, 50, 50), -- красный
        baseChance = 0.005,
        weight = 12,
        value = 50
    }
}

local function GetRandomOffset()
    return Vector3.new(
        math.random(-5, 5),
        0,
        math.random(-5, 5)
    )
end

function EssenceSpawnSystem.SelectRarity(yPosition)
    -- Нормализуем высоту (предполагаем, что максимальная значимая высота - 100)
    local normalizedHeight = math.clamp(yPosition / 100, 0, 1)
    
    local totalWeight = 0
    local weightedChances = {}
    
    for i, rarity in ipairs(RARITIES) do
        local weight = rarity.baseChance * (1 + normalizedHeight * i * 0.5)
        weightedChances[i] = weight
        totalWeight = totalWeight + weight
    end
    
    local normalizedChances = {}
    local cumulative = 0
    
    for i, weight in ipairs(weightedChances) do
        local chance = weight / totalWeight
        cumulative = cumulative + chance
        normalizedChances[i] = {
            index = i,
            cumulative = cumulative
        }
    end
    
    local random = math.random()
    for _, chanceInfo in ipairs(normalizedChances) do
        if random <= chanceInfo.cumulative then
            return RARITIES[chanceInfo.index]
        end
    end
    
    return RARITIES[1] -- fallback
end

function EssenceSpawnSystem.ColorizeModel(model, color)
    if model:FindFirstChild("Shell") then
        model.Shell.Color = color
    end
    if model:FindFirstChild("Core") then
        model.Core.Color = color
        local light = model.Core:FindFirstChildOfClass("PointLight")
        if light then
            light.Color = color
        end
    end
end

function EssenceSpawnSystem.GetRarityInfo(rarityName)
    for _, rarity in ipairs(RARITIES) do
        if rarity.name == rarityName then
            return rarity
        end
    end
    return RARITIES[1] -- fallback to Common
end

function EssenceSpawnSystem.RespawnEssence(object, originalParent)
    object.Parent = nil
    local mainPart = object:FindFirstChild("Core") or object:FindFirstChild("Shell")
    if not mainPart then return end
    
    local spawnPosition
    if (object:GetAttribute("SpawnX") == 0 and object:GetAttribute("SpawnY") == 0 and object:GetAttribute("SpawnZ") == 0) then
        spawnPosition = mainPart.Position
        object:SetAttribute("SpawnX", spawnPosition.X)
        object:SetAttribute("SpawnY", spawnPosition.Y)
        object:SetAttribute("SpawnZ", spawnPosition.Z)
    else
        spawnPosition = Vector3.new(
            object:GetAttribute("SpawnX") or 0,
            object:GetAttribute("SpawnY") or 0,
            object:GetAttribute("SpawnZ") or 0
        )
    end
    
    local rarity = EssenceSpawnSystem.SelectRarity(spawnPosition.Y)
    object:SetAttribute("Rarity", rarity.name)
    EssenceSpawnSystem.ColorizeModel(object, rarity.color)

    delay(5, function()
        if object and not object.Parent then
            local newPosition = spawnPosition + GetRandomOffset()
            object:FindFirstChild("Core").Position = newPosition
            object:FindFirstChild("Shell").Position = newPosition
            object.Parent = originalParent
        end
    end)
end

function EssenceSpawnSystem.GetEssenceValue(rarityName)
    local rarity = EssenceSpawnSystem.GetRarityInfo(rarityName)
    return rarity.value
end

function EssenceSpawnSystem.GetEssenceWeight(rarityName)
    local rarity = EssenceSpawnSystem.GetRarityInfo(rarityName)
    return rarity.weight
end

return EssenceSpawnSystem