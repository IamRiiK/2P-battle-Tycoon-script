-- main_script_orion.lua
-- Main Script Final (OrionLib)
-- Features: ESP, AutoPressE, Walkspeed, Aimbot, Teleport (dropdown per team), Hitbox Expander
-- Safe cleanup, rate limiting, tab UI via OrionLib
-- Notes: executor must allow https requests (HttpGet) for OrionLib; if not, load will fail.

-- Safe cleanup if re-run
if getgenv().MAIN_SCRIPT_LOADED then
    if type(getgenv().MAIN_SCRIPT_CLEANUP) == "function" then
        pcall(getgenv().MAIN_SCRIPT_CLEANUP)
    end
end

getgenv().MAIN_SCRIPT_LOADED = true

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Resource tracking for safe cleanup
local Connections = {}
local Threads = {}
local Highlights = {}
local OrigPartSizes = {}
local OrigWalkspeeds = {}
local FeatureFlags = {
    ESP = false,
    AutoE = false,
    Walk = false,
    Aimbot = false,
    Hitbox = false,
}

local function keepConn(conn)
    if conn and conn.Disconnect then table.insert(Connections, conn) end
    return conn
end

local function keepThread(t)
    if t then table.insert(Threads, t) end
    return t
end

-- Cleanup function
getgenv().MAIN_SCRIPT_CLEANUP = function()
    -- disable features to let threads exit
    FeatureFlags.ESP = false
    FeatureFlags.AutoE = false
    FeatureFlags.Walk = false
    FeatureFlags.Aimbot = false
    FeatureFlags.Hitbox = false

    -- disconnect connections
    for _,c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}

    -- destroy highlights
    for _,hl in ipairs(Highlights) do
        pcall(function() if hl and hl.Parent then hl:Destroy() end end)
    end
    Highlights = {}

    -- restore part sizes
    for part, size in pairs(OrigPartSizes) do
        pcall(function()
            if part and part.Parent then part.Size = size end
        end)
    end
    OrigPartSizes = {}

    -- restore walkspeeds
    for char, ws in pairs(OrigWalkspeeds) do
        pcall(function()
            if char and char.Parent then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and ws then hum.WalkSpeed = ws end
            end
        end)
    end
    OrigWalkspeeds = {}

    -- remove GUI
    pcall(function()
        local gui = game:GetService("CoreGui"):FindFirstChild("MainScriptUI_Orion")
        if gui then gui:Destroy() end
    end)

    getgenv().MAIN_SCRIPT_LOADED = false
    getgenv().MAIN_SCRIPT_CLEANUP = nil
    print("[MainScript] Cleanup complete")
end

-- Attempt to load OrionLib
local OrionLib = nil
local ok, res = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()
end)

if ok and type(res) == "table" then
    OrionLib = res
else
    warn("Failed to load OrionLib. Ensure your executor supports HttpGet and the URL is reachable.")
    -- fallback: create very basic GUI if Orion not available
end

-- Create window (Orion) or fallback GUI
local Window, ESPTab, CombatTab, MoveTab, TeleTab
if OrionLib then
    Window = OrionLib:MakeWindow({Name = "Main Script Final", HidePremium = true, SaveConfig = true, ConfigFolder = "MainScriptOrion"})
    ESPTab = Window:MakeTab({Name = "ESP", Icon = "rbxassetid://4483345998", PremiumOnly = false})
    CombatTab = Window:MakeTab({Name = "Combat", Icon = "rbxassetid://4483345998", PremiumOnly = false})
    MoveTab = Window:MakeTab({Name = "Movement", Icon = "rbxassetid://4483345998", PremiumOnly = false})
    TeleTab = Window:MakeTab({Name = "Teleport", Icon = "rbxassetid://4483345998", PremiumOnly = false})
else
    -- create minimal screen gui fallback to avoid total failure
    local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
    ScreenGui.Name = "MainScriptUI_Orion"
    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.new(0,420,0,300)
    Frame.Position = UDim2.new(0.2,0,0.2,0)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0,8)
    local Title = Instance.new("TextLabel", Frame)
    Title.Size = UDim2.new(1,0,0,36); Title.BackgroundTransparency = 1
    Title.Text = "Main Script (Fallback UI)" Title.Font = Enum.Font.GothamBold; Title.TextColor3 = Color3.new(1,1,1)
    -- create containers for manual building if necessary (not implementing full fallback controls)
    warn("Orion unavailable: UI disabled. Use executor with HTTP support to get full UI.")
end

