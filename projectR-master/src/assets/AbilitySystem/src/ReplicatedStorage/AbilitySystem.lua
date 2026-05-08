-- ModuleScript: ReplicatedStorage.AbilitySystem
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AbilitySystem = {}
AbilitySystem.__index = AbilitySystem

-- Серверная инициализация
local function ServerInit(self, config)
    self.Config = config
    self.Abilities = {}
    self.Cooldowns = {}
    self.ActiveAbilities = {}
    self.PlayerBindings = {}
    self.PlayerAbilities = {} -- Доступные способности для каждого игрока
    
    -- Папка для экземпляров способностей
    if config.InstanceFolder then
        local folder = workspace:FindFirstChild(config.InstanceFolder)
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = config.InstanceFolder
            folder.Parent = workspace
        end
        self.InstancesFolder = folder
    end
    
    -- Удаленные события
    self.RemoteEvents = {
        Activate = Instance.new("RemoteEvent"),
        HoldStart = Instance.new("RemoteEvent"),
        HoldEnd = Instance.new("RemoteEvent"),
        UpdateCooldown = Instance.new("RemoteEvent"),
        AbilityEvent = Instance.new("RemoteEvent"),
        BindingsUpdate = Instance.new("RemoteEvent")
    }
    
    local eventsFolder = Instance.new("Folder")
    eventsFolder.Name = "AbilitySystemEvents"
    eventsFolder.Parent = game.ReplicatedStorage
    
    for eventName, event in pairs(self.RemoteEvents) do
        event.Name = eventName
        event.Parent = eventsFolder
    end
    
    -- Загрузка способностей
    self:LoadAbilities()
    
    -- Обработчики событий
    self.RemoteEvents.Activate.OnServerEvent:Connect(function(player, abilityName, ...)
        self:ActivateAbility(player, abilityName, ...)
    end)
    
    self.RemoteEvents.HoldStart.OnServerEvent:Connect(function(player, abilityName, ...)
        self:StartAbility(player, abilityName, ...)
    end)
    
    self.RemoteEvents.HoldEnd.OnServerEvent:Connect(function(player, abilityName, ...)
        self:EndAbility(player, abilityName, ...)
    end)
    
    -- Обработка игроков
    Players.PlayerAdded:Connect(function(player)
        self:SetupPlayer(player)
        self:ApplyConfigBindings(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayer(player)
    end)
    
    for _, player in ipairs(Players:GetPlayers()) do
        self:SetupPlayer(player)
        self:ApplyConfigBindings(player)
    end
    
    return self
end

-- Клиентская инициализация
local function ClientInit(self)
    self.Bindings = {}
    self.Cooldowns = {}
    
    local eventsFolder = game.ReplicatedStorage:FindFirstChild("AbilitySystemEvents")
    if eventsFolder then
        self.RemoteEvents = {
            Activate = eventsFolder:FindFirstChild("Activate"),
            HoldStart = eventsFolder:FindFirstChild("HoldStart"),
            HoldEnd = eventsFolder:FindFirstChild("HoldEnd"),
            UpdateCooldown = eventsFolder:FindFirstChild("UpdateCooldown"),
            AbilityEvent = eventsFolder:FindFirstChild("AbilityEvent"),
            BindingsUpdate = eventsFolder:FindFirstChild("BindingsUpdate")
        }
    end
    
    -- Обработка обновлений биндингов
    if self.RemoteEvents.BindingsUpdate then
        self.RemoteEvents.BindingsUpdate.OnClientEvent:Connect(function(bindings)
            self:UpdateBindings(bindings)
        end)
    end
    
    -- Обработка кулдаунов
    if self.RemoteEvents.UpdateCooldown then
        self.RemoteEvents.UpdateCooldown.OnClientEvent:Connect(function(abilityName, cooldown)
            self.Cooldowns[abilityName] = cooldown
        end)
    end
    
    -- Инициализация обработчиков ввода
    self:SetupInput()
    
    return self
end

-- Единая функция инициализации
function AbilitySystem.Init(config)
    local self = setmetatable({}, AbilitySystem)
    
    if RunService:IsServer() then
        return ServerInit(self, config)
    else
        return ClientInit(self)
    end
end

-- Обновление биндингов на клиенте
function AbilitySystem:UpdateBindings(bindings)
    self.Bindings = bindings
    self:SetupInput()
end

-- Настройка обработчиков ввода на клиенте
function AbilitySystem:SetupInput()
    local UserInputService = game:GetService("UserInputService")
    
    -- Очистка старых обработчиков
    if self.InputBeganConn then
        self.InputBeganConn:Disconnect()
        self.InputBeganConn = nil
    end
    
    if self.InputEndedConn then
        self.InputEndedConn:Disconnect()
        self.InputEndedConn = nil
    end
    
    -- Новые обработчики
    self.InputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        local key = self:GetInputKey(input)
        if key and self.Bindings[key] then
            local abilityName = self.Bindings[key]
            
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.MouseButton2 then
                local mouse = game.Players.LocalPlayer:GetMouse()
                self.RemoteEvents.Activate:FireServer(abilityName, mouse.Hit.Position)
            else
                self.RemoteEvents.Activate:FireServer(abilityName)
            end
        end
    end)
    
    self.InputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        local key = self:GetInputKey(input)
        if key and self.Bindings[key] then
            local abilityName = self.Bindings[key]
            self.RemoteEvents.HoldEnd:FireServer(abilityName)
        end
    end)
