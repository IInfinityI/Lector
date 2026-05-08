local PetClient = {}

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Настройки
local settings = {
    showOwnPets = true,
    showOthersPets = true
}

-- Локальные переменные
local player = Players.LocalPlayer
local petsController = {}

-- Локальные функции
local function getPosition(angle, radius)
    local x = math.cos(angle) * radius
    local z = math.sin(angle) * radius
    return x, z
end

local function setPetVisibility(petModel, isVisible)
    for _, part in ipairs(petModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = isVisible and 0 or 1
        end
    end
end

local function updatePetsVisibility(petFolder, playerName)
    for _, petModel in ipairs(petFolder:GetChildren()) do
        if petModel:IsA("Model") then
            if playerName == player.Name then
                setPetVisibility(petModel, settings.showOwnPets)
            else
                setPetVisibility(petModel, settings.showOthersPets)
            end
        end
    end
end

local function positionPets(character, folder)
    local CIRCLE = math.pi * 2
    
    for i, pet in pairs(folder:GetChildren()) do
        if pet:IsA("Model") and pet.PrimaryPart then
            local radius = 4 + #folder:GetChildren()
            local angle = i * (CIRCLE / #folder:GetChildren())
            local x, z = math.cos(angle) * radius, math.sin(angle) * radius
            
            -- Получаем размеры персонажа и питомца
            local _, characterSize = character:GetBoundingBox()
            local _, petSize = pet:GetBoundingBox()
            
            -- Базовое смещение по Y
            local baseY = 0
            local isWalkingPet = pet:FindFirstChild("Walks")
            
            if isWalkingPet then
                -- Для ходящих питомцев - проверяем контакт с землей
                local rayOrigin = character.PrimaryPart.Position + Vector3.new(x, 0, z)
                local rayDirection = Vector3.new(0, -10, 0)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {character, pet}
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                
                local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                
                if raycastResult then
                    baseY = raycastResult.Position.Y - character.PrimaryPart.Position.Y + petSize.Y/2
                else
                    baseY = -characterSize.Y/2 + petSize.Y/2
                end
            else
                -- Для летающих питомцев - плавающая анимация
                baseY = -characterSize.Y/2 + petSize.Y/2 + math.sin(time()*3) + 1
            end
            
            -- Эффекты анимации при движении
            local animY = 0
            local animZ = 0
            
            if character.Humanoid.MoveDirection.Magnitude > 0 then
                if isWalkingPet then
                    -- Эффект прыжков для ходящих питомцев
                    animY = (math.sin(15 * time() + 1.6)/0.5) + 1
                    animZ = math.cos(7 * time() + 1)/4
                end
            end
            
            -- Финальная позиция
            local worldPosition = character.PrimaryPart.Position + Vector3.new(x, baseY + animY, z + animZ)
            
            -- Устанавливаем позицию без вращения (но сохраняем оригинальное вращение питомца)
            local targetCFrame = CFrame.new(worldPosition) * pet.PrimaryPart.CFrame.Rotation
            pet:SetPrimaryPartCFrame(pet.PrimaryPart.CFrame:Lerp(targetCFrame, 0.1))
        end
    end
end

-- Публичные методы
function PetClient:Init(petsFolder)
    -- Обработчик для персонажа игрока
    local function onCharacterAdded(character)
        local humanoid = character:WaitForChild("Humanoid")
        local playerFolder = petsFolder:FindFirstChild(player.Name)
        
        if not playerFolder then return end
        
        RunService.RenderStepped:Connect(function()
            if humanoid.Health > 0 then
                positionPets(character, playerFolder)
            end
        end)
    end

    -- Обработчик для других игроков
    local function onOtherPlayerAdded(otherPlayer)
        local function onOtherCharacterAdded(otherCharacter)
            local otherHumanoid = otherCharacter:WaitForChild("Humanoid")
            local otherPlayerFolder = petsFolder:FindFirstChild(otherPlayer.Name)
            
            if not otherPlayerFolder then return end
            
            updatePetsVisibility(otherPlayerFolder, otherPlayer.Name)
            
            RunService.RenderStepped:Connect(function()
                if otherHumanoid.Health > 0 then
                    positionPets(otherCharacter, otherPlayerFolder)
                end
            end)
        end
        
        otherPlayer.CharacterAdded:Connect(onOtherCharacterAdded)
        if otherPlayer.Character then
            onOtherCharacterAdded(otherPlayer.Character)
        end
    end

    -- Инициализация
    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            onOtherPlayerAdded(otherPlayer)
        end
    end
    
    Players.PlayerAdded:Connect(onOtherPlayerAdded)
    
    -- Обновляем видимость всех петов
    for _, playerFolder in pairs(petsFolder:GetChildren()) do
        updatePetsVisibility(playerFolder, playerFolder.Name)
    end
end

function PetClient:SetVisibility(ownPetsVisible, othersPetsVisible)
    settings.showOwnPets = ownPetsVisible
    settings.showOthersPets = othersPetsVisible
    
    local petsFolder = workspace:FindFirstChild("Player_Pets")
    if not petsFolder then return end
    
    for _, playerFolder in pairs(petsFolder:GetChildren()) do
        updatePetsVisibility(playerFolder, playerFolder.Name)
    end
end

return PetClient