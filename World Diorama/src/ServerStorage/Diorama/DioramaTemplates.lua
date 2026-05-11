local ServerStorage = game:GetService("ServerStorage")

local DioramaTemplates = {}

function DioramaTemplates.getTemplateSurfaceGui()
    local dioramaPart = ServerStorage:FindFirstChild("DioramaPart")
    if not dioramaPart then return nil end
    local infoPad = dioramaPart:FindFirstChild("InfoPad")
    if not infoPad then return nil end
    return infoPad:FindFirstChild("SurfaceGui")
end

function DioramaTemplates.createSurfaceGuiForInfoPad(infoPad)
    local template = DioramaTemplates.getTemplateSurfaceGui()
    if not template then return nil end
    local copy = template:Clone()
    copy.Parent = infoPad
    copy.Name = "SurfaceGui"
    copy.Adornee = infoPad
    return copy
end

function DioramaTemplates.getTemplateFrame(frameType)
    frameType = frameType or "DefaultFrame"
    local dioramaPart = ServerStorage:FindFirstChild("DioramaPart")
    if not dioramaPart then return nil end
    local infoPad = dioramaPart:FindFirstChild("InfoPad")
    if not infoPad then return nil end
    local frameFolder = infoPad:FindFirstChild("Frame")
    if not frameFolder then return nil end
    return frameFolder:FindFirstChild(frameType)
end

function DioramaTemplates.createFrameForInfoPad(infoPad, frameType)
    local template = DioramaTemplates.getTemplateFrame(frameType)
    if not template then return nil end
    local copy = template:Clone()
    copy.Name = "Frame"
    copy.Parent = infoPad

    if copy:IsA("Model") then
        local primaryPart = copy.PrimaryPart or copy:FindFirstChildWhichIsA("BasePart")
        if primaryPart then
            local infoPadCF = infoPad.CFrame
            local modelSize = copy:GetExtentsSize()
            local offset = Vector3.new(0, 0, -modelSize.Z / 2 + 0.2)
            local adjustedCFrame = infoPadCF * CFrame.new(offset)
            copy:SetPrimaryPartCFrame(adjustedCFrame)
        end
    elseif copy:IsA("BasePart") then
        copy.CFrame = infoPad.CFrame
        copy.Anchored = true
        copy.CanCollide = false
    end
    return copy
end

function DioramaTemplates.getStandTemplate(standType)
    standType = standType or "DefaultStand"
    local dioramaPart = ServerStorage:FindFirstChild("DioramaPart")
    if not dioramaPart then return nil end
    local standBase = dioramaPart:FindFirstChild("StandBase")
    if not standBase then return nil end
    local standsFolder = standBase:FindFirstChild("Stands")
    if not standsFolder then return nil end
    return standsFolder:FindFirstChild(standType)
end

function DioramaTemplates.setupStandOnBase(dioramaModel, standType)
    local standBase = dioramaModel:FindFirstChild("StandBase")
    if not standBase then return nil end
    local template = DioramaTemplates.getStandTemplate(standType)
    if not template then return nil end
    local copy = template:Clone()
    copy.Name = "Stand"
    copy.Parent = standBase

    local primaryPart = copy.PrimaryPart
    if primaryPart then
        copy:SetPrimaryPartCFrame(standBase.CFrame)
    end

    local buttonPart = copy:FindFirstChild("Button")
    if buttonPart then
        local proximityPrompt = template.Parent.Parent:FindFirstChild("ProximityPrompt"):Clone()
        proximityPrompt.Parent = buttonPart
    end
    return copy
end

function DioramaTemplates.getTemplateCharacter()
    local templateFolder = ServerStorage:FindFirstChild("TemplateCharacters")
    if not templateFolder then return nil end
    return templateFolder:GetChildren()[1]
end

function DioramaTemplates.applyPoseToDiorama(characterModel, poseName)
    if not poseName or poseName == "" then return nil end
    local poseFolder = ServerStorage:FindFirstChild("DioramaPoses")
    if not poseFolder then return nil end
    local poseAnimation = poseFolder:FindFirstChild(poseName)
    if not poseAnimation or not poseAnimation:IsA("Animation") then return nil end
    local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    local poseTrack = humanoid:LoadAnimation(poseAnimation)
    poseTrack:Play()
    poseTrack:AdjustSpeed(0)
    poseTrack.Looped = false
    return poseTrack
end

return DioramaTemplates