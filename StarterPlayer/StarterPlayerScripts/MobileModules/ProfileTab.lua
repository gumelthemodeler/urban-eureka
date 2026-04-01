-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local ProfileTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local CosmeticData = require(ReplicatedStorage:WaitForChild("CosmeticData"))

local NotificationManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("NotificationManager"))
local UIAuraManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("UIAuraManager"))

local player = Players.LocalPlayer
local MainFrame, ContentArea
local SubTabs, SubBtns = {}, {}

local InvGrid
local wpnLabel, accLabel, titanLabel, clanLabel, regimentLabel
local titanAwakenBtn, clanAwakenBtn, prestigeBtn
local RadarContainer, regIcon, AvatarBox, AvatarAuraGlow, AvatarTitle
local toggleStatsBtn
local prestigeValLbl, eloValLbl
local InvTitle 
local isShowingTitanStats = false
local MAX_INVENTORY_CAPACITY = 50

local RarityColors = { ["Common"] = "#AAAAAA", ["Uncommon"] = "#55FF55", ["Rare"] = "#5588FF", ["Epic"] = "#CC44FF", ["Legendary"] = "#FFD700", ["Mythical"] = "#FF3333", ["Transcendent"] = "#FF55FF" }
local RarityOrder = { Transcendent = 0, Mythical = 1, Legendary = 2, Epic = 3, Rare = 4, Uncommon = 5, Common = 6 }
local SellValues = { Common = 10, Uncommon = 25, Rare = 75, Epic = 200, Legendary = 500, Mythical = 1500, Transcendent = 0 }

local TEXT_COLORS = { PrestigeYellow = "#FFD700", EloBlue = "#55AAFF", DefaultGreen = "#55FF55" }
local REG_COLORS = { ["Garrison"] = "#FF5555", ["Military Police"] = "#55FF55", ["Scout Regiment"] = "#55AAFF" }

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

-- [[ THE FIX: Restored text isolation so text stays purely white, disabled AutoButtonColor ]]
local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor = false 
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}; grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 4)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn); stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end

	if not btn:GetAttribute("GradientTextFixed") then
		btn:SetAttribute("GradientTextFixed", true)
		local textLbl = Instance.new("TextLabel", btn)
		textLbl.Name = "BtnTextLabel"
		textLbl.Size = UDim2.new(1, 0, 1, 0)
		textLbl.BackgroundTransparency = 1
		textLbl.Font = btn.Font
		textLbl.TextSize = btn.TextSize
		textLbl.TextScaled = btn.TextScaled
		textLbl.RichText = btn.RichText
		textLbl.TextWrapped = btn.TextWrapped
		textLbl.TextXAlignment = btn.TextXAlignment
		textLbl.TextYAlignment = btn.TextYAlignment
		textLbl.ZIndex = btn.ZIndex + 1

		local tConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint")
		if tConstraint then tConstraint.Parent = textLbl end

		btn.ChildAdded:Connect(function(child) 
			if child:IsA("UITextSizeConstraint") then task.delay(0, function() child.Parent = textLbl end) end 
		end)

		textLbl.Text = btn.Text
		textLbl.TextColor3 = btn.TextColor3
		btn.Text = ""

		btn:GetPropertyChangedSignal("Text"):Connect(function() 
			if btn.Text ~= "" then textLbl.Text = btn.Text; btn.Text = "" end 
		end)
		btn:GetPropertyChangedSignal("TextColor3"):Connect(function() textLbl.TextColor3 = btn.TextColor3 end)
		btn:GetPropertyChangedSignal("RichText"):Connect(function() textLbl.RichText = btn.RichText end)
	end
end

local function TweenGradient(grad, targetTop, targetBot, duration)
	local startTop = grad.Color.Keypoints[1].Value
	local startBot = grad.Color.Keypoints[#grad.Color.Keypoints].Value
	local val = Instance.new("NumberValue"); val.Value = 0
	local tween = TweenService:Create(val, TweenInfo.new(duration), {Value = 1})
	val.Changed:Connect(function(v) grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, startTop:Lerp(targetTop, v)), ColorSequenceKeypoint.new(1, startBot:Lerp(targetBot, v))} end)
	tween:Play(); tween.Completed:Connect(function() val:Destroy() end)
end

