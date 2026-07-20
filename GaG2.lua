-- Zuperming | GAG2

-- [1] GUARD & SERVICES

if getgenv().Zuperming_Running then
	warn("Script already running!")
	return
end
getgenv().Zuperming_Running = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Collection = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local Teleport = game:GetService("TeleportService")
local Http = game:GetService("HttpService")
local Marketplace = game:GetService("MarketplaceService")

local LP = Players.LocalPlayer

-- [2] TROVE (Cleanup System)

local Trove = {}
Trove.__index = Trove

function Trove.new()
	return setmetatable({ _items = {} }, Trove)
end

function Trove:Add(item)
	table.insert(self._items, item)
	return item
end

function Trove:AddConnection(conn)
	table.insert(self._items, { _t = "conn", _o = conn })
	return conn
end

function Trove:AddThread(thread)
	table.insert(self._items, { _t = "thread", _o = thread })
	return thread
end

function Trove:Clean()
	for _, item in ipairs(self._items) do
		if type(item) == "table" then
			if item._t == "conn" then
				pcall(function()
					item._o:Disconnect()
				end)
			elseif item._t == "thread" then
				pcall(function()
					task.cancel(item._o)
				end)
			elseif type(item.Destroy) == "function" then
				pcall(function()
					item:Destroy()
				end)
			elseif type(item.Disconnect) == "function" then
				pcall(function()
					item:Disconnect()
				end)
			end
		end
	end
	table.clear(self._items)
end

local GlobalTrove = Trove.new()
local FeatureTroves = {}

local function getTrove(name)
	if not FeatureTroves[name] then
		FeatureTroves[name] = Trove.new()
	end
	return FeatureTroves[name]
end

local function stopFeature(name)
	if FeatureTroves[name] then
		FeatureTroves[name]:Clean()
		FeatureTroves[name] = nil
	end
end

-- [3] MODULES CACHE

local SM = RS:WaitForChild("SharedModules")
local Modules = {}

Modules.Networking = require(SM:WaitForChild("Networking"))
Modules.SeedData = require(SM:WaitForChild("SeedData"))
Modules.MutationData = require(SM:WaitForChild("MutationData"))
Modules.SellValueData = require(SM:WaitForChild("SellValueData"))
Modules.WeightFormat = require(SM:WaitForChild("WeightFormat"))
Modules.FruitValue = require(SM:WaitForChild("FruitValueCalc"))
Modules.SellFlags = require(SM:WaitForChild("Flags"):WaitForChild("SellFlags"))
Modules.PetData = (function()
	local ok, r = pcall(require, RS:WaitForChild("SharedData"):WaitForChild("PetData"))
	return ok and r or {}
end)()

-- [4] CONSTANTS & LOOKUP TABLES

local Const = {}

Const.MutationList = {
	"None",
	"Gold",
	"Rainbow",
	"Electric",
	"Frozen",
	"Bloodlit",
	"Chained",
	"Starstruck",
	"Pizza",
	"Solarflare",
	"Aurora",
}

Const.RarityList = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Super" }

Const.RarityColors = {
	Common = Color3.fromRGB(170, 170, 170),
	Uncommon = Color3.fromRGB(40, 200, 40),
	Rare = Color3.fromRGB(60, 130, 240),
	Epic = Color3.fromRGB(170, 80, 230),
	Legendary = Color3.fromRGB(245, 200, 60),
	Mythic = Color3.fromRGB(220, 50, 50),
	Super = Color3.fromRGB(255, 100, 255),
}

Const.MutationColors = {
	Gold = Color3.fromRGB(255, 215, 0),
	Rainbow = Color3.fromRGB(255, 50, 255),
	Frozen = Color3.fromRGB(0, 255, 255),
	Electric = Color3.fromRGB(255, 255, 0),
	Bloodlit = Color3.fromRGB(255, 0, 0),
	Chained = Color3.fromRGB(150, 150, 150),
	Starstruck = Color3.fromRGB(255, 255, 150),
	None = Color3.fromRGB(50, 255, 50),
}

-- Build seed list once
Const.SeedList = {}
Const.SeedRarity = {}
Const.SingleHarvest = {}
Const.SeedValues = {}

for _, data in ipairs(Modules.SeedData) do
	if data.SeedName then
		table.insert(Const.SeedList, data.SeedName)
		if data.Rarity then
			Const.SeedRarity[data.SeedName] = data.Rarity
		end
		if data.IsSingleHarvest then
			Const.SingleHarvest[data.SeedName] = true
		end
		if data.PurchasePrice then
			Const.SeedValues[data.SeedName] = data.PurchasePrice
		end
	end
end
table.sort(Const.SeedList)

-- Build mutation multipliers once
Const.MutationMultipliers = {}
local mutDataMod = SM:FindFirstChild("MutationData")
if mutDataMod then
	for _, child in ipairs(mutDataMod:GetChildren()) do
		if child:IsA("ModuleScript") then
			pcall(function()
				local data = require(child)
				if data and data.PriceMultiplier then
					Const.MutationMultipliers[child.Name] = data.PriceMultiplier
				end
			end)
		end
	end
end

-- Build pet list once
Const.PetNames = {}
for name, data in pairs(Modules.PetData) do
	if type(data) == "table" then
		table.insert(Const.PetNames, name)
	end
end
table.sort(Const.PetNames)

-- Crate list
Const.CrateList = {}
local cratesAsset = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Crates")
if cratesAsset then
	for _, c in ipairs(cratesAsset:GetChildren()) do
		table.insert(Const.CrateList, c.Name)
	end
	table.sort(Const.CrateList)
end

-- Weather list
Const.WeatherList = {
	"None",
	"Rain",
	"Lightning",
	"Rainbow",
	"Snowfall",
	"Starfall",
	"Bloodmoon",
	"Blizzard",
}

-- [5] STATE

local State = {
	-- Movement
	moveMethod = "Semi-Tween",
	interactMethod = "Hold Proximity",

	-- Anti-AFK
	antiAFK = true,

	-- God Mode
	godMode = false,

	-- Harvest
	autoHarvest = false,
	targetHarvest = { "All" },
	targetHarvestMut = { "Any" },
	pauseHarvestWeather = { "None" },
	minHarvestKg = 0,
	maxHarvestKg = 9999,
	harvestCheckFull = false,
	harvestMaxCap = 100,

	-- Plant
	autoPlant = false,
	targetPlant = { "All" },
	targetPlantMut = { "Any" },
	gridSpacing = 1.5,
	plantLimit = 0,
	plantMode = "Smart Grid",

	-- Shovel
	autoShovel = false,
	shovelDead = false,
	targetShovel = { "All" },
	targetShovelMut = { "Any" },

	-- Sell
	autoSell = false,
	autoSellFull = false,
	autoSellTimer = false,
	targetSell = { "All" },
	targetSellMut = { "Any" },
	sellInterval = 60,
	autoBargain = false,

	-- Buy
	autoBuySeed = false,
	targetBuySeed = {},
	autoBuyGear = false,
	targetBuyGear = {},
	autoBuyCrate = false,
	targetBuyCrate = {},
	crateAmount = 1,

	-- Gacha
	autoOpenPacks = false,
	autoOpenCrates = false,
	autoOpenEggs = false,
	autoExpand = false,
	autoBuyPetSlot = false,

	-- Water
	autoWater = false,
	waterCan = "Common Watering Can",
	waterPlant = { "All" },
	waterMut = { "Any" },

	-- Sprinkler
	autoSprinkler = false,
	sprinklerType = "Common Sprinkler",
	sprinklerSpacing = 8,

	-- Collect
	autoCollect = false,
	collectMode = "Collect All",
	collectTargets = { "Gold", "Rainbow" },
	collectDelay = 4,

	-- Steal
	autoSteal = false,
	stealTarget = "Anyone",
	stealMode = "Highest Value",
	stealMinValue = 0,
	stealReturnLimit = 50,
	antiSteal = false,
	autoRejoin = false,
	savedGardenCF = nil,
	targetSteal = { "All" },
	targetStealMut = { "Any" },

	-- Pets
	autoTameByName = false,
	autoTameByRarity = false,
	targetTame = { "All Pets" },
	targetRarity = { "Any" },
	petAutoReturn = false,

	-- Misc
	isFrozen = false,
	flingEnabled = false,
	autoSkip = true,
	godMode = false,

	-- ESP
	espPlayers = false,
	espPlants = false,
	espPets = false,
	espShowName = true,
	espShowMut = true,
	espShowKg = true,
	espShowVal = true,

	-- Mail & Gift
	autoClaimMail = false,
	autoAcceptGift = false,
	autoGift = false,
	giftTarget = "",

	-- Favorite
	autoFav = false,
	autoUnfav = false,
	targetFavFruits = { "All" },

	-- Gamble
	autoGamble = false,
	gambleTarget = 2,
	gambleWaitFull = false,
	gambleWaitFullCount = 100,

	-- Bargain
	bargainWaitFull = false,
	bargainWaitFullCount = 100,

	-- Auction
	autoAuction = false,
	auctionBuyMode = "Lowest Only",
	auctionMaxPrice = 0,
	auctionMinCount = 1,
	auctionCheckStock = true,
	auctionCategories = {},
	auctionSelectedSeeds = {},
	auctionSelectedCrates = {},
	auctionSelectedEggs = {},
	auctionSelectedSeedPacks = {},
	auctionSelectedGears = {},

	-- Visual & Utility
	walkSpeedEnabled = false,
	walkSpeed = 16,
	instantPrompt = false,
	lowGraphic = false,
	noParticles = false,
	hidePlants = false,
	
	-- Webhook
	webhookEnabled = false,
	webhookUrl = "",
	webhookInterval = 60,

	-- Weather predictor
	showWeather = true,
	showGardenVal = false,
	showInvVal = false,

	-- Farm Tools
	autoTrowel = false,
}

-- [6] CACHE

local Cache = {
	plot = nil,
	plotId = nil,
	char = nil,
	hrp = nil,
	hum = nil,
	sellTimer = 0,
	stealInProgress = false,
	collectActive = false,
	collectIdle = 0,
	favProcessed = {},
	-- Sell price cache
	fruitPrices = {},
	invTotal = 0,
	gardenTotal = 0,
	plantCount = 0,
	auctionLots = {},
	auctionStock = {},
	auctionPurchaseDebounce = {},
	auctionCooldowns = {},
	auctionListenersReady = false,
	webhookTimer = 0,
}

-- [7] UTILS

local Utils = {}

function Utils.getPlot()
	local id = LP:GetAttribute("PlotId")
	if id ~= Cache.plotId then
		Cache.plotId = id
		local gardens = workspace:FindFirstChild("Gardens")
		Cache.plot = id and gardens and gardens:FindFirstChild("Plot" .. tostring(id)) or nil
	end
	return Cache.plot
end

function Utils.getChar()
	Cache.char = LP.Character
	Cache.hrp = Cache.char and Cache.char:FindFirstChild("HumanoidRootPart")
	Cache.hum = Cache.char and Cache.char:FindFirstChildOfClass("Humanoid")
	return Cache.char, Cache.hrp, Cache.hum
end

