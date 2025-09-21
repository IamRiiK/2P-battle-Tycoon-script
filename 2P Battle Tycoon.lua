-- MAIN SCRIPT (Standalone, no external UI libs)
-- Integrates: ESP, AutoPressE, WalkSpeed, Aimbot, Teleport (per-team dropdown), Hitbox Expander
-- Safe cleanup and rate limiting included
-- Paste & run this in your executor

-- === SAFE PRE-CLEANUP ===
if getgenv().__MAIN_SCRIPT_CLEANUP then
    pcall(getgenv().__MAIN_SCRIPT_CLEANUP)
end

-- Expose cleanup later
getgenv().__MAIN_SCRIPT_CLEANUP = nil

-- === SERVICES & LOCALS ===
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Try to get PlayerGui safely
local PlayerGui = nil
pcall(function() PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 5) end)
if not PlayerGui then
    PlayerGui = Instance.new("ScreenGui") -- temporary fallback (we'll parent later)
end

-- VirtualInputManager (optional)
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- === GLOBAL STATE TRACKERS ===
local FEATURES = {
    ESP = false,
    AutoE = false,
    Walk = false,
    WalkValue = 30,
    Aimbot = false,
    AIM_FOV = 8,
    AIM_LERP = 0.4,
    AIM_HOLD = false,
    Hitbox = false,
}
local WALK_UPDATE_INTERVAL = 0.12

local PersistentConns = {}
local PerPlayerConns = {}
local HighlightsByPlayer = {}
local OrigPartSize = setmetatable({}, {__mode="k"})
local OrigWalkByCharacter = {}

local function keepConn(conn)
    if conn and conn.Disconnect then
        table.insert(PersistentConns, conn)
    end
    return conn
end

local function addPerPlayerConn(p, conn)
    if not p or not conn then return end
    PerPlayerConns[p] = PerPlayerConns[p] or {}
    table.insert(PerPlayerConns[p], conn)
    return conn
end

local function clearPlayerConns(p)
    local t = PerPlayerConns[p]
    if t then
        for _,c in ipairs(t) do pcall(function() c:Disconnect() end) end
        PerPlayerConns[p] = nil
    end
end

local function clearAllConns()
    for _,t in pairs(PerPlayerConns) do
        for _,c in ipairs(t) do pcall(function() c:Disconnect() end) end
    end
    PerPlayerConns = {}
    for _,c in ipairs(PersistentConns) do pcall(function() c:Disconnect() end) end
    PersistentConns = {}
end

local function safeParentGui(gui)
    gui.ResetOnSpawn = false
    if PlayerGui and PlayerGui.Parent then
        gui.Parent = PlayerGui
    else
        pcall(function() gui.Parent = CoreGui end)
    end
end

local function clamp(v,a,b)
    if v < a then return a end
    if v > b then return b end
    return v
end

-- === TELEPORT DATA (from your coordinates) ===
local TeleportPoints = {
    ["Black"] = {
        Spaceship = Vector3.new(153.2, 683.7, 814.4),
        Bunker = Vector3.new(63.9, 3.3, 143.9),
        PrivateIsland = Vector3.new(145.2, 87.5, 697.5),
        Submarine = Vector3.new(61.8, -101.0, 154.9),
        Spawn = Vector3.new(64.1, 72.0, 131.3),
    },
    ["White"] = {
        Spaceship = Vector3.new(-252.3, 683.7, 810.7),
        Bunker = Vector3.new(-116.3, 3.3, 152.9),
        PrivateIsland = Vector3.new(-259.7, 87.5, 697.9),
        Submarine = Vector3.new(-116.6, -101.0, 151.4),
        Spawn = Vector3.new(-115.7, 72.0, 131.2),
    },
    ["Purple"] = {
        Spaceship = Vector3.new(-922.3, 683.7, 95.3),
        Bunker = Vector3.new(-263.3, 3.3, 5.7),
        PrivateIsland = Vector3.new(-807.7, 87.5, 87.4),
        Submarine = Vector3.new(-265.1, -101.0, 6.4),
        Spawn = Vector3.new(-240.9, 72.0, 6.2),
    },
    ["Orange"] = {
        Spaceship = Vector3.new(-922.2, 683.7, -309.5),
        Bunker = Vector3.new(-261.3, 3.3, -173.9),
        PrivateIsland = Vector3.new(-806.2, 87.5, -318.0),
        Submarine = Vector3.new(-266.3, -101.0, -174.2),
        Spawn = Vector3.new(-240.9, 72.0, -174.0),
    },
    ["Yellow"] = {
        Spaceship = Vector3.new(-204.4, 683.7, -979.2),
        Bunker = Vector3.new(-115.9, 3.3, -317.8),
        PrivateIsland = Vector3.new(-197.2, 87.5, -868.6),
        Submarine = Vector3.new(-115.6, -101.0, -319.6),
        Spawn = Vector3.new(-115.8, 72.0, -299.1),
    },
    ["Blue"] = {
        Spaceship = Vector3.new(200.2, 683.7, -978.8),
        Bunker = Vector3.new(63.9, 3.3, -316.2),
        PrivateIsland = Vector3.new(207.6, 87.5, -865.2),
        Submarine = Vector3.new(63.9, -101.0, -319.2),
        Spawn = Vector3.new(63.9, 72.0, -298.7),
    },
    ["Green"] = {
        Spaceship = Vector3.new(871.9, 683.7, -263.0),
        Bunker = Vector3.new(202.8, 3.3, -174.1),
        PrivateIsland = Vector3.new(755.9, 87.5, -254.9),
        Submarine = Vector3.new(211.2, -101.0, -173.9),
        Spawn = Vector3.new(188.5, 72.0, -173.9),
    },
    ["Red"] = {
        Spaceship = Vector3.new(871.2, 683.7, 141.6),
        Bunker = Vector3.new(204.1, 3.3, 5.9),
        PrivateIsland = Vector3.new(755.4, 87.5, 149.4),
        Submarine = Vector3.new(209.8, -101.0, 6.4),
        Spawn = Vector3.new(188.8, 72.0, 6.1),
    },
    ["Flag"] = {
        Neutral = Vector3.new(-24.8, 42.3, -83.2),
    }
}

-- === BUILD UI (manual, tabbed) ===
local Gui = Instance.new("ScreenGui")
Gui.Name = "MainScriptUI"
safeParentGui(Gui)

local MainFrame = Instance.new("Frame", Gui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,420,0,360)
MainFrame.Position = UDim2.new(0.18,0,0.15,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(28,28,30)
MainFrame.BorderSizePixel = 0
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1,0,0,36)
TitleBar.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(0.7,0,1,0)
Title.Position = UDim2.new(0.05,0,0,0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextColor3 = Color3.fromRGB(245,245,245)
Title.Text = "⚔️ 2P Battle Tycoon — Main Script"
Title.TextXAlignment = Enum.TextXAlignment.Left

local HideBtn = Instance.new("TextButton", TitleBar)
HideBtn.Size = UDim2.new(0,36,0,28)
HideBtn.Position = UDim2.new(1,-44,0,4)
HideBtn.Text = "—"
HideBtn.Font = Enum.Font.GothamBold
HideBtn.TextSize = 18
HideBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
Instance.new("UICorner", HideBtn).CornerRadius = UDim.new(0,6)

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1,-16,1,-56)
Content.Position = UDim2.new(0,8,0,48)
Content.BackgroundTransparency = 1

local TabBar = Instance.new("Frame", Content)
TabBar.Size = UDim2.new(0,120,1,0)
TabBar.Position = UDim2.new(0,0,0,0)
TabBar.BackgroundTransparency = 1

local TabContent = Instance.new("Frame", Content)
TabContent.Size = UDim2.new(1,-130,1,0)
TabContent.Position = UDim2.new(0,130,0,0)
TabContent.BackgroundTransparency = 1
local TabLayouts = {}

-- helper to create tab button + content frame
local function makeTab(name)
    local btn = Instance.new("TextButton", TabBar)
    btn.Size = UDim2.new(1, -8, 0, 34)
    btn.Position = UDim2.new(0,4,0, (#TabBar:GetChildren()-0)*36)
    btn.BackgroundColor3 = Color3.fromRGB(46,46,46)
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(240,240,240)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local frame = Instance.new("ScrollingFrame", TabContent)
    frame.Size = UDim2.new(1,-10,1,-10)
    frame.Position = UDim2.new(0,5,0,5)
    frame.Visible = false
    frame.BackgroundTransparency = 1
    frame.ScrollBarThickness = 6
    Instance.new("UIListLayout", frame).Padding = UDim.new(0,8)
    TabLayouts[name] = {button = btn, frame = frame}
    btn.MouseButton1Click:Connect(function()
        for _,v in pairs(TabLayouts) do v.frame.Visible = false end
        frame.Visible = true
    end)
    return btn, frame
end

local btnMain, frameMain = makeTab("Main")
local btnCombat, frameCombat = makeTab("Combat")
local btnMove, frameMove = makeTab("Movement")
local btnTele, frameTele = makeTab("Teleport")
-- open main by default
frameMain.Visible = true

HideBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

-- small helper UI elements
local function createToggle(parent, labelText, init, onChange)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,0,0,36)
    f.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(0.62,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextColor3 = Color3.fromRGB(230,230,230)
    lbl.Text = labelText

    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(0.36,-6,0,28)
    btn.Position = UDim2.new(0.64,6,0.5,-14)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    local state = init
    local function updateBtn()
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(80,150,220) or Color3.fromRGB(60,60,60)
    end
    updateBtn()
    btn.MouseButton1Click:Connect(function()
        state = not state
        updateBtn()
        pcall(onChange, state)
    end)
    return f, btn
end

local function createTextbox(parent, placeholder, default, onEnter)
    local box = Instance.new("TextBox", parent)
    box.Size = UDim2.new(1,0,0,30)
    box.Text = default or ""
    box.PlaceholderText = placeholder or ""
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
    box.FocusLost:Connect(function(enter)
        if enter then pcall(onEnter, box.Text) end
    end)
    return box
end

-- === Main Tab contents (status) ===
local infoLabel = Instance.new("TextLabel", frameMain)
infoLabel.Size = UDim2.new(1,0,0,18)
infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 14
infoLabel.TextColor3 = Color3.fromRGB(220,220,220)
infoLabel.Text = "Status: Ready"

-- === ESP Implementation ===
local function createHighlight(player)
    if not player or not player.Character then return end
    if HighlightsByPlayer[player] then return end
    local humRoot = player.Character
    local ok, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Adornee = player.Character
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.7
        h.OutlineTransparency = 0
        h.FillColor = (player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team) and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,40,40)
        h.Parent = player.Character
        return h
    end)
    if ok and hl then
        HighlightsByPlayer[player] = hl
        -- cleanup when character removed
        addPerPlayerConn(player, player.CharacterRemoving:Connect(function()
            pcall(function() if hl and hl.Parent then hl:Destroy() end end)
            HighlightsByPlayer[player] = nil
        end))
    end
end

local function removeAllHighlights()
    for p,h in pairs(HighlightsByPlayer) do
        pcall(function() if h and h.Parent then h:Destroy() end end)
    end
    HighlightsByPlayer = {}
end

local espToggleFrame, espToggleBtn = createToggle(frameCombat, "ESP (Highlight)", false, function(state)
    FEATURES.ESP = state
    if state then
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then createHighlight(p) end
        end
        keepConn(Players.PlayerAdded:Connect(function(p) if p~=LocalPlayer and FEATURES.ESP then addPerPlayerConn(p, p.CharacterAdded:Connect(function() createHighlight(p) end)) end end))
    else
        removeAllHighlights()
    end
end)

-- === Hitbox Expander ===
local hitboxScale = 1.8
local hitToggleFrame, hitToggleBtn = createToggle(frameCombat, "Hitbox Expander", false, function(state)
    FEATURES.Hitbox = state
    if state then
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _,part in ipairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not OrigPartSize[part] then OrigPartSize[part] = part.Size end
                        pcall(function() part.Size = OrigPartSize[part] * hitboxScale end)
                    end
                end
            end
        end
    else
        for part,sz in pairs(OrigPartSize) do
            pcall(function() if part and part.Parent then part.Size = sz end end)
        end
        OrigPartSize = setmetatable({}, {__mode="k"})
    end
end)

local scaleBox = createTextbox(frameCombat, "Hitbox scale (1.0-5.0)", tostring(hitboxScale), function(txt)
    local n = tonumber(txt)
    if n and n >= 1 and n <= 5 then hitboxScale = n end
end)

-- apply for newly joined players
keepConn(Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        addPerPlayerConn(p, p.CharacterAdded:Connect(function(char)
            if FEATURES.Hitbox then
                task.wait(0.06)
                for _,part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not OrigPartSize[part] then OrigPartSize[part] = part.Size end
                        pcall(function() part.Size = OrigPartSize[part] * hitboxScale end)
                    end
                end
            end
        end))
    end
end))

