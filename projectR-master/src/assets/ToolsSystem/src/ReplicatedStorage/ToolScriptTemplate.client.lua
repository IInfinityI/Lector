local tool = script.Parent
local handle = tool:FindFirstChild("Handle")
local ContextActionService = game:GetService("ContextActionService")

-- Настройки
local REMOTES_FOLDER_NAME = script:GetAttribute("RemotesFolder") or "ToolRemotes"

-- Состояние инструмента
local toolState = {
    actions = {},         -- массив действий
    actionsByName = {},   -- быстрый доступ по имени
    animations = {},
    sounds = {},
    remotes = {},
    cooldowns = {},
    currentAnimator = nil,
    actionBindings = {}
}

-- Вспомогательные функции
local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function getHumanoid()
    if tool.Parent:IsA("Model") then
        return tool.Parent:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

local function safeLoadAnimation(animator, animation)
    local success, animTrack = pcall(function()
        return animator:LoadAnimation(animation)
    end)
    return success and animTrack or nil
end

local function playSound(soundName)
    if soundName and toolState.sounds[soundName] then
        local sound = toolState.sounds[soundName]
        if not sound.IsPlaying then
            pcall(function()
                sound:Play()
            end)
        end
    end
end

local function stopAnimation(animName)
    if animName and toolState.animations[animName] then
        if toolState.animations[animName].IsPlaying then
            toolState.animations[animName]:Stop()
        end
    end
end

