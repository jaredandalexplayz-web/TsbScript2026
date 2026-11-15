-- TSB Halloween 2026 By- @V3inn_wins
-- Complete LocalScript

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local TARGET_NAME = "HalloweenDoorTrees"

local autoTP = false
local candyTPEnabled = false
local instantInteract = false
local jackpotESPEnabled = false
local jackpotESPObjects = {}
local giverESPEnabled = false
local giverESPObjects = {}
local trashGuyESPEnabled = false
local trashGuyESPObjects = {}
local guiVisible = true
local autoTPToken = 0
local candyTPToken = 0
local closed = false
local gui -- forward-declare so ESP instances can be parented to the ScreenGui
local status -- shared by callbacks declared before the status label is created

-- Remove the previous UI
local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("SoulShadeUI")

if oldGui then
    oldGui:Destroy()
end

-- Character helpers
local function getRoot(character)
    character = character or player.Character
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function getTargetPart(object)
    if not object then
        return nil
    end

    if object:IsA("BasePart") then
        return object
    elseif object:IsA("Model") then
        if object.PrimaryPart then
            return object.PrimaryPart
        end

        return object:FindFirstChildWhichIsA("BasePart", true)
    end

    return object:FindFirstChildWhichIsA("BasePart", true)
end

-- Find HalloweenDoorTrees
local function findTarget()
    return getTargetPart(Workspace:FindFirstChild(TARGET_NAME, true))
end

-- Teleport helper
local function teleportToPosition(position)
    local root = getRoot(player.Character)

    if not root then
        return false
    end

    root.CFrame = CFrame.new(position)
    return true
end

local function teleportToTarget()
    local targetPart = findTarget()

    if not targetPart then
        warn("TSB Halloween: Could not find " .. TARGET_NAME)
        return false
    end

    return teleportToPosition(
        targetPart.Position + Vector3.new(0, 4, 0)
    )
end

-- Check for a surface underneath a candy
local function hasGroundBelow(part)
    if not part or not part:IsDescendantOf(Workspace) then
        return false, nil
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        player.Character,
        part
    }
    params.IgnoreWater = true

    local origin = part.Position + Vector3.new(0, 3, 0)
    local direction = Vector3.new(0, -250, 0)

    local result = Workspace:Raycast(origin, direction, params)

    if not result then
        return false, nil
    end

    -- Ignore steep surfaces such as walls
    if result.Normal.Y < 0.65 then
        return false, nil
    end

    return true, result.Position
end

-- Find the nearest candy with ground underneath it
local function findNearestCandy()
    local root = getRoot(player.Character)

    if not root then
        return nil, nil
    end

    local nearestPart = nil
    local nearestGroundPosition = nil
    local nearestDistance = math.huge

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object.Name:lower():find("candy", 1, true) then
            local part = getTargetPart(object)

            if part and part:IsDescendantOf(Workspace) then
                local grounded, groundPosition = hasGroundBelow(part)

                if grounded and groundPosition then
                    local distance =
                        (part.Position - root.Position).Magnitude

                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestPart = part
                        nearestGroundPosition = groundPosition
                    end
                end
            end
        end
    end

    return nearestPart, nearestGroundPosition
end

local function teleportToNearestCandy()
    local candyPart, groundPosition = findNearestCandy()

    if not candyPart or not groundPosition then
        warn("TSB Halloween: No grounded physical Candy found.")
        return false
    end

    return teleportToPosition(
        groundPosition + Vector3.new(0, 4, 0)
    )
end

-- Jackpot Giver ESP
-- Looks for objects whose name contains both "jackpot" and "giver".
local function isJackpotGiver(object)
    local name = object.Name:lower():gsub("[%s_%-]", "")
    if name:find("jackpotgiver", 1, true) then
        return true
    end

    return false
end

local function getESPAdornee(object)
    if object:IsA("Model") then
        return object
    elseif object:IsA("BasePart") then
        return object
    end
    return nil
end

local function removeJackpotESP(object)
    local data = jackpotESPObjects[object]
    if data then
        if data.highlight then data.highlight:Destroy() end
        if data.billboard then data.billboard:Destroy() end
        jackpotESPObjects[object] = nil
    end
end

