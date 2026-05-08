return {
    ClientToServer = {
        PlayerJumped = {
            SecurityCheck = function(player) 
                return true 
            end,
        }
    },

    ServerToClient = {
        PlayerMoneyChanged = {}
    },

    ServerRPC = {
        GetPlayerData = {
            SecurityCheck = function(player, dataKey)
                local allowedKeys = {"coins", "level", "inventory"}
                return table.find(allowedKeys, dataKey) ~= nil 
            end
        },
        
        SetTimeOfDay = {
            SecurityCheck = function(player, time)
                return time >= 0 and time <= 24
            end
        }
    },
    
    ServerOnlyRPC = {
        InternalDataUpdate = {
            SecurityCheck = function(serverKey)
                return serverKey == "SECRET_KEY"
            end
        },
        
        ServerStatistics = {
            SecurityCheck = function()
                return true
            end
        }
    }
}