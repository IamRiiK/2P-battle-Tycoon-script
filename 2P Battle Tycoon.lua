
-- MAIN SCRIPT FINAL with Safe Cleanup
-- Features: ESP, AutoPressE, Walkspeed, AimBot, Teleport, Hitbox Expander
-- UI Tab System + Safe Cleanup + Rate Limiting included

-- Safe cleanup if already loaded
if getgenv().MainScriptLoaded then
    if type(getgenv().__MAIN_CLEANUP) == "function" then
        pcall(getgenv().__MAIN_CLEANUP)
    end
end

getgenv().MainScriptLoaded = true

-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Keep track of resources for cleanup
local _CONNS = {}
local _THREADS = {}
local _HIGHLIGHTS = {}
local _ORIG_PART_SIZES = {}
local _ORIG_WALKS = {}

local function keepConn(c) if c and c.Disconnect then table.insert(_CONNS, c) end; return c end
local function keepThread(t) if t then table.insert(_THREADS, t) end; return t end

-- Cleanup function (exposed to getgenv)
getgenv().__MAIN_CLEANUP = function()
    -- stop threads by flipping flags
    pcall(function() getgenv()._FEATURES = nil end)

    -- disconnect connections
    for _,c in ipairs(_CONNS) do
        pcall(function() c:Disconnect() end)
    end
    _CONNS = {}

    -- cancel threads (no direct cancel, rely on flags)
    for _,th in ipairs(_THREADS) do
        pcall(function() if type(th) == "thread" then -- nothing to do end end) end)
    end
    _THREADS = {}

    -- destroy highlights
    for _,hl in ipairs(_HIGHLIGHTS) do
        pcall(function() if hl and hl.Parent then hl:Destroy() end end)
    end
    _HIGHLIGHTS = {}

    -- restore parts sizes
    for part, size in pairs(_ORIG_PART_SIZES) do
        pcall(function()
            if part and part.Parent then
                part.Size = size
            end
        end)
    end
    _ORIG_PART_SIZES = {}

    -- restore walks
    for char, ws in pairs(_ORIG_WALKS) do
        pcall(function()
            if char and char.Parent then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and ws then hum.WalkSpeed = ws end
            end
        end)
    end
    _ORIG_WALKS = {}

    -- remove GUI
    pcall(function()
        local g = game:GetService("CoreGui"):FindFirstChild("MainScriptUI")
        if g then g:Destroy() end
    end)

    getgenv().MainScriptLoaded = false
    getgenv().__MAIN_CLEANUP = nil
    print("[MainScript] cleanup finished")
end

-- FEATURES table (global so threads can check it)
getgenv()._FEATURES = {
    ESP = false,
    AutoE = false,
    Walk = false,
    WalkValue = 16,
    Aimbot = false,
    Hitbox = false,
}

-- UI BUILD
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name = "MainScriptUI"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 520, 0, 380)
MainFrame.Position = UDim2.new(0.2, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1,0,0,36)
Title.Position = UDim2.new(0,0,0,0)
Title.BackgroundColor3 = Color3.fromRGB(40,40,40)
Title.Text = "Main Script Final"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16

local TabBar = Instance.new("Frame", MainFrame)
TabBar.Size = UDim2.new(0,140,1,-46)
TabBar.Position = UDim2.new(0,0,0,40)
TabBar.BackgroundColor3 = Color3.fromRGB(35,35,35)

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1,-150,1,-56)
Content.Position = UDim2.new(0,150,0,48)
Content.BackgroundTransparency = 1

local Tabs = {}
local TabContents = {}

local function createTab(name)
    local btn = Instance.new("TextButton", TabBar)
    btn.Size = UDim2.new(1,-10,0,32)
    btn.Position = UDim2.new(0,5,0,#TabBar:GetChildren()*0)
    btn.BackgroundColor3 = Color3.fromRGB(60,60,60)
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local frame = Instance.new("ScrollingFrame", Content)
    frame.Size = UDim2.new(1,-10,1,-10)
    frame.Position = UDim2.new(0,5,0,5)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0,6)

    btn.MouseButton1Click:Connect(function()
        for k,v in pairs(TabContents) do v.Visible = (k==name) end
    end)

    Tabs[name] = btn
    TabContents[name] = frame
    return frame
end

local ESPTab = createTab("ESP")
local CombatTab = createTab("Combat")
local MoveTab = createTab("Movement")
local TeleTab = createTab("Teleport")

-- Default open ESP
TabContents["ESP"].Visible = true

