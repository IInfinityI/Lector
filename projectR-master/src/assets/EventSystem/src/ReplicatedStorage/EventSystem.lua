local EventSystem = {
    _initialized = false,
    _config = nil,
    _remotes = {},
    _bindables = {},
    _serverHandlers = {},
    _serverRPCs = {},
    _serverOnlyRPCs = {},
    _remoteFolderName = "EventSystemRemotes"
}

-- Вспомогательные функции
local function getService(serviceName)
    return game:GetService(serviceName)
end

local function isServer()
    return getService("RunService"):IsServer()
end

function EventSystem._getRemote(eventName)
    if EventSystem._remotes[eventName] then
        return EventSystem._remotes[eventName]
    end
    
    local rs = getService("ReplicatedStorage")
    local folder = rs:FindFirstChild(EventSystem._remoteFolderName)
    if folder then
        return folder:FindFirstChild(eventName)
    end
    return nil
end

function EventSystem._getServerOnlyRemote(eventName)
    if EventSystem._serverOnlyRPCs[eventName] then
        return EventSystem._serverOnlyRPCs[eventName].remote
    end
    
    local ss = getService("ServerStorage")
    local folder = ss:FindFirstChild(EventSystem._remoteFolderName)
    if folder then
        return folder:FindFirstChild("RPC_"..eventName)
    end
    return nil
end

function EventSystem._getBindable(eventName)
    if not EventSystem._bindables[eventName] then
        EventSystem._bindables[eventName] = Instance.new("BindableEvent")
    end
    return EventSystem._bindables[eventName]
end

-- Инициализация на сервере
if isServer() then
    function EventSystem.Init(configPath)
        if EventSystem._initialized then
            warn("[EventSystem] Уже инициализирован!")
            return
        end
        
        EventSystem._config = require(configPath)
        
        local rs = getService("ReplicatedStorage")
        local ss = getService("ServerStorage")
        
        -- Создаем папку для всех RemoteEvent'ов (ReplicatedStorage)
        local remoteFolder = rs:FindFirstChild(EventSystem._remoteFolderName)
        if not remoteFolder then
            remoteFolder = Instance.new("Folder")
            remoteFolder.Name = EventSystem._remoteFolderName
            remoteFolder.Parent = rs
        end
        
        -- Создаем папку для серверных RPC (ServerStorage)
        local serverOnlyFolder = ss:FindFirstChild(EventSystem._remoteFolderName)
        if not serverOnlyFolder then
            serverOnlyFolder = Instance.new("Folder")
            serverOnlyFolder.Name = EventSystem._remoteFolderName
            serverOnlyFolder.Parent = ss
        end
        
        -- Обрабатываем ClientToServer события (клиент → сервер)
        for eventName, eventConfig in pairs(EventSystem._config.ClientToServer or {}) do
            local remote = Instance.new("RemoteEvent")
            remote.Name = eventName
            remote.Parent = remoteFolder
            EventSystem._remotes[eventName] = remote
            
            remote.OnServerEvent:Connect(function(player, ...)
                if eventConfig.SecurityCheck and not eventConfig.SecurityCheck(player, ...) then
                    warn(string.format("[EventSystem] Security check failed for %s (player: %s)", 
                         eventName, player.Name))
                    return
                end
                if EventSystem._serverHandlers[eventName] then
                    EventSystem._serverHandlers[eventName](player, ...)
                end
            end)
        end
        
        -- Обрабатываем ServerToClient события (сервер → клиент)
        for eventName in pairs(EventSystem._config.ServerToClient or {}) do
            local remote = Instance.new("RemoteEvent")
            remote.Name = eventName
            remote.Parent = remoteFolder
            EventSystem._remotes[eventName] = remote
        end

        -- Обрабатываем RPC функции (ReplicatedStorage)
        for rpcName, rpcConfig in pairs(EventSystem._config.ServerRPC or {}) do
            local remoteFunction = Instance.new("RemoteFunction")
            remoteFunction.Name = "RPC_"..rpcName
            remoteFunction.Parent = remoteFolder
            
            EventSystem._serverRPCs[rpcName] = {
                config = rpcConfig,
                handler = nil,
                remote = remoteFunction
            }
            
            remoteFunction.OnServerInvoke = function(player, ...)
                local rpc = EventSystem._serverRPCs[rpcName]
                if not rpc.handler then
                    warn("[EventSystem] No handler for RPC:", rpcName)
                    return nil
                end
                
                if rpc.config.SecurityCheck and not rpc.config.SecurityCheck(player, ...) then
                    warn(string.format("[EventSystem] Security check failed for RPC %s (player: %s)", 
                         rpcName, player.Name))
                    return nil
                end
                
                return rpc.handler(player, ...)
            end
        end
        
        -- Обрабатываем ServerOnly RPC функции (ServerStorage)
        for rpcName, rpcConfig in pairs(EventSystem._config.ServerOnlyRPC or {}) do
            local remoteFunction = Instance.new("RemoteFunction")
            remoteFunction.Name = "RPC_"..rpcName
            remoteFunction.Parent = serverOnlyFolder
            
            EventSystem._serverOnlyRPCs[rpcName] = {
                config = rpcConfig,
                handler = nil,
                remote = remoteFunction
            }
            
            remoteFunction.OnServerInvoke = function(...)
                local rpc = EventSystem._serverOnlyRPCs[rpcName]
                if not rpc.handler then
                    warn("[EventSystem] No handler for ServerOnly RPC:", rpcName)
                    return nil
                end
                
                if rpc.config.SecurityCheck and not rpc.config.SecurityCheck(...) then
                    warn(string.format("[EventSystem] Security check failed for ServerOnly RPC %s", rpcName))
                    return nil
                end
                
                return rpc.handler(...)
            end
        end

        EventSystem._initialized = true
        print("[EventSystem] Инициализирован!")
    end
