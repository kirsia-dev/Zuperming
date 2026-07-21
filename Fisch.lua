-- [[ 1. CLEANUP & INIT ]] --
if getgenv().ZuperMingActive then
    getgenv().ZuperMingActive = false
    if game.CoreGui:FindFirstChild("ZuperMing") then
        game.CoreGui.ZuperMing:Destroy()
    end
    getgenv().ZuperMingHook = false
    
    -- Safety Unanchor saat reload script
    if game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        game.Players.LocalPlayer.Character.HumanoidRootPart.Anchored = false
    end
    
    task.wait(0.2)
end

getgenv().ZuperMingActive = true
getgenv().ZuperMingHook = true

-- [[ 2. SERVICES ]] --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- [[ 3. GLOBAL CONFIG ]] --
local Config = {
    AutoEquip = false,
    AutoCast = false,
    AutoShake = false,
    AutoSpear = false,
    AutoSell = false,
    InstantBobber = false,
    SellInterval = 5,
    Mode = "Legit",

    SnapReel      = false,
    SnapFishName  = "None",
    SnapShinyType = "None",
    SnapMutation  = "None",

    -- Hapus Config.TotemName, ganti dengan ini:
    AutoTotem = false,
    TotemDay = "None",
    TotemNight = "None",
    TotemDelay = 60, -- Default delay 60 detik
    TotemBusy = false,
    TotemActive = false,

    AutoAppraise = false,
    ShinyType = "None",
    TargetSize = "None", -- Tambahan untuk filter Big
    TargetMutation = "None",

    -- Identity
    HideIdentity = false,
    CustomName = "ZuperMing User",
    CustomLevel = "Level: 999",
    -- Shop & Teleport
    SelectedLoc = nil,
    SelectedRod = "Flimsy Rod"
}

-- [[ 4. LOGIC FUNCTIONS ]] --

-- > Hook Reel System
local function HookReelController()
    local function FindModule(Name)
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("ModuleScript") and v.Name == Name then return v end
        end
        return nil
    end

    local function cancelFishing()
        local char = LocalPlayer.Character
        if not char then return end

        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if rootPart then rootPart.Anchored = false end

        local reelUI = LocalPlayer.PlayerGui:FindFirstChild("reel")
        if reelUI then reelUI:Destroy() end

        local hud = LocalPlayer.PlayerGui:FindFirstChild("hud")
        if hud then hud.Enabled = true end

        local rod = nil
        for _, tool in pairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool:FindFirstChild("events") then
                rod = tool
                break
            end
        end

        if rod then
            if rod:FindFirstChild("events") and rod.events:FindFirstChild("reset") then
                pcall(function() rod.events.reset:FireServer() end)
                pcall(function() rod.events.reset:FireServer() end)
            end

            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid then
                local rodName = rod.Name
                humanoid:UnequipTools()
                task.wait(0.1)
                local backpackRod = LocalPlayer.Backpack:FindFirstChild(rodName)
                if backpackRod then humanoid:EquipTool(backpackRod) end
            end
        end
    end

    local ReelModule = FindModule("ReelController")
    if ReelModule then
        local success, Controller = pcall(require, ReelModule)
        if success and Controller then
            if not Controller._OldStartReel then
                Controller._OldStartReel = Controller.StartReel
            end
            if not Controller._OldNew then
                Controller._OldNew = Controller.new
            end
            if not Controller._OldEndMinigame then
                Controller._OldEndMinigame = Controller.EndMinigame
            end

            Controller.EndMinigame = function(self, result)
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then root.Anchored = false end
                return Controller._OldEndMinigame(self, result)
            end

            Controller.StartReel = function(data)
                -- Skip jika totem sedang aktif
                if Config.TotemActive then
                    return Controller._OldStartReel(data)
                end

                local fishName     = data and data.fish and data.fish.Name
                local fishMutation = data and data.fish and data.fish.Mutation
                local iShiny       = data and data.fish and data.fish.Shiny == true
                local iSparkling   = data and data.fish and data.fish.Sparkling == true

                -- [SNAP REEL] Filter check
                if Config.SnapReel then
                    local nameOk = (Config.SnapFishName == "None") or (fishName == Config.SnapFishName)
                    local mutationOk = (Config.SnapMutation == "None") or (fishMutation == Config.SnapMutation)

                    local shinyOk = false
                    if Config.SnapShinyType == "None" then
                        shinyOk = true
                    elseif Config.SnapShinyType == "Shiny" then
                        shinyOk = iShiny and not iSparkling
                    elseif Config.SnapShinyType == "Sparkling" then
                        shinyOk = iSparkling
                    elseif Config.SnapShinyType == "Shiny + Sparkling" then
                        shinyOk = iShiny and iSparkling
                    end

                    if not (nameOk and mutationOk and shinyOk) then
                        print(string.format("[SnapReel] ❌ Skip: %s | Mut: %s | Shiny:%s Sparkling:%s",
                            tostring(fishName), tostring(fishMutation),
                            tostring(iShiny), tostring(iSparkling)))
                        task.spawn(cancelFishing)
                        return nil
                    end

                    print(string.format("[SnapReel] ✅ Match: %s | Mut: %s",
                        tostring(fishName), tostring(fishMutation)))
                end

                local Minigame = Controller._OldStartReel(data)
                if not Minigame then return end

                task.spawn(function()
                    while Minigame and Minigame.AddModifier do
                        if Config.Mode == "Fast" then
                            Minigame:AddModifier("barSize", "force", 1)
                            Minigame:AddModifier("progress", "force", 100)
                        elseif Config.Mode == "Legit" then
                            Minigame:AddModifier("barSize", "force", 1)
                            Minigame:AddModifier("resilience", "multiply", 5)
                        end
                        task.wait()
                    end
                end)

                return Minigame
            end

            Controller.new = Controller._OldNew
        end
    end
end
pcall(HookReelController)

-- > Auto Sell Logic
local SellEvent = ReplicatedStorage:WaitForChild("events"):WaitForChild("SellAll")
local function RunAutoSell()
    while Config.AutoSell and getgenv().ZuperMingActive do
        local Backpack = LocalPlayer:FindFirstChild("Backpack")
        if Backpack and #Backpack:GetChildren() > 1 then
            pcall(function()
                SellEvent:InvokeServer()
                print("💲 SellAll Fired!")
            end)
        end
        task.wait(Config.SellInterval)
    end
end

-- > Auto Spear Logic
local SpearEvent = ReplicatedStorage:WaitForChild("packages"):WaitForChild("Net"):WaitForChild("RE/SpearFishing/Minigame")
local SpearWaterFolder = Workspace:WaitForChild("Spearfishing Water", 5)

-- Daftar lokasi spearfishing
local SpearLocations = {
    ["Lost Jungle"]   = CFrame.new(-2591.05, 143.69, -1940.39) * CFrame.Angles(math.rad(180.00), math.rad(-29.96), math.rad(180.00)),
    ["Coral Bastion"] = CFrame.new(2597.93, -1102.88, 872.26)  * CFrame.Angles(math.rad(0.00), math.rad(-10.22), math.rad(0.00)),
    ["Tidefall"]      = CFrame.new(3000.22, -1110.21, 774.12)  * CFrame.Angles(math.rad(-180.00), math.rad(-11.25), math.rad(180.00)),
    ["Colapse Ruin"]  = CFrame.new(3085.12, -1133.90, 1737.09) * CFrame.Angles(math.rad(0.00), math.rad(44.08), math.rad(-0.00)),
    ["Crowned Ruins"] = CFrame.new(3050.45, -1137.82, 2062.73) * CFrame.Angles(math.rad(-180.00), math.rad(7.32), math.rad(-180.00)),
}

-- Default lokasi
Config.AutoSpearLocation = "Lost Jungle"

local function RunAutoSpear()
    -- Teleport ke lokasi yang dipilih saat pertama jalan
    local targetCFrame = SpearLocations[Config.AutoSpearLocation]
    if targetCFrame then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = targetCFrame
            task.wait(0.5) -- Tunggu sebentar setelah teleport
        end
    end

    while Config.AutoSpear and getgenv().ZuperMingActive do
        local foundAnyFish = false
        if SpearWaterFolder then
            for _, waterChild in ipairs(SpearWaterFolder:GetChildren()) do
                if not Config.AutoSpear then break end
                local zoneFish = waterChild:FindFirstChild("ZoneFish")
                if zoneFish then
                    for _, fish in ipairs(zoneFish:GetChildren()) do
                        if not Config.AutoSpear then break end
                        local currentUID = fish:GetAttribute("UID") or (fish:FindFirstChild("UID") and fish.UID.Value)
                        if currentUID then
                            foundAnyFish = true
                            task.spawn(function() SpearEvent:FireServer(currentUID) end)
                            task.wait(1.1)
                            task.spawn(function() SpearEvent:FireServer(currentUID, true) end)
                        end
                    end
                end
            end
        end
        if not foundAnyFish then task.wait(1.5) end
        task.wait(0.5)
    end
end

-- > Helper: Get Equipped Rod
local function getRod()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool:FindFirstChild("events") then return tool end
    end
    return nil
end

-- ============================================================
-- [AUTO CAST ONLY] Hanya fungsi melempar umpan otomatis
-- ============================================================
local shakeCooldown = {}

RunService.RenderStepped:Connect(function()
    local character = LocalPlayer.Character
    local rod = getRod()
    
    -- [AUTO CAST]
    if Config.AutoCast and rod then
        -- Cek apakah remote events tersedia
        if rod:FindFirstChild("events") and rod.events:FindFirstChild("castAsync") then
            local charFolder = rod:FindFirstChild("char")
            
            -- Jika folder 'char' kosong, berarti pancingan sedang tidak dilempar
            if not charFolder or #charFolder:GetChildren() == 0 then
                task.spawn(function()
                    pcall(function()
                        -- Mengirim sinyal cast ke server
                        rod.events.castAsync:InvokeServer(100, 1)
                    end)
                end)
            end
        end
    end
end)

-- ============================================================
-- [AUTO SHAKE] center + random offset ±5px + cooldown per button
-- ============================================================
task.spawn(function()
    while true do
        local shakeUI = PlayerGui:FindFirstChild("shakeui", true)

        if shakeUI then
            local safeZone = shakeUI:FindFirstChild("safezone")
            if safeZone then
                for _, button in pairs(safeZone:GetChildren()) do
                    if button.Name == "button" and button:IsA("ImageButton") and button.Visible then

                        -- Center + random offset ±5px
                        if Config.AutoShake then
                            button.AnchorPoint = Vector2.new(0.5, 0.5)
                            local offsetX = math.random(-5, 5)
                            local offsetY = math.random(-5, 5)
                            button.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
                            button.Size = UDim2.new(0, 50, 0, 50)
                        end

                        -- Cooldown per button 0.05s
                        if Config.AutoShake then
                            local now = tick()
                            if not shakeCooldown[button] or (now - shakeCooldown[button]) > 0.05 then
                                shakeCooldown[button] = now
                                local shakeEvent = button:FindFirstChild("shake")
                                if shakeEvent and shakeEvent:IsA("RemoteEvent") then
                                    for i = 1, 3 do
                                        pcall(function() shakeEvent:FireServer() end)
                                    end
                                end
                            end
                        end

                    end
                end
            end
        end

        task.wait() -- Kecepatan maksimal scan
    end
end)

-- ============================================================
-- [INSTANT BOBBER] - Logic terpisah
-- ============================================================
local BobberProcessed = {}

RunService.RenderStepped:Connect(function()
    if Config.InstantBobber then
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local rod = character:FindFirstChildOfClass("Tool")
            if rod then
                local bobber = rod:FindFirstChild("bobber")
                if bobber and bobber:IsA("BasePart") then

                    bobber.CanCollide = false
                    bobber.CanTouch = false
                    bobber.CanQuery = false

                    if not BobberProcessed[bobber] then
                        local rootPos = character.HumanoidRootPart.Position
                        local forwardDir = character.HumanoidRootPart.CFrame.LookVector * 3

                        local castX = rootPos.X + forwardDir.X
                        local castZ = rootPos.Z + forwardDir.Z

                        local rayOrigin = Vector3.new(castX, rootPos.Y + 50, castZ)

                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                        raycastParams.FilterDescendantsInstances = {character, rod}

                        local targetY = nil

                        local result = workspace:Raycast(rayOrigin, Vector3.new(0, -500, 0), raycastParams)
                        if result and result.Material == Enum.Material.Water then
                            targetY = result.Position.Y + (bobber.Size.Y / 2)
                        end

                        local waterKeywords = {"water", "ocean", "sea", "lake", "pond", "river", "pool"}
                        local function isWaterPart(part)
                            if not part:IsA("BasePart") then return false end
                            local nameLower = string.lower(part.Name)
                            for _, keyword in ipairs(waterKeywords) do
                                if string.find(nameLower, keyword) then return true end
                            end
                            if part.Transparency >= 0.3 and part.Transparency <= 0.9 then
                                local color = part.Color
                                if color.B > color.R and color.B > 0.3 then return true end
                            end
                            return false
                        end

                        if not targetY then
                            if result and result.Instance and isWaterPart(result.Instance) then
                                targetY = result.Instance.Position.Y + (result.Instance.Size.Y / 2)
                            else
                                local overlapParams = OverlapParams.new()
                                overlapParams.FilterDescendantsInstances = {character, rod}
                                overlapParams.FilterType = Enum.RaycastFilterType.Exclude

                                local nearbyParts = workspace:GetPartBoundsInBox(
                                    CFrame.new(castX, rootPos.Y, castZ),
                                    Vector3.new(20, 40, 20),
                                    overlapParams
                                )

                                for _, part in ipairs(nearbyParts) do
                                    if isWaterPart(part) then
                                        targetY = part.Position.Y + (part.Size.Y / 2)
                                        break
                                    end
                                end
                            end
                        end

                        if not targetY then
                            local checkPos = Vector3.new(castX, rootPos.Y, castZ)
                            local region = Region3.new(checkPos - Vector3.new(10, 50, 10), checkPos + Vector3.new(10, 50, 10))
                            region = region:ExpandToGrid(4)
                            local materials = workspace.Terrain:ReadVoxels(region, 4)
                            local size = materials.Size

                            for x = 1, size.X do
                                for y = size.Y, 1, -1 do
                                    for z = 1, size.Z do
                                        if materials[x][y][z] == Enum.Material.Water then
                                            targetY = region.CFrame.Position.Y + (y - size.Y / 2) * 4
                                            break
                                        end
                                    end
                                    if targetY then break end
                                end
                                if targetY then break end
                            end
                        end

                        if not targetY then
                            targetY = rootPos.Y - 2
                        end

                        BobberProcessed[bobber] = Vector3.new(castX, targetY, castZ)

                        bobber.Destroying:Once(function()
                            BobberProcessed[bobber] = nil
                        end)
                    end

                    local targetPos = BobberProcessed[bobber]
                    if targetPos then
                        bobber.CFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
                        bobber.AssemblyLinearVelocity = Vector3.zero
                        bobber.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end
        end
    else
        BobberProcessed = {}
    end
end)

