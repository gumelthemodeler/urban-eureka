-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local RaidTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local EffectsManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("EffectsManager")) 

local player = Players.LocalPlayer

local ArenaFrame, HeaderContainer, HeaderText, TimerBar
local CombatantsFrame, BottomArea
local PartyListFrame, BossFrame
local BossHPBar, BossHPText, BossNameText, BossStatusBox, BossShieldBar
local eStatsArea
local eAvatarBox, eAvatarIcon

local LogText, ActionGrid, TargetMenu, LeaveBtn
local currentRaidId = nil
local currentRange = "Close" -- [[ FIX: Added Range Tracking ]]
local inputLocked = false
local pendingSkillName = nil
local cachedTooltipMgr

local currentTimerTweenSize, currentTimerTweenColor
local PartyUIBars = {} 

local MAX_LOG_MESSAGES = 2
local logMessages = {}

local function AddLogMessage(msgText, append)
	if not msgText or msgText == "" then return end
	if append then table.insert(logMessages, msgText) if #logMessages > MAX_LOG_MESSAGES then table.remove(logMessages, 1) end
	else logMessages = {msgText} end
	LogText.Text = table.concat(logMessages, "\n\n")
end

local function ShakeUI(intensity)
	if not intensity or intensity == "None" then return end
	local amount = (intensity == "Heavy") and 15 or 6
	local originalPos = UDim2.new(0.5, 0, 0.5, 0)
	task.spawn(function()
		for i = 1, 10 do
			if not ArenaFrame.Visible then break end
			local xOffset = math.random(-amount, amount); local yOffset = math.random(-amount, amount)
			ArenaFrame.Position = originalPos + UDim2.new(0, xOffset, 0, yOffset)
			task.wait(0.03)
		end
		ArenaFrame.Position = originalPos
	end)
end

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}; grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 4)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn); stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	if not btn:GetAttribute("GradientTextFixed") then
		btn:SetAttribute("GradientTextFixed", true)
		local textLbl = Instance.new("TextLabel", btn); textLbl.Name = "BtnTextLabel"; textLbl.Size = UDim2.new(1, 0, 1, 0); textLbl.BackgroundTransparency = 1; textLbl.Font = btn.Font; textLbl.TextSize = btn.TextSize; textLbl.TextScaled = btn.TextScaled; textLbl.RichText = btn.RichText; textLbl.TextWrapped = btn.TextWrapped; textLbl.TextXAlignment = btn.TextXAlignment; textLbl.TextYAlignment = btn.TextYAlignment; textLbl.ZIndex = btn.ZIndex + 1
		local tConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint"); if tConstraint then tConstraint.Parent = textLbl end
		btn.ChildAdded:Connect(function(child) if child:IsA("UITextSizeConstraint") then task.delay(0, function() child.Parent = textLbl end) end end)
		textLbl.Text = btn.Text; textLbl.TextColor3 = btn.TextColor3; btn.Text = ""
		btn:GetPropertyChangedSignal("Text"):Connect(function() if btn.Text ~= "" then textLbl.Text = btn.Text; btn.Text = "" end end)
		btn:GetPropertyChangedSignal("TextColor3"):Connect(function() textLbl.TextColor3 = btn.TextColor3 end)
	end
end

local function CreateBar(parent, color1, color2, size, labelText, alignRight)
	local container = Instance.new("Frame", parent); container.Size = size; container.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", container).Color = Color3.fromRGB(60, 60, 70)
	local fill = Instance.new("Frame", container); fill.Size = UDim2.new(1, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	if alignRight then fill.AnchorPoint = Vector2.new(1, 0); fill.Position = UDim2.new(1, 0, 0, 0) end
	local grad = Instance.new("UIGradient", fill); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}; grad.Rotation = 90
	local text = Instance.new("TextLabel", container); text.Size = UDim2.new(1, -10, 1, 0); text.Position = UDim2.new(0, alignRight and 0 or 10, 0, 0); text.BackgroundTransparency = 1; text.Font = Enum.Font.GothamBold; text.TextColor3 = Color3.fromRGB(255, 255, 255); text.TextSize = 10; text.TextStrokeTransparency = 0.5; text.Text = labelText; text.TextXAlignment = alignRight and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left; text.ZIndex = 5
	return fill, text, container
end