local SUFFIXES = { "", "k", "m", "b", "t", "q" }
function Utils.abbreviate(num)
	if type(num) ~= "number" or num ~= num then
		return "0"
	end
	if num >= 1000 then
		local idx = math.min(math.floor(math.log10(math.floor(num)) / 3) + 1, #SUFFIXES)
		local val = math.floor(num / (10 ^ ((idx - 1) * 3)) * 10) / 10
		return string.format("%g", val) .. SUFFIXES[idx]
	end
	return tostring(math.floor(num))
end

function Utils.getServerNow()
	local ts = game:GetService("Workspace"):GetServerTimeNow()
	return ts
end

function Utils.auctionCurrentPrice(lot)
	if Modules.Networking.Auctioneer and Modules.Networking.Auctioneer.CurrentPrice then
		return Modules.Networking.Auctioneer.CurrentPrice(lot, Utils.getServerNow())
	end
	return lot.startPrice or 0
end

local AUCTION_CATEGORY_MAP = {
	Seeds = "Seeds",
	Fruits = "Fruits",
	HarvestedFruits = "Fruits",
	Crates = "Crates",
	Eggs = "Eggs",
	SeedPacks = "SeedPacks",
	Gear = "Gear"
}

function Utils.auctionCategoryOf(lot)
	return AUCTION_CATEGORY_MAP[lot.category] or lot.category or "Unknown"
end

function Utils.auctionPassesFilter(lot)
	local cat = Utils.auctionCategoryOf(lot)
	if next(State.auctionCategories) then
		if not State.auctionCategories[cat] then return false end
	end
	local selectedItems = nil
	if cat == "Seeds" then selectedItems = State.auctionSelectedSeeds
	elseif cat == "Crates" then selectedItems = State.auctionSelectedCrates
	elseif cat == "Eggs" then selectedItems = State.auctionSelectedEggs
	elseif cat == "SeedPacks" then selectedItems = State.auctionSelectedSeedPacks
	elseif cat == "Gear" then selectedItems = State.auctionSelectedGears
	end
	if selectedItems and next(selectedItems) and not table.find(selectedItems, lot.item) then
		return false
	end
	return true
end

-- [8] FEATURES
function Utils.isMatch(itemName, itemMut, targetNames, targetMuts)
	-- Name check
	local nameOk = false
	if table.find(targetNames, "All") or table.find(targetNames, "All Pets") then
		nameOk = true
	else
		for _, n in ipairs(targetNames) do
			if string.lower(n) == string.lower(itemName or "") then
				nameOk = true
				break
			end
		end
	end
	if not nameOk then
		return false
	end

	-- Mutation check
	if table.find(targetMuts, "Any") then
		return true
	end
	local actualMut = (not itemMut or itemMut == "" or itemMut == "None") and "None" or itemMut
	for _, m in ipairs(targetMuts) do
		if string.lower(m) == string.lower(actualMut) then
			return true
		end
	end
	return false
end

function Utils.getActiveWeather()
	local weatherValues = RS:FindFirstChild("WeatherValues")
	if weatherValues then
		for _, w in ipairs(Const.WeatherList) do
			if w ~= "None" and weatherValues:GetAttribute(w .. "_Playing") == true then
				return w
			end
		end
	end
	return "Clear"
end

function Utils.getFruitValue(fName, sMulti, mut, decay)
	if not fName then
		return 0
	end
	local cleanMut = (type(mut) == "string" and mut ~= "" and mut ~= "None") and mut or nil
	local finalValue = 0
	pcall(function()
		local base = Modules.FruitValue(fName, tonumber(sMulti) or 1, cleanMut, LP, tonumber(decay) or 0)
		if Modules.SellFlags and type(Modules.SellFlags.Apply) == "function" then
			finalValue = Modules.SellFlags.Apply(fName, base)
		else
			finalValue = base
		end
	end)
	if finalValue > 0 then
		return math.floor(finalValue)
	end

	-- Fallback calculation
	local baseValue = Modules.SellValueData[fName] or 0
	local sizeExp = (fName == "Mushroom") and 1.9 or (fName == "Bamboo") and 1.75 or 2.65
	local sm = tonumber(sMulti) or 1
	local sizePow = sm <= 5 and (sm ^ sizeExp) or ((5 ^ sizeExp) * ((sm / 5) ^ math.min(1.5, sizeExp)))
	local mutMult = 1
	if cleanMut then
		mutMult = Const.MutationMultipliers[cleanMut] or 2
		if Const.SingleHarvest[fName] and mutMult > 1 then
			mutMult = 1 + (mutMult - 1) * 0.15
		end
	end
	local decay_m = 1 - math.clamp(tonumber(decay) or 0, 0, 1) * 0.8
	local friends = 1 + (LP:GetAttribute("Friends") or 0) * 0.1
	finalValue = math.floor(baseValue * sizePow * mutMult * decay_m * friends)
	if fName == "Carrot" and finalValue < 4 then
		finalValue = 4
	end
	return finalValue
end

function Utils.getMutColor(mut)
	if not mut or mut == "" or mut == "None" then
		return Const.MutationColors["None"]
	end
	return Const.MutationColors[mut] or Color3.fromRGB(255, 150, 50)
end

function Utils.teleport(hrp, cf, mode)
	if not hrp or not cf then
		return
	end
	mode = mode or State.moveMethod

	if mode == "Teleport Instant" then
		hrp.CFrame = cf
		task.wait(0.1)
		return
	end

	-- Semi-Tween
	local dist = (hrp.Position - cf.Position).Magnitude
	if dist <= 15 then
		hrp.CFrame = cf
		task.wait(0.1)
		return
	end

	local speed = 130
	local tweenT = dist / speed
	local tween = TweenService:Create(hrp, TweenInfo.new(tweenT, Enum.EasingStyle.Linear), { CFrame = cf })
	tween:Play()

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if hrp and (hrp.Position - cf.Position).Magnitude <= 15 then
			tween:Cancel()
			hrp.CFrame = cf
			if conn then
				conn:Disconnect()
			end
		end
	end)
	tween.Completed:Wait()
	if conn then
		conn:Disconnect()
	end
	task.wait(0.1)
end

function Utils.interact(prompt)
	if not prompt or not prompt.Parent then
		return
	end
	if State.interactMethod == "Instant Proximity" then
		prompt.HoldDuration = 0
		fireproximityprompt(prompt, 0)
		task.wait(0.1)
	else
		local hold = prompt.HoldDuration > 0 and prompt.HoldDuration or 0.5
		prompt:InputHoldBegin()
		task.wait(hold + 0.1)
		prompt:InputHoldEnd()
	end
end

function Utils.getToolFromBackpack(attrName, targetList)
	local containers = { LP.Character, LP:FindFirstChild("Backpack") }
	for _, cont in ipairs(containers) do
		if cont then
			for _, item in ipairs(cont:GetChildren()) do
				local attr = item:GetAttribute(attrName)
				if attr then
					if not targetList then
						return item, attr
					end
					if table.find(targetList, "All Sprinklers") or table.find(targetList, "All Watering Cans") then
						return item, attr
					end
					for _, t in ipairs(targetList) do
						if string.lower(attr) == string.lower(t) then
							return item, attr
						end
					end
				end
			end
		end
	end
	return nil, nil
end

function Utils.getSeedTool(targetNames, targetMuts)
	local containers = { LP.Character, LP:FindFirstChild("Backpack") }
	for _, cont in ipairs(containers) do
		if cont then
			for _, item in ipairs(cont:GetChildren()) do
				local sName = item:GetAttribute("SeedTool")
				if sName then
					local sMut = item:GetAttribute("Mutation")
					if Utils.isMatch(sName, sMut, targetNames, targetMuts) then
						return item, sName
					end
				end
			end
		end
	end
	return nil, nil
end

function Utils.getMyPlot()
	return Utils.getPlot()
end

function Utils.scanFruits()
	local items = {}
	local function scan(parent)
		for _, item in ipairs(parent:GetChildren()) do
			local fName = item:GetAttribute("FruitName") or item:GetAttribute("Fruit")
			if fName then
				table.insert(items, item)
			end
		end
	end
	scan(LP.Backpack)
	if LP.Character then
		scan(LP.Character)
	end
	return items
end

function Utils.serverHop()
	local placeId = game.PlaceId
	pcall(function()
		local res =
			game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Desc&limit=100")
		local data = Http:JSONDecode(res)
		if data and data.data then
			local servers = data.data
			for i = #servers, 2, -1 do
				local j = math.random(i)
				servers[i], servers[j] = servers[j], servers[i]
			end
			for _, srv in ipairs(servers) do
				if type(srv) == "table" and srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
					Teleport:TeleportToPlaceInstance(placeId, srv.id, LP)
					task.wait(2)
					return
				end
			end
		end
	end)
	Teleport:Teleport(placeId, LP)
end

-- [8] FEATURES

local Features = {}

-- [8.1] ANTI-AFK
function Features.startAntiAFK()
	stopFeature("antiAFK")
	local trove = getTrove("antiAFK")

	trove:AddConnection(LP.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end))

	trove:AddThread(task.spawn(function()
		while State.antiAFK do
			pcall(function()
				LP:SetAttribute("AntiAfkIdleOverride", 9e9)
			end)
			task.wait(5)
		end
	end))
end

-- [8.2] AUTO HARVEST
function Features.startAutoHarvest()
	stopFeature("autoHarvest")
	local trove = getTrove("autoHarvest")
	trove:AddThread(task.spawn(function()
		while State.autoHarvest do
			pcall(function()
				-- Weather pause check
				local activeW = Utils.getActiveWeather()
				if not table.find(State.pauseHarvestWeather, "None") then
					for _, w in ipairs(State.pauseHarvestWeather) do
						if string.lower(w) == string.lower(activeW) then
							return
						end
					end
				end

				-- Backpack full check
				if State.harvestCheckFull then
					local count = 0
					local function cnt(p)
						for _, it in ipairs(p:GetChildren()) do
							if it:GetAttribute("FruitName") or it:GetAttribute("Fruit") then
								count += 1
							end
						end
					end
					cnt(LP.Backpack)
					if LP.Character then
						cnt(LP.Character)
					end
					if count >= State.harvestMaxCap then
						return
					end
				end

				local plot = Utils.getMyPlot()
				if not plot then
					return
				end

				for _, obj in ipairs(plot:GetDescendants()) do
					if not State.autoHarvest then
						break
					end
					if
						not (obj:IsA("ProximityPrompt") and string.find(string.lower(obj.ActionText or ""), "harvest"))
					then
						continue
					end

					local plantModel = obj.Parent
					local seedName, mutation = nil, nil
					while plantModel and plantModel ~= workspace do
						if plantModel:GetAttribute("SeedName") then
							seedName = plantModel:GetAttribute("SeedName")
							mutation = plantModel:GetAttribute("Mutation")
							break
						end
						plantModel = plantModel.Parent
					end

					if not seedName then
						continue
					end
					if not Utils.isMatch(seedName, mutation, State.targetHarvest, State.targetHarvestMut) then
						continue
					end

					-- Weight filter
					local fFolder = plantModel:FindFirstChild("Fruits")
					local firstFruit = fFolder and fFolder:GetChildren()[1]
					local weight = (firstFruit and firstFruit:GetAttribute("Weight")) or 0

					if weight > 0 then
						if weight < State.minHarvestKg or weight > State.maxHarvestKg then
							continue
						end
					end

					obj.HoldDuration = 0
					fireproximityprompt(obj)
					task.wait(0.05)
				end
			end)
			task.wait(0.1)
		end
	end))
end

