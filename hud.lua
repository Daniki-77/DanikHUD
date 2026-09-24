local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

-- File Saving Setup (Executor file support)
local SETTINGS_FILE = "DanikiHUD_Settings.json"
local savedData = {}

local function loadSettingsFromFile()
	if readfile and isfile and isfile(SETTINGS_FILE) then
		local success, result = pcall(function()
			return HttpService:JSONDecode(readfile(SETTINGS_FILE))
		end)
		if success and type(result) == "table" then
			savedData = result
		end
	end
end

local function saveSettingsToFile()
	if writefile then
		pcall(function()
			writefile(SETTINGS_FILE, HttpService:JSONEncode(savedData))
		end)
	end
end

loadSettingsFromFile()

-- Helper to get/set persistent values safely
local function getSavedValue(key, default)
	if savedData[key] ~= nil then
		return savedData[key]
	end
	return default
end

local function setSavedValue(key, value)
	savedData[key] = value
	saveSettingsToFile()
end

-- Stat Visibility States
local statStates = {
	FPS = getSavedValue("Stat_FPS", true),
	PING = getSavedValue("Stat_PING", true),
	PLRS = getSavedValue("Stat_PLRS", true),
	RAM = getSavedValue("Stat_RAM", true),
	TIME = getSavedValue("Stat_TIME", true),
	JIT = getSavedValue("Stat_JIT", true)
}

local function saveStatState(statName, state)
	statStates[statName] = state
	setSavedValue("Stat_" .. statName, state)
end

-- Create Core GUI
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UICorner = Instance.new("UICorner")
local UIStroke = Instance.new("UIStroke")

local StatusDot = Instance.new("Frame")
local DotCorner = Instance.new("UICorner")

-- ScreenGui Setup
ScreenGui.Name = "ExpandedOverlayGui"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Position Persistence
local savedX = getSavedValue("PosX", 16)
local savedY = getSavedValue("PosY", 16)

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.Position = UDim2.new(0, savedX, 0, savedY)
MainFrame.Active = true
MainFrame.ClipsDescendants = true

UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

UIStroke.Thickness = 1
UIStroke.Parent = MainFrame

----------------------------------------------------
-- COLOR THEME PRESETS & MANAGER
----------------------------------------------------
local Themes = {
	{ Name = "Dark Slate", Bg = Color3.fromRGB(18, 18, 22), Stroke = Color3.fromRGB(255, 255, 255), StrokeTrans = 0.88, AccentHex = "#82AAFF" },
	{ Name = "Cyberpunk", Bg = Color3.fromRGB(12, 16, 28), Stroke = Color3.fromRGB(0, 240, 255), StrokeTrans = 0.5, AccentHex = "#00F0FF" },
	{ Name = "Dracula", Bg = Color3.fromRGB(24, 20, 36), Stroke = Color3.fromRGB(189, 147, 249), StrokeTrans = 0.5, AccentHex = "#BD93F9" },
	{ Name = "Matrix Green", Bg = Color3.fromRGB(10, 20, 12), Stroke = Color3.fromRGB(0, 255, 128), StrokeTrans = 0.5, AccentHex = "#00FF80" },
	{ Name = "Crimson Night", Bg = Color3.fromRGB(25, 12, 14), Stroke = Color3.fromRGB(255, 65, 84), StrokeTrans = 0.5, AccentHex = "#FF4154" }
}