local function DrawLineScale(parent, p1x, p1y, p2x, p2y, color, thickness, zindex)
	local dx = p2x - p1x; local dy = p2y - p1y; local dist = math.sqrt(dx*dx + dy*dy)
	local frame = Instance.new("Frame", parent)
	frame.Size = UDim2.new(0, dist, 0, thickness); frame.Position = UDim2.new(0, (p1x + p2x)/2, 0, (p1y + p2y)/2)
	frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Rotation = math.deg(math.atan2(dy, dx))
	frame.BackgroundColor3 = color; frame.BorderSizePixel = 0; frame.ZIndex = zindex or 1
	return frame
end

local function DrawUITriangle(parent, p1, p2, p3, color, transp, zIndex)
	local edges = { {p1, p2}, {p2, p3}, {p3, p1} }
	table.sort(edges, function(a, b) return (a[1]-a[2]).Magnitude > (b[1]-b[2]).Magnitude end)
	local a, b = edges[1][1], edges[1][2]; local c = edges[2][1] == a and edges[2][2] or edges[2][1]
	if c == b then c = edges[3][1] == a and edges[3][2] or edges[3][1] end
	local ab = b - a; local ac = c - a; local dir = ab.Unit; local projLen = ac:Dot(dir); local proj = dir * projLen; local h = (ac - proj).Magnitude
	local w1 = projLen; local w2 = ab.Magnitude - projLen
	local t1 = Instance.new("ImageLabel")
	t1.BackgroundTransparency = 1; t1.Image = "rbxassetid://319692171"; t1.ImageColor3 = color; t1.ImageTransparency = transp; t1.ZIndex = zIndex; t1.BorderSizePixel = 0; t1.AnchorPoint = Vector2.new(0.5, 0.5)
	local t2 = t1:Clone(); t1.Size = UDim2.new(0, w1, 0, h); t2.Size = UDim2.new(0, w2, 0, h)
	t1.Position = UDim2.new(0, a.X + proj.X/2, 0, a.Y + proj.Y/2); t2.Position = UDim2.new(0, b.X + (proj.X - ab.X)/2, 0, b.Y + (proj.Y - ab.Y)/2)
	t1.Rotation = math.deg(math.atan2(dir.Y, dir.X)); t2.Rotation = math.deg(math.atan2(-dir.Y, -dir.X))
	t1.Parent = parent; t2.Parent = parent
end