-- Helper: create highlight for player
local function spawnHighlight(p)
    if not p or not p.Character then return end
    if Highlights[p] then return end
    local ok, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Adornee = p.Character
        h.FillTransparency = 0.7
        h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillColor = (p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team) and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,40,40)
        h.Parent = p.Character
        return h
    end)
    if ok and hl then
        Highlights[p] = hl
        table.insert(Connections, p.CharacterRemoving:Connect(function() pcall(function() if hl and hl.Parent then hl:Destroy() end end) end))
    end
end

-- ESP functionality via Orion UI
if OrionLib then
    ESPTab:AddToggle({
        Name = "Enable ESP",
        Default = false,
        Callback = function(val)
            FeatureFlags.ESP = val
            if not val then
                -- clear
                for _,h in ipairs(Highlights) do pcall(function() if h and h.Parent then h:Destroy() end end) end
                Highlights = {}
            else
                -- create for existing players
                for _,plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then spawnHighlight(plr) end
                end
            end
        end
    })
    -- Option: team color toggle
    local teamColor = true
    ESPTab:AddToggle({Name = "Color by Team", Default = true, Callback = function(v) teamColor = v end})
    -- Keep highlights updated when players/characters spawn
    keepConn(Players.PlayerAdded:Connect(function(p)
        if FeatureFlags.ESP and p ~= LocalPlayer then
            keepConn(p.CharacterAdded:Connect(function() spawnHighlight(p) end))
        end
    end))
end

-- Hitbox Expander
local hitboxScale = 1.8
local function setHitboxForCharacter(char, scale)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if not OrigPartSizes[part] then OrigPartSizes[part] = part.Size end
            pcall(function() part.Size = OrigPartSizes[part] * scale end)
        end
    end
end

if OrionLib then
    CombatTab:AddToggle({Name = "Hitbox Expander", Default = false, Callback = function(val)
        FeatureFlags.Hitbox = val
        if val then
            for _,p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then setHitboxForCharacter(p.Character, hitboxScale) end
            end
        else
            for part, sz in pairs(OrigPartSizes) do
                pcall(function() if part and part.Parent then part.Size = sz end end)
            end
            OrigPartSizes = {}
        end
    end})

    CombatTab:AddTextbox({Name = "Scale (1.0 - 5.0)", Default = tostring(hitboxScale), Placeholder = "1.0-5.0", Callback = function(txt)
        local n = tonumber(txt)
        if n and n >= 1 and n <= 5 then hitboxScale = n end
    end})

    -- Apply to characters that spawn later
    keepConn(Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then
            keepConn(p.CharacterAdded:Connect(function(char)
                if FeatureFlags.Hitbox then
                    task.wait(0.05)
                    setHitboxForCharacter(char, hitboxScale)
                end
            end))
        end
    end))
end

-- Walkspeed & Auto Press E
local defaultWalk = 16
if OrionLib then
    MoveTab:AddTextbox({Name = "WalkSpeed Value", Default = tostring(defaultWalk), Placeholder = "16-200", Callback = function(txt)
        local n = tonumber(txt)
        if n and n >= 16 and n <= 200 then defaultWalk = n end
    end})
    MoveTab:AddToggle({Name = "Enable WalkSpeed", Default = false, Callback = function(val)
        FeatureFlags.Walk = val
        if val then
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    if not OrigWalkspeeds[char] then OrigWalkspeeds[char] = hum.WalkSpeed end
                    pcall(function() hum.WalkSpeed = defaultWalk end)
                end
            end
        else
            for c, ws in pairs(OrigWalkspeeds) do
                pcall(function() if c and c.Parent then local h = c:FindFirstChildOfClass("Humanoid"); if h and ws then h.WalkSpeed = ws end end end)
            end
            OrigWalkspeeds = {}
        end
    end})

    MoveTab:AddToggle({Name = "Auto Press E", Default = false, Callback = function(val)
        FeatureFlags.AutoE = val
        if val then
            keepThread(task.spawn(function()
                local success, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
                if not success or not VIM then
                    warn("VirtualInputManager unavailable. AutoE disabled.")
                    FeatureFlags.AutoE = false
                    return
                end
                while FeatureFlags.AutoE do
                    pcall(function()
                        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end)
                    task.wait(0.5)
                end
            end))
        end
    end})
end

-- Aimbot (basic)
FeatureFlags.AIM_FOV = 8
FeatureFlags.AIM_LERP = 0.4
FeatureFlags.AIM_HOLD = false