local currentThemeIndex = math.clamp(getSavedValue("ThemeIndex", 1), 1, #Themes)

local refreshSettingsLabels
local refreshDisplayAndSize

local function applyTheme(index)
	local theme = Themes[index]
	if not theme then return end
	TweenService:Create(MainFrame, TweenInfo.new(0.25), {BackgroundColor3 = theme.Bg}):Play()
	TweenService:Create(UIStroke, TweenInfo.new(0.25), {Color = theme.Stroke, Transparency = theme.StrokeTrans}):Play()
	setSavedValue("ThemeIndex", index)
	if refreshSettingsLabels then
		refreshSettingsLabels()
	end
end

MainFrame.BackgroundColor3 = Themes[currentThemeIndex].Bg
UIStroke.Color = Themes[currentThemeIndex].Stroke
UIStroke.Transparency = Themes[currentThemeIndex].StrokeTrans

----------------------------------------------------
-- NETWORK STATUS DOT
----------------------------------------------------
StatusDot.Name = "StatusDot"
StatusDot.Parent = MainFrame
StatusDot.BackgroundColor3 = Color3.fromRGB(78, 254, 136)
StatusDot.ZIndex = 2

DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

local DotStrokeInstance = Instance.new("UIStroke")
DotStrokeInstance.Color = Color3.fromRGB(78, 254, 136)
DotStrokeInstance.Transparency = 0.5
DotStrokeInstance.Thickness = 2
DotStrokeInstance.Parent = StatusDot

local dotPulseTween = TweenService:Create(DotStrokeInstance, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	Transparency = 0.95,
	Thickness = 5
})
dotPulseTween:Play()

local function updateNetworkDot(ping, jitter)
	local targetColor
	if ping > 180 or jitter >= 30 then
		targetColor = Color3.fromRGB(254, 78, 78)
	elseif ping > 90 or jitter >= 12 then
		targetColor = Color3.fromRGB(254, 234, 78)
	else
		targetColor = Color3.fromRGB(78, 254, 136)
	end

	TweenService:Create(StatusDot, TweenInfo.new(0.1), {BackgroundColor3 = targetColor}):Play()
	TweenService:Create(DotStrokeInstance, TweenInfo.new(0.1), {Color = targetColor}):Play()
end

----------------------------------------------------
-- CREATE TEXT LABELS
----------------------------------------------------
local function createLabel(name)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Parent = MainFrame
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.RichText = true
	return label
end

local TitleLabel = createLabel("TitleLabel")
TitleLabel.TextXAlignment = Enum.TextXAlignment.Center

local CreditLabel = createLabel("CreditLabel")
CreditLabel.TextXAlignment = Enum.TextXAlignment.Center
CreditLabel.TextColor3 = Color3.fromRGB(100, 108, 123)

local FpsLabel = createLabel("FpsLabel")
local PingLabel = createLabel("PingLabel")
local PlayersLabel = createLabel("PlayersLabel")
local RamLabel = createLabel("RamLabel")
local ClockLabel = createLabel("ClockLabel")
local JitterLabel = createLabel("JitterLabel")

-- Settings Gear Button
local SettingsButton = Instance.new("TextButton")
SettingsButton.Name = "SettingsButton"
SettingsButton.Parent = MainFrame
SettingsButton.BackgroundTransparency = 1
SettingsButton.Font = Enum.Font.GothamBold
SettingsButton.Text = "⚙"
SettingsButton.TextColor3 = Color3.fromRGB(140, 150, 170)
SettingsButton.TextSize = 14
SettingsButton.ZIndex = 3

----------------------------------------------------
-- STATE & SETTINGS (KEYBINDS)
----------------------------------------------------
local TOGGLE_KEY = Enum.KeyCode[getSavedValue("Key_Toggle", "F1")] or Enum.KeyCode.F1
local SIMPLIFIED_KEY = Enum.KeyCode[getSavedValue("Key_Simplified", "F2")] or Enum.KeyCode.F2
local SCALE_KEY = Enum.KeyCode[getSavedValue("Key_Scale", "F3")] or Enum.KeyCode.F3
local THEME_KEY = Enum.KeyCode[getSavedValue("Key_Theme", "F8")] or Enum.KeyCode.F8
local SETTINGS_KEY = Enum.KeyCode[getSavedValue("Key_Settings", "F5")] or Enum.KeyCode.F5
local DESTROY_KEY = Enum.KeyCode[getSavedValue("Key_Destroy", "F10")] or Enum.KeyCode.F10

local function saveKeybind(keyEnum, keyName)
	setSavedValue("Key_" .. keyName, keyEnum.Name)
end

