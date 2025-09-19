-- 2P Battle Tycoon — Full Final Script (with ESP auto-update on team change)
-- Dark UI + HUD (show only when UI hidden) + ESP(team colors auto-update) + AutoE + WalkSpeed + Aimbot (FOV=8, Lerp=0.4)
-- Hotkeys: F1=ESP, F2=AutoE, F3=Walk toggle, F4=Aimbot toggle

-- Ensure game loaded
if not game:IsLoaded() then game.Loaded:Wait() end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace:WaitForChild("CurrentCamera")

-- Optional exploit API (pcall-protected)
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- Feature state
local FEATURE = {
    ESP = false,
    AutoE = false,
    AutoEInterval = 0.5,
    WalkEnabled = false,
    WalkValue = 25,
    Aimbot = false,
    AIM_FOV_DEG = 8,
    AIM_LERP = 0.4,
}

-- Cleanup existing GUI (if any)
local EXIST = PlayerGui:FindFirstChild("TPB_TycoonGUI_Final")
if EXIST then pcall(function() EXIST:Destroy() end) end
local HUD_EXIST = PlayerGui:FindFirstChild("TPB_TycoonHUD_Final")
if HUD_EXIST then pcall(function() HUD_EXIST:Destroy() end) end

-- ---------- UI BUILD ----------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TPB_TycoonGUI_Final"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,360,0,460)
MainFrame.Position = UDim2.new(0.28,0,0.18,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1,0,0,40)
TitleBar.Position = UDim2.new(0,0,0,0)
TitleBar.BackgroundColor3 = Color3.fromRGB(42,42,45)
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0,12)

local DragHandle = Instance.new("TextLabel", TitleBar)
DragHandle.Size = UDim2.new(0,28,0,28)
DragHandle.Position = UDim2.new(0,8,0,6)
DragHandle.BackgroundTransparency = 1
DragHandle.Font = Enum.Font.Gotham
DragHandle.Text = "≡"
DragHandle.TextSize = 20
DragHandle.TextColor3 = Color3.fromRGB(200,200,200)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(0.6,0,1,0)
Title.Position = UDim2.new(0.07,0,0,0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(245,245,245)
Title.Text = "⚔️ 2P Battle Tycoon"
Title.TextXAlignment = Enum.TextXAlignment.Left

local HintLabel = Instance.new("TextLabel", TitleBar)
HintLabel.Size = UDim2.new(0.36,-60,1,0)
HintLabel.Position = UDim2.new(0.64,0,0,0)
HintLabel.BackgroundTransparency = 1
HintLabel.Font = Enum.Font.Gotham
HintLabel.TextSize = 12
HintLabel.TextColor3 = Color3.fromRGB(170,170,170)
HintLabel.Text = "LeftAlt = Hide UI"
HintLabel.TextXAlignment = Enum.TextXAlignment.Right

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Size = UDim2.new(0,38,0,28)
MinBtn.Position = UDim2.new(1,-46,0,6)
MinBtn.BackgroundColor3 = Color3.fromRGB(58,58,60)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 20
MinBtn.TextColor3 = Color3.fromRGB(240,240,240)
MinBtn.Text = "-"
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,8)

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, -16, 1, -56)
Content.Position = UDim2.new(0,8,0,48)
Content.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", Content)
UIList.Padding = UDim.new(0,12)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- ---------- HUD (bottom-right, shows only when UI hidden) ----------
local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "TPB_TycoonHUD_Final"
HUDGui.ResetOnSpawn = false
HUDGui.Parent = PlayerGui

local HUD = Instance.new("Frame", HUDGui)
HUD.Size = UDim2.new(0,220,0,110)
HUD.Position = UDim2.new(1,-230,1,-140) -- kanan bawah
HUD.BackgroundColor3 = Color3.fromRGB(20,20,20)
HUD.BackgroundTransparency = 0.06
HUD.BorderSizePixel = 0
HUD.Visible = false
Instance.new("UICorner", HUD).CornerRadius = UDim.new(0,8)