else
    function EventSystem.Init()
        local rs = getService("ReplicatedStorage")
        if not rs:FindFirstChild(EventSystem._remoteFolderName) then
            warn("[EventSystem] Папка с событиями не найдена в ReplicatedStorage!")
        end
    end
end

-- Серверные функции
if isServer() then
    function EventSystem.FireClient(player, eventName, ...)
        local remote = EventSystem._getRemote(eventName)
        if remote then
            remote:FireClient(player, ...)
        else
            warn("[EventSystem] RemoteEvent не найден:", eventName)
        end
    end

    function EventSystem.FireAllClients(eventName, ...)
        local remote = EventSystem._getRemote(eventName)
        if remote then
            remote:FireAllClients(...)
        else
            warn("[EventSystem] RemoteEvent не найден:", eventName)
        end
    end

    function EventSystem.OnServer(eventName, callback)
        EventSystem._serverHandlers[eventName] = callback
    end

    function EventSystem.RegisterRPC(rpcName, handler)
        if EventSystem._serverRPCs[rpcName] then
            EventSystem._serverRPCs[rpcName].handler = handler
        else
            warn("[EventSystem] RPC не найден:", rpcName)
        end
    end
    
    function EventSystem.RegisterServerOnlyRPC(rpcName, handler)
        if EventSystem._serverOnlyRPCs[rpcName] then
            EventSystem._serverOnlyRPCs[rpcName].handler = handler
        else
            warn("[EventSystem] ServerOnly RPC не найден:", rpcName)
        end
    end
end

-- Клиентские функции
if not isServer() then
    function EventSystem.FireServer(eventName, ...)
        local remote = EventSystem._getRemote(eventName)
        if remote then
            remote:FireServer(...)
        else
            warn("[EventSystem] RemoteEvent не найден:", eventName)
        end
    end

    function EventSystem.OnClient(eventName, callback)
        local remote = EventSystem._getRemote(eventName)
        if remote then
            remote.OnClientEvent:Connect(callback)
        else
            warn("[EventSystem] RemoteEvent не найден:", eventName)
        end
    end

    function EventSystem.FireLocal(eventName, ...)
        EventSystem._getBindable(eventName):Fire(...)
    end

    function EventSystem.OnLocal(eventName, callback)
        EventSystem._getBindable(eventName).Event:Connect(callback)
    end
end

-- Общие функции
function EventSystem.CallRPC(rpcName, ...)
    if isServer() then
        if EventSystem._serverRPCs[rpcName] then
            local rpc = EventSystem._serverRPCs[rpcName]
            if rpc.handler then
                return rpc.handler(nil, ...)
            end
            return nil
        end
        
        if EventSystem._serverOnlyRPCs[rpcName] then
            local rpc = EventSystem._serverOnlyRPCs[rpcName]
            if rpc.handler then
                return rpc.handler(...)
            end
            return nil
        end
        
        warn("[EventSystem] RPC не найден:", rpcName)
        return nil
    else
        local remote = EventSystem._getRemote("RPC_"..rpcName)
        if remote then
            return remote:InvokeServer(...)
        else
            warn("[EventSystem] RPC функция не найдена:", rpcName)
            return nil
        end
    end
end

-- Серверные вызовы ServerOnly RPC
if isServer() then
    function EventSystem.CallServerOnlyRPC(rpcName, ...)
        local rpc = EventSystem._serverOnlyRPCs[rpcName]
        if rpc then
            if rpc.handler then
                return rpc.handler(...)
            else
                warn("[EventSystem] No handler registered for ServerOnly RPC:", rpcName)
                return nil
            end
        else
            warn("[EventSystem] ServerOnly RPC не найден:", rpcName)
            return nil
        end
    end
end

return EventSystem