local Scales = {0.85, 1.0, 1.25}
local currentScaleIndex = math.clamp(getSavedValue("ScaleIndex", 2), 1, #Scales)

local UPDATE_INTERVAL = 0.15
local sizeTweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local frameCount = 0
local elapsedTime = 0
local isSimplified = false
local isVisible = true
local isSettingsOpen = false

local currentFps = 60
local currentPing = 0
local lastPing = 0
local currentJitter = 0
local currentRam = 0

local inputConnection, renderConnection, playerAddedConn, playerRemovingConn

----------------------------------------------------
-- SETTINGS PANEL CREATION
----------------------------------------------------
local SettingsFrame = Instance.new("ScrollingFrame")
SettingsFrame.Name = "SettingsFrame"
SettingsFrame.Parent = ScreenGui
SettingsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
SettingsFrame.BackgroundTransparency = 0.1
SettingsFrame.Size = UDim2.new(0, 340, 0, 420)
SettingsFrame.CanvasSize = UDim2.new(0, 0, 0, 660)
SettingsFrame.ScrollBarThickness = 4
SettingsFrame.Visible = false
SettingsFrame.Active = true
SettingsFrame.ZIndex = 10

local SettingsCorner = Instance.new("UICorner")
SettingsCorner.CornerRadius = UDim.new(0, 10)
SettingsCorner.Parent = SettingsFrame

local SettingsStroke = Instance.new("UIStroke")
SettingsStroke.Color = Color3.fromRGB(80, 90, 110)
SettingsStroke.Thickness = 1
SettingsStroke.Parent = SettingsFrame

local SettingsTitle = Instance.new("TextLabel")
SettingsTitle.Parent = SettingsFrame
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.Position = UDim2.new(0, 14, 0, 12)
SettingsTitle.Size = UDim2.new(1, -50, 0, 24)
SettingsTitle.Font = Enum.Font.GothamBold
SettingsTitle.Text = "HUD SETTINGS & KEYBINDS"
SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
SettingsTitle.TextSize = 11
SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
SettingsTitle.ZIndex = 11

local CloseSettingsBtn = Instance.new("TextButton")
CloseSettingsBtn.Parent = SettingsFrame
CloseSettingsBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
CloseSettingsBtn.Position = UDim2.new(1, -30, 0, 13)
CloseSettingsBtn.Size = UDim2.new(0, 20, 0, 20)
CloseSettingsBtn.Font = Enum.Font.GothamBold
CloseSettingsBtn.Text = "X"
CloseSettingsBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseSettingsBtn.TextSize = 11
CloseSettingsBtn.ZIndex = 11

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseSettingsBtn

-- Enhanced Save Settings Button
local SaveSettingsBtn = Instance.new("TextButton")
SaveSettingsBtn.Parent = SettingsFrame
SaveSettingsBtn.BackgroundColor3 = Color3.fromRGB(35, 110, 200)
SaveSettingsBtn.Position = UDim2.new(0, 16, 0, 42)
SaveSettingsBtn.Size = UDim2.new(1, -32, 0, 34)
SaveSettingsBtn.Font = Enum.Font.GothamBold
SaveSettingsBtn.Text = "💾  Save Settings"
SaveSettingsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveSettingsBtn.TextSize = 12
SaveSettingsBtn.AutoButtonColor = false
SaveSettingsBtn.ZIndex = 11

local SaveCorner = Instance.new("UICorner")
SaveCorner.CornerRadius = UDim.new(0, 6)
SaveCorner.Parent = SaveSettingsBtn

local SaveStroke = Instance.new("UIStroke")
SaveStroke.Color = Color3.fromRGB(100, 170, 255)
SaveStroke.Transparency = 0.4
SaveStroke.Thickness = 1
SaveStroke.Parent = SaveSettingsBtn

local SaveGradient = Instance.new("UIGradient")
SaveGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 210, 255))
})
SaveGradient.Rotation = 90
SaveGradient.Parent = SaveSettingsBtn

SaveSettingsBtn.MouseEnter:Connect(function()
	TweenService:Create(SaveSettingsBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 130, 235)}):Play()
end)

SaveSettingsBtn.MouseLeave:Connect(function()
	TweenService:Create(SaveSettingsBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 110, 200)}):Play()
end)

