-- Auto Joiner - Dual API Version (Brainrot Edition)
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BRAINROT_API_URL = "https://roblox-brainrot-api.vercel.app/api/brainrot-data"
local SIMPLE_API_URL = "https://auto-joiner-api.squareweb.app/get_clipboard"
local USED_JOBIDS_FILE = "used_jobids.json"

-- Configuration
local CHECK_INTERVAL = 2 -- Increased from 0.1 to reduce lag

local autoJoinerEnabled = false
local currentMode = "none" -- "brainrot" or "simple"
local usedJobIds = {}
local teleportAttempts = {}
local currentJobId = tostring(game.JobId or "")

-- Load data functions
local function loadUsedJobIds()
    pcall(function()
        if isfile and isfile(USED_JOBIDS_FILE) then
            local raw = readfile(USED_JOBIDS_FILE)
            if raw and #raw > 0 then
                local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
                if ok and type(decoded) == "table" then
                    usedJobIds = decoded
                end
            end
        end
    end)
end

local function saveUsedJobIds()
    pcall(function()
        if writefile then
            writefile(USED_JOBIDS_FILE, HttpService:JSONEncode(usedJobIds))
        end
    end)
end

-- Function to extract Job ID from the "Job ID: " prefix
local function extractJobId(jobIdString)
    if jobIdString and type(jobIdString) == "string" then
        local jobId = jobIdString:match("Job ID:%s*(.+)")
        if jobId then
            return jobId:gsub("%s+", "") -- Remove any extra whitespace
        end
    end
    return nil
end

-- Initialize
loadUsedJobIds()

if currentJobId ~= "" then
    usedJobIds[currentJobId] = true
    saveUsedJobIds()
end

-- Draggable frames helper
local function makeDraggable(frame, dragArea)
    dragArea = dragArea or frame
    local dragging = false
    local dragStart = Vector2.new()
    local startPos = UDim2.new()

    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragArea.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Create a small shadow that is *relative to the frame*
local function createShadow(parent)
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 6, 1, 6)
    shadow.Position = UDim2.new(0, 3, 0, 3)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.8
    shadow.BorderSizePixel = 0
    shadow.ZIndex = (parent.ZIndex or 2) - 1
    shadow.Parent = parent

    local shadowCorner = Instance.new("UICorner", shadow)
    shadowCorner.CornerRadius = UDim.new(0, 10)

    return shadow
end

local function animateButton(button, hoverColor, originalColor, scaleAmount)
    scaleAmount = scaleAmount or 3
    button.MouseEnter:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = hoverColor,
            Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset + scaleAmount, button.Size.Y.Scale, button.Size.Y.Offset + 1)
        })
        tween:Play()
    end)
    button.MouseLeave:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = originalColor,
            Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset - scaleAmount, button.Size.Y.Scale, button.Size.Y.Offset - 1)
        })
        tween:Play()
    end)
end

