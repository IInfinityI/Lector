-- DataManagerConfig (например, в ReplicatedStorage.Configs)
return {
    DefaultData = {
        Gold = 1000000,
        Level = 99,
        Experience = 0,
        PrestigeLevel = 10,
        LastCollectTime = 0,
        CollectedGold = 0,
        SkillPoints = 0,
        CompletedQuests = 0,
        DailyQuests = {},
        QuestRefreshTime = 0,
        PurchaseBanTickets = 50,

        -- Уровни улучшений (были просто значениями)
        Upgrades = {
            GoldPerMinuteLevel = 0,
            StorageCapacityLevel = 0,
            DoubleChanceLevel = 0,
            QuestBonusLevel = 0,
            AutoCollect = false,
            CriticalChanceLevel = 0,
            CriticalMultiplierLevel = 0,
            QuestSlotsLevel = 1
        },
        Stats = {
            TotalGoldEarned = 0,
            TotalPrestigeGold = 0,
            TotalQuestsCompleted = 0,
            MaxLevelReached = 1,
            PlayTime = 0
        },
        LastLogin = os.time(),
        PrestigeBonuses = {},
        TutorialCompleted = false,
    },
    
    ComputedFields = {
        GoldPerMinuteMultiplier = { base = 1 },
        StorageCapacityMultiplier = { base = 1 },
        DoubleChanceMultiplier = { base = 1 },
        QuestBonusMultiplier = { base = 1 },
        CriticalChanceMultiplier = { base = 1 },
        CriticalMultiplierMultiplier = { base = 1 },
        ExperienceMultiplier = { base = 1 },
        GoldMultiplier = { base = 1 },
        DioramaGoldMultiplier = { base = 1 },
        DonationBonusMultiplier = { base = 1 },
        StatsMultiplier = { base = 1 },
        
        MaxDioramas = { base = 6 }
    },

    DataStoreOptions = {
        Name = "Test_v4.3",
        Scope = "global",
        SaveInterval = 60,
        Retries = 5,
        WriteTimeout = 3,
        QueueTimeout = 5,
        SaveTemporaryModifiers = false
    }
}