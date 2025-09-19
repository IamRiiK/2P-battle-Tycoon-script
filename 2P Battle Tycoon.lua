-- 2P Battle Tycoon — Full (Modern Dark UI + Features + Safe cleanup)
-- Pastikan environment mendukung exploit-specific functions (firetouchinterest, VirtualInputManager) jika ingin AutoGrab/AutoE bekerja.

-------------------------
-- Services
-------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VIM = (pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager")) or nil

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-------------------------
-- Runtime / Feature toggles
-------------------------
local FEATURE = {
    ESP = false,
    AutoE = false,
    AutoEInterval = 0.5,
    AutoGrab = false,
    WalkEnabled = false,
    WalkValue = 16,
    Aimbot = false
}

-------------------------
-- Prevent duplicate GUI
-------------------------
local guiParent = LocalPlayer:WaitForChild("PlayerGui")
local EXISTING = guiParent:FindFirstChild("TPB_TycoonGUI")
if EXISTING then
    pcall(function() EXISTING:Destroy() end)
end

-------------------------
-- Utility: connections management
-------------------------
local connections = {}
local function addConnection(conn)
    if conn and typeof(conn) == "RBXScriptConnection" then
        table.insert(connections, conn)
    end
end
local function disconnectAll()
    for _,c in ipairs(connections) do
        if c and typeof(c) == "RBXScriptConnection" then
            pcall(function() c:Disconnect() end)
        end
    end
    connections = {}
end

-------------------------
-- UI: Modern Dark Theme
-------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TPB_TycoonGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = guiParent

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
MainFrame.Position = UDim2.new(0.28,0,0.18,0)
MainFrame.Size = UDim2.new(0,320,0,420)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true
local mainCorner = Instance.new("UICorner", MainFrame)
mainCorner.CornerRadius = UDim.new(0,12)
local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color = Color3.fromRGB(65,65,65)
mainStroke.Thickness = 1.5

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1,0,0,36)
TitleBar.Position = UDim2.new(0,0,0,0)
local titleGrad = Instance.new("UIGradient", TitleBar)
titleGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(42,42,42)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(25,25,25))
}
local titleCorner = Instance.new("UICorner", TitleBar)
titleCorner.CornerRadius = UDim.new(0,10)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(0.6,0,1,0)
Title.Position = UDim2.new(0,12,0,0)
Title.BackgroundTransparency = 1
Title.Text = "⚔️ 2P Battle Tycoon"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(245,245,245)
Title.TextXAlignment = Enum.TextXAlignment.Left

local HintLabel = Instance.new("TextLabel", TitleBar)
HintLabel.Size = UDim2.new(0.36, -44, 1, 0)
HintLabel.Position = UDim2.new(0.64, 0, 0, 0)
HintLabel.BackgroundTransparency = 1
HintLabel.Font = Enum.Font.Gotham
HintLabel.TextSize = 13
HintLabel.TextColor3 = Color3.fromRGB(170,170,170)
HintLabel.TextXAlignment = Enum.TextXAlignment.Right
HintLabel.Text = "Press LeftAlt to toggle UI"

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Size = UDim2.new(0,36,0,28)
MinBtn.Position = UDim2.new(1,-44,0,4)
MinBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.TextColor3 = Color3.fromRGB(250,250,250)
local minCorner = Instance.new("UICorner", MinBtn); minCorner.CornerRadius = UDim.new(0,8)
local minStroke = Instance.new("UIStroke", MinBtn); minStroke.Color = Color3.fromRGB(75,75,75); minStroke.Thickness = 1

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, -16, 1, -56)
Content.Position = UDim2.new(0,8,0,44)
Content.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", Content)
UIList.Padding = UDim.new(0,10)
UIList.SortOrder = Enum.SortOrder.LayoutOrder

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

