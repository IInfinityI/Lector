local TagBehaviorSystem = {}
TagBehaviorSystem.__index = TagBehaviorSystem

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

-- Глубокое копирование таблиц
local function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = type(v) == "table" and deepCopy(v) or v
    end
    return copy
end

function TagBehaviorSystem.new(object, tag, configPath)
    local self = setmetatable({}, TagBehaviorSystem)
    self.Object = object
    self.Tag = tag
    
    -- Safely require modules with error handling
    local success, Config = pcall(require, configPath or ServerStorage:FindFirstChild("ObjectConfig"))
    if not success then
        warn("Failed to load ObjectConfig:", Config)
        Config = {}
    end

    self.Config = Config[tag] or {}

    self.Connections = {} -- Для хранения всех соединений событий

    self:Initialize()
    return self
end

function TagBehaviorSystem:Initialize()
    -- Установка атрибутов
    for attrName, value in pairs(self.Config.Attributes or {}) do
        self.Object:SetAttribute(attrName, value)
    end

    -- Настройка событий
    self:SetupEvents()
end

function TagBehaviorSystem:ConnectSignal(signal, callback)
    if not signal or typeof(signal) ~= "RBXScriptSignal" then
        warn("Attempt to connect to invalid signal")
        return nil
    end
    
    local connection = signal:Connect(callback)
    table.insert(self.Connections, connection)
    return connection
end

function TagBehaviorSystem:GetPrimaryPart()
    -- Helper function to safely get primary part
    if self.Object:IsA("Model") then
        return self.Object.PrimaryPart or self.Object:FindFirstChildWhichIsA("BasePart")
    elseif self.Object:IsA("BasePart") then
        return self.Object
    end
    return nil
end

function TagBehaviorSystem:SetupEvents()
    if not self.Config.Events then return end
    
    for eventName, eventData in pairs(self.Config.Events) do
        if eventName == "Touched" then
            -- Обработка события Touched
            for _, part in ipairs(self.Object:GetDescendants()) do
                if part:IsA("BasePart") then
                    self:ConnectSignal(part.Touched, function(hit)
                        if eventData.Condition and not eventData.Condition(hit, self.Object) then return end

                        if eventData.Cooldown then
                            local lastHit = self.Object:GetAttribute("LastHit") or 0
                            if os.clock() - lastHit < eventData.Cooldown then return end
                            self.Object:SetAttribute("LastHit", os.clock())
                        end

                        eventData.Action(hit, self.Object)
                    end)
                end
            end
            
        elseif eventName == "ClickDetector" then
            -- Обработка событий ClickDetector
            local primaryPart = self:GetPrimaryPart()
            if primaryPart then
                local clickDetector = Instance.new("ClickDetector")
                clickDetector.Parent = primaryPart
                
                if eventData.MouseClick then
                    self:ConnectSignal(clickDetector.MouseClick, function(player)
                        if eventData.MouseClick.Condition and not eventData.MouseClick.Condition(player, self.Object) then return end
                        eventData.MouseClick.Action(player, self.Object)
                    end)
                end
                
                if eventData.RightMouseClick then
                    self:ConnectSignal(clickDetector.RightMouseClick, function(player)
                        if eventData.RightMouseClick.Condition and not eventData.RightMouseClick.Condition(player, self.Object) then return end
                        eventData.RightMouseClick.Action(player, self.Object)
                    end)
                end
                
                if eventData.MouseHoverEnter then
                    self:ConnectSignal(clickDetector.MouseHoverEnter, function(player)
                        if eventData.MouseHoverEnter.Condition and not eventData.MouseHoverEnter.Condition(player, self.Object) then return end
                        eventData.MouseHoverEnter.Action(player, self.Object)
                    end)
                end
                
                if eventData.MouseHoverLeave then
                    self:ConnectSignal(clickDetector.MouseHoverLeave, function(player)
                        if eventData.MouseHoverLeave.Condition and not eventData.MouseHoverLeave.Condition(player, self.Object) then return end
                        eventData.MouseHoverLeave.Action(player, self.Object)
                    end)
                end
            else
                warn("No suitable part found for ClickDetector in object:", self.Object)
            end
            
        elseif eventName == "ProximityPrompt" then
            -- Обработка событий ProximityPrompt
            local primaryPart = self:GetPrimaryPart()
            if primaryPart then
                local prompt = Instance.new("ProximityPrompt")
                prompt.ObjectText = eventData.ObjectText or self.Object.Name
                prompt.ActionText = eventData.ActionText or "Interact"
                prompt.HoldDuration = eventData.HoldDuration or 0
                prompt.KeyboardKeyCode = eventData.KeyboardKeyCode or Enum.KeyCode.E
                prompt.GamepadKeyCode = eventData.GamepadKeyCode or Enum.KeyCode.ButtonX
                prompt.MaxActivationDistance = eventData.MaxActivationDistance or 10
                
                prompt.Parent = primaryPart
                
                if eventData.Triggered then
                    self:ConnectSignal(prompt.Triggered, function(player)
                        if eventData.Triggered.Condition and not eventData.Triggered.Condition(player, self.Object) then return end
                        eventData.Triggered.Action(player, self.Object)
                    end)
                end
                
                if eventData.PromptShown then
                    self:ConnectSignal(prompt.PromptShown, function(player)
                        if eventData.PromptShown.Condition and not eventData.PromptShown.Condition(player, self.Object) then return end
                        eventData.PromptShown.Action(player, self.Object)
                    end)
                end
                
                if eventData.PromptHidden then
                    self:ConnectSignal(prompt.PromptHidden, function(player)
                        if eventData.PromptHidden.Condition and not eventData.PromptHidden.Condition(player, self.Object) then return end
                        eventData.PromptHidden.Action(player, self.Object)
                    end)
                end
                
                if eventData.TriggerEnded then
                    self:ConnectSignal(prompt.TriggerEnded, function(player)
                        if eventData.TriggerEnded.Condition and not eventData.TriggerEnded.Condition(player, self.Object) then return end
                        eventData.TriggerEnded.Action(player, self.Object)
                    end)
                end
            else
                warn("No suitable part found for ProximityPrompt in object:", self.Object)
            end
            
        elseif eventName == "Destroying" then
            -- Обработка события перед уничтожением объекта
            if self.Object:IsA("Instance") then
                self:ConnectSignal(self.Object.Destroying, function()
                    if eventData.Condition and not eventData.Condition(self.Object) then return end
                    eventData.Action(self.Object)
                end)
            end
        end
    end
end

function TagBehaviorSystem:Destroy()
    -- Очистка всех соединений
    for _, connection in ipairs(self.Connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    self.Connections = {}
end

function TagBehaviorSystem.Init(configPath)
    -- Safely require the config
    local success, Config = pcall(require, configPath or ServerStorage:FindFirstChild("ObjectConfig"))
    if not success then
        warn("Failed to load ObjectConfig:", Config)
        return
    end

    for tagName in pairs(Config) do
        -- Обработка новых объектов с тегом
        local addedSignal = CollectionService:GetInstanceAddedSignal(tagName)
        addedSignal:Connect(function(obj)
            TagBehaviorSystem.new(obj, tagName, configPath)
        end)

        -- Обработка уже существующих объектов с тегом
        for _, obj in ipairs(CollectionService:GetTagged(tagName)) do
            TagBehaviorSystem.new(obj, tagName, configPath)
        end
    end
end

return TagBehaviorSystem