local HUDList = Instance.new("UIListLayout", HUD)
HUDList.Padding = UDim.new(0,4)
HUDList.SortOrder = Enum.SortOrder.LayoutOrder

local hudLabels = {}
local function hudAdd(name)
    local l = Instance.new("TextLabel", HUD)
    l.Size = UDim2.new(1,-12,0,20)
    l.Position = UDim2.new(0,8,0,0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    l.TextSize = 14
    l.TextColor3 = Color3.fromRGB(220,220,220)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = name .. ": OFF"
    hudLabels[name] = l
end

-- Names must match registerToggle's displayName
hudAdd("ESP")
hudAdd("Auto Press E")
hudAdd("WalkSpeed Enabled")
hudAdd("Aimbot")

local function updateHUD(name, state)
    if hudLabels[name] then
        hudLabels[name].Text = name .. ": " .. (state and "ON" or "OFF")
        hudLabels[name].TextColor3 = state and Color3.fromRGB(80,200,120) or Color3.fromRGB(200,200,200)
    end
end

-- LeftAlt hide/show sync HUD visibility
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
        HUD.Visible = not MainFrame.Visible
    end
end)

-- ---------- UI helper: registerToggle (sync) ----------
local ToggleCallbacks = {}
local function registerToggle(displayName, featureKey, onChange)
    local btn = Instance.new("TextButton", Content)
    btn.Size = UDim2.new(1,0,0,36)
    btn.BackgroundColor3 = Color3.fromRGB(36,36,36)
    btn.TextColor3 = Color3.fromRGB(235,235,235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 15
    btn.Text = displayName .. " [OFF]"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

    local function setState(state)
        FEATURE[featureKey] = state
        btn.Text = displayName .. " [" .. (state and "ON" or "OFF") .. "]"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)
        updateHUD(displayName, state)
        if type(onChange) == "function" then
            pcall(onChange, state)
        end
    end

    btn.MouseEnter:Connect(function()
        pcall(function() TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(46,46,46)}):Play() end)
    end)
    btn.MouseLeave:Connect(function()
        pcall(function() TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = FEATURE[featureKey] and Color3.fromRGB(80,150,220) or Color3.fromRGB(36,36,36)}):Play() end)
    end)

    btn.MouseButton1Click:Connect(function()
        setState(not FEATURE[featureKey])
    end)

    ToggleCallbacks[featureKey] = setState
    return btn
end

-- ---------- Features implementation ----------

-- ESP storage
local espHighlights = {}   -- map player -> highlight
local espCharConns = {}    -- map player -> CharacterAdded connection
local espTeamConns = {}    -- map player -> Team property changed connection

local function refreshESPColorForPlayer(player)
    -- adjust highlight color for a single player according to teams
    local h = espHighlights[player]
    if not h then return end
    if player.Team and LocalPlayer.Team then
        if player.Team == LocalPlayer.Team then
            h.FillColor = Color3.fromRGB(24,205,24) -- ally
            pcall(function() h.OutlineColor = Color3.fromRGB(10,80,30) end)
        else
            h.FillColor = Color3.fromRGB(205,24,24) -- enemy
            pcall(function() h.OutlineColor = Color3.fromRGB(120,10,10) end)
        end
    else
        h.FillColor = Color3.fromRGB(150,150,150) -- neutral
        pcall(function() h.OutlineColor = Color3.fromRGB(100,100,100) end)
    end
end

local function refreshAllESPColors()
    for player, _ in pairs(espHighlights) do
        pcall(function() refreshESPColorForPlayer(player) end)
    end
end

local function removeESPForPlayer(player)
    if espHighlights[player] then
        pcall(function() if espHighlights[player].Parent then espHighlights[player]:Destroy() end end)
        espHighlights[player] = nil
    end
    if espCharConns[player] then
        pcall(function() espCharConns[player]:Disconnect() end)
        espCharConns[player] = nil
    end
    if espTeamConns[player] then
        pcall(function() espTeamConns[player]:Disconnect() end)
        espTeamConns[player] = nil
    end
end