-- Helper add UI
local function addToggle(parent, text, initial, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1,0,0,36)
    frame.BackgroundTransparency = 1
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.65,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(230,230,230)

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0.33, -6,0,28)
    btn.Position = UDim2.new(0.67, 6,0.5,-14)
    btn.Text = initial and "ON" or "OFF"
    btn.BackgroundColor3 = initial and Color3.fromRGB(80,150,220) or Color3.fromRGB(50,50,50)
    btn.Font = Enum.Font.Gotham
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    btn.MouseButton1Click:Connect(function()
        local new = not initial
        initial = new
        btn.Text = new and "ON" or "OFF"
        btn.BackgroundColor3 = new and Color3.fromRGB(80,150,220) or Color3.fromRGB(50,50,50)
        pcall(callback, new)
    end)
    return frame, btn
end

local function addTextBox(parent, placeholder, default, onEnter)
    local box = Instance.new("TextBox", parent)
    box.Size = UDim2.new(1,0,0,28)
    box.PlaceholderText = placeholder
    box.Text = default or ""
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
    box.FocusLost:Connect(function(enter)
        if enter then pcall(onEnter, box.Text) end
    end)
    return box
end

-- === ESP implementation ===
local highlights = {}

local function createHighlightForPlayer(p)
    if not p or not p.Character then return end
    if highlights[p] then return end
    local ok, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Adornee = p.Character
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.7
        h.FillColor = (p.Team and LocalPlayer.Team and p.Team==LocalPlayer.Team) and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,40,40)
        h.OutlineTransparency = 0
        h.Parent = p.Character
        return h
    end)
    if ok and hl then highlights[p] = hl; table.insert(_HIGHLIGHTS, hl) end
end

local function clearHighlights()
    for p,hl in pairs(highlights) do
        pcall(function() if hl and hl.Parent then hl:Destroy() end end)
    end
    highlights = {}
    _HIGHLIGHTS = {}
end

-- ESP toggle UI
addToggle(ESPTab, "ESP", false, function(state)
    getgenv()._FEATURES.ESP = state
    if state then
        -- create for current players
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                createHighlightForPlayer(plr)
            end
        end
    else
        clearHighlights()
    end
end)

-- ensure highlights follow new players/characters
keepConn(Players.PlayerAdded:Connect(function(p)
    if getgenv()._FEATURES.ESP and p ~= LocalPlayer then
        p.CharacterAdded:Connect(function() createHighlightForPlayer(p) end)
    end
end))

-- === Hitbox Expander ===
local currentScale = 1.5
addToggle(CombatTab, "Hitbox Expander", false, function(state)
    getgenv()._FEATURES.Hitbox = state
    if state then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                for _,part in ipairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not _ORIG_PART_SIZES[part] then _ORIG_PART_SIZES[part] = part.Size end
                        pcall(function() part.Size = _ORIG_PART_SIZES[part] * currentScale end)
                    end
                end
            end
        end
    else
        for part,sz in pairs(_ORIG_PART_SIZES) do
            pcall(function() if part and part.Parent then part.Size = sz end end)
        end
        _ORIG_PART_SIZES = {}
    end
end)

local scaleBox = addTextBox(CombatTab, "Hitbox scale (1.0 - 5.0)", tostring(currentScale), function(txt)
    local n = tonumber(txt)
    if n and n>=1 and n<=5 then currentScale = n end
end)

-- apply on character join
keepConn(Players.PlayerAdded:Connect(function(p)
    if p~=LocalPlayer then
        p.CharacterAdded:Connect(function(char)
            if getgenv()._FEATURES.Hitbox then
                task.wait(0.05)
                for _,part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not _ORIG_PART_SIZES[part] then _ORIG_PART_SIZES[part] = part.Size end
                        pcall(function() part.Size = _ORIG_PART_SIZES[part] * currentScale end)
                    end
                end
            end
        end)
    end
end))

-- === Walkspeed ===
addToggle(MoveTab, "WalkSpeed", false, function(state)
    getgenv()._FEATURES.Walk = state
    if state then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                if not _ORIG_WALKS[char] then _ORIG_WALKS[char] = hum.WalkSpeed end
                hum.WalkSpeed = tonumber(getgenv()._FEATURES.WalkValue) or 16
            end
        end
    else
        for c,ws in pairs(_ORIG_WALKS) do
            pcall(function() if c and c.Parent then local h = c:FindFirstChildOfClass("Humanoid"); if h and ws then h.WalkSpeed = ws end end end)
        end
        _ORIG_WALKS = {}
    end
end)

local wsBox = addTextBox(MoveTab, "WalkSpeed value (16-200)", tostring(getgenv()._FEATURES.WalkValue), function(txt)
    local n = tonumber(txt)
    if n and n>=16 and n<=200 then getgenv()._FEATURES.WalkValue = n end
end)