local function clearJackpotESP()
    for object in pairs(jackpotESPObjects) do
        removeJackpotESP(object)
    end
end

local function addJackpotESP(object)
    if jackpotESPObjects[object] or not object:IsDescendantOf(Workspace) then
        return
    end

    local adornee = getESPAdornee(object)
    if not adornee then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "JackpotGiverESPHighlight"
    highlight.Adornee = adornee
    highlight.FillColor = Color3.fromRGB(255, 190, 35)
    highlight.OutlineColor = Color3.fromRGB(255, 245, 180)
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = gui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "JackpotGiverESPLabel"
    billboard.Adornee = adornee:IsA("Model")
        and (adornee:FindFirstChild("Head", true) or adornee:FindFirstChildWhichIsA("BasePart", true))
        or adornee
    billboard.Size = UDim2.fromOffset(170, 38)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 2000
    billboard.Parent = gui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
    label.BackgroundTransparency = 0.2
    label.TextColor3 = Color3.fromRGB(255, 215, 90)
    label.TextStrokeTransparency = 0.25
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Text = "JACKPOT GIVER"
    label.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    jackpotESPObjects[object] = {
        highlight = highlight,
        billboard = billboard,
        label = label
    }
end

local function updateJackpotESP()
    if not jackpotESPEnabled or closed then return end

    for _, object in ipairs(Workspace:GetDescendants()) do
        if (object:IsA("Model") or object:IsA("BasePart"))
            and isJackpotGiver(object) then
            addJackpotESP(object)
        end
    end

    local root = getRoot(player.Character)
    for object, data in pairs(jackpotESPObjects) do
        if not object:IsDescendantOf(Workspace) then
            removeJackpotESP(object)
        elseif root and data.label then
            local part = object:IsA("Model")
                and (object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true))
                or object
            if part then
                local distance = math.floor((part.Position - root.Position).Magnitude + 0.5)
                data.label.Text = "JACKPOT GIVER  [" .. distance .. "m]"
            end
        end
    end
end

-- Giver ESP (separate from Jackpot Giver)
local function isRegularGiver(object)
    local name = object.Name:lower():gsub("[%s_%-]", "")
    return name:find("giver", 1, true) ~= nil
        and not name:find("jackpotgiver", 1, true)
end

local function removeGiverESP(object)
    local data = giverESPObjects[object]
    if data then
        if data.highlight then data.highlight:Destroy() end
        if data.billboard then data.billboard:Destroy() end
        giverESPObjects[object] = nil
    end
end

local function clearGiverESP()
    for object in pairs(giverESPObjects) do
        removeGiverESP(object)
    end
end

local function addGiverESP(object)
    if giverESPObjects[object] or not object:IsDescendantOf(Workspace) then return end
    local adornee = getESPAdornee(object)
    if not adornee then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "GiverESPHighlight"
    highlight.Adornee = adornee
    highlight.FillColor = Color3.fromRGB(70, 220, 130)
    highlight.OutlineColor = Color3.fromRGB(190, 255, 210)
    highlight.FillTransparency = 0.55
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = gui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "GiverESPLabel"
    billboard.Adornee = adornee:IsA("Model")
        and (adornee:FindFirstChild("Head", true) or adornee:FindFirstChildWhichIsA("BasePart", true))
        or adornee
    billboard.Size = UDim2.fromOffset(150, 38)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 2000
    billboard.Parent = gui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(15, 25, 20)
    label.BackgroundTransparency = 0.2
    label.TextColor3 = Color3.fromRGB(130, 255, 175)
    label.TextStrokeTransparency = 0.25
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Text = "GIVER"
    label.Parent = billboard
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    giverESPObjects[object] = {highlight = highlight, billboard = billboard, label = label}
end

local function updateGiverESP()
    if not giverESPEnabled or closed then return end
    for _, object in ipairs(Workspace:GetDescendants()) do
        if (object:IsA("Model") or object:IsA("BasePart")) and isRegularGiver(object) then
            addGiverESP(object)
        end
    end
    local root = getRoot(player.Character)
    for object, data in pairs(giverESPObjects) do
        if not object:IsDescendantOf(Workspace) then
            removeGiverESP(object)
        elseif root and data.label then
            local part = object:IsA("Model")
                and (object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true))
                or object
            if part then
                local distance = math.floor((part.Position - root.Position).Magnitude + 0.5)
                data.label.Text = "GIVER [" .. distance .. "m]"
            end
        end
    end
