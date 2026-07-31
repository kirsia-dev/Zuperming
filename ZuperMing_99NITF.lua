local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/kirsia-dev/Zuperming/refs/heads/main/ZuperMingGUI.lua"))()
Library:SetTheme("Grey")

local player = game:GetService("Players").LocalPlayer
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local placeId = game.PlaceId
local Lobby = placeId == 79546208627805
local Hutan = placeId == 126509999114328
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Dynamic character references
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:FindFirstChild("HumanoidRootPart")
local humanoid = character:FindFirstChildOfClass("Humanoid")

player.CharacterAdded:Connect(function(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart", 5)
    humanoid = char:WaitForChild("Humanoid", 5)
end)

RunService.Stepped:Connect(function()
    pcall(function()
        sethiddenproperty(player, "SimulationRadius", math.huge)
        sethiddenproperty(player, "MaxSimulationRadius", math.huge)
    end)
end)

_G.Settings = {
    Main = {
        ["Open Map"] = false,
        ["God Mode"] = false,
        ["Auto Chop Tree"] = false,
        ["Selected Tree Type"] = "Small Tree",
        ["Kill Aura"] = false,
        ["Auto Burn Fire"] = false,
        ["Auto Recycling"] = false,
        ["Auto Plant Sapling"] = false,
        ["Auto Plant Circle"] = false,
        ["Auto Cook"] = false,
        ["Auto Eat"] = false,
        ["Auto Open Chest"] = false,
        ["Auto Farm Diamond"] = false,
    },
    Quest = {
        ["Auto Lost Child Quest"] = false,
        ["Auto Lost Child2 Quest"] = false,
        ["Auto Lost Child3 Quest"] = false,
        ["Auto Lost Child4 Quest"] = false,
    },
    Crafting = {},
    Teleport = {
        ["Selected Item"] = "Revolver"
    },
    Esp = {
        ["Enable Item ESP"] = false,
        ["Item ESP Filter"] = {},
        ["Enable Enemy ESP"] = false,
        ["Enemy ESP Filter"] = {},
    },
    Misc = {
        ["Remove Fog"] = false,
        ["Anti Void"] = false,
        ["Night Teleport"] = false,
        ["Character Speed"] = 16,
        ["Infinite Jump"] = false,
        ["Fly"] = false,
        ["FlySpeed"] = 5,
    },
    AutoSave = false,
    AutoCollectFlower = false,
    AutoFishing = false,
}

local folderPath = "ZuperMing"
makefolder(folderPath)
local configFile = folderPath .. "/99NITF.json"

function SaveConfig()
    local success, result = pcall(function()
        return HttpService:JSONEncode(_G.Settings)
    end)
    if success then writefile(configFile, result) end
end

function LoadConfig()
    if isfile(configFile) then
        local data = readfile(configFile)
        local success, result = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if success and type(result) == "table" then
            for k, v in pairs(result) do
                if _G.Settings[k] ~= nil and type(_G.Settings[k]) == type(v) then
                    _G.Settings[k] = v
                elseif type(v) == "table" and type(_G.Settings[k]) == "table" then
                    for sk, sv in pairs(v) do
                        if _G.Settings[k][sk] ~= nil then
                            _G.Settings[k][sk] = sv
                        end
                    end
                end
            end
        end
    else
        SaveConfig()
    end
end
LoadConfig()

_G.Settings.AutoSave = true

function TweenToPosition(model, targetCFrame)
    if not model.PrimaryPart then
        local base = model:FindFirstChildWhichIsA("BasePart")
        if not base then return end
        model.PrimaryPart = base
    end
    local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(model.PrimaryPart, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
end

local MainWindow = Library:CreateWindow({
    Title = "ZuperMing",
    Description = "| 99 Night In The Forest",
    ["Tab Width"] = 120,
    Acrylic = false,
    Theme = "Grey"
})

local Tabs = {
    Discord = MainWindow:CreateTab({ Name = "Discord", Icon = "discord" }),
    Main = MainWindow:CreateTab({ Name = "Main", Icon = "house" }),
    Items = MainWindow:CreateTab({ Name = "Items", Icon = "package" }),
    Quest = MainWindow:CreateTab({ Name = "Quest", Icon = "scroll" }),
    Teleport = MainWindow:CreateTab({ Name = "Teleport", Icon = "map" }),
    Esp = MainWindow:CreateTab({ Name = "Visual", Icon = "eye" }),
    Misc = MainWindow:CreateTab({ Name = "Misc", Icon = "misc" })
}

local Info = Tabs.Discord:AddSection("Information", true)

Info:AddButton({
    Title = "Discord",
    Content = "Join Us!",
    Callback = function()
        local link = "https://discord.gg/V2S6dCzBX5"
        if setclipboard then setclipboard(link) end
    end,
})

if Lobby then
    Library:SetNotification({
        Title = "Lobby Detected",
        Description = "Features not loaded",
        Content = "Please join the game world.",
        Time = 0.5,
        Delay = 5,
    })
end

local mainGeneral = Tabs.Main:AddSection("General", false)

mainGeneral:AddToggle({
    Title = "Open Map",
    Default = _G.Settings.Main["Open Map"],
    Callback = function(value)
        _G.Settings.Main["Open Map"] = value
        local char = player.Character
        local humanoidRootPart = char and char:FindFirstChild("HumanoidRootPart")
        if value then
            if humanoidRootPart then
                _G.OriginalPosition = humanoidRootPart.CFrame
            end
            _G.OriginalCameraType = workspace.CurrentCamera.CameraType
            _G.OriginalCameraSubject = workspace.CurrentCamera.CameraSubject
            _G.VisitedPositions = {}
            workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
            workspace.CurrentCamera.CameraSubject = nil
            function getRandomUnvisitedCFrame()
                local randomCFrame; local attempts = 0
                repeat
                    local randomX = math.random(-1000, 1000)
                    local randomY = math.random(25, 100)
                    local randomZ = math.random(-1000, 1000)
                    randomCFrame = CFrame.new(randomX, randomY, randomZ)
                    attempts = attempts + 1
                until not _G.VisitedPositions[tostring(randomCFrame.Position)] or attempts > 50
                _G.VisitedPositions[tostring(randomCFrame.Position)] = true
                return randomCFrame
            end
            _G.MapTeleportConnection = RunService.Heartbeat:Connect(function()
                if _G.Settings.Main["Open Map"] then
                    local h = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if h then
                        h.CFrame = getRandomUnvisitedCFrame()
                    end
                    task.wait(1)
                end
            end)
        else
            if _G.MapTeleportConnection then
                _G.MapTeleportConnection:Disconnect()
                _G.MapTeleportConnection = nil
            end
            local h = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if h and _G.OriginalPosition then
                h.CFrame = _G.OriginalPosition
            end
            if workspace.CurrentCamera then
                workspace.CurrentCamera.CameraType = _G.OriginalCameraType or Enum.CameraType.Custom
                workspace.CurrentCamera.CameraSubject = _G.OriginalCameraSubject or (player.Character and player.Character:FindFirstChild("Humanoid"))
            end
            _G.VisitedPositions = nil
            _G.OriginalPosition = nil
        end
    end
})

mainGeneral:AddButton({
    Title = "Reset Config",
    Callback = function()
        function ResetTable(tbl)
            for k, v in pairs(tbl) do
                if type(v) == "table" then
                    ResetTable(v)
                else
                    tbl[k] = false
                end
            end
        end
        ResetTable(_G.Settings)
        SaveConfig()
        Library:SetNotification({
            Title = "ZuperMing",
            Description = "Config Reset",
            Content = "All settings have been reset.",
            Time = 0.5,
            Delay = 3,
        })
    end
})

if Hutan then
    local autoSection = Tabs.Main:AddSection("Auto Farm", false)

    autoSection:AddDropdown({
        Title = "Tree Type",
        Options = {"Small Tree", "Big Tree"},
        Default = _G.Settings.Main["Selected Tree Type"],
        Multi = false,
        Callback = function(option)
            _G.Settings.Main["Selected Tree Type"] = option
            if _G.Settings.AutoSave then SaveConfig() end
        end,
    })

    autoSection:AddToggle({
        Title = "Auto Chop Tree",
        Content = "Equip weapon to enable",
        Default = _G.Settings.Main["Auto Chop Tree"],
        Callback = function(value)
            _G.Settings.Main["Auto Chop Tree"] = value
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    local toolsDamageIDs = {
        ["Old Axe"] = "_1",
        ["Good Axe"] = "_1",
        ["Strong Axe"] = "_1",
    }

    function getToolAndDamageID()
        local inv = player:FindFirstChild("Inventory")
        if not inv then return nil, nil end
        for toolName, suffix in pairs(toolsDamageIDs) do
            local tool = inv:FindFirstChild(toolName)
            if tool then
                return tool, suffix
            end
        end
        return nil, nil
    end

    function findBasePart(model)
        for _, v in ipairs(model:GetDescendants()) do
            if v:IsA("BasePart") then
                return v
            end
        end
        return nil
    end

    function getAllTrees()
        local trees = {}
        local folders = {
            Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Landmarks"),
            Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Foliage")
        }
        local targetType = _G.Settings.Main["Selected Tree Type"]
        for _, folder in ipairs(folders) do
            if folder then
                for _, obj in ipairs(folder:GetChildren()) do
                    if targetType == "Small Tree" and obj.Name == "Small Tree" and obj:IsA("Model") then
                        table.insert(trees, obj)
                    elseif targetType == "Big Tree" and (obj.Name == "TreeBig1" or obj.Name == "TreeBig2" or obj.Name == "TreeBig3") and obj:IsA("Model") then
                        table.insert(trees, obj)
                    end
                end
            end
        end
        return trees
    end

    function createHealthText(tree)
        if tree:FindFirstChild("HealthTextGUI") then
            return tree.HealthTextGUI
        end
        local healthText = Instance.new("BillboardGui")
        healthText.Name = "HealthTextGUI"
        healthText.Size = UDim2.new(8, 0, 3, 0)
        healthText.StudsOffset = Vector3.new(0, 8, 0)
        healthText.AlwaysOnTop = true
        healthText.Adornee = findBasePart(tree)
        healthText.Parent = tree
        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "HealthLabel"
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.TextStrokeTransparency = 0
        local uiStroke = Instance.new("UIStroke")
        uiStroke.Thickness = 2
        uiStroke.Color = Color3.fromRGB(0, 0, 0)
        uiStroke.Parent = textLabel
        textLabel.Parent = healthText
        return healthText
    end

    function updateHealthText(tree)
        if not tree:FindFirstChild("HealthTextGUI") then return end
        local healthText = tree.HealthTextGUI
        local textLabel = healthText.HealthLabel
        local maxHealth = tree:GetAttribute("MaxHealth") or 100
        local currentHealth = tree:GetAttribute("Health") or maxHealth
        textLabel.Text = string.format("%d/%d", currentHealth, maxHealth)
    end

    function cleanupHealthTexts()
        for _, folder in ipairs({Workspace.Map and Workspace.Map:FindFirstChild("Landmarks"), Workspace.Map and Workspace.Map:FindFirstChild("Foliage")}) do
            if folder then
                for _, obj in ipairs(folder:GetChildren()) do
                    if obj:IsA("Model") and (obj.Name == "Small Tree" or obj.Name == "TreeBig1" or obj.Name == "TreeBig2" or obj.Name == "TreeBig3") then
                        if obj:FindFirstChild("HealthTextGUI") then
                            obj.HealthTextGUI:Destroy()
                        end
                    end
                end
            end
        end
    end

    local hitCounter = 1
    spawn(function()
        while task.wait(0.2) do
            if _G.Settings.Main["Auto Chop Tree"] then
                local tool, suffix = getToolAndDamageID()
                if tool and suffix then
                    local allTrees = getAllTrees()
                    if #allTrees == 0 then
                        task.wait(1)
                    else
                        for _, tree in ipairs(allTrees) do
                            if not _G.Settings.Main["Auto Chop Tree"] then break end
                            createHealthText(tree)
                            updateHealthText(tree)
                            local part = findBasePart(tree)
                            if part then
                                spawn(function()
                                    local hitCount = _G.Settings.Main["Selected Tree Type"] == "Small Tree" and 13 or 20
                                    for i = 1, hitCount do
                                        if not _G.Settings.Main["Auto Chop Tree"] then break end
                                        local damageID = tostring(hitCounter) .. suffix
                                        local args = {tree, tool, damageID, CFrame.new(part.Position)}
                                        pcall(function()
                                            RemoteEvents.ToolDamageObject:InvokeServer(unpack(args))
                                        end)
                                        hitCounter = hitCounter + 1
                                        updateHealthText(tree)
                                        task.wait(0.25)
                                    end
                                end)()
                            end
                        end
                        task.wait(0.2)
                    end
                end
            else
                cleanupHealthTexts()
                task.wait(1)
            end
        end
    end)

    autoSection:AddToggle({
        Title = "Kill Aura",
        Content = "Equip weapon to enable",
        Default = _G.Settings.Main["Kill Aura"],
        Callback = function(value)
            _G.Settings.Main["Kill Aura"] = value
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    spawn(function()
        while true do
            task.wait(0.2)
            if _G.Settings.Main["Kill Aura"] then
                local tool, suffix = getToolAndDamageID()
                local char = player.Character
                local h = char and char:FindFirstChild("HumanoidRootPart")
                if tool and suffix and h then
                    local chars = Workspace:FindFirstChild("Characters")
                    if chars then
                        for _, enemy in ipairs(chars:GetChildren()) do
                            if enemy:IsA("Model") and enemy ~= char then
                                local part = findBasePart(enemy)
                                if part then
                                    spawn(function()
                                        for i = 1, 13 do
                                            if not _G.Settings.Main["Kill Aura"] or not enemy or not enemy.Parent then break end
                                            local damageID = tostring(hitCounter) .. suffix
                                            pcall(function()
                                                RemoteEvents.ToolDamageObject:InvokeServer(enemy, tool, damageID, CFrame.new(part.Position))
                                            end)
                                            hitCounter = hitCounter + 1
                                            task.wait(0.2)
                                        end
                                    end)()
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    autoSection:AddToggle({
        Title = "Auto Burn Fuel",
        Default = _G.Settings.Main["Auto Burn Fire"],
        Callback = function(value)
            _G.Settings.Main["Auto Burn Fire"] = value
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    spawn(function()
        pcall(function()
            local remoteEvents = game.ReplicatedStorage:WaitForChild("RemoteEvents")
            local allowedNames = {
                ["Log"] = true,
                ["Chair"] = true,
                ["Biofuel"] = true,
                ["Coal"] = true,
                ["Fuel Canister"] = true,
                ["Oil Barrel"] = true,
            }
            local targetPosition = Vector3.new(0, 8, 0)
            while true do
                task.wait(0.2)
                if _G.Settings.Main["Auto Burn Fire"] then
                    local char = player.Character or player.CharacterAdded:Wait()
                    local h = char:WaitForChild("HumanoidRootPart")
                    while _G.Settings.Main["Auto Burn Fire"] do
                        local itemsFolder = workspace:FindFirstChild("Items")
                        local foundItem = false
                        if itemsFolder and h then
                            for _, item in ipairs(itemsFolder:GetChildren()) do
                                if not _G.Settings.Main["Auto Burn Fire"] then break end
                                if allowedNames[item.Name] and item:IsA("Model") then
                                    local base = item:FindFirstChildWhichIsA("BasePart")
                                    if base then
                                        foundItem = true
                                        if not item.PrimaryPart then item.PrimaryPart = base end
                                        pcall(function()
                                            remoteEvents.RequestStartDraggingItem:FireServer(item)
                                            item:SetPrimaryPartCFrame(CFrame.new(targetPosition))
                                            remoteEvents.RequestBurnItem:FireServer("MainFire", item)
                                            remoteEvents.StopDraggingItem:FireServer(item)
                                        end)
                                        task.wait(0.1)
                                    end
                                end
                            end
                        end
                        if not foundItem then task.wait(1) else task.wait(0.5) end
                    end
                else
                    task.wait(1)
                end
            end
        end)
    end)

    autoSection:AddToggle({
        Title = "Auto Recycling",
        Default = _G.Settings.Main["Auto Recycling"],
        Callback = function(value)
            _G.Settings.Main["Auto Recycling"] = value
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    spawn(function()
        pcall(function()
            local allowedNames = {
                ["Log"] = true,
                ["Sheet Metal"] = true,
                ["Bolt"] = true,
                ["UFO Junk"] = true,
                ["UFO Component"] = true,
                ["Broken Fan"] = true,
                ["Broken Radio"] = true,
                ["Broken Microwave"] = true,
                ["Tyre"] = true,
                ["Metal Chair"] = true,
                ["Old Car Engine"] = true,
                ["Washing Machine"] = true,
                ["Cultist Experiment"] = true,
                ["Cultist Prototype"] = true,
                ["UFO Scrap"] = true,
            }
            local targetPos = Vector3.new(20.953278, 8, -5.237123)
            local remote = game.ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestScrapItem")
            local craftingBench = workspace.Map and workspace.Map:WaitForChild("Campground"):WaitForChild("CraftingBench")
            while true do
                task.wait(0.2)
                if _G.Settings.Main["Auto Recycling"] then
                    local char = player.Character or player.CharacterAdded:Wait()
                    local h = char:FindFirstChild("HumanoidRootPart")
                    if not h then
                        task.wait(1)
                    else
                        local itemsFolder = workspace:FindFirstChild("Items")
                        if itemsFolder then
                            for _, item in ipairs(itemsFolder:GetChildren()) do
                                if not _G.Settings.Main["Auto Recycling"] then break end
                                if item:IsA("Model") and allowedNames[item.Name] then
                                    local basePart = item:FindFirstChildWhichIsA("BasePart")
                                    if basePart then
                                        if not item.PrimaryPart then item.PrimaryPart = basePart end
                                        pcall(function()
                                            item:SetPrimaryPartCFrame(CFrame.new(targetPos))
                                        end)
                                        task.wait(0.3)
                                        pcall(function()
                                            remote:InvokeServer(craftingBench, item)
                                        end)
                                        task.wait(0.5)
                                    end
                                end
                            end
                        end
                    end
                else
                    task.wait(1)
                end
            end
        end)
    end)

    autoSection:AddToggle({
        Title = "Auto Plant Sapling",
        Default = _G.Settings.Main["Auto Plant Sapling"],
        Callback = function(value)
            _G.Settings.Main["Auto Plant Sapling"] = value
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    spawn(function()
        pcall(function()
            local remoteEvents = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
            local itemsFolder = workspace:WaitForChild("Items")
            while true do
                task.wait(0.5)
                if _G.Settings.Main["Auto Plant Sapling"] then
                    local char = player.Character or player.CharacterAdded:Wait()
                    local h = char:FindFirstChild("HumanoidRootPart")
                    if not h then
                        task.wait(1)
                    else
                        for _, item in ipairs(itemsFolder:GetChildren()) do
                            if not _G.Settings.Main["Auto Plant Sapling"] then break end
                            if item:IsA("Model") and item.Name == "Sapling" then
                                local base = item:FindFirstChildWhichIsA("BasePart")
                                if base then
                                    if not item.PrimaryPart then item.PrimaryPart = base end
                                    local pos = item:GetPivot().Position
                                    local vec = Vector3.new(pos.X, pos.Y - 1, pos.Z)
                                    pcall(function()
                                        remoteEvents.RequestStartDraggingItem:FireServer(item)
                                    end)
                                    task.wait(0.1)
                                    pcall(function()
                                        remoteEvents.RequestPlantItem:InvokeServer(item, vec)
                                    end)
                                    pcall(function()
                                        remoteEvents.StopDraggingItem:FireServer(item)
                                    end)
                                    task.wait(0.2)
                                end
                            end
                        end
                    end
                else
                    task.wait(1)
                end
            end
        end)
    end)

    autoSection:AddToggle({
        Title = "Auto Plant Circle",
        Default = _G.Settings.Main["Auto Plant Circle"],
        Callback = function(value)
            _G.Settings.Main["Auto Plant Circle"] = value
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    spawn(function()
        pcall(function()
            local remoteEvents = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
            local itemsFolder = workspace:WaitForChild("Items")
            local outerZone = workspace.Map and workspace.Map:WaitForChild("Campground") and workspace.Map.Campground:WaitForChild("MainFire") and workspace.Map.Campground.MainFire:WaitForChild("OuterTouchZone")
            if not outerZone then return end
            local plantedPositions = {}
            local maxPlants = 16
            local radius = outerZone.Size.X / 2 + 8
            while true do
                task.wait(0.5)
                if _G.Settings.Main["Auto Plant Circle"] then
                    local char = player.Character or player.CharacterAdded:Wait()
                    local h = char:FindFirstChild("HumanoidRootPart")
                    if not h then
                        task.wait(1)
                    else
                        for _, item in ipairs(itemsFolder:GetChildren()) do
                            if not _G.Settings.Main["Auto Plant Circle"] then break end
                            if #plantedPositions >= maxPlants then break end
                            if item:IsA("Model") and item.Name == "Sapling" then
                                local base = item:FindFirstChildWhichIsA("BasePart")
                                if base then
                                    if not item.PrimaryPart then item.PrimaryPart = base end
                                    local angle
                                    local attempts = 0
                                    local validPosition = false
                                    local newVec
                                    repeat
                                        angle = (#plantedPositions / maxPlants) * 2 * math.pi
                                        local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                                        newVec = outerZone.Position + offset
                                        newVec = Vector3.new(newVec.X, outerZone.Position.Y, newVec.Z)
                                        validPosition = true
                                        for _, existingPos in ipairs(plantedPositions) do
                                            if (existingPos - newVec).Magnitude < 5 then
                                                validPosition = false
                                                angle = angle + (2 * math.pi / maxPlants)
                                                break
                                            end
                                        end
                                        attempts = attempts + 1
                                    until validPosition or attempts > 10
                                    if validPosition then
                                        table.insert(plantedPositions, newVec)
                                        pcall(function()
                                            remoteEvents.RequestStartDraggingItem:FireServer(item)
                                        end)
                                        task.wait(0.1)
                                        pcall(function()
                                            remoteEvents.RequestPlantItem:InvokeServer(item, newVec)
                                        end)
                                        pcall(function()
                                            remoteEvents.StopDraggingItem:FireServer(item)
                                        end)
                                        task.wait(0.2)
                                    end
                                end
                            end
                        end
                    end
                else
                    plantedPositions = {}
                    task.wait(1)
                end
            end
        end)
    end)

    local consumableSection = Tabs.Main:AddSection("Consumable", false)

    consumableSection:AddToggle({
        Title = "Auto Cook",
        Default = _G.Settings.Main["Auto Cook"],
        Callback = function(value)
            _G.Settings.Main["Auto Cook"] = value
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    spawn(function()
        pcall(function()
            local autoCookFoods = {"Steak", "Morsel"}
            local itemsFolder = workspace:WaitForChild("Items")
            while true do
                task.wait(0.5)
                if _G.Settings.Main["Auto Cook"] then
                    local available = {}
                    for _, item in ipairs(itemsFolder:GetChildren()) do
                        if item:IsA("Model") and table.find(autoCookFoods, item.Name) then
                            table.insert(available, item)
                        end
                    end
                    if #available > 0 then
                        local food = available[math.random(1, #available)]
                        pcall(function()
                            if not food.PrimaryPart then
                                local bp = food:FindFirstChildWhichIsA("BasePart")
                                if bp then food.PrimaryPart = bp end
                            end
                            if food.PrimaryPart then
                                food:SetPrimaryPartCFrame(CFrame.new(0, 8, 0))
                            end
                        end)
                    end
                else
                    task.wait(1)
                end
            end
        end)
    end)

    consumableSection:AddToggle({
        Title = "Auto Eat",
        Default = _G.Settings.Main["Auto Eat"],
        Callback = function(value)
            _G.Settings.Main["Auto Eat"] = value
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    spawn(function()
        pcall(function()
            local autoEatFoods = {"Cooked Steak", "Cooked Morsel", "Berry", "Carrot", "Apple"}
            local itemsFolder = workspace:WaitForChild("Items")
            local remoteConsume = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("RequestConsumeItem")
            local remoteDrag = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("RequestStartDraggingItem")
            while true do
                task.wait(0.5)
                if _G.Settings.Main["Auto Eat"] then
                    local available = {}
                    for _, item in ipairs(itemsFolder:GetChildren()) do
                        if item:IsA("Model") and table.find(autoEatFoods, item.Name) then
                            table.insert(available, item)
                        end
                    end
                    if #available > 0 then
                        local food = available[math.random(1, #available)]
                        pcall(function()
                            remoteDrag:FireServer(food)
                            task.wait(0.25)
                            remoteConsume:InvokeServer(food)
                        end)
                    end
                else
                    task.wait(1)
                end
            end
        end)
    end)

    local flowerSection = Tabs.Main:AddSection("Flowers", false)

    _G.AutoCollectFlower = false
    local originalCFrame = nil
    local pickFlowerRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestPickFlower")

    function collectFlower(flower)
        pcall(function()
            if not flower:IsA("Model") or not flower.PrimaryPart then return end
            local char = player.Character
            local h = char and char:FindFirstChild("HumanoidRootPart")
            if not h then return end
            if not originalCFrame then
                originalCFrame = h.CFrame
            end
            h.CFrame = flower.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.1)
            pickFlowerRemote:InvokeServer(flower)
            task.wait(0.1)
        end)
    end

    function returnToOriginal()
        local char = player.Character
        local h = char and char:FindFirstChild("HumanoidRootPart")
        if h and originalCFrame then
            h.CFrame = originalCFrame
            originalCFrame = nil
        end
    end

    spawn(function()
        while true do
            task.wait(0.2)
            if _G.AutoCollectFlower then
                local found = false
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj.Name:lower():find("flower") and obj:IsA("Model") then
                        found = true
                        collectFlower(obj)
                    end
                end
                if not found then returnToOriginal() end
            else
                returnToOriginal()
            end
        end
    end)

    flowerSection:AddToggle({
        Title = "Auto Collect Flower",
        Default = _G.AutoCollectFlower,
        Callback = function(val)
            _G.AutoCollectFlower = val
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    flowerSection:AddButton({
        Title = "Show Flower Shop",
        Callback = function()
            local flowerUI = player:WaitForChild("PlayerGui"):WaitForChild("Interface"):FindFirstChild("Flower")
            if flowerUI then flowerUI.Visible = true end
        end
    })

    flowerSection:AddButton({
        Title = "Teleport Seed Box",
        Callback = function()
            local seedBox = workspace:FindFirstChild("Items") and workspace.Items:FindFirstChild("Seed Box")
            if seedBox then
                if not seedBox.PrimaryPart then
                    seedBox.PrimaryPart = seedBox:FindFirstChild("HumanoidRootPart") or seedBox:FindFirstChildWhichIsA("BasePart")
                end
                if seedBox.PrimaryPart then
                    seedBox:SetPrimaryPartCFrame(CFrame.new(0, 8, 0))
                end
            end
        end
    })

    local fishingSection = Tabs.Main:AddSection("Fishing", false)

    fishingSection:AddButton({
        Title = "Teleport to Fishing Area",
        Callback = function()
            local char = player.Character or player.CharacterAdded:Wait()
            local h = char:WaitForChild("HumanoidRootPart")
            local map = workspace:WaitForChild("Map")
            local landmarks = map:WaitForChild("Landmarks")
            local fishingHut = landmarks:WaitForChild("Fishing Hut")
            local building = fishingHut:WaitForChild("Building")
            local door = building:WaitForChild("Door")
            local main = door:WaitForChild("Main")
            if h and main then
                h.CFrame = main.CFrame + Vector3.new(0, 5, 0)
            end
        end
    })

    fishingSection:AddToggle({
        Title = "Auto Fishing",
        Default = _G.AutoFishing,
        Callback = function(value)
            _G.AutoFishing = value
            if _G.Settings.AutoSave then SaveConfig() end
        end
    })

    local waterFolder = workspace:WaitForChild("Map"):WaitForChild("Water")
    function getNearestWater()
        local char = player.Character
        local h = char and char:FindFirstChild("HumanoidRootPart")
        if not h then return nil end
        local nearest, nearestDist = nil, math.huge
        for _, part in ipairs(waterFolder:GetChildren()) do
            if part:IsA("BasePart") then
                local dist = (h.Position - part.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = part
                end
            end
        end
        return nearest
    end

    function clickPartOnce(part)
        local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(part.Position)
        if not onScreen then return end
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
    end

    function getClient()
        local clientScript = player.PlayerScripts:FindFirstChild("Client")
        if not clientScript then return nil end
        local ok, result = pcall(require, clientScript)
        return ok and result or nil
    end

    local Client = getClient()
    spawn(function()
        while task.wait(0.5) do
            if _G.AutoFishing then
                pcall(function()
                    local nearestWater = getNearestWater()
                    if nearestWater then clickPartOnce(nearestWater) end
                    local frame
                    repeat
                        frame = Client and Client.Interface and Client.Interface.FishingCatchFrame
                        task.wait(0.1)
                    until not _G.AutoFishing or (frame and frame.Visible)
                    while _G.AutoFishing and frame and frame.Visible do
                        local successArea = frame.TimingBar and frame.TimingBar:FindFirstChild("SuccessArea")
                        local bar = frame.TimingBar and frame.TimingBar:FindFirstChild("Bar")
                        if successArea and bar then
                            local successY = successArea.AbsolutePosition.Y
                            local successH = successArea.AbsoluteSize.Y
                            local barY = bar.AbsolutePosition.Y
                            if barY >= successY and barY <= successY + successH then
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                                task.wait(0.05)
                            end
                        end
                        task.wait(0.05)
                    end
                    task.wait(0.5)
                end)
            end
        end
    end)

    local tamingSection = Tabs.Main:AddSection("Taming Animals", false)

    local TamingEnabled = false
    local SelectedAnimal = ""
    function GetAnimalList()
        local animals = {}
        local charactersFolder = Workspace:FindFirstChild("Characters")
        if not charactersFolder then return animals end
        local foundNames = {}
        for _, animal in pairs(charactersFolder:GetChildren()) do
            if animal:IsA("Model") and not foundNames[animal.Name] and not animal:FindFirstChild("NameLabel") then
                table.insert(animals, animal.Name)
                foundNames[animal.Name] = true
            end
        end
        return animals
    end

    function GetClosestAnimal(animalName)
        local closest = nil
        local shortestDistance = math.huge
        local char = player.Character
        local playerPos = char and char:GetPivot().Position
        if not playerPos then return nil end
        local chars = Workspace:FindFirstChild("Characters")
        if not chars then return nil end
        for _, animal in pairs(chars:GetChildren()) do
            if animal.Name == animalName and animal:IsA("Model") and not animal:FindFirstChild("NameLabel") then
                local distance = (animal:GetPivot().Position - playerPos).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closest = animal
                end
            end
        end
        return closest
    end

    function GetRequiredFood(petName)
        local pet = GetClosestAnimal(petName)
        if pet then
            local head = pet:FindFirstChild("Head")
            local tamingHunger = head and head:FindFirstChild("TamingHunger")
            local food1 = tamingHunger and tamingHunger:FindFirstChild("Food1")
            if food1 and food1:FindFirstChild("TextLabel") then
                return food1.TextLabel.Text
            end
        end
        return nil
    end

    function BringFood(foodName)
        local items = Workspace:FindFirstChild("Items")
        if not items then return end
        local foodItem = items:FindFirstChild(foodName)
        if foodItem then
            pcall(function()
                ReplicatedStorage.RemoteEvents.RequestStartDraggingItem:FireServer(foodItem)
            end)
            local pet = GetClosestAnimal(SelectedAnimal)
            if pet then
                pcall(function()
                    foodItem:PivotTo(pet:GetPivot())
                end)
            end
        end
    end

    function AutoTame()
        while TamingEnabled do
            task.wait(1)
            if SelectedAnimal == "" then break end
            local pet = GetClosestAnimal(SelectedAnimal)
            if not pet then break end
            local inv = player:FindFirstChild("Inventory")
            local flute = inv and inv:FindFirstChild("Old Taming Flute")
            if pet and flute then
                local requiredFood = GetRequiredFood(SelectedAnimal)
                if requiredFood and requiredFood ~= "" then
                    BringFood(requiredFood)
                    task.wait(2)
                else
                    pcall(function()
                        local args = {pet, flute}
                        ReplicatedStorage.RemoteEvents.RequestTame_Neutral:FireServer(unpack(args))
                    end)
                    task.wait(0.5)
                    pcall(function()
                        local args = {pet, flute}
                        ReplicatedStorage.RemoteEvents.RequestTame_Hungry:FireServer(unpack(args))
                    end)
                end
            end
        end
    end

    local animalList = GetAnimalList()
    local animalDropdown = tamingSection:AddDropdown({
        Title = "Choose Animal",
        Options = animalList,
        Default = #animalList > 0 and animalList[1] or nil,
        Multi = false,
        Callback = function(option)
            SelectedAnimal = option or ""
        end,
    })

    tamingSection:AddButton({
        Title = "Refresh List",
        Callback = function()
            local newList = GetAnimalList()
            animalDropdown:Refresh(newList, #newList > 0 and newList[1] or nil)
            SelectedAnimal = ""
        end
    })

    tamingSection:AddToggle({
        Title = "Auto Taming",
        Default = false,
        Callback = function(state)
            TamingEnabled = state
            if state then AutoTame() end
        end
    })
end

local selectedTargets = {}
local itemsSection = Tabs.Items:AddSection("General", false)

itemsSection:AddDropdown({
    Title = "Choose Target",
    Options = {"Player", "Campfire"},
    Default = nil,
    Multi = true,
    Callback = function(option)
        selectedTargets = option or {}
    end,
})

local selectedItems = {}
local itemListAll = {
    "Bolt", "Tyre", "Sheet Metal", "Old Radio", "Broken Fan",
    "Broken Microwave", "Washing Machine", "Old Car Engine",
    "UFO Scrap", "UFO Component", "UFO Junk", "Cutlist Gem", "Gem of the Forest"
}

local gearsSection = Tabs.Items:AddSection("Gears", false)

gearsSection:AddDropdown({
    Title = "Choose Item",
    Options = itemListAll,
    Default = nil,
    Multi = true,
    Callback = function(option)
        selectedItems = option or {}
    end,
})

gearsSection:AddButton({
    Title = "Collect Item",
    Callback = function()
        local char = player.Character or player.CharacterAdded:Wait()
        local h = char:WaitForChild("HumanoidRootPart")
        local itemsFolder = workspace:WaitForChild("Items")
        local totalMoved = 0
        local notFound = {}
        function includes(t, v) return t and table.find(t, v) ~= nil end
        local destinationCFrame
        if includes(selectedTargets, "Campfire") then
            destinationCFrame = CFrame.new(0, 8, 0)
        elseif includes(selectedTargets, "Player") then
            destinationCFrame = h.CFrame
        else
            Library:SetNotification({Title = "ZuperMing", Description = "Target Missing", Content = "Choose a target first", Time = 0.5, Delay = 4})
            return
        end
        local MAX_ITEMS = 1000
        for _, itemName in ipairs(selectedItems or {}) do
            if totalMoved >= MAX_ITEMS then break end
            local foundAny = false
            for _, item in ipairs(itemsFolder:GetChildren()) do
                if totalMoved >= MAX_ITEMS then break end
                if item.Name == itemName then
                    foundAny = true
                    if item:IsA("Model") then
                        pcall(function() item:PivotTo(destinationCFrame) end)
                    elseif item:IsA("BasePart") then
                        item.CFrame = destinationCFrame
                    else
                        local part = item:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local modelLike = part:FindFirstAncestorOfClass("Model")
                            if modelLike then
                                pcall(function() modelLike:PivotTo(destinationCFrame) end)
                            else
                                part.CFrame = destinationCFrame
                            end
                        end
                    end
                    totalMoved = totalMoved + 1
                    task.wait(0.03)
                end
            end
            if not foundAny then table.insert(notFound, itemName) end
        end
        local targetLabel = includes(selectedTargets, "Campfire") and "Campfire" or "Player"
        if totalMoved > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Items Collected", Content = string.format("Moved %d item(s) to %s", totalMoved, targetLabel), Time = 0.5, Delay = 4})
        end
        if #notFound > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Not Found", Content = table.concat(notFound, ", "), Time = 0.5, Delay = 5})
        end
    end
})

local selectedFuelItems = {}
local fuelSection = Tabs.Items:AddSection("Fuel", false)
fuelSection:AddDropdown({
    Title = "Choose Fuel",
    Options = {"Corpse", "Sapling", "Alien", "Log", "Chair", "Coal", "Fuel Canister", "Oil Barrel", "Biofuel"},
    Default = nil,
    Multi = true,
    Callback = function(option)
        selectedFuelItems = option or {}
    end,
})

fuelSection:AddButton({
    Title = "Collect Fuel",
    Callback = function()
        local char = player.Character or player.CharacterAdded:Wait()
        local h = char:WaitForChild("HumanoidRootPart")
        local itemsFolder = workspace:WaitForChild("Items")
        local totalMoved = 0
        local notFound = {}
        function includes(t, v) return t and table.find(t, v) ~= nil end
        local dest
        if includes(selectedTargets, "Campfire") then
            dest = CFrame.new(0, 8, 0)
        elseif includes(selectedTargets, "Player") then
            dest = h.CFrame
        else
            Library:SetNotification({Title = "ZuperMing", Description = "Target Missing", Content = "Choose a target first", Time = 0.5, Delay = 4})
            return
        end
        local MAX_ITEMS = 1000
        if not (selectedFuelItems and #selectedFuelItems > 0) then
            Library:SetNotification({Title = "ZuperMing", Description = "No Items", Content = "Choose fuel items", Time = 0.5, Delay = 4})
            return
        end
        for _, itemName in ipairs(selectedFuelItems) do
            if totalMoved >= MAX_ITEMS then break end
            local found = false
            for _, item in ipairs(itemsFolder:GetChildren()) do
                if totalMoved >= MAX_ITEMS then break end
                if item.Name == itemName then
                    found = true
                    if item:IsA("Model") then
                        pcall(function() item:PivotTo(dest) end)
                    elseif item:IsA("BasePart") then
                        item.CFrame = dest
                    else
                        local part = item:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local modelLike = part:FindFirstAncestorOfClass("Model")
                            if modelLike then
                                pcall(function() modelLike:PivotTo(dest) end)
                            else
                                part.CFrame = dest
                            end
                        end
                    end
                    totalMoved = totalMoved + 1
                    task.wait(0.03)
                end
            end
            if not found then table.insert(notFound, itemName) end
        end
        local targetLabel = includes(selectedTargets, "Campfire") and "Campfire" or "Player"
        if totalMoved > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Fuel Collected", Content = string.format("Moved %d fuel item(s) to %s", totalMoved, targetLabel), Time = 0.5, Delay = 4})
        end
        if #notFound > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Not Found", Content = table.concat(notFound, ", "), Time = 0.5, Delay = 5})
        end
    end
})

local selectedFoodItems = {}
local foodSection = Tabs.Items:AddSection("Food / Healing", false)

foodSection:AddDropdown({
    Title = "Choose Food / Healing",
    Options = {"Carrot", "Berry", "Morsel", "Steak", "Ribs", "Cooked Morsel", "Cooked Steak", "Cooked Ribs", "Bandage", "Medkit", "Chili"},
    Default = nil,
    Multi = true,
    Callback = function(option)
        selectedFoodItems = option or {}
    end,
})

foodSection:AddButton({
    Title = "Collect Food / Healing",
    Callback = function()
        local char = player.Character or player.CharacterAdded:Wait()
        local h = char:WaitForChild("HumanoidRootPart")
        local itemsFolder = workspace:WaitForChild("Items")
        local totalMoved = 0
        local notFound = {}
        function includes(t, v) return t and table.find(t, v) ~= nil end
        local dest
        if includes(selectedTargets, "Campfire") then
            dest = CFrame.new(0, 8, 0)
        elseif includes(selectedTargets, "Player") then
            dest = h.CFrame
        else
            Library:SetNotification({Title = "ZuperMing", Description = "Target Missing", Content = "Choose a target first", Time = 0.5, Delay = 4})
            return
        end
        local MAX_ITEMS = 1000
        if not (selectedFoodItems and #selectedFoodItems > 0) then
            Library:SetNotification({Title = "ZuperMing", Description = "No Items", Content = "Choose food items", Time = 0.5, Delay = 4})
            return
        end
        for _, itemName in ipairs(selectedFoodItems) do
            if totalMoved >= MAX_ITEMS then break end
            local found = false
            for _, item in ipairs(itemsFolder:GetChildren()) do
                if totalMoved >= MAX_ITEMS then break end
                if item.Name == itemName then
                    found = true
                    if item:IsA("Model") then
                        pcall(function() item:PivotTo(dest) end)
                    elseif item:IsA("BasePart") then
                        item.CFrame = dest
                    else
                        local part = item:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local modelLike = part:FindFirstAncestorOfClass("Model")
                            if modelLike then
                                pcall(function() modelLike:PivotTo(dest) end)
                            else
                                part.CFrame = dest
                            end
                        end
                    end
                    totalMoved = totalMoved + 1
                    task.wait(0.03)
                end
            end
            if not found then table.insert(notFound, itemName) end
        end
        local targetLabel = includes(selectedTargets, "Campfire") and "Campfire" or "Player"
        if totalMoved > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Food Collected", Content = string.format("Moved %d food item(s) to %s", totalMoved, targetLabel), Time = 0.5, Delay = 4})
        end
        if #notFound > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Not Found", Content = table.concat(notFound, ", "), Time = 0.5, Delay = 5})
        end
    end
})

local selectedGearItems = {}
local gearSection = Tabs.Items:AddSection("Guns & Armor", false)

gearSection:AddDropdown({
    Title = "Choose Guns / Armor",
    Options = {"Morning star", "Laser Sword", "Raygun", "Chainsaw", "Strong Axe", "Spear", "Good Axe", "Revolver", "Rifle", "Tactical Shotgun", "Revolver Ammo", "Rifle Ammo", "Alien Armour", "Leather Body", "Iron Body", "Thorn Body", "Riot Shield"},
    Default = nil,
    Multi = true,
    Callback = function(option)
        selectedGearItems = option or {}
    end,
})

gearSection:AddButton({
    Title = "Collect Guns / Armor",
    Callback = function()
        local char = player.Character or player.CharacterAdded:Wait()
        local h = char:WaitForChild("HumanoidRootPart")
        local itemsFolder = workspace:WaitForChild("Items")
        local totalMoved = 0
        local notFound = {}
        function includes(t, v) return t and table.find(t, v) ~= nil end
        local dest
        if includes(selectedTargets, "Campfire") then
            dest = CFrame.new(0, 8, 0)
        elseif includes(selectedTargets, "Player") then
            dest = h.CFrame
        else
            Library:SetNotification({Title = "ZuperMing", Description = "Target Missing", Content = "Choose a target first", Time = 0.5, Delay = 4})
            return
        end
        local MAX_ITEMS = 1000
        if not (selectedGearItems and #selectedGearItems > 0) then
            Library:SetNotification({Title = "ZuperMing", Description = "No Items", Content = "Choose gear items", Time = 0.5, Delay = 4})
            return
        end
        for _, itemName in ipairs(selectedGearItems) do
            if totalMoved >= MAX_ITEMS then break end
            local found = false
            for _, item in ipairs(itemsFolder:GetChildren()) do
                if totalMoved >= MAX_ITEMS then break end
                if item.Name == itemName then
                    found = true
                    if item:IsA("Model") then
                        pcall(function() item:PivotTo(dest) end)
                    elseif item:IsA("BasePart") then
                        item.CFrame = dest
                    else
                        local part = item:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local modelLike = part:FindFirstAncestorOfClass("Model")
                            if modelLike then
                                pcall(function() modelLike:PivotTo(dest) end)
                            else
                                part.CFrame = dest
                            end
                        end
                    end
                    totalMoved = totalMoved + 1
                    task.wait(0.03)
                end
            end
            if not found then table.insert(notFound, itemName) end
        end
        local targetLabel = includes(selectedTargets, "Campfire") and "Campfire" or "Player"
        if totalMoved > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Gear Collected", Content = string.format("Moved %d gear item(s) to %s", totalMoved, targetLabel), Time = 0.5, Delay = 4})
        end
        if #notFound > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Not Found", Content = table.concat(notFound, ", "), Time = 0.5, Delay = 5})
        end
    end
})

local chestSection = Tabs.Items:AddSection("Chest", false)

chestSection:AddToggle({
    Title = "Auto Open Chest",
    Default = _G.Settings.Main["Auto Open Chest"],
    Callback = function(value)
        _G.Settings.Main["Auto Open Chest"] = value
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

spawn(function()
    pcall(function()
        while true do
            task.wait(0.5)
            if _G.Settings.Main["Auto Open Chest"] then
                while _G.Settings.Main["Auto Open Chest"] do
                    local itemsFolder = workspace:FindFirstChild("Items")
                    if itemsFolder then
                        for _, chest in ipairs(itemsFolder:GetChildren()) do
                            if not _G.Settings.Main["Auto Open Chest"] then break end
                            if chest:IsA("Model") and string.find(chest.Name, "Chest") then
                                local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
                                if prompt then
                                    pcall(function()
                                        fireproximityprompt(prompt, 0)
                                    end)
                                    task.wait(0.1)
                                end
                            end
                        end
                    end
                    task.wait(0.5)
                end
            else
                task.wait(1)
            end
        end
    end)
end)

local allChestItems = {
    "Bandage", "Good Sack", "Good Axe", "Old Flashlight", "Spear", "Revolver", "Revolver Ammo",
    "Fuel Canister", "Flower Seeds", "Alien Armor", "Laser Sword", "Laser Cannon", "Ice Axe",
    "Snowball", "Ice Sword", "Frozen Shuriken", "Leather Body", "Berry Seeds", "Rifle", "Ammo",
    "Strong Flashlight", "Defensive Blueprint Spikes", "Iron Body", "Chili Seeds", "Oil Barrel",
    "Strong Axe", "Giant Sack", "Medkit", "Defensive Blueprint Bear Trap",
    "Defensive Blueprint Barbed Sore", "Cultist Gem", "Chainsaw", "Kunai", "Riot Shield",
    "Thorn Armor", "Tactical Shotgun", "Gem of the Forest Fragment"
}

local selectedChestItems = {}
chestSection:AddDropdown({
    Title = "Select Chest Items",
    Options = allChestItems,
    Default = nil,
    Multi = true,
    Callback = function(option)
        selectedChestItems = option or {}
    end,
})

chestSection:AddButton({
    Title = "Collect Chest Items",
    Callback = function()
        local char = player.Character or player.CharacterAdded:Wait()
        local h = char:WaitForChild("HumanoidRootPart")
        local itemsFolder = workspace:WaitForChild("Items")
        local totalMoved = 0
        local notFound = {}
        function includes(t, v) return t and table.find(t, v) ~= nil end
        local dest
        if includes(selectedTargets, "Campfire") then
            dest = CFrame.new(0, 8, 0)
        elseif includes(selectedTargets, "Player") then
            dest = h.CFrame
        else
            Library:SetNotification({Title = "ZuperMing", Description = "Target Missing", Content = "Choose a target first", Time = 0.5, Delay = 4})
            return
        end
        local MAX_ITEMS = 1000
        if not (selectedChestItems and #selectedChestItems > 0) then
            Library:SetNotification({Title = "ZuperMing", Description = "No Items", Content = "Choose items", Time = 0.5, Delay = 4})
            return
        end
        for _, itemName in ipairs(selectedChestItems) do
            if totalMoved >= MAX_ITEMS then break end
            local found = false
            for _, item in ipairs(itemsFolder:GetChildren()) do
                if totalMoved >= MAX_ITEMS then break end
                if item.Name == itemName then
                    found = true
                    if item:IsA("Model") then
                        pcall(function() item:PivotTo(dest) end)
                    elseif item:IsA("BasePart") then
                        item.CFrame = dest
                    else
                        local part = item:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local modelLike = part:FindFirstAncestorOfClass("Model")
                            if modelLike then
                                pcall(function() modelLike:PivotTo(dest) end)
                            else
                                part.CFrame = dest
                            end
                        end
                    end
                    totalMoved = totalMoved + 1
                    task.wait(0.03)
                    break
                end
            end
            if not found then table.insert(notFound, itemName) end
        end
        local targetLabel = includes(selectedTargets, "Campfire") and "Campfire" or "Player"
        if totalMoved > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Items Collected", Content = string.format("Moved %d item(s) to %s", totalMoved, targetLabel), Time = 0.5, Delay = 4})
        end
        if #notFound > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Not Found", Content = table.concat(notFound, ", "), Time = 0.5, Delay = 5})
        end
    end
})

local otherItemsSection = Tabs.Items:AddSection("Other Items", false)

local selectedOtherItems = {}
otherItemsSection:AddDropdown({
    Title = "Choose Other Items",
    Options = {"Sack", "Seed Box", "Chainsaw", "Old Flashlight", "Strong Flastlight", "Bunny Foot", "Wolf Pelt", "Bear Pelt", "Alpha Wolf Pet", "Artic Fox Pelt", "Polar Bear Pelt", "Mammoth Tusk"},
    Default = nil,
    Multi = true,
    Callback = function(option)
        selectedOtherItems = option or {}
    end,
})

otherItemsSection:AddButton({
    Title = "Collect Other Items",
    Callback = function()
        local char = player.Character or player.CharacterAdded:Wait()
        local h = char:WaitForChild("HumanoidRootPart")
        local itemsFolder = workspace:WaitForChild("Items")
        local totalMoved = 0
        local notFound = {}
        function includes(t, v) return t and table.find(t, v) ~= nil end
        local dest
        if includes(selectedTargets, "Campfire") then
            dest = CFrame.new(0, 8, 0)
        elseif includes(selectedTargets, "Player") then
            dest = h.CFrame
        else
            Library:SetNotification({Title = "ZuperMing", Description = "Target Missing", Content = "Choose a target first", Time = 0.5, Delay = 4})
            return
        end
        local MAX_ITEMS = 1000
        if not (selectedOtherItems and #selectedOtherItems > 0) then
            Library:SetNotification({Title = "ZuperMing", Description = "No Items", Content = "Choose other items", Time = 0.5, Delay = 4})
            return
        end
        for _, itemName in ipairs(selectedOtherItems) do
            if totalMoved >= MAX_ITEMS then break end
            local found = false
            for _, item in ipairs(itemsFolder:GetChildren()) do
                if totalMoved >= MAX_ITEMS then break end
                if item.Name == itemName then
                    found = true
                    if item:IsA("Model") then
                        pcall(function() item:PivotTo(dest) end)
                    elseif item:IsA("BasePart") then
                        item.CFrame = dest
                    else
                        local part = item:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local modelLike = part:FindFirstAncestorOfClass("Model")
                            if modelLike then
                                pcall(function() modelLike:PivotTo(dest) end)
                            else
                                part.CFrame = dest
                            end
                        end
                    end
                    totalMoved = totalMoved + 1
                    task.wait(0.03)
                end
            end
            if not found then table.insert(notFound, itemName) end
        end
        local targetLabel = includes(selectedTargets, "Campfire") and "Campfire" or "Player"
        if totalMoved > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Items Collected", Content = string.format("Moved %d item(s) to %s", totalMoved, targetLabel), Time = 0.5, Delay = 4})
        end
        if #notFound > 0 then
            Library:SetNotification({Title = "ZuperMing", Description = "Not Found", Content = table.concat(notFound, ", "), Time = 0.5, Delay = 5})
        end
    end
})

local espSection = Tabs.Esp:AddSection("Item ESP", false)

local itemList = {}
local selectedItemEsp = {}
function refreshItemList()
    itemList = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder then
        for _, item in ipairs(itemsFolder:GetChildren()) do
            if item:IsA("Model") and item.PrimaryPart and not table.find(itemList, item.Name) then
                table.insert(itemList, item.Name)
            end
        end
    end
    return itemList
end

local itemEspDropdown = espSection:AddDropdown({
    Title = "Select Items",
    Options = refreshItemList(),
    Default = nil,
    Multi = true,
    Callback = function(selected)
        selectedItemEsp = selected or {}
    end,
})

espSection:AddButton({
    Title = "Refresh Item List",
    Callback = function()
        itemEspDropdown:Refresh(refreshItemList(), nil)
    end
})

espSection:AddToggle({
    Title = "Enable Item ESP",
    Default = _G.Settings.Esp["Enable Item ESP"],
    Callback = function(v)
        _G.Settings.Esp["Enable Item ESP"] = v
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

function getColorForName(name)
    local hash = 0
    for i = 1, #name do
        hash = (hash + name:byte(i)) % 256
    end
    return Color3.fromHSV(hash / 256, 1, 1)
end

local espItems = {}
spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local itemsFolder = workspace:FindFirstChild("Items")
            local char = player.Character
            local hrpLocal = char and char:FindFirstChild("HumanoidRootPart")
            if not (_G.Settings.Esp["Enable Item ESP"] and selectedItemEsp and #selectedItemEsp > 0) then
                for item, obj in pairs(espItems) do
                    if obj.highlight then obj.highlight:Destroy() end
                    if obj.billboard then obj.billboard:Destroy() end
                    espItems[item] = nil
                end
                return
            end
            for _, item in ipairs(itemsFolder and itemsFolder:GetChildren() or {}) do
                if item:IsA("Model") and item.PrimaryPart then
                    local shouldESP = table.find(selectedItemEsp, item.Name)
                    if shouldESP then
                        local dist = hrpLocal and (hrpLocal.Position - item.PrimaryPart.Position).Magnitude
                        local name = item.Name
                        if not espItems[item] then
                            local highlight = Instance.new("Highlight")
                            highlight.FillColor = getColorForName(name)
                            highlight.OutlineColor = Color3.new(1, 1, 1)
                            highlight.FillTransparency = 0.5
                            highlight.OutlineTransparency = 0
                            highlight.Adornee = item
                            highlight.Parent = item
                            local billboard = Instance.new("BillboardGui")
                            billboard.Size = UDim2.new(0, 200, 0, 50)
                            billboard.AlwaysOnTop = true
                            billboard.Adornee = item.PrimaryPart
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.TextScaled = true
                            label.Font = Enum.Font.SourceSansBold
                            label.TextColor3 = highlight.FillColor
                            label.TextStrokeTransparency = 0.5
                            label.Parent = billboard
                            billboard.Parent = item
                            espItems[item] = {highlight = highlight, label = label, billboard = billboard}
                        end
                        if espItems[item] and espItems[item].label then
                            espItems[item].label.Text = name .. " | " .. (dist and string.format("%.1f", dist) or "?") .. "m"
                        end
                    else
                        if espItems[item] then
                            if espItems[item].highlight then espItems[item].highlight:Destroy() end
                            if espItems[item].billboard then espItems[item].billboard:Destroy() end
                            espItems[item] = nil
                        end
                    end
                end
            end
            for item, obj in pairs(espItems) do
                if not item or not item:IsDescendantOf(game) or not table.find(selectedItemEsp, item.Name) then
                    if obj.highlight then obj.highlight:Destroy() end
                    if obj.billboard then obj.billboard:Destroy() end
                    espItems[item] = nil
                end
            end
        end)
    end
end)

local enemyEspSection = Tabs.Esp:AddSection("Enemy ESP", false)

local enemyList = {}
local selectedEnemyEsp = {}

function refreshEnemyList()
    enemyList = {}
    local chars = workspace:FindFirstChild("Characters")
    if chars then
        for _, char in ipairs(chars:GetChildren()) do
            if char:IsA("Model") and char:FindFirstChildWhichIsA("Humanoid") and not table.find(enemyList, char.Name) then
                table.insert(enemyList, char.Name)
            end
        end
    end
    return enemyList
end

local enemyEspDropdown = enemyEspSection:AddDropdown({
    Title = "Select Enemies",
    Options = refreshEnemyList(),
    Default = nil,
    Multi = true,
    Callback = function(selected)
        selectedEnemyEsp = selected or {}
    end,
})

enemyEspSection:AddButton({
    Title = "Refresh Enemy List",
    Callback = function()
        enemyEspDropdown:Refresh(refreshEnemyList(), nil)
    end
})

enemyEspSection:AddToggle({
    Title = "Enable Enemy ESP",
    Default = _G.Settings.Esp["Enable Enemy ESP"],
    Callback = function(v)
        _G.Settings.Esp["Enable Enemy ESP"] = v
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

local espChars = {}

spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local chars = workspace:FindFirstChild("Characters")
            local char = player.Character
            local hrpLocal = char and char:FindFirstChild("HumanoidRootPart")
            if not (_G.Settings.Esp["Enable Enemy ESP"] and selectedEnemyEsp and #selectedEnemyEsp > 0) then
                for charObj, obj in pairs(espChars) do
                    if obj.highlight then obj.highlight:Destroy() end
                    if obj.billboard then obj.billboard:Destroy() end
                    espChars[charObj] = nil
                end
                return
            end
            for _, charObj in ipairs(chars and chars:GetChildren() or {}) do
                if charObj:IsA("Model") and charObj:FindFirstChildWhichIsA("Humanoid") then
                    local shouldESP = table.find(selectedEnemyEsp, charObj.Name)
                    if shouldESP then
                        local dist = hrpLocal and (hrpLocal.Position - charObj:GetPrimaryPartCFrame().Position).Magnitude
                        local name = charObj.Name
                        if not espChars[charObj] then
                            local highlight = Instance.new("Highlight")
                            highlight.FillColor = getColorForName(name)
                            highlight.OutlineColor = Color3.new(1, 1, 1)
                            highlight.FillTransparency = 0.5
                            highlight.OutlineTransparency = 0
                            highlight.Adornee = charObj
                            highlight.Parent = charObj
                            local billboard = Instance.new("BillboardGui")
                            billboard.Size = UDim2.new(0, 200, 0, 50)
                            billboard.AlwaysOnTop = true
                            billboard.Adornee = charObj:FindFirstChild("HumanoidRootPart") or charObj:FindFirstChild("Head") or charObj.PrimaryPart
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.TextScaled = true
                            label.Font = Enum.Font.SourceSansBold
                            label.TextColor3 = highlight.FillColor
                            label.TextStrokeTransparency = 0.5
                            label.Parent = billboard
                            billboard.Parent = charObj
                            espChars[charObj] = {highlight = highlight, label = label, billboard = billboard}
                        end
                        if espChars[charObj] and espChars[charObj].label then
                            espChars[charObj].label.Text = name .. " | " .. (dist and string.format("%.1f", dist) or "?") .. "m"
                        end
                    else
                        if espChars[charObj] then
                            if espChars[charObj].highlight then espChars[charObj].highlight:Destroy() end
                            if espChars[charObj].billboard then espChars[charObj].billboard:Destroy() end
                            espChars[charObj] = nil
                        end
                    end
                end
            end
            for charObj, obj in pairs(espChars) do
                if not charObj or not charObj:IsDescendantOf(game) or not table.find(selectedEnemyEsp, charObj.Name) then
                    if obj.highlight then obj.highlight:Destroy() end
                    if obj.billboard then obj.billboard:Destroy() end
                    espChars[charObj] = nil
                end
            end
        end)
    end
end)

local teleportSection = Tabs.Teleport:AddSection("Teleport", false)

teleportSection:AddButton({
    Title = "Teleport to Campground",
    Callback = function()
        local position = Vector3.new(0, 8, 0)
        local char = game.Players.LocalPlayer.Character
        if char then
            char:PivotTo(CFrame.new(position))
        end
    end
})

local itemNames = {
    "Revolver", "Medkit", "Alien Chest", "Berry", "Bolt", "Broken Fan",
    "Carrot", "Coal", "Coin Stack", "Hologram Emitter", "Item Chest",
    "Laser Fence Blueprint", "Log", "Old Flashlight", "Old Radio",
    "Sheet Metal", "Bandage", "Rifle"
}

_G.Settings.Teleport["Selected Item"] = _G.Settings.Teleport["Selected Item"] or itemNames[1]
teleportSection:AddDropdown({
    Title = "Teleport to Item",
    Options = itemNames,
    Default = _G.Settings.Teleport["Selected Item"],
    Multi = false,
    Callback = function(value)
        _G.Settings.Teleport["Selected Item"] = value
        if _G.Settings.AutoSave then SaveConfig() end
    end,
})

function getModelPart(model)
    if model.PrimaryPart then return model.PrimaryPart end
    for _, part in ipairs(model:GetChildren()) do
        if part:IsA("BasePart") then return part end
    end
    return nil
end

teleportSection:AddButton({
    Title = "Teleport to Selected Item",
    Callback = function()
        local selectedItem = _G.Settings.Teleport["Selected Item"]
        local candidates = {}
        local itemFolder = workspace:WaitForChild("Items")
        for _, model in ipairs(itemFolder:GetChildren()) do
            if model:IsA("Model") and model.Name == selectedItem then
                local part = getModelPart(model)
                if part then
                    table.insert(candidates, part)
                end
            end
        end
        if #candidates == 0 then return end
        local targetPart = candidates[math.random(1, #candidates)]
        local char = LocalPlayer.Character
        local h = char and char:FindFirstChild("HumanoidRootPart")
        if char and h then
            h.CFrame = targetPart.CFrame + Vector3.new(0, 5, 0)
        end
    end
})

teleportSection:AddButton({
    Title = "Teleport to Volcano",
    Callback = function()
        pcall(function()
            local volcano = workspace.Map and workspace.Map.Landmarks and workspace.Map.Landmarks:FindFirstChild("Volcano")
            if volcano and volcano:IsA("Model") then
                local char = LocalPlayer.Character
                local h = char and char:FindFirstChild("HumanoidRootPart")
                if char and h then
                    h.CFrame = volcano:GetPivot() + Vector3.new(0, 5, 0)
                end
            else
                Library:SetNotification({Title = "ZuperMing", Description = "Volcano not found", Content = "Volcano has not spawned yet", Time = 0.5, Delay = 4})
            end
        end)
    end
})

local miscSection = Tabs.Misc:AddSection("Misc", false)

miscSection:AddToggle({
    Title = "Auto Night Teleport",
    Default = _G.Settings.Misc["Night Teleport"],
    Callback = function(value)
        _G.Settings.Misc["Night Teleport"] = value
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

miscSection:AddToggle({
    Title = "Anti Void",
    Default = _G.Settings.Misc["Anti Void"],
    Callback = function(value)
        _G.Settings.Misc["Anti Void"] = value
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

spawn(function()
    while true do
        task.wait(0.3)
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local h = char.HumanoidRootPart
            local currentPos = h.Position
            local targetPos = Vector3.new(0, 8, 0)
            local distance = (currentPos - targetPos).Magnitude
            if _G.Settings.Misc["Anti Void"] and currentPos.Y < -5 and distance > 10 then
                h.CFrame = CFrame.new(targetPos)
            end
            if _G.Settings.Misc["Night Teleport"] then
                local currentTime = Lighting.ClockTime
                local isNightTime = currentTime < 6 or currentTime >= 18
                if isNightTime and distance > 10 then
                    h.CFrame = CFrame.new(targetPos)
                end
            end
        end
    end
end)

miscSection:AddSlider({
    Title = "Character Speed",
    Min = 16,
    Max = 200,
    Default = _G.Settings.Misc["Character Speed"],
    Callback = function(value)
        _G.Settings.Misc["Character Speed"] = value
        local char = game:GetService("Players").LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = value
            end
        end
    end
})

miscSection:AddToggle({
    Title = "Infinite Jump",
    Default = _G.Settings.Misc["Infinite Jump"],
    Callback = function(value)
        _G.Settings.Misc["Infinite Jump"] = value
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

if not _G.InfiniteJumpConnection then
    _G.InfiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
        if _G.Settings.Misc and _G.Settings.Misc["Infinite Jump"] then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end)
end

miscSection:AddToggle({
    Title = "Fly",
    Default = _G.Settings.Misc["Fly"],
    Callback = function(value)
        _G.Settings.Misc["Fly"] = value
        local speaker = game:GetService("Players").LocalPlayer
        local char = speaker.Character or speaker.CharacterAdded:Wait()
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if value then
            _G.nowe = true
            _G.tpwalking = false
            local speeds = _G.Settings.Misc["FlySpeed"] or 5
            char.Animate.Disabled = true
            for _, v in next, hum:GetPlayingAnimationTracks() do
                v:AdjustSpeed(0)
            end
            for _, state in pairs(Enum.HumanoidStateType:GetEnumItems()) do
                hum:SetStateEnabled(state, false)
            end
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Swimming)
            for i = 1, speeds do
                spawn(function()
                    local hb = game:GetService("RunService").Heartbeat
                    while _G.nowe and hb:Wait() and char and hum and hum.Parent do
                        if hum.MoveDirection.Magnitude > 0 then
                            char:TranslateBy(hum.MoveDirection)
                        end
                    end
                end)
            end
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            if root then
                if _G.FlyBV then _G.FlyBV:Destroy() end
                local bv = Instance.new("BodyVelocity", root)
                bv.Velocity = Vector3.new(0, 0.1, 0)
                bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                _G.FlyBV = bv
                spawn(function()
                    while _G.nowe and task.wait() and root and root.Parent do
                        local cam = workspace.CurrentCamera
                        local pos = root.Position
                        local dir = cam.CFrame.LookVector
                        root.CFrame = CFrame.new(pos, pos + dir)
                    end
                end)
            end
        else
            _G.nowe = false
            local char = speaker.Character
            local hum = char and char:FindFirstChildWhichIsA("Humanoid")
            if hum then
                for _, state in pairs(Enum.HumanoidStateType:GetEnumItems()) do
                    hum:SetStateEnabled(state, true)
                end
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
                char.Animate.Disabled = false
                task.wait(0.1)
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            if _G.FlyBV then
                _G.FlyBV:Destroy()
                _G.FlyBV = nil
            end
        end
    end
})

function setFogState(enabled)
    if enabled then
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6 - 1
        Lighting.Brightness = 5
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        Lighting.FogEnd = 1000
        Lighting.FogStart = 0
        Lighting.Brightness = 2
        Lighting.ClockTime = 12
        Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
        Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
    end
end

miscSection:AddToggle({
    Title = "Remove Fog",
    Default = _G.Settings.Misc["Remove Fog"],
    Callback = function(value)
        _G.Settings.Misc["Remove Fog"] = value
        setFogState(value)
    end
})

miscSection:AddButton({
    Title = "FPS Boost",
    Callback = function()
        local decalsyeeted = true
        local g = game
        local w = g.Workspace
        function optimizeObject(v)
            if v:IsA("Part") or v:IsA("Union") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") then
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
            elseif (v:IsA("Decal") or v:IsA("Texture")) and decalsyeeted then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = false
            elseif v:IsA("Explosion") then
                v.BlastPressure = 1
                v.BlastRadius = 1
            elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") then
                v.Enabled = false
            end
        end
        for _, v in pairs(g:GetDescendants()) do
            optimizeObject(v)
        end
        spawn(function()
            w.DescendantAdded:Connect(function(newObj)
                optimizeObject(newObj)
                if newObj:IsA("Model") or newObj:IsA("Folder") then
                    for _, child in ipairs(newObj:GetDescendants()) do
                        optimizeObject(child)
                    end
                end
            end)
        end)
    end
})

local questSection = Tabs.Quest:AddSection("Announcement", false)

questSection:AddParagraph({
    Title = "Notice",
    Content = "Equip weapon to enable quest features."
})

-- Quest fly helpers using dynamic humanoid
local function getQuestHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getQuestHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local bodyVelocity = Instance.new("BodyVelocity")
local bodyGyro = Instance.new("BodyGyro")
local flySpeed = 50
bodyVelocity.Velocity = Vector3.new(0, 0, 0)
bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
bodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)

function flyQuest()
    local h = getQuestHRP()
    local hum = getQuestHumanoid()
    if not h or not hum then return nil end
    bodyVelocity.Parent = h
    bodyGyro.Parent = h
    hum.PlatformStand = true
    local hoverConnection
    hoverConnection = RunService.Heartbeat:Connect(function()
        bodyGyro.CFrame = workspace.CurrentCamera.CFrame
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end)
    return hoverConnection
end

function unflyQuest(hoverConnection)
    local h = getQuestHRP()
    local hum = getQuestHumanoid()
    if hoverConnection then hoverConnection:Disconnect() end
    bodyVelocity.Parent = nil
    bodyGyro.Parent = nil
    if hum then
        hum.PlatformStand = false
    end
end

local lost1Section = Tabs.Quest:AddSection("Lost Child 1", false)

local jailCellar1Paragraph = lost1Section:AddParagraph({
    Title = "Jail Cellar 1 Status",
    Content = "Status: Waiting..."
})

spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local jailCellar = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Landmarks") and workspace.Map.Landmarks:FindFirstChild("Jail Cellar1")
            if jailCellar then
                jailCellar1Paragraph:SetContent("Status: Spawned ✅")
            else
                jailCellar1Paragraph:SetContent("Status: Not Spawned ❌")
            end
        end)
    end
end)

lost1Section:AddToggle({
    Title = "Auto Lost Child 1",
    Content = "Requires Campfire Level 2",
    Default = _G.Settings.Quest["Auto Lost Child Quest"],
    Callback = function(value)
        _G.Settings.Quest["Auto Lost Child Quest"] = value
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

spawn(function()
    pcall(function()
        local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
        local sackNames = {["Old Sack"] = true, ["Good Sack"] = true, ["Giant Sack"] = true}
        while true do
            task.wait(1)
            if _G.Settings.Quest["Auto Lost Child Quest"] then
                local hover = flyQuest()
                local jailCellar
                local foliage = Workspace:WaitForChild("Map"):WaitForChild("Foliage")
                local visitedTrees = {}
                while not jailCellar and _G.Settings.Quest["Auto Lost Child Quest"] do
                    for _, tree in pairs(foliage:GetChildren()) do
                        if not _G.Settings.Quest["Auto Lost Child Quest"] then
                            unflyQuest(hover)
                            break
                        end
                        if tree:IsA("Model") and (tree.Name == "TreeBig1" or tree.Name == "TreeBig2") and not visitedTrees[tree] then
                            visitedTrees[tree] = true
                            local root = getQuestHRP()
                            local base = tree:FindFirstChildWhichIsA("BasePart")
                            if root and base then
                                root.CFrame = base.CFrame + Vector3.new(0, 3, 0)
                            end
                            task.wait(1)
                            jailCellar = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Landmarks") and Workspace.Map.Landmarks:FindFirstChild("Jail Cellar1")
                            if jailCellar then break end
                        end
                    end
                    task.wait(1)
                end
                if jailCellar then
                    local jailCellarObj = Workspace.Map.Landmarks:WaitForChild("Jail Cellar1")
                    local keyInteraction = jailCellarObj.LockedDoor:WaitForChild("KeyInteraction")
                    local root = getQuestHRP()
                    if root then
                        root.CFrame = keyInteraction.CFrame + Vector3.new(0, 25, 0)
                    end
                    task.wait(5)
                    local redKey
                    repeat
                        redKey = Workspace.Items:FindFirstChild("Red Key")
                        task.wait(0.5)
                    until redKey
                    pcall(function()
                        RemoteEvents.RequestStartDraggingItem:FireServer(redKey)
                    end)
                    if redKey.PrimaryPart then
                        redKey.PrimaryPart.CFrame = keyInteraction.CFrame
                    end
                    pcall(function()
                        RemoteEvents.ToggleDoor:FireServer("FireAllClients", jailCellarObj.LockedDoor, true)
                    end)
                    task.wait(0.3)
                    pcall(function()
                        RemoteEvents.ToggleDoor:FireServer("FireAllClients", jailCellarObj.Door, true)
                    end)
                    task.wait(0.3)
                    local inventory = player:WaitForChild("Inventory")
                    local sackItem
                    for _, item in ipairs(inventory:GetChildren()) do
                        if sackNames[item.Name] then
                            sackItem = item
                            break
                        end
                    end
                    local lostChild = Workspace.Characters:FindFirstChild("Lost Child")
                    if lostChild and sackItem then
                        local h = getQuestHRP()
                        local rightArm = lostChild:FindFirstChild("Right Arm") or lostChild.PrimaryPart
                        if h and rightArm then
                            h.CFrame = rightArm.CFrame
                            task.wait(0.2)
                            pcall(function()
                                RemoteEvents.RequestBagStoreItem:InvokeServer(sackItem, lostChild)
                            end)
                            task.wait(0.2)
                            h.CFrame = CFrame.new(0, 8, 0)
                            task.wait(0.2)
                            pcall(function()
                                RemoteEvents.EquipItemHandle:FireServer("FireAllClients", sackItem)
                            end)
                            task.wait(0.3)
                            pcall(function()
                                RemoteEvents.RequestBagDropItem:FireServer(sackItem, lostChild)
                            end)
                            unflyQuest(hover)
                        end
                    end
                end
                repeat task.wait(1) until not _G.Settings.Quest["Auto Lost Child Quest"]
                unflyQuest(hover)
            end
        end
    end)
end)

local lost2Section = Tabs.Quest:AddSection("Lost Child 2", false)

local jailCellar2Paragraph = lost2Section:AddParagraph({
    Title = "Jail Cellar 2 Status",
    Content = "Status: Waiting..."
})

spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local jailCellar2 = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Landmarks") and workspace.Map.Landmarks:FindFirstChild("Jail Cellar2")
            if jailCellar2 then
                jailCellar2Paragraph:SetContent("Status: Spawned ✅")
            else
                jailCellar2Paragraph:SetContent("Status: Not Spawned ❌")
            end
        end)
    end
end)

lost2Section:AddToggle({
    Title = "Auto Lost Child 2",
    Content = "Requires Campfire Level 4",
    Default = _G.Settings.Quest["Auto Lost Child2 Quest"],
    Callback = function(value)
        _G.Settings.Quest["Auto Lost Child2 Quest"] = value
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

spawn(function()
    pcall(function()
        local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
        local sackNames = {["Old Sack"] = true, ["Good Sack"] = true, ["Giant Sack"] = true}
        while true do
            task.wait(0.2)
            if _G.Settings.Quest["Auto Lost Child2 Quest"] then
                local hover = flyQuest()
                local jailCellar
                local foliage = Workspace:WaitForChild("Map"):WaitForChild("Foliage")
                local visitedTrees = {}
                while not jailCellar and _G.Settings.Quest["Auto Lost Child2 Quest"] do
                    for _, tree in pairs(foliage:GetChildren()) do
                        if not _G.Settings.Quest["Auto Lost Child2 Quest"] then
                            unflyQuest(hover)
                            break
                        end
                        if tree:IsA("Model") and (tree.Name == "TreeBig1" or tree.Name == "TreeBig2") and not visitedTrees[tree] then
                            visitedTrees[tree] = true
                            local root = getQuestHRP()
                            local base = tree:FindFirstChildWhichIsA("BasePart")
                            if root and base then
                                root.CFrame = base.CFrame + Vector3.new(0, 3, 0)
                            end
                            task.wait(1)
                            jailCellar = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Landmarks") and Workspace.Map.Landmarks:FindFirstChild("Jail Cellar2")
                            if jailCellar then break end
                        end
                    end
                    task.wait(1)
                end
                if jailCellar then
                    local jailCellarObj = Workspace.Map.Landmarks:WaitForChild("Jail Cellar2")
                    local keyInteraction = jailCellarObj.LockedDoor:WaitForChild("KeyInteraction")
                    local root = getQuestHRP()
                    if root then
                        root.CFrame = keyInteraction.CFrame + Vector3.new(0, 25, 0)
                    end
                    task.wait(5)
                    local blueKey
                    repeat
                        blueKey = Workspace.Items:FindFirstChild("Blue Key")
                        task.wait(0.5)
                    until blueKey
                    pcall(function()
                        RemoteEvents.RequestStartDraggingItem:FireServer(blueKey)
                    end)
                    if blueKey.PrimaryPart then
                        blueKey.PrimaryPart.CFrame = keyInteraction.CFrame
                    end
                    pcall(function()
                        RemoteEvents.ToggleDoor:FireServer("FireAllClients", jailCellarObj.LockedDoor, true)
                    end)
                    task.wait(0.3)
                    pcall(function()
                        RemoteEvents.ToggleDoor:FireServer("FireAllClients", jailCellarObj.Door, true)
                    end)
                    task.wait(0.3)
                    local inventory = player:WaitForChild("Inventory")
                    local sackItem
                    for _, item in ipairs(inventory:GetChildren()) do
                        if sackNames[item.Name] then
                            sackItem = item
                            break
                        end
                    end
                    local lostChild2 = Workspace.Characters:FindFirstChild("Lost Child2")
                    if lostChild2 and sackItem then
                        local h = getQuestHRP()
                        local rightArm = lostChild2:FindFirstChild("Right Arm") or lostChild2.PrimaryPart
                        if h and rightArm then
                            h.CFrame = rightArm.CFrame
                            task.wait(0.2)
                            pcall(function()
                                RemoteEvents.RequestBagStoreItem:InvokeServer(sackItem, lostChild2)
                            end)
                            task.wait(0.2)
                            h.CFrame = CFrame.new(0, 8, 0)
                            task.wait(0.2)
                            pcall(function()
                                RemoteEvents.EquipItemHandle:FireServer("FireAllClients", sackItem)
                            end)
                            task.wait(0.3)
                            pcall(function()
                                RemoteEvents.RequestBagDropItem:FireServer(sackItem, lostChild2)
                            end)
                            unflyQuest(hover)
                        end
                    end
                end
                repeat task.wait(0.2) until not _G.Settings.Quest["Auto Lost Child2 Quest"]
                unflyQuest(hover)
            end
        end
    end)
end)

local lost3Section = Tabs.Quest:AddSection("Lost Child 3", false)

local jailCellar3Paragraph = lost3Section:AddParagraph({
    Title = "Jail Cellar 3 Status",
    Content = "Status: Waiting..."
})

spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local jailCellar3 = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Landmarks") and workspace.Map.Landmarks:FindFirstChild("Jail Cellar3")
            if jailCellar3 then
                jailCellar3Paragraph:SetContent("Status: Spawned ✅")
            else
                jailCellar3Paragraph:SetContent("Status: Not Spawned ❌")
            end
        end)
    end
end)

lost3Section:AddToggle({
    Title = "Auto Lost Child 3",
    Content = "Requires Campfire Level 5",
    Default = _G.Settings.Quest["Auto Lost Child3 Quest"],
    Callback = function(value)
        _G.Settings.Quest["Auto Lost Child3 Quest"] = value
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

spawn(function()
    pcall(function()
        local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
        local sackNames = {["Old Sack"] = true, ["Good Sack"] = true, ["Giant Sack"] = true}
        while true do
            task.wait(0.2)
            if _G.Settings.Quest["Auto Lost Child3 Quest"] then
                local hover = flyQuest()
                local jailCellar
                local foliage = Workspace:WaitForChild("Map"):WaitForChild("Foliage")
                local visitedTrees = {}
                while not jailCellar and _G.Settings.Quest["Auto Lost Child3 Quest"] do
                    for _, tree in pairs(foliage:GetChildren()) do
                        if not _G.Settings.Quest["Auto Lost Child3 Quest"] then
                            unflyQuest(hover)
                            break
                        end
                        if tree:IsA("Model") and (tree.Name == "TreeBig1" or tree.Name == "TreeBig2") and not visitedTrees[tree] then
                            visitedTrees[tree] = true
                            local root = getQuestHRP()
                            local base = tree:FindFirstChildWhichIsA("BasePart")
                            if root and base then
                                root.CFrame = base.CFrame + Vector3.new(0, 3, 0)
                            end
                            task.wait(1)
                            jailCellar = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Landmarks") and Workspace.Map.Landmarks:FindFirstChild("Jail Cellar3")
                            if jailCellar then break end
                        end
                    end
                    task.wait(1)
                end
                if jailCellar then
                    local jailCellarObj = Workspace.Map.Landmarks:WaitForChild("Jail Cellar3")
                    local keyInteraction = jailCellarObj.LockedDoor:WaitForChild("KeyInteraction")
                    local root = getQuestHRP()
                    if root then
                        root.CFrame = keyInteraction.CFrame + Vector3.new(0, 25, 0)
                    end
                    task.wait(5)
                    local keyItem
                    repeat
                        keyItem = nil
                        for _, item in ipairs(Workspace.Items:GetChildren()) do
                            if item:IsA("Model") and item.Name:find("Key") then
                                keyItem = item
                                break
                            end
                        end
                        task.wait(0.5)
                    until keyItem
                    pcall(function()
                        RemoteEvents.RequestStartDraggingItem:FireServer(keyItem)
                    end)
                    if keyItem.PrimaryPart then
                        keyItem.PrimaryPart.CFrame = keyInteraction.CFrame
                    end
                    pcall(function()
                        RemoteEvents.ToggleDoor:FireServer("FireAllClients", jailCellarObj.LockedDoor, true)
                    end)
                    task.wait(0.3)
                    pcall(function()
                        RemoteEvents.ToggleDoor:FireServer("FireAllClients", jailCellarObj.Door, true)
                    end)
                    task.wait(0.3)
                    local inventory = player:WaitForChild("Inventory")
                    local sackItem
                    for _, item in ipairs(inventory:GetChildren()) do
                        if sackNames[item.Name] then
                            sackItem = item
                            break
                        end
                    end
                    local lostChild3 = Workspace.Characters:FindFirstChild("Lost Child3")
                    if lostChild3 and sackItem then
                        local h = getQuestHRP()
                        local rightArm = lostChild3:FindFirstChild("Right Arm") or lostChild3.PrimaryPart
                        if h and rightArm then
                            h.CFrame = rightArm.CFrame
                            task.wait(0.2)
                            pcall(function()
                                RemoteEvents.RequestBagStoreItem:InvokeServer(sackItem, lostChild3)
                            end)
                            task.wait(0.2)
                            h.CFrame = CFrame.new(0, 8, 0)
                            task.wait(0.2)
                            pcall(function()
                                RemoteEvents.EquipItemHandle:FireServer("FireAllClients", sackItem)
                            end)
                            task.wait(0.3)
                            pcall(function()
                                RemoteEvents.RequestBagDropItem:FireServer(sackItem, lostChild3)
                            end)
                            unflyQuest(hover)
                        end
                    end
                end
                repeat task.wait(0.2) until not _G.Settings.Quest["Auto Lost Child3 Quest"]
                unflyQuest(hover)
            end
        end
    end)
end)

local lost4Section = Tabs.Quest:AddSection("Lost Child 4", false)

local jailCellar4Paragraph = lost4Section:AddParagraph({
    Title = "Jail Cellar 4 Status",
    Content = "Status: Waiting..."
})

spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local jailCellar4 = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Landmarks") and workspace.Map.Landmarks:FindFirstChild("Jail Cellar4")
            if jailCellar4 then
                jailCellar4Paragraph:SetContent("Status: Spawned ✅")
            else
                jailCellar4Paragraph:SetContent("Status: Not Spawned ❌")
            end
        end)
    end
end)

lost4Section:AddToggle({
    Title = "Auto Lost Child 4",
    Content = "Requires Campfire Level 5",
    Default = _G.Settings.Quest["Auto Lost Child4 Quest"],
    Callback = function(value)
        _G.Settings.Quest["Auto Lost Child4 Quest"] = value
        if _G.Settings.AutoSave then SaveConfig() end
    end
})

spawn(function()
    pcall(function()
        local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
        local sackNames = {["Old Sack"] = true, ["Good Sack"] = true, ["Giant Sack"] = true}
        while true do
            task.wait(0.2)
            if _G.Settings.Quest["Auto Lost Child4 Quest"] then
                local hover = flyQuest()
                local jailCellar
                local foliage = Workspace:WaitForChild("Map"):WaitForChild("Foliage")
                local visitedTrees = {}
                while not jailCellar and _G.Settings.Quest["Auto Lost Child4 Quest"] do
                    for _, tree in pairs(foliage:GetChildren()) do
                        if not _G.Settings.Quest["Auto Lost Child4 Quest"] then
                            unflyQuest(hover)
                            break
                        end
                        if tree:IsA("Model") and (tree.Name == "TreeBig1" or tree.Name == "TreeBig2") and not visitedTrees[tree] then
                            visitedTrees[tree] = true
                            local root = getQuestHRP()
                            local base = tree:FindFirstChildWhichIsA("BasePart")
                            if root and base then
                                root.CFrame = base.CFrame + Vector3.new(0, 3, 0)
                            end
                            task.wait(1)
                            jailCellar = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Landmarks") and Workspace.Map.Landmarks:FindFirstChild("Jail Cellar4")
                            if jailCellar then break end
                        end
                    end
                    task.wait(1)
                end
                if jailCellar then
                    local jailCellarObj = Workspace.Map.Landmarks:WaitForChild("Jail Cellar4")
                    local keyInteraction = jailCellarObj.LockedDoor:WaitForChild("KeyInteraction")
                    local root = getQuestHRP()
                    if root then
                        root.CFrame = keyInteraction.CFrame + Vector3.new(0, 25, 0)
                    end
                    task.wait(5)
                    local keyItem
                    repeat
                        keyItem = nil
                        for _, item in ipairs(Workspace.Items:GetChildren()) do
                            if item:IsA("Model") and item.Name:find("Key") then
                                keyItem = item
                                break
                            end
                        end
                        task.wait(0.5)
                    until keyItem
                    pcall(function()
                        RemoteEvents.RequestStartDraggingItem:FireServer(keyItem)
                    end)
                    if keyItem.PrimaryPart then
                        keyItem.PrimaryPart.CFrame = keyInteraction.CFrame
                    end
                    pcall(function()
                        RemoteEvents.ToggleDoor:FireServer("FireAllClients", jailCellarObj.LockedDoor, true)
                    end)
                    task.wait(0.3)
                    pcall(function()
                        RemoteEvents.ToggleDoor:FireServer("FireAllClients", jailCellarObj.Door, true)
                    end)
                    task.wait(0.3)
                    local inventory = player:WaitForChild("Inventory")
                    local sackItem
                    for _, item in ipairs(inventory:GetChildren()) do
                        if sackNames[item.Name] then
                            sackItem = item
                            break
                        end
                    end
                    local lostChild4 = Workspace.Characters:FindFirstChild("Lost Child4")
                    if lostChild4 and sackItem then
                        local h = getQuestHRP()
                        local rightArm = lostChild4:FindFirstChild("Right Arm") or lostChild4.PrimaryPart
                        if h and rightArm then
                            h.CFrame = rightArm.CFrame
                            task.wait(0.2)
                            pcall(function()
                                RemoteEvents.RequestBagStoreItem:InvokeServer(sackItem, lostChild4)
                            end)
                            task.wait(0.2)
                            h.CFrame = CFrame.new(0, 8, 0)
                            task.wait(0.2)
                            pcall(function()
                                RemoteEvents.EquipItemHandle:FireServer("FireAllClients", sackItem)
                            end)
                            task.wait(0.3)
                            pcall(function()
                                RemoteEvents.RequestBagDropItem:FireServer(sackItem, lostChild4)
                            end)
                            unflyQuest(hover)
                        end
                    end
                end
                repeat task.wait(0.2) until not _G.Settings.Quest["Auto Lost Child4 Quest"]
                unflyQuest(hover)
            end
        end
    end)
end)