SaveSettingsBtn.MouseButton1Click:Connect(function()
	setSavedValue("PosX", MainFrame.Position.X.Offset)
	setSavedValue("PosY", MainFrame.Position.Y.Offset)
	setSavedValue("ScaleIndex", currentScaleIndex)
	setSavedValue("ThemeIndex", currentThemeIndex)
	saveSettingsToFile()
	
	SaveSettingsBtn.Text = "✔  Settings Saved!"
	TweenService:Create(SaveSettingsBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(46, 204, 113)}):Play()
	TweenService:Create(SaveStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(150, 255, 190)}):Play()
	
	task.delay(1.2, function()
		SaveSettingsBtn.Text = "💾  Save Settings"
		TweenService:Create(SaveSettingsBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 110, 200)}):Play()
		TweenService:Create(SaveStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(100, 170, 255)}):Play()
	end)
end)

local function updateSettingsPosition()
	SettingsFrame.Position = UDim2.new(0, MainFrame.AbsolutePosition.X, 0, MainFrame.AbsolutePosition.Y + MainFrame.AbsoluteSize.Y + 8)
end

local function createSettingRow(name, yPos, onClick)
	local label = Instance.new("TextLabel")
	label.Parent = SettingsFrame
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 16, 0, yPos)
	label.Size = UDim2.new(0, 155, 0, 28)
	label.Font = Enum.Font.GothamMedium
	label.Text = name
	label.TextColor3 = Color3.fromRGB(180, 190, 210)
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 11

	local btn = Instance.new("TextButton")
	btn.Parent = SettingsFrame
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	btn.Position = UDim2.new(0, 180, 0, yPos)
	btn.Size = UDim2.new(0, 130, 0, 28)
	btn.Font = Enum.Font.GothamBold
	btn.Text = "..."
	btn.TextColor3 = Color3.fromRGB(100, 220, 255)
	btn.TextSize = 11
	btn.ZIndex = 11

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		onClick(btn)
	end)

	return btn
end

local function createSectionHeader(title, yPos)
	local header = Instance.new("TextLabel")
	header.Parent = SettingsFrame
	header.BackgroundTransparency = 1
	header.Position = UDim2.new(0, 16, 0, yPos)
	header.Size = UDim2.new(1, -32, 0, 20)
	header.Font = Enum.Font.GothamBold
	header.Text = title
	header.TextColor3 = Color3.fromRGB(130, 170, 255)
	header.TextSize = 11
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.ZIndex = 11
end

local rebindTarget = nil
local rebindButtonText = nil

local bindToggleBtn = createSettingRow("Toggle HUD", 85, function(btn)
	rebindTarget = "Toggle"
	btn.Text = "Press any key..."
end)

local bindSimpleBtn = createSettingRow("Simplified Mode", 120, function(btn)
	rebindTarget = "Simplified"
	btn.Text = "Press any key..."
end)

local bindScaleBtn = createSettingRow("Cycle Scale", 155, function(btn)
	rebindTarget = "Scale"
	btn.Text = "Press any key..."
end)

local bindThemeBtn = createSettingRow("Cycle Theme", 190, function(btn)
	rebindTarget = "Theme"
	btn.Text = "Press any key..."
end)

local bindSettingsBtn = createSettingRow("Toggle Settings", 225, function(btn)
	rebindTarget = "Settings"
	btn.Text = "Press any key..."
end)

local bindDestroyBtn = createSettingRow("Destroy Script", 260, function(btn)
	rebindTarget = "Destroy"
	btn.Text = "Press any key..."
end)

createSectionHeader("PRESETS & THEMES", 300)