if OrionLib then
    CombatTab:AddToggle({Name = "Aimbot", Default = false, Callback = function(v) FeatureFlags.Aimbot = v end})
    CombatTab:AddTextbox({Name = "AIM FOV (deg)", Default = tostring(FeatureFlags.AIM_FOV), Placeholder = "1-180", Callback = function(txt) local n = tonumber(txt); if n and n>0 and n<=180 then FeatureFlags.AIM_FOV = n end end})
    CombatTab:AddTextbox({Name = "AIM LERP (0.01-0.95)", Default = tostring(FeatureFlags.AIM_LERP), Placeholder = "0.01-0.95", Callback = function(txt) local n = tonumber(txt); if n then FeatureFlags.AIM_LERP = math.clamp(n,0.01,0.95) end end})
    CombatTab:AddToggle({Name = "Hold Right Mouse to Aim", Default = false, Callback = function(v) FeatureFlags.AIM_HOLD = v end})
end

-- Aimbot loop
keepConn(RunService.RenderStepped:Connect(function()
    if not FeatureFlags.Aimbot then return end
    if FeatureFlags.AIM_HOLD and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    if UserInputService:GetFocusedTextBox() then return end
    if not Workspace.CurrentCamera then return end

    local cam = Workspace.CurrentCamera
    local best, bestAng = nil, 1e9
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("HumanoidRootPart")
                if part then
                    local dir = part.Position - cam.CFrame.Position
                    if dir.Magnitude > 0.001 then
                        local ang = math.deg(math.acos(math.clamp((cam.CFrame.LookVector:Dot(dir.Unit))/(cam.CFrame.LookVector.Magnitude*dir.Unit.Magnitude), -1, 1)))
                        if ang < bestAng and ang <= FeatureFlags.AIM_FOV then bestAng = ang; best = part end
                    end
                end
            end
        end
    end

    if best then
        pcall(function()
            local dir = (best.Position - cam.CFrame.Position).Unit
            local currentLook = cam.CFrame.LookVector
            local lerpVal = math.clamp(FeatureFlags.AIM_LERP, 0.01, 0.95)
            local blended = currentLook:Lerp(dir, lerpVal)
            local pos = cam.CFrame.Position
            local target = CFrame.new(pos, pos + blended)
            cam.CFrame = cam.CFrame:Lerp(target, lerpVal)
        end)
    end
end))

-- Teleport points (from your provided table)
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

-- Teleport UI (dropdown per team) using OrionTab helpers
if OrionLib then
    -- Team dropdown
    local teamSelection = "Flag"
    TeleTab:AddDropdown({Name = "Team", Default = "Flag", Options = {"Black","White","Purple","Orange","Yellow","Blue","Green","Red","Flag"}, Callback = function(val)
        teamSelection = val
        -- Build location options
        local locs = TeleportPoints[val] or {}
        local opts = {}
        for name,_ in pairs(locs) do
            if name == "Spawn" then
                if LocalPlayer.Team and LocalPlayer.Team.Name == val then table.insert(opts, name) end
            else
                table.insert(opts, name)
            end
        end
        -- ensure at least one option
        if #opts == 0 then opts = {"None"} end

        -- add/update location dropdown
        TeleTab:Refresh()
        TeleTab:AddDropdown({Name = "Location", Default = opts[1], Options = opts, Callback = function(location)
            local locTable = TeleportPoints[teamSelection]
            if locTable and locTable[location] then
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(locTable[location] + Vector3.new(0,3,0))
                end
            end
        end})
    end})

    -- quick teleport to your own spawn
    TeleTab:AddButton({Name = "Teleport to My Spawn", Callback = function()
        local myTeam = LocalPlayer.Team and LocalPlayer.Team.Name or nil
        if not myTeam or not TeleportPoints[myTeam] or not TeleportPoints[myTeam].Spawn then OrionLib:MakeNotification({Name="Teleport",Content="Spawn coord not available for your team.",Duration=3}) return end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(TeleportPoints[myTeam].Spawn + Vector3.new(0,3,0))
        end
    end})

    TeleTab:AddButton({Name = "Teleport to Flag", Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(TeleportPoints.Flag.Neutral + Vector3.new(0,3,0)) end
    end})

    -- refresh on team change
    keepConn(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function() TeleTab:Refresh() end))
end

-- Keybinds (optional): F1 toggle Orion window visibility (if Orion loaded)
if OrionLib then
    keepConn(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.F1 then
            pcall(function() Window:Toggle() end)
        end
    end))
end

-- Final print
print("[MainScript] Loaded. Call getgenv().MAIN_SCRIPT_CLEANUP() to cleanup.")