local function applyESPToCharacter(player, character)
    if not player or player == LocalPlayer or not character then return end
    removeESPForPlayer(player)
    pcall(function()
        local h = Instance.new("Highlight")
        h.Adornee = character
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.55
        -- initial color based on team
        if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            h.FillColor = Color3.fromRGB(24,205,24)
            h.OutlineColor = Color3.fromRGB(10,80,30)
        elseif player.Team and LocalPlayer.Team and player.Team ~= LocalPlayer.Team then
            h.FillColor = Color3.fromRGB(205,24,24)
            h.OutlineColor = Color3.fromRGB(120,10,10)
        else
            h.FillColor = Color3.fromRGB(150,150,150)
            h.OutlineColor = Color3.fromRGB(100,100,100)
        end
        h.Parent = character
        espHighlights[player] = h
    end)
end

local function onPlayerTeamChanged(player)
    -- refresh highlight color for that player
    pcall(function() refreshESPColorForPlayer(player) end)
end

local function applyESP(player)
    if not player or player == LocalPlayer then return end
    if player.Character then
        pcall(function() applyESPToCharacter(player, player.Character) end)
    end
    -- connect character added
    if espCharConns[player] then pcall(function() espCharConns[player]:Disconnect() end) end
    espCharConns[player] = player.CharacterAdded:Connect(function(char)
        pcall(function() applyESPToCharacter(player, char) end)
    end)
    -- connect team change for this player
    if espTeamConns[player] then pcall(function() espTeamConns[player]:Disconnect() end) end
    espTeamConns[player] = player:GetPropertyChangedSignal("Team"):Connect(function()
        pcall(function() onPlayerTeamChanged(player) end)
    end)
end

local function enableESP()
    for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
    Players.PlayerAdded:Connect(function(plr) applyESP(plr) end)
    Players.PlayerRemoving:Connect(function(plr) removeESPForPlayer(plr) end)
    -- Also watch local player's team change so we can refresh all colors
    pcall(function()
        if LocalPlayer_Conn then LocalPlayer_Conn:Disconnect() end
    end)
end

-- connect LocalPlayer team change to refresh all ESP colors
local localTeamConn = LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    -- small delay to ensure other player.Team updates have propagated
    task.defer(function()
        pcall(function() refreshAllESPColors() end)
    end)
end)

local function disableESP()
    for p,_ in pairs(espHighlights) do removeESPForPlayer(p) end
end

-- Auto Press E (uses VIM if available)
local autoEThread = nil
local function startAutoE()
    if autoEThread then return end
    autoEThread = task.spawn(function()
        while FEATURE.AutoE do
            pcall(function()
                if VIM then
                    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end
            end)
            task.wait(math.clamp(FEATURE.AutoEInterval or 0.5, 0.05, 5))
        end
        autoEThread = nil
    end)
end

-- WalkSpeed
local walkThread = nil
local function startWalk()
    if walkThread then return end
    walkThread = task.spawn(function()
        while FEATURE.WalkEnabled do
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.WalkSpeed = FEATURE.WalkValue end) end
            task.wait(0.25)
        end
        walkThread = nil
    end)
end

-- Aimbot (sniper-style: pick target by angle to camera, aim at head if possible)
local function angleBetween(v1,v2)
    if not v1 or not v2 then return math.pi end
    local denom = (v1.Magnitude * v2.Magnitude)
    if denom == 0 then return math.pi end
    return math.acos(math.clamp(v1:Dot(v2) / denom, -1, 1))
end

local function getBestTargetByAngle()
    local camCF = Camera.CFrame
    local camPos = camCF.Position
    local camDir = camCF.LookVector
    local best, bestPart, bestAng = nil, nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local cand = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
                if cand then
                    local dir = cand.Position - camPos
                    if dir.Magnitude > 0 then
                        local ang = angleBetween(camDir, dir.Unit)
                        if ang < bestAng then
                            bestAng = ang
                            best = plr
                            bestPart = cand
                        end
                    end
                end
            end
        end
    end
    return best, bestPart, bestAng
end