-- === Walkspeed & AutoE ===
local walkBtnFrame, walkBtn = createToggle(frameMove, "Enable WalkSpeed", false, function(state)
    FEATURES.Walk = state
    if state then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                if OrigWalkByCharacter[char] == nil then OrigWalkByCharacter[char] = hum.WalkSpeed end
                pcall(function() hum.WalkSpeed = FEATURES.WalkValue end)
            end
        end
    else
        for char,orig in pairs(OrigWalkByCharacter) do
            pcall(function() if char and char.Parent then local h = char:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = orig end end end)
        end
        OrigWalkByCharacter = {}
    end
end)

local walkValBox = createTextbox(frameMove, "WalkSpeed value (16-200)", tostring(FEATURES.WalkValue), function(txt)
    local n = tonumber(txt)
    if n and n >= 16 and n <= 200 then FEATURES.WalkValue = n end
end)

-- Walkspeed continuous apply (rate limited)
keepConn(RunService.Heartbeat:Connect(function(dt)
    if not FEATURES.Walk then return end
    -- apply at interval
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if OrigWalkByCharacter[char] == nil then OrigWalkByCharacter[char] = hum.WalkSpeed end
            if hum.WalkSpeed ~= FEATURES.WalkValue then
                pcall(function() hum.WalkSpeed = FEATURES.WalkValue end)
            end
        end
    end
end))

