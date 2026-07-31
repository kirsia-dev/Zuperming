
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/kirsia-dev/Zuperming/refs/heads/main/ZuperMingGUI.lua"))()
Library:SetTheme("Grey")

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local Workspace       = game:GetService("Workspace")
local TweenService    = game:GetService("TweenService")
local HttpService     = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Lighting        = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local plr = LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local hrp = character:FindFirstChild("HumanoidRootPart")

local isLobby  = game.PlaceId == 79546208627805
local isForest = game.PlaceId == 126509999114328

RunService.Stepped:Connect(function()
    pcall(function()
        sethiddenproperty(plr, "SimulationRadius", math.huge)
        sethiddenproperty(plr, "MaxSimulationRadius", math.huge)
    end)
end)

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local folderPath = "StreeHub_99NITF"
makefolder(folderPath)
local configFile = folderPath .. "/config.json"

_G.Settings = {
    Main = {
        ["Auto Chop Tree"] = false, ["Selected Tree Type"] = "Small Tree",
        ["Kill Aura"] = false, ["Auto Recycling"] = false,
        ["Auto Plant Sapling"] = false, ["Auto Plant Circle"] = false,
        ["Auto Cook"] = false, ["Auto Eat"] = false,
        ["Auto Open Chest"] = false, ["Open Map"] = false, ["God Mode"] = false,
    },
    Quest = {
        ["Auto Lost Child Quest"] = false, ["Auto Lost Child2 Quest"] = false,
        ["Auto Lost Child3 Quest"] = false, ["Auto Lost Child4 Quest"] = false,
    },
    Misc = {
        ["Remove Fog"] = false, ["Anti Void"] = false,
        ["Night Teleport"] = false, ["Infinite Jump"] = false,
    },
    Esp  = { ["Enable Enemy ESP"] = false, ["Item ESP"] = false },
    AutoSave = false
}

function SaveConfig()
    local ok, r = pcall(function() return HttpService:JSONEncode(_G.Settings) end)
    if ok then writefile(configFile, r) end
end
function LoadConfig()
    if isfile(configFile) then
        local d = readfile(configFile)
        local ok, r = pcall(function() return HttpService:JSONDecode(d) end)
        if ok and type(r) == "table" then
            for k, v in pairs(r) do _G.Settings[k] = v end
        end
    else
        SaveConfig()
    end
end
LoadConfig()
_G.Settings.AutoSave = true

local toolsDamageIDs = {
    ["Old Axe"]   = "3_7367831688",
    ["Good Axe"]  = "112_7367831688",
    ["Strong Axe"] = "116_7367831688",
    ["Chainsaw"]  = "647_8992824875",
    ["Spear"]     = "196_8999010016"
}
local currentammount = 0

local killAuraEnabled = false; local killAuraRadius = 50
local chopAuraEnabled = false; local chopAuraRadius = 50
local autoFeedToggle  = false; local selectedFood = {}; local hungerThreshold = 75
local autoCookEnabled = false; local autoCookEnabledItems = {}
local autocookItems   = {"Morsel", "Steak"}
local autoUpgradeCampfireEnabled = false; local selectedCampfireItem = nil
local campfireFuelItems = {"Log", "Chair", "Coal"}
local campfireDropPos   = Vector3.new(-15.5, 8.12, -82.6)
local espItemsEnabled = false; local espMobsEnabled = false
local selectedItems_esp = {}; local selectedMobs_esp = {}; local espConnections = {}
local ie = {
    "Bandage","Bolt","Broken Fan","Broken Microwave","Cake","Carrot","Chair","Coal","Coin Stack",
    "Cooked Morsel","Cooked Steak","Fuel Canister","Iron Body","Leather Armor","Log","MadKit",
    "Metal Chair","MedKit","Old Car Engine","Old Flashlight","Old Radio","Revolver","Revolver Ammo",
    "Rifle","Rifle Ammo","Morsel","Sheet Metal","Steak","Tyre","Washing Machine"
}
local me = {"Bunny","Wolf","Alpha Wolf","Bear","Cultist","Crossbow Cultist","Alien"}
local junkItems  = {"Tyre","Bolt","Broken Fan","Broken Microwave","Sheet Metal","Old Radio","Washing Machine","Old Car Engine"}
local fuelItems  = {"Log","Chair","Coal","Fuel Canister","Oil Barrel"}
local foodItems  = {"Cake","Cooked Steak","Cooked Morsel","Steak","Morsel","Berry","Carrot"}
local medItems   = {"Bandage","MedKit"}
local equipItems = {"Revolver","Rifle","Leather Body","Iron Body","Revolver Ammo","Rifle Ammo","Giant Sack","Good Sack","Strong Axe","Good Axe"}
local alimentos  = {"Apple","Berry","Carrot","Cake","Chili","Cooked Morsel","Cooked Steak"}
local selectedJunk = {}; local selectedFuel = {}; local selectedFoodB = {}
local selectedMedical = {}; local selectedEquip = {}

local junkControl  = {enabled=false, running=false}
local fuelControl  = {enabled=false, running=false}
local foodControl  = {enabled=false, running=false}
local medControl   = {enabled=false, running=false}
local equipControl = {enabled=false, running=false}

local currentChests = {}; local currentChestNames = {}
local currentMobs_tp = {}; local currentMobNames_tp = {}
local selectedChest = nil; local selectedMob_tp = nil
local isCollecting = false; local originalPosition = nil
local infJump = false; local noclip = false
local autoReconnect = false; local antiAFK = false; local afkConnection = nil
local defaultWalk = 16; local defaultJump = 50
local currentWalk = defaultWalk; local currentJump = defaultJump
local savedServers = {}; local inputObj = nil
local espFolder = Instance.new("Folder"); espFolder.Name="ZSH_ESP"; espFolder.Parent = game.CoreGui

local selectedTargets  = {}
local selectedGear     = {}
local selectedFoodCol  = {}
local selectedGearCol  = {}
local selectedOtherCol = {}
local selectedChestCol = {}
local MAX_ITEMS        = 1000

local function notify(title, content, icon, dur)
    Library:SetNotification({ Title = title, Description = "| 99NITF", Content = content, Time = 0.5, Delay = dur or 4 })
end

local function includes(t, v) return t and table.find(t, v) ~= nil end

local function getModelPart(model)
    if model.PrimaryPart then return model.PrimaryPart end
    for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") then return p end end
end

local function moveToDest(item, dest)
    if item:IsA("Model") then item:PivotTo(dest)
    elseif item:IsA("BasePart") then item.CFrame = dest
    else
        local p = item:FindFirstChildWhichIsA("BasePart", true)
        if p then
            local m = p:FindFirstAncestorOfClass("Model")
            if m then m:PivotTo(dest) else p.CFrame = dest end
        end
    end
end

local function collectItems(selectedList, targetLabel)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    local folder = workspace:WaitForChild("Items")
    local total, notFound = 0, {}
    local dest
    if includes(selectedTargets, "Campfire") then dest = CFrame.new(0,8,0)
    elseif includes(selectedTargets, "Player") then dest = root.CFrame
    else notify("⚠️", "Pilih Target dulu!", "alert-triangle", 3) return end
    if not (selectedList and #selectedList > 0) then
        notify("⚠️", "Pilih item dulu!", "alert-triangle", 3) return
    end
    for _, name in ipairs(selectedList) do
        if total >= MAX_ITEMS then break end
        local found = false
        for _, item in ipairs(folder:GetChildren()) do
            if total >= MAX_ITEMS then break end
            if item.Name == name then
                found = true
                moveToDest(item, dest)
                total += 1
                task.wait(0.03)
            end
        end
        if not found then table.insert(notFound, name) end
    end
    if total > 0 then
        notify("✅", "Moved "..total.." item(s) → "..(targetLabel or "?"), "check-circle", 3)
    end
    if #notFound > 0 then
        notify("⚠️", "Not found: "..table.concat(notFound,", "), "alert-triangle", 4)
    end
end

local function createESP(part, name, color)
    if not (part and part:IsA("BasePart")) then return end
    if espFolder:FindFirstChild(name.."_"..part:GetFullName()) then return end
    local bg = Instance.new("BillboardGui")
    bg.Name = name.."_"..part:GetFullName(); bg.Adornee = part
    bg.Size = UDim2.new(0,100,0,50); bg.StudsOffset = Vector3.new(0,2,0)
    bg.AlwaysOnTop = true; bg.Parent = espFolder
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1; lbl.Text = name; lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0; lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 14; lbl.Parent = bg
end
local function removeESP(name)
    for _, e in ipairs(espFolder:GetChildren()) do if e.Name:find(name, 1, true) then e:Destroy() end end
end
local function Aesp(name, espType)
    local container = espType=="item" and workspace:FindFirstChild("Items") or workspace:FindFirstChild("Characters")
    if not container then return end
    for _, obj in ipairs(container:GetChildren()) do
        if obj.Name == name then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then createESP(part, name, espType=="item" and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,255,0)) end
        end
    end
