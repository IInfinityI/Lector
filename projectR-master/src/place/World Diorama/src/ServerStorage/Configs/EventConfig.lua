return {
    Storage = {
        Remotes = "Remotes",
    },

    ClientToServer = {
        ShowDioramaGUI = {
            SecurityCheck = function(player, dioramaId)
                return type(dioramaId) == "string" and #dioramaId >= 0
            end
        },
        SubscribeToDiorama = {
            SecurityCheck = function(player, dioramaId)
                return true
            end
        },
        UnsubscribeFromDiorama = {
            SecurityCheck = function(player, dioramaId)
                return true
            end
        },
        PurchaseDiorama = {
            SecurityCheck = function(player, dioramaId)
                return true
            end
        },
        CollectIncome = {
            SecurityCheck = function(player, dioramaId)
                return true
            end
        },
        ChangeDioramaSpot = {
            SecurityCheck = function(player, dioramaId, spotNumber)
                return true
            end
        },
        SetDioramaGamePass = {
            SecurityCheck = function(player, dioramaId, gamePassId)
                return dioramaId >= 0 and gamePassId > 0
            end
        },
        ChangeDioramaFrameType = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        ChangeDioramaStandType = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        ChangeDioramaWallColor = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        ChangeDioramaWallMaterial = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        RemoveDioramaGamePass = {
            SecurityCheck = function(player, dioramaId)
                return dioramaId >= 0
            end
        },
        PurchaseDioramaWithGamePass = {
            SecurityCheck = function(player, dioramaId)
                return dioramaId >= 0
            end
        },
        QuickSellDiorama = {
            SecurityCheck = function(player, dioramaId)
                return true
            end
        },
        CheckGamePassOwnership = {
            SecurityCheck = function(player, gamePassId)
                return true
            end
        },
        SubscribeToGoldGUI = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        SubscribeToUpgradesGUI = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        SubscribeToLevelGUI = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        SubscribeToQuestsGUI = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        VoteForDiorama = {
            SecurityCheck = function(player, dioramaId, voteType)
                return dioramaId >= 0 and (voteType == "up" or voteType == "down")
            end
        },
        UnsubscribeFromGoldGUI = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        UnsubscribeFromUpgradesGUI = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        UnsubscribeFromLevelGUI = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        UnsubscribeFromQuestsGUI = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        CollectGold = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        UpgradeSkill = {
            SecurityCheck = function(player, skillType)
                return player and player:IsA("Player")
                       and type(skillType) == "string"
                       and #skillType > 0
            end
        },
        Prestige = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        ClaimQuest = {
            SecurityCheck = function(player, questId)
                return player and player:IsA("Player")
                       and type(questId) == "string"
                       and #questId > 0
            end
        },
        GetQuestsData = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetUpgradesData = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        UpgradeSkillRequest = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetLevelData = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        RefreshQuests = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        SkipQuest = {
            SecurityCheck = function(player, questId)
                return player and player:IsA("Player")
            end
        },
        CollectQuestItem = {
            SecurityCheck = function(player, data)
                return player and player:IsA("Player")
            end
        },
        PurchaseProduct = {
            SecurityCheck = function(player, questId)
                return player and player:IsA("Player")
            end
        },
        PurchaseGamePass = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        BanDioramaPurchase = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        ExtendPurchaseBan = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        SaveSettings = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
    },

    ServerToClient = {
        UpdateGold = {},
        PurchaseResult = {},
        CollectResult = {},
        QuickSellResult = {},
        DioramaDataUpdated = {},
        SetGamePassResult = {},
        RemoveGamePassResult = {},
        PurchaseWithGamePassResult = {},
        GamePassSaleCompleted = {},
        ChangeSpotResult = {},
        PurchaseDiorama = {},
        DioramaIncomeUpdated = {},
        VoteResult = {},
        VoteDataUpdated = {},
        ChangeFrameTypeResult = {},
        ChangeStandTypeResult = {},
        ChangeWallColorResult = {},
        ChangeWallMaterialResult = {},
        
        -- Gold GUI события
        GoldGUIInitialData = {},
        GoldGUIUpdate = {},
        PlayerDioramasUpdated = {},
        
        -- Upgrades GUI события
        UpgradesGUIInitialData = {},
        UpgradesGUIUpdate = {},
        UpgradeSkillResponse = {},
        LevelRewardReceived = {},
        
        -- Level GUI события
        LevelGUIInitialData = {},
        LevelGUIUpdate = {},
        
        -- Quests GUI события
        QuestsGUIInitialData = {},
        QuestsGUIUpdate = {},
        QuestsRefreshed = {},
        RefreshQuestsResponse = {},
        ClaimQuestResponse = {},
        SkipQuestResponse = {},
        
        -- Системные события
        LevelUp = {},
        GoldCollected = {},
        SkillUpgraded = {},
        PrestigeComplete = {},
        QuestProgress = {},
        QuestsUpdated = {},
        AutoCollectUnlocked = {},
        CollectItemError = {},
        
        -- GUI события
        QuestsDataUpdated = {},
        UpgradesDataUpdated = {},
        LevelDataUpdated = {},
        
        ActivateQuestItems = {},
        PendingGoldReceived = {},
        ItemCollected = {},
        ShowDialogGUI = {},
        GamepassOfferByName = {},

        BanPurchaseResult = {},
        ExtendBanResult = {},
        AddBanTicketsResult = {},
        DioramaOwnershipLost = {},
        ClaimDailyRewardEvent = {},
    },
    
    ServerRPC = {
        GetPlayerGold = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetPlayerStats = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        CollectGold = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetGameSystems = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetQuestsData = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetUpgradesData = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetDioramaData = {
            SecurityCheck = function(player, dioramaId)
                return true
            end
        },
        GetPlayerDioramas = {
            SecurityCheck = function(player, dioramaId)
                return true
            end
        },
        GetLevelRewardsData = {
            SecurityCheck = function(player, dioramaId)
                return true
            end
        },
        ClaimLevelReward = {
            SecurityCheck = function(player, dioramaId)
                return true
            end
        },
        GetLevelData = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetShopData = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        CheckOwnership = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },                     
        GetPlayerPremiumStatus = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetPurchaseBanTickets = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetDioramaLimit = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
		},
		GetTutorialCompleted = {
			SecurityCheck = function(player)
				return player and player:IsA("Player")
			end
		},
		SetTutorialCompleted = {
			SecurityCheck = function(player)
				return player and player:IsA("Player")
			end
		},
        GetSavedSettings = {
			SecurityCheck = function(player)
				return player and player:IsA("Player")
			end
		},
        GetDailyRewardsData = {
			SecurityCheck = function(player)
				return player and player:IsA("Player")
			end
		},
        ClaimDailyReward = {
			SecurityCheck = function(player)
				return player and player:IsA("Player")
			end
		},
        Prestige = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetDonationBonusMultiplier = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
    },
    
    ServerOnlyRPC = {
        GetPlayerGold = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        UpdatePlayerGold = {
            SecurityCheck = function(player, amount, reason)
                return player and player:IsA("Player") 
                       and type(amount) == "number"
                       and (not reason or type(reason) == "string")
            end
        },
        GetPlayerData = {
            SecurityCheck = function(player, keys)
                return player and player:IsA("Player")
                       and (not keys or type(keys) == "table")
            end
        },
        CheckCustomizationItem = {
            SecurityCheck = function(player, keys)
                return player and player:IsA("Player")
            end
        },
        GetCustomizationItems = {
            SecurityCheck = function(player, keys)
                return player and player:IsA("Player")
            end
        },
        UpgradeSkill = {
            SecurityCheck = function(player, skillType)
                return player and player:IsA("Player")
                       and type(skillType) == "string"
            end
        },
        ClaimQuest = {
            SecurityCheck = function(player, questId)
                return player and player:IsA("Player")
                       and type(questId) == "string"
            end
        },
        RefreshQuests = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        DioramaInteraction = {
            SecurityCheck = function(player, questId)
                return player and player:IsA("Player")
            end
        },
        GetPurchaseBanTickets = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        UsePurchaseBanTicket = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        AddPurchaseBanTickets = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
        GetMaxDioramas = {
            SecurityCheck = function(player)
                return player and player:IsA("Player")
            end
        },
    }
}