local themeCycleBtn = createSettingRow("Theme", 325, function()
	currentThemeIndex = (currentThemeIndex % #Themes) + 1
	applyTheme(currentThemeIndex)
end)
themeCycleBtn.Text = Themes[currentThemeIndex].Name

local scaleCycleBtn = createSettingRow("Scale", 360, function()
	currentScaleIndex = (currentScaleIndex % #Scales) + 1
	setSavedValue("ScaleIndex", currentScaleIndex)
	refreshDisplayAndSize()
	if refreshSettingsLabels then
		refreshSettingsLabels()
	end
end)
scaleCycleBtn.Text = Scales[currentScaleIndex] .. "x"

createSectionHeader("SIMPLE MODE TOGGLES", 405)

local statToggleButtons = {}
local statList = {"FPS", "PING", "PLRS", "RAM", "TIME", "JIT"}
local startY = 430

for i, statName in ipairs(statList) do
	local yPos = startY + ((i - 1) * 32)
	statToggleButtons[statName] = createSettingRow("Show " .. statName, yPos, function(btn)
		local newState = not statStates[statName]
		saveStatState(statName, newState)
		refreshSettingsLabels()
		refreshDisplayAndSize()
	end)
end

refreshSettingsLabels = function()
	bindToggleBtn.Text = TOGGLE_KEY.Name
	bindSimpleBtn.Text = SIMPLIFIED_KEY.Name
	bindScaleBtn.Text = SCALE_KEY.Name
	bindThemeBtn.Text = THEME_KEY.Name
	bindSettingsBtn.Text = SETTINGS_KEY.Name
	bindDestroyBtn.Text = DESTROY_KEY.Name
	themeCycleBtn.Text = Themes[currentThemeIndex].Name
	scaleCycleBtn.Text = Scales[currentScaleIndex] .. "x"

	for statName, btn in pairs(statToggleButtons) do
		btn.Text = statStates[statName] and "Enabled" or "Disabled"
		btn.TextColor3 = statStates[statName] and Color3.fromRGB(78, 254, 136) or Color3.fromRGB(254, 78, 78)
	end
end
refreshSettingsLabels()

local function toggleSettingsMenu(show)
	isSettingsOpen = show
	if show then
		updateSettingsPosition()
		refreshSettingsLabels()
		SettingsFrame.Visible = true
		TweenService:Create(SettingsFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
	else
		SettingsFrame.Visible = false
	end
end

CloseSettingsBtn.MouseButton1Click:Connect(function()
	toggleSettingsMenu(false)
end)

SettingsButton.MouseButton1Click:Connect(function()
	toggleSettingsMenu(not isSettingsOpen)
end)

----------------------------------------------------
-- FORMATTING HELPERS
----------------------------------------------------
local LABEL_COLOR = "<font color=\"#77808F\">"

local function getFpsColor(fps)
	if fps >= 50 then return "<font color=\"#4EFE88\">" .. fps .. "</font>" end
	if fps >= 30 then return "<font color=\"#FEEA4E\">" .. fps .. "</font>" end
	return "<font color=\"#FE4E4E\">" .. fps .. "</font>"
end

local function getPingColor(ping)
	if ping <= 80 then return "<font color=\"#4EFE88\">" .. ping .. " ms</font>" end
	if ping <= 150 then return "<font color=\"#FEEA4E\">" .. ping .. " ms</font>" end
	return "<font color=\"#FE4E4E\">" .. ping .. " ms</font>"
end

local function getRamColor(ram)
	if ram < 1200 then return "<font color=\"#4EFE88\">" .. ram .. " MB</font>" end
	if ram < 2000 then return "<font color=\"#FEEA4E\">" .. ram .. " MB</font>" end
	return "<font color=\"#FE4E4E\">" .. ram .. " MB</font>"
end

local function getJitterColor(jit)
	if jit < 10 then return "<font color=\"#4EFE88\">" .. jit .. " ms</font>" end
	if jit < 25 then return "<font color=\"#FEEA4E\">" .. jit .. " ms</font>" end
	return "<font color=\"#FE4E4E\">" .. jit .. " ms</font>"
end

local function getPlayersFormatted()
	local count = #Players:GetPlayers()
	local maxCount = Players.MaxPlayers
	local ratio = maxCount > 0 and (count / maxCount) or 0
	local colorHex = "#4EFE88"
	if ratio >= 1.0 then colorHex = "#FE4E4E" elseif ratio >= 0.8 then colorHex = "#FEEA4E" end
	return string.format("<font color=\"%s\">%d/%d</font>", colorHex, count, maxCount)
end

local function stripRichText(str)
	return string.gsub(str, "<[^>]+>", "")
end

----------------------------------------------------
-- REFRESH & DYNAMIC SIZING
----------------------------------------------------
refreshDisplayAndSize = function()
	local scale = Scales[currentScaleIndex]
	local font = Enum.Font.GothamBold
	
	local fontSize = math.round(13 * scale)
	local titleSize = math.round(11 * scale)
	local creditSize = math.round(6 * scale)
	local rowHeight = math.round(20 * scale)
	local titleHeight = math.round(16 * scale)
	local creditHeight = math.round(9 * scale)
	local paddingX = math.round(14 * scale)
	local paddingY = math.round(12 * scale)
	local rowSpacing = math.round(20 * scale)
	local colSpacing = math.round(28 * scale)
	local dotSize = math.round(8 * scale)

	local maxBounds = Vector2.new(1000, rowHeight)

	TitleLabel.TextSize = titleSize
	CreditLabel.TextSize = creditSize
	FpsLabel.TextSize = fontSize
	PingLabel.TextSize = fontSize
	PlayersLabel.TextSize = fontSize
	RamLabel.TextSize = fontSize
	ClockLabel.TextSize = fontSize
	JitterLabel.TextSize = fontSize

	local accentHex = Themes[currentThemeIndex].AccentHex
	TitleLabel.Text = string.format("<font color=\"%s\">DANIK'S HUD</font>", accentHex)
	CreditLabel.Text = "MADE BY DANIKI"

	local clockStr = string.format("<font color=\"%s\">%s</font>", accentHex, os.date("%I:%M %p"))

	FpsLabel.Visible = false
	PingLabel.Visible = false
	PlayersLabel.Visible = false
	RamLabel.Visible = false
	ClockLabel.Visible = false
	JitterLabel.Visible = false
	
	local activeItems = {}
	
	local fpsFormatted = LABEL_COLOR .. "FPS</font>   " .. getFpsColor(currentFps)
	local pingFormatted = LABEL_COLOR .. "PING</font>   " .. getPingColor(currentPing)
	local plrsFormatted = LABEL_COLOR .. "PLRS</font>  " .. getPlayersFormatted()
	local ramFormatted = LABEL_COLOR .. "RAM</font>   " .. getRamColor(currentRam)
	local clockFormatted = LABEL_COLOR .. "TIME</font>  " .. clockStr
	local jitFormatted = LABEL_COLOR .. "JIT</font>   " .. getJitterColor(currentJitter)

	if not isSimplified then
		table.insert(activeItems, {Label = FpsLabel, Text = fpsFormatted})
		table.insert(activeItems, {Label = PingLabel, Text = pingFormatted})
		table.insert(activeItems, {Label = PlayersLabel, Text = plrsFormatted})
		table.insert(activeItems, {Label = RamLabel, Text = ramFormatted})
		table.insert(activeItems, {Label = ClockLabel, Text = clockFormatted})
		table.insert(activeItems, {Label = JitterLabel, Text = jitFormatted})
		CreditLabel.Visible = true
	else
		if statStates.FPS then table.insert(activeItems, {Label = FpsLabel, Text = fpsFormatted}) end
		if statStates.PING then table.insert(activeItems, {Label = PingLabel, Text = pingFormatted}) end
		if statStates.PLRS then table.insert(activeItems, {Label = PlayersLabel, Text = plrsFormatted}) end
		if statStates.RAM then table.insert(activeItems, {Label = RamLabel, Text = ramFormatted}) end
		if statStates.TIME then table.insert(activeItems, {Label = ClockLabel, Text = clockFormatted}) end
		if statStates.JIT then table.insert(activeItems, {Label = JitterLabel, Text = jitFormatted}) end
		CreditLabel.Visible = false
	end

	local col1Items = {}
	local col2Items = {}
	for i, item in ipairs(activeItems) do
		item.Label.Text = item.Text
		item.Label.Visible = true
		if i % 2 ~= 0 then
			table.insert(col1Items, item)
		else
			table.insert(col2Items, item)
		end
	end

	local maxCol1Width = 0
	local maxCol2Width = 0

	for _, item in ipairs(col1Items) do
		local w = TextService:GetTextSize(stripRichText(item.Text), fontSize, font, maxBounds).X
		if w > maxCol1Width then maxCol1Width = w end
	end
	for _, item in ipairs(col2Items) do
		local w = TextService:GetTextSize(stripRichText(item.Text), fontSize, font, maxBounds).X
		if w > maxCol2Width then maxCol2Width = w end
	end

	local totalColumnsWidth = maxCol1Width + (#col2Items > 0 and (colSpacing + maxCol2Width) or 0)
	local titleStringWidth = TextService:GetTextSize("DANIK'S HUD", titleSize, font, maxBounds).X
	local creditStringWidth = TextService:GetTextSize("MADE BY DANIKI", creditSize, font, maxBounds).X
	local targetWidth = math.max(totalColumnsWidth + (paddingX * 2), titleStringWidth + (paddingX * 2) + 30, isSimplified and 0 or (creditStringWidth + (paddingX * 2)))

	TitleLabel.Position = UDim2.new(0.5, -targetWidth / 2 + paddingX, 0, paddingY)
	TitleLabel.Size = UDim2.new(0, targetWidth - (paddingX * 2), 0, titleHeight)

	local gearSize = math.round(18 * scale)
	SettingsButton.Size = UDim2.new(0, gearSize, 0, gearSize)
	SettingsButton.Position = UDim2.new(0, paddingX + targetWidth - (paddingX * 2) - gearSize - 2, 0, paddingY - 1)

	local gridStartY = paddingY + titleHeight + math.round(8 * scale)
	local maxRows = math.max(#col1Items, #col2Items)

	for i = 1, maxRows do
		local rowY = gridStartY + ((i - 1) * rowSpacing)
		
		if col1Items[i] then
			col1Items[i].Label.Position = UDim2.new(0, paddingX, 0, rowY)
			col1Items[i].Label.Size = UDim2.new(0, maxCol1Width, 0, rowHeight)
		end
		
		if col2Items[i] then
			local col2X = paddingX + maxCol1Width + colSpacing
			col2Items[i].Label.Position = UDim2.new(0, col2X, 0, rowY)
			col2Items[i].Label.Size = UDim2.new(0, maxCol2Width, 0, rowHeight)
		end
	end

	local dotRowY = gridStartY
	StatusDot.Size = UDim2.new(0, dotSize, 0, dotSize)
	local col2X = maxCol1Width > 0 and (paddingX + maxCol1Width + colSpacing) or (paddingX + 50)
	StatusDot.Position = UDim2.new(0, col2X - math.round(14 * scale), 0, dotRowY + math.round(6 * scale))

	local totalRows = maxRows
	local gridBottomY = gridStartY + (rowSpacing * math.max(0, totalRows - 1)) + rowHeight
	
	local targetHeight
	if isSimplified or totalRows == 0 then
		targetHeight = gridBottomY + paddingY
	else
		local creditY = gridBottomY + math.round(8 * scale)
		CreditLabel.Position = UDim2.new(0.5, -targetWidth / 2 + paddingX, 0, creditY)
		CreditLabel.Size = UDim2.new(0, targetWidth - (paddingX * 2), 0, creditHeight)
		targetHeight = creditY + creditHeight + math.round(10 * scale)
	end

	TweenService:Create(MainFrame, sizeTweenInfo, {Size = UDim2.new(0, targetWidth, 0, targetHeight)}):Play()
	
	if isSettingsOpen then
		updateSettingsPosition()
	end
end

playerAddedConn = Players.PlayerAdded:Connect(refreshDisplayAndSize)
playerRemovingConn = Players.PlayerRemoving:Connect(refreshDisplayAndSize)

----------------------------------------------------
-- DRAGGABLE LOGIC
----------------------------------------------------
local dragging, dragInput, dragStart, startPos

MainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				setSavedValue("PosX", MainFrame.Position.X.Offset)
				setSavedValue("PosY", MainFrame.Position.Y.Offset)
				saveSettingsToFile()
			end
		end)
	end
end)

MainFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		if isSettingsOpen then updateSettingsPosition() end
	end
end)

----------------------------------------------------
-- FADE TWEENING
----------------------------------------------------
local fadeTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setVisibilitySmooth(show)
	isVisible = show
	TweenService:Create(MainFrame, fadeTweenInfo, {BackgroundTransparency = show and 0.25 or 1}):Play()
	TweenService:Create(UIStroke, fadeTweenInfo, {Transparency = show and Themes[currentThemeIndex].StrokeTrans or 1}):Play()
	TweenService:Create(StatusDot, fadeTweenInfo, {BackgroundTransparency = show and 0 or 1}):Play()
	TweenService:Create(DotStrokeInstance, fadeTweenInfo, {Transparency = show and 0.5 or 1}):Play()
	TweenService:Create(SettingsButton, fadeTweenInfo, {TextTransparency = show and 0 or 1}):Play()

	for _, child in ipairs(MainFrame:GetChildren()) do
		if child:IsA("TextLabel") and child.Visible then
			TweenService:Create(child, fadeTweenInfo, {TextTransparency = show and 0 or 1}):Play()
		end
	end
	
	if not show and isSettingsOpen then
		toggleSettingsMenu(false)
	end
end

----------------------------------------------------
-- KEYBINDS
----------------------------------------------------
local function destroyScript()
	if dotPulseTween then dotPulseTween:Cancel() end
	if renderConnection then renderConnection:Disconnect() end
	if inputConnection then inputConnection:Disconnect() end
	if playerAddedConn then playerAddedConn:Disconnect() end
	if playerRemovingConn then playerRemovingConn:Disconnect() end
	ScreenGui:Destroy()
end

inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if rebindTarget then
			if input.KeyCode ~= Enum.KeyCode.Unknown then
				if rebindTarget == "Toggle" then TOGGLE_KEY = input.KeyCode saveKeybind(input.KeyCode, "Toggle")
				elseif rebindTarget == "Simplified" then SIMPLIFIED_KEY = input.KeyCode saveKeybind(input.KeyCode, "Simplified")
				elseif rebindTarget == "Scale" then SCALE_KEY = input.KeyCode saveKeybind(input.KeyCode, "Scale")
				elseif rebindTarget == "Theme" then THEME_KEY = input.KeyCode saveKeybind(input.KeyCode, "Theme")
				elseif rebindTarget == "Settings" then SETTINGS_KEY = input.KeyCode saveKeybind(input.KeyCode, "Settings")
				elseif rebindTarget == "Destroy" then DESTROY_KEY = input.KeyCode saveKeybind(input.KeyCode, "Destroy")
				end
				saveSettingsToFile()
				rebindTarget = nil
				refreshSettingsLabels()
			end
			return
		end
	end

	if gameProcessed then return end

	if input.KeyCode == TOGGLE_KEY then
		setVisibilitySmooth(not isVisible)
	elseif input.KeyCode == SIMPLIFIED_KEY then
		isSimplified = not isSimplified
		refreshDisplayAndSize()
	elseif input.KeyCode == SCALE_KEY then
		currentScaleIndex = (currentScaleIndex % #Scales) + 1
		setSavedValue("ScaleIndex", currentScaleIndex)
		refreshDisplayAndSize()
		refreshSettingsLabels()
	elseif input.KeyCode == THEME_KEY then
		currentThemeIndex = (currentThemeIndex % #Themes) + 1
		applyTheme(currentThemeIndex)
		refreshDisplayAndSize()
	elseif input.KeyCode == SETTINGS_KEY then
		toggleSettingsMenu(not isSettingsOpen)
	elseif input.KeyCode == DESTROY_KEY then
		destroyScript()
	end
end)

----------------------------------------------------
-- MAIN UPDATE LOOP
----------------------------------------------------
renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
	if not isVisible then return end

	frameCount += 1
	elapsedTime += deltaTime

	if elapsedTime >= UPDATE_INTERVAL then
		currentFps = math.floor(frameCount / elapsedTime)
		currentPing = math.floor(LocalPlayer:GetNetworkPing() * 1000)
		currentRam = math.floor(Stats:GetTotalMemoryUsageMb())
		
		if lastPing > 0 then
			currentJitter = math.abs(currentPing - lastPing)
		end
		lastPing = currentPing

		updateNetworkDot(currentPing, currentJitter)
		refreshDisplayAndSize()

		frameCount = 0
		elapsedTime = 0
	end
end)