-- Auto Press E toggle
local autoBtnFrame, autoBtn = createToggle(frameMove, "Auto Press E", false, function(state)
    FEATURES.AutoE = state
    if state then
        -- spawn thread
        task.spawn(function()
            local ok, vimService = pcall(function() return game:GetService("VirtualInputManager") end)
            if not ok or not vimService then
                -- VirtualInputManager not available
                FEATURES.AutoE = false
                autoBtn.Text = "OFF"
                autoBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
                warn("AutoE requires VirtualInputManager. Disabled.")
                return
            end
            while FEATURES.AutoE do
                pcall(function()
                    vimService:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    vimService:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
                task.wait(0.5)
            end
        end)
    end
end)

-- === Aimbot (basic) ===
local aimToggleFrame, aimToggleBtn = createToggle(frameCombat, "Aimbot", false, function(state)
    FEATURES.Aimbot = state
end)

local fovBox = createTextbox(frameCombat, "Aim FOV (deg)", tostring(FEATURES.AIM_FOV), function(txt)
    local n = tonumber(txt)
    if n and n > 0 and n <= 180 then FEATURES.AIM_FOV = n end
end)

local lerpBox = createTextbox(frameCombat, "Aim Lerp (0.01-0.95)", tostring(FEATURES.AIM_LERP), function(txt)
    local n = tonumber(txt)
    if n then FEATURES.AIM_LERP = math.clamp(n, 0.01, 0.95) end
end)

local holdAimFrame, holdAimBtn = createToggle(frameCombat, "Hold Right Mouse to Aim", false, function(state)
    FEATURES.AIM_HOLD = state
end)

-- Aimbot loop
keepConn(RunService.RenderStepped:Connect(function()
    if not FEATURES.Aimbot then return end
    if FEATURES.AIM_HOLD and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    if UIS:GetFocusedTextBox() then return end
    if not Workspace.CurrentCamera then return end

    local cam = Workspace.CurrentCamera
    local bestHead = nil
    local bestAngle = 1e9

    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local targetPart = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("HumanoidRootPart")
                if targetPart then
                    local dir = targetPart.Position - cam.CFrame.Position
                    if dir.Magnitude > 0.001 then
                        local ang = math.deg(math.acos(clamp((cam.CFrame.LookVector:Dot(dir.Unit))/(cam.CFrame.LookVector.Magnitude*dir.Unit.Magnitude), -1, 1)))
                        if ang < bestAngle and ang <= FEATURES.AIM_FOV then
                            bestAngle = ang
                            bestHead = targetPart
                        end
                    end
                end
            end
        end
    end

    if bestHead then
        pcall(function()
            local dir = (bestHead.Position - cam.CFrame.Position).Unit
            local currentLook = cam.CFrame.LookVector
            local lerpVal = clamp(FEATURES.AIM_LERP, 0.01, 0.95)
            local blended = currentLook:Lerp(dir, lerpVal)
            local pos = cam.CFrame.Position
            local targetCFrame = CFrame.new(pos, pos + blended)
            Workspace.CurrentCamera.CFrame = Workspace.CurrentCamera.CFrame:Lerp(targetCFrame, lerpVal)
        end)
    end
end))

-- === Teleport Tab UI & Logic ===
local function makeTeleportMenu(parentFrame)
    local label = Instance.new("TextLabel", parentFrame)
    label.Size = UDim2.new(1,0,0,18)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.Text = "Teleport"

    local sc = Instance.new("ScrollingFrame", parentFrame)
    sc.Size = UDim2.new(1,0,1,-24)
    sc.Position = UDim2.new(0,0,0,24)
    sc.BackgroundTransparency = 1
    sc.ScrollBarThickness = 6
    local layout = Instance.new("UIListLayout", sc)
    layout.Padding = UDim.new(0,6)

    local function rebuild()
        for _,c in ipairs(sc:GetChildren()) do
            if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end
        end
        local myTeam = LocalPlayer.Team and LocalPlayer.Team.Name or nil
        for team, locs in pairs(TeleportPoints) do
            if team == "Flag" then
                for locName, pos in pairs(locs) do
                    local btn = Instance.new("TextButton", sc)
                    btn.Size = UDim2.new(1,-8,0,30)
                    btn.Text = "Flag - "..locName
                    btn.Font = Enum.Font.GothamBold
                    btn.TextColor3 = Color3.fromRGB(255,255,255)
                    btn.BackgroundColor3 = Color3.fromRGB(60,60,60)
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
                    btn.MouseButton1Click:Connect(function()
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
                        end
                    end)
                end
            else
                local header = Instance.new("TextButton", sc)
                header.Size = UDim2.new(1,-8,0,28)
                header.Text = team.." ▼"
                header.Font = Enum.Font.Gotham
                header.TextColor3 = Color3.fromRGB(255,255,255)
                header.BackgroundColor3 = Color3.fromRGB(45,45,45)
                Instance.new("UICorner", header).CornerRadius = UDim.new(0,6)

                local content = Instance.new("Frame", sc)
                content.Size = UDim2.new(1,-16,0,0)
                content.Position = UDim2.new(0,8,0,34)
                content.BackgroundTransparency = 1
                content.Visible = false
                local list = Instance.new("UIListLayout", content)
                list.Padding = UDim.new(0,4)
                header.MouseButton1Click:Connect(function() content.Visible = not content.Visible end)

                for locName, pos in pairs(locs) do
                    if locName == "Spawn" then
                        if myTeam == team then
                            local b = Instance.new("TextButton", content)
                            b.Size = UDim2.new(1,-6,0,28)
                            b.Text = locName
                            b.Font = Enum.Font.Gotham
                            b.TextColor3 = Color3.fromRGB(255,255,255)
                            b.BackgroundColor3 = Color3.fromRGB(70,70,70)
                            Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
                            b.MouseButton1Click:Connect(function()
                                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
                                end
                            end)
                        end
                    else
                        local b = Instance.new("TextButton", content)
                        b.Size = UDim2.new(1,-6,0,28)
                        b.Text = locName
                        b.Font = Enum.Font.Gotham
                        b.TextColor3 = Color3.fromRGB(255,255,255)
                        b.BackgroundColor3 = Color3.fromRGB(70,70,70)
                        Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
                        b.MouseButton1Click:Connect(function()
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
                            end
                        end)
                    end
                end
            end
        end
    end

    -- quick buttons
    local quickFrame = Instance.new("Frame", sc)
    quickFrame.Size = UDim2.new(1, -8, 0, 32)
    quickFrame.BackgroundTransparency = 1
    local quickLayout = Instance.new("UIListLayout", quickFrame)
    quickLayout.FillDirection = Enum.FillDirection.Horizontal
    quickLayout.Padding = UDim.new(0,6)

    local btnMySpawn = Instance.new("TextButton", quickFrame)
    btnMySpawn.Size = UDim2.new(0.5,-6,1,0)
    btnMySpawn.Text = "Teleport to My Spawn"
    btnMySpawn.Font = Enum.Font.Gotham
    btnMySpawn.TextSize = 12
    Instance.new("UICorner", btnMySpawn).CornerRadius = UDim.new(0,6)
    btnMySpawn.BackgroundColor3 = Color3.fromRGB(65,100,65)
    btnMySpawn.MouseButton1Click:Connect(function()
        local myTeam = LocalPlayer.Team and LocalPlayer.Team.Name or nil
        if myTeam and TeleportPoints[myTeam] and TeleportPoints[myTeam].Spawn then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(TeleportPoints[myTeam].Spawn + Vector3.new(0,3,0))
            end
        else
            -- feedback
            infoLabel.Text = "Spawn coord not available for your team."
            task.defer(function() task.wait(2); infoLabel.Text = "Status: Ready" end)
        end
    end)

    local btnFlag = Instance.new("TextButton", quickFrame)
    btnFlag.Size = UDim2.new(0.5,-6,1,0)
    btnFlag.Text = "Teleport to Flag"
    btnFlag.Font = Enum.Font.Gotham
    btnFlag.TextSize = 12
    Instance.new("UICorner", btnFlag).CornerRadius = UDim.new(0,6)
    btnFlag.BackgroundColor3 = Color3.fromRGB(70,70,120)
    btnFlag.MouseButton1Click:Connect(function()
        if TeleportPoints.Flag and TeleportPoints.Flag.Neutral then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(TeleportPoints.Flag.Neutral + Vector3.new(0,3,0))
            end
        end
    end)

    -- initial build & team-change refresh
    rebuild()
    addPerPlayerConn(LocalPlayer, LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function() rebuild() end))
