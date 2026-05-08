--!strict
local NPC = script.Parent
local Humanoid = NPC:WaitForChild("Humanoid")
local RootPart = NPC.PrimaryPart or NPC:FindFirstChild("HumanoidRootPart") or NPC:FindFirstChildWhichIsA("BasePart")
if not RootPart then return end

-- Services
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")

-- Reaction types
local REACTION_TYPES = {
    ATTACK = "attack",
    IGNORE = "ignore",
    FLEE = "flee",
    FLEE_ON_DAMAGE = "flee_on_damage"
}

-- Animation states
local ANIMATION_STATES = {
    IDLE = "idle",
    WALK = "walk",
    RUN = "run",
    ATTACK = "attack",
    CUSTOM = "custom"
}

-- Configuration
local function getConfig()
    local config = {}
    
    config.name = NPC:GetAttribute("Name") or "NPC"
    config.spawnType = NPC:GetAttribute("SpawnType") or "Region"
    config.detectionRange = NPC:GetAttribute("DetectionRange") or 30
    config.respawnTime = NPC:GetAttribute("RespawnTime") or 0
    config.playerReaction = NPC:GetAttribute("PlayerReaction") or "attack"
    config.targetLostTime = NPC:GetAttribute("TargetLostTime") or 5
    config.scriptLoop = NPC:GetAttribute("ScriptLoop") or true
    config.reactionSpeed = NPC:GetAttribute("ReactionSpeed") or "Run"
    
    -- Combat properties
    config.damage = NPC:GetAttribute("Damage") or 10
    config.attackRange = NPC:GetAttribute("AttackRange") or 5
    config.attackCooldown = NPC:GetAttribute("AttackCooldown") or 1
    
    -- Speed configuration
    local speedsStr = NPC:GetAttribute("SpeedsConfig")
    if speedsStr then
        config.speeds = HttpService:JSONDecode(speedsStr)
    else
        config.speeds = {
            Walk = 16,
            Run = 16,
            Sneak = 16
        }
    end
    
    -- Animations
    local animsStr = NPC:GetAttribute("AnimationsConfig")
    if animsStr then
        config.animations = HttpService:JSONDecode(animsStr)
    else
        config.animations = {}
    end
    
    -- Script
    local scriptStr = NPC:GetAttribute("ScriptConfig")
    if scriptStr then
        config.script = HttpService:JSONDecode(scriptStr)
    else
        config.script = {}
    end
    
    -- Pathfinding
    local pathStr = NPC:GetAttribute("PathfindingConfig")
    if pathStr then
        config.pathfinding = HttpService:JSONDecode(pathStr)
    else
        config.pathfinding = {
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = false,
            AgentCanClimb = false,
            WaypointSpacing = 4,
            Costs = {}
        }
    end
    
    -- Trigger config
    local triggerStr = NPC:GetAttribute("TriggerConfig")
    if triggerStr then
        config.triggerConfig = HttpService:JSONDecode(triggerStr)
    end
    
    return config
end

local config = getConfig()

-- Trigger activation state
local isActive = config.spawnType ~= "Triggered"
local triggerCheckConnection = nil
local triggerPart = nil

