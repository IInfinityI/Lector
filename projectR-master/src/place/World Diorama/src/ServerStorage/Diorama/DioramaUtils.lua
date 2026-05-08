local MarketplaceService = game:GetService("MarketplaceService")

local DioramaUtils = {}

function DioramaUtils.color3ToTable(color)
    return { R = color.R, G = color.G, B = color.B }
end

function DioramaUtils.tableToColor3(tbl)
    if tbl and tbl.R and tbl.G and tbl.B then
        return Color3.new(tbl.R, tbl.G, tbl.B)
    end
    return Color3.new(1, 1, 1)
end

function DioramaUtils.materialToName(material)
    return material.Name
end

function DioramaUtils.nameToMaterial(name)
    local material = Enum.Material[name]
    return material or Enum.Material.SmoothPlastic
end

function DioramaUtils.getGamePassInfo(gamePassId)
    local success, gamePassInfo = pcall(function()
        return MarketplaceService:GetProductInfo(gamePassId, Enum.InfoType.GamePass)
    end)
    
    if success and gamePassInfo then
        return {
            Id = gamePassId,
            Name = gamePassInfo.Name,
            PriceInRobux = gamePassInfo.PriceInRobux or 0,
            Description = gamePassInfo.Description or "",
            IconImageAssetId = gamePassInfo.IconImageAssetId
        }
    end
    return nil
end

function DioramaUtils.hasGamePass(player, gamePassId)
    local success, ownsPass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
    end)
    return success and ownsPass or false
end

function DioramaUtils.formatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(num)
end

return DioramaUtils