-- Инициализация действий из атрибутов скрипта
local function initializeActions()
    toolState.actions = {}
    toolState.actionsByName = {}

    -- Временный словарь для сбора данных по actionName
    local actionsTemp = {}

    -- Собираем все атрибуты скрипта
    for attrName, attrValue in pairs(script:GetAttributes()) do
        -- Ищем атрибуты действий (формат: ActionName_Type)
        local actionName, attrType = string.match(attrName, "^([^_]+)_(.+)$")
        if actionName and attrType then
            -- Создаем структуру действия если ее еще нет
            if not actionsTemp[actionName] then
                actionsTemp[actionName] = {
                    name = actionName,
                    inputs = {},
                    event = "",
                    animation = "",
                    sound = "",
                    cooldown = 1
                }
            end

            -- Заполняем данные в зависимости от типа атрибута
            if attrType == "Inputs" then
                -- Обрабатываем список вводов с обрезкой пробелов
                actionsTemp[actionName].inputs = {}
                for input in string.gmatch(attrValue, "[^,]+") do
                    table.insert(actionsTemp[actionName].inputs, trim(input))
                end
            elseif attrType == "Event" then
                actionsTemp[actionName].event = attrValue
            elseif attrType == "Animation" then
                actionsTemp[actionName].animation = attrValue
            elseif attrType == "Sound" then
                actionsTemp[actionName].sound = attrValue
            elseif attrType == "Cooldown" then
                actionsTemp[actionName].cooldown = tonumber(attrValue) or 1
            end
        end
    end

    -- Переносим из временного словаря в массив и actionsByName
    for actionName, actionData in pairs(actionsTemp) do
        -- table.insert(toolState.actions, actionData) -- корректно, actions - массив
        toolState.actions[#toolState.actions + 1] = actionData -- эквивалент table.insert, но явно
        toolState.actionsByName[actionName] = actionData
    end
end

-- Инициализация анимаций
local function initializeAnimations()
    toolState.animations = {}
    local animationsFolder = tool:FindFirstChild("Animations")
    if not animationsFolder then return end

    local humanoid = getHumanoid()
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    toolState.currentAnimator = animator

    for _, animObj in ipairs(animationsFolder:GetChildren()) do
        if animObj:IsA("Animation") then
            local animTrack = safeLoadAnimation(animator, animObj)
            if animTrack then
                toolState.animations[animObj.Name] = animTrack
            end
        end
    end
end

-- Инициализация звуков
local function initializeSounds()
    toolState.sounds = {}
    local soundsFolder = tool:FindFirstChild("Sounds")
    if not soundsFolder then return end

    for _, soundObj in ipairs(soundsFolder:GetChildren()) do
        if soundObj:IsA("Sound") then
            toolState.sounds[soundObj.Name] = soundObj
        end
    end
end

-- Инициализация удаленных событий
local function initializeRemotes()
    toolState.remotes = {}
    local remotesRoot = game:GetService("ReplicatedStorage"):FindFirstChild(REMOTES_FOLDER_NAME)
    if not remotesRoot then return end

    -- Используем actionsByName для корректного доступа
    for actionName, actionData in pairs(toolState.actionsByName) do
        if actionData.event and actionData.event ~= "" then
            toolState.remotes[actionName] = remotesRoot:FindFirstChild(actionData.event)
            if not toolState.remotes[actionName] then
                warn("Remote event not found: "..actionData.event)
            end
        end
    end
end

-- Обработчик действия
local function handleAction(actionName, inputState, inputObject)
    local action = toolState.actionsByName[actionName]
    if not action then
        warn("Action not found: "..tostring(actionName))
        return
    end

    -- Проверка кулдауна
    local currentTime = tick()
    if toolState.cooldowns[actionName] and currentTime - toolState.cooldowns[actionName] < action.cooldown then
        return
    end

    if inputState == Enum.UserInputState.Begin then
        -- Отправка события на сервер
        if toolState.remotes[actionName] then
            toolState.remotes[actionName]:FireServer()
        end

        -- Воспроизведение анимации
        if action.animation ~= "" and toolState.animations[action.animation] then
            toolState.animations[action.animation]:Play()
        end

        -- Воспроизведение звука
        if action.sound ~= "" then
            playSound(action.sound)
        end

        -- Установка кулдауна
        toolState.cooldowns[actionName] = currentTime

    elseif inputState == Enum.UserInputState.End then
        -- Остановка анимации при отпускании кнопки
        if action.animation ~= "" then
            stopAnimation(action.animation)
        end
    end
end

-- Привязка действий
local function bindActions()
    for i, actionData in ipairs(toolState.actions) do
        if type(actionData.inputs) ~= "table" then
            warn("Action '"..actionData.name.."' has invalid inputs type: "..tostring(actionData.inputs))
            continue
        end
        if #actionData.inputs > 0 then
            for j, input in ipairs(actionData.inputs) do
                local inputType

                -- Определение типа ввода
                if input == "MouseButton1" then
                    inputType = Enum.UserInputType.MouseButton1
                elseif input == "MouseButton2" then
                    inputType = Enum.UserInputType.MouseButton2
                else
                    inputType = Enum.KeyCode[input]
                    if not inputType then
                        warn("Invalid input type for action "..actionData.name..": "..input)
                        continue
                    end
                end

                -- Создаем уникальное имя для привязки
                local bindName = actionData.name.."_"..input.."_"..tool.Name

                -- Привязываем действие
                ContextActionService:BindAction(
                    bindName,
                    function(_, state, obj)
                        handleAction(actionData.name, state, obj)
                    end,
                    false,
                    inputType
                )

                -- Сохраняем привязку для последующей отвязки
                toolState.actionBindings[#toolState.actionBindings + 1] = bindName -- эквивалент table.insert
            end
        else
            warn("Action '"..actionData.name.."' has no inputs defined")
        end
    end
end

-- Отвязка действий
local function unbindActions()
    for _, bindName in ipairs(toolState.actionBindings) do
        ContextActionService:UnbindAction(bindName)
    end
    toolState.actionBindings = {}
end

-- Инициализация
initializeActions()
initializeSounds()
initializeRemotes()

-- События инструмента
tool.Equipped:Connect(function()
    initializeAnimations()
    playSound("Equip") -- Звук экипировки, если есть в папке Sounds
    bindActions()
end)

tool.Unequipped:Connect(function()
    -- Останавливаем все анимации
    for animName, _ in pairs(toolState.animations) do
        stopAnimation(animName)
    end

    unbindActions()
    toolState.currentAnimator = nil
end)

-- Инициализация при загрузке, если инструмент уже экипирован
if tool.Parent:IsA("Model") then
    local humanoid = getHumanoid()
    if humanoid and humanoid == game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        initializeAnimations()
        bindActions()
    end
end