end
local function Desp(name) removeESP(name) end

local function getChests()
    local chests, names = {}, {}
    local c = workspace:FindFirstChild("Items")
    if c then for _, o in ipairs(c:GetChildren()) do
        if o.Name=="Chest" or o.Name:find("Chest") then
            table.insert(chests,o); table.insert(names,o.Name) end
    end end
    return chests, names
end
local function getMobs()
    local mobs, names = {}, {}
    local c = workspace:FindFirstChild("Characters")
    if c then for _, o in ipairs(c:GetChildren()) do
        table.insert(mobs,o); table.insert(names,o.Name) end end
    return mobs, names
end

currentChests, currentChestNames = getChests()
currentMobs_tp, currentMobNames_tp = getMobs()
selectedChest  = currentChestNames[1]
selectedMob_tp = currentMobNames_tp[1]

local function findTool()
    for name, id in pairs(toolsDamageIDs) do
        local t = LocalPlayer.Inventory:FindFirstChild(name)
        if t then return t, id end
    end
end
local function equipTool(tool)
    if tool then
        local r = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("EquipItemHandle")
        r:FireServer("FireAllClients", tool)
    end
end
local function moveItemToPos(item, pos)
    if not item or not item:IsA("BasePart") then return end
    pcall(function()
        item.CFrame = CFrame.new(pos)
        item.Velocity = Vector3.new(0,0,0)
        item.AngularVelocity = Vector3.new(0,0,0)
    end)
end

local function bypassBring(items, stopFlag)
    if isCollecting then return end
    isCollecting = true
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then isCollecting=false; return end
    local root = c.HumanoidRootPart
    originalPosition = root.CFrame
    for _, name in ipairs(items) do
        if stopFlag and not stopFlag() then break end
        for _, item in ipairs(workspace:GetDescendants()) do
            if item.Name == name and (item:IsA("BasePart") or item:IsA("Model")) then
                local part = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
                if part and part.Parent and part.Parent ~= c then
                    pcall(function() part.CFrame = root.CFrame + Vector3.new(0,-1,0) end)
                    task.wait(0.1)
                end
            end
        end
    end
    if originalPosition then root.CFrame = originalPosition end
    isCollecting = false
end
local function runAutoBring(items, ctrl, flag)
    ctrl.running = true
    while ctrl.enabled do
        if #items > 0 then bypassBring(items, flag) end
        task.wait(5)
    end
    ctrl.running = false
end

local function getHunger()
    return math.floor(LocalPlayer.PlayerGui.Interface.StatBars.HungerBar.Bar.Size.X.Scale * 100)
end
local function feedPlayer(foodItem)
    for _, item in ipairs(workspace.Items:GetChildren()) do
        if item.Name == foodItem then
            ReplicatedStorage.RemoteEvents.RequestConsumeItem:InvokeServer(item); break
        end
    end
end
local function autoFeedLoop()
    while autoFeedToggle do
        if getHunger() < hungerThreshold then
            for _, f in ipairs(selectedFood) do feedPlayer(f); task.wait(0.5) end
        end
        task.wait(1)
    end
end

