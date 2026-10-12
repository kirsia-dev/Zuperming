repeat task.wait() until game:IsLoaded()

if game.GameId ~= 5750914919 then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "ZuperMing",
        Text = "Game not supported",
        Duration = 5,
    })
    return
end

local api = loadstring(game:HttpGet("https://sdkapi-public.luarmor.net/library.lua"))()
api.script_id = "f4637e4007980627b00ad48cf9370ea2"

local KEY_LINK = "YOUR_KEY_LINK"
local DISCORD = "https://discord.gg/wpubHwymwQ"
local FILE = "ZuperMing_Key.txt"

local function check(key)
    key = tostring(key or ""):gsub("%s+", "")
    if #key ~= 32 then
        return false, { code = "KEY_FORMAT" }, key
    end
    local status = api.check_key(key)
    return status.code == "KEY_VALID", status, key
end

local function launch(key)
    pcall(writefile, FILE, key)
    getgenv().script_key = key
    api.load_script()
end

local preset = getgenv().script_key
if preset then
    local ok, _, key = check(preset)
    if ok then return launch(key) end
end

local okRead, saved = pcall(readfile, FILE)
if okRead and saved and saved ~= "" then
    local ok, _, key = check(saved)
    if ok then return launch(key) end
end

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

local Blue = Color3.fromRGB(56, 140, 255)
local BlueHex = "rgb(56,140,255)"

Library.Scheme.BackgroundColor = Color3.fromRGB(15, 15, 15)
Library.Scheme.MainColor = Color3.fromRGB(25, 25, 25)
Library.Scheme.OutlineColor = Color3.fromRGB(40, 40, 40)
Library.Scheme.AccentColor = Blue

local Window = Library:CreateWindow({
    Title = "ZuperMing - Fisch",
    Footer = "Key System - discord.gg/wpubHwymwQ",
    NotifySide = "Right",
    ShowCustomCursor = false,
})

Library:UpdateColorsUsingRegistry()

local KeyTab = Window:AddTab("Key System", "key-round")
local KeyBox = KeyTab:AddLeftGroupbox("Key")
local InfoBox = KeyTab:AddRightGroupbox("Information")

local function notify(title, desc)
    Library:Notify({ Title = title, Description = desc, Time = 5 })
end

local function verify(input)
    local ok, status, key = check(input)

    if ok then
        notify("Success", "Key is valid, loading script...")
        task.wait(1)
        Library:Unload()
        return launch(key)
    end

    local code = status.code
    if code == "KEY_FORMAT" then
        notify("Invalid Key", "The key must be 32 characters long.")
    elseif code == "KEY_HWID_LOCKED" then
        notify("Key Locked", "This key is locked to another device.")
    elseif code == "KEY_INCORRECT" then
        notify("Incorrect Key", "The key is incorrect or does not exist.")
    else
        notify("Failed", tostring(status.message or code))
    end
end

KeyBox:AddInput("KeyInput", {
    Text = "Input",
    Placeholder = "Enter your key here...",
})

KeyBox:AddButton({
    Text = "Enter",
    Func = function()
        verify(Library.Options.KeyInput.Value)
    end,
})

KeyBox:AddButton({
    Text = "Copy Key Link",
    Func = function()
        setclipboard(KEY_LINK)
        notify("Copied", "Key link copied to clipboard.")
    end,
})

InfoBox:AddLabel(
    '<font color="' .. BlueHex .. '">Upgrade to premium?</font>\nGet premium from our Discord server to support us and skip the key system.',
    true
)
InfoBox:AddLabel(
    '<font color="' .. BlueHex .. '">How do checkpoints work?</font>\nComplete the checkpoints to receive your free key, then paste it into the input box.',
    true
)

InfoBox:AddButton({
    Text = "Copy Discord",
    Func = function()
        setclipboard(DISCORD)
        notify("Copied", "Discord link copied to clipboard.")
    end,
})
