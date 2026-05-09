-- =====================================================================
-- 🎲 POODLE HUD - RNG EVENT CORE (BASE FRAMEWORK)
-- 🎁 CHUẨN BỊ CHO BẢN CẬP NHẬT TỐI NAY
-- =====================================================================
if _G.RNGEventStarted then return end
_G.RNGEventStarted = true

-- ==========================================
-- 1. CẤU HÌNH NGOẠI VI (GETGENV)
-- ==========================================
local config = getgenv().RNGConfig or {
    WebhookURL = "",
    PingID = "",               -- ID Discord để ping khi ra Huge/Titanic
    Blackout = true,           -- Bật/Tắt màn hình đen tối ưu FPS
    AutoTrade = true,          -- Bật/Tắt Auto Trade (Load từ Github)
    EventInstanceID = "rngevent" -- Tên map sự kiện (cần check lại vào tối nay)
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
-- 4. DỊCH CHUYỂN VÀO MAP SỰ KIỆN
-- ==========================================
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            if InstancingCmds.GetInstanceID() ~= config.EventInstanceID then
                print("Đang dịch chuyển vào map sự kiện: " .. config.EventInstanceID)
                InstancingCmds.Enter(config.EventInstanceID)
            end
        end)
    end
end)

-- ==========================================
-- 5. TỐI ƯU HÓA FPS & CHỐNG AFK
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
-- 6. AUTO GIFTS, MAIL & DYNAMIC AUTO TRADE
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

-- Auto Trade (Load script từ Github)
if config.AutoTrade then
    task.spawn(function()
        local success, err = pcall(function()
            local codeString = ""
            
            local httprequest = (request or http_request or syn and syn.request)
            if httprequest then
                local response = httprequest({
                    Url = "https://raw.githubusercontent.com/thuyan1510/99/refs/heads/main/give.lua",
                    Method = "GET"
                })
                if response.StatusCode == 200 then
                    codeString = response.Body
                else
                    error("Mã lỗi mạng: " .. tostring(response.StatusCode))
                end
            else
                -- Dự phòng nếu executor không hỗ trợ request
                codeString = game:HttpGet("https://raw.githubusercontent.com/thuyan1510/99/refs/heads/main/give.lua")
            end
            
            if type(codeString) == "string" then
                local loadedScript, compileErr = loadstring(codeString)
                if loadedScript then
                    loadedScript()
                    print("[AT] Script loaded successfully!")
                else
                    error(" " .. tostring(compileErr))
                end
            else
                error(" " .. type(codeString))
            end
        end)
        
        if not success then
            warn("[ERROR AUTO TRADE]: " .. tostring(err))
        end
    end)
end

-- ==========================================
-- 7. WEBHOOK TRACKER
-- ==========================================
task.spawn(function()
    local httprequest = (request or http_request or syn and syn.request)
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
-- 8. GIAO DIỆN NỀN ĐEN & THỐNG KÊ (UI)
-- ==========================================
if CoreGui:FindFirstChild("RNGCrawlerHUD") then CoreGui.RNGCrawlerHUD:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RNGCrawlerHUD"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local Container = Instance.new("Frame", ScreenGui)
Container.Size = UDim2.new(0, 300, 0, 260)
Container.Position = UDim2.new(0.5, 0, 0.5, 0)
Container.AnchorPoint = Vector2.new(0.5, 0.5)
Container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Container.BorderSizePixel = 0
Instance.new("UICorner", Container).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", Container).Color = Color3.fromRGB(150, 0, 255)

local Layout = Instance.new("UIListLayout", Container)
Layout.Padding = UDim.new(0, 6)
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Layout.VerticalAlignment = Enum.VerticalAlignment.Center

local function CreateLabel(text, color)
    local lbl = Instance.new("TextLabel", Container)
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    lbl.Text = text
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
