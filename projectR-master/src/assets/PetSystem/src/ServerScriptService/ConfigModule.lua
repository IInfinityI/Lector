return {
    DefaultData = {
        Coins = 100
    },
    
    DataStoreOptions = {
        Name = "PlayerData_v3",
        Scope = "global",
        SaveInterval = 60,
        Retries = 5,
        WriteTimeout = 3,
        QueueTimeout = 30
    },
    
    ComputedFields = {
        JumpHeight = {base = 7},
        MovementSpeed = {base = 16},
        Defense = {base = 5},
        MaxHealth = {base = 100},
        Damage = {base = 5}
    }
}