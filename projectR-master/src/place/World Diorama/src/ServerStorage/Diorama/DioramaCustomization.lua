local DioramaConfig = require(script.Parent:WaitForChild("DioramaConfig"))

local DioramaCustomization = {}

function DioramaCustomization.getColorFromName(colorName)
    return DioramaConfig.PREDEFINED_COLORS[colorName]
end

function DioramaCustomization.playerHasCustomization(player, category, itemId)
    local EventSystem = _G.AssetService and _G.AssetService:GetModule("EventSystem")
    if not EventSystem then
        warn("DioramaCustomization: EventSystem not available")
        return false
    end
    
    local success, has = pcall(function()
        return EventSystem.CallServerOnlyRPC("CheckCustomizationItem", player, category, itemId)
    end)
    return success and has or false
end

return DioramaCustomization