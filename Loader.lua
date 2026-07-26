repeat task.wait() until game.Players.LocalPlayer and game.Players.LocalPlayer.Character
if not game:IsLoaded() then game.Loaded:Wait() end

local gameId = game.GameId
local StarterGui = game:GetService("StarterGui")

local gameScripts = {
    [10200395747] = {
        name = "Grow A Garden 2",
        Zuper = "https://raw.githubusercontent.com/kirsia-dev/Zuperming/refs/heads/main/GaG2-obfuscated.lua"
    },
    [6739698191] = {
        name = "Violence District",
        Zuper = "https://raw.githubusercontent.com/kirsia-dev/Zuperming/refs/heads/main/Vd-obfuscated.lua"
    }
}

local gameData = gameScripts[gameId]
local gameName = gameData and gameData.name or "Unknown Game"

StarterGui:SetCore("SendNotification", {
    Title = "ZuperMing",
    Text = "Detected game: " .. gameName,
    Duration = 3
})

task.wait(2)

if gameData then
    StarterGui:SetCore("SendNotification", {
        Title = "ZuperMing",
        Text = "Loading ZuperMing for " .. gameName .. "...",
        Duration = 3
    })
    loadstring(game:HttpGet(gameData.Zuper))()
else
    StarterGui:SetCore("SendNotification", {
        Title = "ZuperMing",
        Text = "Game not supported!",
        Duration = 4
    })
    game.Players.LocalPlayer:Kick("Game not supported!")
end
