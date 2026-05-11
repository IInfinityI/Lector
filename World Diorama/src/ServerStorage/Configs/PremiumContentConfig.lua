return {
    GamePasses = {
        {
            Name = "Season 1 Pass",
            DisplayName = "Season 1 Pass",
            Id = 1339362482,
            Price = 75,
            Bonus = {
                Gold = 750,
                Modifiers = {
                    {
                        Type = "GoldPerMinuteMultiplier",
                        Operation = "MultiplyBase", 
                        Value = 1.02
                    },
                    {
                        Type = "MaxDioramas",
                        Operation = "Add", 
                        Value = 1
                    }
                }
            }
        },
        {
            Name = "CollectIncome",
            DisplayName = "CollectIncome",
            Id = 1760121803,
            Price = 100
        },
        {
            Name = "quests", --при изменении поменять отправку события GamepassOfferByName
            DisplayName = "quests",
            Id = 1800701349,
            Price = 100
        }
    },

    DeveloperProducts = {
        {
            Name = "Gold",
            DisplayName = "Gold Pack (1000)",
            Id = 3578725402,
            Price = 100,
            Bonus = {
                Gold = 1000
            }
        }
    },

    PremiumBonuses = {
        {
            Name = "PremiumRewards",
            DisplayName = "Premium bonuses",
            Bonus = {
                Gold = 200,
                Modifiers = {
                    {
                        Type = "GoldPerMinuteMultiplier",
                        Operation = "MultiplyBase", 
                        Value = 1.02
                    }
                }
            }
        }
    },
    
    DailyRewards = {
        Settings = {
            Enabled = true,
            EnablePostCompletionRewards = true,
            ResetAfterCompletion = false,
            AllowSkippingDays = false
        },
        
        RewardGroups = {
            Default = {
                AccessType = "All",
                CycleLength = 7,
                Rewards = {
                    [1] = { Gold = 100 },
                    [2] = { PurchaseBanTickets = 1 },
                    [3] = { Gold = 150 },
                    [4] = { PurchaseBanTickets = 1 },
                    [5] = { Gold = 250 },
                    [6] = { PurchaseBanTickets = 1 },
                    [7] = { Gold = 200, PurchaseBanTickets = 1 }
                },
                PostCompletionReward = { 
                    Modifiers = {
                        {
                            Type = "GoldPerMinuteMultiplier",
                            Operation = "MultiplyBase", 
                            Value = 1.02
                        }
                    }
                }
            },
            Premium = {
                AccessType = "GamePass",
                RequiredGamePass = "Season 1 Pass",
                CycleLength = 7,
                Rewards = {
                    [1] = { Gold = 100 },
                    [2] = { PurchaseBanTickets = 1 },
                    [3] = { Gold = 150 },
                    [4] = { PurchaseBanTickets = 1 },
                    [5] = { Gold = 250 },
                    [6] = { PurchaseBanTickets = 1 },
                    [7] = { Gold = 1000, PurchaseBanTickets = 2 }
                },
                PostCompletionReward = { 
                    Modifiers = {
                        {
                            Type = "GoldPerMinuteMultiplier",
                            Operation = "MultiplyBase", 
                            Value = 1.02
                        }
                    } 
                }
            }
        }
    },
    
    Achievements = {
        {
            Name = "FirstSteps",
            DisplayName = "First Steps",
            Description = "Enter the game for the first time",
            BadgeId = 11056884442015,
            Rewards = {
                Gold = 1000
            },
            Category = "Beginning",
            Difficulty = "Easy"
        },
        {
            Name = "Backstage",
            DisplayName = "Backstage",
            Description = "Get backstage",
            BadgeId = 654584443537830,
            Rewards = {
                Gold = 1000
            },
            Category = "Exploration",
            Difficulty = "Easy"
        },
        {
            Name = "TutorialComplete",
            DisplayName = "Tutorial Complete",
            Description = "Complete the tutorial",
            BadgeId = 4326835810346776,
            Rewards = {
                Gold = 1000
            },
            Category = "Beginning",
            Difficulty = "Easy"
        },
        {
            Name = "FirstDiorama",
            DisplayName = "First Diorama",
            Description = "Buy your first diorama",
            BadgeId = 3689675177140657,
            Rewards = {
                Gold = 1000
            },
            Category = "Progress",
            Difficulty = "Easy"
        }
    }
}