end

-- TrashGuy ESP (separate toggle)
local function isTrashGuy(object)
    local name = object.Name:lower():gsub("[%s_%-]", "")
    return name:find("trashguy", 1, true) ~= nil
end

local function removeTrashGuyESP(object)
    local data = trashGuyESPObjects[object]
    if data then
        if data.highlight then data.highlight:Destroy() end
        if data.billboard then data.billboard:Destroy() end
        trashGuyESPObjects[object] = nil
    end
end

local function clearTrashGuyESP()
    for object in pairs(trashGuyESPObjects) do
        removeTrashGuyESP(object)
    end
end

local function addTrashGuyESP(object)
    if trashGuyESPObjects[object] or not object:IsDescendantOf(Workspace) then return end
    local adornee = getESPAdornee(object)
    if not adornee then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "TrashGuyESPHighlight"
    highlight.Adornee = adornee
    highlight.FillColor = Color3.fromRGB(235, 105, 65)
    highlight.OutlineColor = Color3.fromRGB(255, 205, 175)
    highlight.FillTransparency = 0.55
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = gui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TrashGuyESPLabel"
    billboard.Adornee = adornee:IsA("Model")
        and (adornee:FindFirstChild("Head", true) or adornee:FindFirstChildWhichIsA("BasePart", true))
        or adornee
    billboard.Size = UDim2.fromOffset(150, 38)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 2000
    billboard.Parent = gui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(30, 18, 15)
    label.BackgroundTransparency = 0.2
    label.TextColor3 = Color3.fromRGB(255, 165, 125)
    label.TextStrokeTransparency = 0.25
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Text = "TRASH GUY"
    label.Parent = billboard
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    trashGuyESPObjects[object] = {highlight = highlight, billboard = billboard, label = label}
end

local function updateTrashGuyESP()
    if not trashGuyESPEnabled or closed then return end
    for _, object in ipairs(Workspace:GetDescendants()) do
        if (object:IsA("Model") or object:IsA("BasePart")) and isTrashGuy(object) then
            addTrashGuyESP(object)
        end
    end
    local root = getRoot(player.Character)
    for object, data in pairs(trashGuyESPObjects) do
        if not object:IsDescendantOf(Workspace) then
            removeTrashGuyESP(object)
        elseif root and data.label then
            local part = object:IsA("Model")
                and (object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true))
                or object
            if part then
                local distance = math.floor((part.Position - root.Position).Magnitude + 0.5)
                data.label.Text = "TRASH GUY [" .. distance .. "m]"
            end
        end
    end
end

-- TP Up: move upward in short steps until a walkable surface is found.
local tpUpRunning = false
local tpUpToken = 0

local function findLandingAbove(root, startY, candidateY)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {player.Character}
    params.IgnoreWater = true

    local candidate = Vector3.new(root.Position.X, candidateY, root.Position.Z)
    local result = Workspace:Raycast(
        candidate + Vector3.new(0, 5, 0),
        Vector3.new(0, -16, 0),
        params
    )

    if result and result.Normal.Y >= 0.65 and result.Position.Y > startY + 5 then
        return result.Position
    end
    return nil
end

local function startTPUp(button)
    if tpUpRunning then
        tpUpRunning = false
        tpUpToken += 1
        button.Text = "TP Up"
        status.Text = "TP Up cancelled"
        return
    end

    tpUpRunning = true
    tpUpToken += 1
    local token = tpUpToken
    button.Text = "TP Up: STOP"
    status.Text = "Searching for a platform above..."

    task.spawn(function()
        local root = getRoot(player.Character)
        if not root then
            tpUpRunning = false
            button.Text = "TP Up"
            status.Text = "Character not ready"
            return
        end

        local startY = root.Position.Y
        local steps = 0
        local maxSteps = 60 -- maximum rise: 480 studs

        while tpUpRunning and token == tpUpToken and not closed and steps < maxSteps do
            root = getRoot(player.Character)
            if not root then break end

            local nextY = root.Position.Y + 8
            local landing = findLandingAbove(root, startY, nextY)

            if landing then
                root.CFrame = CFrame.new(landing + Vector3.new(0, 4, 0))
                status.Text = "Found a platform - landed safely"
                break
            end

            root.CFrame = root.CFrame + Vector3.new(0, 8, 0)
            steps += 1
            task.wait(0.08)
        end

        if steps >= maxSteps then
            status.Text = "No platform found within 480 studs"
        elseif not getRoot(player.Character) then
            status.Text = "Character not ready"
        end

        if token == tpUpToken then
            tpUpRunning = false
            button.Text = "TP Up"
        end
    end)
