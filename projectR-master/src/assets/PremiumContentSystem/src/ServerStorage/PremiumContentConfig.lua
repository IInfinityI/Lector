return {
    GamePasses = {
        {
            Name = "Test",
            DisplayName = "VIP Статус",
            Id = 1339362482,
            Price = 52,
            Bonus = {
                PermanentUnlock = "VIP_Access",
                Currency = 500,
                XP_Multiplier = 1.5,
                CustomTag = "[VIP]",
                Modifiers = {
                    {
                        Type = "MovementSpeed",
                        Operation = "MultiplyBase",
                        Value = 1.15
                    },
                    {
                        Type = "JumpHeight", 
                        Operation = "Add",
                        Value = 10
                    }
                }
            }
        },
        {
            Name = "Premium_Status",
            DisplayName = "Премиум Статус",
            Id = 1339362483,
            Price = 75,
            Bonus = {
                Currency = 750,
                XP_Multiplier = 1.8,
                CustomTag = "[PREMIUM]",
                Modifiers = {
                    {
                        Type = "MovementSpeed",
                        Operation = "MultiplyBase", 
                        Value = 1.2
                    },
                    {
                        Type = "Damage",
                        Operation = "MultiplyBase",
                        Value = 1.1
                    },
                    {
                        Type = "MaxHealth",
                        Operation = "Add",
                        Value = 25
                    }
                }
            }
        }
    },

    DeveloperProducts = {
        {
            Name = "Money",
            DisplayName = "Набор монет (1000)",
            Id = 3344347083,
            Price = 100,
            Bonus = {
                Currency = 1000
            }
        },
        {
            Name = "Money_Pack_Large",
            DisplayName = "Большой набор монет (5000)",
            Id = 3344347084,
            Price = 450,
            Bonus = {
                Currency = 5000
            }
        },
        {
            Name = "Speed_Boost",
            DisplayName = "Ускорение скорости",
            Id = 3344347085,
            Price = 150,
            Bonus = {
                Modifiers = {
                    {
                        Type = "MovementSpeed",
                        Operation = "MultiplyBase",
                        Value = 1.25,
                        Duration = 3600 -- 1 час в секундах
                    }
                }
            }
        }
    },

    PremiumBonuses = {
        {
            Name = "PremiumRewards",
            DisplayName = "Премиум бонусы",
            Bonus = {
                DailyCoins = 200,
                XP_Multiplier = 1.3,
                ExtraInventorySlots = 5,
                Modifiers = {
                    {
                        Type = "Luck",
                        Operation = "Add",
                        Value = 5
                    },
                    {
                        Type = "CoinMultiplier",
                        Operation = "MultiplyBase",
                        Value = 1.2
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
                    [1] = { 
                        Currency = 100, 
                        XP = 51, 
                        Item = "CommonChest",
                        Modifiers = {
                            {
                                Type = "MaxHealth",
                                Operation = "MultiplyBase",
                                Value = 1.1,
                                Duration = 86400 -- 24 часа
                            }
                        }
                    },
                    [2] = { 
                        Currency = 150, 
                        XP = 75 
                    },
                    [3] = { 
                        Currency = 200, 
                        XP = 100, 
                        Item = "UncommonChest",
                        Modifiers = {
                            {
                                Type = "Damage",
                                Operation = "Add",
                                Value = 5,
                                Duration = 7200 -- 2 часа
                            }
                        }
                    },
                    [4] = { 
                        Currency = 250, 
                        XP = 125 
                    },
                    [5] = { 
                        Currency = 300, 
                        XP = 150, 
                        Item = "RareChest",
                        Modifiers = {
                            {
                                Type = "MovementSpeed",
                                Operation = "MultiplyBase",
                                Value = 1.16,
                                Duration = 10800 -- 3 часа
                            }
                        }
                    },
                    [6] = { 
                        Currency = 350, 
                        XP = 175 
                    },
                    [7] = { 
                        Currency = 500, 
                        XP = 250, 
                        Item = "EpicChest", 
                        IsMajorReward = true,
                        Modifiers = {
                            {
                                Type = "Luck",
                                Operation = "Add",
                                Value = 10,
                                Duration = 43200 -- 12 часов
                            }
                        }
                    }
                },
                PostCompletionReward = { 
                    Currency = 100, 
                    XP = 50 
                }
            },
            
            VIP = {
                AccessType = "Premium",
                RequiredGamePass = "Test",
                CycleLength = 7,
                Rewards = {
                    [1] = { 
                        Currency = 300, 
                        XP = 150, 
                        Item = "RareChest",
                        Modifiers = {
                            {
                                Type = "MaxHealth",
                                Operation = "MultiplyBase",
                                Value = 1.2,
                                Duration = 86400
                            }
                        }
                    },
                    [2] = { 
                        Currency = 350, 
                        XP = 175 
                    },
                    [3] = { 
                        Currency = 400, 
                        XP = 200, 
                        Item = "EpicChest",
                        Modifiers = {
                            {
                                Type = "Damage",
                                Operation = "Add",
                                Value = 8,
                                Duration = 10800
                            }
                        }
                    },
                    [4] = { 
                        Currency = 450, 
                        XP = 225 
                    },
                    [5] = { 
                        Currency = 500, 
                        XP = 250, 
                        Item = "LegendaryChest",
                        Modifiers = {
                            {
                                Type = "MovementSpeed",
                                Operation = "MultiplyBase",
                                Value = 1.2,
                                Duration = 14400
                            }
                        }
                    },
                    [6] = { 
                        Currency = 550, 
                        XP = 275 
                    },
                    [7] = { 
                        Currency = 1000, 
                        XP = 500, 
                        Item = "VIPExclusiveChest", 
                        IsMajorReward = true,
                        Modifiers = {
                            {
                                Type = "AllStats",
                                Operation = "MultiplyBase",
                                Value = 1.1,
                                Duration = 86400
                            }
                        }
                    }
                },
                PostCompletionReward = { 
                    Currency = 200, 
                    XP = 100 
                }
            },
            
            Premium = {
                AccessType = "Premium",
                CycleLength = 7,
                Rewards = {
                    [1] = { 
                        Currency = 200, 
                        XP = 100, 
                        Item = "UncommonChest",
                        Modifiers = {
                            {
                                Type = "CoinMultiplier",
                                Operation = "MultiplyBase",
                                Value = 1.17,
                                Duration = 86400
                            }
                        }
                    },
                    [2] = { 
                        Currency = 250, 
                        XP = 125 
                    },
                    [3] = { 
                        Currency = 300, 
                        XP = 150, 
                        Item = "RareChest",
                        Modifiers = {
                            {
                                Type = "Luck",
                                Operation = "Add",
                                Value = 8,
                                Duration = 21600
                            }
                        }
                    },
                    [4] = { 
                        Currency = 350, 
                        XP = 175 
                    },
                    [5] = { 
                        Currency = 400, 
                        XP = 200, 
                        Item = "EpicChest",
                        Modifiers = {
                            {
                                Type = "MaxHealth",
                                Operation = "MultiplyBase",
                                Value = 1.25,
                                Duration = 86400
                            }
                        }
                    },
                    [6] = { 
                        Currency = 450, 
                        XP = 225 
                    },
                    [7] = { 
                        Currency = 700, 
                        XP = 350, 
                        Item = "PremiumExclusiveChest", 
                        IsMajorReward = true,
                        Modifiers = {
                            {
                                Type = "AllStats",
                                Operation = "MultiplyBase",
                                Value = 1.18,
                                Duration = 172800 -- 48 часов
                            }
                        }
                    }
                },
                PostCompletionReward = { 
                    Currency = 150, 
                    XP = 75 
                }
            }
        }
    },
    
    Achievements = {
        {
            Name = "FirstSteps",
            DisplayName = "Первые шаги",
            Description = "Войдите в игру впервые",
            BadgeId = 285695783016936,
            Rewards = {
                Currency = 100,
                XP = 54,
                Modifiers = {
                    {
                        Type = "MaxHealth",
                        Operation = "MultiplyBase",
                        Value = 1.05,
                        Duration = 3600 -- 1 час
                    }
                }
            },
            Category = "Начало",
            Difficulty = "Легкий"
        },
        {
            Name = "Veteran",
            DisplayName = "Ветеран",
            Description = "Играйте в течение 30 дней",
            BadgeId = 2124869037,
            Rewards = {
                Currency = 500,
                XP = 250,
                Item = "VeteranChest",
                Modifiers = {
                    {
                        Type = "AllStats",
                        Operation = "MultiplyBase",
                        Value = 1.08,
                        Duration = 2592000 -- 30 дней
                    }
                }
            },
            Category = "Время",
            Difficulty = "Средний"
        },
        {
            Name = "Explorer",
            DisplayName = "Исследователь",
            Description = "Посетите все локации на карте",
            BadgeId = 709619331891711,
            Rewards = {
                Currency = 750,
                XP = 400,
                Item = "ExplorerBackpack",
                Modifiers = {
                    {
                        Type = "MovementSpeed",
                        Operation = "MultiplyBase",
                        Value = 1.1
                    }
                }
            },
            Category = "Исследование",
            Difficulty = "Средний"
        }
    }
}