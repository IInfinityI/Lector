local ServerStorage = game:GetService("ServerStorage")
local EventSystem = require(game:GetService("ReplicatedStorage").EventSystem)

EventSystem.Init(ServerStorage.EventConfig)  -- Путь до конфига

-- Обработчик ClientToServer
EventSystem.OnServer("PlayerJumped", function(player)
    print(`Игрок {player.Name} прыгнул!`)

    EventSystem.FireClient(player, "PlayerMoneyChanged", 100)
end)

-- Обработчики RPC
EventSystem.RegisterRPC("GetPlayerData", function(player, key)
    return `Данные игрока {player.Name}: {key} = 100`
end)

EventSystem.RegisterRPC("SetTimeOfDay", function(player, time)
    print(`Игрок {player.Name} установил время: {time}`)
    return true
end)

EventSystem.RegisterServerOnlyRPC("InternalDataUpdate", function(serverKey, data)
    return "success"
end)

print(EventSystem.CallServerOnlyRPC("InternalDataUpdate", 123, 22))