UIS.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- helper: create toggle (modern)
local function createToggle(name, callback)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,38)
    btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 15
    btn.TextColor3 = Color3.fromRGB(235,235,235)
    btn.Text = name.." [OFF]"
    local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", btn); stroke.Color = Color3.fromRGB(70,70,70); stroke.Thickness = 1

    -- hover effects
    btn.MouseEnter:Connect(function() pcall(function() btn.BackgroundColor3 = Color3.fromRGB(46,46,46) end) end)
    btn.MouseLeave:Connect(function() pcall(function() btn.BackgroundColor3 = Color3.fromRGB(36,36,36) end) end)

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = name.." ["..(state and "ON" or "OFF").."]"
        if state then
            btn.BackgroundColor3 = Color3.fromRGB(56,96,56)
        else
            btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
        end
        callback(state)
    end)
    return btn
end

-- helper: create small frame + textbox (modern)
local function createLabeledTextbox(labelText, defaultText, placeholderText, onEnter)
    local frame = Instance.new("Frame", Content)
    frame.Size = UDim2.new(1,0,0,40)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.45, -8, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(0.55, 0, 1, 0)
    box.Position = UDim2.new(0.45, 8, 0, 0)
    box.BackgroundColor3 = Color3.fromRGB(30,30,30)
    box.TextColor3 = Color3.fromRGB(245,245,245)
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.Text = tostring(defaultText)
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left

    local corner = Instance.new("UICorner", box); corner.CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", box); stroke.Color = Color3.fromRGB(70,70,70); stroke.Thickness = 1

    local placeholder = Instance.new("TextLabel", box)
    placeholder.Size = UDim2.new(1,-10,1,0)
    placeholder.Position = UDim2.new(0,6,0,0)
    placeholder.BackgroundTransparency = 1
    placeholder.Font = Enum.Font.Gotham
    placeholder.TextSize = 13
    placeholder.TextColor3 = Color3.fromRGB(140,140,140)
    placeholder.Text = placeholderText
    placeholder.TextXAlignment = Enum.TextXAlignment.Left

    local function updatePlaceholder()
        placeholder.Visible = (box.Text == "")
    end
    box:GetPropertyChangedSignal("Text"):Connect(updatePlaceholder)
    box.Focused:Connect(updatePlaceholder)
    box.FocusLost:Connect(function(enter)
        updatePlaceholder()
        if enter and onEnter then
            onEnter(box.Text)
        end
    end)
    updatePlaceholder()
    return frame, box
end

-------------------------
-- Feature Implementations (safer)
-------------------------
-- connections container for ESP charAdded connections so they can be disconnected individually
local espCharConns = {}        -- player -> connection
local highlights = {}          -- player -> highlight instance

local function removeESPForPlayer(player)
    local h = highlights[player]
    if h then
        pcall(function() if h and h.Parent then h:Destroy() end end)
        highlights[player] = nil
    end
    local c = espCharConns[player]
    if c then
        pcall(function() c:Disconnect() end)
        espCharConns[player] = nil
    end
end

local function applyESPToCharacter(player, char)
    if not player or player == LocalPlayer or not char then return end
    removeESPForPlayer(player)
    pcall(function()
        local h = Instance.new("Highlight")
        h.Adornee = char
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.55
        if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            h.FillColor = Color3.fromRGB(20,120,70)
            h.OutlineColor = Color3.fromRGB(10,60,35)
        else
            h.FillColor = Color3.fromRGB(200,30,30)
            h.OutlineColor = Color3.fromRGB(120,10,10)
        end
        h.Parent = char
        highlights[player] = h
    end)
end

local function applyESPToPlayer(player)
    if not player or player == LocalPlayer then return end
    if player.Character then
        pcall(function() applyESPToCharacter(player, player.Character) end)
    end
    -- CharacterAdded connection per player (so we can disconnect when removing ESP)
    local c = player.CharacterAdded:Connect(function(cchar)
        pcall(function() applyESPToCharacter(player, cchar) end)
    end)
    espCharConns[player] = c
    addConnection(c)
end

local function enableESP()
    for _,p in ipairs(Players:GetPlayers()) do
        applyESPToPlayer(p)
    end
    local connAdded = Players.PlayerAdded:Connect(function(p)
        applyESPToPlayer(p)
    end)
    local connRemoving = Players.PlayerRemoving:Connect(function(p)
        removeESPForPlayer(p)
    end)
    addConnection(connAdded); addConnection(connRemoving)
end

local function disableESP()
    for p,_ in pairs(highlights) do
        removeESPForPlayer(p)
    end
    highlights = {}
end