-- [8.3] AUTO PLANT
function Features.startAutoPlant()
	stopFeature("autoPlant")
	local trove = getTrove("autoPlant")
	trove:AddThread(task.spawn(function()
		local planted = 0
		while State.autoPlant do
			pcall(function()
				local plot = Utils.getMyPlot()
				if not plot then
					return
				end

				local seedTool, seedName = Utils.getSeedTool(State.targetPlant, State.targetPlantMut)
				if not seedTool then
					return
				end

				local plantAreas = {}
				for _, area in ipairs(Collection:GetTagged("PlantArea")) do
					if area:IsDescendantOf(plot) then
						table.insert(plantAreas, area)
					end
				end
				if #plantAreas == 0 then
					return
				end

				local step = State.gridSpacing
				local plantsFolder = plot:FindFirstChild("Plants")
				local existingPos = {}
				if plantsFolder then
					for _, plant in ipairs(plantsFolder:GetChildren()) do
						local p = plant:IsA("Model") and plant.PrimaryPart
							or plant:FindFirstChildWhichIsA("BasePart", true)
						if p then
							table.insert(existingPos, p.Position)
						end
					end
				end

				for _, area in ipairs(plantAreas) do
					local cf = area.CFrame
					local sizeX = area.Size.X
					local sizeZ = area.Size.Z
					for x = -sizeX / 2 + step, sizeX / 2 - step, step do
						for z = -sizeZ / 2 + step, sizeZ / 2 - step, step do
							if not State.autoPlant then
								return
							end
							if State.plantLimit > 0 and planted >= State.plantLimit then
								State.autoPlant = false
								return
							end

							local pos = (cf * CFrame.new(x, area.Size.Y / 2, z)).Position
							local tooClose = false
							for _, ep in ipairs(existingPos) do
								if (Vector2.new(pos.X, pos.Z) - Vector2.new(ep.X, ep.Z)).Magnitude < 1.2 then
									tooClose = true
									break
								end
							end

							if not tooClose then
								Modules.Networking.Plant.PlantSeed:Fire(pos, seedName, seedTool)
								table.insert(existingPos, pos)
								planted += 1
								task.wait(0.1)
								seedTool, seedName = Utils.getSeedTool(State.targetPlant, State.targetPlantMut)
								if not seedTool then
									return
								end
							end
						end
					end
				end
			end)
			task.wait(planted == 0 and 2 or 0.5)
		end
	end))
end

-- [8.4] AUTO SELL
function Features.startAutoSell()
	stopFeature("autoSell")
	local trove = getTrove("autoSell")
	trove:AddThread(task.spawn(function()
		while State.autoSell or State.autoSellFull or State.autoSellTimer do
			pcall(function()
				local doSell = false

				if State.autoSellTimer then
					Cache.sellTimer = Cache.sellTimer + 0.5
					if Cache.sellTimer >= State.sellInterval then
						doSell = true
						Cache.sellTimer = 0
					end
				end

				if State.autoSellFull then
					local cur = LP:GetAttribute("FruitCount") or 0
					local max = LP:GetAttribute("MaxFruitCapacity") or 100
					if cur >= max then
						doSell = true
					end
				end

				if State.autoSell then
					doSell = true
				end

				if not doSell then
					return
				end

				local allAny = table.find(State.targetSell, "All") and table.find(State.targetSellMut, "Any")
				if allAny then
					Modules.Networking.NPCS.SellAll:Fire()
					task.wait(1)
				else
					for _, item in ipairs(Utils.scanFruits()) do
						local fName = item:GetAttribute("FruitName") or item:GetAttribute("Fruit")
						local mut = item:GetAttribute("Mutation")
						if Utils.isMatch(fName, mut, State.targetSell, State.targetSellMut) then
							local itemId = item:GetAttribute("Id") or item:GetAttribute("UniqueId")
							if itemId then
								Modules.Networking.NPCS.SellFruit:Fire(itemId)
								task.wait(0.1)
							end
						end
					end
				end
			end)
			task.wait(0.5)
		end
	end))
end

-- [8.5] AUTO WATER
function Features.startAutoWater()
	stopFeature("autoWater")
	local trove = getTrove("autoWater")
	trove:AddThread(task.spawn(function()
		while State.autoWater do
			pcall(function()
				local _, hrp, hum = Utils.getChar()
				local plot = Utils.getMyPlot()
				if not (hrp and plot) then
					return
				end

				local canTool, canAttr = Utils.getToolFromBackpack("WateringCan", { State.waterCan })
				if not canTool then
					return
				end

				local plantsFolder = plot:FindFirstChild("Plants")
				if not plantsFolder then
					return
				end

				for _, plant in ipairs(plantsFolder:GetChildren()) do
					if not State.autoWater then
						break
					end
					local sName = plant:GetAttribute("SeedName")
					local mut = plant:GetAttribute("Mutation")
					if Utils.isMatch(sName, mut, State.waterPlant, State.waterMut) then
						local pPart = plant:IsA("Model") and plant.PrimaryPart
							or plant:FindFirstChildWhichIsA("BasePart", true)
						if pPart then
							Modules.Networking.WateringCan.UseWateringCan:Fire(
								pPart.Position - Vector3.new(0, 0.3, 0),
								canAttr,
								canTool
							)
							task.wait(0.15)
						end
					end
				end
			end)
			task.wait(2)
		end
	end))
end

-- [8.6] AUTO SPRINKLER
function Features.startAutoSprinkler()
	stopFeature("autoSprinkler")
	local trove = getTrove("autoSprinkler")
	trove:AddThread(task.spawn(function()
		while State.autoSprinkler do
			pcall(function()
				local plotId = LP:GetAttribute("PlotId")
				local plot = Utils.getMyPlot()
				local _, hrp, hum = Utils.getChar()
				if not (plotId and plot and hum) then
					return
				end

				local plantAreas = {}
				for _, area in ipairs(Collection:GetTagged("PlantArea")) do
					if area:IsDescendantOf(plot) then
						table.insert(plantAreas, area)
					end
				end
				if #plantAreas == 0 then
					return
				end

				local sprTool, sprAttr = Utils.getToolFromBackpack("Sprinkler", { State.sprinklerType })
				if not sprTool then
					return
				end

				local step = State.sprinklerSpacing
				local area = plantAreas[1]
				local cf = area.CFrame

				for x = -area.Size.X / 2 + step, area.Size.X / 2 - step, step do
					for z = -area.Size.Z / 2 + step, area.Size.Z / 2 - step, step do
						if not State.autoSprinkler then
							return
						end
						local pos = (cf * CFrame.new(x, area.Size.Y / 2, z)).Position

						-- Check existing
						local tooClose = false
						for _, obj in ipairs(plot:GetDescendants()) do
							if obj:IsA("Model") and string.find(obj.Name, "Sprinkler") then
								local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
								if
									pp
									and (Vector2.new(pos.X, pos.Z) - Vector2.new(pp.Position.X, pp.Position.Z)).Magnitude
										< 1
								then
									tooClose = true
									break
								end
							end
						end

						if not tooClose then
							Modules.Networking.Place.PlaceSprinkler:Fire(pos, sprAttr, sprTool, tonumber(plotId))
							task.wait(0.2)
							sprTool, sprAttr = Utils.getToolFromBackpack("Sprinkler", { State.sprinklerType })
							if not sprTool then
								return
							end
						end
					end
				end
			end)
			task.wait(5)
		end
	end))
end

-- [8.7] AUTO SHOVEL
function Features.startAutoShovel()
	stopFeature("autoShovel")
	local trove = getTrove("autoShovel")
	trove:AddThread(task.spawn(function()
		while State.autoShovel or State.shovelDead do
			pcall(function()
				local plot = Utils.getMyPlot()
				if not plot then
					return
				end

				local shovelTool, shovelAttr = Utils.getToolFromBackpack("Shovel")
				if not shovelTool then
					return
				end

				local plantsFolder = plot:FindFirstChild("Plants")
				if not plantsFolder then
					return
				end

				for _, plant in ipairs(plantsFolder:GetChildren()) do
					if not (State.autoShovel or State.shovelDead) then
						break
					end

					local isDecaying = plant:GetAttribute("Decaying") == true
					local sName = plant:GetAttribute("SeedName")
					local mut = plant:GetAttribute("Mutation")
					local shouldShovel = false

					if State.shovelDead and isDecaying then
						shouldShovel = true
					elseif State.autoShovel and sName then
						if Utils.isMatch(sName, mut, State.targetShovel, State.targetShovelMut) then
							shouldShovel = true
						end
					end

					if shouldShovel then
						Modules.Networking.Shovel.UseShovel:Fire(plant.Name, "", shovelAttr, shovelTool)
						task.wait(0.15)
					end
				end
			end)
			task.wait(0.5)
		end
	end))
end

-- [8.8] AUTO STEAL
function Features.startAutoSteal()
	stopFeature("autoSteal")
	local trove = getTrove("autoSteal")
	trove:AddThread(task.spawn(function()
		while State.autoSteal do
			pcall(function()
				if Cache.stealInProgress then
					return
				end
				local Night = RS:FindFirstChild("Night")
				if not (Night and Night.Value == true) then
					return
				end

				Cache.stealInProgress = true
				local char = LP.Character or LP.CharacterAdded:Wait()

				local rawPrompts = {}
				local gardens = workspace:FindFirstChild("Gardens")
				if not gardens then
					Cache.stealInProgress = false
					return
				end

				for _, v in pairs(gardens:GetDescendants()) do
					if not (v.Name == "StealPrompt" and v.Parent) then
						continue
					end

					local plotModel = v.Parent
					while plotModel and plotModel.Parent ~= gardens do
						plotModel = plotModel.Parent
					end

					local pOwner, ownerPlayer = "", nil
					if plotModel then
						local ownerId = plotModel:GetAttribute("OwnerUserId")
						if ownerId then
							for _, p in ipairs(Players:GetPlayers()) do
								if p.UserId == ownerId then
									pOwner = p.Name
									ownerPlayer = p
									break
								end
							end
						end
					end

					-- Owner in garden check
					if
						ownerPlayer
						and ownerPlayer.Character
						and ownerPlayer.Character:FindFirstChild("HumanoidRootPart")
						and plotModel
					then
						local dist = (ownerPlayer.Character.HumanoidRootPart.Position - plotModel:GetPivot().Position).Magnitude
						if dist < 150 then
							continue
						end
					end

					local isTargetMatch = (State.stealTarget == "Anyone" or State.stealTarget == "")
						or string.find(string.lower(pOwner), string.lower(State.stealTarget))
					if not isTargetMatch then
						continue
					end

					local currentObj = v.Parent
					local sizeMulti, seedName, fMut = 0, nil, nil
					while currentObj and currentObj ~= workspace do
						if currentObj:GetAttribute("SeedName") then
							seedName = currentObj:GetAttribute("SeedName")
							fMut = currentObj:GetAttribute("Mutation")
						end
						if currentObj:GetAttribute("SizeMulti") then
							sizeMulti = currentObj:GetAttribute("SizeMulti")
						end
						currentObj = currentObj.Parent
					end

					if v.Parent:GetAttribute("Mutation") then
						local m = v.Parent:GetAttribute("Mutation")
						if m ~= "" and m ~= "None" then
							fMut = m
						end
					end

					if
						sizeMulti >= State.stealMinValue
						and Utils.isMatch(seedName, fMut, State.targetSteal, State.targetStealMut)
					then
						table.insert(rawPrompts, { prompt = v, size = sizeMulti, owner = pOwner })
					end
				end

				if #rawPrompts == 0 then
					Cache.stealInProgress = false
					return
				end

				if State.stealMode == "Highest Value" then
					table.sort(rawPrompts, function(a, b)
						return a.size > b.size
					end)
				elseif State.stealMode == "Lowest Value" then
					table.sort(rawPrompts, function(a, b)
						return a.size < b.size
					end)
				end

				local stolen = 0
				for _, data in ipairs(rawPrompts) do
					if not State.autoSteal then
						break
					end
					if not (data.prompt and data.prompt.Parent) then
						continue
					end

					local fruitModel = data.prompt.Parent
					local hrp = char:FindFirstChild("HumanoidRootPart")
					Utils.teleport(hrp, fruitModel:GetPivot() * CFrame.new(0, 2.8, 0))
					if hrp then
						hrp.Velocity = Vector3.zero
						hrp.RotVelocity = Vector3.zero
						hrp.Anchored = true
					end

					if not (data.prompt.Parent and fruitModel.Parent) then
						if hrp then
							hrp.Anchored = State.isFrozen
						end
						continue
					end

					Utils.interact(data.prompt)
					task.wait(0.3)

					if hrp then
						hrp.Anchored = State.isFrozen
					end
					stolen += 1
					task.wait(0.05)

					if stolen >= State.stealReturnLimit then
						if State.autoRejoin then
							pcall(function()
								Teleport:Teleport(game.PlaceId, LP)
							end)
						else
							if State.savedGardenCF and hrp then
								Utils.teleport(hrp, State.savedGardenCF)
							end
						end
						Cache.stealInProgress = false
						return
					end
				end

				if State.autoRejoin then
					pcall(function()
						Teleport:Teleport(game.PlaceId, LP)
					end)
				else
					if State.savedGardenCF and char:FindFirstChild("HumanoidRootPart") then
						Utils.teleport(char.HumanoidRootPart, State.savedGardenCF)
					end
				end
				Cache.stealInProgress = false
			end)
			task.wait(0.5)
		end
	end))
