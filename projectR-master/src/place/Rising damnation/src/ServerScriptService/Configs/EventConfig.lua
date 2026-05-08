return {
    Storage = {
        Remotes = "Emotes",
    },

    ClientToServer = {
        BuyAccessory = {},
        EquipAccessory = {},
        UnequipAccessory = {},
        UpgradeAccessory = {}
    },

    ServerToClient = {
        OpenShopUI = {},
        OpenUpgradeUI = {},
        ShowEssenceCollection = {},
        ShowOverloadNotification = {}
    },

    ServerRPC = {
        GetShopData = { SecurityCheck = function() return true end },
        GetAccessoryState = { SecurityCheck = function() return true end },
        GetEquippedUpgradesInfo = { SecurityCheck = function() return true end }
    },
    
    ServerOnlyRPC = {
        EssenceTouched = { SecurityCheck = function() return true end },
        SellAllEssences = { SecurityCheck = function() return true end }
    }
}