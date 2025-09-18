-- 2P battle Tycoon - Final Revised
-- UI (light), draggable + minimize, ESP (Highlight body), Auto E fixed, AutoGrab, Walkspeed, Smooth Aimbot (F1)

-- Services & refs
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Remove any previous UI
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("RiiK_CustomUI") then
    playerGui.RiiK_CustomUI:Destroy()
end

-- MAIN UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RiiK_CustomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.Size = UDim2.new(0, 320, 0, 420)
MainFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(245,245,245) -- light theme
MainFrame.BorderSizePixel = 1
MainFrame.ClipsDescendants = true

local UI_Corner = Instance.new("UICorner", MainFrame)
UI_Corner.CornerRadius = UDim.new(0,8)

-- Title bar (kept visible when minimize)
local TitleBar = Instance.new("Frame")
TitleBar.Parent = MainFrame
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Color3.fromRGB(230,230,230)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = TitleBar
TitleLabel.Size = UDim2.new(1, -90, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 18
TitleLabel.TextColor3 = Color3.fromRGB(10,10,10)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Text = "2P battle Tycoon"

local MinBtn = Instance.new("TextButton")
MinBtn.Parent = TitleBar
MinBtn.Size = UDim2.new(0, 40, 0, 28)
MinBtn.Position = UDim2.new(1, -84, 0, 4)
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.SourceSansBold
MinBtn.TextSize = 18
MinBtn.BackgroundColor3 = Color3.fromRGB(210,210,210)
MinBtn.TextColor3 = Color3.fromRGB(10,10,10)
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,6)

-- Keep a small "Restore" area if totally minimized; we will only minimize content,
-- title bar will remain clickable. No separate "close" button to avoid accidental hiding.

-- Content container
local Content = Instance.new("Frame")
Content.Parent = MainFrame
Content.Position = UDim2.new(0, 8, 0, 44)
Content.Size = UDim2.new(1, -16, 1, -52)
Content.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", Content)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0,8)

-- small footer area (kept hidden if minimized)
local Footer = Instance.new("Frame")
Footer.Parent = MainFrame
Footer.Size = UDim2.new(1, -16, 0, 36)
Footer.Position = UDim2.new(0, 8, 1, -44)
Footer.BackgroundTransparency = 1

-- Helper: create toggle button (text toggles [OFF]/[ON])
local function createToggle(name, init, callback)
    local btn = Instance.new("TextButton")
    btn.Parent = Content
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(235,235,235)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 16
    btn.TextColor3 = Color3.fromRGB(10,10,10)
    btn.AutoButtonColor = true
    local state = init and true or false
    btn.Text = (state and "[X] " or "[ ] ") .. name
    -- click toggles
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = (state and "[X] " or "[ ] ") .. name
        pcall(callback, state)
    end)
    return btn
end

-- Helper: create textbox (label + box)
local function createTextbox(labelText, default)
    local frame = Instance.new("Frame")
    frame.Parent = Content
    frame.Size = UDim2.new(1, 0, 0, 34)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.Size = UDim2.new(0.5, -8, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSans
    label.TextSize = 15
    label.TextColor3 = Color3.fromRGB(10,10,10)
    label.Text = labelText

    local box = Instance.new("TextBox")
    box.Parent = frame
    box.Size = UDim2.new(0.5, 0, 1, 0)
    box.Position = UDim2.new(0.5, 8, 0, 0)
    box.BackgroundColor3 = Color3.fromRGB(255,255,255)
    box.TextColor3 = Color3.fromRGB(10,10,10)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 15
    box.Text = default or ""
    box.ClearTextOnFocus = false

    return box
end

-- Minimize behavior: hide Content & Footer, keep TitleBar visible
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    Footer.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
    -- shrink/expand frame height
    MainFrame.Size = minimized and UDim2.new(0, 320, 0, 46) or UDim2.new(0, 320, 0, 420)
end)

-- Dragging (TitleBar) - robust implementation
do
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

-- ============================
-- Feature states
-- ============================
local FEATURE = {
    ESP = false,
    AutoE = false,
    AutoGrab = false,
    WalkToggle = false,
    WalkValue = 16,
    Aimbot = false
}

-- Colors for ESP: friend & enemy per request
local FRIEND_COLOR = Color3.fromRGB(13,71,21)
local ENEMY_COLOR  = Color3.fromRGB(205,24,24) -- updated per request