end

local function teleportToClosestPlayer()
    local myRoot = getRoot(player.Character)
    if not myRoot then
        status.Text = "Character not ready"
        return
    end

    local closestRoot = nil
    local closestName = nil
    local closestDistance = math.huge

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherCharacter = otherPlayer.Character
            local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
            local otherRoot = getRoot(otherCharacter)

            if otherRoot and (not otherHumanoid or otherHumanoid.Health > 0) then
                local distance = (otherRoot.Position - myRoot.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestRoot = otherRoot
                    closestName = otherPlayer.Name
                end
            end
        end
    end

    if closestRoot then
        myRoot.CFrame = closestRoot.CFrame * CFrame.new(0, 0, 3)
        status.Text = "Teleported near " .. closestName
    else
        status.Text = "No other player found"
    end
end

-- Create UI
gui = Instance.new("ScreenGui")
gui.Name = "SoulShadeUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(310, 660)
main.Position = UDim2.new(0.5, -155, 0.5, -330)
main.ClipsDescendants = true
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(115, 70, 155)
mainStroke.Thickness = 1.5
mainStroke.Parent = main

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 65)
header.BackgroundColor3 = Color3.fromRGB(31, 25, 40)
header.BorderSizePixel = 0
header.Active = true
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

-- Responsive scrolling content: compact on phones, full-sized on PC.
local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(0, 65)
content.Size = UDim2.new(1, 0, 1, -91)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = Color3.fromRGB(145, 105, 180)
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.CanvasSize = UDim2.new(0, 0, 0, 490)
content.AutomaticCanvasSize = Enum.AutomaticSize.None
content.Parent = main

local function updateResponsiveSize()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local mobile = UserInputService.TouchEnabled or viewport.X < 650
    local width = mobile and math.clamp(viewport.X - 20, 260, 310) or 310
    local height = math.clamp(viewport.Y - 24, 300, 660)
    main.Size = UDim2.fromOffset(width, height)
    main.Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2)
    content.Size = UDim2.new(1, 0, 1, -91)
end

updateResponsiveSize()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveSize)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then
        Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveSize)
        updateResponsiveSize()
    end