-- Auto Press E
local hasVIM = (type(VIM) == "table" or type(VIM) == "userdata")
local autoEThread = nil
local function startAutoE()
    if autoEThread then return end
    autoEThread = task.spawn(function()
        while FEATURE.AutoE do
            if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                pcall(function()
                    if hasVIM then
                        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    else
                        -- no VIM available; no-op
                    end
                end)
            end
            task.wait(math.clamp(FEATURE.AutoEInterval or 0.5, 0.05, 5))
        end
        autoEThread = nil
    end)
end

-- Auto Grab Weapon
local toolGiverNames = {
    "ToolGiver1P1","ToolGiver1P2","ToolGiver2P1",
    "ToolGiver3P1","ToolGiver3P2","ToolGiver4P1","ToolGiver4P2",
    "ToolGiver5","ToolGiver5P1","ToolGiver5P2",
    "ToolGiver6P1","ToolGiver6P2","ToolGiver7P1","ToolGiver7P2",
    "ToolGiver8P1","ToolGiver8P2","ToolGiver9P1","ToolGiver9P2",
    "ToolGiver10P1","ToolGiver10P2","ToolGiver11P1","ToolGiver11P2",
    "ToolGiver12P1","ToolGiver12P2","ToolGiver13P1","ToolGiver13P2",
    "ToolGiver14P1","ToolGiver14P2","ToolGiver100"
}
local hasFireTouch = (type(firetouchinterest) == "function")
local autoGrabThread = nil

local function touchPartSafely(part, root)
    if not part or not root then return end
    if hasFireTouch then
        pcall(function()
            firetouchinterest(part, root, 0)
            firetouchinterest(part, root, 1)
        end)
    else
        -- fallback: brief teleport if allowed (small distance)
        pcall(function()
            local old = root.CFrame
            root.CFrame = part.CFrame + Vector3.new(0,2,0)
            task.wait(0.06)
            root.CFrame = old
        end)
    end
end

local function startAutoGrab()
    if autoGrabThread then return end
    autoGrabThread = task.spawn(function()
        while FEATURE.AutoGrab do
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and Workspace:FindFirstChild("Tycoons") then
                for _,tycoon in ipairs(Workspace.Tycoons:GetChildren()) do
                    local purchased = tycoon:FindFirstChild("PurchasedObjects")
                    if purchased then
                        for _,name in ipairs(toolGiverNames) do
                            local giver = purchased:FindFirstChild(name)
                            if giver and giver:FindFirstChild("Touch") and giver.Touch:IsA("BasePart") then
                                pcall(function() touchPartSafely(giver.Touch, root) end)
                            end
                        end
                    end
                end
            end
            task.wait(1)
        end
        autoGrabThread = nil
    end)
end

-- WalkSpeed safer enforcement
local walkThread = nil
local function startWalk()
    if walkThread then return end
    walkThread = task.spawn(function()
        while FEATURE.WalkEnabled do
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                if hum.WalkSpeed ~= FEATURE.WalkValue then
                    pcall(function() hum.WalkSpeed = FEATURE.WalkValue end)
                end
            end
            task.wait(0.4)
        end
        walkThread = nil
    end)
end

-- Aimbot (RenderStepped, smooth)
local AIM_LERP = 0.28
local AIM_THRESHOLD = math.rad(35)

local function angleBetween(v1, v2)
    if not v1 or not v2 then return math.pi end
    local denom = (v1.Magnitude * v2.Magnitude)
    if denom == 0 then return math.pi end
    return math.acos(math.clamp(v1:Dot(v2) / denom, -1, 1))
end

local function getClosestEnemy()
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    local closest = nil
    local shortest = math.huge
    local myPos = myChar.HumanoidRootPart.Position
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Team ~= LocalPlayer.Team and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local root = plr.Character.HumanoidRootPart
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (root.Position - myPos).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = plr
                end
            end
        end
    end
    return closest
end