-- Handle triggered spawn
if config.spawnType == "Triggered" and config.triggerConfig then
    -- Make NPC invisible and non-collidable
    for _, part in ipairs(NPC:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
            part.CanCollide = false
        end
    end
    
    -- Disable humanoid states
    if Humanoid then
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end

    -- Create trigger part based on config
    if config.triggerConfig.triggerType == "PointRadius" then
        triggerPart = Instance.new("Part")
        triggerPart.Shape = Enum.PartType.Ball
        triggerPart.Size = Vector3.new(config.triggerConfig.radius*2, config.triggerConfig.radius*2, config.triggerConfig.radius*2)
        triggerPart.Position = config.triggerConfig.point
        triggerPart.Transparency = 1
        triggerPart.CanCollide = false
        triggerPart.Anchored = true
        triggerPart.Parent = workspace
    elseif config.triggerConfig.triggerType == "Part" then
        triggerPart = game:GetService("Workspace"):FindFirstChild(config.triggerConfig.part, true)
    end

    -- Start trigger check
    if triggerPart then
        triggerCheckConnection = RunService.Heartbeat:Connect(function()
            if not NPC.Parent then 
                if triggerCheckConnection then
                    triggerCheckConnection:Disconnect()
                end
                return 
            end

            local players = Players:GetPlayers()
            local anyPlayerInTrigger = false
            
            for _, player in ipairs(players) do
                if player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        if config.triggerConfig.triggerType == "PointRadius" then
                            if (hrp.Position - triggerPart.Position).Magnitude <= config.triggerConfig.radius then
                                anyPlayerInTrigger = true
                                break
                            end
                        elseif config.triggerConfig.triggerType == "Part" then
                            local relativePos = triggerPart.CFrame:PointToObjectSpace(hrp.Position)
                            local size = triggerPart.Size / 2
                            if math.abs(relativePos.X) <= size.X and 
                               math.abs(relativePos.Y) <= size.Y and 
                               math.abs(relativePos.Z) <= size.Z then
                                anyPlayerInTrigger = true
                                break
                            end
                        end
                    end
                end
            end

            if anyPlayerInTrigger then
                if triggerCheckConnection then
                    triggerCheckConnection:Disconnect()
                    triggerCheckConnection = nil
                end
                
                -- Activate NPC
                isActive = true
                for _, part in ipairs(NPC:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = 0
                        part.CanCollide = true
                    end
                end
                
                if Humanoid then
                    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                    Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end
        end)
    else
        warn("Trigger part not created for NPC: ".. config.name)
    end
end

-- Animation system
local animator = Humanoid:FindFirstChildOfClass("Animator")
if not animator then
    animator = Instance.new("Animator")
    animator.Parent = Humanoid
end

local animationTracks = {}
for name, animId in pairs(config.animations) do
    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    animationTracks[name] = animator:LoadAnimation(anim)
end

-- Animation state management
local currentAnimationState = ANIMATION_STATES.IDLE
local currentAnimationTrack = nil
local lastAnimationChange = 0
local ANIMATION_CHANGE_COOLDOWN = 0.1

local function playAnimation(name, priority, fadeTime, weight, speed)
    if not animationTracks[name] then return end
    if currentAnimationTrack and currentAnimationTrack.Animation.AnimationId == config.animations[name] then
        return currentAnimationTrack
    end
    
    if tick() - lastAnimationChange < ANIMATION_CHANGE_COOLDOWN then
        return currentAnimationTrack
    end
    
    if currentAnimationTrack and currentAnimationTrack.IsPlaying then
        currentAnimationTrack:Stop(fadeTime or 0.2)
    end
    
    local track = animationTracks[name]
    if track then
        track.Priority = priority or Enum.AnimationPriority.Idle
        track:Play(fadeTime or 0.2)
        if weight then track:AdjustWeight(weight, fadeTime or 0.2) end
        if speed then track:AdjustSpeed(speed) end
        
        currentAnimationTrack = track
        lastAnimationChange = tick()
        
        if name == "idle" then
            currentAnimationState = ANIMATION_STATES.IDLE
        elseif name == "walk" then
            currentAnimationState = ANIMATION_STATES.WALK
        elseif name == "run" then
            currentAnimationState = ANIMATION_STATES.RUN
        elseif name == "attack" then
            currentAnimationState = ANIMATION_STATES.ATTACK
        else
            currentAnimationState = ANIMATION_STATES.CUSTOM
        end
        
        return track
    end
    return nil
end

local function stopAllAnimations()
    for _, track in pairs(animationTracks) do
        if track and track.IsPlaying then
            track:Stop(0.2)
        end
    end
    currentAnimationTrack = nil
    currentAnimationState = ANIMATION_STATES.IDLE
end

-- Helper functions
local function findCheckpoints(tagName)
    local points = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj:GetAttribute("CheckpointTag") == tagName then
            table.insert(points, obj)
        end
    end
    return points
end

local function findPlayersInRange(position, range)
    local targets = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - position).Magnitude <= range then
                table.insert(targets, player.Character)
            end
        end
    end
    return targets
end

-- Speed management
local function setMovementSpeed(speedType)
    local speed = config.speeds[speedType] or 16
    Humanoid.WalkSpeed = speed
end

-- Damage indicator
local function onDamageTaken()
    local damageIndicator = {
        enabled = NPC:GetAttribute("DamageIndicatorEnabled") or false,
        color = NPC:GetAttribute("DamageIndicatorColor") or Color3.fromRGB(255, 0, 0),
        duration = NPC:GetAttribute("DamageIndicatorDuration") or 0.5
    }
    
    if not damageIndicator.enabled then return end
    
    local originalColor = NPC:GetAttribute("OriginalColor")
    if not originalColor then
        for _, part in ipairs(NPC:GetDescendants()) do
            if part:IsA("BasePart") then
                NPC:SetAttribute("OriginalColor", part.Color)
                originalColor = part.Color
                break
            end
        end
    end
    
    for _, part in ipairs(NPC:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Color = damageIndicator.color
        end
    end
    
    task.delay(damageIndicator.duration, function()
        for _, part in ipairs(NPC:GetDescendants()) do
            if part:IsA("BasePart") then
                local tween = TweenService:Create(
                    part,
                    TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                    {Color = originalColor}
                )
                tween:Play()
            end
        end
    end)
end

-- Health monitoring
Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
    if Humanoid.Health < Humanoid.MaxHealth then
        onDamageTaken()
        if config.playerReaction == REACTION_TYPES.FLEE_ON_DAMAGE then
            NPC:SetAttribute("ShouldFlee", true)
        end
    end
end)

-- NPC state management
local currentTarget = nil
local path = nil
local waypoints = {}
local currentWaypointIndex = 1
local lastPathCalculation = 0
local lastSeenTargetTime = 0
local lastKnownTargetPosition = nil
local lastPosition = RootPart.Position
local lastPositionTime = tick()
local lastAttackTime = 0
local stuckTimer = 0
local isStuck = false
local failedPathAttempts = 0

-- Script execution state
local currentScriptStep = 1
local scriptState = "idle"
local scriptInterrupted = false
local scriptTarget = nil
local scriptStepStartTime = 0
local scriptPaused = false
local interruptedScriptStep = 1
local interruptedScriptState = "idle"
local currentMovementSpeed = "Walk"

-- Wander state
local wanderState = "none"
local wanderStartTime = 0
local wanderDuration = 0
local wanderTargetPoint = nil
local wanderStep = nil

-- Optimized pathfinding parameters
local RECALCULATE_INTERVAL = 1.0
local WAYPOINT_REACHED_DISTANCE = 4
local STUCK_CHECK_INTERVAL = 2.0
local STUCK_THRESHOLD = 1.5
local FLEE_DISTANCE_MULTIPLIER = 2.0
local MAX_FAILED_PATH_ATTEMPTS = 3

-- Pathfinding functions
local function createPath(targetPosition)
    if not RootPart then return false end
    
    local agentParams = config.pathfinding or {}
    
    local newPath = PathfindingService:CreatePath({
        AgentRadius = agentParams.AgentRadius or 2,
        AgentHeight = agentParams.AgentHeight or 5,
        AgentCanJump = agentParams.AgentCanJump or true,
        AgentCanClimb = agentParams.AgentCanClimb or true,
        WaypointSpacing = agentParams.WaypointSpacing or 4,
        Costs = agentParams.Costs or {}
    })
    
    newPath:ComputeAsync(RootPart.Position, targetPosition)
    
    if newPath.Status == Enum.PathStatus.Success then
        path = newPath
        waypoints = newPath:GetWaypoints()
        currentWaypointIndex = 1
        lastPathCalculation = tick()
        isStuck = false
        stuckTimer = tick()
        failedPathAttempts = 0
        return true
    else
        failedPathAttempts = failedPathAttempts + 1
        if failedPathAttempts >= MAX_FAILED_PATH_ATTEMPTS then
            waypoints = {}
            currentWaypointIndex = 1
            return false
        end
    end
    return false
end

local function checkIfStuck()
    local currentPosition = RootPart.Position
    local distanceMoved = (currentPosition - lastPosition).Magnitude
    local timeSinceLastCheck = tick() - lastPositionTime
    
    if distanceMoved < STUCK_THRESHOLD then
        if not isStuck then
            stuckTimer = tick()
            isStuck = true
        end
        
        if tick() - stuckTimer > STUCK_CHECK_INTERVAL then
            return true
        end
    else
        isStuck = false
    end
    
    lastPosition = currentPosition
    lastPositionTime = tick()
    return false
end

local function followPath()
    if not RootPart then return false end
    if not Humanoid or Humanoid.Health <= 0 then return false end
    if #waypoints == 0 then return false end
    
    if currentWaypointIndex > #waypoints then
        return false
    end
    
    local currentWaypoint = waypoints[currentWaypointIndex]
    
    while currentWaypointIndex <= #waypoints do
        local distance = (currentWaypoint.Position - RootPart.Position).Magnitude
        if distance > WAYPOINT_REACHED_DISTANCE then
            break
        end
        currentWaypointIndex = currentWaypointIndex + 1
        currentWaypoint = waypoints[currentWaypointIndex]
    end
    
    if currentWaypointIndex > #waypoints then
        return false
    end
    
    Humanoid:MoveTo(currentWaypoint.Position)
    
    if currentWaypoint.Action == Enum.PathWaypointAction.Jump then
        Humanoid.Jump = true
    end
    
    return true
end

local function shouldRecalculatePath(targetPosition)
    if tick() - lastPathCalculation > RECALCULATE_INTERVAL then
        return true
    end
    
    if #waypoints == 0 then
        return true
    end
    
    if checkIfStuck() then
        return true
    end
    
    return false
end

-- Target management
local function hasLostTarget()
    if not currentTarget then return true end
    if not currentTarget.Parent then return true end
    
    local targetHumanoid = currentTarget:FindFirstChildOfClass("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        return true
    end
    
    if tick() - lastSeenTargetTime > config.targetLostTime then
        return true
    end
    
    return false
end

local function findAndSetTarget()
    if not isActive then return false end
    local targets = findPlayersInRange(RootPart.Position, config.detectionRange)
    if #targets == 0 then return false end
    if config.playerReaction == REACTION_TYPES.IGNORE then return false end
    
    local closest = nil
    local minDistance = math.huge
    
    for _, target in ipairs(targets) do
        local hrp = target:FindFirstChild("HumanoidRootPart")
        if hrp then
            local distance = (hrp.Position - RootPart.Position).Magnitude
            if distance < minDistance then
                minDistance = distance
                closest = target
            end
        end
    end
    
    if closest then
        currentTarget = closest
        lastSeenTargetTime = tick()
        scriptInterrupted = true
        
        -- Reset wander state
        wanderState = "none"
        wanderStep = nil
        
        -- Save script state
        interruptedScriptStep = currentScriptStep
        interruptedScriptState = scriptState
        
        -- Reset script movement
        scriptState = "idle"
        waypoints = {}
        scriptTarget = nil
        
        setMovementSpeed(config.reactionSpeed)
        return true
    end
    
    return false
end

-- Script execution
local function resetScriptState()
    currentScriptStep = 1
    scriptState = "idle"
    scriptTarget = nil
    waypoints = {}
    playAnimation("idle", Enum.AnimationPriority.Idle)
    setMovementSpeed("Walk")
end

local function executeScriptStep()
    if #config.script == 0 then return end
    if currentScriptStep > #config.script then
        if config.scriptLoop then
            resetScriptState()
        else
            scriptPaused = true
        end
        return
    end
    
    local step = config.script[currentScriptStep]
    if not step then
        currentScriptStep += 1
        return
    end

    if step.type == "Loop" then
        resetScriptState()
        return
    end
    
    if step.type == "MoveToTag" then
        local checkpoints = findCheckpoints(step.tag)
        if #checkpoints == 0 then
            currentScriptStep += 1
            return
        end
        
        if step.selection == "random" then
            scriptTarget = checkpoints[math.random(1, #checkpoints)]
        else
            local lastCheckpointIndex = NPC:GetAttribute("LastCheckpointIndex") or 0
            lastCheckpointIndex = (lastCheckpointIndex % #checkpoints) + 1
            scriptTarget = checkpoints[lastCheckpointIndex]
            NPC:SetAttribute("LastCheckpointIndex", lastCheckpointIndex)
        end
        
        currentMovementSpeed = step.speed or "Walk"
        setMovementSpeed(currentMovementSpeed)
        
        if createPath(scriptTarget.Position) then
            scriptState = "moving"
            playAnimation(currentMovementSpeed == "Run" and "run" or "walk", Enum.AnimationPriority.Movement)
        else
            currentScriptStep += 1
        end
        
    elseif step.type == "Wait" then
        scriptStepStartTime = tick()
        scriptState = "waiting"
        playAnimation("idle", Enum.AnimationPriority.Idle)
        
    elseif step.type == "PlayAnimation" then
        scriptStepStartTime = tick()
        playAnimation(step.animation, step.priority or Enum.AnimationPriority.Action)
        scriptState = "playing_anim"
        
    elseif step.type == "WanderInArea" then
        scriptState = "wandering"
        wanderState = "none"
        wanderStep = step
        currentMovementSpeed = step.speed or "Walk"
        setMovementSpeed(currentMovementSpeed)
    end
end

local function updateScriptExecution(deltaTime)
    if scriptPaused then return end
    if scriptInterrupted then return end
    
    if scriptState == "idle" then
        executeScriptStep()
        return
    end
    
    local step = config.script[currentScriptStep]
    if not step then
        currentScriptStep += 1
        scriptState = "idle"
        return
    end
    
    if scriptState == "moving" then
        if not scriptTarget or not scriptTarget.Parent then
            scriptState = "idle"
            currentScriptStep += 1
            return
        end
        
        local pathActive = followPath()
        
        if not pathActive then
            if currentWaypointIndex > #waypoints then
                local distance = (RootPart.Position - scriptTarget.Position).Magnitude
                if distance < (WAYPOINT_REACHED_DISTANCE * 2) then
                    scriptState = "idle"
                    currentScriptStep += 1
                    scriptTarget = nil
                    waypoints = {}
                    playAnimation("idle", Enum.AnimationPriority.Idle)
                    return
                end
            end
            
            createPath(scriptTarget.Position)
        elseif checkIfStuck() then
            createPath(scriptTarget.Position)
        end
        
    elseif scriptState == "waiting" then
        if tick() - scriptStepStartTime > (step.duration or 1) then
            scriptState = "idle"
            currentScriptStep += 1
        end
        
    elseif scriptState == "playing_anim" then
        if tick() - scriptStepStartTime > (step.duration or 1) then
            scriptState = "idle"
            currentScriptStep += 1
            playAnimation("idle", Enum.AnimationPriority.Idle)
        end
        
    elseif scriptState == "wandering" then
        if not wanderStep then
            scriptState = "idle"
            currentScriptStep += 1
            return
        end

        if wanderState == "none" then
            local area = wanderStep.area
            local min = area.Min
            local max = area.Max
            wanderTargetPoint = Vector3.new(
                math.random(min.X, max.X),
                math.random(min.Y, max.Y),
                math.random(min.Z, max.Z)
            )
            
            if createPath(wanderTargetPoint) then
                wanderState = "moving"
                wanderDuration = math.random(wanderStep.minWanderTime, wanderStep.maxWanderTime)
                wanderStartTime = tick()
                playAnimation(currentMovementSpeed == "Run" and "run" or "walk", Enum.AnimationPriority.Movement)
            else
                wanderState = "waiting"
                wanderDuration = math.random(wanderStep.minWaitTime, wanderStep.maxWaitTime)
                wanderStartTime = tick()
                if wanderStep.animations and #wanderStep.animations > 0 then
                    local animName = wanderStep.animations[math.random(1, #wanderStep.animations)]
                    playAnimation(animName, Enum.AnimationPriority.Idle)
                else
                    playAnimation("idle", Enum.AnimationPriority.Idle)
                end
            end

        elseif wanderState == "moving" then
            local pathActive = followPath()
            local currentTime = tick()
            local distance = (RootPart.Position - wanderTargetPoint).Magnitude
            
            if not pathActive or distance < WAYPOINT_REACHED_DISTANCE or 
               (currentTime - wanderStartTime) > wanderDuration then
                wanderState = "waiting"
                wanderDuration = math.random(wanderStep.minWaitTime, wanderStep.maxWaitTime)
                wanderStartTime = currentTime
                if wanderStep.animations and #wanderStep.animations > 0 then
                    local animName = wanderStep.animations[math.random(1, #wanderStep.animations)]
                    playAnimation(animName, Enum.AnimationPriority.Idle)
                else
                    playAnimation("idle", Enum.AnimationPriority.Idle)
                end
            end

        elseif wanderState == "waiting" then
            if tick() - wanderStartTime > wanderDuration then
                wanderState = "none"
                playAnimation("idle", Enum.AnimationPriority.Idle)
            end
        end
    end
end

-- Player reaction handlers
local function handleAttack(deltaTime)
    if not currentTarget then return end
    
    local targetHrp = currentTarget:FindFirstChild("HumanoidRootPart")
    if not targetHrp then
        currentTarget = nil
        return
    end
    
    lastKnownTargetPosition = targetHrp.Position
    lastSeenTargetTime = tick()
    
    local distance = (targetHrp.Position - RootPart.Position).Magnitude
    
    if distance <= config.attackRange then
        if tick() - lastAttackTime >= config.attackCooldown then
            local targetHumanoid = currentTarget:FindFirstChildOfClass("Humanoid")
            if targetHumanoid then
                targetHumanoid:TakeDamage(config.damage)
                playAnimation("attack", Enum.AnimationPriority.Action)
            end
            lastAttackTime = tick()
        end
        Humanoid:MoveTo(RootPart.Position)
        
        -- Only play idle if attack animation isn't playing
        if currentAnimationState ~= ANIMATION_STATES.ATTACK then
            playAnimation("idle", Enum.AnimationPriority.Idle)
        end
    else
        if shouldRecalculatePath(targetHrp.Position) then
            createPath(targetHrp.Position)
        end
        
        if followPath() then
            playAnimation("run", Enum.AnimationPriority.Movement)
        else
            playAnimation("idle", Enum.AnimationPriority.Idle)
        end
    end
end

local function handleFlee(deltaTime)
    if not currentTarget then return end
    
    local targetHrp = currentTarget:FindFirstChild("HumanoidRootPart")
    if not targetHrp then
        currentTarget = nil
        return
    end
    
    lastKnownTargetPosition = targetHrp.Position
    lastSeenTargetTime = tick()
    
    local fleeDirection = (RootPart.Position - targetHrp.Position).Unit
    local fleePosition = RootPart.Position + fleeDirection * (config.detectionRange * FLEE_DISTANCE_MULTIPLIER)
    
    if shouldRecalculatePath(fleePosition) then
        createPath(fleePosition)
    end
    
    if followPath() then
        playAnimation("run", Enum.AnimationPriority.Movement)
    else
        playAnimation("idle", Enum.AnimationPriority.Idle)
    end
end

-- Main state machine
local function updateNPC(deltaTime)
    if not isActive then return end
    if not RootPart or not Humanoid or Humanoid.Health <= 0 then return end
    
    if findAndSetTarget() then
        if config.playerReaction == REACTION_TYPES.ATTACK then
            handleAttack(deltaTime)
        elseif config.playerReaction == REACTION_TYPES.FLEE or 
              (config.playerReaction == REACTION_TYPES.FLEE_ON_DAMAGE and NPC:GetAttribute("ShouldFlee")) then
            handleFlee(deltaTime)
        end
    else
        if currentTarget and hasLostTarget() then
            currentTarget = nil
            scriptInterrupted = false
            currentScriptStep = interruptedScriptStep
            scriptState = interruptedScriptState
            setMovementSpeed(currentMovementSpeed)
            playAnimation("idle", Enum.AnimationPriority.Idle)
        end
        
        if not currentTarget then
            updateScriptExecution(deltaTime)
        end
    end
end

local function setupAttributeListeners()
    NPC:GetAttributeChangedSignal("Name"):Connect(function()
        local value = NPC:GetAttribute("Name")
        if value ~= nil then
            config.name = value
        end
    end)
    
    NPC:GetAttributeChangedSignal("SpawnType"):Connect(function()
        local value = NPC:GetAttribute("SpawnType")
        if value ~= nil then
            config.spawnType = value
        end
    end)
    
    NPC:GetAttributeChangedSignal("DetectionRange"):Connect(function()
        local value = NPC:GetAttribute("DetectionRange")
        if value ~= nil then
            config.detectionRange = value
        end
    end)
    
    NPC:GetAttributeChangedSignal("RespawnTime"):Connect(function()
        local value = NPC:GetAttribute("RespawnTime")
        if value ~= nil then
            config.respawnTime = value
        end
    end)
    
    NPC:GetAttributeChangedSignal("PlayerReaction"):Connect(function()
        local value = NPC:GetAttribute("PlayerReaction")
        if value ~= nil then
            config.playerReaction = value
        end
    end)
    
    NPC:GetAttributeChangedSignal("TargetLostTime"):Connect(function()
        local value = NPC:GetAttribute("TargetLostTime")
        if value ~= nil then
            config.targetLostTime = value
        end
    end)
    
    NPC:GetAttributeChangedSignal("ScriptLoop"):Connect(function()
        local value = NPC:GetAttribute("ScriptLoop")
        if value ~= nil then
            config.scriptLoop = value
        end
    end)
    
    NPC:GetAttributeChangedSignal("ReactionSpeed"):Connect(function()
        local value = NPC:GetAttribute("ReactionSpeed")
        if value ~= nil then
            config.reactionSpeed = value
        end
    end)
    
    -- Combat properties listeners
    NPC:GetAttributeChangedSignal("Damage"):Connect(function()
        local value = NPC:GetAttribute("Damage")
        if value ~= nil then
            config.damage = value
        end
    end)
    
    NPC:GetAttributeChangedSignal("AttackRange"):Connect(function()
        local value = NPC:GetAttribute("AttackRange")
        if value ~= nil then
            config.attackRange = value
        end
    end)
    
    NPC:GetAttributeChangedSignal("AttackCooldown"):Connect(function()
        local value = NPC:GetAttribute("AttackCooldown")
        if value ~= nil then
            config.attackCooldown = value
        end
    end)
    
    -- JSON config listeners
    NPC:GetAttributeChangedSignal("SpeedsConfig"):Connect(function()
        local speedsStr = NPC:GetAttribute("SpeedsConfig")
        if speedsStr ~= nil then
            config.speeds = HttpService:JSONDecode(speedsStr)
        end
    end)
    
    NPC:GetAttributeChangedSignal("AnimationsConfig"):Connect(function()
        local animsStr = NPC:GetAttribute("AnimationsConfig")
        if animsStr ~= nil then
            config.animations = HttpService:JSONDecode(animsStr)
        end
    end)
    
    NPC:GetAttributeChangedSignal("ScriptConfig"):Connect(function()
        local scriptStr = NPC:GetAttribute("ScriptConfig")
        if scriptStr ~= nil then
            config.script = HttpService:JSONDecode(scriptStr)
        end
    end)
    
    NPC:GetAttributeChangedSignal("PathfindingConfig"):Connect(function()
        local pathStr = NPC:GetAttribute("PathfindingConfig")
        if pathStr ~= nil then
            config.pathfinding = HttpService:JSONDecode(pathStr)
        end
    end)
    
    NPC:GetAttributeChangedSignal("TriggerConfig"):Connect(function()
        local triggerStr = NPC:GetAttribute("TriggerConfig")
        if triggerStr ~= nil then
            config.triggerConfig = HttpService:JSONDecode(triggerStr)
        end
    end)
end

-- Main loop
local lastUpdate = tick()
local heartbeatConnection
heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
    if not NPC.Parent then 
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
        end
        if triggerCheckConnection then
            triggerCheckConnection:Disconnect()
        end
        return 
    end
    
    local currentTime = tick()
    updateNPC(currentTime - lastUpdate)
    lastUpdate = currentTime
end)

-- Death handling
Humanoid.Died:Connect(function()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
    end
    if triggerCheckConnection then
        triggerCheckConnection:Disconnect()
    end
    stopAllAnimations()
    
    if config.respawnTime > 0 then
        Debris:AddItem(NPC, config.respawnTime)
    else
        NPC:Destroy()
    end
end)

playAnimation("idle", Enum.AnimationPriority.Idle)
setMovementSpeed("Walk")
setupAttributeListeners()