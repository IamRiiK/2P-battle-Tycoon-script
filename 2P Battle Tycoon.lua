-- Load Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/IamRiiK/RiiK-2P-battle-Tycoon/refs/heads/main/Wizard"))()
local PhantomForcesWindow = Library:NewWindow("2P Battle Tycoon")

-- Sections
local SpeedSection = PhantomForcesWindow:NewSection("WalkSpeed")
local AutoSection = PhantomForcesWindow:NewSection("AutoClick E")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- Speed setup
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

-- AutoClick setup (ON / OFF)
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


-- Unlimited Energy Section
local EnergySection = PhantomForcesWindow:NewSection("Unlimited Energy")

local unlimitedEnergy = false
local staminaTarget = nil

-- Debug Section untuk cek semua NumberValue / IntValue
local DebugSection = PhantomForcesWindow:NewSection("Debug Tools")

DebugSection:CreateButton("Print All Values", function()
    local chr = LocalPlayer.Character
    print("=== [DEBUG] Checking values in Character & LocalPlayer ===")

    -- cek di Character
    if chr then
        for _, inst in ipairs(chr:GetDescendants()) do
            if inst:IsA("NumberValue") or inst:IsA("IntValue") then
                print("Character ->", inst.Name, "=", inst.Value)
            end
        end
    else
        print("Character tidak ditemukan!")
    end

    -- cek di LocalPlayer
    for _, inst in ipairs(LocalPlayer:GetDescendants()) do
        if inst:IsA("NumberValue") or inst:IsA("IntValue") then
            print("LocalPlayer ->", inst.Name, "=", inst.Value)
        end
    end

    print("=== [DEBUG] Selesai ===")
end)


-- daftar kemungkinan nama stamina
local staminaNames = {"Stamina", "Energy", "JumpStamina", "Fatigue"}

-- fungsi untuk mencari stamina value
local function findStamina()
    local chr = LocalPlayer.Character
    if not chr then return nil end

    for _,name in ipairs(staminaNames) do
        local val = chr:FindFirstChild(name) or LocalPlayer:FindFirstChild(name)
        if val and val.Value then
            return val
        end
    end
    return nil
end

-- loop menjaga stamina tetap penuh
local function keepStaminaFull()
    spawn(function()
        while unlimitedEnergy do
            RunService.Heartbeat:Wait()
            if staminaTarget and staminaTarget.Parent then
                local maxVal = staminaTarget.MaxValue or staminaTarget.Value
                if staminaTarget.Value < maxVal then
                    staminaTarget.Value = maxVal
                end
            end
        end
    end)
end

-- Tombol ON
EnergySection:CreateButton("Unlimited Energy ON", function()
    if unlimitedEnergy then return end

    staminaTarget = findStamina()
    if staminaTarget then
        unlimitedEnergy = true
        keepStaminaFull()
        print("[Unlimited Energy] ON → menjaga", staminaTarget.Name)
    else
        warn("[Unlimited Energy] Tidak menemukan Stamina/Energy di character!")
    end
end)

-- Tombol OFF
EnergySection:CreateButton("Unlimited Energy OFF", function()
    unlimitedEnergy = false
    staminaTarget = nil
    print("[Unlimited Energy] OFF")
end)
