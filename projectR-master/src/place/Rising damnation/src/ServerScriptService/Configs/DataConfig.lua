return {
    DefaultData = {
        CommonEssence = 0,
        IncommonEssence = 0,
        RareEssence = 0,
        EpicEssence = 0,
        LegendaryEssence = 0,
        MythicalEssence = 0,
        Coins = 0,
        Inventory = {},
        EquippedItem = {}
    },
    
    ComputedFields = {
        JumpHeight = {base = 7},
        MovementSpeed = {base = 16},
        JumpsNumber = {base = 1},
        MaxWeight = {base = 50},
        SphereSize = {base = 10},
    },

    DataStoreOptions = {
        Name = "PlayerDataTest_V2",
        Scope = "global",
        SaveInterval = 60,
        Retries = 5,
        WriteTimeout = 3,
        QueueTimeout = 5
    }
}