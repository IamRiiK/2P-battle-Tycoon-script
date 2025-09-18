-- Load Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/IamRiiK/RiiK-2P-battle-Tycoon/refs/heads/main/Wizard"))()
local PhantomForcesWindow = Library:NewWindow("2P Battle Tycoon")

-- Sections
local SpeedSection = PhantomForcesWindow:NewSection("WalkSpeed")
local AutoSection = PhantomForcesWindow:NewSection("AutoClick E")
local JumpSection = PhantomForcesWindow:NewSection("Unlimited Jump")
local DebugSection = PhantomForcesWindow:NewSection("Debug Tools")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-------------------------------------------------------
-- WalkSpeed Setup
-------------------------------------------------------
local tspeed = 0
local minSpeed = 0
local maxSpeed = 100
local tpwalking = true
local hum

local function isNumber(str)
    return tonumber(str) ~= nil or str == "inf"
end

local function adjustSpeed(newSpeed)
    if isNumber(newSpeed) then
        local speedValue = tonumber(newSpeed)
        if not speedValue then return end
        if speedValue < minSpeed then
            tspeed = minSpeed
        elseif speedValue > maxSpeed then
            tspeed = maxSpeed
        else
            tspeed = speedValue
        end
    end
end

local function setupCharacter()
    local chr = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    hum = chr:WaitForChild("Humanoid")

    -- Input speed
    SpeedSection:CreateTextbox("Speed", function(text)
        adjustSpeed(text)
    end)

    -- Movement loop
    spawn(function()
        while tpwalking and chr and hum and hum.Parent do
            RunService.Heartbeat:Wait()
            if hum.MoveDirection.Magnitude > 0 then
                local adjustedSpeed = tspeed
                chr:TranslateBy(hum.MoveDirection * adjustedSpeed * 0.1)
            end
        end
    end)
end

-- Setup karakter
setupCharacter()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    setupCharacter()
end)

-------------------------------------------------------
-- AutoClick E Setup
-------------------------------------------------------
local autoClicking = false
local AUTO_INTERVAL = 0.5 -- detik interval auto click

AutoSection:CreateButton("AutoClick ON", function()
    if autoClicking then return end
    autoClicking = true
    print("[AutoClick] ON")

    spawn(function()
        while autoClicking do
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)

            local t0 = tick()
            while tick() - t0 < AUTO_INTERVAL do
                if not autoClicking then break end
                RunService.Heartbeat:Wait()
            end
        end
        print("[AutoClick] OFF (loop berhenti)")
    end)
end)

AutoSection:CreateButton("AutoClick OFF", function()
    autoClicking = false
    print("[AutoClick] OFF (user menekan tombol)")
end)

-------------------------------------------------------
-- Unlimited Jump Setup
-------------------------------------------------------
local unlimitedJump = false

local function setupUnlimitedJump()
    spawn(function()
        while unlimitedJump do
            RunService.Heartbeat:Wait()
            local chr = LocalPlayer.Character
            local hum = chr and chr:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Jump = true -- paksa selalu bisa lompat
            end
        end
    end)
end

JumpSection:CreateButton("Unlimited Jump ON", function()
    if unlimitedJump then return end
    unlimitedJump = true
    setupUnlimitedJump()
    print("[Unlimited Jump] ON")
end)

JumpSection:CreateButton("Unlimited Jump OFF", function()
    unlimitedJump = false
    print("[Unlimited Jump] OFF")
end)

-------------------------------------------------------
-- Debug Tools
-------------------------------------------------------
DebugSection:CreateButton("Print All Values", function()
    local chr = LocalPlayer.Character
    print("=== [DEBUG] Checking values in Character & LocalPlayer ===")

    -- cek di Character
    if chr then
        for _, inst in ipairs(chr:GetDescendants()) do
            if inst:IsA("NumberValue") or inst:IsA("IntValue") then
                print("Character ->", inst:GetFullName(), "=", inst.Value)
            end
        end
    else
        print("Character tidak ditemukan!")
    end

    -- cek di LocalPlayer
    for _, inst in ipairs(LocalPlayer:GetDescendants()) do
        if inst:IsA("NumberValue") or inst:IsA("IntValue") then
            print("LocalPlayer ->", inst:GetFullName(), "=", inst.Value)
        end
    end

    print("=== [DEBUG] Selesai ===")
end)