function showMainInterface()
    -- Build Main GUI (More Compact)
    local autoJoinerGui = Instance.new("ScreenGui")
    autoJoinerGui.Name = "BrainrotAutoJoiner"
    autoJoinerGui.Parent = PlayerGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 380, 0, 320) -- Reduced height from 420 to 320
    mainFrame.Position = UDim2.new(0.5, -190, 0.5, -160)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.ZIndex = 2
    mainFrame.Parent = autoJoinerGui

    local mainShadow = createShadow(mainFrame)

    local mainGradient = Instance.new("UIGradient", mainFrame)
    mainGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 33, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 23, 30))
    }
    mainGradient.Rotation = 90

    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 10)

    local mainStroke = Instance.new("UIStroke", mainFrame)
    mainStroke.Color = Color3.fromRGB(55, 60, 70)
    mainStroke.Thickness = 1
    mainStroke.Transparency = 0.3

    makeDraggable(mainFrame)

    local headerBg = Instance.new("Frame", mainFrame)
    headerBg.Size = UDim2.new(1, 0, 0, 50) -- Reduced from 60 to 50
    headerBg.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
    headerBg.BackgroundTransparency = 0.2
    headerBg.BorderSizePixel = 0
    headerBg.ZIndex = 3
    local headerBgCorner = Instance.new("UICorner", headerBg)
    headerBgCorner.CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel", mainFrame)
    title.Size = UDim2.new(1, 0, 0, 35) -- Reduced from 40 to 35
    title.Position = UDim2.new(0, 0, 0, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16 -- Reduced from 18
    title.Text = "🧠 BRAINROT JOINER"
    title.TextColor3 = Color3.fromRGB(240, 245, 255)
    title.ZIndex = 4

    -- User info card (more compact)
    local userCard = Instance.new("Frame", mainFrame)
    userCard.Size = UDim2.new(0.9, 0, 0, 35) -- Reduced from 45 to 35
    userCard.Position = UDim2.new(0.05, 0, 0, 60) -- Adjusted position
    userCard.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
    userCard.BackgroundTransparency = 0.2
    userCard.BorderSizePixel = 0
    userCard.ZIndex = 3
    local userCardCorner = Instance.new("UICorner", userCard)
    userCardCorner.CornerRadius = UDim.new(0, 8)

    local userCardStroke = Instance.new("UIStroke", userCard)
    userCardStroke.Color = Color3.fromRGB(70, 75, 85)
    userCardStroke.Thickness = 1
    userCardStroke.Transparency = 0.5

    local welcomeLabel = Instance.new("TextLabel", userCard)
    welcomeLabel.Size = UDim2.new(1, -20, 1, 0)
    welcomeLabel.Position = UDim2.new(0, 10, 0, 0)
    welcomeLabel.BackgroundTransparency = 1
    welcomeLabel.Font = Enum.Font.GothamBold
    welcomeLabel.TextSize = 11 -- Reduced from 13
    welcomeLabel.Text = string.format("Welcome, %s (@%s)", LocalPlayer.DisplayName, LocalPlayer.Name)
    welcomeLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
    welcomeLabel.TextXAlignment = Enum.TextXAlignment.Left
    welcomeLabel.ZIndex = 4

    -- Brainrot info card (only shows for premium mode)
    local brainrotCard = Instance.new("Frame", mainFrame)
    brainrotCard.Size = UDim2.new(0.9, 0, 0, 65) -- Reduced from 85 to 65
    brainrotCard.Position = UDim2.new(0.05, 0, 0, 105) -- Adjusted position
    brainrotCard.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
    brainrotCard.BackgroundTransparency = 0.2
    brainrotCard.BorderSizePixel = 0
    brainrotCard.ZIndex = 3
    brainrotCard.Visible = false
    local brainrotCardCorner = Instance.new("UICorner", brainrotCard)
    brainrotCardCorner.CornerRadius = UDim.new(0, 8)

    local brainrotCardStroke = Instance.new("UIStroke", brainrotCard)
    brainrotCardStroke.Color = Color3.fromRGB(70, 75, 85)
    brainrotCardStroke.Thickness = 1
    brainrotCardStroke.Transparency = 0.5

    local brainrotNameLabel = Instance.new("TextLabel", brainrotCard)
    brainrotNameLabel.Size = UDim2.new(1, -20, 0, 20) -- Reduced height
    brainrotNameLabel.Position = UDim2.new(0, 10, 0, 5)
    brainrotNameLabel.BackgroundTransparency = 1
    brainrotNameLabel.Font = Enum.Font.GothamBold
    brainrotNameLabel.TextSize = 10 -- Reduced from 12
    brainrotNameLabel.Text = "Brainrot: Waiting for data..."
    brainrotNameLabel.TextColor3 = Color3.fromRGB(255, 100, 150)
    brainrotNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    brainrotNameLabel.ZIndex = 4

    local brainrotGenLabel = Instance.new("TextLabel", brainrotCard)
    brainrotGenLabel.Size = UDim2.new(1, -20, 0, 20)
    brainrotGenLabel.Position = UDim2.new(0, 10, 0, 22)
    brainrotGenLabel.BackgroundTransparency = 1
    brainrotGenLabel.Font = Enum.Font.Gotham
    brainrotGenLabel.TextSize = 9 -- Reduced from 11
    brainrotGenLabel.Text = "Level: N/A"
    brainrotGenLabel.TextColor3 = Color3.fromRGB(140, 200, 140)
    brainrotGenLabel.TextXAlignment = Enum.TextXAlignment.Left
    brainrotGenLabel.ZIndex = 4

    local brainrotJobLabel = Instance.new("TextLabel", brainrotCard)
    brainrotJobLabel.Size = UDim2.new(1, -20, 0, 20)
    brainrotJobLabel.Position = UDim2.new(0, 10, 0, 39)
    brainrotJobLabel.BackgroundTransparency = 1
    brainrotJobLabel.Font = Enum.Font.GothamMedium
    brainrotJobLabel.TextSize = 8 -- Reduced from 9
    brainrotJobLabel.Text = "Job ID: N/A"
    brainrotJobLabel.TextColor3 = Color3.fromRGB(120, 130, 150)
    brainrotJobLabel.TextXAlignment = Enum.TextXAlignment.Left
    brainrotJobLabel.ZIndex = 4

    -- Status card (more compact)
    local statusCard = Instance.new("Frame", mainFrame)
    statusCard.Size = UDim2.new(0.9, 0, 0, 50) -- Reduced from 65 to 50
    statusCard.Position = UDim2.new(0.05, 0, 0, 180) -- Adjusted position
    statusCard.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
    statusCard.BackgroundTransparency = 0.2
    statusCard.BorderSizePixel = 0
    statusCard.ZIndex = 3
    local statusCardCorner = Instance.new("UICorner", statusCard)
    statusCardCorner.CornerRadius = UDim.new(0, 8)

    local statusCardStroke = Instance.new("UIStroke", statusCard)
    statusCardStroke.Color = Color3.fromRGB(70, 75, 85)
    statusCardStroke.Thickness = 1
    statusCardStroke.Transparency = 0.5

    local statusDot = Instance.new("Frame", statusCard)
    statusDot.Size = UDim2.new(0, 8, 0, 8) -- Reduced from 10 to 8
    statusDot.Position = UDim2.new(0, 12, 0, 10)
    statusDot.BackgroundColor3 = Color3.fromRGB(220, 85, 85)
    statusDot.BorderSizePixel = 0
    statusDot.ZIndex = 4
    local dotCorner = Instance.new("UICorner", statusDot)
    dotCorner.CornerRadius = UDim.new(1, 0)

    local statusLabel = Instance.new("TextLabel", statusCard)
    statusLabel.Size = UDim2.new(1, -35, 0, 20) -- Reduced height
    statusLabel.Position = UDim2.new(0, 30, 0, 6)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 12 -- Reduced from 14
    statusLabel.Text = "Offline"
    statusLabel.TextColor3 = Color3.fromRGB(220, 85, 85)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.ZIndex = 4

    local statusDesc = Instance.new("TextLabel", statusCard)
    statusDesc.Size = UDim2.new(1, -35, 0, 20)
    statusDesc.Position = UDim2.new(0, 30, 0, 24)
    statusDesc.BackgroundTransparency = 1
    statusDesc.Font = Enum.Font.Gotham
    statusDesc.TextSize = 9 -- Reduced from 11
    statusDesc.Text = "Ready to start - Choose a mode below"
    statusDesc.TextColor3 = Color3.fromRGB(140, 150, 170)
    statusDesc.TextXAlignment = Enum.TextXAlignment.Left
    statusDesc.ZIndex = 4

    -- Premium Button (Currently Disabled)
    local premiumButton = Instance.new("TextButton", mainFrame)
    premiumButton.Size = UDim2.new(0.4, -10, 0, 40) -- Reduced height from 50 to 40
    premiumButton.Position = UDim2.new(0.05, 0, 0, 240) -- Adjusted position
    premiumButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Grayed out
    premiumButton.BackgroundTransparency = 0.3
    premiumButton.Font = Enum.Font.GothamBold
    premiumButton.TextSize = 10 -- Reduced from 12
    premiumButton.Text = "🧠 PREMIUM BRAINROTS\\n[MAINTENANCE]"
    premiumButton.TextColor3 = Color3.fromRGB(180, 180, 180)
    premiumButton.BorderSizePixel = 0
    premiumButton.ZIndex = 4
    local premiumCorner = Instance.new("UICorner", premiumButton)
    premiumCorner.CornerRadius = UDim.new(0, 8)
    -- No hover animation for disabled button

    -- Standard Button (Works)
    local standardButton = Instance.new("TextButton", mainFrame)
    standardButton.Size = UDim2.new(0.4, -10, 0, 40) -- Reduced height from 50 to 40
    standardButton.Position = UDim2.new(0.55, 0, 0, 240) -- Adjusted position
    standardButton.BackgroundColor3 = Color3.fromRGB(34, 139, 34) -- Green
    standardButton.BackgroundTransparency = 0.1
    standardButton.Font = Enum.Font.GothamBold
    standardButton.TextSize = 10 -- Reduced from 12
    standardButton.Text = "⚡ FAST JOINER\\n[WORKING]"
    standardButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    standardButton.BorderSizePixel = 0
    standardButton.ZIndex = 4
    local standardCorner = Instance.new("UICorner", standardButton)
    standardCorner.CornerRadius = UDim.new(0, 8)
    animateButton(standardButton, Color3.fromRGB(49, 154, 49), Color3.fromRGB(34, 139, 34), 3)

    -- Stop Button (more compact)
    local stopButton = Instance.new("TextButton", mainFrame)
    stopButton.Size = UDim2.new(0.9, 0, 0, 30) -- Reduced height from 35 to 30
    stopButton.Position = UDim2.new(0.05, 0, 0, 285) -- Adjusted position
    stopButton.BackgroundColor3 = Color3.fromRGB(220, 85, 85)
    stopButton.BackgroundTransparency = 0.1
    stopButton.Font = Enum.Font.GothamBold
    stopButton.TextSize = 12 -- Reduced from 14
    stopButton.Text = "STOP BRAINROT JOINER"
    stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopButton.BorderSizePixel = 0
    stopButton.ZIndex = 4
    stopButton.Visible = false
    local stopCorner = Instance.new("UICorner", stopButton)
    stopCorner.CornerRadius = UDim.new(0, 8)
    animateButton(stopButton, Color3.fromRGB(235, 100, 100), Color3.fromRGB(220, 85, 85), 3)

    -- Function to start auto joiner with specified mode
    local function startAutoJoiner(mode)
        autoJoinerEnabled = true
        currentMode = mode
        
        premiumButton.Visible = false
        standardButton.Visible = false
        stopButton.Visible = true
        
        if mode == "brainrot" then
            brainrotCard.Visible = true
            statusLabel.Text = "Online - Premium"
            statusDesc.Text = "Scanning for premium brainrots..."
            print("Premium Brainrot Auto Joiner Started")
        else
            brainrotCard.Visible = false
            statusLabel.Text = "Online - Fast"
            statusDesc.Text = "Fast scanning for brainrots..."
            print("Fast Brainrot Joiner Started")
        end
        
        statusLabel.TextColor3 = Color3.fromRGB(85, 170, 85)
        statusDot.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
    end
    
    -- Function to stop auto joiner
    local function stopAutoJoiner()
        autoJoinerEnabled = false
        currentMode = "none"
        
        premiumButton.Visible = true
        standardButton.Visible = true
        stopButton.Visible = false
        brainrotCard.Visible = false
        
        statusLabel.Text = "Offline"
        statusDesc.Text = "Ready to start - Choose a mode below"
        statusLabel.TextColor3 = Color3.fromRGB(220, 85, 85)
        statusDot.BackgroundColor3 = Color3.fromRGB(220, 85, 85)
        
        print("Brainrot Auto Joiner Stopped")
    end

    -- Button events
    premiumButton.MouseButton1Click:Connect(function()
        -- Show maintenance message
        statusLabel.Text = "Under Maintenance"
        statusDesc.Text = "Premium brainrots are temporarily unavailable"
        statusLabel.TextColor3 = Color3.fromRGB(220, 160, 85)
        statusDot.BackgroundColor3 = Color3.fromRGB(220, 160, 85)
        
        task.wait(3)
        
        if not autoJoinerEnabled then
            statusLabel.Text = "Offline"
            statusDesc.Text = "Ready to start - Choose a mode below"
            statusLabel.TextColor3 = Color3.fromRGB(220, 85, 85)
            statusDot.BackgroundColor3 = Color3.fromRGB(220, 85, 85)
        end
    end)

    standardButton.MouseButton1Click:Connect(function()
        startAutoJoiner("simple")
    end)

    stopButton.MouseButton1Click:Connect(function()
        stopAutoJoiner()
    end)

    -- Teleport event handler
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, targetPlaceId, teleportOptions)
        if player == LocalPlayer and autoJoinerEnabled then
            statusLabel.Text = "Failed to Join"
            statusDesc.Text = "Server join failed, retrying in 3 seconds..."
            statusLabel.TextColor3 = Color3.fromRGB(220, 160, 85)
            statusDot.BackgroundColor3 = Color3.fromRGB(220, 160, 85)

            task.wait(3)
            if autoJoinerEnabled then
                if currentMode == "brainrot" then
                    statusLabel.Text = "Online - Premium"
                    statusDesc.Text = "Scanning for premium brainrots..."
                else
                    statusLabel.Text = "Online - Fast"
                    statusDesc.Text = "Fast scanning for brainrots..."
                end
                statusLabel.TextColor3 = Color3.fromRGB(85, 170, 85)
                statusDot.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
            end
        end
    end)

    -- Auto joiner loop
    task.spawn(function()
        while true do
            if autoJoinerEnabled then
                if currentMode == "brainrot" then
                    -- Premium Brainrots API (Currently disabled)
                    statusLabel.Text = "Maintenance Mode"
                    statusDesc.Text = "Premium brainrots temporarily unavailable"
                    statusLabel.TextColor3 = Color3.fromRGB(220, 160, 85)
                    statusDot.BackgroundColor3 = Color3.fromRGB(220, 160, 85)
                    
                elseif currentMode == "simple" then
                    -- Fast Joiner API - Fixed to actually work
                    local success, response = pcall(function()
                        return game:HttpGet(SIMPLE_API_URL)
                    end)

                    if success and response and response ~= "" then
                        -- Clean the response to get just the Job ID
                        local jobId = response:gsub("%s+", ""):gsub("\\n", ""):gsub("\\r", "")
                        
                        -- Debug print
                        print("API Response:", response)
                        print("Cleaned Job ID:", jobId)
                        
                        if jobId and #jobId > 0 and jobId ~= currentJobId and not usedJobIds[jobId] then
                            -- Mark this job ID as used
                            usedJobIds[jobId] = true
                            saveUsedJobIds()

                            -- Update status to show joining
                            statusLabel.Text = "Joining Server"
                            statusDesc.Text = "Found brainrot server! Joining..."
                            statusLabel.TextColor3 = Color3.fromRGB(85, 135, 230)
                            statusDot.BackgroundColor3 = Color3.fromRGB(85, 135, 230)

                            print("Attempting to join server with Job ID:", jobId)

                            -- Attempt teleport
                            teleportAttempts[jobId] = tick()
                            local teleportSuccess = pcall(function()
                                TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
                            end)
                            
                            if not teleportSuccess then
                                print("Teleport failed for Job ID:", jobId)
                            end

                            -- Wait a bit, then reset status if still enabled
                            task.wait(3)
                            if autoJoinerEnabled and currentMode == "simple" then
                                statusLabel.Text = "Online - Fast"
                                statusDesc.Text = "Scanning for more brainrots..."
                                statusLabel.TextColor3 = Color3.fromRGB(85, 170, 85)
                                statusDot.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
                            end
                        elseif jobId == currentJobId then
                            statusDesc.Text = "Skipping current server..."
                            print("Skipping current server Job ID:", jobId)
                        elseif usedJobIds[jobId] then
                            statusDesc.Text = "Skipping used server..."
                            print("Skipping already used Job ID:", jobId)
                        else
                            statusDesc.Text = "Invalid server data received..."
                            print("Invalid Job ID received:", jobId)
                        end
                    else
                        statusLabel.Text = "No Servers Found"
                        statusDesc.Text = "No brainrot servers available, retrying..."
                        statusLabel.TextColor3 = Color3.fromRGB(220, 160, 85)
                        statusDot.BackgroundColor3 = Color3.fromRGB(220, 160, 85)
                        print("No response from API or empty response")
                    end
                end
            end
            task.wait(CHECK_INTERVAL)
        end
    end)

    print("Brainrot Auto Joiner loaded successfully!")
end