-- Auto Press E
addToggle(MoveTab, "Auto Press E", false, function(state)
    getgenv()._FEATURES.AutoE = state
    if getgenv()._FEATURES.AutoE then
        keepThread(task.spawn(function()
            while getgenv()._FEATURES.AutoE do
                pcall(function()
                    local vim = pcall(function() return game:GetService("VirtualInputManager") end)
                    if vim then
                        pcall(function()
                            local VIM = game:GetService("VirtualInputManager")
                            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        end)
                    end
                end)
                task.wait(tonumber(getgenv()._FEATURES.AutoEInterval) or 0.5)
            end
        end))
    end
end)

-- default interval
getgenv()._FEATURES.AutoEInterval = 0.5

-- === Aimbot (basic) ===
getgenv()._FEATURES.Aimbot = false
getgenv()._FEATURES.AIM_FOV = 8
getgenv()._FEATURES.AIM_LERP = 0.4

addToggle(CombatTab, "Aimbot", false, function(state)
    getgenv()._FEATURES.Aimbot = state
end)

local fovBox = addTextBox(CombatTab, "AIM FOV (deg)", tostring(getgenv()._FEATURES.AIM_FOV), function(txt)
    local n = tonumber(txt)
    if n and n>0 and n<=180 then getgenv()._FEATURES.AIM_FOV = n end
end)

-- Aimbot loop (RenderStepped)
keepConn(RunService.RenderStepped:Connect(function()
    if not getgenv()._FEATURES.Aimbot then return end
    if UserInputService:GetFocusedTextBox() then return end
    if not Workspace.CurrentCamera then return end

    local cam = Workspace.CurrentCamera
    local best, bestAng = nil, 1e9
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character.Parent then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health>0 then
                local head = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("HumanoidRootPart")
                if head then
                    local dir = head.Position - cam.CFrame.Position
                    local ang = math.deg(math.acos(math.clamp((cam.CFrame.LookVector:Dot(dir.Unit))/(cam.CFrame.LookVector.Magnitude*dir.Unit.Magnitude), -1, 1)))
                    if ang < bestAng and ang <= getgenv()._FEATURES.AIM_FOV then
                        bestAng = ang; best = head
                    end
                end
            end
        end
    end

    if best then
        pcall(function()
            local dir = (best.Position - cam.CFrame.Position).Unit
            local cur = cam.CFrame.LookVector
            local lerp = math.clamp(getgenv()._FEATURES.AIM_LERP, 0.01, 0.95)
            local blended = cur:Lerp(dir, lerp)
            local pos = cam.CFrame.Position
            local target = CFrame.new(pos, pos + blended)
            cam.CFrame = cam.CFrame:Lerp(target, lerp)
        end)
    end
end))

-- === TELEPORT Tab (dropdown per team) ===
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

local function createTeleportDropdown(parent)
    local label = Instance.new("TextLabel", parent)
    label.Size = UDim2.new(1,0,0,20)
    label.BackgroundTransparency = 1
    label.Text = "Teleport"
    label.Font = Enum.Font.Gotham
    label.TextColor3 = Color3.fromRGB(230,230,230)

    local sc = Instance.new("ScrollingFrame", parent)
    sc.Size = UDim2.new(1,0,0,220)
    sc.Position = UDim2.new(0,0,0,24)
    sc.BackgroundTransparency = 1
    sc.ScrollBarThickness = 6
    Instance.new("UIListLayout", sc).Padding = UDim.new(0,6)

    local myTeam = LocalPlayer.Team and LocalPlayer.Team.Name or nil

    for team, locs in pairs(TeleportPoints) do
        if team == "Flag" then
            for locName, pos in pairs(locs) do
                local btn = Instance.new("TextButton", sc)
                btn.Size = UDim2.new(1,-8,0,28)
                btn.Text = "Flag - "..locName
                btn.Font = Enum.Font.Gotham
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
            header.Size = UDim2.new(1,-8,0,30)
            header.Text = team.." ▼"
            header.Font = Enum.Font.GothamBold
            header.TextColor3 = Color3.fromRGB(255,255,255)
            header.BackgroundColor3 = Color3.fromRGB(45,45,45)
            Instance.new("UICorner", header).CornerRadius = UDim.new(0,6)

            local content = Instance.new("Frame", sc)
            content.Size = UDim2.new(1,-16,0,0)
            content.Position = UDim2.new(0,8,0,34)
            content.BackgroundTransparency = 1
            content.Visible = false
            local l = Instance.new("UIListLayout", content)
            l.Padding = UDim.new(0,4)

            header.MouseButton1Click:Connect(function()
                content.Visible = not content.Visible
            end)

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

createTeleportDropdown(TeleTab)

-- Refresh teleport menu on team change
keepConn(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function() 
    -- rebuild TeleTab content: destroy children then recreate
    for _,c in ipairs(TeleTab:GetChildren()) do
        if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end
    end
    createTeleportDropdown(TeleTab)
end))

-- Final notes
print("[MainScript] Loaded. Use getgenv().__MAIN_CLEANUP() to cleanup manually or re-run script to auto-clean.") 