-- ============================================================
-- [AUTO EQUIP] Equip rod otomatis dari backpack
-- ============================================================
task.spawn(function()
    while task.wait(0.5) do
        -- Double check: skip kalau totem sedang aktif
        if Config.AutoEquip and not Config.TotemActive then
            local char = LocalPlayer.Character
            local bp = LocalPlayer:FindFirstChild("Backpack")

            if char and not getRod() then
                if bp then
                    for _, tool in pairs(bp:GetChildren()) do
                        if tool:IsA("Tool") and tool:FindFirstChild("events") then
                            char.Humanoid:EquipTool(tool)
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- [AUTO USE TOTEM] 
-- ============================================================
local function equipAndUseTotem(name)
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not char or not bp then return end

    Config.TotemActive = true
    print("-- [AUTO TOTEM] Auto Equip blocked")

    for _, tool in pairs(bp:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == name then
            char.Humanoid:EquipTool(tool)
            task.wait(0.5)
            tool:Activate()
            print("-- [AUTO TOTEM] Activated: " .. name)
            Library:MakeNotify({Title = "Auto Totem", Content = "Totem activated!", Duration = 3})
            task.wait(1)
            Config.TotemActive = false
            print("-- [AUTO TOTEM] Auto Equip unblocked")
            return
        end
    end

    -- Kalau sudah ter-equip di karakter
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == name then
            tool:Activate()
            print("-- [AUTO TOTEM] Activated (already equipped): " .. name)
            Library:MakeNotify({Title = "Auto Totem", Content = "Totem activated!", Duration = 3})
            task.wait(1)
            Config.TotemActive = false
            print("-- [AUTO TOTEM] Auto Equip unblocked")
            return
        end
    end

    print("-- [AUTO TOTEM] Totem tidak ditemukan: " .. name)
    Library:MakeNotify({Title = "Auto Totem", Content = "Totem tidak ditemukan!", Duration = 4})
    Config.TotemActive = false
end


-- ============================================================
-- [FUNGSI BARU] Deteksi Siang / Malam dari UI Game
-- ============================================================
local function GetCurrentTimeOfDay()
    local label = LocalPlayer.PlayerGui:FindFirstChild("hud")
        and LocalPlayer.PlayerGui.hud:FindFirstChild("safezone")
        and LocalPlayer.PlayerGui.hud.safezone:FindFirstChild("worldstatuses")
        and LocalPlayer.PlayerGui.hud.safezone.worldstatuses:FindFirstChild("4_cycle")
        and LocalPlayer.PlayerGui.hud.safezone.worldstatuses["4_cycle"]:FindFirstChild("label")

    if label and label:IsA("TextLabel") then
        local text = string.lower(label.Text)
        if string.find(text, "night") then
            return "Night"
        else
            return "Day"
        end
    end
    return "Day" -- Default kalau UI belum loading
end

-- ============================================================
-- [UPDATE LOGIC] RunAutoTotem Smart Day/Night (Fast Response)
-- ============================================================
local function RunAutoTotem()
    TotemThread = task.spawn(function()
        local lastTimeOfDay = GetCurrentTimeOfDay()
        local lastUseTime = 0 -- Diset 0 agar saat pertama kali di-ON-kan langsung melempar totem
        
        while Config.AutoTotem do
            task.wait(1) -- Looping sekarang mengecek setiap 1 detik agar sangat responsif saat ganti hari

            -- Cek apakah lagi ada event aktif (Busy flag)
            if Config.TotemBusy then
                if tick() - TotemBusyTimer >= TOTEM_BUSY_DURATION then
                    Config.TotemBusy = false
                    print("-- [AUTO TOTEM] Clear, lanjut activate...")
                else
                    continue
                end
            end

            -- 1. Cek waktu sekarang
            local currentTime = GetCurrentTimeOfDay()
            
            -- 2. Cek apakah waktunya baru saja berubah
            local isTimeChanged = (currentTime ~= lastTimeOfDay)

            -- 3. Eksekusi JIKA waktu berubah ATAU delay sudah tercapai
            if isTimeChanged or (tick() - lastUseTime >= Config.TotemDelay) then
                local totemToUse = "None"

                if currentTime == "Night" then
                    totemToUse = Config.TotemNight
                else
                    totemToUse = Config.TotemDay
                end

                if totemToUse ~= "None" and totemToUse ~= "" then
                    if isTimeChanged then
                        print("-- [AUTO TOTEM] Waktu ganti ke " .. currentTime .. "! Langsung pakai: " .. totemToUse)
                    else
                        print("-- [AUTO TOTEM] Waktu: " .. currentTime .. " | Normal Activating: " .. totemToUse)
                    end
                    equipAndUseTotem(totemToUse)
                end

                -- 4. Reset tracker waktu dan reset ulang timer delay
                lastUseTime = tick()
                lastTimeOfDay = currentTime
            end
        end
    end)
end

-- Opsi totem (Ditambah "None" di paling depan biar bisa dimatikan manual)
local TotemOptions = {
    "None", "Sundial Totem", "Tempest Totem", "Windset Totem", "Clearcast Totem",
    "Smokescreen Totem", "Aurora Totem", "Meteor Totem", "Avalanche Totem",
    "Eclipse Totem", "Blizzard Totem", "Zeus Storm Totem", "Poseidon Wrath Totem",
    "Blue Moon Totem", "Shiny Totem", "Sparkling Totem", "Mutation Totem",
    "Starfall Totem", "Rainbow Totem", "Megalodon Hunt Totem", "Kraken Hunt Totem",
    "Colossal Dragon Hunt Totem", "Scylla Hunt Totem", "Dripstone Collapse Totem"
}

-- ============================================================
-- [FIXED RADAR LOGIC] Universal Toggle (Value / Enabled)
-- ============================================================
-- Deklarasikan di paling atas script agar bisa diakses On/Off
local RadarLoop = nil

local function ToggleRadar(state)
    if state then
        -- Fungsi untuk menyalakan
        RadarLoop = task.spawn(function()
            while true do
                local fishingPath = workspace:WaitForChild("zones"):FindFirstChild("fishing")
                if fishingPath then
                    for _, folder in pairs(fishingPath:GetChildren()) do
                        local targets = {"radar1", "radar2"}
                        for _, name in pairs(targets) do
                            local obj = folder:FindFirstChild(name)
                            if obj then
                                pcall(function()
                                    -- Paksa jadi TRUE
                                    if obj:IsA("BoolValue") then obj.Value = true end
                                    obj.Enabled = true
                                end)
                            end
                        end
                    end
                end
                task.wait(1) -- Cek setiap detik
            end
        end)
        print("Radar Bypass: ON")
    else
        -- FUNGSI OFF: Matikan Loop
        if RadarLoop then
            task.cancel(RadarLoop)
            RadarLoop = nil
        end
        
        -- FUNGSI OFF: Kembalikan Radar ke FALSE (Agar fungsi OFF terasa bekerja)
        local fishingPath = workspace:WaitForChild("zones"):FindFirstChild("fishing")
        if fishingPath then
            for _, folder in pairs(fishingPath:GetChildren()) do
                local targets = {"radar1", "radar2"}
                for _, name in pairs(targets) do
                    local obj = folder:FindFirstChild(name)
                    if obj then
                        pcall(function()
                            if obj:IsA("BoolValue") then obj.Value = false end
                            obj.Enabled = false
                        end)
                    end
                end
            end
        end
        print("Radar Bypass: OFF")
    end
end

-- > Identity Logic (Fixed)
local IdentityData = { OriginalName = "", OriginalLevel = "", Saved = false }

local function SaveIdentity()
    if IdentityData.Saved then return end
    local char = LocalPlayer.Character
    if char then
        local userFolder = char:WaitForChild("HumanoidRootPart", 5) and char.HumanoidRootPart:FindFirstChild("user")
        if userFolder then
            local n = userFolder:FindFirstChild("user")
            local l = userFolder:FindFirstChild("level")
            if n and n:IsA("TextLabel") then IdentityData.OriginalName = n.Text end
            if l and l:IsA("TextLabel") then IdentityData.OriginalLevel = l.Text end
            IdentityData.Saved = true
        end
    end
end

local function ToggleIdentity(state)
    local char = LocalPlayer.Character
    if not char then return end
    local userFolder = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild("user")
    if not userFolder then return end

    local nameLbl = userFolder:FindFirstChild("user")
    local levelLbl = userFolder:FindFirstChild("level")
    local titleLbl = userFolder:FindFirstChild("title")

    if state then
        SaveIdentity()
        if nameLbl then nameLbl.Text = Config.CustomName end
        if levelLbl then levelLbl.Text = Config.CustomLevel end
        if titleLbl then
            titleLbl.Text = "https://discord.gg/zuperming"
            titleLbl.Visible = true
            task.spawn(function()
                while Config.HideIdentity and getgenv().ZuperMingActive do
                    local t = tick()
                    titleLbl.TextColor3 = Color3.new(math.sin(t)*0.5+0.5, math.sin(t+2)*0.5+0.5, math.sin(t+4)*0.5+0.5)
                    task.wait()
                end
            end)
        end
    else
        if IdentityData.Saved then
            if nameLbl then nameLbl.Text = IdentityData.OriginalName end
            if levelLbl then levelLbl.Text = IdentityData.OriginalLevel end
            if titleLbl then titleLbl.Visible = false end
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    IdentityData.Saved = false
    task.wait(2)
    SaveIdentity()
end)
SaveIdentity()

-- > Data Tables (CFRAME)
local Locations = {
    ["???"] = CFrame.new(Vector3.new(497.28, -655.42, -1770.71), Vector3.new(497.28, -655.42, -1770.71) + Vector3.new(0.416, 0, 0.909)),
    ["Abyssal Zenith"] = CFrame.new(Vector3.new(-13447.83, -11050.60, 121.02), Vector3.new(-13447.83, -11050.60, 121.02) + Vector3.new(-0.186, 0, 0.983)),
    ["Ancient Archives"] = CFrame.new(Vector3.new(-3158.28, -754.61, 1873.31), Vector3.new(-3158.28, -754.61, 1873.31) + Vector3.new(0.052, 0, 0.999)),
    ["Ancient Isle"] = CFrame.new(Vector3.new(6057.48, 195.12, 286.64), Vector3.new(6057.48, 195.12, 286.64) + Vector3.new(0.231, 0, 0.973)),
    ["Atlantean Storm"] = CFrame.new(Vector3.new(-3662.12, 141.70, 780.09), Vector3.new(-3662.12, 141.70, 780.09) + Vector3.new(-0.051, 0, -0.999)),
    ["Atlantis"] = CFrame.new(Vector3.new(-4260.43, -603.40, 1825.14), Vector3.new(-4260.43, -603.40, 1825.14) + Vector3.new(0.231, 0, 0.973)),
    ["Behind Waterfall"] = CFrame.new(Vector3.new(20654.87, 139.89, -18007.32), Vector3.new(20654.87, 139.89, -18007.32) + Vector3.new(-0.784, 0, -0.621)),
    ["Birch Cay"] = CFrame.new(Vector3.new(1688.56, 147.51, -2388.44), Vector3.new(1688.56, 147.51, -2388.44) + Vector3.new(0.474, 0, -0.880)),
    ["Blue Moon - First Sea"] = CFrame.new(Vector3.new(2743.25, 131.50, 2512.18), Vector3.new(2743.25, 131.50, 2512.18) + Vector3.new(0.328, 0, -0.945)),
    ["Boreal Pines"] = CFrame.new(Vector3.new(21590.09, 250.16, 4012.17), Vector3.new(21590.09, 250.16, 4012.17) + Vector3.new(0.548, 0, -0.836)),
    ["Brine Pool"] = CFrame.new(Vector3.new(-1787.60, -142.69, -3384.50), Vector3.new(-1787.60, -142.69, -3384.50) + Vector3.new(-0.000, 0, -1.000)),
    ["Calm Zone"] = CFrame.new(-4356.28, -11160.87, 3733.14) * CFrame.Angles(math.rad(-180.00), math.rad(-48.88), math.rad(-180.00)),
    ["Carrot Garden"] = CFrame.new(Vector3.new(3719.45, -1127.99, -1089.54), Vector3.new(3719.45, -1127.99, -1089.54) + Vector3.new(0.663, 0, -0.749)),
    ["Castaway Cliffs"] = CFrame.new(Vector3.new(459.90, 204.00, -1938.74), Vector3.new(459.90, 204.00, -1938.74) + Vector3.new(0.000, 0, -1.000)),
    ["Challenger's Deep"] = CFrame.new(Vector3.new(670.20, -3357.35, -1693.42), Vector3.new(670.20, -3357.35, -1693.42) + Vector3.new(-0.231, 0, -0.973)),
    ["Collapsed Ruins"] = CFrame.new(Vector3.new(3143.34, -1101.96, 1624.77), Vector3.new(3143.34, -1101.96, 1624.77) + Vector3.new(0.000, 0, 1.000)),
    ["Coral Bestion"] = CFrame.new(Vector3.new(2524.73, -1096.11, 849.94), Vector3.new(2524.73, -1096.11, 849.94) + Vector3.new(-0.131, 0, 0.991)),
    ["Crimson Cavern"] = CFrame.new(Vector3.new(-994.66, -338.96, -4940.33), Vector3.new(-994.66, -338.96, -4940.33) + Vector3.new(-0.016, 0, -1.000)),
    ["Crowned Ruins"] = CFrame.new(Vector3.new(3121.78, -1127.33, 2050.75), Vector3.new(3121.78, -1127.33, 2050.75) + Vector3.new(-0.054, 0, 0.999)),
    ["Cryogenic Canal"] = CFrame.new(Vector3.new(19988.45, 913.86, 5407.79), Vector3.new(19988.45, 913.86, 5407.79) + Vector3.new(-0.225, 0, -0.974)),
    ["Crystal Cove"] = CFrame.new(Vector3.new(1361.44, -613.18, 2457.00), Vector3.new(1361.44, -613.18, 2457.00) + Vector3.new(-0.539, 0, 0.842)),
    ["Crystal Fissure"] = CFrame.new(Vector3.new(21731.42, 134.47, 4001.87), Vector3.new(21731.42, 134.47, 4001.87) + Vector3.new(0.575, 0, 0.818)),
    ["Cultist Lair"] = CFrame.new(Vector3.new(4260.41, -2003.00, -4677.10), Vector3.new(4260.41, -2003.00, -4677.10) + Vector3.new(-0.115, 0, -0.993)),
    ["Cultist Lair - Entrance"] = CFrame.new(Vector3.new(50.77, -288.42, 1910.56), Vector3.new(50.77, -288.42, 1910.56) + Vector3.new(0.003, 0, -1.000)),
    ["Cupid's Island"] = CFrame.new(Vector3.new(20641.13, 850.57, -17640.25), Vector3.new(20641.13, 850.57, -17640.25) + Vector3.new(0.617, 0, -0.787)),
    ["Disolate Deep"] = CFrame.new(Vector3.new(-1493.85, -234.70, -2837.54), Vector3.new(-1493.85, -234.70, -2837.54) + Vector3.new(-0.171, 0, -0.985)),
    ["Detonator's Rest"] = CFrame.new(Vector3.new(-1403.91, -843.74, -3482.22), Vector3.new(-1403.91, -843.74, -3482.22) + Vector3.new(0.206, 0, 0.979)),
    ["Earmark Island"] = CFrame.new(Vector3.new(1279.13, 140.10, 542.61), Vector3.new(1279.13, 140.10, 542.61) + Vector3.new(-0.047, 0, -0.999)),
    ["Ethereal Abyss"] = CFrame.new(Vector3.new(-3790.56, -566.77, 1852.19), Vector3.new(-3790.56, -566.77, 1852.19) + Vector3.new(-0.328, 0, 0.945)),
    ["Ethereal Trial"] = CFrame.new(Vector3.new(-3803.22, -664.01, 1830.52), Vector3.new(-3803.22, -664.01, 1830.52) + Vector3.new(0.039, 0, 0.999)),
    ["Executive Headquaters"] = CFrame.new(Vector3.new(-37.26, -246.55, 205.14), Vector3.new(-37.26, -246.55, 205.14) + Vector3.new(0.129, 0, 0.992)),
    ["Forgotten Tample"] = CFrame.new(Vector3.new(-5125.93, -1759.56, -9871.60), Vector3.new(-5125.93, -1759.56, -9871.60) + Vector3.new(-0.001, 0, 1.000)),
    ["Forsaken Shores"] = CFrame.new(Vector3.new(-2821.91, 213.92, 1518.06), Vector3.new(-2821.91, 213.92, 1518.06) + Vector3.new(-0.639, 0, 0.769)),
    ["Frigid Cavern"] = CFrame.new(Vector3.new(19800.15, 424.73, 5346.64), Vector3.new(19800.15, 424.73, 5346.64) + Vector3.new(-0.231, 0, -0.973)),
    ["Ghost Tavern"] = CFrame.new(Vector3.new(295.04, 800.00, -6893.89), Vector3.new(295.04, 800.00, -6893.89) + Vector3.new(-0.103, 0, -0.995)),
    ["Glacial Grotto"] = CFrame.new(Vector3.new(19934.08, 1211.92, 5282.95), Vector3.new(19934.08, 1211.92, 5282.95) + Vector3.new(0.601, 0, -0.799)),
    ["Grand Reef"] = CFrame.new(Vector3.new(-3618.28, 140.00, 502.10), Vector3.new(-3618.28, 140.00, 502.10) + Vector3.new(-0.000, 0, -1.000)),
    ["Haddock Rock"] = CFrame.new(Vector3.new(-527.92, 156.33, -464.76), Vector3.new(-527.92, 156.33, -464.76) + Vector3.new(-0.233, 0, -0.972)),
    ["Half of Whisper"] = CFrame.new(Vector3.new(4313.69, -2234.82, -4681.31), Vector3.new(4313.69, -2234.82, -4681.31) + Vector3.new(-0.353, 0, -0.936)),
    ["Harvesters Spike"] = CFrame.new(Vector3.new(-1260.49, 134.60, 1579.02), Vector3.new(-1260.49, 134.60, 1579.02) + Vector3.new(-0.391, 0, -0.920)),
    ["Inner Tidefall Castle"] = CFrame.new(Vector3.new(4542.61, -1101.11, 946.08), Vector3.new(4542.61, -1101.11, 946.08) + Vector3.new(0.148, 0, 0.989)),
    ["Keepers Altar"] = CFrame.new(Vector3.new(1319.22, -805.29, -105.08), Vector3.new(1319.22, -805.29, -105.08) + Vector3.new(-0.041, 0, -0.999)),
    ["Kraken Pool"] = CFrame.new(Vector3.new(-4398.01, -996.26, 2051.75), Vector3.new(-4398.01, -996.26, 2051.75) + Vector3.new(-0.130, 0, -0.992)),
    ["Lost Jungle"] = CFrame.new(Vector3.new(-2708.26, 150.20, -2054.09), Vector3.new(-2708.26, 150.20, -2054.09) + Vector3.new(-0.463, 0, -0.886)),
    ["Liminescent Cavern"] = CFrame.new(Vector3.new(-2708.26, 150.20, -2054.09), Vector3.new(-2708.26, 150.20, -2054.09) + Vector3.new(-0.463, 0, -0.886)),
    ["Merlins Hut"] = CFrame.new(Vector3.new(-946.89, 222.42, -985.54), Vector3.new(-946.89, 222.42, -985.54) + Vector3.new(0.314, 0, -0.949)),
    ["Mineshaft"] = CFrame.new(Vector3.new(-466.27, -851.80, -133.91), Vector3.new(-466.27, -851.80, -133.91) + Vector3.new(-0.111, 0, -0.994)),
    ["Moosewood"] = CFrame.new(Vector3.new(385.68, 134.50, 250.40), Vector3.new(385.68, 134.50, 250.40) + Vector3.new(0.221, 0, 0.975)),
    ["Mossjaw Rest"] = CFrame.new(Vector3.new(-4857.97, -1790.56, -10220.56), Vector3.new(-4857.97, -1790.56, -10220.56) + Vector3.new(0.017, 0, -0.999)),
    ["Mushgrove"] = CFrame.new(Vector3.new(2666.55, 133.50, -758.31), Vector3.new(2666.55, 133.50, -758.31) + Vector3.new(-0.002, 0, -1.000)),
    ["Mysterious Crack"] = CFrame.new(Vector3.new(-1108.50, -292.26, -3279.06), Vector3.new(-1108.50, -292.26, -3279.06) + Vector3.new(0.002, 0, -1.000)),
    ["Mysterious River"] = CFrame.new(Vector3.new(-1019.86, -325.13, -3748.90), Vector3.new(-1019.86, -325.13, -3748.90) + Vector3.new(0.002, 0, -1.000)),
    ["OverGrowth Caves"] = CFrame.new(Vector3.new(19807.06, 426.33, 5341.04), Vector3.new(19807.06, 426.33, 5341.04) + Vector3.new(-0.353, 0, -0.936)),
    ["Passage of Oaths"] = CFrame.new(Vector3.new(4363.88, -2482.57, -4682.22), Vector3.new(4363.88, -2482.57, -4682.22) + Vector3.new(-0.009, 0, -1.000)),
    ["Poseidon Tample"] = CFrame.new(Vector3.new(-4285.63, -683.42, 1168.26), Vector3.new(-4285.63, -683.42, 1168.26) + Vector3.new(-0.036, 0, -0.999)),
    ["Poseidon Trial"] = CFrame.new(Vector3.new(-3807.24, -550.69, 1082.53), Vector3.new(-3807.24, -550.69, 1082.53) + Vector3.new(0.623, 0, -0.782)),
    ["Roslit Bay"] = CFrame.new(Vector3.new(-1684.01, 156.08, 439.96), Vector3.new(-1684.01, 156.08, 439.96) + Vector3.new(-0.001, 0, -1.000)),
    ["Roslit Volcano"] = CFrame.new(Vector3.new(-1896.77, 176.63, 302.68), Vector3.new(-1896.77, 176.63, 302.68) + Vector3.new(0.261, 0, 0.965)),
    ["Roslit Hamlet"] = CFrame.new(Vector3.new(-1459.95, 133.14, 701.61), Vector3.new(-1459.95, 133.14, 701.61) + Vector3.new(-0.000, 0, -1.000)),
    ["Roslit Pond"] = CFrame.new(Vector3.new(-1787.08, 148.07, 636.50), Vector3.new(-1787.08, 148.07, 636.50) + Vector3.new(0.202, 0, 0.979)),
    ["Snow Burrow"] = CFrame.new(Vector3.new(2759.10, 97.95, 2602.91), Vector3.new(2759.10, 97.95, 2602.91) + Vector3.new(-0.055, 0, -0.998)),
    ["Snowcap"] = CFrame.new(2812.06, 280.78, 2559.54) * CFrame.Angles(math.rad(-180.00), math.rad(-3.16), math.rad(-180.00)),
    ["Snowcap Cave"] = CFrame.new(Vector3.new(2873.89, 144.51, 2601.30), Vector3.new(2873.89, 144.51, 2601.30) + Vector3.new(-0.374, 0, -0.927)),
    ["Statue Of Sovereignty"] = CFrame.new(Vector3.new(-138.67, 146.95, -1130.52), Vector3.new(-138.67, 146.95, -1130.52) + Vector3.new(0.289, 0, 0.957)),
    ["Sunken Depths"] = CFrame.new(Vector3.new(-4978.62, -694.01, 1821.56), Vector3.new(-4978.62, -694.01, 1821.56) + Vector3.new(-0.046, 0, -0.999)),
    ["Sunken Reliquary"] = CFrame.new(Vector3.new(2947.59, -1102.42, 72.65), Vector3.new(2947.59, -1102.42, 72.65) + Vector3.new(0.127, 0, -0.992)),
    ["Sunken Trial"] = CFrame.new(Vector3.new(-4937.98, -595.12, 1837.59), Vector3.new(-4937.98, -595.12, 1837.59) + Vector3.new(0.027, 0, -1.000)),
    ["Sunstone"] = CFrame.new(Vector3.new(-1047.27, 202.84, -1111.12), Vector3.new(-1047.27, 202.84, -1111.12) + Vector3.new(-0.200, 0, 0.980)),
    ["Sunstone Rift"] = CFrame.new(Vector3.new(-1032.72, -561.13, -1344.93), Vector3.new(-1032.72, -561.13, -1344.93) + Vector3.new(-0.602, 0, 0.799)),
    ["Sweetheart Shores"] = CFrame.new(Vector3.new(20650.27, 142.52, -17726.15), Vector3.new(20650.27, 142.52, -17726.15) + Vector3.new(-0.605, 0, -0.796)),
    ["Terrapin"] = CFrame.new(Vector3.new(-55.44, 133.12, 2029.67), Vector3.new(-55.44, 133.12, 2029.67) + Vector3.new(0.023, 0, 0.999)),
    ["Terrapin Island Cave"] = CFrame.new(Vector3.new(51.42, 152.97, 2006.59), Vector3.new(51.42, 152.97, 2006.59) + Vector3.new(0.036, 0, -0.999)),
    ["Thalassar's Secret"] = CFrame.new(Vector3.new(2888.87, -578.06, 1255.43), Vector3.new(2888.87, -578.06, 1255.43) + Vector3.new(0.097, 0, -0.995)),
    ["The Arch"] = CFrame.new(Vector3.new(1005.17, 132.93, -1241.42), Vector3.new(1005.17, 132.93, -1241.42) + Vector3.new(-0.122, 0, -0.993)),
    ["The Bunker"] = CFrame.new(Vector3.new(1846.38, -327.14, -2384.53), Vector3.new(1846.38, -327.14, -2384.53) + Vector3.new(0.220, 0, -0.975)),
    ["The Depths"] = CFrame.new(Vector3.new(952.22, -711.66, 1230.06), Vector3.new(952.22, -711.66, 1230.06) + Vector3.new(0.130, 0, -0.992)),
    ["The Depths - Maze"] = CFrame.new(Vector3.new(1162.42, -729.79, 1311.02), Vector3.new(1162.42, -729.79, 1311.02) + Vector3.new(-0.313, 0, -0.950)),
    ["The Keeper's Secret"] = CFrame.new(Vector3.new(2234.31, -802.77, 1035.99), Vector3.new(2234.31, -802.77, 1035.99) + Vector3.new(-0.016, 0, -1.000)),
    ["The Sanctum"] = CFrame.new(Vector3.new(4292.10, -2652.54, -4671.55), Vector3.new(4292.10, -2652.54, -4671.55) + Vector3.new(0.066, 0, 1.000)),
    ["The Void"] = CFrame.new(Vector3.new(-32099.49, 10010.04, -23302.99), Vector3.new(-32099.49, 10010.04, -23302.99) + Vector3.new(0.639, 0, -0.769)),
    ["Tidefall"] = CFrame.new(Vector3.new(3906.72, -1092.81, 912.64), Vector3.new(3906.72, -1092.81, 912.64) + Vector3.new(0.240, 0, 0.971)),
    ["Treasure Island"] = CFrame.new(Vector3.new(8293.00, 192.13, -17212.79), Vector3.new(8293.00, 192.13, -17212.79) + Vector3.new(-0.595, 0, -0.804)),
    ["Trident"] = CFrame.new(Vector3.new(-1481.28, -223.51, -2221.96), Vector3.new(-1481.28, -223.51, -2221.96) + Vector3.new(0.176, 0, -0.984)),
    ["Trident Entrance"] = CFrame.new(Vector3.new(-1476.97, -224.07, -2313.51), Vector3.new(-1476.97, -224.07, -2313.51) + Vector3.new(0.143, 0, -0.990)),
    ["Underground Music Venue"] = CFrame.new(Vector3.new(2051.02, -643.50, 2472.21), Vector3.new(2051.02, -643.50, 2472.21) + Vector3.new(0.038, 0, 0.999)),
    ["Underwater Cave"] = CFrame.new(Vector3.new(3204.82, -399.22, 976.88), Vector3.new(3204.82, -399.22, 976.88) + Vector3.new(0.706, 0, 0.708)),
    ["Underwater Opening"] = CFrame.new(Vector3.new(3219.60, 132.91, 847.59), Vector3.new(3219.60, 132.91, 847.59) + Vector3.new(-0.291, 0, -0.957)),
    ["Upper Snowcap"] = CFrame.new(Vector3.new(2822.26, 283.83, 2544.17), Vector3.new(2822.26, 283.83, 2544.17) + Vector3.new(0.560, 0, -0.829)),
    ["Veil of the Forsaken"] = CFrame.new(Vector3.new(-2357.54, -11177.86, 7106.80), Vector3.new(-2357.54, -11177.86, 7106.80) + Vector3.new(-0.345, 0, -0.939)),
    ["Vertigo"] = CFrame.new(Vector3.new(-72.79, -506.79, 1538.82), Vector3.new(-72.79, -506.79, 1538.82) + Vector3.new(0.050, 0, 1.000)),
    ["Vertigo Dip"] = CFrame.new(Vector3.new(-20.53, -702.61, 1232.18), Vector3.new(-20.53, -702.61, 1232.18) + Vector3.new(0.081, 0, 0.997)),
    ["Zeus Trial"] = CFrame.new(Vector3.new(-4296.86, -665.89, 2426.31), Vector3.new(-4296.86, -665.89, 2426.31) + Vector3.new(-0.005, 0, -1.000)),
    ["Zeus's Rod Room"] = CFrame.new(Vector3.new(-4307.33, -606.60, 2723.37), Vector3.new(-4307.33, -606.60, 2723.37) + Vector3.new(0.297, 0, 0.955)),
}

local locationNames = {}
for name in pairs(Locations) do table.insert(locationNames, name) end
table.sort(locationNames)

local RodList = {
    "Abyssal Specter Rod", "Adventurer's Rod", "Arctic Rod", "Astralhook Rod", "Aurora Rod", "Blazebringer Rod", 
    "Carbon Rod", "Carrot Rod", "Celestial Rod", "Cerulean Fang Rod", "Challenger's Rod", "Champions Rod", 
    "Christmas Tree Rod", "Dave Rod", "Depthseeker Rod", "Destiny Rod", "Developers Rod", "Dusekkar Rod", 
    "Eidolon Rod", "Ethereal Prism Rod", "Fabulous Rod", "Firefly Rod", "Flimsy Rod", "Free Spirit Rod", 
    "Frog Rod", "Great Dreamer Rod", "Great Rod of Oscar", "Haunted Rod", "Heaven's Rod", "Kings Rod", 
    "Kraken Rod", "Leviathan's Fang Rod", "Long Rod", "Lucky Rod", "Magma Rod", "Magnet Rod", "Midas Rod", 
    "Mythical Rod", "No-Life Rod", "Paper Fan Rod", "Pen Rod", "Phoenix Rod", "Popsicle Rod", "Poseidon Rod",
    "Precision Rod", "Rainbow Cluster Rod", "ReRod", "Reinforced Rod", "Resourceful Rod", "Riptide Rod",
    "Rod Of The Depths", "Rod Of The Eternal King", "Rod Of The Exalted One", "Rod Of The Forgotten Fang",
    "Rod Of The Zenith", "Santa's Miracle Rod", "Scurvy Rod", "Seraphic Rod", "Silly Fun Happy Rod",
    "Steady Rod", "Summit Rod", "Sunken Rod", "Tempest Rod", "The Lost Rod", "Training Rod", "Trident Rod",
    "Tryhard Rod", "Verdant Shear Rod", "Vineweaver Rod", "Volcanic Rod", "Voyager Rod", "Wildflower Rod",
    "Wisdom Rod", "Zeus Rod"
}
table.sort(RodList)

-- ============================================================
-- [ DATA: ENCHANT LIST ]
-- ============================================================
local EnchantsData = {
    ["Enchant Relic"] = {
        "Abyssal", "Blessed", "Blessed Song", "Blood Reckoning", "Breezed", "Chaotic", 
        "Chronos", "Clever", "Controlled", "Cupid", "Divine", "Eerie", "Flashline", 
        "Fractured", "Frightful", "Ghastly", "Gingerbread", "Greed", "Hasty", "Hunter", 
        "Insight", "Long", "Lucky", "Merry", "Momentum", "Mutated", "Noir", "Peppermint", 
        "Pharaohs Curse", "Putrid", "Quality", "Rage", "Resilient", "Santa", "Scavenger", 
        "Scrapper", "Sea King", "Spooky", "Steady", "Storming", "Swift", "Unbreakable", 
        "Valentine's", "Weak", "Wobbly", "Wormhole"
    },
    ["Exalted Relic"] = {
        "Anomalous", "Ferocious", "Herculean", "Immortal", "Invincible", 
        "Mystical", "Piercing", "Quantum", "Sea Overlord"
    },
    ["Cosmic Relic"] = {
        "Cryogenic", "Glittered", "Overclocked", "Sea Prince", 
        "Tenacity", "Tryhard", "Vicious", "Wise"
    },
    ["Twisted Relic"] = {
        "Rage", "Greed", "Fractured", "Putrid", 
        "Pharaohs Curse", "Weak", "Wobbly"
    }
}

table.sort(EnchantsData["Enchant Relic"])
table.sort(EnchantsData["Exalted Relic"])
table.sort(EnchantsData["Cosmic Relic"])
table.sort(EnchantsData["Twisted Relic"])

-- ============================================================
-- [ HELPER & LOGIC: AUTO ENCHANT ]
-- ============================================================
local AltarCFrame = CFrame.new(1310.65, -802.43, -82.53) * CFrame.Angles(math.rad(-180.00), math.rad(-12.43), math.rad(-180.00))

-- Relic yang pakai slot SECONDARY enchant (Cosmic & Twisted)
local SecondaryRelics = {
    ["Cosmic Relic"]  = true,
    ["Twisted Relic"] = true,
}

local function GetEquippedRodInfo()
    local RodInfo = { Name = "None", PrimaryEnchant = "None", SecondaryEnchant = "None" }
    local ok, _ = pcall(function()
        local rodsContainer = LocalPlayer.PlayerGui.hud.safezone.equipment.rods.scroll.safezone
        for _, rodFrame in pairs(rodsContainer:GetChildren()) do
            if rodFrame:IsA("Frame") then
                local equipBtn = rodFrame:FindFirstChild("equip")
                if equipBtn and equipBtn.Text == "[Equipped]" then
                    RodInfo.Name = rodFrame.Name
                    local enchantsFolder = rodFrame:FindFirstChild("rod") and rodFrame.rod:FindFirstChild("enchants")
                    if enchantsFolder then
                        local primaryLbl = enchantsFolder:FindFirstChild("enchant")
                        if primaryLbl and primaryLbl.Text ~= "" then
                            local clean1 = primaryLbl.Text:gsub("[^%a%s%-]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
                            if clean1 ~= "" then RodInfo.PrimaryEnchant = clean1 end
                        end
                        local secondaryLbl = enchantsFolder:FindFirstChild("secondary")
                        if secondaryLbl and secondaryLbl.Text ~= "" then
                            local clean2 = secondaryLbl.Text:gsub("[^%a%s%-]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
                            if clean2 ~= "" then RodInfo.SecondaryEnchant = clean2 end
                        end
                    end
                    break
                end
            end
        end
    end)
    return RodInfo
end

local function equipRelic(relicName)
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not char or not bp then return false end

    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool and currentTool.Name == relicName then return true end

    local tool = bp:FindFirstChild(relicName)
    if tool then
        char.Humanoid:EquipTool(tool)
        task.wait(0.3)
        return true
    end
    return false
end

local function FireEnchantAltar()
    local altar = Workspace:FindFirstChild("world")
        and Workspace.world:FindFirstChild("interactables")
        and Workspace.world.interactables:FindFirstChild("Enchant Altar")

    if altar then
        local prompt = altar:FindFirstChild("PromptTemplate")
        if prompt and not prompt:IsA("ProximityPrompt") then
            prompt = prompt:FindFirstChildOfClass("ProximityPrompt") or altar:FindFirstChildOfClass("ProximityPrompt")
        end
        if prompt then
            fireproximityprompt(prompt)
            return true
        end
    end
    return false
end

-- > The Main Auto Enchant Loop (Bypass Confirm via getconnections)
task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.AutoEnchant and getgenv().ZuperMingActive then
            local char = LocalPlayer.Character
            if not char then continue end
            
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end

            local currentRod = GetEquippedRodInfo()
            if currentRod.Name == "None" then continue end

            -- Cosmic & Twisted pakai secondary slot, sisanya primary
            local useSecondary = SecondaryRelics[Config.SelectedRelic] == true
            local currentEnchant = useSecondary and currentRod.SecondaryEnchant or currentRod.PrimaryEnchant
            
            -- Cek keberhasilan
            if currentEnchant and string.find(string.lower(currentEnchant), string.lower(Config.TargetEnchant)) then
                Config.AutoEnchant = false
                Library:MakeNotify({
                    Title = "Enchant Success!", 
                    Content = "Berhasil mendapatkan: " .. currentEnchant .. " pada " .. currentRod.Name, 
                    Duration = 8, 
                    Icon = "check"
                })
                print("✅ [AUTO ENCHANT] Target achieved:", currentEnchant)
            else
                -- 1. Teleport ke Altar jika terlalu jauh
                if (hrp.Position - AltarCFrame.Position).Magnitude > 10 then
                    hrp.CFrame = AltarCFrame
                    task.wait(0.5)
                end

                -- 2. Equip Relic
                local hasRelic = equipRelic(Config.SelectedRelic)
                if hasRelic then
                    -- 3. Fire Altar
                    local altarFired = FireEnchantAltar()
                    
                    if altarFired then
                        task.wait(0.5) -- Tunggu UI Dialog muncul
                        
                        -- 4. Auto Confirm pakai getconnections
                        pcall(function()
                            local GuiService = game:GetService("GuiService")
                            local VirtualInputManager = game:GetService("VirtualInputManager")
                            
                            local confirmBtn = LocalPlayer.PlayerGui.over.prompt:WaitForChild("confirm", 3)
                            
                            if not confirmBtn then
                                warn("[Enchant] confirm ga ketemu!")
                                return
                            end
                        
                            GuiService.SelectedObject = confirmBtn
                            task.wait(0.05)
                        
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                            task.wait(0.05)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                        
                            task.wait(0.1)
                            GuiService.SelectedObject = nil
                        end)
                    end
                    
                    task.wait(1.5) -- Jeda render gacha
                else
                    Config.AutoEnchant = false
                    Library:MakeNotify({
                        Title = "Auto Enchant Stopped", 
                        Content = Config.SelectedRelic .. " habis atau tidak ditemukan di tas!", 
                        Duration = 5
                    })
                end
            end
        end
    end
end)

-- Full Mutation List
local MutationList = {
    "None", "Albino", "Darkened", "Negative", "Glossy", "Translucent", 
    "Lunar", "Electric", "Silver", "Hexed", "Frozen", "Mosaic", "Scorched",
    "Amber", "Abyssal's Poisoned", "Fossilized", "Vined", "Crimson", "Midas", "Boreal",
    "Spirit", "Greedy", "Mythical", "Mourned", "Shrouded", "Coral", "Fallen"
}

-- [IMPROVEMENT: SMART CATCH LIST]
-- Mengurutkan nama mutasi dari yang terpanjang agar deteksi kata lebih akurat
local DetectionList = {}
for _, v in ipairs(MutationList) do table.insert(DetectionList, v) end
table.sort(DetectionList, function(a, b) return #a > #b end)

-- ============================================================
-- Helper Functions
-- ============================================================
local function FireProximityPrompt()
    local prompt = Workspace:FindFirstChild("world")
    if prompt then prompt = prompt:FindFirstChild("npcs") end
    if prompt then prompt = prompt:FindFirstChild("Appraiser") end
    if prompt then prompt = prompt:FindFirstChild("ProximityPrompt") end
    
    if prompt then
        fireproximityprompt(prompt)
        return true
    end
    return false
end

local function ParseAppraiseResult(text)
    local cleanText = text:gsub("<[^>]*>", "") -- Hapus tag HTML/RichText
    local hasShiny = cleanText:find("Shiny") ~= nil
    local hasSparkling = cleanText:find("Sparkling") ~= nil
    local hasBig = cleanText:find("Big") ~= nil -- Deteksi Big
    
    local mutation = "None"
    for _, mutName in ipairs(DetectionList) do
        if mutName ~= "None" and cleanText:find(mutName) then
            mutation = mutName
            break
        end
    end
    
    return {
        hasShiny = hasShiny,
        hasSparkling = hasSparkling,
        hasBig = hasBig,
        mutation = mutation,
        fullText = cleanText
    }
end

local function CheckIfTargetMatch(result)
    -- Jika ketiga dropdown diset "None", jangan jalan
    if Config.TargetMutation == "None" and Config.ShinyType == "None" and Config.TargetSize == "None" then 
        return false 
    end

    -- Berhenti jika Mutasi COCOK
    if Config.TargetMutation ~= "None" and result.mutation == Config.TargetMutation then return true end
    
    -- Berhenti jika Size (Big) COCOK
    if Config.TargetSize == "Big" and result.hasBig then return true end
    
    -- Berhenti jika Tier COCOK
    if Config.ShinyType ~= "None" then
        if Config.ShinyType == "Shiny" and result.hasShiny then return true end
        if Config.ShinyType == "Sparkling" and result.hasSparkling then return true end
        if Config.ShinyType == "ShinySparkling" and (result.hasShiny and result.hasSparkling) then return true end
    end
    
    return false
end

-- ============================================================
-- Auto Appraise Loop Logic (With Friend's Prompt Logic)
-- ============================================================

-- Table dari temanmu (Bisa dipake buat next update kalau mau ganti appraiser)
local appraiserPromptPaths = {
    ["Appraiser"] = function() 
        local prompt = nil
        pcall(function() prompt = workspace.world.npcs.Appraiser:FindFirstChildOfClass("ProximityPrompt") end)
        return prompt
    end,
    ["Drowned Appraiser"] = function() 
        local prompt = nil
        pcall(function() prompt = workspace.world.npcs.DrownedAppraiser:FindFirstChildOfClass("ProximityPrompt") end)
        return prompt
    end
}

local function RunAutoAppraise()
    local dialogRF = ReplicatedStorage:WaitForChild("packages"):WaitForChild("Net"):WaitForChild("RF/DialogInteract")
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if not hrp then
        Config.AutoAppraise = false
        return
    end

    task.spawn(function()
        -- 1. Simpan Posisi Asli & Teleport ke Appraiser Moosewood
        local originalCFrame = hrp.CFrame
        hrp.CFrame = CFrame.new(448.84, 150.54, 207.15) * CFrame.Angles(0, math.rad(-86.58), 0)
        task.wait(0.5) -- Tunggu karakter benar-benar sampai biar prompt muncul

        -- 2. Cari dan Trigger Proximity Prompt (Pake Logic Temenmu)
        local prompt = appraiserPromptPaths["Appraiser"]()
            
        if prompt then
            fireproximityprompt(prompt)
            task.wait(1)
        else
            print("Prompt Appraiser tidak ditemukan!")
            Library:MakeNotify({Title = "Error", Content = "Gagal interaksi dengan NPC!", Duration = 3})
            Config.AutoAppraise = false
            return
        end

        -- 3. Teleport Kembali ke Posisi Asli
        hrp.CFrame = originalCFrame
        task.wait(0.2)

        -- 4. Initial Dialog
        pcall(function() dialogRF:InvokeServer(1, 1) end)
        task.wait(0.3)

        -- 5. Loop Gacha Appraise
        print("Spamming Appraise...")
        while Config.AutoAppraise do
            pcall(function() dialogRF:InvokeServer(6, 1) end)
            task.wait(0.01)
            pcall(function() dialogRF:InvokeServer(1, 1) end)
            task.wait(0.01)

            -- Cek tulisan ikan di UI Subvalues karakter
            local subvalues = char:FindFirstChild("fishinfo") 
                and char.fishinfo:FindFirstChild("Info") 
                and char.fishinfo.Info:FindFirstChild("Subvalues")

            if subvalues and subvalues:IsA("TextLabel") then
                local result = ParseAppraiseResult(subvalues.Text)
                print("🔍 Cek Ikan:", result.fullText)

                if CheckIfTargetMatch(result) then
                    Config.AutoAppraise = false
                    print("✅ TARGET ACHIEVED!")
                    Library:MakeNotify({
                        Title = "Target Found!",
                        Content = "Berhasil dapat: " .. result.fullText,
                        Duration = 10,
                        Icon = "check"
                    })
                    break
                end
            end
        end
    end)
end

-- ============================================================
-- [ 1. DATA & CONFIG TOTEM ]
-- ============================================================
local TotemData = {
    ["Sundial Totem"] = "2,000C$",
    ["Tempest Totem"] = "2,000C$",
    ["Windset Totem"] = "2,000C$",
    ["Smokescreen Totem"] = "2,000C$",
    ["Meteor Totem"] = "75,000C$",
    ["Eclipse Totem"] = "200,000C$",
    ["Aurora Totem"] = "500,000C$"
}

local TotemListOnly = {}
for name in pairs(TotemData) do table.insert(TotemListOnly, name) end
table.sort(TotemListOnly)

Config.AutoBuyTotem = false
Config.SelectedTotem = ""
Config.TotemInterval = 5

-- ============================================================
-- [ 2. LOGIC AUTO BUYER ]
-- ============================================================
task.spawn(function()
    while true do
        if Config.AutoBuyTotem and getgenv().ZuperMingActive then
            if Config.SelectedTotem ~= "" then
                pcall(function()
                    ReplicatedStorage.events.purchase:FireServer(Config.SelectedTotem, "Item", nil, 1)
                end)
            end
            task.wait(Config.TotemInterval)
        else
            task.wait(1)
        end
    end
end)

-- LIST EVENT
local eventList = {
    "Baby Bloop Fish", "Bloop Fish", "Whales Pool", "Orcas Pool",
    "The Kraken Pool", "Animal Pool", "Plesiosaur Hunt", "Goldwraith Hunt",
    "Reef Titan Hunt", "Sunken Reliquary", "Omnithal Hunt",
    "Animal Pool - Second Sea", "Octophant Pool Without Elephant",
    "Sea Leviathan Pool", "Isonade", "Forsaken Veil - Scylla",
    "Blue Moon - Second Sea", "Blue Moon - First Sea", "LEGO",
    "LEGO - Studolodon", "Mosslurker", "Narwhal", "Whale Shark",
    "Birthday Megalodon", "Colossal Blue Dragon", "Colossal Ancient Dragon",
    "Colossal Ethereal Dragon", "Megalodon Ancient", "Megalodon Default",
    "Megalodon Phantom"
}

-- ============================================================
-- LOGIC DARI TEMAN KAMU (Dibuat jadi fungsi Return Text)
-- ============================================================
local function GetEventText()
    local contentText = ""
    
    -- Pakai FindFirstChild biar aman dan gak bikin script nyangkut (freeze)
    local zones = workspace:FindFirstChild("zones")
    local fishingZones = zones and zones:FindFirstChild("fishing")

    for _, eventName in ipairs(eventList) do
        local isActive = false
        if fishingZones then
            isActive = fishingZones:FindFirstChild(eventName) ~= nil
        end
        
        -- utf8.char(9989) itu ✅, utf8.char(10060) itu ❌
        local statusSymbol = isActive and utf8.char(9989) or utf8.char(10060)
        contentText = contentText .. eventName .. ": " .. statusSymbol .. "\n"
    end

    return contentText
end

local snapFishList = {
    "None",
    "Abyss Dart","Abyss Flicker","Abyss Snapper","Abyssacuda","Abyssal Bearded Seadevil",
    "Abyssal Devourer","Abyssal Goliath","Abyssal Grenadier","Abyssal King","Abyssal Maw",
    "Abyssal Slickhead","Abyssborn Monstrosity","Acanthodii","Aetherfin","Akkorokamui",
    "Algae Lurker","Alligator","Alligator Gar","Amberjack","Amblypterus","Anchovy",
    "Ancient Depth Serpent","Ancient Eel","Ancient Kraken","Ancient Megalodon","Ancient Orca",
    "Angelfish","Anglerfish","Anomalocaris","Antarctic Icefish","Apex Leviathan","Aqua Scribe",
    "Arapaima","Arctic Char","Armorhead","Ashclaw","Ashcloud Archerfish","Ashscale Minnow",
    "Atlantean Alchemist","Atlantean Anchovy","Atlantean Guardian","Atlantean Sardine",
    "Atlantic Goliath Grouper","Atlantic Halosaur","Atolla Jellyfish","Aurora Trout","Axolotl",
    "Azure Prowler","Baby Bloop Fish","Baby Pond Emperor","Banditfish","Barbed Shark",
    "Barracuda","Barreleye Fish","Basalt Loach","Basalt Pike","Batfish","Bauble Bass",
    "Beach Ball Pufferfish","Bearded Toadfish","Bellfin","Beluga","Bigeye Houndshark",
    "Bigeye Trevally","Bigfin Squid","Birgeria","Birthday Dumbo Octopus","Birthday Goldfish",
    "Birthday Megalodon","Birthday Squid","Black Dragon Fish","Black Ghost Knifefish",
    "Black Grouper","Black Scabbardfish","Black Snoek","Black Swallower","Black Veil Ray",
    "Blackfin Barracuda","Blackfish","Blackmouth Catshark","Blackspot Tuskfish","Blazebelly",
    "Blind Swamp Eel","Blisterback Blenny","Blistered Eel","Blisterfish","Blobfish",
    "Bloodscript Eel","Bloomtail","Bloop Fish","Blue Foamtail","Blue Langanose",
    "Blue Ribbon Eel","Blue Tang","Blue Whale","Bluefin Tuna","Bluefish","Bluegem Angelfish",
    "Bluegill","Bluehead Wrasse","Bluelip Batfish","Boarfish","Bog Lantern Goby","Bogscale",
    "Bone Lanternfish","Bowfin","Brackscale","Breaker Moth","Bream","Brimstone Angler",
    "Brine Phantom","Brine Sovereign","Bronze Corydoras","Buccaneer Barracuda","Bull Shark",
    "Bumpy Snailfish","Burbot","Burnt Betta","Butterflyfish","Candle Carp","Candy Cane Carp",
    "Candy Cane Cod","Candy Fish","Canopy Tetra","Capybass","Cardinal Tetra","Carol Carp",
    "Carp","Carrot Eel","Carrot Goldfish","Carrot Minnow","Carrot Pufferfish","Carrot Salmon",
    "Carrot Shark","Carrot Snapper","Carrot Turtle","Cataclysm Carp","Catfish","Cathulid",
    "Cathulith","Caustic Starwyrm","Cave Angel Fish","Cave Loach","Celestial Koi","Charybdis",
    "Chasm Leech","Chillback Whitefish","Chillfin Chimaera","Chillfin Herring","Chillshadow Chub",
    "Chinfish","Chinook Salmon","Chronos Deep Swimmer","Chub","Cinder Carp","Cinder Dart",
    "Cindercoil Eel","Cladoselache","Clout Carp","Clowned Triggerfish","Clownfish","Cluckfin",
    "Coalfin Darter","Cobalt Angelfish","Cobia","Cockatoo Squid","Cod","Coelacanth",
    "Coffin Crab","Coin Piranha","Coin Squid","Coin Triggerfish","Colossal Carp",
    "Colossal Saccopharynx","Colossal Squid","Column Crawler","Coney Grouper","Confetti Carp",
    "Confetti Shark","Cookiecutter Shark","Copper Rockfish","Coral Chromis","Coral Emperor",
    "Coral Guard","Coral Turkey","Cornetfish","Corsair Grouper","Countdown Perch","Crag-Crab",
    "Cragscale","Crawling Angler","Crescent Madtom","Crestscale","Crocokoi","Crown Bass",
    "Crowned Anglerfish","Crowned Royal Gramma","Crustal Colossus","Cryo Coelacanth",
    "Cryoshock Serpent","Cryoskin","Crystal Chorus","Crystal Corydoras","Crystal Frilled Shark",
    "Crystal Wrasse","Crystallized Seadragon","Cupid Crab","Cursed Eel","Cusk Eel",
    "Cutlass Fish","Cyclone Mako","Cyclone Scorpionfish","Dasyatis","Deep Behemoth",
    "Deep Crownfish","Deep Emperor","Deep Freeze Devilfish","Deep One","Deep-sea Dragonfish",
    "Deep-sea Hatchetfish","Deeplight Footballfish","Deepwater Stingray","Depth Drifter",
    "Depth Lurker","Depth Octopus","Diamond Discus","Diplomystus","Diplurus","DJ Spinopus",
    "Doctorfish Tang","Dogefin","Dolphin","Dreaming Aberration","Drift Claw","Driftfin",
    "Drifting Gildfin","Duckfin Tuna","Dumbo Octopus","Dunkleosteus","Dweller Catfish",
    "Echo Fisher","Echo Koi","Ectoplasm Eel","Edestus","Eel","Eelpout","Eldritch Horror",
    "Eldritch Spineback","Electric Eel","Elf Eel","Emerald Angelfish","Emerald Elephantnose",
    "Emperor Angelfish","Emperor Jellyfish","Eonshell","Escolar","Eternal Frostwhale",
    "Fangborn Gar","Fangtooth","Firecrest","Flamangler","Flamekissed Hawkfish","Flounder",
    "Flying Fish","Flying Gurnard","Foamrunner","Fogstripe","Forbidden Plesiosaur",
    "Forsaken Algae","Four Eyes Fish","Fourhorn Sculpin","Frankenshrimp","French Grunt",
    "Freshwater Pacu","Frigid Shrimp","Frilled Shark","Frost Minnow","Frost Ray",
    "Frostbite Flounder","Frostjaw Cod","Frostling Goby","Frostscale Fangtooth","Frosty Turkey",
    "Frozen Leviathan","Frozen Pike","Fruitcake Flounder","Furnace Leaper","Gale Snapper",
    "Galleon Goliath","Garra Andruzzii","Garra Typhlops","Gazerfish","Gem Anchovy","Gem Blobfish",
    "Gem Dolphin","Gem Eel","Gem Marlin","Gem Salmon","Gemscale Mandarinfish",
    "Gemstone Whale Shark","Ghost Minnow","Ghost Turkey","Ghoulfish","Giant Grouper",
    "Giant Lamprey","Giant Manta","Giant Moray","Giant Seadevil","Gillicus","Gingerbread Fish",
    "Ginsu Shark","Glacial Squid","Glacial Sturgeon","Glacier Pike","Glacier Swordfish",
    "Glacierfish","Glade Lurker","Glassfish","Glimmer Guppy","Gloamfin Gar","Globefish",
    "Gloombiter","Glowfin Skipper","Gnomefish","Goblin Shark","Goldband Butterflyfish",
    "Golden Dorado","Golden Seahorse","Golden Smallmouth Bass","Goldfin Octopus","Goldfish",
    "Goliath Tigerfish","Gollum Snakehead","Gorgon Grouper","Grand Reef Guardian",
    "Gravestone Stingray","Grayling","Great Barracuda","Great Goldcursed Shark",
    "Great Hammerhead Shark","Great White Shark","Greater Weever","Greenland Halibut",
    "Grey Carp","Gudgeon","Gulf Toadfish","Gust Tail","Haddock","Halibut","Hallucigenia",
    "Handfish","Harbinger Koi","Hawaiian Bobtail Squid","Heartbreak Herring","Helicoprion",
    "Helios Ray","Hellfire Haddock","Hellmaw Eel","Herring","Hexeye Snapper","Hidden Filefish",
    "Hidden Pipefish","Hogchoker","Hollow Gazer","Hollow Snapper","Hollowfin","Holly Haddock",
    "Horizon Tetra","Hot Cocoa","Hourglass Bass","Hydra Haddock","Hyneria","Ice Anchovy",
    "Ice Eel","Ice Jellyfish","Ice Octopus","Icebeard Shark","Icebreaker Haddock","Iced Perch",
    "Icefang Barracuda","Icy Carp","Icy Daggerfish","Icy Goldfish","Icy Salmon","Icy Tuna",
    "Icy Walleye","Infant Giant Seadevil","Infernal Iguanafish","Infernal Isonade",
    "Inferno Chaser","Islandhopper Butterflyfish","Isonade","Japanese Dragon Eel","Jellystud",
    "John Dory","Jungle Phantom","Jurassic Helicoprion","Kelpie","King Jellyfish",
    "Kissing Gourami","Kitefin Shark","Kittyfish","Knifefish","Krabbit","Kraken Koi",
    "Lagoon Dart","Lake Whitefish","Lantern Snapper","Lanternfish","Lapisjack","Largemouth Bass",
    "Lava Bream","Lava Lamprey","Leedsichthys","Lepidotes","Leviathan","Leviathan Bass",
    "Leviathan Humpback Anglerfish","Lightning Minnow","Lightning Pike","Lingcod","Long Pike",
    "Longnose Chimaera","Longtail Bass","Lost Turkey","Lovestorm Eel","Lovestorm Eel Supercharged",
    "Lovestorm Turtle","Lovestorm Turtle Supercharged","Lumilotl","Luminescent Minnow",
    "Lumpclinger","Lunar Monkfish","Lurkerfish","Lurking Crescent Pike","Lusca","Mackerel",
    "Maelstorm Shark","Mage Marlin","Magician Narwhal","Magma Leviathan","Magma Pike",
    "Magma Tang","Magma Turkey","Magmatic Hermit Crab","Mahi Mahi","Mained Lionfish","Manatee",
    "Mandarinfish","Manta Ray","Marble Maiden","Marsh Gar","Massive Marlin","Megalodon",
    "Merry Manta Ray","Mexican Tetra","Midnight Axolotl","Minnow","Minnowse","Mirage Toadfish",
    "Mistletoe Minnow","Molten Banshee","Molten Minnow","Molten Moray","Molten Ripple",
    "Molten Serpent","Moltenstripe","Moon Arctic Char","Moonfish","Moonridge Catfish",
    "Moonveil Killifish","Mosaic Swimmer","Mosasaurus","Mosslurker","Mossy Turkey",
    "Mourning Manta Ray","Mullet","Murkdrifter","Murkfin","Murkslither","Murky Turkey",
    "Mutated Shark","Mythic Fish","Napoleonfish","Narwhal","Nautilus","Neon Tetra","Nessie",
    "Net Wolffish","Northstar Serpent","Northstar Whale","Nurse Shark","Nutcracker Catfish",
    "Oak Stripetail","Oarfish","Obsidian Koi","Obsidian Ray","Obsidian Salmon","Obsidian Swordfish",
    "Ocean Triggerfish","Octophant","Oilfish","Olm","Olmdeer","Onychodus","Opalescent Catfish",
    "Orca","Orcanda","Oreochima","Ornament Fish","Ornament Pufferfish","Oyster toadfish",
    "Ozark Cavefish","Palaeoniscum","Pale Ghost Lumpfish","Pale Tang","Paradox Piranha",
    "Parktail Spinesnapper","Parrotfish","Party Popperfish","Party Pufferfish","Payara",
    "Pelagic Cod","Pelican Eel","Pengwhal","Peppermint Pike","Perch","Phanerorhynchus",
    "Phantom Brine","Phantom Jellyfish","Phantom Koi","Phantom Megalodon","Phantom Ray",
    "Piglet Pike","Pike","Pine Zephyrfish","Pink Betta","Pioneer Turkey","Piranha","Piranhamunk",
    "Pirarucu","Pirate Turkey","Polar Alligator","Polar Cod","Polar Prowler","Pollock",
    "Pond Emperor","Porcufish","Porcupinefish","Porgy","Poseidon Turkey","Potion Perch",
    "Primordial Levi","Prismatic Parrotfish","Profane Leviathan","Profane Ray","Psychedelic Frogfish",
    "Pufferfish","Pufferflute","Pumpkin Pufferfish","Pumpkinseed","Pupfish","Pyre Fang",
    "Pyrite Pufferfish","Pyro Pike","Pyrogrub","Quartzfin Queenfish","Queen Angelfish",
    "Rabbitfish","Racuda","Radiant Triplewart Seadevil","Rainbow Grouper","Razorfin","Red Drum",
    "Red Fangtooth","Red Snapper","Red Tang","Redeye Bass","Redeye Piranha","Redwood Duskray",
    "Reed Striker","Reef Goby","Reef Minnow","Reef Parrotfish","Reefdart","Reefrunner Snapper",
    "Regal Angelfish","Reindeer Ray","Rhizodus","Ribbon Eel","Ringle","Ripple Spine",
    "Rock Gunnel","Rock Hind","Rose Rockfish","Rotfin Eel","Rotjaw","Roughhead Grenadier",
    "Roundnose Grenadier","Royal Tigerfish","Ruby Lionfish","Ruby Rasbora","Sacred Lovestorm Turtle",
    "Saffron Cod","Sailfish","Salmon","Salmoose","Sand Tiger Shark","Sandslasher","Santa Pufferfish",
    "Santa Salmon","Santa Whale Shark","Sapphire Stargazer","Sarcastic Fringehead","Sardine",
    "Sawfish","Scalding Swordfish","Scalloped Hammerhead","Scaly Dragonfish","Scooty Salmon",
    "Scorchray","Scoria Swordfish","Scrawled Filefish","Screaming Fluke","Scurvy Sailfish","Scylla",
    "Sea Bass","Sea Leviathan","Sea Pickle","Sea Raven","Sea Snake","Sea Turtle","Seacow",
    "Searfin","Sergeant Major","Serpent Surgeonfish","Shadowfang Snapper","Shimmering Silverside",
    "Shipwreck Barracuda","Shiverfin Haddock","Shortfin Mako Shark","Shrimpanzee","Silver Roughy",
    "Silver Scuttler","Sinocyclocheilus","Siren Sculpin","Siren Sheep","Siren Singer","Sixgill Shark",
    "Skelefish","Skeletal Leviathan","Skeletal Nessie","Skipjack Tuna","Slag","Slain Maw",
    "Slate Tuna","Slate Turkey","Sloane's Viperfish","Slurpfloth","Small Spine Chimera",
    "Small-Spotted Catshark","Smallmouth Bass","Smeltjaw Snapper","Smogfish","Smolderfang",
    "Smoldering Stingray","Smooth toadfish","Snakehead","Snipefish","Snook","Snowback Char",
    "Snowfish","Snowflake Flounder","Snowflake Smelt","Snowgill Dace","Sockeye Salmon","Spadefish",
    "Sparkfin Tetra","Sparkler Sardine","Sparkling Corkfin","Spectral Serpent","Spider Salmon",
    "Spiderfish","Spiny Hatchetfish","Splendid toadfish","Split Eye Snapper","Spotted Drum",
    "Spotted Moray Eel","Sprayfin","Squid","Squirrelfish","Squirrelray","Starbellied Wolf Fish",
    "Starlit Weaver","Static Ray","Stingray","Stockingfish","Stoplight Loosejaw",
    "Stoplight Parrotfish","Storm Eel","Storm Skipper","Stormcloud Angelfish","Stormgazer",
    "Stringed Grouper","Sturgeon","Subzero Stargazer","Suckermouth Catfish","Sulfur Snapper",
    "Sunfish","Sunflare Tetra","Sunken Silverscale","Sunny Turkey","Sunray Sunscale","Sunsquid",
    "Surge Pike","Swamp Bass","Swampfish","Swampjaw","Sweetfish","Sweetheart Seahorse","Swordfish",
    "Tarnished Moongill","Tartaruga","Telescopefish","Tempest Ray","Temple Drifter","Temple Perch",
    "Tentacle Eel","Tentacled Horror","The Whispering One","Thornfish","Three-eyed Fish",
    "Thunder Bass","Thunder Serpent","Tidal Pike","Tidallow","Tide Fang","Tidepopper","Tilefish",
    "Tinsel Trout","Titan Tuna","Titanfang Grouper","Titanic Black Seadevil","Titanic Sturgeon",
    "Toilet Fish","Treble Bass","Trevally","Tripod Fish","Tropicspike","Trout","Trumpetfish",
    "Tumor Pike","Tuskmaw","Twilight Eel","Twilight Glowfish","Twilight Tentaclefish","Typhleotris",
    "Typhoon Tailfin","Typhoon Tuna","Umbral Shark","Vampire Perch","Vampire Squid",
    "Veilborn Parasite","Veinspawn","Velvet Belly Lanternshark","Verdant Mirage","Vinefish",
    "Viperfish","Void Angler","Void Emperor","Voidfin Mahi","Voidglow Ghostfish","Voidscale Guppy",
    "Volcanic Prowler","Voltfin Carp","Voltfish","Vortex Barracuda","Vortex Ray","Walleye",
    "Warty Angler","Warty Frogfish","Watching Glowfin","Wave Piercer","Werewolf Walleye",
    "Whale Shark","Whiptail Catfish","Whisker Bill","Whisper Eel","White Bass","White Perch",
    "White Sturgeon","Wraithfin","Wreath Wrasse","Wretched Guppy","X-ray Tetra","Xiphactinus",
    "Yellow Boxfish","Yellowfin Tuna","Zebrafishlet","Zombiefish",
}

local snapMutationList = {
    "None",
    "Amped","Obsidian","Igneous","Solar","Sweet","Lovely","Candy","Rose","Embraced","Lovestruck",
    "Heartburst","Ascended","Brined","Rusty","Coral","Mourned","Ocean's Ruin","Forgotten","Husk",
    "Requies","Fallen","Withered","Royal","New Years","Astraeus","Noctic","Corvid","Frostnova",
    "Merry","Jingle Bell","Boreal","Peppermint","Gingerbread","Frostbitten","Permafrost","Santa",
    "Honked","Gravy","Pancake","Putrid","Magical","Gleebous","Distraught","Lucid","Phantom",
    "Fabulous","Unlucky","Jackpot","Frightful","Spooky","Eerie","Necrotic","Batty","Wicked",
    "Jack's Curse","Nightmare","Breezed","Upside-Down","Part","Birthday","Poisoned","Vined",
    "Shrouded","Mossy","Toxic","Glowy","Dirty","Mastered","Luminescent","Crimson","Exploded",
    "Galaxy","Atomic","Alien","Fragmented","Mayhem","Madness","67","Tryhard","Darkness","Mango",
    "Oblivion","Summer","Popsicle","Beachy","Nova","Nico's Nyantics","Skrunkly","Nullified",
    "Galactic","Spirit","Lightened","Rainbow Cluster","Mace","Tormented","Surreal","Chilled",
    "Glacial","Rooted","Botanic","Venomous","Chlorowoken","Soulless","Wisp","Haunted","Spectral",
    "Golden","Fortune","Lustrous","Radiant","Siren's Spite","Evil","Serene","Quiet","Nocturnal",
    "Diurnal","Flora","Infernal","Patriotic","Snowy","Smurf","Puritas","Sacratus","Levitas",
    "Gemstone","Oscar","Carrot","Umbra","Awesome","Brother","Sanguine","Chaotic","Lost",
    "Moon-Kissed","Ember","Cracked","Emberflame","Cursed Touch","Bloom","Mother Nature",
    "Green Leaf","Brown Wood","Oak","Cement","Female","Mission Specialist","Fixer",
    "Paleontologist","Cursed","Ashen Fortune","Prismize","King's Blessing","Tentacle Surge",
    "Electric Shock","Charred","Crystalized","Heavenly","Sleet","Blighted","Albino","Darkened",
    "Electric","Glossy","Midas","Silver","Translucent","Negative","Mythical","Frozen","Atlantean",
    "Mosaic","Aurora","Nuclear","Hexed","Sunken","Greedy","Tidal","Lunar","Abyssal","Fungal",
    "Solarblaze","Celestial","Fossilized","Amber","Scorched","Spicy","Purified","Revitalized",
    "Seasonal","Aurous","Aurelian","Studded","Aureate","Aurulent","Aureolin","Sandstormy","Sandy",
    "Blessed","Unsellable","Subspace","Anomalous","Glyphed","Harmonized","Sinister","Ghastly",
    "Jolly","Festive","Minty","Firework","Wrath","Lightning","Astral","Stardust","Clover",
    "Blarney","Chocolate","Doomsday","Easter","Red","Green","Blue","Pink","Yellow","Bubblegum",
    "Lumpy","Rockstar","Colossal Ink","Neon","Lobster","Blue Moon","Rainbow",
}

    -- =============================================
    --  SETUP
    -- =============================================
    local ReplicatedStorage  = game:GetService("ReplicatedStorage")
    local LocalPlayer        = game:GetService("Players").LocalPlayer

    local DataController  = require(ReplicatedStorage.client.legacyControllers.DataController)
    local itemDisplayInfo = require(ReplicatedStorage.client.modules.ui.Backpack.itemDisplayInfo)
    local Backpack        = require(ReplicatedStorage.client.modules.ui.Backpack)

    -- =============================================
    --  STATIC LIST
    -- =============================================
    local rarityList = {
        "Trash", "Common", "Uncommon", "Unusual", "Rare",
        "Legendary", "Mythical", "Divine", "Exotic", "Secret",
        "Relic", "Fragment", "Gemstone", "Limited", "Apex",
        "Extinct", "Cataclysmic", "Special"
    }

    local mutationList = {
        "Amped", "Obsidian", "Igneous", "Solar", "Sweet", "Lovely", "Candy", "Rose",
        "Embraced", "Lovestruck", "Heartburst", "Ascended", "Brined", "Rusty", "Coral",
        "Mourned", "Ocean's Ruin", "Forgotten", "Husk", "Requies", "Fallen", "Withered",
        "Royal", "New Years", "Astraeus", "Noctic", "Corvid", "Frostnova", "Merry",
        "Jingle Bell", "Boreal", "Peppermint", "Gingerbread", "Frostbitten", "Permafrost",
        "Santa", "Honked", "Gravy", "Pancake", "Putrid", "Magical", "Gleebous", "Distraught",
        "Lucid", "Phantom", "Fabulous", "Unlucky", "Jackpot", "Frightful", "Spooky", "Eerie",
        "Necrotic", "Batty", "Wicked", "Jack's Curse", "Nightmare", "Breezed", "Upside-Down",
        "Part", "Birthday", "Poisoned", "Vined", "Shrouded", "Mossy", "Toxic", "Glowy",
        "Dirty", "Mastered", "Luminescent", "Crimson", "Exploded", "Galaxy", "Atomic", "Alien",
        "Fragmented", "Mayhem", "Madness", "67", "Tryhard", "Darkness", "Mango", "Oblivion",
        "Summer", "Popsicle", "Beachy", "Nova", "Nico's Nyantics", "Skrunkly", "Nullified",
        "Galactic", "Spirit", "Lightened", "Rainbow Cluster", "Mace", "Tormented", "Surreal",
        "Chilled", "Glacial", "Rooted", "Botanic", "Venomous", "Chlorowoken", "Soulless",
        "Wisp", "Haunted", "Spectral", "Golden", "Fortune", "Lustrous", "Radiant",
        "Siren's Spite", "Evil", "Serene", "Quiet", "Nocturnal", "Diurnal", "Flora",
        "Infernal", "Patriotic", "Snowy", "Smurf", "Puritas", "Sacratus", "Levitas",
        "Gemstone", "Oscar", "Carrot", "Umbra", "Awesome", "Brother", "Sanguine", "Chaotic",
        "Lost", "Moon-Kissed", "Ember", "Cracked", "Emberflame", "Cursed Touch", "Bloom",
        "Mother Nature", "Green Leaf", "Brown Wood", "Oak", "Cement", "Female",
        "Mission Specialist", "Fixer", "Paleontologist", "Cursed", "Ashen Fortune", "Prismize",
        "King's Blessing", "Tentacle Surge", "Electric Shock", "Charred", "Crystalized",
        "Heavenly", "Sleet", "Blighted", "Albino", "Darkened", "Electric", "Glossy", "Midas",
        "Silver", "Translucent", "Negative", "Mythical", "Frozen", "Atlantean", "Mosaic",
        "Aurora", "Nuclear", "Hexed", "Sunken", "Greedy", "Tidal", "Lunar", "Abyssal",
        "Fungal", "Solarblaze", "Celestial", "Fossilized", "Amber", "Scorched", "Spicy",
        "Purified", "Revitalized", "Seasonal", "Aurous", "Aurelian", "Studded", "Aureate",
        "Aurulent", "Aureolin", "Sandstormy", "Sandy", "Blessed", "Unsellable", "Subspace",
        "Anomalous", "Glyphed", "Harmonized", "Sinister", "Ghastly", "Jolly", "Festive",
        "Minty", "Firework", "Wrath", "Lightning", "Astral", "Stardust", "Clover", "Blarney",
        "Chocolate", "Doomsday", "Easter", "Red", "Green", "Blue", "Pink", "Yellow",
        "Bubblegum", "Lumpy", "Rockstar", "Colossal Ink", "Neon", "Lobster", "Blue Moon", "Rainbow"
    }

    -- =============================================
    --  HELPER
    -- =============================================
    local function getRarity(itemData)
        if not itemData or not itemData.name then return nil end
        local info = itemDisplayInfo[itemData.name]
        return info and info.rarity or nil
    end

    -- =============================================
    --  STATE
    -- =============================================
    local FishByName = {}   -- dynamic dari inventory: name → { uid, ... }

    local SelName     = {}
    local SelRarity   = {}  -- nilai asli dari rarityList
    local SelMutation = {}  -- nilai asli dari mutationList

    -- =============================================
    --  BUILD nama ikan dari inventory (dynamic)
    -- =============================================
    local function BuildFishNames()
        FishByName = {}

        local inventory = DataController.fetch("Inventory")
        if not inventory then
            warn("[AutoFav] Inventory nil!")
            return
        end

        for uid, itemData in pairs(inventory) do
            if type(itemData) ~= "table" or not itemData.name then continue end
            if not itemData.sub then continue end
            if typeof(itemData.sub.Weight) ~= "number" then continue end

            local name = itemData.name
            if not FishByName[name] then FishByName[name] = {} end
            table.insert(FishByName[name], uid)
        end
    end

    local function MakeNameOptions()
        local list = {}
        for name, uids in pairs(FishByName) do
            local label = #uids > 1 and (name .. " (" .. #uids .. ")") or name
            table.insert(list, label)
        end
        table.sort(list)
        if #list == 0 then table.insert(list, "Kosong") end
        return list
    end

    local function LabelToKey(label)
        return label:match("^(.-)%s*%(%d+%)$") or label
    end

    -- =============================================
    --  KUMPUL UID berdasarkan filter aktif
    -- =============================================
    local function CollectUIDs()
        local collected = {}
        local seen      = {}

        local inventory = DataController.fetch("Inventory")
        if not inventory then return collected end

        -- Kumpul UID dari filter nama
        for _, label in pairs(SelName) do
            local key  = LabelToKey(label)
            local uids = FishByName[key]
            if uids then
                for _, uid in pairs(uids) do
                    if not seen[uid] then
                        seen[uid] = true
                        table.insert(collected, uid)
                    end
                end
            end
        end

        -- Kumpul UID dari filter rarity & mutasi (scan inventory langsung)
        if #SelRarity > 0 or #SelMutation > 0 then
            -- buat set untuk lookup cepat
            local wantRarity   = {}
            local wantMutation = {}
            for _, r in pairs(SelRarity)   do wantRarity[r]   = true end
            for _, m in pairs(SelMutation) do wantMutation[m] = true end

            for uid, itemData in pairs(inventory) do
                if type(itemData) ~= "table" or not itemData.name then continue end
                if not itemData.sub then continue end
                if typeof(itemData.sub.Weight) ~= "number" then continue end
                if seen[uid] then continue end  -- sudah masuk dari filter nama

                local matchRarity   = wantRarity[getRarity(itemData) or "Unknown"]
                local matchMutation = wantMutation[itemData.sub.Mutation or ""]

                if matchRarity or matchMutation then
                    seen[uid] = true
                    table.insert(collected, uid)
                end
            end
        end

        return collected
    end

    -- =============================================
    --  INIT
    -- =============================================
    BuildFishNames()

    -- =============================================
    --  SETUP AUTO STORAGE
    -- =============================================
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players           = game:GetService("Players")

    local LocalPlayer    = Players.LocalPlayer
    local DataController = require(ReplicatedStorage.client.legacyControllers.DataController)
    local AddToStorage   = ReplicatedStorage.packages.Net["RE/Storage/RequestAddToStorage"]
    local AquariumJoin   = ReplicatedStorage.packages.Net["RE/PersonalAquarium/Join"]

    local STORAGE_CFRAME = CFrame.new(2931.66, 4252.44, 2975.60) * CFrame.Angles(math.rad(-0.00), math.rad(84.84), math.rad(0.00))
    local STORAGE_RADIUS = 15

    -- =============================================
    --  STATE
    -- =============================================
    local StorageFishByName = {}
    local StorageSelName    = {}
    local StorageActive     = false
    local DropStorage       = nil

    -- =============================================
    --  HELPER
    -- =============================================
    local function IsNearStorage()
        local char = LocalPlayer.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        return (hrp.Position - STORAGE_CFRAME.Position).Magnitude <= STORAGE_RADIUS
    end

    local function GetPlayerCFrame()
        local char = LocalPlayer.Character
        if not char then return nil end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        return hrp.CFrame
    end

    local function TeleportTo(cf)
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        hrp.CFrame = cf
    end

    local function LabelToNameKey(label)
        return label:match("^(.-)%s*%(%d+%)$") or label
    end

    -- =============================================
    --  BUILD dari Backpack
    -- =============================================
    local function BuildStorageFishNames()
        StorageFishByName = {}

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not backpack then return end

        local sources = {}
        for _, v in pairs(backpack:GetChildren()) do
            table.insert(sources, v)
        end
        if LocalPlayer.Character then
            for _, v in pairs(LocalPlayer.Character:GetChildren()) do
                table.insert(sources, v)
            end
        end

        local inv = DataController.fetch("Inventory")

        for _, tool in pairs(sources) do
            if not tool:IsA("Tool") then continue end

            local linkVal = tool:FindFirstChild("link")
            if not linkVal or not linkVal:IsA("StringValue") then continue end
            if linkVal.Value == "" then continue end

            local uid = linkVal.Value

            if inv and inv[uid] then
                local itemData = inv[uid]
                if not itemData.sub then continue end
                if typeof(itemData.sub.Weight) ~= "number" then continue end
            end

            local name = tool.Name
            if not StorageFishByName[name] then StorageFishByName[name] = {} end

            local dup = false
            for _, existing in pairs(StorageFishByName[name]) do
                if existing == uid then dup = true break end
            end
            if not dup then
                table.insert(StorageFishByName[name], uid)
            end
        end
    end

    local function MakeStorageNameOptions()
        local list = {}
        for name, uids in pairs(StorageFishByName) do
            local label = #uids > 1 and (name .. " (" .. #uids .. ")") or name
            table.insert(list, label)
        end
        table.sort(list)
        table.insert(list, 1, "None")
        return list
    end

    -- =============================================
    --  REFRESH SILENT
    -- =============================================
    local function RefreshDropdownSilent()
        BuildStorageFishNames()

        local newSel = {}
        for _, label in pairs(StorageSelName) do
            local key = LabelToNameKey(label)
            if key == "None" then continue end
            if StorageFishByName[key] then
                local uids = StorageFishByName[key]
                local newLabel = #uids > 1 and (key .. " (" .. #uids .. ")") or key
                table.insert(newSel, newLabel)
            end
        end
        StorageSelName = newSel

        pcall(function() DropStorage:SetValues(MakeStorageNameOptions()) end)
    end

    -- =============================================
    --  REFRESH dengan notify
    -- =============================================
    local function RefreshDropdown()
        BuildStorageFishNames()
        StorageSelName = {}

        pcall(function() DropStorage:SetValues(MakeStorageNameOptions()) end)

        local total = 0
        for _, uids in pairs(StorageFishByName) do total += #uids end
        Library:MakeNotify({
            Title    = "Refresh",
            Content  = total .. " ikan ditemukan di backpack!",
            Duration = 3
        })
    end

    -- =============================================
    --  KUMPUL UID
    -- =============================================
    local function CollectStorageUIDs()
        BuildStorageFishNames()

        local collected = {}
        local seen      = {}
        local wantName  = {}

        for _, label in pairs(StorageSelName) do
            local key = LabelToNameKey(label)
            if key == "None" then continue end
            wantName[key] = true
        end

        for name, uids in pairs(StorageFishByName) do
            if wantName[name] then
                for _, uid in pairs(uids) do
                    if not seen[uid] then
                        seen[uid] = true
                        table.insert(collected, uid)
                    end
                end
            end
        end

        return collected
    end

    -- =============================================
    --  MAIN: sekali jalan, bukan loop
    -- =============================================
    local function RunAutoStorage()
        if not StorageActive then return end

        -- Simpan posisi player sebelum teleport
        local lastCFrame = GetPlayerCFrame()
        if not lastCFrame then
            Library:MakeNotify({Title = "Error", Content = "Character tidak ditemukan!", Duration = 3})
            return
        end

        -- 1. Fire aquarium join
        pcall(function() AquariumJoin:FireServer(10594128852) end)
        task.wait(0.8)

        -- 2. Teleport ke storage (sekali)
        TeleportTo(STORAGE_CFRAME)

        -- 3. Tunggu sampai dekat storage (max 3 detik)
        local waited = 0
        while not IsNearStorage() and waited < 3 do
            task.wait(0.1)
            waited += 0.1
        end

        -- 4. Kirim semua ikan
        local uids  = CollectStorageUIDs()
        local count = 0

        for _, uid in pairs(uids) do
            pcall(function() AddToStorage:FireServer(uid) end)
            count += 1
            task.wait(0.1)
        end

        -- 5. Tunggu server proses
        task.wait(0.5)

        -- 6. Teleport balik ke posisi asal
        TeleportTo(lastCFrame)

        -- 7. Refresh dropdown
        RefreshDropdownSilent()

        -- 8. Notify hasil
        if count > 0 then
            Library:MakeNotify({
                Title    = "Auto Storage",
                Content  = count .. " ikan disimpan! Kembali ke posisi asal.",
                Duration = 3
            })
        else
            Library:MakeNotify({
                Title    = "Auto Storage",
                Content  = "Tidak ada ikan yang perlu disimpan.",
                Duration = 3
            })
        end

        StorageActive = false
    end

    -- =============================================
    --  INIT
    -- =============================================
    task.spawn(function()
        local _ = LocalPlayer:WaitForChild("Backpack")
        local waited = 0
        repeat
            task.wait(0.5)
            waited += 0.5
            BuildStorageFishNames()
        until next(StorageFishByName) ~= nil or waited >= 10

        pcall(function()
            if DropStorage then
                DropStorage:SetValues(MakeStorageNameOptions())
            end
        end)
    end)

    -- =============================================
    --  DROPDOWN
    -- =============================================
    BuildStorageFishNames()

    -- =============================================
    --  AUTO CLAIM STAR CRATER
    -- =============================================
    local StarCraterActive = false

    local function GetAllStarCraters()
        local craters = {}
        for _, obj in pairs(workspace:GetChildren()) do
            if obj.Name == "StarCrater" then
                table.insert(craters, obj)
            end
        end
        return craters
    end

    local function GetCraterPrompts(crater)
        local prompts = {}
        for _, item in pairs(crater:GetChildren()) do
            local center = item:FindFirstChild("Center")
            if not center then continue end
            for _, child in pairs(center:GetChildren()) do
                if child:IsA("ProximityPrompt") then
                    table.insert(prompts, child)
                end
            end
        end
        return prompts
    end

    local function RunStarCrater()
        if StarCraterActive then
            Library:MakeNotify({
                Title   = "Star Crater",
                Content = "Sedang berjalan, tunggu selesai!",
                Duration = 2
            })
            return
        end

        -- Simpan posisi awal
        local lastCFrame = nil
        local char0 = LocalPlayer.Character
        if char0 then
            local hrp0 = char0:FindFirstChild("HumanoidRootPart")
            if hrp0 then lastCFrame = hrp0.CFrame end
        end

        local craters = GetAllStarCraters()
        if #craters == 0 then
            Library:MakeNotify({
                Title   = "Starfall",
                Content = "Tidak ada Starfall",
                Duration = 3
            })
            return
        end

        StarCraterActive = true
        local totalClaim = 0

        Library:MakeNotify({
            Title   = "Star Crater",
            Content = #craters .. " crater ditemukan, mulai claim...",
            Duration = 2
        })

        for _, crater in pairs(craters) do
            local prompts = GetCraterPrompts(crater)

            for _, prompt in pairs(prompts) do
                if not prompt or not prompt.Parent then continue end

                -- Teleport tepat ke posisi prompt parent (Part)
                local part = prompt.Parent
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        -- Pakai .Position bukan .WorldPosition
                        hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
                        task.wait(0.5)
                    end
                end

                -- Fire proximity dengan pcall
                local ok, err = pcall(function()
                    fireproximityprompt(prompt)
                end)

                if ok then
                    totalClaim += 1
                else
                    warn("[StarCrater] fireproximityprompt error:", err)
                end

                task.wait(0.5)
            end

            task.wait(0.3)
        end

        -- Teleport balik ke posisi asal
        if lastCFrame then
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = lastCFrame end
            end
        end

        StarCraterActive = false

        Library:MakeNotify({
            Title    = "Star Crater",
            Content  = totalClaim .. " item berhasil di-claim!",
            Duration = 4
        })
    end


-- [[ 5. UI CONSTRUCTION ]] --
local Window = Library:Window({Footer = "Fisch - 1.25"})

-- //////////////////////////////////////////////////////////////
-- //////////////////// LOAD TABS ///////////////////////////////
-- //////////////////////////////////////////////////////////////
local function LoadInfoTab()
    local InfoTab = Window:AddTab({ Name = "Info", Icon = "info" })
    local EventSection = InfoTab:AddSection("Active Events Status", true)

    local EventParagraph = EventSection:AddParagraph({
        Title = "Live Event List",
        Content = GetEventText() 
    })
    
    -- Looping otomatis setiap 5 detik
    task.spawn(function()
        while true do
            task.wait(5)
            pcall(function()
                EventParagraph:SetContent(GetEventText())
            end)
        end
    end)

end


local function LoadMainTab()
    local MainTab = Window:AddTab({ Name = "Main", Icon = "main" })
    local FarmSection = MainTab:AddSection("Auto Farm")

    FarmSection:AddDropdown({ 
        Title = "Rod Catch Mode", 
        Options = {"Legit", "Fast"}, 
        Default = "Legit", 
        Callback = function(v) Config.Mode = v end 
    })

    FarmSection:AddToggle({
        Title = "Auto Equip Rod",
        Content = "Equip rod otomatis dari backpack",
        Default = false,
        Callback = function(v) Config.AutoEquip = v end
    })

    FarmSection:AddToggle({ 
        Title = "Auto Cast", 
        Content = "Cast otomatis saat bobber kosong",
        Default = false, 
        Callback = function(v) Config.AutoCast = v end 
    })

    FarmSection:AddToggle({ 
        Title = "Auto Shake", 
        Content = "Center button + FireServer shake otomatis",
        Default = false, 
        Callback = function(v) Config.AutoShake = v end 
    })

    FarmSection:AddToggle({
        Title = "Instant Bobber",
        Content = "Super fast Reel",
        Default = false,
        Callback = function(v)
            Config.InstantBobber = v
        end
    })

    local SnapSection = MainTab:AddSection("Snap Reel")

    SnapSection:AddDropdown({
        Title = "Target Fish",
        Options = snapFishList,
        Default = "None",
        Callback = function(v) Config.SnapFishName = v end
    })

    SnapSection:AddDropdown({
        Title = "Shiny Type",
        Options = {"None", "Shiny", "Sparkling", "Shiny + Sparkling"},
        Default = "None",
        Callback = function(v) Config.SnapShinyType = v end
    })

    SnapSection:AddDropdown({
        Title = "Mutation",
        Options = snapMutationList,
        Default = "None",
        Callback = function(v) Config.SnapMutation = v end
    })

    SnapSection:AddToggle({
        Title = "Enable Snap Reel",
        Content = "Cancel otomatis jika ikan tidak sesuai filter",
        Default = false,
        Callback = function(v)
            Config.SnapReel = v
            if v then
                Library:MakeNotify({
                    Title = "Snap Reel ON",
                    Content = string.format("Fish: %s | Shiny: %s | Mut: %s",
                        Config.SnapFishName, Config.SnapShinyType, Config.SnapMutation),
                    Duration = 4,
                    Icon = "target"
                })
            else
                Library:MakeNotify({Title = "Snap Reel", Content = "OFF", Duration = 2})
            end
        end
    })

    local SpearSection = MainTab:AddSection("Auto Spear Fishing")

    -- Dropdown pilih lokasi
    SpearSection:AddDropdown({
        Title = "Spear Location",
        Content = "Pilih lokasi spearfishing",
        Options = {"Lost Jungle", "Coral Bastion", "Tidefall", "Colapse Ruin", "Crowned Ruins"},
        Default = "Lost Jungle",
        Callback = function(Value)
            Config.AutoSpearLocation = Value
    
            -- Kalau spear lagi aktif, langsung teleport ke lokasi baru
            if Config.AutoSpear then
                local targetCFrame = SpearLocations[Value]
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") and targetCFrame then
                    char.HumanoidRootPart.CFrame = targetCFrame
                    Library:MakeNotify({
                        Title = "Spear Location",
                        Content = "Pindah ke: " .. Value,
                        Duration = 2
                    })
                end
            end
        end
    })
    
    -- Toggle Auto Spear
    SpearSection:AddToggle({
        Title = "Auto Spearfishing",
        Content = "Teleport & Catch Spear Fish",
        Default = false,
        Callback = function(Value)
            Config.AutoSpear = Value
            if Value then
                task.spawn(RunAutoSpear)
                Library:MakeNotify({
                    Title = "Auto Spear",
                    Content = "Started di: " .. Config.AutoSpearLocation,
                    Duration = 3
                })
            else
                Library:MakeNotify({
                    Title = "Auto Spear",
                    Content = "Stopped.",
                    Duration = 2
                })
            end
        end
    })

    FarmSection:AddButton({
        Title = "Instant Respawn / Reset",
        Callback = function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.Health = 0 -- Memicu logic 'Died' di controller game
            end
        end
    })

end

local function LoadAutoTab()
    local AutoTab = Window:AddTab({ Name = "Auto", Icon = "auto" })
    local SellSection = AutoTab:AddSection("Selling Config")
    local AutoAppraise = AutoTab:AddSection("Auto Appraise")
    local TotemSection = AutoTab:AddSection("Auto Totem")
    local EnchantSection = AutoTab:AddSection("Auto Enchant System")
    local FavSection = AutoTab:AddSection("Auto Favourite")
    local StorageSection = AutoTab:AddSection("Auto Fish Storage")
    local ChestSection = AutoTab:AddSection("Auto Collect All Chest")
    local AutoSection = AutoTab:AddSection("Auto Collect All Starfall")

    SellSection:AddInput({ 
        Title = "Sell Interval (s)", 
        Default = "5", 
        Callback = function(v) Config.SellInterval = tonumber(v) end 
    })
    
    SellSection:AddToggle({ 
        Title = "Enable Auto Sell", 
        Content = "Fire Remote SellAll Only", 
        Default = false, 
        Callback = function(v) 
            Config.AutoSell = v 
            if v then task.spawn(RunAutoSell) end 
        end 
    })

    -- Dropdown 1: Tier
    AutoAppraise:AddDropdown({
        Title = "Tier Requirement",
        Options = {"None", "Shiny", "Sparkling", "ShinySparkling"},
        Default = "None",
        Callback = function(v) Config.ShinyType = v end
    })

    -- Dropdown 2: Size (Big)
    AutoAppraise:AddDropdown({
        Title = "Size Requirement",
        Options = {"None", "Big"},
        Default = "None",
        Callback = function(v) Config.TargetSize = v end
    })

    -- Dropdown 3: Mutasi
    AutoAppraise:AddDropdown({
        Title = "Mutation Target",
        Options = MutationList,
        Default = "None",
        Callback = function(v) Config.TargetMutation = v end
    })

    -- Toggle Start
    AutoAppraise:AddToggle({
        Title = "Enable Auto Appraise",
        Content = "Otomatis Teleport & Gacha",
        Default = false,
        Callback = function(v)
            Config.AutoAppraise = v
            if v then
                -- Cegah script jalan kalau gak milih apa-apa
                if Config.ShinyType == "None" and Config.TargetMutation == "None" and Config.TargetSize == "None" then
                    Library:MakeNotify({Title = "Error", Content = "Pilih target Mutasi, Tier, atau Size dulu!", Duration = 3})
                    Config.AutoAppraise = false
                    return
                end
                RunAutoAppraise()
            end
        end
    })

    TotemSection:AddDropdown({
        Title = "Day Totem",
        Options = TotemOptions,
        Default = "None",
        Callback = function(v) Config.TotemDay = v end
    })

    TotemSection:AddDropdown({
        Title = "Night Totem",
        Options = TotemOptions,
        Default = "None",
        Callback = function(v) Config.TotemNight = v end
    })

    TotemSection:AddInput({
        Title = "Delay Per Use (Seconds)",
        Default = "60",
        Callback = function(v)
            local val = tonumber(v)
            if val and val > 0 then
                Config.TotemDelay = val
            end
        end
    })
    
    TotemSection:AddToggle({
        Title = "Enable Smart Auto Totem",
        Content = "Otomatis ganti totem sesuai waktu",
        Default = false,
        Callback = function(v)
            Config.AutoTotem = v
            if v then
                RunAutoTotem()
                Library:MakeNotify({Title = "Auto Totem", Content = "Smart Totem Started!", Duration = 3})
            else
                if TotemThread then task.cancel(TotemThread) end
                Config.TotemBusy = false
                Config.TotemActive = false
                Library:MakeNotify({Title = "Auto Totem", Content = "Stopped.", Duration = 3})
            end
        end
    })

    -- Gabungkan semua enchant jadi satu list agar UI tidak perlu update dinamis (Anti-Bug)
    -- Referensi dropdown enchant agar bisa diupdate secara dinamis
    local EnchantDropdownRef = nil

    -- Fungsi update isi dropdown enchant sesuai relic yang dipilih
    local function UpdateEnchantDropdown(relicType)
        if not EnchantDropdownRef then return end

        local list = EnchantsData[relicType]
        if not list or #list == 0 then return end

        -- Set default ke enchant pertama di list baru
        Config.TargetEnchant = list[1]

        -- Clear lalu isi ulang dropdown
        EnchantDropdownRef:Clear()
        for _, enchant in ipairs(list) do
            EnchantDropdownRef:AddOption(enchant)
        end
    end

    -- Dropdown 1: Pilih Relic Type
    EnchantSection:AddDropdown({
        Title = "Select Relic Type",
        Options = {"Enchant Relic", "Exalted Relic", "Cosmic Relic", "Twisted Relic"},
        Default = "Enchant Relic",
        Callback = function(Value)
            Config.SelectedRelic = Value
            -- Update list enchant otomatis saat relic diganti
            UpdateEnchantDropdown(Value)
        end
    })

    -- Dropdown 2: Target Enchant (isi awal dari Enchant Relic)
    local initialList = EnchantsData["Enchant Relic"]
    Config.TargetEnchant = initialList[1]

    EnchantDropdownRef = EnchantSection:AddDropdown({
        Title = "Target Enchant",
        Options = initialList,
        Default = initialList[1],
        Callback = function(Value)
            Config.TargetEnchant = Value
        end
    })

    -- Toggle Enable Auto Enchant
    EnchantSection:AddToggle({
        Title = "Enable Auto Enchant",
        Content = "Otomatis Equip Relic, Teleport, & Gacha Altar",
        Default = false,
        Callback = function(Value)
            Config.AutoEnchant = Value
            if Value then
                Library:MakeNotify({
                    Title = "Auto Enchant",
                    Content = "Started! Mencari: " .. (Config.TargetEnchant or "?") .. " [" .. (Config.SelectedRelic or "?") .. "]",
                    Duration = 3
                })
            end
        end
    })

    -- =============================================
    --  DROPDOWN 1 — Nama Ikan (dynamic)
    -- =============================================
    local DropName = FavSection:AddDropdown({
        Title    = "Filter by Nama Ikan",
        Options  = MakeNameOptions(),
        Default  = {},
        Multi    = true,
        Callback = function(Value)
            local t = {}
            for k, v in pairs(Value) do
                local entry = type(k) == "number" and v or (v == true and k or nil)
                if entry then table.insert(t, entry) end
            end
            SelName = t
        end
    })

    -- =============================================
    --  DROPDOWN 2 — Rarity (static, semua tampil)
    -- =============================================
    FavSection:AddDropdown({
        Title    = "Filter by Rarity",
        Options  = rarityList,
        Default  = {},
        Multi    = true,
        Callback = function(Value)
            local t = {}
            for k, v in pairs(Value) do
                local entry = type(k) == "number" and v or (v == true and k or nil)
                if entry then table.insert(t, entry) end
            end
            SelRarity = t
        end
    })

    -- =============================================
    --  DROPDOWN 3 — Mutasi (static, semua tampil)
    -- =============================================
    FavSection:AddDropdown({
        Title    = "Filter by Mutasi",
        Options  = mutationList,
        Default  = {},
        Multi    = true,
        Callback = function(Value)
            local t = {}
            for k, v in pairs(Value) do
                local entry = type(k) == "number" and v or (v == true and k or nil)
                if entry then table.insert(t, entry) end
            end
            SelMutation = t
        end
    })

    -- =============================================
    --  REFRESH BUTTON (hanya refresh nama ikan)
    -- =============================================
    FavSection:AddButton({
        Title    = "Refresh Nama Ikan",
        Content  = "Update list nama ikan dari inventory",
        Callback = function()
            BuildFishNames()
            SelName = {}
            pcall(function() DropName:SetValues(MakeNameOptions()) end)  -- ganti SetOptions → SetValues

            local total = 0
            for _, uids in pairs(FishByName) do total += #uids end
            Library:MakeNotify({
                Title    = "Refresh",
                Content  = total .. " ikan ditemukan!",
                Duration = 3
            })
        end
    })

    -- =============================================
    --  AUTO FAVOURITE TOGGLE
    -- =============================================
    FavSection:AddToggle({
        Title    = "Auto Favourite",
        Content  = "Favourite semua ikan dari filter yang dipilih",
        Default  = false,
        Callback = function(v)
            if not v then return end

            local hasFilter = (#SelName > 0) or (#SelRarity > 0) or (#SelMutation > 0)
            if not hasFilter then
                Library:MakeNotify({
                    Title   = "Warning",
                    Content = "Pilih minimal 1 filter dulu!",
                    Duration = 3
                })
                return
            end

            local uids  = CollectUIDs()
            local count = 0

            for _, uid in pairs(uids) do
                pcall(function()
                    Backpack.handleInput(uid, "favourite", true)
                end)
                count += 1
                task.wait(0.05)
            end

            Library:MakeNotify({
                Title    = "Auto Favourite",
                Content  = count .. " ikan berhasil di-favourite!",
                Duration = 4,
                Icon     = "star"
            })
        end
    })

    DropStorage = StorageSection:AddDropdown({
        Title    = "Pilih Ikan untuk Storage",
        Options  = MakeStorageNameOptions(),
        Default  = {},
        Multi    = true,
        Callback = function(Value)
            local t = {}
            for k, v in pairs(Value) do
                local entry = type(k) == "number" and v or (v == true and k or nil)
                if entry and entry ~= "None" then
                    table.insert(t, entry)
                end
            end
            StorageSelName = t
        end
    })

    -- =============================================
    --  REFRESH BUTTON
    -- =============================================
    StorageSection:AddButton({
        Title    = "Refresh Ikan",
        Content  = "Update list ikan dari backpack",
        Callback = function()
            RefreshDropdown()
        end
    })

    -- =============================================
    --  TOGGLE
    -- =============================================
    StorageSection:AddToggle({
        Title    = "Auto Storage",
        Content  = "Simpan ikan ke storage lalu kembali ke posisi asal",
        Default  = false,
        Callback = function(v)
            if v then
                if #StorageSelName == 0 then
                    Library:MakeNotify({
                        Title   = "Warning",
                        Content = "Pilih minimal 1 ikan dulu!",
                        Duration = 3
                    })
                    return
                end

                StorageActive = true
                task.spawn(RunAutoStorage)

                Library:MakeNotify({
                    Title   = "Auto Storage",
                    Content = "Memulai proses storage...",
                    Duration = 2
                })
            else
                StorageActive = false
            end
        end
    })

    -- =============================================
    --  BUTTON
    -- =============================================
    AutoSection:AddButton({
        Title    = "Claim Starfall",
        Content  = "Claim semua item di Starfall lalu kembali ke posisi asal",
        Callback = function()
            task.spawn(RunStarCrater)
        end
    })

    local function AutoCollectAllChests()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local ChestsFolder = workspace:FindFirstChild("world") and workspace.world:FindFirstChild("chests")
    
        if not ChestsFolder then 
            warn("❌ Folder Chests tidak ditemukan!") 
            return 
        end
    
        local allChests = ChestsFolder:GetChildren()
        if #allChests == 0 then
            Library:MakeNotify({Title = "Chest Farmer", Content = "Tidak ada chest saat ini.", Duration = 3})
            return
        end
    
        Library:MakeNotify({Title = "Chest Farmer", Content = "Memulai pengambilan " .. #allChests .. " Chest...", Duration = 5})
    
        for _, chest in ipairs(allChests) do
            -- Pastikan objek adalah chest dan memiliki ProximityPrompt
            local prompt = chest:FindFirstChild("ProximityPrompt") or (chest:FindFirstChild("ChestClosed") and chest.ChestClosed:FindFirstChild("ProximityPrompt"))
            
            if chest:IsA("Model") or chest:IsA("BasePart") then
                local character = LocalPlayer.Character
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
                if rootPart then
                    -- 1. Teleport ke atas chest
                    rootPart.CFrame = chest:GetPivot() * CFrame.new(0, 3, 0)
                    
                    -- 2. Tunggu sebentar agar server sinkron (PENTING!)
                    task.wait(0.5)
                    
                    -- 3. Cari prompt lagi (siapa tahu letaknya di dalam model)
                    local targetPrompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                    
                    if targetPrompt then
                        fireproximityprompt(targetPrompt)
                        print("✅ Berhasil mengambil: " .. chest.Name)
                    end
                    
                    -- 4. Jeda antar chest agar tidak instan (Anti-Kick)
                    task.wait(0.5)
                end
            end
        end
        
        Library:MakeNotify({Title = "Chest Farmer", Content = "Selesai mengambil semua chest!", Duration = 5, Icon = "check"})
    end
    
    ChestSection:AddButton({
        Title = "Collect All Chests (One-Time)",
        Callback = function()
            AutoCollectAllChests()
        end
    })

end

local function LoadShopTab()
    local ShopTab = Window:AddTab({ Name = "Shop", Icon = "shop" })
    local ShopSection = ShopTab:AddSection("Buy Rods")

    ShopSection:AddDropdown({
        Title = "Select Rod to Buy",
        Options = RodList,
        Default = "Flimsy Rod",
        Callback = function(Value)
            Config.SelectedRod = Value
        end
    })

    ShopSection:AddButton({
        Title = "Purchase Rod",
        Callback = function()
            if Config.SelectedRod then
                local PurchaseEvent = ReplicatedStorage.events.purchase
                PurchaseEvent:FireServer(Config.SelectedRod, "Rod", nil, 1)
                Library:MakeNotify({ Title = "Shop", Content = "Buying " .. Config.SelectedRod .. "...", Duration = 3, Icon = "cart" })
            end
        end
    })

    local TotemSection = ShopTab:AddSection("Auto Buy Totem")

    TotemSection:AddDropdown({
        Title = "Select Totem",
        Options = TotemListOnly,
        Default = "None",
        Callback = function(Value)
            Config.SelectedTotem = Value
            local price = TotemData[Value] or "Unknown"
            
            -- Kasih notif aja biar gampang liat harganya
            Library:MakeNotify({
                Title = "Totem Selected",
                Content = Value .. " harganya " .. price,
                Duration = 3,
                Icon = "shopping-cart"
            })
        end
    })

    TotemSection:AddInput({
        Title = "Interval (Seconds)",
        Default = "5",
        Callback = function(v) 
            Config.TotemInterval = tonumber(v) or 5 
        end
    })

    TotemSection:AddToggle({
        Title = "Enable Auto Buy",
        Default = false,
        Callback = function(v) 
            Config.AutoBuyTotem = v 
        end
    })
    local BaitSection = ShopTab:AddSection("Auto Buy Crate")

    BaitSection:AddDropdown({
        Title = "Select Item",
        Options = {"Bait Crate", "Tropical Bait Crate", "Quality Bait Crate", "Carbon Crate", "Metal Strongbox"},
        Default = "Bait Crate",
        Callback = function(Value)
            Config.SelectedShopItem = Value
        end
    })

    BaitSection:AddInput({
        Title = "Amount to Buy",
        Default = "1",
        Placeholder = "Enter quantity...",
        Callback = function(v) 
            Config.BuyItemAmount = tonumber(v) or 1 
        end
    })

    BaitSection:AddButton({
        Title = "Purchase Item",
        Callback = function()
            if Config.SelectedShopItem then
                local PurchaseEvent = game:GetService("ReplicatedStorage").events.purchase
                local amount = Config.BuyItemAmount or 1
                
                -- Loop untuk membeli sesuai jumlah input
                for i = 1, amount do
                    PurchaseEvent:FireServer(Config.SelectedShopItem, "Fish", nil, 1)
                    -- Delay sangat tipis agar tidak kena limit rate server
                    if amount > 5 then task.wait(0.1) end
                end

                Library:MakeNotify({ 
                    Title = "Purchase Success", 
                    Content = "Bought " .. tostring(amount) .. "x " .. Config.SelectedShopItem, 
                    Duration = 3, 
                    Icon = "shopping-cart" 
                })
            end
        end
    })

    local RemoteShopSection = ShopTab:AddSection("Item Shop")

    local selectedPurchaseItem = "Basic Diving Gear" -- Default
    local purchaseItemsList = {
        "Basic Diving Gear", "Advanced Diving Gear", 
        "Flippers", "Super Flippers", 
        "Basic Oxygen Tank", "Beginner Oxygen Tank", "Intermediate Oxygen Tank", "Advanced Oxygen Tank",
        "Winter Cloak", "Fish Radar", "Pickaxe", 
        "Glider", "Advanced Glider", "Tidebreaker",
        "Magic Mirror", "Traveler's Whistle", 
        "Crab Cage", "Reinforced Crab Cage", "Golden Crab Cage", "Coral Crab Cage", "Relic Crab Cage",
        "Conception Conch", "Abyssal Tonic", "Firework"
    }

    -- Dropdown Pilih Item
    RemoteShopSection:AddDropdown({
        Title = "Select Item",
        Options = purchaseItemsList,
        Default = "Basic Diving Gear",
        Callback = function(v)
            selectedPurchaseItem = v
        end
    })

    -- Button Eksekusi Beli
    RemoteShopSection:AddButton({
        Title = "Purchase Selected Item",
        Content = "Beli item yang dipilih secara remote",
        Callback = function()
            local purchaseEvent = game:GetService("ReplicatedStorage"):FindFirstChild("events") 
                and game:GetService("ReplicatedStorage").events:FindFirstChild("purchase")
                
            if purchaseEvent then
                -- Gunakan Remote Event sesuai kirimanmu
                purchaseEvent:FireServer(selectedPurchaseItem, "Item", nil, 1)
                
                Library:MakeNotify({
                    Title = "Purchase", 
                    Content = "Attempting to buy: " .. selectedPurchaseItem, 
                    Duration = 3
                })
            else
                Library:MakeNotify({Title = "Error", Content = "Purchase Event not found!", Duration = 3})
            end
        end
    })

    local ShopUISection = ShopTab:AddSection("Shop UI")

        -- Tombol Open Daily Shop
    ShopUISection:AddButton({
        Title = "Open Daily Shop",
        Content = "Buka menu Daily Shop secara remote",
        Callback = function()
            local dailyShopGui = LocalPlayer.PlayerGui:FindFirstChild("hud")
                and LocalPlayer.PlayerGui.hud:FindFirstChild("safezone")
                and LocalPlayer.PlayerGui.hud.safezone:FindFirstChild("DailyShop")

            if dailyShopGui then
                dailyShopGui.Visible = not dailyShopGui.Visible
                if dailyShopGui.Visible then
                    Library:MakeNotify({Title = "Shop", Content = "Daily Shop Opened!", Duration = 2})
                end
            end
        end
    })

    -- Tombol Open Black Market
    ShopUISection:AddButton({
        Title = "Open Black Market",
        Content = "Buka menu Black Market secara remote",
        Callback = function()
            local blackMarketGui = LocalPlayer.PlayerGui:FindFirstChild("hud")
                and LocalPlayer.PlayerGui.hud:FindFirstChild("safezone")
                and LocalPlayer.PlayerGui.hud.safezone:FindFirstChild("BlackMarket")

            if blackMarketGui then
                blackMarketGui.Visible = not blackMarketGui.Visible
                
                -- Biar makin mantap, kita kasih notif kalau kebuka
                if blackMarketGui.Visible then
                    Library:MakeNotify({Title = "Black Market", Content = "Black Market UI Opened!", Duration = 2})
                end
            else
                Library:MakeNotify({Title = "Error", Content = "Black Market UI tidak ditemukan!", Duration = 3})
            end
        end
    })

end

local function LoadTeleportTab()
    local TeleportTab = Window:AddTab({ Name = "Teleport", Icon = "teleport" })
    local TeleportSection = TeleportTab:AddSection("Locations")

    TeleportSection:AddDropdown({
        Title = "Select Location",
        Options = locationNames,
        Callback = function(Value) Config.SelectedLoc = Locations[Value] end
    })

    TeleportSection:AddButton({
        Title = "Teleport",
        Callback = function()
            if Config.SelectedLoc then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    -- Perubahan: Langsung pakai Config.SelectedLoc karena sudah CFrame
                    char.HumanoidRootPart.CFrame = Config.SelectedLoc
                end
            end
        end
    })

    local WhirlpoolSection = TeleportTab:AddSection("Teleport Whirlpool")

    WhirlpoolSection:AddButton({
        Title = "Teleport to Whirlpool",
        Content = "Cari dan TP ke Whirlpool terdekat",
        Callback = function()
            local activeFolder = workspace:FindFirstChild("active")
    
            if activeFolder then
                local targetWhirlpool = activeFolder:FindFirstChild("Safe Whirlpool")
    
                if targetWhirlpool then
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local targetCFrame
    
                        -- Cek apakah itu Model atau Part
                        if targetWhirlpool:IsA("Model") then
                            -- Kalau Model, pakai GetModelCFrame() atau PrimaryPart
                            if targetWhirlpool.PrimaryPart then
                                targetCFrame = targetWhirlpool.PrimaryPart.CFrame
                            else
                                targetCFrame = targetWhirlpool:GetModelCFrame()
                            end
                        elseif targetWhirlpool:IsA("BasePart") then
                            -- Kalau Part biasa, langsung ambil .CFrame
                            targetCFrame = targetWhirlpool.CFrame
                        end
    
                        if targetCFrame then
                            -- Offset +5 studs ke atas biar gak nyangkut di dalam object
                            hrp.CFrame = targetCFrame * CFrame.new(0, 5, 0)
    
                            Library:MakeNotify({
                                Title = "Success",
                                Content = "Teleported to Safe Whirlpool!",
                                Duration = 3
                            })
                        else
                            print("Tidak bisa dapat CFrame dari Safe Whirlpool!")
                        end
                    end
                else
                    Library:MakeNotify({
                        Title = "Whirlpool Not Found",
                        Content = "Whirlpool sedang tidak aktif di server ini.",
                        Duration = 3
                    })
                end
            else
                print("Folder workspace.active tidak ditemukan!")
            end
        end
    })

    local TeleportPlayer = TeleportTab:AddSection("Teleport Player") --////////////////////////

    local player = Players.LocalPlayer
    local PlayerDropdown = nil
    local selectedPlayerName = ""
    local playerList = {}
    local tpLoopThread -- Variabel untuk menyimpan thread loop

    local function GetTargetCFrame(targetName)
        local target = Players:FindFirstChild(targetName)
        if not target or not target.Character then return nil end
        
        local char = target.Character
        
        -- Cara 1: Coba ambil posisi Model (Paling Ampuh buat StreamingEnabled)
        local pivot = char:GetPivot()
        if pivot and pivot.Position.Y > -500 then -- Cek validitas posisi
            return pivot
        end

        -- Cara 2: Cari RootPart (Fallback)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.CFrame end

        -- Cara 3: Cari Torso (R6/R15 Fallback)
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if torso then return torso.CFrame end

        return nil
    end

    -- Fungsi update list (Tetap sama seperti kode Anda)
    local function updatePlayerList()
        playerList = {}
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player then
                table.insert(playerList, plr.Name)
            end
        end
        table.sort(playerList)
        if #playerList == 0 then
            table.insert(playerList, "No other players")
        end

        if _G.TelePlayer then
            print(#playerList)
            _G.TelePlayer:Clear()
            for i=1, #playerList do
                _G.TelePlayer:AddOption(playerList[i])
            end
            local isCurrentSelectionInvalid = not table.find(playerList, selectedPlayerName)
            local isPlaceholderSelected = (selectedPlayerName == "No other players" or selectedPlayerName == "No players" or selectedPlayerName == "")
            
            if isCurrentSelectionInvalid or (isPlaceholderSelected and playerList[1] ~= "No other players") then
                selectedPlayerName = playerList[1]
            end
        else
            if #playerList > 0 then
                selectedPlayerName = playerList[1]
            end
        end
    end

    Players.PlayerAdded:Connect(updatePlayerList)
    Players.PlayerRemoving:Connect(updatePlayerList)
    
    _G.TelePlayer = TeleportPlayer:AddDropdown({
        Title = "Select Player to Teleport",
        Content = "Pilih pemain untuk teleport",
        Options = playerList,
        Default = selectedPlayerName,
        MultiSelect = false,
        Callback = function(Value)
            selectedPlayerName = Value
        end
    })
    updatePlayerList()

    TeleportPlayer:AddButton({
        Title = "Update Player List",
        Callback = function() updatePlayerList() end
    })

    TeleportPlayer:AddButton({
        Title = "Teleport Now",
        Callback = function()
            local targetPlayer = GetTargetCFrame(selectedPlayerName)
            if targetPlayer then
                player.Character.HumanoidRootPart.CFrame = targetPlayer
            end
        end
    })

end

local function LoadMiscTab()
    local MiscTab = Window:AddTab({ Name = "Misc", Icon = "misc" })
    local IdentitySection = MiscTab:AddSection("Hide Identity")

    IdentitySection:AddInput({ 
        Title = "Custom Name", 
        Default = "ZuperMing User", 
        Callback = function(v) Config.CustomName = v end 
    })
    
    IdentitySection:AddInput({ 
        Title = "Custom Level", 
        Default = "Level: 999", 
        Callback = function(v) Config.CustomLevel = v end 
    })
    
    IdentitySection:AddToggle({ 
        Title = "Enable Hide ID", 
        Content = "Spoof Name/Level/Title", 
        Default = false, 
        Callback = function(v) 
            Config.HideIdentity = v 
            ToggleIdentity(v) 
        end 
    })
    -- [[ SECTION 2: PLAYER UTILITIES ]] --
    local PlayerUtilities = MiscTab:AddSection("Player Utilities")

    PlayerUtilities:AddToggle({
        Title = "Enable Radar Bypass",
        Default = false,
        Callback = function(Value)
            ToggleRadar(Value)
        end
    })

    -- Walk On Water Logic
    local wowEnabled = false
    local waterPart = nil
    local wowLoop = nil

    local function createWaterPlatform()
        if waterPart then waterPart:Destroy() end
        waterPart = Instance.new("Part")
        waterPart.Name = "WalkOnWater_Fixed"
        waterPart.Size = Vector3.new(20, 1, 20)
        waterPart.Transparency = 1 
        waterPart.Anchored = true
        waterPart.CanCollide = true
        waterPart.CastShadow = false
        waterPart.Parent = Workspace
    end

    local function startWalkOnWater()
        if not waterPart then createWaterPlatform() end
        
        wowLoop = RunService.Heartbeat:Connect(function()
            if not wowEnabled then return end
            
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            
            if root and humanoid then
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Include
                raycastParams.FilterDescendantsInstances = {Workspace.Terrain} 
                raycastParams.IgnoreWater = false 
                
                local rayOrigin = root.Position + Vector3.new(0, 10, 0) 
                local rayDirection = Vector3.new(0, -500, 0)
                local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                
                local shouldPlatform = false
                local targetY = -1000
                
                if rayResult then
                    if rayResult.Material == Enum.Material.Water then
                        shouldPlatform = true
                        targetY = rayResult.Position.Y
                    elseif humanoid:GetState() == Enum.HumanoidStateType.Swimming then
                        shouldPlatform = true
                        targetY = root.Position.Y - 0.5 
                    end
                end

                if shouldPlatform then
                    if (root.Position.Y - targetY) < 15 then
                        waterPart.CFrame = CFrame.new(root.Position.X, targetY - 0.5, root.Position.Z)
                        if root.Velocity.Y < -30 then
                            root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
                        end
                    else
                        waterPart.CFrame = CFrame.new(0, -1000, 0)
                    end
                else
                    waterPart.CFrame = CFrame.new(0, -1000, 0)
                end
            end
        end)
    end
    
    PlayerUtilities:AddToggle({
        Title = "Walk On Water",
        Content = "Membuat player bisa berjalan diatas air",
        Default = false,
        Callback = function(Value)
            wowEnabled = Value
            if Value then
                createWaterPlatform()
                startWalkOnWater()
            else
                if wowLoop then wowLoop:Disconnect() wowLoop = nil end
                if waterPart then waterPart:Destroy() waterPart = nil end
            end
        end
    })

    local GeneralFeatures = MiscTab:AddSection("General Features")
        
    local AntiAfk = {conn = nil}
    local VirtualUser = game:GetService("VirtualUser")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- 1. Definisikan Logic
    local function StartAntiAFKLogic()
        if AntiAfk.conn then AntiAfk.conn:Disconnect() AntiAfk.conn = nil end
        pcall(function()
            AntiAfk.conn = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new()) -- Klik Virtual saat Idle
            end)
            VirtualUser:CaptureController()
        end)
    end

    local function StopAntiAFKLogic()
        if AntiAfk.conn then AntiAfk.conn:Disconnect() AntiAfk.conn = nil end
    end

    GeneralFeatures:AddToggle({
        Title = "Anti AFK",
        Content = "Mencegah kick 20menit",
        Default = true,
        Callback = function(Value)
            if Value then
                StartAntiAFKLogic()
                if not isScriptLoading then
                    Library:MakeNotify({Title = "Anti-AFK", Content = "Enabled (Invisible Method)", Duration = 3, Icon = "shield-check"})
                end
            else
                StopAntiAFKLogic()
                if not isScriptLoading then
                    Library:MakeNotify({Title = "Anti-AFK", Content = "Disabled", Duration = 2, Icon = "x"})
                end
            end
        end
    })

end

-- //////////////////////////////////////////////////////////////
-- //////////////////// EXECUTE LOADERS /////////////////////////
-- //////////////////////////////////////////////////////////////
LoadInfoTab()
task.wait(0.05)
LoadMainTab()
task.wait(0.05)
LoadAutoTab()
task.wait(0.05)
LoadShopTab()
task.wait(0.05)
LoadTeleportTab()
task.wait(0.05)
LoadMiscTab()

task.wait(1)
Library:MakeNotify({ Title = "ZuperMing", Content = "Fisch Script Loaded!", Duration = 5, Icon = "check" })
