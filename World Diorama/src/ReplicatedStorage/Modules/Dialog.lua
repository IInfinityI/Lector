-- Модуль Dialog (поместите в ReplicatedStorage или в Script внутри StarterPlayerScripts)
local Dialog = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Показывает диалог
-- @param options table: {
--   type: "warning" | "error" | "confirm",
--   title: string,
--   message: string,
--   onConfirm: function() (вызывается при нажатии ОК)
-- }
function Dialog:Show(options)
    local dialogType = options.type or "warning"
    local title = options.title or ""
    local message = options.message or ""
    local onConfirm = options.onConfirm or function() end
    
    -- Проверяем существование GUI
    local gui = playerGui:FindFirstChild("DialogGui")
    if not gui then
        warn("DialogGui not found in StarterGui! Please create the GUI structure first.")
        return
    end
    
    -- Получаем все необходимые элементы
    local overlay = gui:FindFirstChild("Overlay")
    local dialogFrame = gui:FindFirstChild("DialogFrame")
    local icon = dialogFrame and dialogFrame:FindFirstChild("Header") and dialogFrame.Header:FindFirstChild("Icon")
    local titleLabel = dialogFrame and dialogFrame:FindFirstChild("Header") and dialogFrame.Header:FindFirstChild("Title")
    local messageLabel = dialogFrame and dialogFrame:FindFirstChild("Message")
    local okButton = dialogFrame and dialogFrame:FindFirstChild("Buttons") and dialogFrame.Buttons:FindFirstChild("OKButton")
    local cancelButton = dialogFrame and dialogFrame:FindFirstChild("Buttons") and dialogFrame.Buttons:FindFirstChild("CancelButton")
    local closeButton = dialogFrame and dialogFrame:FindFirstChild("Header") and dialogFrame.Header:FindFirstChild("CloseButton")
    
    -- Проверяем наличие всех необходимых элементов
    if not overlay or not dialogFrame or not icon or not titleLabel or not messageLabel or not okButton or not closeButton then
        warn("DialogGui structure is incomplete! Required elements: Overlay, DialogFrame, Header, Icon, Title, Message, OKButton, CloseButton")
        return
    end
    
    -- Устанавливаем содержимое
    titleLabel.Text = title
    messageLabel.Text = message
    
    -- Настраиваем иконку в зависимости от типа
    if dialogType == "warning" then
        icon.Text = "⚠️"
    elseif dialogType == "error" then
        icon.Text = "❌"
    elseif dialogType == "confirm" then
        icon.Text = "❓"
    end
    
    -- Управляем видимостью кнопки отмены
    if cancelButton then
        if dialogType == "confirm" then
            cancelButton.Visible = true
        else
            cancelButton.Visible = false
        end
    end
    
    -- Функция закрытия диалога
    local function closeDialog()
        gui.Enabled = false
        overlay.Visible = false
        dialogFrame.Visible = false
    end
    
    -- Обработчик нажатия на ОК
    local function onOk()
        onConfirm()
        closeDialog()
    end
    
    -- Обработчик отмены (закрытие без вызова onConfirm)
    local function onCancel()
        closeDialog()
    end
    
    -- Сохраняем старые обработчики, если они были
    local oldOkConnection = okButton.MouseButton1Click:Connect(function() end)
    local oldCancelConnection = cancelButton.MouseButton1Click:Connect(function() end)
    local oldCloseConnection = closeButton.MouseButton1Click:Connect(function() end)
    
    if oldOkConnection then oldOkConnection:Disconnect() end
    if oldCloseConnection then oldCloseConnection:Disconnect() end
    
    -- Назначаем новые обработчики
    local okConnection = okButton.MouseButton1Click:Connect(onOk)
    local closeConnection = closeButton.MouseButton1Click:Connect(onCancel)
    
    if cancelButton then
        if oldCancelConnection then oldCancelConnection:Disconnect() end
        local cancelConnection = cancelButton.MouseButton1Click:Connect(onCancel)
        -- Сохраняем все соединения для возможной очистки
        okConnection = okConnection
        closeConnection = closeConnection
        cancelConnection = cancelConnection
    end
    
    -- Показываем диалог
    gui.Enabled = true
    overlay.Visible = true
    dialogFrame.Visible = true
    
    -- Возвращаем функции для ручного управления (опционально)
    return {
        close = closeDialog,
        isVisible = function() return dialogFrame.Visible end
    }
end

return Dialog