end)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -85, 0, 27)
title.Position = UDim2.fromOffset(12, 7)
title.BackgroundTransparency = 1
title.Text = "TSB Halloween 2026"
title.TextColor3 = Color3.fromRGB(245, 235, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Creator"
subtitle.Size = UDim2.new(1, -20, 0, 18)
subtitle.Position = UDim2.fromOffset(12, 36)
subtitle.BackgroundTransparency = 1
subtitle.Text = "By- @V3inn_wins"
subtitle.TextColor3 = Color3.fromRGB(180, 150, 205)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

-- Button creator
local function createButton(name, text, y, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(1, -24, 0, 36)
    button.Position = UDim2.fromOffset(12, y - 65)
    button.BackgroundColor3 = Color3.fromRGB(44, 38, 54)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Text = text
    button.TextColor3 = Color3.fromRGB(242, 237, 248)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 12
    button.Parent = content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    button.Activated:Connect(callback)

    return button
end

-- Minimize button
local minimize = Instance.new("TextButton")
minimize.Name = "Minimize"
minimize.Size = UDim2.fromOffset(27, 27)
minimize.Position = UDim2.new(1, -64, 0, 9)
minimize.BackgroundColor3 = Color3.fromRGB(69, 57, 84)
minimize.BorderSizePixel = 0
minimize.Text = "−"
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 16
minimize.Parent = header

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimize

-- Close button
local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.fromOffset(27, 27)
close.Position = UDim2.new(1, -33, 0, 9)
close.BackgroundColor3 = Color3.fromRGB(135, 48, 60)
close.BorderSizePixel = 0
close.Text = "×"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = close

-- Teleport to HalloweenDoorTrees
createButton(
    "TeleportToTarget",
    "Teleport to HalloweenDoorTrees",
    77,
    function()
        teleportToTarget()
    end
)

-- Auto teleport toggle
local autoButton
autoButton = createButton(
    "AutoTeleport",
    "Auto TP: OFF",
    120,
    function()
        autoTP = not autoTP
        autoTPToken += 1

        local token = autoTPToken
        autoButton.Text = autoTP and "Auto TP: ON" or "Auto TP: OFF"

        if autoTP then
            task.spawn(function()
                while autoTP and token == autoTPToken and not closed do
                    teleportToTarget()
                    task.wait(11)
                end
            end)
        end
    end
)

-- Instant interact toggle
-- Applies a client-side zero hold duration to prompts as they become visible.
-- The original value is retained until the feature is disabled so it can be restored.
local originalHoldDurations = {}

local function applyInstantInteract(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return
    end

    if originalHoldDurations[prompt] == nil then
        originalHoldDurations[prompt] = prompt.HoldDuration
    end

    prompt.HoldDuration = 0
end

local function restorePromptDurations()
    for prompt, original in pairs(originalHoldDurations) do
        if prompt and prompt.Parent then
            prompt.HoldDuration = original
        end
        originalHoldDurations[prompt] = nil
    end
end

local interactButton
interactButton = createButton(
    "InstantInteract",
    "Instant Interact: OFF",
    163,
    function()
        instantInteract = not instantInteract

        interactButton.Text = instantInteract
            and "Instant Interact: ON"
            or "Instant Interact: OFF"

        if instantInteract then
            -- Also handle prompts that already exist in the world.
            for _, object in ipairs(Workspace:GetDescendants()) do
                if object:IsA("ProximityPrompt") then
                    applyInstantInteract(object)
                end
            end
        else
            restorePromptDurations()
        end
    end
)

ProximityPromptService.PromptShown:Connect(function(prompt)
    if closed or not instantInteract then
        return
    end
    applyInstantInteract(prompt)
end)

-- Keep the saved original value while a prompt hides; it may show again.
ProximityPromptService.PromptHidden:Connect(function(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then
        return
    end

    if not instantInteract then
        local original = originalHoldDurations[prompt]
        if original ~= nil then
            if prompt.Parent then
                prompt.HoldDuration = original
            end
            originalHoldDurations[prompt] = nil
        end
    end
end)

Workspace.DescendantAdded:Connect(function(object)
    if instantInteract and object:IsA("ProximityPrompt") then
        applyInstantInteract(object)
    end
end)

-- TP Candy toggle
local candyButton
candyButton = createButton(
    "NearestCandy",
    "TP Candy: OFF",
    206,
    function()
        candyTPEnabled = not candyTPEnabled
        candyTPToken += 1

        local token = candyTPToken
        candyButton.Text = candyTPEnabled
            and "TP Candy: ON"
            or "TP Candy: OFF"

        if candyTPEnabled then
            task.spawn(function()
                while candyTPEnabled
                    and token == candyTPToken
                    and not closed do

                    teleportToNearestCandy()
                    task.wait(2)
                end
            end)
        end
    end
)

-- TP Up: keep stepping upward until a walkable platform is detected.
local tpUpButton
tpUpButton = createButton(
    "TPUp",
    "TP Up",
    421,
    function()
        startTPUp(tpUpButton)
    end
)

-- Teleport beside the nearest living player.
createButton(
    "TeleportClosestPlayer",
    "TP Closest Player",
    464,
    function()
        teleportToClosestPlayer()
    end
)

-- Teleport to Penyta (searches Workspace descendants by name).
local function findPenytaTarget()
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object.Name:lower():find("penyta", 1, true) then
            local part = getTargetPart(object)
            if part and part:IsDescendantOf(Workspace) then
                return part
            end
        end
    end
    return nil
end

createButton(
    "TeleportToPenyta",
    "Teleport to Penyta",
    507,
    function()
        local target = findPenytaTarget()
        if target then
            teleportToPosition(target.Position + Vector3.new(0, 4, 0))
            status.Text = "Teleported to Penyta"
        else
            status.Text = "Penyta not found in Workspace"
            warn("TSB Halloween: Could not find an object with 'Penyta' in its name.")
        end
    end
)

-- Reset character
createButton(
    "ResetCharacter",
    "Reset Character",
    249,
    function()
        local character = player.Character
        local humanoid =
            character and character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            humanoid.Health = 0
        end
    end
)

-- Jackpot Giver ESP toggle
local jackpotButton
jackpotButton = createButton(
    "JackpotGiverESP",
    "Jackpot Giver ESP: OFF",
    292,
    function()
        jackpotESPEnabled = not jackpotESPEnabled
        jackpotButton.Text = jackpotESPEnabled
            and "Jackpot Giver ESP: ON"
            or "Jackpot Giver ESP: OFF"

        if not jackpotESPEnabled then
            clearJackpotESP()
        else
            updateJackpotESP()
        end
    end
)

-- Regular Giver ESP toggle
local giverButton
giverButton = createButton(
    "GiverESP",
    "Giver ESP: OFF",
    335,
    function()
        giverESPEnabled = not giverESPEnabled
        giverButton.Text = giverESPEnabled and "Giver ESP: ON" or "Giver ESP: OFF"
        if not giverESPEnabled then clearGiverESP() else updateGiverESP() end
    end
)

-- TrashGuy ESP toggle
local trashGuyButton
trashGuyButton = createButton(
    "TrashGuyESP",
    "TrashGuy ESP: OFF",
    378,
    function()
        trashGuyESPEnabled = not trashGuyESPEnabled
        trashGuyButton.Text = trashGuyESPEnabled and "TrashGuy ESP: ON" or "TrashGuy ESP: OFF"
        if not trashGuyESPEnabled then clearTrashGuyESP() else updateTrashGuyESP() end
    end
)

-- Keep the ESP updated while enabled
task.spawn(function()
    while not closed do
        if jackpotESPEnabled then updateJackpotESP() end
        if giverESPEnabled then updateGiverESP() end
        if trashGuyESPEnabled then updateTrashGuyESP() end
        task.wait(0.5)
    end
end)

-- Status label
status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -24, 0, 20)
status.Position = UDim2.new(0, 12, 1, -23)
status.BackgroundTransparency = 1
status.Text = "Ground check enabled"
status.TextColor3 = Color3.fromRGB(165, 150, 180)
status.Font = Enum.Font.Gotham
status.TextSize = 10
status.Parent = main

-- Minimize / restore
minimize.Activated:Connect(function()
    guiVisible = not guiVisible

    for _, child in ipairs(main:GetChildren()) do
        if child ~= header
            and child ~= mainCorner
            and child ~= mainStroke then
            child.Visible = guiVisible
        end
    end

    if guiVisible then
        updateResponsiveSize()
    else
        main.Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 65)
    end

    minimize.Text = guiVisible and "−" or "+"
end)

-- Drag the window by the header
local dragging = false
local dragStart
local startPosition
local dragInput

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

local dragConnection
dragConnection = RunService.RenderStepped:Connect(function()
    if closed or not dragging or not dragInput then
        return
    end

    local delta = dragInput.Position - dragStart

    main.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end)

-- Close and cleanup
close.Activated:Connect(function()
    closed = true
    tpUpRunning = false
    tpUpToken += 1

    autoTP = false
    candyTPEnabled = false
    jackpotESPEnabled = false
    giverESPEnabled = false
    clearJackpotESP()
    clearGiverESP()
    trashGuyESPEnabled = false
    clearTrashGuyESP()

    autoTPToken += 1
    candyTPToken += 1

    for prompt, original in pairs(originalHoldDurations) do
        if prompt and prompt.Parent then
            prompt.HoldDuration = original
        end
    end

    if dragConnection then
        dragConnection:Disconnect()
    end

    gui:Destroy()
end)

print("TSB Halloween 2026 loaded with ESP, TP Up, TP Closest Player and Instant Interact.")