-- Helper: safe apply Highlight to character (robust for various rigs)
local function applyHighlightToCharacter(char, isFriend)
    if not char or not char.Parent then return end
    -- remove old if exists
    if char:FindFirstChild("ESP_HL") then
        char.ESP_HL:Destroy()
    end

    -- create Highlight and set Adornee to the model (works for R6/R15)
    local ok, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Name = "ESP_HL"
        h.Adornee = char
        h.FillTransparency = 0.5
        h.OutlineTransparency = 0
        if isFriend then
            h.FillColor = FRIEND_COLOR
            h.OutlineColor = FRIEND_COLOR
        else
            h.FillColor = ENEMY_COLOR
            h.OutlineColor = ENEMY_COLOR
        end
        h.Parent = char
        return h
    end)
    -- if pcall failed, try adornee fallback to first BasePart (best-effort)
    if not ok then
        pcall(function()
            local firstPart
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    firstPart = part
                    break
                end
            end
            if firstPart then
                local h2 = Instance.new("Highlight")
                h2.Name = "ESP_HL"
                h2.Adornee = firstPart
                h2.FillTransparency = 0.5
                h2.OutlineTransparency = 0
                if isFriend then
                    h2.FillColor = FRIEND_COLOR
                    h2.OutlineColor = FRIEND_COLOR
                else
                    h2.FillColor = ENEMY_COLOR
                    h2.OutlineColor = ENEMY_COLOR
                end
                h2.Parent = char
            end
        end)
    end
end

local function removeHighlightFromCharacter(char)
    if not char then return end
    local ex = char:FindFirstChild("ESP_HL")
    if ex then
        pcall(function() ex:Destroy() end)
    end
end

-- Apply or remove ESP for all players depending on FEATURE.ESP
local function refreshAllESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if FEATURE.ESP then
                applyHighlightToCharacter(plr.Character, plr.Team == LocalPlayer.Team)
            else
                removeHighlightFromCharacter(plr.Character)
            end
        end
    end
end

-- Player join/char events to auto-apply ESP
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.6)
        if FEATURE.ESP then
            applyHighlightToCharacter(char, plr.Team == LocalPlayer.Team)
        end
    end)
end)
Players.PlayerRemoving:Connect(function(plr)
    if plr.Character then removeHighlightFromCharacter(plr.Character) end
end)

-- ============================
-- UI Elements (in requested order)
-- ============================
-- 1) ESP toggle
createToggle("ESP", FEATURE.ESP, function(state)
    FEATURE.ESP = state
    refreshAllESP()
end)

-- 2) Auto Press E
createToggle("Auto Press E", FEATURE.AutoE, function(state)
    FEATURE.AutoE = state
    if state then
        -- spawn auto press loop
        task.spawn(function()
            while FEATURE.AutoE do
                -- try VirtualInputManager first
                local ok, vim = pcall(function() return game:GetService("VirtualInputManager") end)
                if ok and vim then
                    pcall(function()
                        vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end)
                else
                    -- fallback: try to trigger ProximityPrompts nearby (best-effort, pcall to avoid errors)
                    pcall(function()
                        for _, obj in ipairs(Workspace:GetDescendants()) do
                            if obj:IsA("ProximityPrompt") then
                                -- attempt Triggered event simulation (may not work on all clients)
                                pcall(function()
                                    obj:InputHoldBegin()
                                    task.wait(0.05)
                                    obj:InputHoldEnd()
                                end)
                            end
                        end
                    end)
                end
                task.wait(0.5)
            end
        end)
    end
end)

-- 3) Auto Grab Weapon
createToggle("Auto Grab Weapon", FEATURE.AutoGrab, function(state)
    FEATURE.AutoGrab = state
    if state then
        task.spawn(function()
            local toolGiverNames = {
                "ToolGiver1P1","ToolGiver1P2","ToolGiver2P1","ToolGiver3P1","ToolGiver3P2",
                "ToolGiver4P1","ToolGiver4P2","ToolGiver5","ToolGiver5P1","ToolGiver5P2",
                "ToolGiver6P1","ToolGiver6P2","ToolGiver7P1","ToolGiver7P2","ToolGiver8P1","ToolGiver8P2",
                "ToolGiver9P1","ToolGiver9P2","ToolGiver10P1","ToolGiver10P2","ToolGiver11P1","ToolGiver11P2",
                "ToolGiver12P1","ToolGiver12P2","ToolGiver13P1","ToolGiver13P2","ToolGiver14P1","ToolGiver14P2",
                "ToolGiver100"
            }
            local TycoonsFolder = Workspace:FindFirstChild("Tycoons")
            while FEATURE.AutoGrab do
                if TycoonsFolder and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local root = LocalPlayer.Character.HumanoidRootPart
                    for _, ty in ipairs(TycoonsFolder:GetChildren()) do
                        local purchased = ty:FindFirstChild("PurchasedObjects")
                        if purchased then
                            for _, name in ipairs(toolGiverNames) do
                                local giver = purchased:FindFirstChild(name)
                                if giver and giver:FindFirstChild("Touch") then
                                    pcall(function()
                                        firetouchinterest(giver.Touch, root, 0)
                                        firetouchinterest(giver.Touch, root, 1)
                                    end)
                                end
                            end
                        end
                    end
                end
                task.wait(1.2)
            end
        end)
    end
end)

