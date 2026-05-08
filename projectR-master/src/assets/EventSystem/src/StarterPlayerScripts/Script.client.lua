-- LocalScript (в StarterPlayerScripts)
local EventSystem = require(game:GetService("ReplicatedStorage"):WaitForChild("EventSystem"))

-- Подписка на ServerToClient событие
EventSystem.OnClient("PlayerMoneyChanged", function(newMoney)
    print("Деньги изменены:", newMoney)
end)

-- Вызов ClientToServer события (например, при прыжке)
game:GetService("UserInputService").JumpRequest:Connect(function()
    EventSystem.FireServer("PlayerJumped")
end)

-- Тест RPC
local function testRPC()
    local data = EventSystem.CallRPC("GetPlayerData", "coins")
    print(data) -- Данные с сервера

    local timeSet = EventSystem.CallRPC("SetTimeOfDay", 12)
    print("Время установлено?", timeSet)
end

task.delay(5, testRPC) -- Вызов через 5 секунд