end

-- Преобразование ввода в ключ
function AbilitySystem:GetInputKey(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        return input.KeyCode.Name
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        return "MouseButton1"
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        return "MouseButton2"
    end
    return nil
end

-- Настройка игрока (сервер)
function AbilitySystem:SetupPlayer(player)
    self.PlayerBindings[player] = {}
    self.PlayerAbilities[player] = {}
    
    -- Папка для привязок
    local bindingsFolder = player:FindFirstChild("AbilityBindings")
    if not bindingsFolder then
        bindingsFolder = Instance.new("Folder")
        bindingsFolder.Name = "AbilityBindings"
        bindingsFolder.Parent = player
    end
    
    -- Загрузка сохраненных привязок
    for _, child in ipairs(bindingsFolder:GetChildren()) do
        if child:IsA("StringValue") then
            self.PlayerBindings[player][child.Name] = child.Value
        end
    end
    
    -- Отправка биндингов на клиент
    self:SendBindingsToClient(player)
end

-- Применение биндингов из конфига (сервер)
function AbilitySystem:ApplyConfigBindings(player)
    for abilityName, abilityConfig in pairs(self.Config.Abilities) do
        if abilityConfig.input then
            self:BindAbility(player, abilityName, abilityConfig.input)
        end
        -- Добавляем способность в список доступных для игрока
        self.PlayerAbilities[player][abilityName] = true
    end
end

-- Отправка биндингов на клиент
function AbilitySystem:SendBindingsToClient(player)
    if self.RemoteEvents.BindingsUpdate then
        self.RemoteEvents.BindingsUpdate:FireClient(player, self.PlayerBindings[player])
    end
end

-- Очистка игрока (сервер)
function AbilitySystem:CleanupPlayer(player)
    local playerId = player.UserId
    
    -- Отмена активных способностей
    for abilityId in pairs(self.ActiveAbilities) do
        if string.find(abilityId, tostring(playerId)) then
            self.ActiveAbilities[abilityId] = nil
        end
    end
    
    -- Очистка кулдаунов
    self.Cooldowns[playerId] = nil
    
    -- Удаление биндингов
    self.PlayerBindings[player] = nil
    self.PlayerAbilities[player] = nil
end

-- Загрузка способностей (сервер)
function AbilitySystem:LoadAbilities()
    local abilityFolder = game.ServerStorage:FindFirstChild(self.Config.AbilityFolder)
    if abilityFolder then
        for abilityName, abilityConfig in pairs(self.Config.Abilities) do
            local abilityAssets = abilityFolder:FindFirstChild(abilityName)
            if abilityAssets then
                local moduleScript = abilityAssets:FindFirstChild("AbilityModule")
                if moduleScript then
                    local success, abilityModule = pcall(require, moduleScript)
                    if success and type(abilityModule) == "table" then
                        self.Abilities[abilityName] = {
                            Config = abilityConfig,
                            Assets = abilityAssets,
                            Module = abilityModule
                        }
                    end
                end
            end
        end
    end
end

-- Привязка способности (сервер)
function AbilitySystem:BindAbility(player, abilityName, inputType)
    -- Проверка существования способности
    if not self.Abilities[abilityName] then
        warn("Способность не найдена: "..abilityName)
        return false
    end
    
    -- Удаление старых привязок для этого input
    local currentBinding = self:GetBoundAbility(player, inputType)
    if currentBinding then
        self:UnbindAbility(player, inputType)
    end
    
    -- Обновление привязок
    self.PlayerBindings[player][inputType] = abilityName
    
    -- Сохранение в папке игрока
    local bindingsFolder = player:FindFirstChild("AbilityBindings")
    if not bindingsFolder then
        bindingsFolder = Instance.new("Folder")
        bindingsFolder.Name = "AbilityBindings"
        bindingsFolder.Parent = player
    end
    
    -- Создание/обновление привязки
    local binding = bindingsFolder:FindFirstChild(inputType)
    if not binding then
        binding = Instance.new("StringValue")
        binding.Name = inputType
        binding.Parent = bindingsFolder
    end
    binding.Value = abilityName
    
    -- Отправка обновлений на клиент
    self:SendBindingsToClient(player)
    
    return true
end

-- Отвязка способности (сервер)
function AbilitySystem:UnbindAbility(player, inputType)
    if not self.PlayerBindings[player][inputType] then
        return false
    end
    
    -- Удаление из памяти
    self.PlayerBindings[player][inputType] = nil
    
    -- Удаление из папки игрока
    local bindingsFolder = player:FindFirstChild("AbilityBindings")
    if bindingsFolder then
        local binding = bindingsFolder:FindFirstChild(inputType)
        if binding then
            binding:Destroy()
        end
    end
    
    -- Отправка обновлений на клиент
    self:SendBindingsToClient(player)
    
    return true
end

-- Добавление способности (сервер)
function AbilitySystem:AddAbility(player, abilityName)
    -- Проверка существования способности в системе
    if not self.Abilities[abilityName] then
        warn("Способность не найдена в системе: "..abilityName)
        return false
    end
    
    -- Добавляем в список доступных способностей игрока
    self.PlayerAbilities[player][abilityName] = true
    
    -- Привязываем если указан input в конфиге
    local inputType = self.Config.Abilities[abilityName].input
    if inputType then
        self:BindAbility(player, abilityName, inputType)
    end
    
    return true
end

-- Удаление способности (сервер)
function AbilitySystem:RemoveAbility(player, abilityName)
    -- Удаляем из доступных способностей игрока
    self.PlayerAbilities[player][abilityName] = nil
    
    -- Отмена активных способностей
    for abilityId in pairs(self.ActiveAbilities) do
        if string.find(abilityId, abilityName) then
            self:CancelAbilityById(abilityId)
        end
    end
    
    -- Удаление привязок
    for inputType, boundAbility in pairs(self.PlayerBindings[player]) do
        if boundAbility == abilityName then
            self:UnbindAbility(player, inputType)
        end
    end
    
    return true
end

-- Получение привязанной способности (сервер)
function AbilitySystem:GetBoundAbility(player, inputType)
    return self.PlayerBindings[player] and self.PlayerBindings[player][inputType]
end

-- Проверка кулдауна (сервер)
function AbilitySystem:CheckCooldown(player, abilityName)
    -- Проверка доступности способности
    if not self.PlayerAbilities[player] or not self.PlayerAbilities[player][abilityName] then
        return false
    end
    
    local playerId = player.UserId
    self.Cooldowns[playerId] = self.Cooldowns[playerId] or {}
    local lastUsed = self.Cooldowns[playerId][abilityName] or 0
    local cooldown = self.Abilities[abilityName].Config.Cooldown or 0
    
    if os.time() - lastUsed < cooldown then
        local remaining = cooldown - (os.time() - lastUsed)
        self.RemoteEvents.UpdateCooldown:FireClient(player, abilityName, remaining)
        return false
    end
    return true
end

-- Начало кулдауна (сервер)
function AbilitySystem:StartCooldown(player, abilityName)
    local playerId = player.UserId
    local cooldown = self.Abilities[abilityName].Config.Cooldown or 0
    self.Cooldowns[playerId] = self.Cooldowns[playerId] or {}
    self.Cooldowns[playerId][abilityName] = os.time()
    self.RemoteEvents.UpdateCooldown:FireClient(player, abilityName, cooldown)
end

-- Активация способности (сервер)
function AbilitySystem:ActivateAbility(player, abilityName, ...)
    -- Проверка доступности способности
    if not self.PlayerAbilities[player] or not self.PlayerAbilities[player][abilityName] then
        return
    end
    
    local ability = self.Abilities[abilityName]
    if not ability then return end
    if not self:CheckCooldown(player, abilityName) then return end
    
    -- Для мгновенных способностей
    if ability.Module.activate then
        self:StartCooldown(player, abilityName)
        
        local abilityId = player.UserId .. "_" .. abilityName .. "_" .. os.time()
        self.ActiveAbilities[abilityId] = true
        
        local function cleanup()
            self.ActiveAbilities[abilityId] = nil
        end
        
        -- Создание экземпляра в папке системы
        local function createInstance(instance)
            if self.InstancesFolder then
                instance.Parent = self.InstancesFolder
                return instance
            end
            return instance
        end
        
        task.spawn(ability.Module.activate, player, ability.Config, ability.Assets, cleanup, createInstance, ...)
    end
end

-- Начало удержания способности (сервер)
function AbilitySystem:StartAbility(player, abilityName, ...)
    -- Проверка доступности способности
    if not self.PlayerAbilities[player] or not self.PlayerAbilities[player][abilityName] then
        return
    end
    
    local ability = self.Abilities[abilityName]
    if not ability then return end
    if not ability.Module.holdStart then return end
    if not self:CheckCooldown(player, abilityName) then return end
    
    local abilityId = player.UserId .. "_" .. abilityName .. "_hold"
    self.ActiveAbilities[abilityId] = true
    
    -- Создание экземпляра в папке системы
    local function createInstance(instance)
        if self.InstancesFolder then
            instance.Parent = self.InstancesFolder
            return instance
        end
        return instance
    end
    
    task.spawn(ability.Module.holdStart, player, ability.Config, ability.Assets, createInstance, ...)
end

-- Завершение способности (сервер)
function AbilitySystem:EndAbility(player, abilityName, ...)
    -- Проверка доступности способности
    if not self.PlayerAbilities[player] or not self.PlayerAbilities[player][abilityName] then
        return
    end
    
    local ability = self.Abilities[abilityName]
    if not ability then return end
    if not ability.Module.holdEnd then return end
    
    local abilityId = player.UserId .. "_" .. abilityName .. "_hold"
    if not self.ActiveAbilities[abilityId] then return end
    
    self:StartCooldown(player, abilityName)
    self.ActiveAbilities[abilityId] = nil
    
    -- Создание экземпляра в папке системы
    local function createInstance(instance)
        if self.InstancesFolder then
            instance.Parent = self.InstancesFolder
            return instance
        end
        return instance
    end
    
    task.spawn(ability.Module.holdEnd, player, ability.Config, ability.Assets, createInstance, ...)
end

-- Отмена способности по ID
function AbilitySystem:CancelAbilityById(abilityId)
    if not self.ActiveAbilities[abilityId] then return end
    
    -- Парсим ID способности
    local playerId, abilityName, abilityType = string.match(abilityId, "^(%d+)_(.+)_(.+)$")
    
    -- Вызов функции отмены
    local ability = self.Abilities[abilityName]
    if ability and ability.Module.cancel then
        local player = Players:GetPlayerByUserId(tonumber(playerId))
        if player then
            task.spawn(ability.Module.cancel, player)
        end
    end
    
    self.ActiveAbilities[abilityId] = nil
end

-- Перезагрузка системы (сервер)
function AbilitySystem:Reload()
    self.ActiveAbilities = {}
    self:LoadAbilities()
    
    -- Переприменение биндингов для всех игроков
    for player in pairs(self.PlayerBindings) do
        self:ApplyConfigBindings(player)
    end
end

return AbilitySystem