local aimConn = RunService.RenderStepped:Connect(function()
    if FEATURE.Aimbot then
        local target, part, ang = getBestTargetByAngle()
        if target and part and ang then
            local fovRad = math.rad(FEATURE.AIM_FOV_DEG or 8)
            if ang <= fovRad then
                local camCF = Camera.CFrame
                local dir = (part.Position - camCF.Position)
                if dir.Magnitude > 0 then
                    local desired = CFrame.new(camCF.Position, camCF.Position + dir.Unit)
                    local lerpAmt = FEATURE.AIM_LERP or 0.4
                    local newCF = camCF:Lerp(desired, lerpAmt)
                    pcall(function() Camera.CFrame = newCF end)
                end
            end
        end
    end
end)

-- ---------- Register toggles & UI controls ----------
-- We use displayName strings that match hud labels
local btnESP = registerToggle("ESP", "ESP", function(state)
    if state then
        for _,p in ipairs(Players:GetPlayers()) do applyESP(p) end
    else
        disableESP()
    end
end)

local btnAutoE = registerToggle("Auto Press E", "AutoE", function(state)
    if state then startAutoE() end
end)

local btnWalk = registerToggle("WalkSpeed Enabled", "WalkEnabled", function(state)
    if state then startWalk() end
end)

local btnAim = registerToggle("Aimbot", "Aimbot", function(state) end)

-- WalkSpeed input box with placeholder
do
    local frame = Instance.new("Frame", Content)
    frame.Size = UDim2.new(1,0,0,40)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.55, -8, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.Text = "WalkSpeed"

    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(0.45, -12, 0, 28)
    box.Position = UDim2.new(0.55, 0, 0.5, -14)
    box.BackgroundColor3 = Color3.fromRGB(32,32,32)
    box.TextColor3 = Color3.fromRGB(240,240,240)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Text = tostring(FEATURE.WalkValue)
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,8)

    local placeholder = Instance.new("TextLabel", box)
    placeholder.Size = UDim2.new(1,-12,1,0)
    placeholder.Position = UDim2.new(0,6,0,0)
    placeholder.BackgroundTransparency = 1
    placeholder.Font = Enum.Font.Gotham
    placeholder.TextSize = 12
    placeholder.TextColor3 = Color3.fromRGB(140,140,140)
    placeholder.Text = "16–200 (rec 25–40)"
    placeholder.TextXAlignment = Enum.TextXAlignment.Left

    local function updatePlaceholder()
        placeholder.Visible = (box.Text == "")
    end
    box:GetPropertyChangedSignal("Text"):Connect(updatePlaceholder)
    box.Focused:Connect(updatePlaceholder)
    box.FocusLost:Connect(function(enter)
        updatePlaceholder()
        if enter then
            local n = tonumber(box.Text)
            if n and n >= 16 and n <= 200 then
                FEATURE.WalkValue = n
                box.Text = tostring(n)
            else
                box.Text = tostring(FEATURE.WalkValue)
            end
        end
    end)
    updatePlaceholder()
end

-- Hotkeys: call ToggleCallbacks to keep everything synced
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F1 then pcall(function() ToggleCallbacks.ESP(not FEATURE.ESP) end)
    elseif input.KeyCode == Enum.KeyCode.F2 then pcall(function() ToggleCallbacks.AutoE(not FEATURE.AutoE) end)
    elseif input.KeyCode == Enum.KeyCode.F3 then pcall(function() ToggleCallbacks.WalkEnabled(not FEATURE.WalkEnabled) end)
    elseif input.KeyCode == Enum.KeyCode.F4 then pcall(function() ToggleCallbacks.Aimbot(not FEATURE.Aimbot) end)
    end
end)

-- Respawn handling: reapply walk/ESP for local player
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.12)
    if FEATURE.WalkEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.WalkSpeed = FEATURE.WalkValue end) end
    end
    if FEATURE.ESP then
        for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
    end
end)

-- Initial populate HUD states
updateHUD("ESP", FEATURE.ESP)
updateHUD("Auto Press E", FEATURE.AutoE)
updateHUD("WalkSpeed Enabled", FEATURE.WalkEnabled)
updateHUD("Aimbot", FEATURE.Aimbot)

-- Done
print("[TPB_TycoonGUI_Final] loaded.")