end

makeTeleportMenu(frameTele)

-- === SAFE CLEANUP ===
getgenv().__MAIN_SCRIPT_CLEANUP = function()
    -- disable features so loops exit
    FEATURES.ESP = false
    FEATURES.AutoE = false
    FEATURES.Walk = false
    FEATURES.Aimbot = false
    FEATURES.Hitbox = false

    -- restore walk speeds
    for char,ws in pairs(OrigWalkByCharacter) do
        pcall(function()
            if char and char.Parent then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and ws then hum.WalkSpeed = ws end
            end
        end)
    end
    OrigWalkByCharacter = {}

    -- restore part sizes
    for part, sz in pairs(OrigPartSize) do
        pcall(function() if part and part.Parent then part.Size = sz end end)
    end
    OrigPartSize = setmetatable({}, {__mode="k"})

    -- destroy highlights
    removeAllHighlights()

    -- disconnect per-player connections & persistent ones
    for p, t in pairs(PerPlayerConns) do
        for _,c in ipairs(t) do pcall(function() c:Disconnect() end) end
    end
    PerPlayerConns = {}

    for _,c in ipairs(PersistentConns) do
        pcall(function() c:Disconnect() end)
    end
    PersistentConns = {}

    -- destroy GUI
    pcall(function()
        if Gui and Gui.Parent then Gui:Destroy() end
    end)

    -- unset global
    getgenv().__MAIN_SCRIPT_CLEANUP = nil
    print("[MainScript] cleanup done")
end

-- auto print
print("Main Script loaded. Call getgenv().__MAIN_SCRIPT_CLEANUP() to cleanup.")

-- === END OF SCRIPT ===
