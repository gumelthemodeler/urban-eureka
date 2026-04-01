-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local RegimentTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local RegimentData = require(ReplicatedStorage:WaitForChild("RegimentData"))
local NotificationManager = require(script.Parent.Parent:WaitForChild("UIModules"):WaitForChild("NotificationManager"))

local player = Players.LocalPlayer
local MainFrame, ContentArea
local SubTabs, SubBtns = {}, {}

local FactionColors = { ["Garrison"] = Color3.fromRGB(180, 60, 60), ["Military Police"] = Color3.fromRGB(60, 160, 60), ["Scout Regiment"] = Color3.fromRGB(60, 100, 200) }
local RegimentIcons = { ["Garrison"] = "rbxassetid://133062844", ["Military Police"] = "rbxassetid://132793466", ["Scout Regiment"] = "rbxassetid://132793532" }

local TimerLabel
local selectedDistrict = nil

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor = false 
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}; grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 6)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn); stroke.Color = strokeColor; stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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

function RegimentTab.Init(parentFrame, tooltipMgr)
	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "RegimentFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 35); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 255, 255); Title.TextSize = 24; Title.Text = "REGIMENT WARS"
	ApplyGradient(Title, Color3.fromRGB(230, 230, 255), Color3.fromRGB(160, 180, 255))

	TimerLabel = Instance.new("TextLabel", MainFrame)
	TimerLabel.Size = UDim2.new(1, 0, 0, 20); TimerLabel.Position = UDim2.new(0, 0, 0, 40); TimerLabel.BackgroundTransparency = 1; TimerLabel.Font = Enum.Font.GothamBold; TimerLabel.TextColor3 = Color3.fromRGB(255, 150, 150); TimerLabel.TextSize = 14; TimerLabel.Text = "CYCLE ENDS IN: Awaiting Intel..."

	-- [[ FIX: Centered Tabs ]]
	local TopNav = Instance.new("Frame", MainFrame)
	TopNav.Size = UDim2.new(1, 0, 0, 40); TopNav.Position = UDim2.new(0, 0, 0, 70); TopNav.BackgroundTransparency = 1
	local navLayout = Instance.new("UIListLayout", TopNav); navLayout.FillDirection = Enum.FillDirection.Horizontal; navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; navLayout.VerticalAlignment = Enum.VerticalAlignment.Center; navLayout.Padding = UDim.new(0, 10)

	ContentArea = Instance.new("Frame", MainFrame)
	ContentArea.Size = UDim2.new(1, 0, 1, -120); ContentArea.Position = UDim2.new(0, 0, 0, 120); ContentArea.BackgroundTransparency = 1

	local function CreateSubNavBtn(name, text)
		local btn = Instance.new("TextButton", TopNav)
		btn.Size = UDim2.new(0, 120, 0, 28); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(180, 180, 180); btn.TextSize = 12; btn.Text = text
		btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		btn.MouseButton1Click:Connect(function()
			for k, v in pairs(SubBtns) do 
				TweenService:Create(v, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(180, 180, 180), BackgroundColor3 = Color3.fromRGB(30, 30, 35)}):Play() 
			end
			TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = Color3.fromRGB(80, 80, 90)}):Play()

			for k, frame in pairs(SubTabs) do frame.Visible = (k == name) end
		end)
		SubBtns[name] = btn
		return btn
	end

	CreateSubNavBtn("WarMap", "WAR MAP")
	CreateSubNavBtn("Factions", "FACTIONS")

	-- ==========================================
	-- [[ 1. WAR MAP TAB (Mobile Vertical Layout) ]]
	-- ==========================================
	SubTabs["WarMap"] = Instance.new("Frame", ContentArea)
	SubTabs["WarMap"].Size = UDim2.new(1, 0, 1, 0); SubTabs["WarMap"].BackgroundTransparency = 1; SubTabs["WarMap"].Visible = true

	-- [[ FIX: Removed Constraints & Used Crop to flawlessly fill the space ]]
	local MapFrame = Instance.new("ImageLabel", SubTabs["WarMap"])
	MapFrame.Size = UDim2.new(1, 0, 0.52, 0); MapFrame.Position = UDim2.new(0, 0, 0, 0)
	MapFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15); MapFrame.Image = "rbxassetid://319692171"; MapFrame.ImageColor3 = Color3.fromRGB(80, 100, 150); MapFrame.ImageTransparency = 0.85
	MapFrame.ScaleType = Enum.ScaleType.Crop
	Instance.new("UICorner", MapFrame).CornerRadius = UDim.new(0, 12); Instance.new("UIStroke", MapFrame).Color = Color3.fromRGB(80, 120, 200); MapFrame.UIStroke.Thickness = 2
	MapFrame.ClipsDescendants = true

	-- [[ FIX: Added Regiment Logo to the Map ]]
	local PlayerRegLogo = Instance.new("ImageLabel", MapFrame)
	PlayerRegLogo.Size = UDim2.new(0, 80, 0, 80)
	PlayerRegLogo.Position = UDim2.new(0, 10, 1, -10)
	PlayerRegLogo.AnchorPoint = Vector2.new(0, 1)
	PlayerRegLogo.BackgroundTransparency = 1
	PlayerRegLogo.ImageTransparency = 0.6
	PlayerRegLogo.ZIndex = 2

	local function UpdateMapLogo()
		local reg = player:GetAttribute("Regiment") or "Cadet Corps"
		PlayerRegLogo.Image = RegimentIcons[reg] or ""
		PlayerRegLogo.ImageColor3 = FactionColors[reg] or Color3.fromRGB(255, 255, 255)
	end
	player:GetAttributeChangedSignal("Regiment"):Connect(UpdateMapLogo)
	UpdateMapLogo()

	local MapTitle = Instance.new("TextLabel", MapFrame); MapTitle.Size = UDim2.new(1, 0, 0, 25); MapTitle.Position = UDim2.new(0, 0, 0, 5); MapTitle.BackgroundTransparency = 1; MapTitle.Font = Enum.Font.GothamBlack; MapTitle.TextColor3 = Color3.fromRGB(200, 220, 255); MapTitle.TextSize = 14; MapTitle.Text = "TACTICAL OVERVIEW"; MapTitle.ZIndex = 5

	local WallData = {
		{ Name = "Wall Maria", Scale = 0.80 },
		{ Name = "Wall Rose", Scale = 0.50 },
		{ Name = "Wall Sina", Scale = 0.25 }
	}

	for _, w in ipairs(WallData) do
		local wFrame = Instance.new("Frame", MapFrame)
		wFrame.Size = UDim2.new(w.Scale, 0, w.Scale, 0); wFrame.Position = UDim2.new(0.5, 0, 0.5, 0); wFrame.AnchorPoint = Vector2.new(0.5, 0.5); wFrame.BackgroundTransparency = 1; wFrame.ZIndex = 3
		Instance.new("UICorner", wFrame).CornerRadius = UDim.new(1, 0)
		local str = Instance.new("UIStroke", wFrame); str.Color = Color3.fromRGB(100, 140, 220); str.Thickness = 2; str.Transparency = 0.6

		local wTxt = Instance.new("TextLabel", wFrame)
		wTxt.Size = UDim2.new(1, 0, 0, 20); wTxt.Position = UDim2.new(0.5, 0, 0, -10); wTxt.AnchorPoint = Vector2.new(0.5, 0.5); wTxt.BackgroundTransparency = 1; wTxt.Font = Enum.Font.GothamBlack; wTxt.Text = string.upper(w.Name); wTxt.TextColor3 = Color3.fromRGB(120, 160, 255); wTxt.TextTransparency = 0.4; wTxt.TextSize = 10; wTxt.ZIndex = 3
	end

	local DetailPanel = Instance.new("Frame", SubTabs["WarMap"])
	DetailPanel.Size = UDim2.new(1, 0, 0.46, 0); DetailPanel.Position = UDim2.new(0, 0, 0.54, 0); DetailPanel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	Instance.new("UICorner", DetailPanel).CornerRadius = UDim.new(0, 8)
	local dpStroke = Instance.new("UIStroke", DetailPanel); dpStroke.Color = Color3.fromRGB(60, 60, 70); dpStroke.Thickness = 2

	local dpGrad = Instance.new("UIGradient", DetailPanel)
	dpGrad.Color = ColorSequence.new(Color3.fromRGB(22, 22, 28), Color3.fromRGB(12, 12, 16)); dpGrad.Rotation = 90

	local dNameLbl = Instance.new("TextLabel", DetailPanel); dNameLbl.Size = UDim2.new(1, -20, 0, 25); dNameLbl.Position = UDim2.new(0, 10, 0, 5); dNameLbl.BackgroundTransparency = 1; dNameLbl.Font = Enum.Font.GothamBlack; dNameLbl.TextColor3 = Color3.fromRGB(255, 215, 100); dNameLbl.TextSize = 18; dNameLbl.TextXAlignment = Enum.TextXAlignment.Left; dNameLbl.Text = "AWAITING INTEL..."

	-- [[ FIX: Enabled RichText so HTML colors work ]]
	local dBuffLbl = Instance.new("TextLabel", DetailPanel); dBuffLbl.Size = UDim2.new(1, -20, 0, 25); dBuffLbl.Position = UDim2.new(0, 10, 0, 25); dBuffLbl.BackgroundTransparency = 1; dBuffLbl.Font = Enum.Font.GothamBold; dBuffLbl.TextColor3 = Color3.fromRGB(100, 255, 100); dBuffLbl.TextSize = 11; dBuffLbl.TextXAlignment = Enum.TextXAlignment.Left; dBuffLbl.TextYAlignment = Enum.TextYAlignment.Top; dBuffLbl.TextWrapped = true; dBuffLbl.RichText = true; dBuffLbl.Text = "Select a district on the map."

	local BarsFrame = Instance.new("Frame", DetailPanel); BarsFrame.Size = UDim2.new(1, -20, 0, 85); BarsFrame.Position = UDim2.new(0, 10, 0, 45); BarsFrame.BackgroundTransparency = 1
	local bLayout = Instance.new("UIListLayout", BarsFrame); bLayout.Padding = UDim.new(0, 5)

	local DeployBtn = Instance.new("TextButton", DetailPanel)
	DeployBtn.Size = UDim2.new(0.8, 0, 0, 40); DeployBtn.Position = UDim2.new(0.5, 0, 1, -5); DeployBtn.AnchorPoint = Vector2.new(0.5, 1); DeployBtn.Font = Enum.Font.GothamBlack; DeployBtn.TextColor3 = Color3.fromRGB(255, 255, 255); DeployBtn.TextSize = 16; DeployBtn.Text = "DEPLOY FORCES"
	ApplyButtonGradient(DeployBtn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(80, 80, 90))

	local dMapNodes = {}
	local dVPBars = {}

	for i, reg in ipairs({"Garrison", "Military Police", "Scout Regiment"}) do
		local barBg = Instance.new("Frame", BarsFrame); barBg.Size = UDim2.new(1, 0, 0, 22); barBg.BackgroundColor3 = Color3.fromRGB(10, 10, 12); Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 4)
		Instance.new("UIStroke", barBg).Color = Color3.fromRGB(40, 40, 50); barBg.UIStroke.Thickness = 1

		local fill = Instance.new("Frame", barBg); fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
		local fGrad = Instance.new("UIGradient", fill); fGrad.Color = ColorSequence.new(FactionColors[reg], Color3.new(FactionColors[reg].R*0.5, FactionColors[reg].G*0.5, FactionColors[reg].B*0.5)); fGrad.Rotation = 90

		local txt = Instance.new("TextLabel", barBg); txt.Size = UDim2.new(1, -10, 1, 0); txt.Position = UDim2.new(0, 5, 0, 0); txt.BackgroundTransparency = 1; txt.Font = Enum.Font.GothamBlack; txt.TextColor3 = Color3.fromRGB(255, 255, 255); txt.TextSize = 11; txt.TextXAlignment = Enum.TextXAlignment.Left; txt.Text = string.upper(reg) .. " - 0 VP"; txt.ZIndex = 2
		dVPBars[reg] = { Fill = fill, Txt = txt }
	end

	for dName, dInfo in pairs(RegimentData.Districts) do
		local nodeBtn = Instance.new("TextButton", MapFrame)
		nodeBtn.Size = UDim2.new(0, 24, 0, 24); nodeBtn.Position = dInfo.MapPos; nodeBtn.AnchorPoint = Vector2.new(0.5, 0.5); nodeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25); nodeBtn.Text = ""; nodeBtn.ZIndex = 10
		Instance.new("UICorner", nodeBtn).CornerRadius = UDim.new(1, 0)
		local stroke = Instance.new("UIStroke", nodeBtn); stroke.Color = Color3.fromRGB(150, 150, 160); stroke.Thickness = 2

		local innerDot = Instance.new("Frame", nodeBtn)
		innerDot.Size = UDim2.new(1, -10, 1, -10); innerDot.Position = UDim2.new(0.5, 0, 0.5, 0); innerDot.AnchorPoint = Vector2.new(0.5, 0.5); innerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255); innerDot.ZIndex = 10; innerDot.BackgroundTransparency = 0.1
		Instance.new("UICorner", innerDot).CornerRadius = UDim.new(1, 0)

		-- [[ FIX: Glowing Deployed Marker Icon ]]
		local deployedMarker = Instance.new("ImageLabel", nodeBtn)
		deployedMarker.Size = UDim2.new(0, 24, 0, 24)
		deployedMarker.Position = UDim2.new(0.5, 0, -0.6, 0)
		deployedMarker.AnchorPoint = Vector2.new(0.5, 1)
		deployedMarker.BackgroundTransparency = 1
		deployedMarker.Image = "rbxassetid://3926305904" 
		deployedMarker.ImageRectOffset = Vector2.new(524, 44) 
		deployedMarker.ImageRectSize = Vector2.new(36, 36)
		deployedMarker.ImageColor3 = Color3.fromRGB(100, 255, 100)
		deployedMarker.ZIndex = 15
		deployedMarker.Visible = false

		local isCentered = (dInfo.TextAlign == Enum.TextXAlignment.Center)
		local lblBg = Instance.new("Frame", nodeBtn)
		lblBg.Size = isCentered and UDim2.new(0, 110, 0, 18) or UDim2.new(0, 100, 0, 18)
		lblBg.Position = dInfo.LabelPos or UDim2.new(0.5, 0, 1, 6)
		lblBg.AnchorPoint = dInfo.LabelAnchor or Vector2.new(0.5, 0)
		lblBg.BackgroundColor3 = Color3.fromRGB(10, 10, 14); lblBg.BackgroundTransparency = 0.35; lblBg.ZIndex = 10
		Instance.new("UICorner", lblBg).CornerRadius = UDim.new(0, 4)

		local lblAccent = Instance.new("Frame", lblBg)
		lblAccent.Size = UDim2.new(0, 2, 1, 0); lblAccent.Position = UDim2.new(0, 0, 0, 0); lblAccent.BackgroundColor3 = Color3.fromRGB(150, 150, 160); lblAccent.BorderSizePixel = 0; lblAccent.ZIndex = 11
		Instance.new("UICorner", lblAccent).CornerRadius = UDim.new(0, 4)

		if not isCentered then
			local pad = Instance.new("UIPadding", lblBg); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
		end

		local lbl = Instance.new("TextLabel", lblBg)
		lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(200, 200, 210); lbl.TextSize = 10; lbl.Text = string.upper(dName); lbl.ZIndex = 11; lbl.TextXAlignment = dInfo.TextAlign or Enum.TextXAlignment.Center

		local selRing = Instance.new("Frame", nodeBtn)
		selRing.Size = UDim2.new(1, 4, 1, 4); selRing.Position = UDim2.new(0.5, 0, 0.5, 0); selRing.AnchorPoint = Vector2.new(0.5, 0.5); selRing.BackgroundTransparency = 1; selRing.ZIndex = 9; selRing.Visible = false
		Instance.new("UICorner", selRing).CornerRadius = UDim.new(1, 0)
		local selStroke = Instance.new("UIStroke", selRing); selStroke.Color = Color3.fromRGB(255, 215, 100); selStroke.Thickness = 2; selStroke.Transparency = 0

		local selTween = nil

		nodeBtn.MouseButton1Click:Connect(function()
			selectedDistrict = dName
			dNameLbl.Text = string.upper(dName); dBuffLbl.Text = "<font color='#55FF55'>Strategic Value:</font> " .. dInfo.Buff

			for n, data in pairs(dMapNodes) do
				if data.Tween then data.Tween:Cancel(); data.Tween = nil end
				if n == dName then
					data.Stroke.Color = Color3.fromRGB(255, 215, 100); data.Stroke.Thickness = 3
					data.Lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
					data.Accent.BackgroundColor3 = Color3.fromRGB(255, 215, 100)
					data.SelRing.Visible = true
					data.SelRing.Size = UDim2.new(1, 4, 1, 4); data.SelRing.UIStroke.Transparency = 0
					data.Tween = TweenService:Create(data.SelRing, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1), {Size = UDim2.new(1, 20, 1, 20), UIStroke = {Transparency = 1}})
					data.Tween:Play()
					dpStroke.Color = Color3.fromRGB(255, 215, 100)
				else
					data.Stroke.Color = Color3.fromRGB(100, 100, 120); data.Stroke.Thickness = 2
					data.Lbl.TextColor3 = Color3.fromRGB(150, 150, 160)
					data.Accent.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
					data.SelRing.Visible = false
				end
			end

			local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
			if currentReg == "Cadet Corps" then
				ApplyButtonGradient(DeployBtn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(80, 80, 90)); DeployBtn.Text = "JOIN A FACTION FIRST"
			else
				local deployedTo = player:GetAttribute("DeployedDistrict") or "None"
				if deployedTo == dName then
					ApplyButtonGradient(DeployBtn, Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 50, 20), Color3.fromRGB(60, 150, 60)); DeployBtn.Text = "CURRENTLY DEPLOYED"
				else
					ApplyButtonGradient(DeployBtn, Color3.fromRGB(80, 140, 200), Color3.fromRGB(40, 80, 120), Color3.fromRGB(60, 100, 160)); DeployBtn.Text = "DEPLOY FORCES HERE"
				end
			end

			pcall(function()
				local vpData = Network:WaitForChild("GetRegimentVP"):InvokeServer()
				if vpData and vpData.Districts and vpData.Districts[dName] then
					local dData = vpData.Districts[dName]
					local total = math.max(1, (dData["Garrison"] or 0) + (dData["Scout Regiment"] or 0) + (dData["Military Police"] or 0))
					TweenService:Create(dVPBars["Garrison"].Fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new((dData["Garrison"] or 0) / total, 0, 1, 0)}):Play(); dVPBars["Garrison"].Txt.Text = "GARRISON - " .. (dData["Garrison"] or 0) .. " VP"
					TweenService:Create(dVPBars["Military Police"].Fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new((dData["Military Police"] or 0) / total, 0, 1, 0)}):Play(); dVPBars["Military Police"].Txt.Text = "MILITARY POLICE - " .. (dData["Military Police"] or 0) .. " VP"
					TweenService:Create(dVPBars["Scout Regiment"].Fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new((dData["Scout Regiment"] or 0) / total, 0, 1, 0)}):Play(); dVPBars["Scout Regiment"].Txt.Text = "SCOUTS - " .. (dData["Scout Regiment"] or 0) .. " VP"
				end
			end)
		end)
		dMapNodes[dName] = { Btn = nodeBtn, Inner = innerDot, Stroke = stroke, Lbl = lbl, Accent = lblAccent, SelRing = selRing, Tween = selTween, Marker = deployedMarker }
	end

	local function UpdateDeployedMarkers()
		local deployedTo = player:GetAttribute("DeployedDistrict") or "None"
		for dName, nodeData in pairs(dMapNodes) do
			if deployedTo == dName then nodeData.Marker.Visible = true else nodeData.Marker.Visible = false end
		end
	end
	player:GetAttributeChangedSignal("DeployedDistrict"):Connect(UpdateDeployedMarkers)
	UpdateDeployedMarkers()

	DeployBtn.MouseButton1Click:Connect(function()
		if selectedDistrict then
			local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
			if currentReg == "Cadet Corps" then
				if NotificationManager then NotificationManager.Show("You must join a Faction first!", "Error") end return
			end
			Network:WaitForChild("DeployToDistrict"):FireServer(selectedDistrict)
			ApplyButtonGradient(DeployBtn, Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 50, 20), Color3.fromRGB(60, 150, 60)); DeployBtn.Text = "CURRENTLY DEPLOYED"
		end
	end)

	-- ==========================================
	-- [[ 2. FACTIONS TAB ]]
	-- ==========================================
	SubTabs["Factions"] = Instance.new("ScrollingFrame", ContentArea)
	SubTabs["Factions"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Factions"].BackgroundTransparency = 1; SubTabs["Factions"].Visible = false; SubTabs["Factions"].ScrollBarThickness = 0
	local fLayout = Instance.new("UIListLayout", SubTabs["Factions"]); fLayout.SortOrder = Enum.SortOrder.LayoutOrder; fLayout.Padding = UDim.new(0, 15); fLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function CreateRegimentCard(name, color, imageId, buffTxt)
		local card = Instance.new("Frame", SubTabs["Factions"])
		card.Size = UDim2.new(0.95, 0, 0, 120); card.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
		local stroke = Instance.new("UIStroke", card); stroke.Color = color; stroke.Thickness = 2; stroke.Transparency = 0.4; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		card.ClipsDescendants = true

		local bgGrad = Instance.new("UIGradient", card)
		bgGrad.Color = ColorSequence.new(Color3.fromRGB(25, 25, 30), Color3.fromRGB(15, 15, 18))
		bgGrad.Rotation = 45

		local logo = Instance.new("ImageLabel", card)
		logo.Size = UDim2.new(0, 200, 0, 200); logo.Position = UDim2.new(0, -30, 0.5, 0); logo.AnchorPoint = Vector2.new(0, 0.5); logo.BackgroundTransparency = 1; logo.Image = imageId; logo.ScaleType = Enum.ScaleType.Fit; logo.ImageTransparency = 0.85; logo.ImageColor3 = color

		local title = Instance.new("TextLabel", card); title.Size = UDim2.new(0.6, 0, 0, 30); title.Position = UDim2.new(0, 110, 0, 15); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextColor3 = color; title.TextSize = 24; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = string.upper(name)
		local bTxt = Instance.new("TextLabel", card); bTxt.Size = UDim2.new(0.6, 0, 0, 30); bTxt.Position = UDim2.new(0, 110, 0, 50); bTxt.BackgroundTransparency = 1; bTxt.Font = Enum.Font.GothamBold; bTxt.TextColor3 = Color3.fromRGB(200, 200, 210); bTxt.TextSize = 14; bTxt.TextXAlignment = Enum.TextXAlignment.Left; bTxt.Text = "Exclusive Perk:\n<font color='#55FF55'>" .. buffTxt .. "</font>"; bTxt.RichText = true

		local joinBtn = Instance.new("TextButton", card); joinBtn.Size = UDim2.new(0, 160, 0, 45); joinBtn.Position = UDim2.new(1, -20, 0.5, 0); joinBtn.AnchorPoint = Vector2.new(1, 0.5); joinBtn.Font = Enum.Font.GothamBlack; joinBtn.TextSize = 14; joinBtn.Text = ""

		joinBtn.MouseButton1Click:Connect(function()
			local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
			if currentReg == name then return end
			local cost = (currentReg == "Cadet Corps") and 0 or 50000
			if cost > 0 then
				local currentDews = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
				if currentDews >= cost then Network:WaitForChild("JoinRegiment"):FireServer(name) else if NotificationManager then NotificationManager.Show("Not enough Dews! You need 50,000 to swap regiments.", "Error") end end
			else Network:WaitForChild("JoinRegiment"):FireServer(name) end
		end)

		local function UpdateBtnState()
			local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
			if currentReg == name then joinBtn.Text = "CURRENTLY SERVING"; ApplyButtonGradient(joinBtn, Color3.fromRGB(40, 40, 45), Color3.fromRGB(20, 20, 25), Color3.fromRGB(60, 60, 70)); joinBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
			else joinBtn.Text = (currentReg == "Cadet Corps") and "JOIN (FREE)" or "SWAP (50k DEWS)"; local rTop = Color3.new(color.R*0.8, color.G*0.8, color.B*0.8); local rBot = Color3.new(color.R*0.4, color.G*0.4, color.B*0.4); ApplyButtonGradient(joinBtn, rTop, rBot, color); joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255) end
		end
		player:GetAttributeChangedSignal("Regiment"):Connect(UpdateBtnState); UpdateBtnState()
	end

	CreateRegimentCard("Garrison", FactionColors["Garrison"], RegimentIcons["Garrison"], "+10% Defense against all attacks")
	CreateRegimentCard("Military Police", FactionColors["Military Police"], RegimentIcons["Military Police"], "+15% Dews from all activities")
	CreateRegimentCard("Scout Regiment", FactionColors["Scout Regiment"], RegimentIcons["Scout Regiment"], "+10% Speed in combat")

	fLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SubTabs["Factions"].CanvasSize = UDim2.new(0, 0, 0, fLayout.AbsoluteContentSize.Y + 20) end)


	-- ==========================================
	-- [[ GLOBAL TIMER & VP LOOP ]]
	-- ==========================================
	local function FormatTimer()
		local now = os.time(); local weekSeconds = 604800
		local nextReset = (math.floor(now / weekSeconds) + 1) * weekSeconds
		local timeLeft = nextReset - now
		local d = math.floor(timeLeft / 86400)
		local h = math.floor((timeLeft % 86400) / 3600)
		local m = math.floor((timeLeft % 3600) / 60)
		return string.format("%dd %dh %dm", d, h, m)
	end

	task.spawn(function()
		while true do
			task.wait(5)
			if MainFrame.Visible then
				TimerLabel.Text = "CYCLE ENDS IN: " .. FormatTimer()
				pcall(function()
					local vpData = Network:WaitForChild("GetRegimentVP"):InvokeServer()
					if vpData and vpData.Districts then
						for dName, nodeData in pairs(dMapNodes) do
							local dData = vpData.Districts[dName]
							if dData then
								local leader = "None"; local highest = 0
								for reg, vp in pairs(dData) do if reg ~= "Winner" and type(vp) == "number" and vp > highest then highest = vp; leader = reg end end
								if leader == "None" then leader = dData.Winner end

								local facColor = FactionColors[leader] or Color3.fromRGB(50, 50, 60)
								nodeData.Btn.BackgroundColor3 = facColor
								if leader == "None" then
									nodeData.Inner.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
								else
									nodeData.Inner.BackgroundColor3 = Color3.new(math.min(1, facColor.R*1.5), math.min(1, facColor.G*1.5), math.min(1, facColor.B*1.5))
								end

								if selectedDistrict == dName and SubTabs["WarMap"].Visible then
									local total = math.max(1, (dData["Garrison"] or 0) + (dData["Scout Regiment"] or 0) + (dData["Military Police"] or 0))
									TweenService:Create(dVPBars["Garrison"].Fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new((dData["Garrison"] or 0) / total, 0, 1, 0)}):Play(); dVPBars["Garrison"].Txt.Text = "GARRISON - " .. (dData["Garrison"] or 0) .. " VP"
									TweenService:Create(dVPBars["Military Police"].Fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new((dData["Military Police"] or 0) / total, 0, 1, 0)}):Play(); dVPBars["Military Police"].Txt.Text = "MILITARY POLICE - " .. (dData["Military Police"] or 0) .. " VP"
									TweenService:Create(dVPBars["Scout Regiment"].Fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new((dData["Scout Regiment"] or 0) / total, 0, 1, 0)}):Play(); dVPBars["Scout Regiment"].Txt.Text = "SCOUTS - " .. (dData["Scout Regiment"] or 0) .. " VP"
								end
							end
						end
					end
				end)
			end
		end
	end)

	TweenService:Create(SubBtns["WarMap"], TweenInfo.new(0), {TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = Color3.fromRGB(80, 80, 90)}):Play()
end

function RegimentTab.Show() if MainFrame then MainFrame.Visible = true end end

return RegimentTab