end

-- [8.9] AUTO COLLECT DROPS
function Features.startAutoCollect()
	stopFeature("autoCollect")
	local trove = getTrove("autoCollect")
	trove:AddThread(task.spawn(function()
		while State.autoCollect do
			pcall(function()
				local hrp = Cache.hrp
				if not hrp then
					return
				end

				local targets = {
					workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("SeedPackSpawnServerLocations"),
					workspace:FindFirstChild("DroppedItems"),
				}

				local foundAny = false
				for _, folder in ipairs(targets) do
					if not folder then
						continue
					end
					for _, item in ipairs(folder:GetChildren()) do
						if not State.autoCollect then
							break
						end

						local itemName = string.lower(item.Name)
						local isGold = item:GetAttribute("GoldSeed") or string.find(itemName, "gold")
						local isRainbow = item:GetAttribute("RainbowSeed") or string.find(itemName, "rainbow")
						local isRandom = not isGold and not isRainbow

						local shouldCollect = false
						if table.find(State.collectTargets, "All") then
							shouldCollect = true
						else
							if isGold and table.find(State.collectTargets, "Gold") then
								shouldCollect = true
							end
							if isRainbow and table.find(State.collectTargets, "Rainbow") then
								shouldCollect = true
							end
							if isRandom and table.find(State.collectTargets, "Random Seed") then
								shouldCollect = true
							end
						end

						if shouldCollect then
							local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
							if prompt and prompt.Parent then
								foundAny = true
								Cache.collectActive = true
								Cache.collectIdle = 0
								local pos = (prompt.Parent.CFrame and prompt.Parent.CFrame.Position)
									or item:GetPivot().Position
								Utils.teleport(hrp, CFrame.new(pos + Vector3.new(0, 3, 0)))
								Utils.interact(prompt)
							end
						end
					end
				end

				if Cache.collectActive and not foundAny then
					if State.collectMode == "Collect & Back" then
						Cache.collectIdle += 0.5
						if Cache.collectIdle >= State.collectDelay then
							Cache.collectActive = false
							Cache.collectIdle = 0
							-- Return to garden
							local plot = Utils.getMyPlot()
							if plot and Cache.hrp then
								Utils.teleport(Cache.hrp, plot:GetPivot() * CFrame.new(0, 3, 0))
							end
						end
					else
						Cache.collectActive = false
						Cache.collectIdle = 0
					end
				end
			end)
			task.wait(0.5)
		end
	end))
end

-- [8.10] AUTO GAMBLE (Double or Nothing)
function Features.startAutoGamble()
	stopFeature("autoGamble")
	local trove = getTrove("autoGamble")
	trove:AddThread(task.spawn(function()
		task.wait(1.5)
		while State.autoGamble do
			if State.gambleWaitFull then
				local currentFruit = LP:GetAttribute("FruitCount") or 0
				if currentFruit < State.gambleWaitFullCount then
					task.wait(2)
					continue
				end
			end
			pcall(function()
				local roll, ok = nil, false
				ok, roll = pcall(function()
					return Modules.Networking.NPCS.DoubleOrNothing:Fire()
				end)
				if not (ok and roll) then
					task.wait(2)
					return
				end

				if roll.Busted then
					task.wait(3)
				elseif roll.Won then
					local wins = roll.Wins or 0
					if wins >= State.gambleTarget then
						Modules.Networking.NPCS.CashOutDoubleOrNothing:Fire()
						task.wait(2)
					else
						task.wait(0.5)
					end
				elseif roll.Reason == "NoFruits" then
					task.wait(5)
				elseif roll.Reason == "Cooldown" then
					task.wait(roll.Remaining or 2)
				else
					task.wait(2)
				end
			end)
		end
	end))
end

-- [8.11] AUTO OPEN (Packs/Crates/Eggs)
function Features.startAutoOpen()
	stopFeature("autoOpen")
	local trove = getTrove("autoOpen")
	trove:AddThread(task.spawn(function()
		while State.autoOpenPacks or State.autoOpenCrates or State.autoOpenEggs do
			pcall(function()
				for _, item in ipairs(LP.Backpack:GetChildren()) do
					if State.autoOpenPacks and item:GetAttribute("SeedPack") then
						Modules.Networking.SeedPack.OpenSeedPack:Fire(item:GetAttribute("SeedPack"))
						task.wait(0.5)
					end
					if State.autoOpenCrates and item:GetAttribute("Crate") then
						Modules.Networking.Crate.OpenCrate:Fire(item:GetAttribute("Crate"))
						task.wait(0.5)
					end
					if State.autoOpenEggs and item:GetAttribute("Egg") then
						Modules.Networking.Egg.OpenEgg:Fire(item:GetAttribute("Egg"))
						task.wait(0.5)
					end
				end
			end)
			task.wait(1)
		end
	end))
end

-- [8.12] AUTO BUY
function Features.startAutoBuy()
	stopFeature("autoBuy")
	local trove = getTrove("autoBuy")
	trove:AddThread(task.spawn(function()
		while
			State.autoBuySeed
			or State.autoBuyGear
			or State.autoBuyCrate
			or State.autoExpand
			or State.autoBuyPetSlot
		do
			pcall(function()
				if State.autoBuySeed then
					for _, seed in ipairs(State.targetBuySeed) do
						Modules.Networking.SeedShop.PurchaseSeed:Fire(seed)
						task.wait(0.3)
					end
				end
				if State.autoBuyGear then
					for _, gear in ipairs(State.targetBuyGear) do
						Modules.Networking.GearShop.PurchaseGear:Fire(gear)
						task.wait(0.3)
					end
				end
				if State.autoBuyCrate then
					for _, crate in ipairs(State.targetBuyCrate) do
						Modules.Networking.CrateShop.PurchaseCrate:Fire(crate)
						task.wait(0.3)
					end
				end
				if State.autoExpand then
					Modules.Networking.Actions.ExpandGarden:Fire()
					task.wait(1)
				end
				if State.autoBuyPetSlot then
					Modules.Networking.Pets.RequestPurchasePetSlot:Fire()
					task.wait(1)
				end
			end)
			task.wait(0.5)
		end
	end))
end

-- [8.13] AUTO FAVORITE
function Features.startAutoFav()
	stopFeature("autoFav")
	local trove = getTrove("autoFav")
	trove:AddThread(task.spawn(function()
		while State.autoFav or State.autoUnfav do
			pcall(function()
				for _, item in ipairs(Utils.scanFruits()) do
					local fName = item:GetAttribute("FruitName") or item:GetAttribute("Fruit")
					local mut = item:GetAttribute("Mutation")
					if not Utils.isMatch(fName, mut, State.targetFavFruits, { "Any" }) then
						continue
					end

					local itemId = item:GetAttribute("Id") or item:GetAttribute("UniqueId")
					if not itemId then
						continue
					end

					if State.autoFav and not Cache.favProcessed[itemId .. "_fav"] then
						Modules.Networking.Backpack.SetFruitFavorite:Fire(itemId, true)
						Cache.favProcessed[itemId .. "_fav"] = true
						task.wait(0.05)
					elseif State.autoUnfav and not Cache.favProcessed[itemId .. "_unfav"] then
						Modules.Networking.Backpack.SetFruitFavorite:Fire(itemId, false)
						Cache.favProcessed[itemId .. "_unfav"] = true
						task.wait(0.05)
					end
				end
			end)
			task.wait(0.5)
		end
		table.clear(Cache.favProcessed)
	end))
end

-- [8.14] AUTO BARGAIN
function Features.startAutoBargain()
	stopFeature("autoBargain")
	local trove = getTrove("autoBargain")
	trove:AddThread(task.spawn(function()
		while State.autoBargain do
			if State.bargainWaitFull then
				local currentFruit = LP:GetAttribute("FruitCount") or 0
				if currentFruit < State.bargainWaitFullCount then
					task.wait(2)
					continue
				end
			end
			pcall(function()
				Modules.Networking.NPCS.AskBidAll:Fire()
				task.wait(2)
			end)
			task.wait(2)
		end
	end))
end

-- [8.14.1] AUTO AUCTION
function Features.startAutoAuction()
	stopFeature("autoAuction")
	local trove = getTrove("autoAuction")
	local PURCHASE_DEBOUNCE = 0.25
	local PURCHASE_COOLDOWN = 10.5

	local function tryPurchase(lot)
		local now = os.clock()
		local lastFire = Cache.auctionPurchaseDebounce[lot.lotId]
		if lastFire and (now - lastFire) < PURCHASE_DEBOUNCE then return false, "debounce" end
		local cdUntil = Cache.auctionCooldowns[lot.lotId] or 0
		if now < cdUntil then return false, "cooldown" end
		local price = Utils.auctionCurrentPrice(lot)
		if State.auctionMaxPrice > 0 and price > State.auctionMaxPrice then return false, "over budget" end

		Cache.auctionPurchaseDebounce[lot.lotId] = now
		Cache.auctionCooldowns[lot.lotId] = now + PURCHASE_COOLDOWN
		local ok = pcall(function()
			Modules.Networking.Auctioneer.PurchaseLot:Fire(lot.lotId, price)
		end)
		return ok, "fired @ " .. price .. "Â¢"
	end

	trove:AddThread(task.spawn(function()
		task.wait(1)
		while State.autoAuction do
			local totalLots = 0
			for _ in pairs(Cache.auctionLots) do totalLots += 1 end
			if totalLots == 0 then
				task.spawn(function() pcall(function() Modules.Networking.Auctioneer.RequestSnapshot:Fire() end) end)
				task.wait(2)
				continue
			end

			local candidates = {}
			for id, lot in pairs(Cache.auctionLots) do
				local stock = Cache.auctionStock[id] or lot.amount
				if State.auctionCheckStock and stock <= 0 then continue end
				if stock < State.auctionMinCount then continue end
				if not Utils.auctionPassesFilter(lot) then continue end
				local price = Utils.auctionCurrentPrice(lot)
				if State.auctionMaxPrice > 0 and price > State.auctionMaxPrice then continue end
				table.insert(candidates, { lot = lot, price = price })
			end

			table.sort(candidates, function(a, b) return a.price < b.price end)
			if #candidates > 0 then
				if State.auctionBuyMode == "Lowest Only" then
					tryPurchase(candidates[1].lot)
				else
					for _, c in ipairs(candidates) do
						if not State.autoAuction then break end
						tryPurchase(c.lot)
						task.wait(0.1)
					end
				end
			end
			task.wait(0.5)
		end
	end))