function ProfileTab.Init(parentFrame, tooltipMgr)
	local cachedTooltipMgr = tooltipMgr
	MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Name = "ProfileFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false
	MainFrame.ScrollBarThickness = 0; MainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local mLayout = Instance.new("UIListLayout", MainFrame)
	mLayout.SortOrder = Enum.SortOrder.LayoutOrder; mLayout.Padding = UDim.new(0, 15); mLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local mPad = Instance.new("UIPadding", MainFrame); mPad.PaddingTop = UDim.new(0, 10); mPad.PaddingBottom = UDim.new(0, 30)

	-- ==========================================
	-- [[ 1. TOP COLUMN (AVATAR & INFO FIXED) ]]
	-- ==========================================
	local ShowcaseCard = Instance.new("Frame", MainFrame)
	ShowcaseCard.Size = UDim2.new(0.95, 0, 0, 0); ShowcaseCard.AutomaticSize = Enum.AutomaticSize.Y; ShowcaseCard.BackgroundColor3 = Color3.fromRGB(20, 20, 25); ShowcaseCard.LayoutOrder = 1
	Instance.new("UICorner", ShowcaseCard).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", ShowcaseCard).Color = Color3.fromRGB(80, 80, 90)

	local scLayout = Instance.new("UIListLayout", ShowcaseCard)
	scLayout.SortOrder = Enum.SortOrder.LayoutOrder; scLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; scLayout.Padding = UDim.new(0, 10)
	local scPad = Instance.new("UIPadding", ShowcaseCard); scPad.PaddingTop = UDim.new(0, 20); scPad.PaddingBottom = UDim.new(0, 20)

	AvatarTitle = Instance.new("TextLabel", ShowcaseCard)
	AvatarTitle.Size = UDim2.new(1, 0, 0, 25); AvatarTitle.BackgroundTransparency = 1; AvatarTitle.Font = Enum.Font.GothamBlack; AvatarTitle.TextColor3 = Color3.fromRGB(255, 255, 255); AvatarTitle.TextSize = 16; AvatarTitle.Text = "104TH CADET"; AvatarTitle.LayoutOrder = 1; AvatarTitle.ZIndex = 10

	local AvatarContainer = Instance.new("Frame", ShowcaseCard)
	AvatarContainer.Size = UDim2.new(0.4, 0, 0.4, 0); AvatarContainer.BackgroundTransparency = 1; AvatarContainer.LayoutOrder = 2
	Instance.new("UIAspectRatioConstraint", AvatarContainer).AspectRatio = 1.0

	AvatarAuraGlow = Instance.new("Frame", AvatarContainer)
	AvatarAuraGlow.Size = UDim2.new(1, 0, 1, 0); AvatarAuraGlow.Position = UDim2.new(0.5, 0, 0.5, 0); AvatarAuraGlow.AnchorPoint = Vector2.new(0.5, 0.5); AvatarAuraGlow.BackgroundTransparency = 1; AvatarAuraGlow.ZIndex = 1

	AvatarBox = Instance.new("ImageLabel", AvatarContainer)
	AvatarBox.Size = UDim2.new(1, 0, 1, 0); AvatarBox.Position = UDim2.new(0.5, 0, 0.5, 0); AvatarBox.AnchorPoint = Vector2.new(0.5, 0.5); AvatarBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	AvatarBox.Image = "rbxthumb://type=AvatarBust&id="..player.UserId.."&w=420&h=420"; AvatarBox.ZIndex = 5
	Instance.new("UICorner", AvatarBox).CornerRadius = UDim.new(1, 0); Instance.new("UIStroke", AvatarBox).Color = Color3.fromRGB(100, 100, 110); AvatarBox.UIStroke.Thickness = 2

	local PlayerNameLbl = Instance.new("TextLabel", ShowcaseCard)
	PlayerNameLbl.Size = UDim2.new(1, 0, 0, 30); PlayerNameLbl.BackgroundTransparency = 1; PlayerNameLbl.Font = Enum.Font.GothamBlack; PlayerNameLbl.TextColor3 = Color3.fromRGB(255, 255, 255); PlayerNameLbl.TextSize = 22; PlayerNameLbl.Text = string.upper(player.Name); PlayerNameLbl.LayoutOrder = 3
	ApplyGradient(PlayerNameLbl, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	local InfoTextContainer = Instance.new("Frame", ShowcaseCard)
	InfoTextContainer.Size = UDim2.new(1, -20, 0, 0); InfoTextContainer.AutomaticSize = Enum.AutomaticSize.Y; InfoTextContainer.BackgroundTransparency = 1; InfoTextContainer.LayoutOrder = 4
	local itLayout = Instance.new("UIListLayout", InfoTextContainer); itLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; itLayout.Padding = UDim.new(0, 4)

	local function CreateStyledInfoLabel(parent)
		local l = Instance.new("TextLabel", parent); l.Size = UDim2.new(1, 0, 0, 18); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold; l.TextColor3 = Color3.fromRGB(180, 180, 190); l.TextSize = 14; l.RichText = true
		return l
	end

	prestigeValLbl = CreateStyledInfoLabel(InfoTextContainer)
	eloValLbl = CreateStyledInfoLabel(InfoTextContainer)

	regIcon = Instance.new("ImageLabel", ShowcaseCard)
	regIcon.Size = UDim2.new(0, 115, 0, 115); regIcon.BackgroundTransparency = 1; regIcon.ZIndex = 6; regIcon.LayoutOrder = 5

	-- ==========================================
	-- [[ 2. MIDDLE COLUMN (RADAR & STATS) ]]
	-- ==========================================
	local MidCol = Instance.new("Frame", MainFrame)
	MidCol.Size = UDim2.new(0.95, 0, 0, 420); MidCol.BackgroundColor3 = Color3.fromRGB(20, 20, 25); MidCol.LayoutOrder = 2
	Instance.new("UICorner", MidCol).CornerRadius = UDim.new(0, 12); Instance.new("UIStroke", MidCol).Color = Color3.fromRGB(80, 80, 90)

	local midLayout = Instance.new("UIListLayout", MidCol); midLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; midLayout.SortOrder = Enum.SortOrder.LayoutOrder; midLayout.Padding = UDim.new(0, 10)
	local midPad = Instance.new("UIPadding", MidCol); midPad.PaddingTop = UDim.new(0, 15); midPad.PaddingBottom = UDim.new(0, 15)

	local RadarBG = Instance.new("Frame", MidCol)
	RadarBG.Size = UDim2.new(0.95, 0, 0, 200); RadarBG.BackgroundColor3 = Color3.fromRGB(15, 15, 20); RadarBG.LayoutOrder = 1
	Instance.new("UICorner", RadarBG).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", RadarBG).Color = Color3.fromRGB(60, 60, 70)

	RadarContainer = Instance.new("Frame", RadarBG)
	RadarContainer.Size = UDim2.new(1, 0, 1, 0); RadarContainer.Position = UDim2.new(0.5, 0, 0.5, 0); RadarContainer.AnchorPoint = Vector2.new(0.5, 0.5); RadarContainer.BackgroundTransparency = 1
	Instance.new("UIAspectRatioConstraint", RadarContainer).AspectRatio = 1

	local StatsRect = Instance.new("Frame", MidCol)
	StatsRect.Size = UDim2.new(0.95, 0, 0, 0); StatsRect.AutomaticSize = Enum.AutomaticSize.Y; StatsRect.BackgroundColor3 = Color3.fromRGB(15, 15, 20); StatsRect.LayoutOrder = 2
	Instance.new("UICorner", StatsRect).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", StatsRect).Color = Color3.fromRGB(60, 60, 70)
	local srLayout = Instance.new("UIListLayout", StatsRect); srLayout.Padding = UDim.new(0, 0); srLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local srPad = Instance.new("UIPadding", StatsRect); srPad.PaddingTop = UDim.new(0, 10); srPad.PaddingBottom = UDim.new(0, 10)

	local function CreateInfoLabel(parent)
		local l = Instance.new("TextLabel", parent); l.Size = UDim2.new(1, 0, 0, 36); l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold; l.TextColor3 = Color3.fromRGB(200, 200, 200); l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextWrapped = true
		local pad = Instance.new("UIPadding", l); pad.PaddingLeft = UDim.new(0, 15)
		return l
	end

	local titanRow = Instance.new("Frame", StatsRect); titanRow.Size = UDim2.new(1, 0, 0, 36); titanRow.BackgroundTransparency = 1
	titanLabel = CreateInfoLabel(titanRow); titanLabel.Size = UDim2.new(1, 0, 1, 0)
	titanAwakenBtn = Instance.new("TextButton", titanRow); titanAwakenBtn.Size = UDim2.new(0.28, 0, 0.8, 0); titanAwakenBtn.Position = UDim2.new(0.68, 0, 0.1, 0)
	titanAwakenBtn.Font = Enum.Font.GothamBold; titanAwakenBtn.TextColor3 = Color3.fromRGB(255, 255, 255); titanAwakenBtn.TextSize = 10; titanAwakenBtn.Text = "AWAKEN"
	ApplyButtonGradient(titanAwakenBtn, Color3.fromRGB(200, 60, 60), Color3.fromRGB(120, 30, 30), Color3.fromRGB(80, 20, 20)); titanAwakenBtn.Visible = false

	regimentLabel = CreateInfoLabel(StatsRect); regimentLabel.RichText = true

	local clanRow = Instance.new("Frame", StatsRect); clanRow.Size = UDim2.new(1, 0, 0, 36); clanRow.BackgroundTransparency = 1
	clanLabel = CreateInfoLabel(clanRow); clanLabel.Size = UDim2.new(1, 0, 1, 0)
	clanAwakenBtn = Instance.new("TextButton", clanRow); clanAwakenBtn.Size = UDim2.new(0.28, 0, 0.8, 0); clanAwakenBtn.Position = UDim2.new(0.68, 0, 0.1, 0)
	clanAwakenBtn.Font = Enum.Font.GothamBold; clanAwakenBtn.TextColor3 = Color3.fromRGB(255, 255, 255); clanAwakenBtn.TextSize = 10; clanAwakenBtn.Text = "AWAKEN"
	ApplyButtonGradient(clanAwakenBtn, Color3.fromRGB(200, 60, 60), Color3.fromRGB(120, 30, 30), Color3.fromRGB(80, 20, 20)); clanAwakenBtn.Visible = false

	wpnLabel = CreateInfoLabel(StatsRect); wpnLabel.RichText = true
	accLabel = CreateInfoLabel(StatsRect); accLabel.RichText = true

	local ActionRow = Instance.new("Frame", MidCol)
	ActionRow.Size = UDim2.new(0.95, 0, 0, 40); ActionRow.BackgroundTransparency = 1; ActionRow.LayoutOrder = 3
	local arLayout = Instance.new("UIListLayout", ActionRow); arLayout.FillDirection = Enum.FillDirection.Horizontal; arLayout.Padding = UDim.new(0.02, 0)

	prestigeBtn = Instance.new("TextButton", ActionRow)
	prestigeBtn.Size = UDim2.new(0.49, 0, 1, 0); prestigeBtn.LayoutOrder = 1
	prestigeBtn.Font = Enum.Font.GothamBlack; prestigeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); prestigeBtn.TextSize = 12; prestigeBtn.Text = "PRESTIGE"
	ApplyButtonGradient(prestigeBtn, Color3.fromRGB(220, 180, 50), Color3.fromRGB(140, 100, 20), Color3.fromRGB(255, 215, 100)); prestigeBtn.Visible = false

	toggleStatsBtn = Instance.new("TextButton", ActionRow)
	toggleStatsBtn.Size = UDim2.new(1, 0, 1, 0); toggleStatsBtn.LayoutOrder = 2
	toggleStatsBtn.Font = Enum.Font.GothamBold; toggleStatsBtn.TextColor3 = Color3.fromRGB(200, 200, 255); toggleStatsBtn.TextSize = 12; toggleStatsBtn.Text = "VIEW TITAN STATS"
	ApplyButtonGradient(toggleStatsBtn, Color3.fromRGB(60, 60, 80), Color3.fromRGB(30, 30, 40), Color3.fromRGB(100, 100, 150))

	prestigeBtn:GetPropertyChangedSignal("Visible"):Connect(function()
		if prestigeBtn.Visible then toggleStatsBtn.Size = UDim2.new(0.49, 0, 1, 0) else toggleStatsBtn.Size = UDim2.new(1, 0, 1, 0) end
	end)

	midLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() MidCol.Size = UDim2.new(0.95, 0, 0, midLayout.AbsoluteContentSize.Y + 30) end)


	-- ==========================================
	-- [[ 3. SUB-NAVIGATION TABS (INVENTORY & COSMETICS) ]]
	-- ==========================================
	local TopNav = Instance.new("ScrollingFrame", MainFrame)
	TopNav.Size = UDim2.new(0.95, 0, 0, 40); TopNav.BackgroundColor3 = Color3.fromRGB(15, 15, 18); TopNav.ScrollBarThickness = 0; TopNav.ScrollingDirection = Enum.ScrollingDirection.X; TopNav.LayoutOrder = 3
	Instance.new("UICorner", TopNav).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", TopNav).Color = Color3.fromRGB(80, 80, 90)
	local navLayout = Instance.new("UIListLayout", TopNav); navLayout.FillDirection = Enum.FillDirection.Horizontal; navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left; navLayout.VerticalAlignment = Enum.VerticalAlignment.Center; navLayout.Padding = UDim.new(0, 10)
	local navPad = Instance.new("UIPadding", TopNav); navPad.PaddingLeft = UDim.new(0, 10); navPad.PaddingRight = UDim.new(0, 10)

	navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TopNav.CanvasSize = UDim2.new(0, navLayout.AbsoluteContentSize.X + 20, 0, 0) end)

	ContentArea = Instance.new("Frame", MainFrame)
	ContentArea.Size = UDim2.new(0.95, 0, 0, 0); ContentArea.AutomaticSize = Enum.AutomaticSize.Y; ContentArea.BackgroundTransparency = 1; ContentArea.LayoutOrder = 4

	local function CreateSubNavBtn(name, text)
		local btn = Instance.new("TextButton", TopNav)
		btn.Size = UDim2.new(0, 110, 0, 28); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(180, 180, 180); btn.TextSize = 11; btn.Text = text
		ApplyButtonGradient(btn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 65))

		btn.MouseButton1Click:Connect(function()
			for k, v in pairs(SubBtns) do 
				local cGrad = v:FindFirstChildOfClass("UIGradient")
				if cGrad then TweenGradient(cGrad, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), 0.2) end
				TweenService:Create(v, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(180, 180, 180)}):Play() 
			end
			local grad = btn:FindFirstChildOfClass("UIGradient")
			if grad then TweenGradient(grad, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), 0.2) end
			TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()

			for k, frame in pairs(SubTabs) do frame.Visible = (k == name) end
		end)
		SubBtns[name] = btn
		return btn
	end

	CreateSubNavBtn("Inventory", "INVENTORY")
	CreateSubNavBtn("Titles", "TITLES")
	CreateSubNavBtn("Auras", "AURAS")

	-- [[ 3A. INVENTORY TAB ]]
	SubTabs["Inventory"] = Instance.new("Frame", ContentArea)
	SubTabs["Inventory"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Inventory"].BackgroundColor3 = Color3.fromRGB(20, 20, 25); SubTabs["Inventory"].Visible = true
	Instance.new("UICorner", SubTabs["Inventory"]).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", SubTabs["Inventory"]).Color = Color3.fromRGB(80, 80, 90)

	InvTitle = Instance.new("TextLabel", SubTabs["Inventory"])
	InvTitle.Size = UDim2.new(1, 0, 0, 40); InvTitle.BackgroundTransparency = 1; InvTitle.Font = Enum.Font.GothamBlack; InvTitle.TextColor3 = Color3.fromRGB(255, 215, 100); InvTitle.TextSize = 18; InvTitle.Text = "INVENTORY (0/50)"
	ApplyGradient(InvTitle, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	local AutoSellFrame = Instance.new("Frame", SubTabs["Inventory"])
	AutoSellFrame.Size = UDim2.new(1, 0, 0, 30); AutoSellFrame.Position = UDim2.new(0, 0, 0, 40); AutoSellFrame.BackgroundTransparency = 1
	local asLayout = Instance.new("UIListLayout", AutoSellFrame); asLayout.FillDirection = Enum.FillDirection.Horizontal; asLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; asLayout.Padding = UDim.new(0, 5)

	local asLabel = Instance.new("TextLabel", AutoSellFrame)
	asLabel.Size = UDim2.new(0, 70, 1, 0); asLabel.BackgroundTransparency = 1; asLabel.Font = Enum.Font.GothamBold; asLabel.TextColor3 = Color3.fromRGB(180, 180, 180); asLabel.TextSize = 11; asLabel.TextXAlignment = Enum.TextXAlignment.Right; asLabel.Text = "Auto-Sell:"

	local autoSellStates = {Common = false, Uncommon = false, Rare = false}
	local function CreateAutoSell(rarity, color)
		local asBtn = Instance.new("TextButton", AutoSellFrame)
		asBtn.Size = UDim2.new(0, 75, 1, 0); asBtn.Font = Enum.Font.GothamBold; asBtn.TextColor3 = color; asBtn.TextSize = 11; asBtn.Text = "All " .. rarity
		ApplyButtonGradient(asBtn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 70))

		asBtn.MouseButton1Click:Connect(function()
			autoSellStates[rarity] = not autoSellStates[rarity]
			if autoSellStates[rarity] then
				ApplyButtonGradient(asBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40), Color3.fromRGB(60, 120, 60))
				Network.AutoSell:FireServer(rarity)
				if NotificationManager then NotificationManager.Show("Auto-Sell " .. rarity .. " ENABLED", "Info") end
			else
				ApplyButtonGradient(asBtn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 70))
				if NotificationManager then NotificationManager.Show("Auto-Sell " .. rarity .. " DISABLED", "Info") end
			end
		end)
	end
	CreateAutoSell("Common", Color3.fromRGB(180, 180, 180))
	CreateAutoSell("Uncommon", Color3.fromRGB(100, 255, 100))
	CreateAutoSell("Rare", Color3.fromRGB(100, 100, 255))

	InvGrid = Instance.new("ScrollingFrame", SubTabs["Inventory"])
	InvGrid.Size = UDim2.new(1, -10, 1, -90); InvGrid.Position = UDim2.new(0, 5, 0, 80); InvGrid.BackgroundTransparency = 1; InvGrid.BorderSizePixel = 0; InvGrid.ScrollBarThickness = 4
	local gl = Instance.new("UIGridLayout", InvGrid)
	gl.CellSize = UDim2.new(0, 75, 0, 75); gl.CellPadding = UDim2.new(0, 10, 0, 15); gl.HorizontalAlignment = Enum.HorizontalAlignment.Center; gl.SortOrder = Enum.SortOrder.LayoutOrder

	-- [[ 3B. TITLES TAB ]]
	SubTabs["Titles"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Titles"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Titles"].BackgroundTransparency = 1; SubTabs["Titles"].Visible = false; SubTabs["Titles"].ScrollBarThickness = 6; SubTabs["Titles"].BorderSizePixel = 0
	local tLayout = Instance.new("UIListLayout", SubTabs["Titles"]); tLayout.Padding = UDim.new(0, 10); tLayout.SortOrder = Enum.SortOrder.LayoutOrder; tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local tPad = Instance.new("UIPadding", SubTabs["Titles"]); tPad.PaddingTop = UDim.new(0, 10); tPad.PaddingBottom = UDim.new(0, 20)

	-- [[ 3C. AURAS TAB ]]
	SubTabs["Auras"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Auras"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Auras"].BackgroundTransparency = 1; SubTabs["Auras"].Visible = false; SubTabs["Auras"].ScrollBarThickness = 6; SubTabs["Auras"].BorderSizePixel = 0
	local aLayout = Instance.new("UIListLayout", SubTabs["Auras"]); aLayout.Padding = UDim.new(0, 10); aLayout.SortOrder = Enum.SortOrder.LayoutOrder; aLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local aPad = Instance.new("UIPadding", SubTabs["Auras"]); aPad.PaddingTop = UDim.new(0, 10); aPad.PaddingBottom = UDim.new(0, 20)

	local function BuildCosmeticList(tab, typeKey, dataPool)
		local sorted = {}
		for key, data in pairs(dataPool) do table.insert(sorted, {Key = key, Data = data}) end
		table.sort(sorted, function(a, b) return a.Data.Order < b.Data.Order end)

		for _, item in ipairs(sorted) do
			local card = Instance.new("Frame", tab)
			card.Size = UDim2.new(0.95, 0, 0, 80); card.BackgroundColor3 = Color3.fromRGB(22, 22, 28); card.LayoutOrder = item.Data.Order
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
			local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(60, 60, 70); stroke.Thickness = 1

			local cColor = Color3.fromRGB(255,255,255)
			if typeKey == "Title" then cColor = Color3.fromHex((item.Data.Color or "#FFFFFF"):gsub("#", "")) else cColor = Color3.fromHex((item.Data.Color1 or "#FFFFFF"):gsub("#", "")) end

			local title = Instance.new("TextLabel", card); title.Size = UDim2.new(0.65, 0, 0, 25); title.Position = UDim2.new(0, 15, 0, 10); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextColor3 = cColor; title.TextSize = 16; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = item.Data.Name
			local desc = Instance.new("TextLabel", card); desc.Size = UDim2.new(0.65, 0, 0, 30); desc.Position = UDim2.new(0, 15, 0, 35); desc.BackgroundTransparency = 1; desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(150, 150, 160); desc.TextSize = 13; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = item.Data.Desc

			local btn = Instance.new("TextButton", card)
			btn.Size = UDim2.new(0.25, 0, 0, 40); btn.AnchorPoint = Vector2.new(1, 0.5); btn.Position = UDim2.new(1, -15, 0.5, 0); btn.Font = Enum.Font.GothamBlack; btn.TextSize = 13; btn.Text = ""

			local function UpdateState()
				local isUnlocked = CosmeticData.CheckUnlock(player, item.Data.ReqType, item.Data.ReqValue)
				local isEquipped = (player:GetAttribute("Equipped" .. typeKey) or (typeKey == "Title" and "Cadet" or "None")) == item.Key

				if isEquipped then
					btn.Text = "EQUIPPED"; ApplyButtonGradient(btn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(60, 60, 70)); btn.TextColor3 = Color3.fromRGB(150, 150, 150)
					stroke.Color = cColor; stroke.Thickness = 2; stroke.Transparency = 0.2
				elseif isUnlocked then
					btn.Text = "EQUIP"; ApplyButtonGradient(btn, Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 50, 20), Color3.fromRGB(60, 150, 60)); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					stroke.Color = Color3.fromRGB(80, 80, 90); stroke.Thickness = 1; stroke.Transparency =