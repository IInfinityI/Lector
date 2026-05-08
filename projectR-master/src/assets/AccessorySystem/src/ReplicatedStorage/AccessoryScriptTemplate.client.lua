local accessory = script.Parent
local character = accessory:FindFirstAncestorOfClass("Model")
local player = character and game:GetService("Players"):GetPlayerFromCharacter(character)
local humanoid = character and character:FindFirstChildOfClass("Humanoid")

local ACCESSORY_NAME = script:GetAttribute("AccessoryName")
local ACCESSORY_TYPE = script:GetAttribute("AccessoryType")
local CATEGORY = script:GetAttribute("Category")

-- Собираем все эффекты из атрибутов
local effects = {}
local i = 1
while true do
    local effectType = script:GetAttribute(string.format("Effect%d_type", i))
    if not effectType then break end
    
    local effectValue = script:GetAttribute(string.format("Effect%d_value", i))
    if effectValue == nil then
        warn(string.format("Effect %d for accessory %s has nil value!", i, ACCESSORY_NAME))
        break
    end
    
    table.insert(effects, {
        type = effectType,
        value = effectValue
    })
    i += 1
end

local function applyEffects()
    if not humanoid then return end
    
    for _, effect in ipairs(effects) do
        if effect.type == "MaxHealth" then
            humanoid.MaxHealth = humanoid.MaxHealth + (effect.value or 0)
            humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
        elseif effect.type == "MovementSpeed" then
            humanoid.WalkSpeed = humanoid.WalkSpeed + (effect.value or 0)
        elseif effect.type == "JumpPower" then
            humanoid.JumpPower = humanoid.JumpPower + (effect.value or 0)
        elseif effect.type == "Health" then
            humanoid.Health = math.min(humanoid.Health + (effect.value or 0), humanoid.MaxHealth)
        else
            local current = humanoid:GetAttribute(effect.type) or 0
            humanoid:SetAttribute(effect.type, current + (effect.value or 0))
        end
    end
end

local function removeEffects()
    if not humanoid then return end
    
    for _, effect in ipairs(effects) do
        if effect.type == "MaxHealth" then
            humanoid.MaxHealth = humanoid.MaxHealth - (effect.value or 0)
            humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
        elseif effect.type == "MovementSpeed" then
            humanoid.WalkSpeed = humanoid.WalkSpeed - (effect.value or 0)
        elseif effect.type == "JumpPower" then
            humanoid.JumpPower = humanoid.JumpPower - (effect.value or 0)
        elseif effect.type == "Health" then
            humanoid.Health = math.min(humanoid.Health - (effect.value or 0), humanoid.MaxHealth)
        else
            local current = humanoid:GetAttribute(effect.type) or 0
            humanoid:SetAttribute(effect.type, current - (effect.value or 0))
        end
    end
end

-- Применяем эффекты при добавлении в персонажа
if character and humanoid then
    applyEffects()
end

-- Обработка изменения родителя
local function onAncestryChanged(_, newParent)
    local newCharacter = newParent and newParent:FindFirstAncestorOfClass("Model")
    local newHumanoid = newCharacter and newCharacter:FindFirstChildOfClass("Humanoid")
    
    -- Если аксессуар был удален из персонажа
    if character and not newCharacter then
        removeEffects()
    end
    
    -- Если аксессуар добавлен в нового персонажа
    if newCharacter and newHumanoid and (not character or character ~= newCharacter) then
        if character and humanoid then
            removeEffects()
        end
        
        character = newCharacter
        humanoid = newHumanoid
        player = game:GetService("Players"):GetPlayerFromCharacter(character)
        applyEffects()
    end
end

accessory.AncestryChanged:Connect(onAncestryChanged)

-- Очистка при удалении аксессуара
local function onDestroying()
    if character and humanoid then
        removeEffects()
    end
end

accessory.Destroying:Connect(onDestroying)