end

-- [8.15] AUTO SKIP CUTSCENE
function Features.startAutoSkip()
	stopFeature("autoSkip")
	local trove = getTrove("autoSkip")
	local Camera = workspace.CurrentCamera
	local function executeSkip()
		local pgui = LP:FindFirstChild("PlayerGui")
		if not pgui then
			return
		end
		for _, gui in ipairs(pgui:GetChildren()) do
			local gName = string.lower(gui.Name)
			if string.find(gName, "cutscene") or string.find(gName, "intro") or string.find(gName, "cinematic") then
				gui:Destroy()
				if Camera.CameraType == Enum.CameraType.Scriptable then
					Camera.CameraType = Enum.CameraType.Custom
					if LP.Character and LP.Character:FindFirstChild("Humanoid") then
						Camera.CameraSubject = LP.Character.Humanoid
					end
				end
				if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
					LP.Character.HumanoidRootPart.Anchored = false
				end
			end
		end
	end

	trove:AddThread(task.spawn(function()
		while State.autoSkip do
			pcall(executeSkip)
			task.wait(0.5)
		end
	end))
end

-- [8.16] ANTI-STEAL (Fling-based defend)
function Features.startAntiSteal()
	stopFeature("antiSteal")
	local trove = getTrove("antiSteal")
	trove:AddThread(task.spawn(function()
		while State.antiSteal do
			pcall(function()
				local Night = RS:FindFirstChild("Night")
				if not (Night and Night.Value == true) then
					return
				end

				local plot = Utils.getMyPlot()
				if not plot then
					return
				end
				local plotCenter = plot:GetPivot().Position
				local char = LP.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChild("Humanoid")

				for _, p in ipairs(Players:GetPlayers()) do
					if p == LP then
						continue
					end
					local pChar = p.Character
					local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
					if not pHrp then
						continue
					end
					if (pHrp.Position - plotCenter).Magnitude < 120 and hrp and hum then
						if hum.Sit then
							hum.Sit = false
						end
						hrp.RotVelocity = Vector3.new(0, 50000, 0)
						hrp.CFrame = pHrp.CFrame
					end
				end
			end)
			task.wait(0.1)
		end
	end))
end

-- [8.17] AUTO CLAIM MAIL / ACCEPT GIFT
function Features.startAutoMail()
	stopFeature("autoMail")
	local trove = getTrove("autoMail")

	-- Accept gift hook (event-driven, register once)
	if not Cache.giftHooked then
		Cache.giftHooked = true
		GlobalTrove:AddConnection(Modules.Networking.Gifting.Prompted.OnClientEvent:Connect(function(playerInstance)
			if State.autoAcceptGift and playerInstance then
				Modules.Networking.Gifting.Response:Fire(playerInstance, true)
			end
		end))
	end

	trove:AddThread(task.spawn(function()
		while State.autoClaimMail do
			pcall(function()
				local ok, inbox = pcall(function()
					return Modules.Networking.Mailbox.OpenInbox:Fire()
				end)
				if ok and type(inbox) == "table" then
					for mailId, _ in pairs(inbox) do
						pcall(function()
							Modules.Networking.Mailbox.Claim:Fire(mailId)
						end)
						task.wait(0.8)
					end
				end
			end)
			task.wait(5)
		end
	end))
end

-- [8.18] UTILITY & VISUALS
function Features.startUtilityLoop()
	stopFeature("utilityLoop")
	local trove = getTrove("utilityLoop")
	trove:AddConnection(Svc.Run.Heartbeat:Connect(function()
		if State.walkSpeedEnabled and Cache.char and Cache.hum then
			Cache.hum.WalkSpeed = State.walkSpeed
		end
		if State.instantPrompt then
			for _, prompt in ipairs(Svc.Collection:GetTagged("ProximityPrompt")) do
				prompt.HoldDuration = 0
			end
			-- Fallback
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end
			end
		end
	end))
end

function Features.startGraphicOptimization()
	stopFeature("graphicOpt")
	local trove = getTrove("graphicOpt")
	local hiddenPlantsCache = {}
	local function hidePlants()
		local gardens = workspace:FindFirstChild("Gardens")
		if gardens then
			for _, plot in ipairs(gardens:GetChildren()) do
				if plot ~= Utils.getPlot() then
					local plantsFolder = plot:FindFirstChild("Plants")
					if plantsFolder then
						for _, child in ipairs(plantsFolder:GetChildren()) do
							if child.Parent == plantsFolder then
								hiddenPlantsCache[child] = plantsFolder
								child.Parent = nil
							end
						end
					end
				end
			end
		end
	end
	local function restorePlants()
		for child, parent in pairs(hiddenPlantsCache) do pcall(function() child.Parent = parent end) end
		table.clear(hiddenPlantsCache)
	end

	trove:AddThread(task.spawn(function()
		while task.wait(1) do
			if State.hidePlants then hidePlants() else restorePlants() end
			if State.lowGraphic then
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("BasePart") then
						obj.Material = Enum.Material.SmoothPlastic
						obj.CastShadow = false
					elseif obj:IsA("Decal") or obj:IsA("Texture") then
						obj.Transparency = 1
					end
				end
				Svc.Lighting.GlobalShadows = false
			end
			if State.noParticles then
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Sparkles") or obj:IsA("Fire") or obj:IsA("Smoke") then
						obj.Enabled = false
					end
				end
			end
		end
	end))
	trove:Add(restorePlants)
end

-- [8.19] WEBHOOK
function Features.startWebhook()
	stopFeature("webhook")
	local trove = getTrove("webhook")
	trove:AddThread(task.spawn(function()
		while State.webhookEnabled do
			if State.webhookUrl ~= "" then
				pcall(function()
					local data = {
						embeds = {{
							title = "Zuperming - GAG2 Update",
							color = tonumber("0x00FF00"),
							fields = {
								{ name = "Inv Value", value = "Â¢" .. Utils.abbreviate(Cache.invTotal), inline = true },
								{ name = "Garden Value", value = "Â¢" .. Utils.abbreviate(Cache.gardenTotal), inline = true },
								{ name = "Fruit Count", value = tostring(LP:GetAttribute("FruitCount") or 0), inline = true }
							}
						}}
					}
					local req = syn and syn.request or request or http_request or (http and http.request)
					if req then
						req({Url = State.webhookUrl, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = Svc.Http:JSONEncode(data)})
					end
				end)
			end
			task.wait(State.webhookInterval)
		end
	end))
end

-- [8.20] AUTO GIFT & TROWEL
function Features.startAutoGift()
	stopFeature("autoGift")
	local trove = getTrove("autoGift")
	trove:AddThread(task.spawn(function()
		while State.autoGift do
			pcall(function()
				if State.giftTarget and State.giftTarget ~= "" then
					Modules.Networking.Gift.SendGift:Fire(State.giftTarget)
				end
			end)
			task.wait(5)
		end
	end))
end

function Features.startAutoTrowel()
	stopFeature("autoTrowel")
	local trove = getTrove("autoTrowel")
	trove:AddThread(task.spawn(function()
		while State.autoTrowel do
			pcall(function()
				-- Simplified trowel firing. A real implementation maps positions.
				local shovelTool = getToolFromBackpack("Trowel")
				if shovelTool then
					Modules.Networking.Trowel.UseTrowel:Fire()
				end
			end)
			task.wait(2)
		end
	end))
end

-- [9] ESP SYSTEM

local ESP = {}
ESP.drawings = {}

local function getMutColor(mut)
	return Utils.getMutColor(mut)
end

local function getOrCreateDrawing(key)
	if not ESP.drawings[key] then
		local txt = Drawing.new("Text")
		txt.Visible = false
		txt.Center = true
		txt.Outline = true
		txt.Font = 2
		txt.Size = 13
		ESP.drawings[key] = txt
	end
	return ESP.drawings[key]
end

-- ESP refresh via RenderStepped (lightweight, no loop)
GlobalTrove:AddConnection(RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local activeKeys = {}

	-- ESP Players
	if State.espPlayers then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LP then
				continue
			end
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then
				continue
			end
			local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
			if onScreen then
				local key = "player_" .. plr.UserId
				activeKeys[key] = true
				local d = getOrCreateDrawing(key)
				d.Text = plr.Name
				d.Color = Color3.fromRGB(255, 50, 50)
				d.Position = Vector2.new(pos.X, pos.Y)
				d.Visible = true
			end
		end
	end

	-- ESP Plants
	if State.espPlants then
		local gardens = workspace:FindFirstChild("Gardens")
		if gardens then
			for _, plot in ipairs(gardens:GetChildren()) do
				local pf = plot:FindFirstChild("Plants")
				if not pf then
					continue
				end
				for _, plant in ipairs(pf:GetChildren()) do
					local fFolder = plant:FindFirstChild("Fruits")
					local isReady = plant:GetAttribute("PlantGrowthReady") == true
					local hasFruit = fFolder and #fFolder:GetChildren() > 0
					if not (isReady or hasFruit) then
						continue
					end

					local part = (fFolder and fFolder:GetChildren()[1])
							and (fFolder:GetChildren()[1]:IsA("BasePart") and fFolder:GetChildren()[1] or fFolder
								:GetChildren()[1]
								:FindFirstChildWhichIsA("BasePart", true))
						or plant.PrimaryPart
						or plant:FindFirstChildWhichIsA("BasePart", true)
					if not part then
						continue
					end

					local pos, onScreen = cam:WorldToViewportPoint(part.Position)
					if not onScreen then
						continue
					end

					local sName = plant:GetAttribute("SeedName") or plant.Name
					local pMut = plant:GetAttribute("Mutation") or ""
					local pSize = plant:GetAttribute("SizeMultiplier") or plant:GetAttribute("SizeMulti") or 1

					local lines = {}
					if State.espShowName then
						table.insert(lines, sName)
					end
					if State.espShowMut and pMut ~= "" and pMut ~= "None" then
						table.insert(lines, "[" .. pMut .. "]")
					end
					if State.espShowKg and pSize > 1 then
						table.insert(lines, string.format("x%.2f", pSize))
					end
					if State.espShowVal then
						local v = Utils.getFruitValue(sName, pSize, pMut, 0)
						if v > 0 then
							table.insert(lines, "Â¢" .. Utils.abbreviate(v))
						end
					end

					if #lines > 0 then
						local key = "plant_" .. plant:GetAttribute("PlantId") or tostring(plant)
						activeKeys[key] = true
						local d = getOrCreateDrawing(key)
						d.Text = table.concat(lines, "\n")
						d.Color = getMutColor(pMut)
						d.Position = Vector2.new(pos.X, pos.Y)
						d.Visible = true
					end
				end
			end
		end
	end

	-- ESP Wild Pets
	if State.espPets then
		local mapF = workspace:FindFirstChild("Map")
		local wildSpawns = mapF and mapF:FindFirstChild("WildPetSpawns")
		if wildSpawns then
			for _, petModel in ipairs(wildSpawns:GetChildren()) do
				if not petModel:IsA("Model") then
					continue
				end
				local part = petModel.PrimaryPart or petModel:FindFirstChildWhichIsA("BasePart", true)
				if not part then
					continue
				end
				local pos, onScreen = cam:WorldToViewportPoint(part.Position)
				if not onScreen then
					continue
				end
				local pName = petModel:GetAttribute("PetName") or petModel.Name
				local key = "pet_" .. petModel.Name
				activeKeys[key] = true
				local d = getOrCreateDrawing(key)
				d.Text = pName .. "\n[Wild]"
				d.Color = Color3.fromRGB(255, 105, 180)
				d.Position = Vector2.new(pos.X, pos.Y)
				d.Visible = true
			end
		end
	end

	-- Hide drawings not in active set
	for key, drawing in pairs(ESP.drawings) do
		if not activeKeys[key] then
			drawing.Visible = false
		end
	end
end))