-- connect a single RenderStepped to handle aimbot smoothly
local renderConn = RunService.RenderStepped:Connect(function()
    if FEATURE.Aimbot then
        local target = getClosestEnemy()
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local camCF = Camera.CFrame
            local camDir = camCF.LookVector
            local dirVec = (target.Character.HumanoidRootPart.Position - camCF.Position)
            if dirVec.Magnitude > 0 then
                local dir = dirVec.Unit
                if angleBetween(camDir, dir) < AIM_THRESHOLD then
                    local desired = CFrame.new(camCF.Position, camCF.Position + dir)
                    local lerped = camCF:Lerp(desired, AIM_LERP)
                    pcall(function() Camera.CFrame = lerped end)
                end
            end
        end
    end
end)
addConnection(renderConn)

-- hotkey F1 toggles aimbot
local hotF1 = UIS.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.F1 then
        FEATURE.Aimbot = not FEATURE.Aimbot
    end
end)
addConnection(hotF1)

-------------------------
-- UI Controls wired to features
-------------------------
-- ESP toggle
createToggle("ESP", function(val)
    FEATURE.ESP = val
    if val then
        enableESP()
    else
        disableESP()
        -- also remove per-player char conns for cleanliness
        for p,_ in pairs(espCharConns) do
            if espCharConns[p] then
                pcall(function() espCharConns[p]:Disconnect() end)
                espCharConns[p] = nil
            end
        end
    end
end)

-- Auto Press E toggle + interval box
createToggle("Auto Press E", function(val)
    FEATURE.AutoE = val
    if val then startAutoE() end
end)
do
    local _, box = createLabeledTextbox("AutoE Interval (s)", FEATURE.AutoEInterval, "0.05–5 (default 0.5)", function(text)
        local n = tonumber(text)
        if n and n >= 0.05 and n <= 5 then
            FEATURE.AutoEInterval = n
        else
            FEATURE.AutoEInterval = 0.5
        end
    end)
end

-- Auto Grab toggle
createToggle("Auto Grab Weapon", function(val)
    FEATURE.AutoGrab = val
    if val then startAutoGrab() end
end)

-- WalkSpeed toggle + box
createToggle("WalkSpeed Enabled", function(val)
    FEATURE.WalkEnabled = val
    if val then startWalk() end
end)
do
    local _, box = createLabeledTextbox("WalkSpeed", FEATURE.WalkValue, "16–200 (rec 25–40)", function(text)
        local n = tonumber(text)
        if n and n >= 16 and n <= 200 then
            FEATURE.WalkValue = n
            -- immediate set if humanoid present
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.WalkSpeed = n end) end
        else
            FEATURE.WalkValue = 16
        end
    end)
end

-- Aimbot toggle (note: F1 also toggles)
createToggle("Aimbot (F1 hotkey)", function(val)
    FEATURE.Aimbot = val
end)

-- Close & Cleanup button
do
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,40)
    btn.BackgroundColor3 = Color3.fromRGB(190,90,90)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.TextColor3 = Color3.fromRGB(20,20,20)
    btn.Text = "Close & Cleanup"
    local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0,8)
    btn.MouseButton1Click:Connect(function()
        -- disable features
        FEATURE.AutoE = false
        FEATURE.AutoGrab = false
        FEATURE.WalkEnabled = false
        FEATURE.ESP = false
        FEATURE.Aimbot = false
        -- cleanup ESP visuals
        disableESP()
        -- disconnect everything
        disconnectAll()
        -- destroy gui
        pcall(function() ScreenGui:Destroy() end)
    end)
end

-------------------------
-- Respawn handling & safety
-------------------------
-- Ensure walk speed reapplied on respawn if enabled
local charAddedConn = LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.15)
    if FEATURE.WalkEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.WalkSpeed = FEATURE.WalkValue end) end
    end
end)
addConnection(charAddedConn)

-- keep references tidy when player leaves/join (optional cleanup)
local playersRemovingConn = Players.PlayerRemoving:Connect(function(p)
    removeESPForPlayer(p)
end)
addConnection(playersRemovingConn)

-------------------------
-- Final notes (in-code)
-------------------------
-- This script bundles UI + features. Some features (AutoE, AutoGrab) rely on exploit-specific APIs:
--  - VirtualInputManager (for VIM:SendKeyEvent) and firetouchinterest. They are used inside pcall so absence won't break the script.
-- Aimbot overrides Camera.CFrame — some camera scripts may fight with it.
-- Use responsibly; modifying game state may violate rules/ToS for the platform or server.
