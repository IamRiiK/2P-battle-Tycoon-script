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

-- ===== Improved Auto-Detect Unlimited Energy =====
local EnergySection = EnergySection or PhantomForcesWindow:NewSection("Unlimited Energy (Auto)")

local unlimitedEnergy = false
local staminaTarget = nil -- { kind = "instance"/"attribute", inst = Instance, name = string, target = number }
local detectRunning = false

local function waitForHumanoid()
    -- pastikan hum ada (setupCharacter sudah defines `hum`)
    local tries = 0
    while (not hum or not hum.Parent) and tries < 300 do
        RunService.Heartbeat:Wait()
        tries = tries + 1
    end
    return hum and hum.Parent
end

local function collectNumericCandidates()
    local roots = {}
    table.insert(roots, LocalPlayer)
    if LocalPlayer.Character then table.insert(roots, LocalPlayer.Character) end
    for _,n in ipairs({"PlayerGui","PlayerScripts","Backpack"}) do
        local obj = LocalPlayer:FindFirstChild(n)
        if obj then table.insert(roots, obj) end
    end
    local wsChar = workspace:FindFirstChild(LocalPlayer.Name)
    if wsChar then table.insert(roots, wsChar) end

    local found = {}
    for _,root in ipairs(roots) do
        if root and root:GetDescendants then
            for _,inst in ipairs(root:GetDescendants()) do
                if inst:IsA("NumberValue") or inst:IsA("IntValue") then
                    table.insert(found, inst)
                end
            end
        end
    end
    return found
end

local function getHumanoidNumericAttributes()
    local attrs = {}
    if hum and hum.GetAttributeNames then
        for _,name in ipairs(hum:GetAttributeNames()) do
            local v = hum:GetAttribute(name)
            if type(v) == "number" then
                table.insert(attrs, name)
            end
        end
    end
    return attrs
end

local function detectStaminaByJumpTest()
    if not waitForHumanoid() then return {} end
    local candidates = collectNumericCandidates()
    local attrNames = getHumanoidNumericAttributes()

    -- sample before
    local beforeInst = {}
    for _,inst in ipairs(candidates) do beforeInst[inst] = inst.Value end
    local beforeAttr = {}
    for _,name in ipairs(attrNames) do beforeAttr[name] = hum:GetAttribute(name) end

    -- trigger a single jump (non-invasive)
    -- we try hum.Jump first; if not, ChangeState
    pcall(function()
        if hum then
            hum.Jump = true
        end
    end)
    task.wait(0.6) -- tunggu efek stamina muncul

    -- sample after
    local afterInst = {}
    for _,inst in ipairs(candidates) do afterInst[inst] = inst.Value end
    local afterAttr = {}
    for _,name in ipairs(attrNames) do afterAttr[name] = hum:GetAttribute(name) end

    -- collect deltas
    local results = {}
    for _,inst in ipairs(candidates) do
        local b = beforeInst[inst] or 0
        local a = afterInst[inst] or 0
        local delta = b - a
        if delta > 0 then
            table.insert(results, { kind = "instance", inst = inst, name = inst.Name, delta = delta, before = b, after = a })
        end
    end
    for _,name in ipairs(attrNames) do
        local b = beforeAttr[name] or 0
        local a = afterAttr[name] or 0
        local delta = b - a
        if delta > 0 then
            table.insert(results, { kind = "attribute", name = name, delta = delta, before = b, after = a })
        end
    end

    table.sort(results, function(a,b) return a.delta > b.delta end)
    return results
end

local function fallbackNameSearch()
    local keywords = {"stamina","energy","jump","fatigue","stam","energi"}
    local found = {}
    for _,inst in ipairs(collectNumericCandidates()) do
        local lname = string.lower(inst.Name)
        for _,k in ipairs(keywords) do
            if string.find(lname, k, 1, true) then
                table.insert(found, { kind = "instance", inst = inst, name = inst.Name, delta = 0, before = inst.Value })
                break
            end
        end
    end
    -- attributes name-based
    if hum and hum.GetAttributeNames then
        for _,name in ipairs(hum:GetAttributeNames()) do
            local lname = string.lower(name)
            for _,k in ipairs(keywords) do
                if string.find(lname, k, 1, true) then
                    table.insert(found, { kind = "attribute", name = name, delta = 0, before = hum:GetAttribute(name) })
                    break
                end
            end
        end
    end
    return found
end

local function chooseBestCandidate(results)
    if not results or #results == 0 then return nil end
    -- pick top result
    local top = results[1]
    if top.kind == "instance" then
        return { kind = "instance", inst = top.inst, target = top.before or top.after or top.inst.Value }
    else
        return { kind = "attribute", name = top.name, target = top.before or top.after }
    end
end

local keepLoopConnection
local function keepStaminaFullLoop()
    if keepLoopConnection then return end
    keepLoopConnection = spawn(function()
        while unlimitedEnergy do
            RunService.Heartbeat:Wait()
            if not staminaTarget then
                RunService.Heartbeat:Wait()
            else
                if staminaTarget.kind == "instance" then
                    local inst = staminaTarget.inst
                    if inst and inst.Parent then
                        -- restore if it dropped
                        if inst.Value < staminaTarget.target then
                            pcall(function() inst.Value = staminaTarget.target end)
                        end
                    end
                elseif staminaTarget.kind == "attribute" then
                    if hum and hum.Parent then
                        local cur = hum:GetAttribute(staminaTarget.name)
                        if type(cur) == "number" and cur < staminaTarget.target then
                            pcall(function() hum:SetAttribute(staminaTarget.name, staminaTarget.target) end)
                        end
                    end
                end
            end
        end
        keepLoopConnection = nil
    end)
end

-- UI: Auto-detect & enable
EnergySection:CreateButton("Auto Detect & Enable Unlimited Energy", function()
    if detectRunning then
        warn("[Unlimited Energy] Deteksi sedang berjalan.")
        return
    end
    detectRunning = true
    print("[Unlimited Energy] Menjalankan deteksi...")
    local results = detectStaminaByJumpTest()
    if not results or #results == 0 then
        -- fallback name-based
        local fallback = fallbackNameSearch()
        if #fallback > 0 then
            print("[Unlimited Energy] Tidak ada nilai yang turun saat jump, pakai fallback berdasarkan nama.")
            staminaTarget = chooseBestCandidate(fallback)
        else
            print("[Unlimited Energy] Gagal menemukan candidate stamina (mungkin server-side atau memakai mekanik yang tidak diekspos ke client).")
            staminaTarget = nil
        end
    else
        print("[Unlimited Energy] Kandidat ditemukan:", results[1].name, " (delta="..tostring(results[1].delta)..")")
        staminaTarget = chooseBestCandidate(results)
    end

    if staminaTarget then
        unlimitedEnergy = true
        keepStaminaFullLoop()
        print("[Unlimited Energy] Aktif. Menjaga:", staminaTarget.kind, staminaTarget.name or (staminaTarget.inst and staminaTarget.inst.Name))
    else
        warn("[Unlimited Energy] Tidak ada target yang bisa dipertahankan dari sisi client.")
    end
    detectRunning = false
end)

-- UI: Turn OFF
EnergySection:CreateButton("Unlimited Energy OFF", function()
    unlimitedEnergy = false
    staminaTarget = nil
    print("[Unlimited Energy] OFF")
end)

-- reconnect on character change: re-detect hum references if needed
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    -- hum akan direset oleh setupCharacter(), jadi kita clear target supaya user dapat detect ulang
    staminaTarget = nil
end)
-- ===== end Improved Auto-Detect Unlimited Energy =====