-- [10] VALUE TRACKER

GlobalTrove:AddThread(task.spawn(function()
	while true do
		task.wait(0.5)
		pcall(function()
			local invTotal = 0
			for _, item in ipairs(Utils.scanFruits()) do
				local fName = item:GetAttribute("FruitName") or item:GetAttribute("Fruit")
				local sMulti = item:GetAttribute("SizeMultiplier") or item:GetAttribute("SizeMulti") or 1
				local mut = item:GetAttribute("Mutation")
				local decay = item:GetAttribute("DecayAlpha") or 0
				invTotal += Utils.getFruitValue(fName, sMulti, mut, decay)
			end
			Cache.invTotal = invTotal

			local gardenTotal = 0
			local plantCount = 0
			local plot = Utils.getMyPlot()
			if plot then
				local pf = plot:FindFirstChild("Plants")
				if pf then
					plantCount = #pf:GetChildren()
					for _, plant in ipairs(pf:GetChildren()) do
						local sName = plant:GetAttribute("SeedName")
						if not sName then
							continue
						end
						local pSize = plant:GetAttribute("SizeMultiplier") or 1
						local pMut = plant:GetAttribute("Mutation")
						local fFolder = plant:FindFirstChild("Fruits")
						if fFolder and #fFolder:GetChildren() > 0 then
							for _, fruit in ipairs(fFolder:GetChildren()) do
								local fS = fruit:GetAttribute("SizeMultiplier") or 1
								local fM = fruit:GetAttribute("Mutation")
								gardenTotal += Utils.getFruitValue(sName, math.max(pSize, fS), fM or pMut, 0)
							end
						else
							gardenTotal += Utils.getFruitValue(sName, pSize, pMut, 0)
						end
					end
				end
			end
			Cache.gardenTotal = gardenTotal
			Cache.plantCount = plantCount
		end)
	end
end))

-- [11] WEATHER PREDICTOR UI

local PredUI = {}
do
	local gui = Instance.new("ScreenGui")
	gui.Name = "ZupermingPredictor"
	gui.ResetOnSpawn = false
	local ok = pcall(function()
		gui.Parent = game:GetService("CoreGui")
	end)
	if not ok then
		gui.Parent = LP:WaitForChild("PlayerGui")
	end

	local frame = Instance.new("Frame", gui)
	frame.Size = UDim2.new(0, 200, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Position = UDim2.new(0, 15, 0.4, 0)
	frame.BackgroundTransparency = 1
	Instance.new("UIListLayout", frame).Padding = UDim.new(0, 4)

	local function makeLabel(parent, text, size)
		local lbl = Instance.new("TextLabel", parent)
		lbl.Size = UDim2.new(1, 0, 0, size or 16)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextStrokeTransparency = 0
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.RichText = true
		return lbl
	end

	PredUI.frame = frame
	PredUI.gui = gui
	PredUI.lblCurrent = makeLabel(frame, "Loading...")
	PredUI.lblPred = makeLabel(frame, "")
	PredUI.lblPred.AutomaticSize = Enum.AutomaticSize.Y
	makeLabel(frame, "<font color='#A050FF'>.gg/zuperming</font>", 14)

	-- Drag support
	local dragging, dragStart, startPos = false, nil, nil
	frame.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = inp.Position
			startPos = frame.Position
		end
	end)
	UIS.InputChanged:Connect(function(inp)
		if
			dragging
			and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch)
		then
			local d = inp.Position - dragStart
			frame.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	-- Garden stats UI
	local gardenGui = Instance.new("ScreenGui")
	gardenGui.Name = "ZupermingGarden"
	gardenGui.ResetOnSpawn = false
	pcall(function()
		gardenGui.Parent = game:GetService("CoreGui")
	end)

	local gardenFrame = Instance.new("Frame", gardenGui)
	gardenFrame.Size = UDim2.new(0, 160, 0, 0)
	gardenFrame.AutomaticSize = Enum.AutomaticSize.Y
	gardenFrame.Position = UDim2.new(0, 15, 0.56, 0)
	gardenFrame.BackgroundTransparency = 1

	PredUI.gardenGui = gardenGui
	PredUI.gardenFrame = gardenFrame
	PredUI.gardenText = Instance.new("TextLabel", gardenFrame)
	PredUI.gardenText.Size = UDim2.new(1, 0, 0, 0)
	PredUI.gardenText.AutomaticSize = Enum.AutomaticSize.Y
	PredUI.gardenText.BackgroundTransparency = 1
	PredUI.gardenText.TextStrokeTransparency = 0
	PredUI.gardenText.Font = Enum.Font.GothamSemibold
	PredUI.gardenText.TextSize = 13
	PredUI.gardenText.TextXAlignment = Enum.TextXAlignment.Left
	PredUI.gardenText.RichText = true
	PredUI.gardenText.Text = ""
end

-- Weather predictor update loop
GlobalTrove:AddThread(task.spawn(function()
	local weatherData = {
		{ name = "Rain", interval = 120 * 60, color = "#55FF55" },
		{ name = "Lightning", interval = 90 * 60, color = "#FFD700" },
		{ name = "Rainbow", interval = 60 * 60, color = "#AA00FF" },
		{ name = "Snowfall", interval = 30 * 60, color = "#88DDFF" },
		{ name = "Starfall", interval = 30 * 60, color = "#e88bff" },
	}
	while true do
		task.wait(1)
		pcall(function()
			PredUI.frame.Visible = State.showWeather

			if State.showWeather then
				local now = DateTime.now().UnixTimestamp
				local tod = RS:FindFirstChild("Night") and RS.Night.Value and "Night" or "Day"
				local activeW = Utils.getActiveWeather()

				PredUI.lblCurrent.Text = string.format("Live: %s | %s", activeW, tod)

				local lines = {}
				for _, w in ipairs(weatherData) do
					local rem = w.interval - (now % w.interval)
					local m = math.floor(rem / 60)
					local s = rem % 60
					table.insert(lines, string.format('<font color="%s">%s</font> in %dm %ds', w.color, w.name, m, s))
				end
				PredUI.lblPred.Text = table.concat(lines, "\n")
			end

			PredUI.gardenFrame.Visible = State.showGardenVal
			if State.showGardenVal then
				PredUI.gardenText.Text = string.format(
					'<font color="#7cd675">ðŸŒ± Garden Stats</font>\n<font color="#cccccc">Plants: %d\nGarden: Â¢%s\nInv: Â¢%s</font>',
					Cache.plantCount,
					Utils.abbreviate(Cache.gardenTotal),
					Utils.abbreviate(Cache.invTotal)
				)
			end
		end)
	end
end))

-- [12] CHARACTER CACHE

local function onCharAdded(char)
	Cache.char = char
	Cache.hrp = char:WaitForChild("HumanoidRootPart", 5)
	Cache.hum = char:WaitForChild("Humanoid", 5)
end

if LP.Character then
	onCharAdded(LP.Character)
end
GlobalTrove:AddConnection(LP.CharacterAdded:Connect(onCharAdded))

-- [13] EXPLOIT (Freeze / God Mode / Fling)

-- Freeze character
GlobalTrove:AddThread(task.spawn(function()
	while true do
		task.wait(0.5)
		pcall(function()
			if State.isFrozen and Cache.hrp then
				Cache.hrp.Anchored = true
			end
		end)
	end
end))

-- God mode (block damage remotes)
GlobalTrove:AddThread(task.spawn(function()
	pcall(function()
		if not hookfunction then
			return
		end
		local Net = Modules.Networking
		local oldFire
		oldFire = hookfunction(Net.AntiAfk.RequestHop.Fire, function(self, ...)
			if State.antiAFK and self == Net.AntiAfk.RequestHop then
				return
			end
			if State.godMode then
				local blocked = {
					Net.Bee and Net.Bee.Sting,
					Net.FlytrapService and Net.FlytrapService.Chomp,
					Net.GhostPepperService and Net.GhostPepperService.TouchBegan,
					Net.PoisonIvyService and Net.PoisonIvyService.TouchBegan,
				}
				for _, b in ipairs(blocked) do
					if self == b then
						return
					end
				end
			end
			return oldFire(self, ...)
		end)
	end)
end))

-- [14] UI SETUP

local ZuperMing = loadstring(game:HttpGet("https://raw.githubusercontent.com/kirsia-dev/Zuperming/refs/heads/main/ZuperMingGUI.lua"))()

ZuperMing:SetTheme("Grey")

local Window = ZuperMing:CreateWindow({
    Title = "ZuperMing",
    Description = "| GaG 2 | v1.0",
    ["Tab Width"] = 120,
    Acrylic = false,
    Theme = "Grey"
})

ZuperMing:SetNotification({
    Title = "ZuperMing |",
    Description = "Grow A Garden 2",
    Content = "Script loaded successfully!",
    Time = 0.5,
    Delay = 5,
})

-- [15] UI TABS & SECTIONS

local Tabs = {
    Farm = Window:CreateTab({ Name = "Farming", Icon = "sprout" }),
    Shop = Window:CreateTab({ Name = "Shop", Icon = "shopping-bag" }),
    Mgmt= Window:CreateTab({ Name = "Storage", Icon = "archive" }),
    Finder = Window:CreateTab({ Name = "Finder", Icon = "search" }),
    Webhook = Window:CreateTab({ Name = "Webhooks", Icon = "webhook" }),
    Misc = Window:CreateTab({ Name = "Miscellaneous", Icon = "setting" }),
    Settings = Window:CreateTab({ Name = "Settings", Icon = "settings" }),
}

-- Helper dropdown callback
local function toArr(v)
	return type(v) == "table" and v or { v }
end