-- 4) Toggle Walkspeed
createToggle("Use WalkSpeed", FEATURE.WalkToggle, function(state)
    FEATURE.WalkToggle = state
end)

-- 5) Input Walkspeed (textbox)
local walkBox = createTextbox("WalkSpeed (number)", tostring(FEATURE.WalkValue))
walkBox.FocusLost:Connect(function(enter)
    if not enter then return end
    local n = tonumber(walkBox.Text)
    if n and n > 0 then
        FEATURE.WalkValue = n
        walkBox.Text = tostring(n)
    else
        walkBox.Text = tostring(FEATURE.WalkValue)
    end
end)

-- 6) Aimbot toggle (UI) — keep hotkey F1
createToggle("Aimbot (F1)", FEATURE.Aimbot, function(state)
    FEATURE.Aimbot = state
end)

-- Hotkey F1 toggles Aimbot as well
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        FEATURE.Aimbot = not FEATURE.Aimbot
        -- find the aimbot toggle button (last created toggles) and update its text to match (best-effort)
        for _, child in ipairs(Content:GetChildren()) do
            if child:IsA("TextButton") and child.Text and child.Text:find("Aimbot") then
                child.Text = (FEATURE.Aimbot and "[X] " or "[ ] ") .. "Aimbot (F1)"
                break
            end
        end
    end
end)

-- ============================
-- Core loops: WalkSpeed, Aimbot (smooth + angle threshold), ensure ESP upkeep
-- ============================
-- WalkSpeed loop
RunService.Heartbeat:Connect(function()
    if FEATURE.WalkToggle and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        pcall(function()
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = tonumber(FEATURE.WalkValue) or 16
        end)
    else
        -- attempt to reset to default 16 (safe)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            pcall(function()
                if LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed ~= 16 then
                    LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
                end
            end)
        end
    end
end)

-- Aimbot params
local AIM_LERP = 0.3           -- more responsive
local AIM_THRESHOLD_RAD = math.rad(35) -- 35 degrees threshold

local function angleBetween(u, v)
    return math.acos(math.clamp(u:Dot(v) / ( (u.Magnitude>0 and u.Magnitude) * (v.Magnitude>0 and v.Magnitude) ), -1, 1))
end

local function findClosestValidTarget(maxDist)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    local closest, shortest = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Team ~= LocalPlayer.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (plr.Character.HumanoidRootPart.Position - myPos).Magnitude
                if dist < shortest and (not maxDist or dist <= maxDist) then
                    shortest, closest = dist, plr
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    -- Ensure ESP is up-to-date for existing characters
    if FEATURE.ESP then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and not plr.Character:FindFirstChild("ESP_HL") then
                -- small delay to allow parts to exist
                pcall(function()
                    applyHighlightToCharacter(plr.Character, plr.Team == LocalPlayer.Team)
                end)
            end
        end
    end

    -- Aimbot smooth behavior
    if FEATURE.Aimbot and Camera and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local target = findClosestValidTarget(300) -- consider up to 300 studs
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local camCF = Camera.CFrame
            local camDir = camCF.LookVector
            local dirToTarget = (target.Character.HumanoidRootPart.Position - camCF.Position)
            if dirToTarget.Magnitude > 0 then
                dirToTarget = dirToTarget.Unit
                local ang = angleBetween(camDir, dirToTarget)
                if ang <= AIM_THRESHOLD_RAD then
                    local goal = CFrame.new(camCF.Position, camCF.Position + dirToTarget)
                    Camera.CFrame = camCF:Lerp(goal, AIM_LERP)
                end
            end
        end
    end
end)