local function RenderStatuses(container, statuses)
	for _, child in ipairs(container:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
	if not statuses then return end

	local function addIcon(iconTxt, bgColor, strokeColor)
		local f = Instance.new("Frame", container); f.Size = UDim2.new(0, 20, 0, 14); f.BackgroundColor3 = bgColor; Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", f).Color = strokeColor
		local t = Instance.new("TextLabel", f); t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBlack; t.Text = iconTxt; t.TextColor3 = Color3.fromRGB(255,255,255); t.TextScaled = true; t.TextStrokeTransparency = 0
	end

	if statuses.Dodge and statuses.Dodge > 0 then addIcon("DGE", Color3.fromRGB(30, 60, 120), Color3.fromRGB(60, 100, 200)) end
	if statuses.Transformed and statuses.Transformed > 0 then addIcon("TTN", Color3.fromRGB(150, 40, 40), Color3.fromRGB(200, 60, 60)) end
	for sName, duration in pairs(statuses) do
		if duration > 0 then
			if sName == "Crippled" then addIcon("CRP", Color3.fromRGB(80, 80, 80), Color3.fromRGB(120, 120, 120))
			elseif sName == "Weakened" then addIcon("WEK", Color3.fromRGB(120, 80, 40), Color3.fromRGB(200, 120, 60))
			elseif sName == "Bleed" then addIcon("BLD", Color3.fromRGB(180, 40, 40), Color3.fromRGB(220, 60, 60))
			elseif sName == "Burn" then addIcon("BRN", Color3.fromRGB(200, 100, 40), Color3.fromRGB(240, 140, 60))
			end
		end
	end
end

local function StartVisualTimer(endTime)
	if currentTimerTweenSize then currentTimerTweenSize:Cancel() end
	if currentTimerTweenColor then currentTimerTweenColor:Cancel() end

	local remaining = endTime - os.time()
	if remaining < 0 then remaining = 0 end

	TimerBar.Size = UDim2.new(1, 0, 1, 0); TimerBar.BackgroundColor3 = Color3.fromRGB(46, 204, 113) 
	local tweenInfo = TweenInfo.new(remaining, Enum.EasingStyle.Linear)
	currentTimerTweenSize = TweenService:Create(TimerBar, tweenInfo, {Size = UDim2.new(0, 0, 1, 0)})
	currentTimerTweenColor = TweenService:Create(TimerBar, tweenInfo, {BackgroundColor3 = Color3.fromRGB(231, 76, 60)}) 
	currentTimerTweenSize:Play(); currentTimerTweenColor:Play()
end

local function LockGridAndWait()
	inputLocked = true; TargetMenu.Visible = false; ActionGrid.Visible = true
	for _, b in ipairs(ActionGrid:GetChildren()) do 
		if b:IsA("TextButton") then ApplyButtonGradient(b, Color3.fromRGB(25, 20, 30), Color3.fromRGB(15, 10, 20), Color3.fromRGB(40, 30, 50)); b.TextColor3 = Color3.fromRGB(120, 120, 120) end 
	end
	AddLogMessage("<font color='#55FFFF'><b>MOVE LOCKED IN. WAITING FOR PARTY...</b></font>", false)
end

function RaidTab.Init(parentFrame, tooltipMgr)
	cachedTooltipMgr = tooltipMgr

	-- *** MOBILE ARENA FRAME ***
	ArenaFrame = Instance.new("Frame", parentFrame.Parent)
	ArenaFrame.Name = "RaidArenaFrame"; ArenaFrame.Size = UDim2.new(0.95, 0, 0.95, 0); ArenaFrame.Position = UDim2.new(0.5, 0, 0.5, 0); ArenaFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	ArenaFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20); ArenaFrame.Visible = false; ArenaFrame.ZIndex = 200
	Instance.new("UICorner", ArenaFrame).CornerRadius = UDim.new(0, 12)
	local outerStroke = Instance.new("UIStroke", ArenaFrame); outerStroke.Thickness = 2; outerStroke.Color = Color3.fromRGB(200, 50, 255); outerStroke.LineJoinMode = Enum.LineJoinMode.Miter

	local arenaLayout = Instance.new("UIListLayout", ArenaFrame); arenaLayout.SortOrder = Enum.SortOrder.LayoutOrder; arenaLayout.Padding = UDim.new(0, 5); arenaLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local arenaPadding = Instance.new("UIPadding", ArenaFrame); arenaPadding.PaddingTop = UDim.new(0, 5); arenaPadding.PaddingBottom = UDim.new(0, 5)

	HeaderContainer = Instance.new("Frame", ArenaFrame); HeaderContainer.Size = UDim2.new(1, 0, 0, 25); HeaderContainer.BackgroundTransparency = 1; HeaderContainer.LayoutOrder = 1
	HeaderText = Instance.new("TextLabel", HeaderContainer); HeaderText.Size = UDim2.new(1, 0, 1, 0); HeaderText.BackgroundTransparency = 1; HeaderText.Font = Enum.Font.GothamBlack; HeaderText.TextColor3 = Color3.fromRGB(200, 50, 255); HeaderText.TextSize = 14; HeaderText.Text = "MULTIPLAYER RAID"; ApplyGradient(HeaderText, Color3.fromRGB(200, 100, 255), Color3.fromRGB(150, 40, 200))
	local TimerBG = Instance.new("Frame", HeaderContainer); TimerBG.Size = UDim2.new(1, -20, 0, 4); TimerBG.Position = UDim2.new(0, 10, 1, 0); TimerBG.BackgroundColor3 = Color3.fromRGB(30, 30, 35); Instance.new("UICorner", TimerBG).CornerRadius = UDim.new(1, 0)
	TimerBar = Instance.new("Frame", TimerBG); TimerBar.Size = UDim2.new(1, 0, 1, 0); TimerBar.BackgroundColor3 = Color3.fromRGB(46, 204, 113); Instance.new("UICorner", TimerBar).CornerRadius = UDim.new(1, 0)

	-- [[ DYNAMIC PARTY AREA ]]
	CombatantsFrame = Instance.new("Frame", ArenaFrame); CombatantsFrame.Size = UDim2.new(0.98, 0, 0, 85); CombatantsFrame.BackgroundTransparency = 1; CombatantsFrame.LayoutOrder = 2

	PartyListFrame = Instance.new("Frame", CombatantsFrame); PartyListFrame.Size = UDim2.new(0.48, 0, 1, 0); PartyListFrame.BackgroundTransparency = 1
	local pLayout = Instance.new("UIListLayout", PartyListFrame); pLayout.Padding = UDim.new(0, 5)

	local vsLbl = Instance.new("TextLabel", CombatantsFrame); vsLbl.Size = UDim2.new(0.04, 0, 1, 0); vsLbl.Position = UDim2.new(0.48, 0, 0, 0); vsLbl.BackgroundTransparency = 1; vsLbl.Font = Enum.Font.GothamBlack; vsLbl.TextColor3 = Color3.fromRGB(100, 100, 110); vsLbl.TextSize = 16; vsLbl.Text = "VS"

	BossFrame = Instance.new("Frame", CombatantsFrame); BossFrame.Size = UDim2.new(0.48, 0, 1, 0); BossFrame.Position = UDim2.new(0.52, 0, 0, 0); BossFrame.BackgroundTransparency = 1

	eAvatarBox = Instance.new("Frame", BossFrame); eAvatarBox.Size = UDim2.new(0, 65, 0, 65); eAvatarBox.Position = UDim2.new(1, 0, 0.5, 0); eAvatarBox.AnchorPoint = Vector2.new(1, 0.5); eAvatarBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	Instance.new("UIStroke", eAvatarBox).Color = Color3.fromRGB(255, 100, 100); Instance.new("UIStroke", eAvatarBox).Thickness = 2; Instance.new("UIStroke", eAvatarBox).LineJoinMode = Enum.LineJoinMode.Miter
	eAvatarIcon = Instance.new("TextLabel", eAvatarBox); eAvatarIcon.Size = UDim2.new(1, 0, 1, 0); eAvatarIcon.BackgroundTransparency = 1; eAvatarIcon.Font = Enum.Font.GothamBlack; eAvatarIcon.TextColor3 = Color3.fromRGB(200, 50, 50); eAvatarIcon.TextScaled = true; eAvatarIcon.Text = "?"

	eStatsArea = Instance.new("Frame", BossFrame); eStatsArea.Size = UDim2.new(1, -75, 0, 70); eStatsArea.Position = UDim2.new(0, 0, 0.5, 0); eStatsArea.AnchorPoint = Vector2.new(0, 0.5); eStatsArea.BackgroundTransparency = 1
	local eStatsLayout = Instance.new("UIListLayout", eStatsArea); eStatsLayout.SortOrder = Enum.SortOrder.LayoutOrder; eStatsLayout.Padding = UDim.new(0, 4); eStatsLayout.VerticalAlignment = Enum.VerticalAlignment.Center; eStatsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	BossNameText = Instance.new("TextLabel", eStatsArea); BossNameText.Size = UDim2.new(1, 0, 0, 12); BossNameText.BackgroundTransparency = 1; BossNameText.Font = Enum.Font.GothamBlack; BossNameText.TextColor3 = Color3.fromRGB(255, 120, 120); BossNameText.TextSize = 11; BossNameText.TextScaled = true; BossNameText.TextXAlignment = Enum.TextXAlignment.Right

	local eHpCont
	BossHPBar, BossHPText, eHpCont = CreateBar(eStatsArea, Color3.fromRGB(220, 60, 60), Color3.fromRGB(140, 30, 30), UDim2.new(1, 0, 0, 10), "HP: 100", true)
	BossShieldBar = Instance.new("Frame", eHpCont); BossShieldBar.Size = UDim2.new(0, 0, 1, 0); BossShieldBar.AnchorPoint = Vector2.new(1,0); BossShieldBar.Position = UDim2.new(1,0,0,0); BossShieldBar.BackgroundColor3 = Color3.fromRGB(220, 230, 240); Instance.new("UICorner", BossShieldBar).CornerRadius = UDim.new(0, 4); BossShieldBar.ZIndex = 5; BossHPText.ZIndex = 6

	BossStatusBox = Instance.new("Frame", eStatsArea); BossStatusBox.Size = UDim2.new(1, 0, 0, 16); BossStatusBox.BackgroundTransparency = 1; local bStatusLayout = Instance.new("UIListLayout", BossStatusBox); bStatusLayout.FillDirection = Enum.FillDirection.Horizontal; bStatusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; bStatusLayout.Padding = UDim.new(0, 2)

	local FeedBox = Instance.new("Frame", ArenaFrame); FeedBox.Size = UDim2.new(0.98, 0, 0, 50); FeedBox.BackgroundColor3 = Color3.fromRGB(22, 22, 26); FeedBox.ClipsDescendants = true; FeedBox.LayoutOrder = 3
	Instance.new("UICorner", FeedBox).CornerRadius = UDim.new(0, 6); local fbStroke = Instance.new("UIStroke", FeedBox); fbStroke.Color = Color3.fromRGB(60, 60, 70); fbStroke.Thickness = 1; fbStroke.LineJoinMode = Enum.LineJoinMode.Miter
	LogText = Instance.new("TextLabel", FeedBox); LogText.Size = UDim2.new(1, -10, 1, -10); LogText.Position = UDim2.new(0, 5, 0, 5); LogText.BackgroundTransparency = 1; LogText.Font = Enum.Font.GothamMedium; LogText.TextColor3 = Color3.fromRGB(230, 230, 230); LogText.TextSize = 10; LogText.TextXAlignment = Enum.TextXAlignment.Left; LogText.TextYAlignment = Enum.TextYAlignment.Bottom; LogText.TextWrapped = true; LogText.RichText = true; LogText.Text = ""

	BottomArea = Instance.new("Frame", ArenaFrame); BottomArea.Size = UDim2.new(0.98, 0, 1, -180); BottomArea.BackgroundTransparency = 1; BottomArea.LayoutOrder = 4

	ActionGrid = Instance.new("ScrollingFrame", BottomArea); ActionGrid.Size = UDim2.new(1, 0, 1, 0); ActionGrid.BackgroundTransparency = 1; ActionGrid.ScrollBarThickness = 0; ActionGrid.BorderSizePixel = 0
	local gridLayout = Instance.new("UIGridLayout", ActionGrid); gridLayout.CellSize = UDim2.new(0.48, 0, 0, 38); gridLayout.CellPadding = UDim2.new(0.03, 0, 0, 6); gridLayout.SortOrder = Enum.SortOrder.LayoutOrder; gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ActionGrid.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 10) end)

	TargetMenu = Instance.new("Frame", BottomArea); TargetMenu.Size = UDim2.new(1, 0, 1, -10); TargetMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TargetMenu.Visible = false
	Instance.new("UICorner", TargetMenu).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", TargetMenu).Color = Color3.fromRGB(80, 80, 90)

	local InfoPanel = Instance.new("Frame", TargetMenu); InfoPanel.Size = UDim2.new(0.45, 0, 1, 0); InfoPanel.BackgroundTransparency = 1
	local tHoverTitle = Instance.new("TextLabel", InfoPanel); tHoverTitle.Size = UDim2.new(1, -10, 0, 20); tHoverTitle.Position = UDim2.new(0, 10, 0, 5); tHoverTitle.BackgroundTransparency = 1; tHoverTitle.Font = Enum.Font.GothamBlack; tHoverTitle.TextColor3 = Color3.fromRGB(255, 215, 100); tHoverTitle.TextSize = 13; tHoverTitle.TextXAlignment = Enum.TextXAlignment.Left; tHoverTitle.Text = "SELECT TARGET"; ApplyGradient(tHoverTitle, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))
	local tHoverDesc = Instance.new("TextLabel", InfoPanel); tHoverDesc.Size = UDim2.new(1, -10, 0, 80); tHoverDesc.Position = UDim2.new(0, 10, 0, 25); tHoverDesc.BackgroundTransparency = 1; tHoverDesc.Font = Enum.Font.GothamMedium; tHoverDesc.TextColor3 = Color3.fromRGB(200, 200, 200); tHoverDesc.TextSize = 10; tHoverDesc.TextXAlignment = Enum.TextXAlignment.Left; tHoverDesc.TextYAlignment = Enum.TextYAlignment.Top; tHoverDesc.TextWrapped = true; tHoverDesc.Text = "Select a limb to attack."

	local CancelBtn = Instance.new("TextButton", InfoPanel); CancelBtn.Size = UDim2.new(0.8, 0, 0, 30); CancelBtn.Position = UDim2.new(0, 10, 1, -35); CancelBtn.Font = Enum.Font.GothamBlack; CancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255); CancelBtn.TextSize = 11; CancelBtn.Text = "CANCEL"
	ApplyButtonGradient(CancelBtn, Color3.fromRGB(160, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(60, 20, 20))
	CancelBtn.MouseButton1Click:Connect(function() TargetMenu.Visible = false; ActionGrid.Visible = true; pendingSkillName = nil end)

	local BodyContainer = Instance.new("Frame", TargetMenu); BodyContainer.Size = UDim2.new(0.5, 0, 1, -10); BodyContainer.Position = UDim2.new(0.5, 0, 0, 5); BodyContainer.BackgroundTransparency = 1

	local function CreateLimb(name, size, pos, hoverText, baseColor)
		local limb = Instance.new("TextButton", BodyContainer); limb.Size = size; limb.Position = pos; limb.Text = name:upper(); limb.Font = Enum.Font.GothamBlack; limb.TextColor3 = Color3.fromRGB(255, 255, 255); limb.TextSize = 9
		local mTop = Color3.new(math.clamp(baseColor.R * 0.6, 0, 1), math.clamp(baseColor.G * 0.6, 0, 1), math.clamp(baseColor.B * 0.6, 0, 1))
		local mBot = Color3.new(math.clamp(baseColor.R * 0.3, 0, 1), math.clamp(baseColor.G * 0.3, 0, 1), math.clamp(baseColor.B * 0.3, 0, 1))
		ApplyButtonGradient(limb, mTop, mBot, baseColor)

		limb.MouseEnter:Connect(function()
			local hTop = Color3.new(math.clamp(baseColor.R * 1.2, 0, 1), math.clamp(baseColor.G * 1.2, 0, 1), math.clamp(baseColor.B * 1.2, 0, 1))
			local hBot = Color3.new(math.clamp(baseColor.R * 0.8, 0, 1), math.clamp(baseColor.G * 0.8, 0, 1), math.clamp(baseColor.B * 0.8, 0, 1))
			ApplyButtonGradient(limb, hTop, hBot, baseColor); tHoverTitle.Text = name:upper(); tHoverTitle.TextColor3 = baseColor
			local grad = tHoverTitle:FindFirstChildOfClass("UIGradient"); if grad then grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, hTop), ColorSequenceKeypoint.new(1, hBot)} end
			tHoverDesc.Text = hoverText
		end)

		limb.MouseLeave:Connect(function()
			ApplyButtonGradient(limb, mTop, mBot, baseColor); tHoverTitle.Text = "SELECT TARGET"; tHoverTitle.TextColor3 = Color3.fromRGB(255, 215, 100)
			local grad = tHoverTitle:FindFirstChildOfClass("UIGradient"); if grad then grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 100)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 50))} end
			tHoverDesc.Text = "Select a limb to attack."
		end)

		limb.MouseButton1Click:Connect(function()
			if pendingSkillName and not inputLocked then
				EffectsManager.PlaySFX("Click"); LockGridAndWait()
				Network.RaidAction:FireServer("SubmitMove", { RaidId = currentRaidId, Move = pendingSkillName, Limb = name })
			end
		end)
	end

	local aspect = Instance.new("UIAspectRatioConstraint", BodyContainer); aspect.AspectRatio = 0.8
	CreateLimb("Eyes", UDim2.new(0.24, 0, 0.18, 0), UDim2.new(0.5, 0, 0.08, 0), "Deals 20% Damage. Inflicts Weakness.", Color3.fromRGB(120, 120, 180))
	CreateLimb("Nape", UDim2.new(0.24, 0, 0.06, 0), UDim2.new(0.5, 0, 0.22, 0), "Deals 150% Damage. Low accuracy.", Color3.fromRGB(220, 80, 80))
	CreateLimb("Body", UDim2.new(0.48, 0, 0.38, 0), UDim2.new(0.5, 0, 0.45, 0), "Deals 100% Damage. Standard accuracy.", Color3.fromRGB(80, 160, 80))
	CreateLimb("Arms", UDim2.new(0.22, 0, 0.38, 0), UDim2.new(0.14, 0, 0.45, 0), "Deals 50% Damage. Inflicts Weakened.", Color3.fromRGB(180, 140, 60))
	CreateLimb("Arms", UDim2.new(0.22, 0, 0.38, 0), UDim2.new(0.86, 0, 0.45, 0), "Deals 50% Damage. Inflicts Weakened.", Color3.fromRGB(180, 140, 60))
	CreateLimb("Legs", UDim2.new(0.23, 0, 0.32, 0), UDim2.new(0.37, 0, 0.81, 0), "Deals 50% Damage. Inflicts Crippled.", Color3.fromRGB(80, 140, 180))
	CreateLimb("Legs", UDim2.new(0.23, 0, 0.32, 0), UDim2.new(0.63, 0, 0.81, 0), "Deals 50% Damage. Inflicts Crippled.", Color3.fromRGB(80, 140, 180))
	for _, child in ipairs(BodyContainer:GetChildren()) do if child:IsA("TextButton") then child.AnchorPoint = Vector2.new(0.5, 0.5) end end

	LeaveBtn = Instance.new("TextButton", ArenaFrame); LeaveBtn.Size = UDim2.new(0.6, 0, 0, 45); LeaveBtn.LayoutOrder = 5; LeaveBtn.Font = Enum.Font.GothamBlack; LeaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255); LeaveBtn.TextSize = 16; LeaveBtn.Text = "LEAVE ARENA"; LeaveBtn.Visible = false
	ApplyButtonGradient(LeaveBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 80, 20))

	LeaveBtn.MouseButton1Click:Connect(function()
		EffectsManager.PlaySFX("Click")
		ArenaFrame.Visible = false; parentFrame.Visible = true 
		local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
		if topGui then
			if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = true end
			if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = true end
		end
	end)

	local function BuildParty(partyData)
		for _, child in ipairs(PartyListFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		PartyUIBars = {}

		local pData = partyData.PartyData or partyData.Party or partyData
		local pSize = #pData
		local panelHeight = 70
		local cHeight = math.max(85, (pSize * panelHeight) + ((pSize - 1) * 5))

		CombatantsFrame.Size = UDim2.new(0.98, 0, 0, cHeight)
		BottomArea.Size = UDim2.new(0.98, 0, 1, -(95 + cHeight)) 

		for _, mem in ipairs(pData) do
			local mFr = Instance.new("Frame", PartyListFrame)
			mFr.Name = "P_" .. mem.UserId
			mFr.Size = UDim2.new(1, 0, 0, panelHeight)
			mFr.BackgroundTransparency = 1

			local pAvatarBox = Instance.new("Frame", mFr)
			pAvatarBox.Size = UDim2.new(0, 60, 0, 60); pAvatarBox.Position = UDim2.new(0, 0, 0.5, 0); pAvatarBox.AnchorPoint = Vector2.new(0, 0.5); pAvatarBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
			Instance.new("UIStroke", pAvatarBox).Color = (mem.UserId == player.UserId) and Color3.fromRGB(150, 200, 255) or Color3.fromRGB(80, 120, 200); Instance.new("UIStroke", pAvatarBox).Thickness = 2; Instance.new("UIStroke", pAvatarBox).LineJoinMode = Enum.LineJoinMode.Miter
			local pAvatarImg = Instance.new("ImageLabel", pAvatarBox); pAvatarImg.Size = UDim2.new(1, 0, 1, 0); pAvatarImg.BackgroundTransparency = 1
			if mem.UserId > 0 then pAvatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. mem.UserId .. "&w=150&h=150"
			else pAvatarImg.Image = "rbxassetid://132795247" end 

			local pStatsArea = Instance.new("Frame", mFr)
			pStatsArea.Size = UDim2.new(1, -65, 1, 0); pStatsArea.Position = UDim2.new(0, 65, 0, 0); pStatsArea.BackgroundTransparency = 1
			local pLayout = Instance.new("UIListLayout", pStatsArea); pLayout.SortOrder = Enum.SortOrder.LayoutOrder; pLayout.Padding = UDim.new(0, 2); pLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			local nameLbl = Instance.new("TextLabel", pStatsArea); nameLbl.Size = UDim2.new(1, 0, 0, 12); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBlack; nameLbl.TextColor3 = (mem.UserId == player.UserId) and Color3.fromRGB(150, 200, 255) or Color3.fromRGB(200, 220, 255); nameLbl.TextSize = 11; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.TextScaled = true; nameLbl.Text = string.upper(mem.Name)

			local hpBar, hpTxt = CreateBar(pStatsArea, Color3.fromRGB(220, 60, 60), Color3.fromRGB(140, 30, 30), UDim2.new(1, 0, 0, 10), "HP: " .. math.floor(mem.HP) .. " / " .. math.floor(mem.MaxHP), false)
			local gasBar, gasTxt = CreateBar(pStatsArea, Color3.fromRGB(150, 220, 255), Color3.fromRGB(60, 140, 200), UDim2.new(1, 0, 0, 8), "GAS: " .. math.floor(mem.Gas) .. " / " .. math.floor(mem.MaxGas), false)

			local statusBox = Instance.new("Frame", pStatsArea); statusBox.Size = UDim2.new(1, 0, 0, 16); statusBox.BackgroundTransparency = 1
			local sLayout = Instance.new("UIListLayout", statusBox); sLayout.FillDirection = Enum.FillDirection.Horizontal; sLayout.Padding = UDim.new(0, 2)

			PartyUIBars[mem.UserId] = { HPBar = hpBar, HPText = hpTxt, GasBar = gasBar, GasText = gasTxt, StatusBox = statusBox }
		end
	end

	local function SyncParty(partyData)
		local pData = partyData.PartyData or partyData.Party or partyData
		local tInfo = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		for _, mem in ipairs(pData) do
			local ui = PartyUIBars[mem.UserId]
			if ui then
				TweenService:Create(ui.HPBar, tInfo, {Size = UDim2.new(math.clamp(mem.HP / mem.MaxHP, 0, 1), 0, 1, 0)}):Play()
				ui.HPText.Text = "HP: " .. math.floor(mem.HP) .. " / " .. math.floor(mem.MaxHP)
				TweenService:Create(ui.GasBar, tInfo, {Size = UDim2.new(math.clamp(mem.Gas / mem.MaxGas, 0, 1), 0, 1, 0)}):Play()
				ui.GasText.Text = "GAS: " .. math.floor(mem.Gas) .. " / " .. math.floor(mem.MaxGas)
				RenderStatuses(ui.StatusBox, mem.Statuses)
			end
		end
	end

	local function UpdateActionGrid(partyData)
		inputLocked = false
		for _, child in ipairs(ActionGrid:GetChildren()) do 
			if child:IsA("TextButton") then child.Visible = false end 
		end

		local pData = partyData.PartyData or partyData.Party or partyData
		local myData = nil
		for _, p in ipairs(pData) do if p.UserId == player.UserId then myData = p; break end end
		if not myData or myData.HP <= 0 then return end 

		local eqWpn = player:GetAttribute("EquippedWeapon") or "None"
		local pStyle = (ItemData.Equipment[eqWpn] and ItemData.Equipment[eqWpn].Style) or "None"
		local pTitan = player:GetAttribute("Titan") or "None"
		local pClan = player:GetAttribute("Clan") or "None"
		local isTransformed = myData.Statuses and myData.Statuses["Transformed"]
		local isODM = (pStyle == "Ultrahard Steel Blades" or pStyle == "Thunder Spears" or pStyle == "Anti-Personnel")

		local function CreateBtn(sName, color, order)
			local sData = SkillData.Skills[sName]
			if not sData then return end
			if sName == "Transform" and (pClan == "Ackerman" or pClan == "Awakened Ackerman") then return end

			local cd = myData.Cooldowns and myData.Cooldowns[sName] or 0
			local energyCost = sData.EnergyCost or 0
			local gasCost = sData.GasCost or 0
			local hasGas = (myData.Gas or 0) >= gasCost
			local hasEnergy = (myData.TitanEnergy or 0) >= energyCost
			local isReady = (cd == 0) and hasGas and hasEnergy

			local btn = ActionGrid:FindFirstChild("Btn_" .. sName)
			if not btn then
				btn = Instance.new("TextButton", ActionGrid)
				btn.Name = "Btn_" .. sName
				btn.RichText = true; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11

				btn.MouseButton1Click:Connect(function()
					local currentMyData
					for _, p in ipairs(pData) do if p.UserId == player.UserId then currentMyData = p; break end end
					local c_cd = currentMyData and currentMyData.Cooldowns and currentMyData.Cooldowns[sName] or 0
					local c_ready = (c_cd == 0) and ((currentMyData and currentMyData.Gas or 0) >= gasCost)

					if not inputLocked and c_ready then
						EffectsManager.PlaySFX("Click")
						-- [[ FIX: Directly submit Retreat/FallBack/CloseIn instead of opening target menu ]]
						if sName == "Retreat" or sName == "Fall Back" or sName == "Close In" or sData.Effect == "Rest" or sData.Effect == "TitanRest" or sData.Effect == "Eject" or sData.Effect == "Transform" or sData.Effect == "Block" then
							if cachedTooltipMgr then cachedTooltipMgr.Hide() end
							LockGridAndWait()
							Network.RaidAction:FireServer("SubmitMove", { RaidId = currentRaidId, Move = sName, Limb = "Body" })
						else
							if cachedTooltipMgr then cachedTooltipMgr.Hide() end
							pendingSkillName = sName
							ActionGrid.Visible = false
							TargetMenu.Visible = true
						end
					end
				end)

				btn.MouseEnter:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Show(sData.Description or sName) end end)
				btn.MouseLeave:Connect(function() if cachedTooltipMgr then cachedTooltipMgr.Hide() end end)
			end

			btn.Visible = true
			btn.LayoutOrder = order or 10

			if isReady then
				ApplyButtonGradient(btn, color, Color3.new(color.R*0.7, color.G*0.7, color.B*0.7), color); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				ApplyButtonGradient(btn, Color3.fromRGB(25, 20, 30), Color3.fromRGB(15, 10, 20), Color3.fromRGB(40, 30, 50)); btn.TextColor3 = Color3.fromRGB(120, 120, 120)
			end

			local cdStr = isReady and "READY" or "CD: " .. cd
			if cd == 0 then if not hasGas then cdStr = "NO GAS" elseif not hasEnergy then cdStr = "NO HEAT" end end

			btn.Text = sName:upper() .. "\n<font size='9' color='" .. (isReady and "#CCCCCC" or "#FF5555") .. "'>[" .. cdStr .. "]</font>"
		end

		if isTransformed then
			CreateBtn("Titan Recover", Color3.fromRGB(40, 140, 80), 1); CreateBtn("Titan Punch", Color3.fromRGB(120, 40, 40), 2); CreateBtn("Titan Kick", Color3.fromRGB(140, 60, 40), 3); CreateBtn("Eject", Color3.fromRGB(140, 40, 40), 4)
			local orderIndex = 5
			for sName, sData in pairs(SkillData.Skills) do
				if sData.Requirement == pTitan or sData.Requirement == "AnyTitan" or sData.Requirement == "Transformed" then
					if sName ~= "Titan Recover" and sName ~= "Eject" and sName ~= "Titan Punch" and sName ~= "Titan Kick" and sName ~= "Transform" then
						CreateBtn(sName, Color3.fromRGB(60, 40, 60), sData.Order or orderIndex); orderIndex += 1
					end
				end
			end
		else
			CreateBtn("Basic Slash", Color3.fromRGB(120, 40, 40), 1)
			CreateBtn("Maneuver", Color3.fromRGB(40, 80, 140), 2)

			-- [[ FIX: Dynamic Range buttons based on the Current Range! ]]
			if currentRange == "Long" then
				CreateBtn("Close In", Color3.fromRGB(80, 140, 100), 3)
			else
				CreateBtn("Fall Back", Color3.fromRGB(80, 100, 140), 3)
			end

			CreateBtn("Recover", Color3.fromRGB(40, 140, 80), 4)

			-- [[ FIX: Added the Retreat Button ]]
			CreateBtn("Retreat", Color3.fromRGB(60, 60, 70), 5)

			if pTitan ~= "None" and pClan ~= "Ackerman" and pClan ~= "Awakened Ackerman" then CreateBtn("Transform", Color3.fromRGB(200, 150, 50), 6) end

			local orderIndex = 7
			for sName, sData in pairs(SkillData.Skills) do
				-- Exclude manually added buttons to prevent duplicates
				if sName == "Basic Slash" or sName == "Maneuver" or sName == "Recover" or sName == "Transform" or sName == "Close In" or sName == "Fall Back" or sName == "Retreat" then continue end

				local req = sData.Requirement
				if req == pStyle or req == pClan or (req == "Ackerman" and pClan == "Awakened Ackerman") or (req == "ODM" and isODM) then
					CreateBtn(sName, Color3.fromRGB(45, 40, 60), sData.Order or orderIndex); orderIndex += 1
				end
			end
		end
	end

	local function SyncBoss(bossData)
		local bData = bossData.BossData or bossData.Boss or bossData
		BossNameText.Text = bData.Name:upper()

		if bData.MaxGateHP and bData.MaxGateHP > 0 then
			BossShieldBar.Visible = true
			TweenService:Create(BossShieldBar, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp(bData.GateHP / bData.MaxGateHP, 0, 1), 0, 1, 0)}):Play()
			if bData.GateHP > 0 then
				if bData.GateType == "Steam" then BossHPText.Text = bData.GateType:upper() .. ": " .. math.floor(bData.GateHP) .. " TURNS LEFT"
				else BossHPText.Text = bData.GateType:upper() .. ": " .. math.floor(bData.GateHP) .. " / " .. math.floor(bData.MaxGateHP) end
			else BossHPText.Text = "HP: " .. math.floor(bData.HP) .. " / " .. math.floor(bData.MaxHP) end
		else
			BossShieldBar.Visible = false
			BossHPText.Text = "HP: " .. math.floor(bData.HP) .. " / " .. math.floor(bData.MaxHP)
		end

		TweenService:Create(BossHPBar, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp(bData.HP / bData.MaxHP, 0, 1), 0, 1, 0)}):Play()
		RenderStatuses(BossStatusBox, bData.Statuses)
	end

	Network:WaitForChild("RaidUpdate").OnClientEvent:Connect(function(action, data)
		local safeParty = data and (data.PartyData or data.Party)
		local safeBoss = data and (data.BossData or data.Boss)

		if action == "RaidStarted" then
			currentRaidId = data.RaidId; logMessages = {}
			currentRange = data.Range or "Close" -- [[ FIX: Initial Range Setup ]]

			local topGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
			if topGui then
				if topGui:FindFirstChild("TopBar") then topGui.TopBar.Visible = false end
				if topGui:FindFirstChild("NavBar") then topGui.NavBar.Visible = false end
			end

			parentFrame.Visible = false; ArenaFrame.Visible = true; LeaveBtn.Visible = false; TargetMenu.Visible = false; ActionGrid.Visible = true
			AddLogMessage("<font color='#FFD700'><b>RAID COMMENCES! STAY ALIVE!</b></font>", false)

			BuildParty(safeParty)
			SyncParty(safeParty)
			SyncBoss(safeBoss)
			UpdateActionGrid(safeParty)
			StartVisualTimer(data.EndTime)

		elseif action == "TurnStrike" then
			ShakeUI(data.ShakeType); AddLogMessage(data.LogMsg, true)
			if data.Range then currentRange = data.Range end -- [[ FIX: Update Range if it changes mid-turn ]]

			if data.SkillUsed then 
				local attackerIsLeft = false
				if data.Attacker ~= BossNameText.Text then attackerIsLeft = true end
				if EffectsManager and type(EffectsManager.PlayCombatEffect) == "function" then
					EffectsManager.PlayCombatEffect(data.SkillUsed, attackerIsLeft, nil, eAvatarBox, true) 
				end
			end

			if safeParty then SyncParty(safeParty) end
			if safeBoss then SyncBoss(safeBoss) end

		elseif action == "NextTurnStarted" then
			StartVisualTimer(data.EndTime)
			if data.Range then currentRange = data.Range end -- [[ FIX: Sync Range before drawing UI ]]

			-- [[ THE CRITICAL BUG FIX: Actually call SyncBoss so the UI updates the Steam visually ]]
			if safeBoss then SyncBoss(safeBoss) end

			local myData = nil
			if safeParty then
				for _, p in ipairs(safeParty) do 
					if p.UserId == player.UserId then myData = p; break end 
				end
			end

			if myData and myData.HP <= 0 then 
				inputLocked = true
				for _, child in ipairs(ActionGrid:GetChildren()) do if child:IsA("TextButton") then child.Visible = false end end
				AddLogMessage("<font color='#FF5555'>You have fallen in battle. Spectating party...</font>", true)
			elseif safeParty then
				UpdateActionGrid(safeParty)
			end

		elseif action == "RaidEnded" then
			if data == true then 
				if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Victory", 1) end
			else 
				if EffectsManager and type(EffectsManager.PlaySFX) == "function" then EffectsManager.PlaySFX("Defeat", 1) end 
			end
			AddLogMessage("<font color='#FF5555'><b>RAID CONCLUDED.</b></font>", true)
			ActionGrid.Visible = false
			LeaveBtn.Visible = true
		end
	end)
end

return RaidTab