-- [FARM TAB]
do
	local HarvestGroup = Tabs.Farm:AddSection({ "Harvesting" })
	HarvestGroup:AddDropdown({
		Title = "Select Name",
		Options = table.move(Const.SeedList, 1, #Const.SeedList, 2, { "All" }),
		Default = "All",
		Callback = function(v)
			State.targetHarvest = toArr(v)
		end,
	})
	HarvestGroup:AddDropdown({
		Title = "Select Mutation",
		Options = Const.MutationList,
		Default = "Any",
		Callback = function(v)
			State.targetHarvestMut = toArr(v)
		end,
	})
	HarvestGroup:AddDropdown({
		Title = "Pause on Weather",
		Options = Const.WeatherList,
		Default = "None",
		Callback = function(v)
			State.pauseHarvestWeather = toArr(v)
		end,
	})
	HarvestGroup:AddInput({
		Title = "Min Weight (Kg)",
		PlaceHolder = "0",
		Default = "0",
		Callback = function(t)
			State.minHarvestKg = tonumber(t) or 0
		end,
	})
	HarvestGroup:AddInput({
		Title = "Max Weight (Kg)",
		PlaceHolder = "9999",
		Default = "9999",
		Callback = function(t)
			State.maxHarvestKg = tonumber(t) or 9999
		end,
	})
	HarvestGroup:AddToggle({
		Title = "Auto Harvest",
		Default = false,
		Callback = function(s)
			State.autoHarvest = s
			if s then
				Features.startAutoHarvest()
			else
				stopFeature("autoHarvest")
			end
		end,
	})
	HarvestGroup:AddToggle({
		Title = "Auto Trowel",
		Default = false,
		Callback = function(s)
			State.autoTrowel = s
			if s then Features.startAutoTrowel() else stopFeature("autoTrowel") end
		end,
	})

	local PlantGroup = Tabs.Farm:AddSection({ "Planting" })
	PlantGroup:AddDropdown({
		Title = "Select Seed Name",
		Options = table.move(Const.SeedList, 1, #Const.SeedList, 2, { "All" }),
		Default = "All",
		Callback = function(v)
			State.targetPlant = toArr(v)
		end,
	})
	PlantGroup:AddDropdown({
		Title = "Select Mutation",
		Options = Const.MutationList,
		Default = "Any",
		Callback = function(v)
			State.targetPlantMut = toArr(v)
		end,
	})
	PlantGroup:AddInput({
		Title = "Grid Distance (Studs)",
		PlaceHolder = "1.5",
		Callback = function(t)
			local v = tonumber(t)
			State.gridSpacing = (v and v >= 1.2) and v or 1.5
		end,
	})
	PlantGroup:AddInput({
		Title = "Plant Limit (0=Inf)",
		PlaceHolder = "0",
		Callback = function(t)
			State.plantLimit = tonumber(t) or 0
		end,
	})
	PlantGroup:AddToggle({
		Title = "Auto Plant",
		Default = false,
		Callback = function(s)
			State.autoPlant = s
			if s then
				Features.startAutoPlant()
			else
				stopFeature("autoPlant")
			end
		end,
	})

	local ShovelGroup = Tabs.Farm:AddSection({ Title = "Shoveling" })
	ShovelGroup:AddDropdown({
		Title = "Select Name",
		Options = table.move(Const.SeedList, 1, #Const.SeedList, 2, { "All" }),
		Default = "All",
		Callback = function(v)
			State.targetShovel = toArr(v)
		end,
	})
	ShovelGroup:AddToggle({
		Title = "Auto Shovel Dead/Decaying",
		Default = false,
		Callback = function(s)
			State.shovelDead = s
			if s or State.autoShovel then
				Features.startAutoShovel()
			else
				stopFeature("autoShovel")
			end
		end,
	})
	ShovelGroup:AddToggle({
		Title = "Auto Shovel",
		Default = false,
		Callback = function(s)
			State.autoShovel = s
			if s or State.shovelDead then
				Features.startAutoShovel()
			else
				stopFeature("autoShovel")
			end
		end,
	})

	local SafetyGroup = Tabs.Farm:AddSection({ "Movements" })
	SafetyGroup:AddDropdown({
		Title = "Movement Method",
		Options = { "Semi-Tween", "Teleport Instant" },
		Default = "Semi-Tween",
		Callback = function(v)
			State.moveMethod = v
		end,
	})
	SafetyGroup:AddDropdown({
		Title = "Interact Method",
		Options = { "Hold Proximity", "Instant Proximity" },
		Default = "Hold Proximity",
		Callback = function(v)
			State.interactMethod = v
		end,
	})

	local WaterGroup = Tabs.Farm:AddSection({ "Watering" })
	WaterGroup:AddDropdown({
		Title = "Select Watering Can",
		Options = { "Common Watering Can", "Super Watering Can" },
		Default = "Common Watering Can",
		Callback = function(v)
			State.waterCan = v
		end,
	})
	WaterGroup:AddDropdown({
		Title = "Select Plant",
		Options = table.move(Const.SeedList, 1, #Const.SeedList, 2, { "All" }),
		Default = "All",
		Callback = function(v)
			State.waterPlant = toArr(v)
		end,
	})
	WaterGroup:AddToggle({
		Title = "Auto Water Plants",
		Default = false,
		Callback = function(s)
			State.autoWater = s
			if s then
				Features.startAutoWater()
			else
				stopFeature("autoWater")
			end
		end,
	})

	local SprinklerGroup = Tabs.Farm:AddSection({ "Sprinklers" })
	SprinklerGroup:AddDropdown({
		Title = "Select Sprinkler",
		Options = {
			"Common Sprinkler",
			"Uncommon Sprinkler",
			"Rare Sprinkler",
			"Legendary Sprinkler",
			"Super Sprinkler",
		},
		Default = "Common Sprinkler",
		Callback = function(v)
			State.sprinklerType = v
		end,
	})
	SprinklerGroup:AddInput({
		Title = "Sprinkler Grid (Studs)",
		PlaceHolder = "8",
		Callback = function(t)
			local v = tonumber(t)
			State.sprinklerSpacing = (v and v >= 2) and v or 8
		end,
	})
	SprinklerGroup:AddToggle({
		Title = "Auto Place Sprinklers",
		Default = false,
		Callback = function(s)
			State.autoSprinkler = s
			if s then
				Features.startAutoSprinkler()
			else
				stopFeature("autoSprinkler")
			end
		end,
	})

	local StealGroup = Tabs.Farm:AddSection({ "Auto Stealing" })
	StealGroup:AddDropdown({
		Title = "Steal Sort",
		Options = { "Any", "Highest Value", "Lowest Value" },
		Default = "Highest Value",
		Callback = function(v)
			State.stealMode = v
		end,
	})
	StealGroup:AddDropdown({
		Title = "Select Fruit",
		Options = table.move(Const.SeedList, 1, #Const.SeedList, 2, { "All" }),
		Default = "All",
		Callback = function(v)
			State.targetSteal = toArr(v)
		end,
	})
	StealGroup:AddInput({
		Title = "Min Value/Multiplier",
		PlaceHolder = "0",
		Callback = function(t)
			State.stealMinValue = tonumber(t) or 0
		end,
	})
	StealGroup:AddInput({
		Title = "Return After X Stolen",
		PlaceHolder = "50",
		Callback = function(t)
			local v = tonumber(t)
			State.stealReturnLimit = (v and v > 0) and v or 50
		end,
	})
	StealGroup:AddToggle({
		Title = "Auto Rejoin After Steal",
		Default = false,
		Callback = function(s)
			State.autoRejoin = s
		end,
	})
	StealGroup:AddToggle({
		Title = "Auto Anti-Stealing",
		Default = false,
		Callback = function(s)
			State.antiSteal = s
			if s then
				Features.startAntiSteal()
			else
				stopFeature("antiSteal")
			end
		end,
	})
	StealGroup:AddToggle({
		Title = "Enable Auto Steal",
		Default = false,
		Callback = function(s)
			State.autoSteal = s
			Cache.stealInProgress = false
			if s then
				Features.startAutoSteal()
			else
				stopFeature("autoSteal")
			end
		end,
	})
	StealGroup:AddButton({
		Title = "Set Garden Base Position",
		Callback = function()
			if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
				State.savedGardenCF = LP.Character.HumanoidRootPart.CFrame
				Library:Notify({ Title = "Auto Steal", Title = "Garden position saved!", Lifetime = 3 })
			end
		end,
	})

	local CollectGroup = Tabs.Farm:AddSection({ "Collecting" })
	CollectGroup:AddDropdown({
		Title = "Mode",
		Options = { "Collect All", "Collect & Back" },
		Default = "Collect All",
		Callback = function(v)
			State.collectMode = v
		end,
	})
	CollectGroup:AddDropdown({
		Title = "Target",
		Options = { "All", "Gold", "Rainbow", "Random Seed" },
		Default = "Gold",
		Callback = function(v)
			State.collectTargets = toArr(v)
		end,
	})
	CollectGroup:AddInput({
		Title = "Back Delay (sec)",
		PlaceHolder = "4",
		Callback = function(t)
			local v = tonumber(t)
			State.collectDelay = (v and v > 0) and v or 4
		end,
	})
	CollectGroup:AddToggle({
		Title = "Auto Collect Drops",
		Default = false,
		Callback = function(s)
			State.autoCollect = s
			Cache.collectActive = false
			Cache.collectIdle = 0
			if s then
				Features.startAutoCollect()
			else
				stopFeature("autoCollect")
			end
		end,
	})

	local EspGroup = Tabs.Farm:AddSection({ "Visuals" })
	EspGroup:AddToggle({
		Title = "ESP Players",
		Default = false,
		Callback = function(s)
			State.espPlayers = s
		end,
	})
	EspGroup:AddToggle({
		Title = "ESP Plants",
		Default = false,
		Callback = function(s)
			State.espPlants = s
		end,
	})
	EspGroup:AddToggle({
		Title = "ESP Wild Pets",
		Default = false,
		Callback = function(s)
			State.espPets = s
		end,
	})
	EspGroup:AddToggle({
		Title = "Show Name",
		Default = true,
		Callback = function(s)
			State.espShowName = s
		end,
	})
	EspGroup:AddToggle({
		Title = "Show Mutation",
		Default = true,
		Callback = function(s)
			State.espShowMut = s
		end,
	})
	EspGroup:AddToggle({
		Title = "Show Multiplier",
		Default = true,
		Callback = function(s)
			State.espShowKg = s
		end,
	})
	EspGroup:AddToggle({
		Title = "Show Value",
		Default = true,
		Callback = function(s)
			State.espShowVal = s
		end,
	})
	EspGroup:AddToggle({
		Title = "Weather Predictor",
		Default = true,
		Callback = function(s)
			State.showWeather = s
		end,
	})
	EspGroup:AddToggle({
		Title = "Show Garden Value",
		Default = false,
		Callback = function(s)
			State.showGardenVal = s
		end,
	})
end

-- [SHOP TAB]
do
	local SellGroup = Tabs.Shop:AddSection({ "Selling", })
	SellGroup:AddDropdown({
		Title = "Select Fruit",
		Options = table.move(Const.SeedList, 1, #Const.SeedList, 2, { "All" }),
		Default = "All",
		Callback = function(v)
			State.targetSell = toArr(v)
		end,
	})
	SellGroup:AddInput({
		Title = "Timer Interval (Secs)",
		PlaceHolder = "60",
		Callback = function(t)
			local v = tonumber(t)
			State.sellInterval = (v and v > 0) and v or 60
		end,
	})
	SellGroup:AddToggle({
		Title = "Auto Sell on Backpack Full",
		Default = false,
		Callback = function(s)
			State.autoSellFull = s
			if s then
				Features.startAutoSell()
			end
		end,
	})
	SellGroup:AddToggle({
		Title = "Auto Sell on Timer",
		Default = false,
		Callback = function(s)
			State.autoSellTimer = s
			Cache.sellTimer = 0
			if s then
				Features.startAutoSell()
			end
		end,
	})
	SellGroup:AddToggle({
		Title = "Auto Sell",
		Default = false,
		Callback = function(s)
			State.autoSell = s
        end,
	})
	SellGroup:AddToggle({
		Title = "Auto Bargain (AskBid)",
		Default = false,
		Callback = function(s)
			State.autoBargain = s
			if s then
				Features.startAutoBargain()
			else
				stopFeature("autoBargain")
			end
		end,
	})
	SellGroup:AddToggle({
		Title = "Bargain Wait Full Backpack",
		Default = false,
		Callback = function(s) State.bargainWaitFull = s end,
	})
	SellGroup:AddInput({
		Title = "Wait Full Backpack Count",
		PlaceHolder = "100",
		Callback = function(t)
			local v = tonumber(t)
			if v and v > 0 then State.bargainWaitFullCount = v end
		end,
	})

	local BuyGroup = Tabs.Shop:AddSection({ "Shopping" })
	BuyGroup:AddDropdown({
		Title = "Select Seed/Pack",
		Options = Const.SeedList,
		Default = Const.SeedList[1] or "",
		Callback = function(v)
			State.targetBuySeed = toArr(v)
		end,
	})
	BuyGroup:AddToggle({
		Title = "Auto Buy Seed",
		Default = false,
		Callback = function(s)
			State.autoBuySeed = s
			if s then
				Features.startAutoBuy()
			else
				stopFeature("autoBuy")
			end
		end,
	})
	BuyGroup:AddDropdown({
		Title = "Select Crate",
		Options = Const.CrateList,
		Default = Const.CrateList[1] or "",
		Callback = function(v)
			State.targetBuyCrate = toArr(v)
		end,
	})
	BuyGroup:AddToggle({
		Title = "Auto Buy Crate",
		Default = false,
		Callback = function(s)
			State.autoBuyCrate = s
			if s then
				Features.startAutoBuy()
			else
				stopFeature("autoBuy")
			end
		end,
	})
	BuyGroup:AddDropdown({
		Title = "Select Gear",
		Options = Const.GearList or {},
		Default = (Const.GearList and Const.GearList[1]) or "",
		Callback = function(v) State.targetBuyGear = toArr(v) end,
	})
	BuyGroup:AddToggle({
		Title = "Auto Buy Gear",
		Default = false,
		Callback = function(s)
			State.autoBuyGear = s
			if s then Features.startAutoBuy() else stopFeature("autoBuy") end
		end,
	})

	local GachaGroup = Tabs.Shop:AddSection({ "Gacha & Loot" })
	GachaGroup:AddToggle({
		Title = "Auto Open Seed Packs",
		Default = false,
		Callback = function(s)
			State.autoOpenPacks = s
			if s then
				Features.startAutoOpen()
			else
				stopFeature("autoOpen")
			end
		end,
	})
	GachaGroup:AddToggle({
		Title = "Auto Open Crates",
		Default = false,
		Callback = function(s)
			State.autoOpenCrates = s
			if s then
				Features.startAutoOpen()
			end
		end,
	})
	GachaGroup:AddToggle({
		Title = "Auto Open Eggs",
		Default = false,
		Callback = function(s)
			State.autoOpenEggs = s
			if s then
				Features.startAutoOpen()
			end
		end,
	})
	GachaGroup:AddToggle({
		Title = "Auto Expand Garden",
		Default = false,
		Callback = function(s)
			State.autoExpand = s
			if s then
				Features.startAutoBuy()
			end
		end,
	})
	GachaGroup:AddToggle({
		Title = "Auto Purchase Pet Slots",
		Default = false,
		Callback = function(s)
			State.autoBuyPetSlot = s
			if s then
				Features.startAutoBuy()
			end
		end,
	})

	local AuctionGroup = Tabs.Shop:AddSection({ "Auction Sniper" })
	AuctionGroup:AddDropdown({
		Title = "Filter by Category (0=all)",
		Options = { "Seeds", "Crates", "Eggs", "SeedPacks", "Gear" },
		Default = "",
		Callback = function(val)
			local d = {}
			for _, v in ipairs(toArr(val)) do d[v] = true end
			State.auctionCategories = d
		end,
	})
	AuctionGroup:AddDropdown({
		Title = "Buy Mode",
		Options = { "Lowest Only", "All Matches" },
		Default = "Lowest Only",
		Callback = function(val) State.auctionBuyMode = val end,
	})
	AuctionGroup:AddInput({
		Title = "Max Price (0=no limit)",
		PlaceHolder = "0",
		Callback = function(val) State.auctionMaxPrice = tonumber(val) or 0 end,
	})
	AuctionGroup:AddToggle({
		Title = "Skip Sold-Out Lots",
		Default = true,
		Callback = function(v) State.auctionCheckStock = v end,
	})
	AuctionGroup:AddToggle({
		Title = "Enable Auto Auction Buy",
		Default = false,
		Callback = function(v)
			State.autoAuction = v
			if v then
				Features.startAutoAuction()
			else
				stopFeature("autoAuction")
			end
		end,
	})
end

-- [MGMT TAB]
do
	local DoNGroup = Tabs.Mgmt:AddSection({ "Double Or Nothing" })
	DoNGroup:AddSlider({
		Title = "Target Wins (Cashout)",
		Min = 1,
		Max = 10,
		Default = 2,
		Callback = function(v)
			State.gambleTarget = v
		end,
	})
	DoNGroup:AddToggle({
		Title = "Auto Double or Nothing",
		Default = false,
		Callback = function(s)
			State.autoGamble = s
			if s then
				Features.startAutoGamble()
			else
				stopFeature("autoGamble")
			end
		end,
	})

	local InvGroup = Tabs.Mgmt:AddSection({ "Favorite / Unfavorite" })
	InvGroup:AddDropdown({
		Title = "Select Fruit",
		Options = table.move(Const.SeedList, 1, #Const.SeedList, 2, { "All" }),
		Default = "All",
		Callback = function(v)
			State.targetFavFruits = toArr(v)
		end,
	})
	InvGroup:AddToggle({
		Title = "Auto Favorite",
		Default = false,
		Callback = function(s)
			State.autoFav = s
			if s then
				Features.startAutoFav()
			else
				stopFeature("autoFav")
			end
		end,
	})
	InvGroup:AddToggle({
		Title = "Auto Unfavorite",
		Default = false,
		Callback = function(s)
			State.autoUnfav = s
			if s then
				Features.startAutoFav()
			else
				stopFeature("autoFav")
			end
		end,
	})

	local MailGroup = Tabs.Mgmt:AddSection({ "Mailbox & Gifts" })
	MailGroup:AddToggle({
		Title = "Auto Claim All Mailbox",
		Default = false,
		Callback = function(s)
			State.autoClaimMail = s
			if s then
				Features.startAutoMail()
			else
				stopFeature("autoMail")
			end
		end,
	})
	MailGroup:AddToggle({
		Title = "Auto Accept All Gifts",
		Default = false,
		Callback = function(s)
			State.autoAcceptGift = s
		end,
	})
	MailGroup:AddInput({
		Title = "Gift Target Username",
		PlaceHolder = "Target Name...",
		Callback = function(t) State.giftTarget = t end,
	})
	MailGroup:AddToggle({
		Title = "Auto Send Gifts",
		Default = false,
		Callback = function(s)
			State.autoGift = s
			if s then Features.startAutoGift() else stopFeature("autoGift") end
		end,
	})
end

-- [FINDER TAB]
do
	local FinderGroup = Tabs.Finder:AddSection({ "Server & Pet Finder" })
	FinderGroup:AddButton({
		Title = "Launch Pet/Server Finder",
		Callback = function()
			pcall(function()
				loadstring(game:HttpGet("https://raw.githubusercontent.com/x2zu/loader/main/ui-main/sffinder.lua"))()
			end)
		end,
	})
end

-- [WEBHOOK TAB]
do
	local WebGroup = Tabs.Webhook:AddSection({ "Discord Webhook" })
	WebGroup:AddInput({
		Title = "Webhook URL",
		PlaceHolder = "https://discord.com/api/webhooks/...",
		Callback = function(t) State.webhookUrl = t end,
	})
	WebGroup:AddInput({
		Title = "Interval (Seconds)",
		PlaceHolder = "60",
		Default = "60",
		Callback = function(t)
			local v = tonumber(t)
			if v and v > 0 then State.webhookInterval = v end
		end,
	})
	WebGroup:AddToggle({
		Title = "Enable Webhook Updates",
		Default = false,
		Callback = function(s)
			State.webhookEnabled = s
			if s then Features.startWebhook() else stopFeature("webhook") end
		end,
	})
end

-- [MISC TAB]
do
	local MiscGroup = Tabs.Misc:AddSection({ "Miscellaneous" })
	MiscGroup:AddToggle({
		Title = "Anti-AFK",
		Default = true,
		Callback = function(s)
			State.antiAFK = s
			if s then
				Features.startAntiAFK()
			else
				stopFeature("antiAFK")
			end
		end,
	})
	MiscGroup:AddToggle({
		Title = "Auto Skip Cutscene",
		Default = true,
		Callback = function(s)
			State.autoSkip = s
			if s then
				Features.startAutoSkip()
			else
				stopFeature("autoSkip")
			end
		end,
	})
	local ExploitGroup = Tabs.Misc:AddSection({ "Exploits" })
	ExploitGroup:AddToggle({
		Title = "God Mode",
		Default = false,
		Callback = function(s)
			State.godMode = s
		end,
	})
	ExploitGroup:AddToggle({
		Title = "Freeze Character",
		Default = false,
		Callback = function(s)
			State.isFrozen = s
			if Cache.hrp then
				Cache.hrp.Anchored = s
			end
		end,
	})

	local UtilGroup = Tabs.Misc:AddSection({ "Utility & Visuals" })
	UtilGroup:AddSlider({
		Title = "WalkSpeed",
		Min = 16,
		Max = 200,
		Default = 16,
		Callback = function(v) State.walkSpeed = v end,
	})
	UtilGroup:AddToggle({
		Title = "Enable WalkSpeed Override",
		Default = false,
		Callback = function(s)
			State.walkSpeedEnabled = s
			if s then Features.startUtilityLoop() else stopFeature("utilityLoop") end
		end,
	})
	UtilGroup:AddToggle({
		Title = "Instant Proximity Prompts",
		Default = false,
		Callback = function(s)
			State.instantPrompt = s
			if s then Features.startUtilityLoop() else stopFeature("utilityLoop") end
		end,
	})
	UtilGroup:AddToggle({
		Title = "Low Graphic Mode",
		Default = false,
		Callback = function(s)
			State.lowGraphic = s
			if s then Features.startGraphicOptimization() else stopFeature("graphicOpt") end
		end,
	})
	UtilGroup:AddToggle({
		Title = "No Particles",
		Default = false,
		Callback = function(s)
			State.noParticles = s
			if s then Features.startGraphicOptimization() else stopFeature("graphicOpt") end
		end,
	})
	UtilGroup:AddToggle({
		Title = "Hide Plants (Client Side)",
		Default = false,
		Callback = function(s)
			State.hidePlants = s
			if s then Features.startGraphicOptimization() else stopFeature("graphicOpt") end
		end,
	})
end

-- [SETTINGS TAB]
do
	local SystemGroup = Tabs.Settings:AddSection({ "System" })
	
	SystemGroup:AddButton({
		Title = "Unload Script",
		Callback = function()
			if Library and Library.Unload then
				Library:Unload()
			end
			
			getgenv().Zuperming_Running = false
			
			if GlobalTrove then
				GlobalTrove:Clean()
			end
			for _, trove in pairs(FeatureTroves) do
				trove:Clean()
			end
		end
	})
end

-- [16] AUTO-START FEATURES

Features.startAntiAFK()
Features.startAutoSkip()

-- [17] NOTIFY

ZuperMing:SetNotification({
    Title = "ZuperMing |",
    Description = "Script Loaded",
    Content = "Welcome to ZuperMing Hub.",
    Time = 0.5,
    Delay = 5,
})