local function chopAuraLoop()
    while chopAuraEnabled do
        local root = (LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()):FindFirstChild("HumanoidRootPart")
        if root then
            local tool, toolID = findTool()
            if tool and (toolID=="3_7367831688" or toolID=="112_7367831688" or toolID=="116_7367831688") then
                equipTool(tool); currentammount += 1
                local map = workspace:FindFirstChild("Map")
                if map then
                    for _, folder in ipairs({map:FindFirstChild("Foliage"), map:FindFirstChild("Landmarks")}) do
                        if folder then
                            for _, obj in ipairs(folder:GetChildren()) do
                                if obj:IsA("Model") and obj.Name=="Small Tree" then
                                    local trunk = obj:FindFirstChild("Trunk")
                                    if trunk and trunk:IsA("BasePart") and (trunk.Position-root.Position).Magnitude<=chopAuraRadius then
                                        currentammount += 1
                                        pcall(function()
                                            ReplicatedStorage:WaitForChild("RemoteEvents").ToolDamageObject:InvokeServer(
                                                obj, tool, tostring(currentammount).."_7367831688",
                                                CFrame.new(-2.96,4.55,-75.95)
                                            )
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(0.1)
            else task.wait(1) end
        else task.wait(0.5) end
    end
end
local function killAuraLoop()
    while killAuraEnabled do
        local root = (LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()):FindFirstChild("HumanoidRootPart")
        if root then
            local tool, toolID = findTool()
            if tool and toolID then
                equipTool(tool)
                for _, entity in ipairs(workspace.Characters:GetChildren()) do
                    if entity:IsA("Model") then
                        local ep = entity:FindFirstChildWhichIsA("BasePart")
                        if ep and (ep.Position-root.Position).Magnitude <= killAuraRadius then
                            pcall(function()
                                ReplicatedStorage:WaitForChild("RemoteEvents").ToolDamageObject:InvokeServer(
                                    entity, tool, toolID, CFrame.new(ep.Position)
                                )
                            end)
                        end
                    end
                end
                task.wait(0.1)
            else task.wait(1) end
        else task.wait(0.5) end
    end
end

local function getAllTrees()
    local trees = {}
    local folders = {
        Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Landmarks"),
        Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Foliage")
    }
    local ttype = _G.Settings.Main["Selected Tree Type"]
    for _, folder in ipairs(folders) do
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if ttype=="Small Tree" and obj.Name=="Small Tree" and obj:IsA("Model") then table.insert(trees,obj)
                elseif ttype=="Big Tree" and (obj.Name=="TreeBig1" or obj.Name=="TreeBig2" or obj.Name=="TreeBig3") and obj:IsA("Model") then table.insert(trees,obj)
                end
            end
        end
    end
    return trees
end

local function getColorForName(name)
    local hash = 0
    for i=1,#name do hash=(hash+name:byte(i))%256 end
    return Color3.fromHSV(hash/256,1,1)
end

local function setFogState(en)
    if en then
        Lighting.FogEnd=1e6; Lighting.FogStart=1e6-1; Lighting.Brightness=5
        Lighting.ClockTime=14; Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
    else
        Lighting.FogEnd=1000; Lighting.FogStart=0; Lighting.Brightness=2
        Lighting.ClockTime=12; Lighting.Ambient=Color3.new(0.5,0.5,0.5); Lighting.OutdoorAmbient=Color3.new(0.5,0.5,0.5)
    end
end

local humanoid   = character:WaitForChild("Humanoid")
local HRP        = character:WaitForChild("HumanoidRootPart")
local bodyVel    = Instance.new("BodyVelocity")
local bodyGyro   = Instance.new("BodyGyro")
bodyVel.Velocity = Vector3.new(0,0,0); bodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
bodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
local function fly()
    bodyVel.Parent = HRP; bodyGyro.Parent = HRP; humanoid.PlatformStand = true
    local conn = RunService.Heartbeat:Connect(function()
        bodyGyro.CFrame = workspace.CurrentCamera.CFrame; bodyVel.Velocity = Vector3.new(0,0,0)
    end)
    return conn
end
local function unfly(conn)
    if conn then conn:Disconnect() end
    bodyVel.Parent=nil; bodyGyro.Parent=nil; humanoid.PlatformStand=false
end

local savedServerDropdown
local function refreshDropdown()
    if savedServerDropdown then savedServerDropdown:SetOptions(savedServers) end
end

local IsOnMobile = table.find({Enum.Platform.Android, Enum.Platform.IOS}, UserInputService:GetPlatform())
local WindowSize = IsOnMobile and UDim2.fromOffset(528,334) or UDim2.fromOffset(580,350)

local MainWindow = Library:CreateWindow({
    Title = "StreeHub x NatHub",
    Description = "| 99NITF | Forsaken",
    ["Tab Width"] = 120,
    Acrylic = false,
    Theme = "Grey"
})

local Tabs = {
    Home     = MainWindow:CreateTab({ Name = "Home",     Icon = "house" }),
    Lobby    = MainWindow:CreateTab({ Name = "Lobby",    Icon = "door-open" }),
    Main     = MainWindow:CreateTab({ Name = "Main",     Icon = "sword" }),
    Auto     = MainWindow:CreateTab({ Name = "Auto",     Icon = "play" }),
    Items    = MainWindow:CreateTab({ Name = "Items",    Icon = "backpack" }),
    Craft    = MainWindow:CreateTab({ Name = "Craft",    Icon = "wrench" }),
    Quest    = MainWindow:CreateTab({ Name = "Quest",    Icon = "scroll-text" }),
    Visual   = MainWindow:CreateTab({ Name = "Visual",   Icon = "eye" }),
    Teleport = MainWindow:CreateTab({ Name = "Teleport", Icon = "map-pin" }),
    Misc     = MainWindow:CreateTab({ Name = "Misc",     Icon = "layout-grid" }),
    Settings = MainWindow:CreateTab({ Name = "Settings", Icon = "settings" }),
}

Library:SetNotification({
    Title = "StreeHub x NatHub",
    Description = "| 99NITF",
    Content = "Script loaded! Game: "..(isForest and "Forest" or isLobby and "Lobby" or "Unknown"),
    Time = 0.5,
    Delay = 5,
})

local HomeSection = Tabs.Home:AddSection("Information", true)

HomeSection:AddButton({
    Title = "Copy Discord",
    Content = "discord.gg/jdmX43t5mY",
    Callback = function()
        if setclipboard then setclipboard("https://discord.gg/jdmX43t5mY") end
        notify("Discord", "Link copied!", "clipboard", 2)
    end,
})
HomeSection:AddParagraph({ Title = "Support", Content = "Setiap ada update game atau laporan bug, akan difix secepat mungkin." })

local HomePlayer = Tabs.Home:AddSection("Local Player", true)

HomePlayer:AddSlider({
    Title = "WalkSpeed",
    Content = "Default: 16",
    Min = 0, Max = 200, Default = 16, Increment = 1,
    Callback = function(v)
        currentWalk = v
        local c = LocalPlayer.Character
        if c and c:FindFirstChildOfClass("Humanoid") then c:FindFirstChildOfClass("Humanoid").WalkSpeed = v end
    end,
})
HomePlayer:AddSlider({
    Title = "JumpPower",
    Content = "Default: 50",
    Min = 0, Max = 200, Default = 50, Increment = 1,
    Callback = function(v)
        currentJump = v
        local c = LocalPlayer.Character
        if c and c:FindFirstChildOfClass("Humanoid") then c:FindFirstChildOfClass("Humanoid").JumpPower = v end
    end,
})
HomePlayer:AddButton({
    Title = "Reset Default",
    Callback = function()
        local c = LocalPlayer.Character
        if c and c:FindFirstChildOfClass("Humanoid") then
            c:FindFirstChildOfClass("Humanoid").WalkSpeed = 16
            c:FindFirstChildOfClass("Humanoid").JumpPower = 50
        end
    end,
})

if isLobby then
    local LobbySection = Tabs.Lobby:AddSection("Play", true)
    local TeleportEvent = ReplicatedStorage.RemoteEvents.TeleportEvent
    local SelectedAdd = 1; local SelectedChosen = 1

    LobbySection:AddDropdown({
        Title = "Select Add",
        Options = {"1","2","3"}, Default = {"1"}, Multi = false,
        Callback = function(v) SelectedAdd = tonumber(type(v)=="table" and v[1] or v) end,
    })
    LobbySection:AddDropdown({
        Title = "Select Chosen",
        Options = {"1","2","3","4","5"}, Default = {"1"}, Multi = false,
        Callback = function(v) SelectedChosen = tonumber(type(v)=="table" and v[1] or v) end,
    })
    LobbySection:AddButton({ Title = "Set Chosen",
        Callback = function() TeleportEvent:FireServer("Chosen", nil, SelectedChosen, nil) end })
    LobbySection:AddButton({ Title = "Remove",
        Callback = function() TeleportEvent:FireServer("Remove") end })
    LobbySection:AddButton({ Title = "Play",
        Callback = function() TeleportEvent:FireServer("Add", SelectedAdd) end })

    local DailySection = Tabs.Lobby:AddSection("Daily Quest", true)
    DailySection:AddButton({
        Title = "Spin Daily Quest",
        Callback = function()
            local e = ReplicatedStorage.RemoteEvents:FindFirstChild("SpinQuest")
            if e then e:FireServer() end
        end,
    })
end

if isForest then

local MainKill = Tabs.Main:AddSection("Kill Aura", true)
MainKill:AddSlider({
    Title = "Kill Aura Radius",
    Min = 10, Max = 200, Default = 50, Increment = 1,
    Callback = function(v) killAuraRadius = v end,
})
MainKill:AddToggle({
    Title = "Kill Aura",
    Default = false,
    Callback = function(v)
        killAuraEnabled = v
        if v then task.spawn(killAuraLoop) end
    end,
})

local MainChop = Tabs.Main:AddSection("Chop Aura", true)
MainChop:AddSlider({
    Title = "Chop Aura Radius",
    Min = 10, Max = 200, Default = 50, Increment = 1,
    Callback = function(v) chopAuraRadius = v end,
})
MainChop:AddToggle({
    Title = "Chop Aura",
    Default = false,
    Callback = function(v)
        chopAuraEnabled = v
        if v then task.spawn(chopAuraLoop) end
    end,
})

local MainTree = Tabs.Main:AddSection("Auto Chop Tree", true)
local toolsDamageIDsNat = { ["Old Axe"]="_1", ["Good Axe"]="_1", ["Strong Axe"]="_1" }
local function getToolAndDamageIDNat()
    for n, s in pairs(toolsDamageIDsNat) do
        local t = LocalPlayer:FindFirstChild("Inventory") and LocalPlayer.Inventory:FindFirstChild(n)
        if t then return t, s end
    end
end
local function findBasePart(model)
    for _, v in ipairs(model:GetDescendants()) do if v:IsA("BasePart") then return v end end
end
local hitCounter = 1
MainTree:AddDropdown({
    Title = "Tree Type",
    Options = {"Small Tree","Big Tree"},
    Default = {_G.Settings.Main["Selected Tree Type"] or "Small Tree"},
    Multi = false,
    Callback = function(v)
        _G.Settings.Main["Selected Tree Type"] = type(v)=="table" and v[1] or v
        if _G.Settings.AutoSave then SaveConfig() end
    end,
})
MainTree:AddToggle({
    Title = "Auto Chop Tree",
    Content = "Equip Axe to enable",
    Default = false,
    Callback = function(v)
        _G.Settings.Main["Auto Chop Tree"] = v
        if _G.Settings.AutoSave then SaveConfig() end
    end,
})
spawn(LPH_NO_VIRTUALIZE(function()
    while task.wait(0.2) do
        if _G.Settings.Main["Auto Chop Tree"] then
            local tool, suffix = getToolAndDamageIDNat()
            if tool and suffix then
                local allTrees = getAllTrees()
                for _, tree in ipairs(allTrees) do
                    if not _G.Settings.Main["Auto Chop Tree"] then break end
                    local part = findBasePart(tree)
                    if part then
                        coroutine.wrap(function()
                            local hits = _G.Settings.Main["Selected Tree Type"]=="Small Tree" and 13 or 20
                            for i=1,hits do
                                if not _G.Settings.Main["Auto Chop Tree"] then break end
                                local dmgID = tostring(hitCounter)..suffix
                                RemoteEvents.ToolDamageObject:InvokeServer(tree, tool, dmgID, CFrame.new(part.Position))
                                hitCounter += 1; task.wait(0.25)
                            end
                        end)()
                    end
                end
            end
        else task.wait(1) end
    end
end))

local MainBring = Tabs.Main:AddSection("Auto Bring Items", true)
MainBring:AddDropdown({
    Title = "Select Junk Items",
    Options = junkItems, Default = {}, Multi = true,
    Callback = function(v) selectedJunk = type(v)=="table" and v or {v} end,
})
MainBring:AddToggle({
    Title = "Auto Bring Junk",
    Default = false,
    Callback = function(v)
        junkControl.enabled = v
        if v and not junkControl.running then task.spawn(function() runAutoBring(selectedJunk, junkControl, function() return junkControl.enabled end) end) end
    end,
})
MainBring:AddDropdown({
    Title = "Select Fuel Items",
    Options = fuelItems, Default = {}, Multi = true,
    Callback = function(v) selectedFuel = type(v)=="table" and v or {v} end,
})
MainBring:AddToggle({
    Title = "Auto Bring Fuel",
    Default = false,
    Callback = function(v)
        fuelControl.enabled = v
        if v and not fuelControl.running then task.spawn(function() runAutoBring(selectedFuel, fuelControl, function() return fuelControl.enabled end) end) end
    end,
})
MainBring:AddDropdown({
    Title = "Select Food Items",
    Options = foodItems, Default = {}, Multi = true,
    Callback = function(v) selectedFoodB = type(v)=="table" and v or {v} end,
})
MainBring:AddToggle({
    Title = "Auto Bring Food",
    Default = false,
    Callback = function(v)
        foodControl.enabled = v
        if v and not foodControl.running then task.spawn(function() runAutoBring(selectedFoodB, foodControl, function() return foodControl.enabled end) end) end
    end,
})

local MainExtra = Tabs.Main:AddSection("Extra", true)
MainExtra:AddToggle({
    Title = "Open Map",
    Default = _G.Settings.Main["Open Map"],
    Callback = function(value)
        _G.Settings.Main["Open Map"] = value
        local root = character:FindFirstChild("HumanoidRootPart")
        if value then
            _G.OriginalPosition = root.CFrame
            _G.OriginalCameraType = workspace.CurrentCamera.CameraType
            _G.OriginalCameraSubject = workspace.CurrentCamera.CameraSubject
            _G.VisitedPositions = {}
            workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
            workspace.CurrentCamera.CameraSubject = nil
            _G.MapTeleportConnection = RunService.Heartbeat:Connect(function()
                if _G.Settings.Main["Open Map"] and root then
                    root.CFrame = CFrame.new(math.random(-1000,1000), math.random(25,100), math.random(-1000,1000))
                    task.wait(1)
                end
            end)
        else
            if _G.MapTeleportConnection then _G.MapTeleportConnection:Disconnect(); _G.MapTeleportConnection=nil end
            if root and _G.OriginalPosition then root.CFrame = _G.OriginalPosition end
            workspace.CurrentCamera.CameraType = _G.OriginalCameraType or Enum.CameraType.Custom
            workspace.CurrentCamera.CameraSubject = _G.OriginalCameraSubject or character:FindFirstChild("Humanoid")
        end
    end,
})
MainExtra:AddToggle({
    Title = "God Mode",
    Default = _G.Settings.Main["God Mode"],
    Callback = function(value)
        _G.Settings.Main["God Mode"] = value
        local dmgEvent = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("DamagePlayer")
        if value then
            if dmgEvent then
                _G.GodModeConnection = RunService.Heartbeat:Connect(function()
                    if _G.Settings.Main["God Mode"] then dmgEvent:FireServer(-math.huge) end
                end)
            end
        else
            if _G.GodModeConnection then _G.GodModeConnection:Disconnect(); _G.GodModeConnection=nil end
        end
    end,
})

end -- if isForest

if isForest then
local AutoMed = Tabs.Auto:AddSection("Medical & Equipment", true)
AutoMed:AddDropdown({
    Title = "Select Medical Items",
    Options = medItems, Default = {}, Multi = true,
    Callback = function(v) selectedMedical = type(v)=="table" and v or {v} end,
})
AutoMed:AddToggle({
    Title = "Auto Bring Medical",
    Default = false,
    Callback = function(v)
        medControl.enabled = v
        if v and not medControl.running then task.spawn(function() runAutoBring(selectedMedical, medControl, function() return medControl.enabled end) end) end
    end,
})
AutoMed:AddDropdown({
    Title = "Select Equipment Items",
    Options = equipItems, Default = {}, Multi = true,
    Callback = function(v) selectedEquip = type(v)=="table" and v or {v} end,
})
AutoMed:AddToggle({
    Title = "Auto Bring Equipment",
    Default = false,
    Callback = function(v)
        equipControl.enabled = v
        if v and not equipControl.running then task.spawn(function() runAutoBring(selectedEquip, equipControl, function() return equipControl.enabled end) end) end
    end,
})

local AutoFeed = Tabs.Auto:AddSection("Auto Feed", true)
AutoFeed:AddDropdown({
    Title = "Select Food",
    Options = alimentos, Default = {}, Multi = true,
    Callback = function(v) selectedFood = type(v)=="table" and v or {v} end,
})
AutoFeed:AddSlider({
    Title = "Hunger Threshold",
    Min = 0, Max = 100, Default = 75, Increment = 1,
    Callback = function(v) hungerThreshold = v end,
})
AutoFeed:AddToggle({
    Title = "Auto Feed",
    Default = false,
    Callback = function(v) autoFeedToggle = v; if v then task.spawn(autoFeedLoop) end end,
})

local AutoCook = Tabs.Auto:AddSection("Auto Cook & Upgrade", true)
AutoCook:AddDropdown({
    Title = "Auto Cook Items",
    Options = autocookItems, Default = {}, Multi = true,
    Callback = function(v)
        local arr = type(v)=="table" and v or {v}
        for _, n in ipairs(autocookItems) do autoCookEnabledItems[n] = table.find(arr,n)~=nil end
    end,
})
AutoCook:AddToggle({
    Title = "Auto Cook Food",
    Default = false,
    Callback = function(v) autoCookEnabled = v end,
})
coroutine.wrap(function()
    while true do
        if autoCookEnabled then
            for name, en in pairs(autoCookEnabledItems) do
                if en then
                    for _, item in ipairs(Workspace:WaitForChild("Items"):GetChildren()) do
                        if item.Name == name then moveItemToPos(item, campfireDropPos) end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)()
AutoCook:AddDropdown({
    Title = "Campfire Fuel Item",
    Options = campfireFuelItems, Default = {campfireFuelItems[1]}, Multi = false,
    Callback = function(v) selectedCampfireItem = type(v)=="table" and v[1] or v end,
})
AutoCook:AddToggle({
    Title = "Auto Upgrade Campfire",
    Default = false,
    Callback = function(v)
        autoUpgradeCampfireEnabled = v
        if v then
            task.spawn(function()
                while autoUpgradeCampfireEnabled do
                    if selectedCampfireItem then
                        for _, item in ipairs(workspace:WaitForChild("Items"):GetChildren()) do
                            if item.Name == selectedCampfireItem then moveItemToPos(item, campfireDropPos) end
                        end
                    end
                    task.wait(2)
                end
            end)
        end
    end,
})

local AutoFarm = Tabs.Auto:AddSection("Auto Farm (NatHub)", true)
AutoFarm:AddToggle({
    Title = "Auto Recycling",
    Default = false,
    Callback = function(v)
        _G.Settings.Main["Auto Recycling"] = v
        if _G.Settings.AutoSave then SaveConfig() end
    end,
})
spawn(LPH_NO_VIRTUALIZE(function()
    pcall(function()
        local allowedNames = {["Log"]=true,["Sheet Metal"]=true,["Bolt"]=true,["UFO Junk"]=true,
            ["UFO Component"]=true,["Broken Fan"]=true,["Broken Radio"]=true,["Broken Microwave"]=true,
            ["Tyre"]=true,["Metal Chair"]=true,["Old Car Engine"]=true,["Washing Machine"]=true}
        local targetPos = Vector3.new(20.95, 8, -5.24)
        local remote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestScrapItem")
        local bench  = workspace.Map.Campground:WaitForChild("CraftingBench")
        while true do
            task.wait(0.2)
            if _G.Settings.Main["Auto Recycling"] then
                local folder = workspace:FindFirstChild("Items")
                if folder then
                    for _, item in ipairs(folder:GetChildren()) do
                        if not _G.Settings.Main["Auto Recycling"] then break end
                        if item:IsA("Model") and allowedNames[item.Name] then
                            local base = item:FindFirstChildWhichIsA("BasePart")
                            if base then
                                if not item.PrimaryPart then item.PrimaryPart = base end
                                item:SetPrimaryPartCFrame(CFrame.new(targetPos)); task.wait(0.3)
                                pcall(function() remote:InvokeServer(bench, item) end); task.wait(0.5)
                            end
                        end
                    end
                end
            else task.wait(1) end
        end
    end)
end))
AutoFarm:AddToggle({
    Title = "Auto Plant Sapling",
    Default = false,
    Callback = function(v) _G.Settings.Main["Auto Plant Sapling"] = v end,
})
spawn(LPH_NO_VIRTUALIZE(function()
    pcall(function()
        local re = ReplicatedStorage:WaitForChild("RemoteEvents")
        local items = workspace:WaitForChild("Items")
        while true do
            task.wait(0.5)
            if _G.Settings.Main["Auto Plant Sapling"] then
                for _, item in ipairs(items:GetChildren()) do
                    if not _G.Settings.Main["Auto Plant Sapling"] then break end
                    if item:IsA("Model") and item.Name=="Sapling" then
                        local base = item:FindFirstChildWhichIsA("BasePart")
                        if base then
                            if not item.PrimaryPart then item.PrimaryPart = base end
                            local pos = item:GetPivot().Position
                            re.RequestStartDraggingItem:FireServer(item); task.wait(0.1)
                            pcall(function() re.RequestPlantItem:InvokeServer(item, Vector3.new(pos.X,pos.Y-1,pos.Z)) end)
                            re.StopDraggingItem:FireServer(item); task.wait(0.2)
                        end
                    end
                end
            else task.wait(1) end
        end
    end)
end))
AutoFarm:AddToggle({
    Title = "Auto Collect Flower",
    Default = false,
    Callback = function(v) _G.AutoCollectFlower = v end,
})
local pickFlowerRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestPickFlower")
local origFlowerCF
local function collectFlower(flower)
    pcall(function()
        if not flower:IsA("Model") or not flower.PrimaryPart then return end
        if not origFlowerCF then origFlowerCF = HRP.CFrame end
        HRP.CFrame = flower.PrimaryPart.CFrame + Vector3.new(0,3,0); task.wait(0.1)
        pickFlowerRemote:InvokeServer(flower); task.wait(0.1)
    end)
end
spawn(LPH_NO_VIRTUALIZE(function()
    while true do
        task.wait(0.2)
        if _G.AutoCollectFlower then
            local found = false
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj.Name:lower():find("flower") and obj:IsA("Model") then found=true; collectFlower(obj) end
            end
            if not found and origFlowerCF then HRP.CFrame = origFlowerCF; origFlowerCF = nil end
        elseif origFlowerCF then HRP.CFrame = origFlowerCF; origFlowerCF = nil end
    end
end))

AutoFarm:AddToggle({
    Title = "Auto Cook Food (NatHub)",
    Default = false,
    Callback = function(v) _G.Settings.Main["Auto Cook"] = v end,
})
spawn(LPH_NO_VIRTUALIZE(function()
    pcall(function()
        local foods = {"Steak","Morsel"}
        local folder = workspace:WaitForChild("Items")
        while true do
            task.wait(0.5)
            if _G.Settings.Main["Auto Cook"] then
                local avail = {}
                for _, item in ipairs(folder:GetChildren()) do
                    if item:IsA("Model") and table.find(foods, item.Name) then table.insert(avail, item) end
                end
                if #avail > 0 then
                    local food = avail[math.random(1,#avail)]
                    food:SetPrimaryPartCFrame(CFrame.new(0,8,0))
                end
            else task.wait(1) end
        end
    end)
end))
AutoFarm:AddToggle({
    Title = "Auto Eat",
    Default = false,
    Callback = function(v) _G.Settings.Main["Auto Eat"] = v end,
})
spawn(LPH_NO_VIRTUALIZE(function()
    pcall(function()
        local eatFoods = {"Cooked Steak","Cooked Morsel","Berry","Carrot","Apple"}
        local folder = workspace:WaitForChild("Items")
        local consume = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestConsumeItem")
        local drag = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestStartDraggingItem")
        while true do
            task.wait(0.5)
            if _G.Settings.Main["Auto Eat"] then
                local avail = {}
                for _, item in ipairs(folder:GetChildren()) do
                    if item:IsA("Model") and table.find(eatFoods, item.Name) then table.insert(avail, item) end
                end
                if #avail > 0 then
                    local food = avail[math.random(1,#avail)]
                    pcall(function() drag:FireServer(food); task.wait(0.25); consume:InvokeServer(food) end)
                end
            else task.wait(1) end
        end
    end)
end))
AutoFarm:AddToggle({
    Title = "Auto Open Chest",
    Default = false,
    Callback = function(v) _G.Settings.Main["Auto Open Chest"] = v end,
})
spawn(LPH_NO_VIRTUALIZE(function()
    pcall(function()
        while true do
            task.wait(0.5)
            if _G.Settings.Main["Auto Open Chest"] then
                local folder = workspace:FindFirstChild("Items")
                if folder then
                    for _, chest in ipairs(folder:GetChildren()) do
                        if not _G.Settings.Main["Auto Open Chest"] then break end
                        if chest:IsA("Model") and chest.Name:find("Chest") then
                            local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                            if prompt then fireproximityprompt(prompt, 0); task.wait(0.1) end
                        end
                    end
                end
            else task.wait(1) end
        end
    end)
end))

local AutoFish = Tabs.Auto:AddSection("Fishing", true)
AutoFish:AddParagraph({ Title = "Note", Content = "Jika Rod Cast gagal, lakukan cast manual terlebih dahulu." })
AutoFish:AddButton({
    Title = "Teleport to Fishing Area",
    Callback = function()
        local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = c:WaitForChild("HumanoidRootPart")
        local target = workspace:WaitForChild("Map"):WaitForChild("Landmarks"):WaitForChild("Fishing Hut")
                       :WaitForChild("Building"):WaitForChild("Door"):WaitForChild("Main")
        if root and target then root.CFrame = target.CFrame + Vector3.new(0,5,0) end
    end,
})
AutoFish:AddToggle({
    Title = "Auto Fishing",
    Default = false,
    Callback = function(v) _G.AutoFishing = v end,
})
local VIM = game:GetService("VirtualInputManager")
local waterFolder = workspace:WaitForChild("Map"):WaitForChild("Water")
local camW = workspace.CurrentCamera
local function getNearestWater()
    local n, nd = nil, math.huge
    for _, p in ipairs(waterFolder:GetChildren()) do
        if p:IsA("BasePart") then
            local d = (HRP.Position - p.Position).Magnitude
            if d < nd then nd=d; n=p end
        end
    end
    return n
end
local function clickPart(part)
    local sp, on = camW:WorldToViewportPoint(part.Position)
    if not on then return end
    VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, true, game, 0)
    VIM:SendMouseButtonEvent(sp.X, sp.Y, 0, false, game, 0)
end
local function getClient()
    local cs = LocalPlayer.PlayerScripts:FindFirstChild("Client")
    if not cs then return nil end
    local ok, r = pcall(require, cs); return ok and r or nil
end
local FishClient = getClient()
spawn(LPH_NO_VIRTUALIZE(function()
    while task.wait(0.5) do
        if _G.AutoFishing then
            pcall(function()
                local w = getNearestWater()
                if w then clickPart(w) end
                local frame
                repeat
                    frame = FishClient and FishClient.Interface and FishClient.Interface.FishingCatchFrame
                    task.wait(0.1)
                until not _G.AutoFishing or (frame and frame.Visible)
                while _G.AutoFishing and frame and frame.Visible do
                    local sa = frame.TimingBar.SuccessArea; local bar = frame.TimingBar.Bar
                    if sa and bar then
                        local sy, sh, by = sa.AbsolutePosition.Y, sa.AbsoluteSize.Y, bar.AbsolutePosition.Y
                        if by >= sy and by <= sy+sh then
                            VIM:SendMouseButtonEvent(0,0,0,true,game,0); VIM:SendMouseButtonEvent(0,0,0,false,game,0); task.wait(0.05)
                        end
                    end
                    task.wait(0.05)
                end
                task.wait(0.5)
            end)
        end
    end
end))

local AutoTame = Tabs.Auto:AddSection("Taming Animal", true)
local TamingEnabled = false; local SelectedAnimal = ""
local function GetAnimalList()
    local animals, found = {}, {}
    for _, a in pairs(Workspace:WaitForChild("Characters"):GetChildren()) do
        if a:IsA("Model") and not found[a.Name] and not a:FindFirstChild("NameLabel") then
            table.insert(animals, a.Name); found[a.Name] = true
        end
    end
    return animals
end
local function GetClosestAnimal(name)
    local closest, minD = nil, math.huge
    local ppos = LocalPlayer.Character and LocalPlayer.Character:GetPivot().Position
    if not ppos then return nil end
    for _, a in pairs(Workspace.Characters:GetChildren()) do
        if a.Name == name and a:IsA("Model") and not a:FindFirstChild("NameLabel") then
            local d = (a:GetPivot().Position - ppos).Magnitude
            if d < minD then minD=d; closest=a end
        end
    end
    return closest
end
local function GetRequiredFood(petName)
    local pet = GetClosestAnimal(petName)
    if pet then
        local f1 = pet:FindFirstChild("Head") and pet.Head:FindFirstChild("TamingHunger") and pet.Head.TamingHunger:FindFirstChild("Food1")
        if f1 and f1:FindFirstChild("TextLabel") then return f1.TextLabel.Text end
    end
end
local function AutoTameLoop()
    while TamingEnabled do
        wait(1)
        if SelectedAnimal=="" then break end
        local pet = GetClosestAnimal(SelectedAnimal)
        if not pet then break end
        local flute = LocalPlayer.Inventory:FindFirstChild("Old Taming Flute")
        if pet and flute then
            local food = GetRequiredFood(SelectedAnimal)
            if food and food ~= "" then
                local fi = Workspace.Items:FindFirstChild(food)
                if fi then
                    RemoteEvents.RequestStartDraggingItem:FireServer(fi)
                    fi:PivotTo(pet:GetPivot()); wait(2)
                end
            else
                RemoteEvents.RequestTame_Neutral:FireServer(pet, flute); wait(0.5)
                RemoteEvents.RequestTame_Hungry:FireServer(pet, flute)
            end
        end
    end
end
local AnimalDropdown = AutoTame:AddDropdown({
    Title = "Choose Animal",
    Options = GetAnimalList(), Default = {}, Multi = false,
    Callback = function(v) SelectedAnimal = type(v)=="table" and v[1] or v end,
})
AutoTame:AddButton({
    Title = "Refresh Animal List",
    Callback = function() AnimalDropdown:SetOptions(GetAnimalList()) end,
})
AutoTame:AddToggle({
    Title = "Auto Taming",
    Default = false,
    Callback = function(v) TamingEnabled = v; if v then task.spawn(AutoTameLoop) end end,
})

end -- if isForest

if isForest then
local ItemTarget = Tabs.Items:AddSection("Select Target", true)
ItemTarget:AddDropdown({
    Title = "Target",
    Options = {"Player","Campfire"}, Default = {}, Multi = true,
    Callback = function(v) selectedTargets = type(v)=="table" and v or {v} end,
})

local ItemGear = Tabs.Items:AddSection("Gears", true)
ItemGear:AddDropdown({
    Title = "Choose Gear Item",
    Options = {"Bolt","Tyre","Sheet Metal","Old Radio","Broken Fan","Broken Microwave","Washing Machine","Old Car Engine","UFO Scrap","UFO Component","UFO Junk","Cultist Gem","Gem of the Forest"},
    Default = {}, Multi = true,
    Callback = function(v) selectedGear = type(v)=="table" and v or {v} end,
})
ItemGear:AddButton({
    Title = "Collect Gear",
    Callback = function()
        collectItems(selectedGear, includes(selectedTargets,"Campfire") and "Campfire" or "Player")
    end,
})

local ItemFood = Tabs.Items:AddSection("Food / Healing", true)
ItemFood:AddDropdown({
    Title = "Choose Food / Healing",
    Options = {"Carrot","Berry","Morsel","Steak","Ribs","Cooked Morsel","Cooked Steak","Cooked Ribs","Bandage","Medkit","Chili"},
    Default = {}, Multi = true,
    Callback = function(v) selectedFoodCol = type(v)=="table" and v or {v} end,
})
ItemFood:AddButton({
    Title = "Collect Food",
    Callback = function()
        collectItems(selectedFoodCol, includes(selectedTargets,"Campfire") and "Campfire" or "Player")
    end,
})

local ItemGuns = Tabs.Items:AddSection("Guns & Armor", true)
ItemGuns:AddDropdown({
    Title = "Choose Guns / Armor",
    Options = {"Morning star","Laser Sword","Raygun","Chainsaw","Strong Axe","Spear","Good Axe","Revolver","Rifle","Tactical Shotgun","Revolver Ammo","Rifle Ammo","Alien Armour","Leather Body","Iron Body","Thorn Body","Riot Shield"},
    Default = {}, Multi = true,
    Callback = function(v) selectedGearCol = type(v)=="table" and v or {v} end,
})
ItemGuns:AddButton({
    Title = "Collect Guns / Armor",
    Callback = function()
        collectItems(selectedGearCol, includes(selectedTargets,"Campfire") and "Campfire" or "Player")
    end,
})

local ItemChest = Tabs.Items:AddSection("Chest Items", true)
local allChestItems = {"Bandage","Good Sack","Good Axe","Old Flashlight","Spear","Revolver","Revolver Ammo","Fuel Canister","Flower Seeds","Alien Armor","Laser Sword","Laser Cannon","Ice Axe","Snowball","Ice Sword","Frozen Shuriken","Leather Body","Berry Seeds","Rifle","Ammo","Strong Flashlight","Iron Body","Chili Seeds","Oil Barrel","Strong Axe","Giant Sack","Medkit","Cultist Gem","Chainsaw","Kunai","Riot Shield","Thorn Armor","Tactical Shotgun","Gem of the Forest Fragment"}
ItemChest:AddDropdown({
    Title = "Select Chest Items",
    Options = allChestItems, Default = {}, Multi = true,
    Callback = function(v) selectedChestCol = type(v)=="table" and v or {v} end,
})
ItemChest:AddButton({
    Title = "Collect Chest Items",
    Callback = function()
        collectItems(selectedChestCol, includes(selectedTargets,"Campfire") and "Campfire" or "Player")
    end,
})

local ItemOther = Tabs.Items:AddSection("Other Items", true)
ItemOther:AddDropdown({
    Title = "Choose Other Items",
    Options = {"Sack","Seed Box","Chainsaw","Old Flashlight","Strong Flashlight","Bunny Foot","Wolf Pelt","Bear Pelt","Alpha Wolf Pet","Artic Fox Pelt","Polar Bear Pelt","Mammoth Tusk"},
    Default = {}, Multi = true,
    Callback = function(v) selectedOtherCol = type(v)=="table" and v or {v} end,
})
ItemOther:AddButton({
    Title = "Collect Other Items",
    Callback = function()
        collectItems(selectedOtherCol, includes(selectedTargets,"Campfire") and "Campfire" or "Player")
    end,
})
ItemOther:AddButton({
    Title = "Show Flower Shop",
    Callback = function()
        local gui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Interface"):FindFirstChild("Flower")
        if gui then gui.Visible = true end
    end,
})
ItemOther:AddButton({
    Title = "Teleport Seed Box",
    Callback = function()
        local box = workspace:FindFirstChild("Items") and workspace.Items:FindFirstChild("Seed Box")
        if box then
            if not box.PrimaryPart then box.PrimaryPart = box:FindFirstChildWhichIsA("BasePart") end
            if box.PrimaryPart then box:SetPrimaryPartCFrame(CFrame.new(0,8,0)) end
        end
    end,
})
end -- if isForest

if isForest then
local craftRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CraftItem")

local function addCraftButtons(sectionName, items)
    local sec = Tabs.Craft:AddSection(sectionName, true)
    for _, name in ipairs(items) do
        sec:AddButton({
            Title = "Craft: "..name,
            Content = "⚠️ Pastikan kamu punya material!",
            Callback = function() pcall(function() craftRemote:InvokeServer(name) end) end,
        })
    end
end

addCraftButtons("Bench 1", {"Map","Old Bed","Bunny Trap","Crafting Bench 2"})
addCraftButtons("Bench 2", {"Sun Dial","Regular Bed","Compass","Freezer","Farm Plot","Wood Rain Storage","Shelf","Log Wall","Bear Trap","Crafting Bench 3"})
addCraftButtons("Bench 3", {"Crock Pot","Radar","Boost Pad","Biofuel Processor","Torch","Good Bed","Lightning Rod","Crafting Bench 4"})
addCraftButtons("Bench 4", {"Ammo Crate","Oil Drill","Giant Bed","Teleporter","Crafting Bench 5"})
addCraftButtons("Bench 5", {"Respawn Capsule","Temporal Accelerometer","Weather Machine"})
end

if isForest then
local sackNames = {["Old Sack"]=true, ["Good Sack"]=true, ["Giant Sack"]=true}

local Q1 = Tabs.Quest:AddSection("Lost Child 1", true)
Q1:AddParagraph({ Title = "Note", Content = "Perlu Campfire Level 2. Equip weapon dulu." })
Q1:AddToggle({
    Title = "Auto Lost Child 1",
    Default = false,
    Callback = function(v)
        _G.Settings.Quest["Auto Lost Child Quest"] = v
        if _G.Settings.AutoSave then SaveConfig() end
    end,
})
task.spawn(LPH_NO_VIRTUALIZE(function()
    pcall(function()
        local re = ReplicatedStorage:WaitForChild("RemoteEvents")
        while true do
            task.wait(1)
            if _G.Settings.Quest["Auto Lost Child Quest"] then
                local hover = fly()
                local visited = {}
                local jailCellar = nil
                local foliage = Workspace:WaitForChild("Map"):WaitForChild("Foliage")
                while not jailCellar and _G.Settings.Quest["Auto Lost Child Quest"] do
                    for _, tree in pairs(foliage:GetChildren()) do
                        if not _G.Settings.Quest["Auto Lost Child Quest"] then unfly(hover); break end
                        if tree:IsA("Model") and (tree.Name=="TreeBig1" or tree.Name=="TreeBig2") and not visited[tree] then
                            visited[tree] = true
                            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            local base = tree:FindFirstChildWhichIsA("BasePart")
                            if root and base then root.CFrame = base.CFrame + Vector3.new(0,3,0) end
                            task.wait(1)
                            jailCellar = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Landmarks") and Workspace.Map.Landmarks:FindFirstChild("Jail Cellar1")
                            if jailCellar then break end
                        end
                    end
                    task.wait(1)
                end
                if jailCellar then
                    local jc = Workspace.Map.Landmarks:WaitForChild("Jail Cellar1")
                    local ki = jc.LockedDoor:WaitForChild("KeyInteraction")
                    local root = character:WaitForChild("HumanoidRootPart")
                    root.CFrame = ki.CFrame + Vector3.new(0,25,0); task.wait(5)
                    local redKey
                    repeat redKey = Workspace.Items:FindFirstChild("Red Key"); task.wait(0.5) until redKey
                    re.RequestStartDraggingItem:FireServer(redKey)
                    redKey.PrimaryPart.CFrame = ki.CFrame
                    re.ToggleDoor:FireServer("FireAllClients", jc.LockedDoor, true); task.wait(0.3)
                    re.ToggleDoor:FireServer("FireAllClients", jc.Door, true); task.wait(0.3)
                    local lostChild
                    repeat lostChild = jc:FindFirstChild("LostChild"); task.wait(0.5) until lostChild
                    local sack = nil
                    for name in pairs(sackNames) do
                        sack = Workspace.Items:FindFirstChild(name); if sack then break end
                    end
                    if sack and lostChild then
                        re.RequestStartDraggingItem:FireServer(sack)
                        sack.PrimaryPart.CFrame = lostChild.PrimaryPart.CFrame
                        re.RequestBagDropItem:FireServer(sack, lostChild)
                    end
                    unfly(hover)
                end
                repeat task.wait(0.2) until not _G.Settings.Quest["Auto Lost Child Quest"]
                unfly(hover)
            end
        end
    end)
end))

local Q2 = Tabs.Quest:AddSection("Lost Child 2", true)
Q2:AddToggle({
    Title = "Auto Lost Child 2",
    Default = false,
    Callback = function(v)
        _G.Settings.Quest["Auto Lost Child2 Quest"] = v
        if _G.Settings.AutoSave then SaveConfig() end
    end,
})
local Q3 = Tabs.Quest:AddSection("Lost Child 3", true)
Q3:AddToggle({
    Title = "Auto Lost Child 3",
    Default = false,
    Callback = function(v)
        _G.Settings.Quest["Auto Lost Child3 Quest"] = v
        if _G.Settings.AutoSave then SaveConfig() end
    end,
})
local Q4 = Tabs.Quest:AddSection("Lost Child 4", true)
Q4:AddToggle({
    Title = "Auto Lost Child 4",
    Default = false,
    Callback = function(v)
        _G.Settings.Quest["Auto Lost Child4 Quest"] = v
        if _G.Settings.AutoSave then SaveConfig() end
    end,
})
end -- if isForest

if isForest then
local VisItems = Tabs.Visual:AddSection("Item ESP", true)
VisItems:AddDropdown({
    Title = "Select Items",
    Options = ie, Default = {}, Multi = true,
    Callback = function(v)
        selectedItems_esp = type(v)=="table" and v or {v}
        if espItemsEnabled then
            for _, name in ipairs(ie) do
                if table.find(selectedItems_esp, name) then Aesp(name,"item") else Desp(name) end
            end
        end
    end,
})
VisItems:AddToggle({
    Title = "Enable Item ESP",
    Default = false,
    Callback = function(v)
        espItemsEnabled = v
        for _, name in ipairs(ie) do
            if v and table.find(selectedItems_esp, name) then Aesp(name,"item") else Desp(name) end
        end
        if v then
            if not espConnections["Items"] then
                local c = workspace:FindFirstChild("Items")
                if c then espConnections["Items"] = c.ChildAdded:Connect(function(obj)
                    if table.find(selectedItems_esp, obj.Name) then
                        local p = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                        if p then createESP(p, obj.Name, Color3.fromRGB(0,255,0)) end
                    end
                end) end
            end
        else
            if espConnections["Items"] then espConnections["Items"]:Disconnect(); espConnections["Items"]=nil end
        end
    end,
})

local VisMobs = Tabs.Visual:AddSection("Mob ESP", true)
VisMobs:AddDropdown({
    Title = "Select Mobs",
    Options = me, Default = {}, Multi = true,
    Callback = function(v)
        selectedMobs_esp = type(v)=="table" and v or {v}
        if espMobsEnabled then
            for _, name in ipairs(me) do
                if table.find(selectedMobs_esp, name) then Aesp(name,"mob") else Desp(name) end
            end
        end
    end,
})
VisMobs:AddToggle({
    Title = "Enable Mob ESP",
    Default = false,
    Callback = function(v)
        espMobsEnabled = v
        for _, name in ipairs(me) do
            if v and table.find(selectedMobs_esp, name) then Aesp(name,"mob") else Desp(name) end
        end
        if v then
            if not espConnections["Mobs"] then
                local c = workspace:FindFirstChild("Characters")
                if c then espConnections["Mobs"] = c.ChildAdded:Connect(function(obj)
                    if table.find(selectedMobs_esp, obj.Name) then
                        local p = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                        if p then createESP(p, obj.Name, Color3.fromRGB(255,255,0)) end
                    end
                end) end
            end
        else
            if espConnections["Mobs"] then espConnections["Mobs"]:Disconnect(); espConnections["Mobs"]=nil end
        end
    end,
})

local VisEnemy = Tabs.Visual:AddSection("Enemy ESP (NatHub)", true)
local enemyList = {}; local selectedEnemies = {}; local espChars = {}
local function refreshEnemyList()
    enemyList = {}
    local chars = workspace:FindFirstChild("Characters")
    if chars then for _, c in ipairs(chars:GetChildren()) do
        if c:IsA("Model") and c:FindFirstChildWhichIsA("Humanoid") and not table.find(enemyList, c.Name) then
            table.insert(enemyList, c.Name) end
    end end
    return enemyList
end
local EnemyDropdown = VisEnemy:AddDropdown({
    Title = "Select Enemies",
    Options = refreshEnemyList(), Default = {}, Multi = true,
    Callback = function(v) selectedEnemies = type(v)=="table" and v or {v} end,
})
VisEnemy:AddButton({ Title = "Refresh Enemy List",
    Callback = function() EnemyDropdown:SetOptions(refreshEnemyList()) end })
VisEnemy:AddToggle({
    Title = "Enable Enemy ESP",
    Default = false,
    Callback = function(v) _G.Settings.Esp["Enable Enemy ESP"] = v end,
})
spawn(LPH_NO_VIRTUALIZE(function()
    while task.wait(0.2) do
        pcall(function()
            local chars = workspace:FindFirstChild("Characters")
            local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if not (_G.Settings.Esp["Enable Enemy ESP"] and #selectedEnemies > 0) then
                for char, obj in pairs(espChars) do
                    obj.highlight:Destroy(); obj.label.Parent:Destroy(); espChars[char]=nil
                end
                return
            end
            for _, char in ipairs(chars and chars:GetChildren() or {}) do
                if char:IsA("Model") and char:FindFirstChildWhichIsA("Humanoid") then
                    local should = table.find(selectedEnemies, char.Name)
                    if should then
                        local dist = root and (root.Position - char:GetPrimaryPartCFrame().Position).Magnitude
                        if not espChars[char] then
                            local hl = Instance.new("Highlight")
                            hl.FillColor = getColorForName(char.Name); hl.OutlineColor=Color3.new(1,1,1)
                            hl.FillTransparency=0.5; hl.OutlineTransparency=0; hl.Adornee=char; hl.Parent=char
                            local bb = Instance.new("BillboardGui"); bb.Size=UDim2.new(0,200,0,50)
                            bb.AlwaysOnTop=true; bb.Adornee=char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
                            local lbl = Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0)
                            lbl.BackgroundTransparency=1; lbl.TextScaled=true; lbl.Font=Enum.Font.SourceSansBold
                            lbl.TextColor3=hl.FillColor; lbl.TextStrokeTransparency=0.5; lbl.Parent=bb; bb.Parent=char
                            espChars[char] = {highlight=hl, label=lbl, billboard=bb}
                        end
                        if espChars[char] then
                            espChars[char].label.Text = char.Name.." | "..(dist and string.format("%.1f",dist) or "?").."m"
                        end
                    else
                        if espChars[char] then
                            espChars[char].highlight:Destroy(); espChars[char].billboard:Destroy(); espChars[char]=nil
                        end
                    end
                end
            end
            for char, obj in pairs(espChars) do
                if not char or not char:IsDescendantOf(game) or not table.find(selectedEnemies, char.Name) then
                    obj.highlight:Destroy(); obj.billboard:Destroy(); espChars[char]=nil
                end
            end
        end)
    end
end))
end -- if isForest

if isForest then
local TpChest = Tabs.Teleport:AddSection("Chest Teleport", true)
local ChestDropdown = TpChest:AddDropdown({
    Title = "Select Chest",
    Options = currentChestNames, Default = {currentChestNames[1] or ""}, Multi = false,
    Callback = function(v) selectedChest = type(v)=="table" and v[1] or v end,
})
TpChest:AddButton({
    Title = "Teleport to Chest",
    Callback = function()
        if selectedChest then
            for i, name in ipairs(currentChestNames) do
                if name == selectedChest then
                    local t = currentChests[i]
                    if t then
                        local p = t.PrimaryPart or t:FindFirstChildWhichIsA("BasePart")
                        if p and LocalPlayer.Character then
                            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if root then root.CFrame = p.CFrame + Vector3.new(0,5,0) end
                        end
                    end
                    break
                end
            end
        end
    end,
})
TpChest:AddButton({
    Title = "Refresh Chest List",
    Callback = function()
        currentChests, currentChestNames = getChests()
        ChestDropdown:SetOptions(currentChestNames)
        if #currentChestNames > 0 then selectedChest = currentChestNames[1] end
        notify(#currentChestNames > 0 and "✅" or "⚠️",
               #currentChestNames > 0 and "Ditemukan "..(#currentChestNames).." chest" or "Tidak ada chest",
               "info", 3)
    end,
})

local TpChild = Tabs.Teleport:AddSection("Children", true)
local MobDropdown = TpChild:AddDropdown({
    Title = "Select Child",
    Options = currentMobNames_tp, Default = {currentMobNames_tp[1] or ""}, Multi = false,
    Callback = function(v) selectedMob_tp = type(v)=="table" and v[1] or v end,
})
TpChild:AddButton({
    Title = "Teleport to Child",
    Callback = function()
        if selectedMob_tp then
            for i, name in ipairs(currentMobNames_tp) do
                if name == selectedMob_tp then
                    local t = currentMobs_tp[i]
                    if t then
                        local p = t.PrimaryPart or t:FindFirstChildWhichIsA("BasePart")
                        if p and LocalPlayer.Character then
                            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if root then root.CFrame = p.CFrame + Vector3.new(0,5,0) end
                        end
                    end
                    break
                end
            end
        end
    end,
})
TpChild:AddButton({
    Title = "Refresh Child List",
    Callback = function()
        currentMobs_tp, currentMobNames_tp = getMobs()
        MobDropdown:SetOptions(currentMobNames_tp)
        if #currentMobNames_tp > 0 then selectedMob_tp = currentMobNames_tp[1] end
    end,
})

local TpPlace = Tabs.Teleport:AddSection("Teleport Places", true)
TpPlace:AddButton({
    Title = "Teleport to Campground",
    Callback = function()
        local c = LocalPlayer.Character
        if c then c:PivotTo(CFrame.new(0,8,0)) end
    end,
})
TpPlace:AddButton({
    Title = "Teleport to Volcano",
    Callback = function()
        pcall(function()
            local vol = workspace.Map.Landmarks:FindFirstChild("Volcano")
            if vol then HRP.CFrame = vol:GetPivot() + Vector3.new(0,5,0) else notify("⚠️","Volcano belum spawn","alert-triangle",3) end
        end)
    end,
})
TpPlace:AddButton({
    Title = "Teleport to Fishing Area",
    Callback = function()
        local target = workspace:WaitForChild("Map"):WaitForChild("Landmarks"):WaitForChild("Fishing Hut")
                       :WaitForChild("Building"):WaitForChild("Door"):WaitForChild("Main")
        if target then HRP.CFrame = target.CFrame + Vector3.new(0,5,0) end
    end,
})

local TpItem = Tabs.Teleport:AddSection("Teleport to Item", true)
local tpItemNames = {"Revolver","Medkit","Alien Chest","Berry","Bolt","Broken Fan","Carrot","Coal","Coin Stack","Hologram Emitter","Item Chest","Log","Old Flashlight","Old Radio","Sheet Metal","Bandage","Rifle"}
local selectedTpItem = tpItemNames[1]
TpItem:AddDropdown({
    Title = "Select Item",
    Options = tpItemNames, Default = {tpItemNames[1]}, Multi = false,
    Callback = function(v) selectedTpItem = type(v)=="table" and v[1] or v end,
})
TpItem:AddButton({
    Title = "Teleport to Item",
    Callback = function()
        local folder = workspace:WaitForChild("Items")
        local candidates = {}
        for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and m.Name == selectedTpItem then
                local p = getModelPart(m); if p then table.insert(candidates, p) end
            end
        end
        if #candidates > 0 then
            local target = candidates[math.random(1,#candidates)]
            HRP.CFrame = target.CFrame + Vector3.new(0,5,0)
        end
    end,
})
end -- if isForest

local MiscSec = Tabs.Misc:AddSection("Player", true)

MiscSec:AddToggle({
    Title = "Infinite Jump",
    Default = false,
    Callback = function(v)
        _G.Settings.Misc["Infinite Jump"] = v
        infJump = v
    end,
})
UserInputService.JumpRequest:Connect(function()
    if infJump then
        local c = LocalPlayer.Character
        if c and c:FindFirstChildOfClass("Humanoid") then c:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping") end
    end
end)

MiscSec:AddToggle({
    Title = "Noclip",
    Default = false,
    Callback = function(v) noclip = v end,
})
RunService.Stepped:Connect(function()
    if noclip then
        local c = LocalPlayer.Character
        if c then for _, v in pairs(c:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end end
    end
end)

MiscSec:AddButton({
    Title = "FPS Boost",
    Callback = function()
        local function opt(v)
            if v:IsA("BasePart") then v.Material=Enum.Material.Plastic; v.Reflectance=0
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency=1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=false
            elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") then v.Enabled=false end
        end
        for _, v in pairs(game:GetDescendants()) do opt(v) end
        spawn(function() workspace.DescendantAdded:Connect(function(o) opt(o) end) end)
    end,
})

if isForest then
local MiscWorld = Tabs.Misc:AddSection("World", true)
MiscWorld:AddToggle({
    Title = "Remove Fog",
    Default = _G.Settings.Misc["Remove Fog"],
    Callback = function(v) _G.Settings.Misc["Remove Fog"] = v; setFogState(v) end,
})
MiscWorld:AddToggle({
    Title = "Anti Void",
    Default = _G.Settings.Misc["Anti Void"],
    Callback = function(v) _G.Settings.Misc["Anti Void"] = v end,
})
MiscWorld:AddToggle({
    Title = "Auto Detect Night (→ Campfire)",
    Default = _G.Settings.Misc["Night Teleport"],
    Callback = function(v) _G.Settings.Misc["Night Teleport"] = v end,
})
spawn(LPH_NO_VIRTUALIZE(function()
    while true do
        task.wait(0.3)
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("HumanoidRootPart") then
            local root = c.HumanoidRootPart
            local pos = root.Position
            local targetPos = Vector3.new(0,8,0)
            if _G.Settings.Misc["Anti Void"] and pos.Y < -5 and (pos - targetPos).Magnitude > 10 then
                root.CFrame = CFrame.new(targetPos)
            end
            if _G.Settings.Misc["Night Teleport"] then
                local t = Lighting.ClockTime
                local night = t < 6 or t >= 18
                if night and (pos - targetPos).Magnitude > 10 then root.CFrame = CFrame.new(targetPos) end
            end
        end
    end
end))
MiscWorld:AddSlider({
    Title = "Character Speed",
    Min = 16, Max = 200, Default = 16, Increment = 1,
    Callback = function(v)
        local c = LocalPlayer.Character
        if c and c:FindFirstChildOfClass("Humanoid") then c:FindFirstChildOfClass("Humanoid").WalkSpeed = v end
    end,
})
end -- isForest

local MiscConn = Tabs.Misc:AddSection("Connection", true)
MiscConn:AddToggle({
    Title = "Auto Reconnect",
    Default = false,
    Callback = function(v)
        autoReconnect = v
        if v then
            local ts = game:GetService("TeleportService")
            game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
                if autoReconnect and child.Name=="ErrorPrompt" then
                    task.wait(2); ts:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
        end
    end,
})
MiscConn:AddToggle({
    Title = "Anti AFK",
    Default = false,
    Callback = function(v)
        antiAFK = v
        if v then
            local vu = game:GetService("VirtualUser")
            afkConnection = LocalPlayer.Idled:Connect(function()
                vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame); task.wait(1)
                vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end)
        else
            if afkConnection then afkConnection:Disconnect(); afkConnection=nil end
        end
    end,
})

local SettingsSec = Tabs.Settings:AddSection("Settings", true)

SettingsSec:AddDropdown({
    Title = "Theme",
    Content = "Pilih warna tema UI",
    Default = {"Grey"},
    Options = Library:GetThemes(),
    Multi = false,
    Callback = function(v)
        local s = type(v)=="table" and v[1] or v
        if s and s~="" then Library:SetTheme(s) end
    end,
})
SettingsSec:AddButton({
    Title = "Reset Config",
    Callback = function()
        local function ResetTable(t)
            for k, v in pairs(t) do if type(v)=="table" then ResetTable(v) else t[k]=false end end
        end
        ResetTable(_G.Settings)
        SaveConfig()
        notify("Config", "Config telah direset!", "rotate-ccw", 3)
    end,
})

local SettingsServer = Tabs.Settings:AddSection("Server", true)
SettingsServer:AddButton({
    Title = "Rejoin",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})
SettingsServer:AddButton({
    Title = "Server Hop",
    Callback = function()
        local ts = game:GetService("TeleportService")
        local id = game.PlaceId
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..id.."/servers/Public?sortOrder=Asc&limit=100"))
        for _, v in pairs(servers.data) do
            if v.playing < v.maxPlayers then ts:TeleportToPlaceInstance(id, v.id, LocalPlayer); break end
        end
    end,
})
SettingsServer:AddParagraph({ Title = "Current Server", Content = "JobId: "..game.JobId })
SettingsServer:AddInput({
    Title = "Target Server ID",
    Default = "",
    Callback = function(v)
        if v~="" then
            local found = false
            for _, id in ipairs(savedServers) do if id==v then found=true; break end end
            if not found then table.insert(savedServers, 1, v); refreshDropdown() end
            inputObj = v
        end
    end,
})
SettingsServer:AddButton({
    Title = "Teleport to Server",
    Callback = function()
        if inputObj and inputObj~="" then
            pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, inputObj) end)
        end
    end,
})

Library:SetNotification({
    Title = "StreeHub x NatHub",
    Description = "| 99NITF",
    Content = "✅ Script berhasil dimuat!",
    Time = 0.5,
    Delay = 5,
})
