return {
    DefaultData = {
        coins = 100,
        gems = 10,
        level = 1,
        experience = 0,
        test = 11,
        test2 = 22,
        inventory = {},
        settings = {music = true, sfx = true}
    },
    
    DataStoreOptions = {
        Name = "PlayerData_v3",
        Scope = "global",
        SaveInterval = 60,
        Retries = 5,
        WriteTimeout = 3,
        QueueTimeout = 30,
        SaveTemporaryModifiers = false
    },
    
    ComputedFields = {
        jumpHeight = {base = 7},
        moveSpeed = {base = 16},
        defense = {base = 5},
        testAdd = {base = 1},
        testMultiplyBase = {base = 2},
        testMultiplyTotal = {base = 3},
        testAll = {base = 5},
        testRemove = {base = 5},
        testTemporary = {base = 5},
        testAutoRemove = {base = 5},
        testSave = {base = 5}
    }
}