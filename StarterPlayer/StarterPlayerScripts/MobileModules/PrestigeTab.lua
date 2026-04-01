-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local PrestigeTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

local player = Players.LocalPlayer
local MainFrame
local PointsLabel
local DetailPanel, DTitle, DDesc, DBuff, DCost, DReq, UnlockBtn
local StatCardContainer
local TreeScroll
local SelectedNodeId = nil
local NodeGuis = {}

local CANVAS_HEIGHT = 1500 -- Large canvas so you can comfortably scroll down

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}; grad.Rotation = 90
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

local function CreateStatCard(parent, title, valueStr, themeColorHex)
	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(0, 110, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

	local stroke = Instance.new("UIStroke", card)
	stroke.Color = Color3.fromHex(themeColorHex:gsub("#", ""))
	stroke.Thickness = 1
	stroke.Transparency = 0.5

	local tLbl = Instance.new("TextLabel", card)
	tLbl.Size = UDim2.new(1, 0, 0, 15)
	tLbl.Position = UDim2.new(0, 0, 0, 4)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Enum.Font.GothamBold
	tLbl.TextColor3 = Color3.fromRGB(180, 180, 190)
	tLbl.TextSize = 10
	tLbl.Text = string.upper(title)

	local vLbl = Instance.new("TextLabel", card)
	vLbl.Size = UDim2.new(1, 0, 0, 25)
	vLbl.Position = UDim2.new(0, 0, 0, 20)
	vLbl.BackgroundTransparency = 1
	vLbl.Font = Enum.Font.GothamBlack
	vLbl.TextColor3 = Color3.fromHex(themeColorHex:gsub("#", ""))
	vLbl.TextSize = 14
	vLbl.Text = valueStr

	return card
end

local function GetSafeYScale(originalYScale)
	return (tonumber(originalYScale) or 0.5) * 0.75 + 0.15
end

local function ExtractPos(posData)
	if not posData then return 0.5, 0.5 end
	if typeof(posData) == "UDim2" then return posData.X.Scale, posData.Y.Scale end
	if typeof(posData) == "Vector2" then return posData.X, posData.Y end
	if type(posData) == "table" then return posData.X or 0.5, posData.Y or 0.5 end
	return 0.5, 0.5
end

function PrestigeTab.Init(parentFrame)
	if not GameData.PrestigeNodes then warn("GameData.PrestigeNodes is missing!") return end

	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "PrestigeFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 30); Title.Position = UDim2.new(0, 0, 0, 0); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(255, 215, 100); Title.TextSize = 22; Title.Text = "PRESTIGE TALENTS"
	ApplyGradient(Title, Color3.fromRGB(255, 215, 100), Color3.fromRGB(255, 150, 50))

	PointsLabel = Instance.new("TextLabel", MainFrame)
	PointsLabel.Size = UDim2.new(1, 0, 0, 20); PointsLabel.Position = UDim2.new(0, 0, 0, 30); PointsLabel.BackgroundTransparency = 1; PointsLabel.Font = Enum.Font.GothamBold; PointsLabel.TextColor3 = Color3.fromRGB(150, 255, 150); PointsLabel.TextSize = 14; PointsLabel.Text = "AVAILABLE POINTS: 0"

	TreeScroll = Instance.new("ScrollingFrame", MainFrame)
	TreeScroll.Size = UDim2.new(1, 0, 1, -55)
	TreeScroll.Position = UDim2.new(0, 0, 0, 55)
	TreeScroll.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
	TreeScroll.ScrollBarThickness = 0
	TreeScroll.BorderSizePixel = 0
	Instance.new("UICorner", TreeScroll).CornerRadius = UDim.new(0, 8)
	Instance.new("UIStroke", TreeScroll).Color = Color3.fromRGB(40, 40, 50)
	TreeScroll.CanvasSize = UDim2.new(0, 0, 0, CANVAS_HEIGHT) 

	local function CreateBranchBackdrop(name, xPos, colorHex)
		local bg = Instance.new("Frame", TreeScroll)
		bg.Size = UDim2.new(0.31, 0, 0, CANVAS_HEIGHT); bg.Position = UDim2.new(xPos, 0, 0, 0); bg.AnchorPoint = Vector2.new(0.5, 0)
		bg.BackgroundColor3 = Color3.fromRGB(16, 16, 20); bg.ZIndex = 0
		Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", bg).Color = Color3.fromRGB(30, 30, 40)

		local header = Instance.new("TextLabel", bg)
		header.Size = UDim2.new(1, 0, 0, 30); header.Position = UDim2.new(0, 0, 0, 10); header.BackgroundTransparency = 1; header.Font = Enum.Font.GothamBlack; header.TextColor3 = Color3.fromHex(colorHex:gsub("#","")); header.TextSize = 12; header.Text = name; header.ZIndex = 1

		local sep = Instance.new("Frame", bg)
		sep.Size = UDim2.new(0.8, 0, 0, 2); sep.Position = UDim2.new(0.1, 0, 0, 40); sep.BackgroundColor3 = Color3.fromHex(colorHex:gsub("#","")); sep.BorderSizePixel = 0; sep.ZIndex = 1
		local grad = Instance.new("UIGradient", sep)
		grad.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)}
	end

	CreateBranchBackdrop("SCOUT", 0.17, "#55AAFF")
	CreateBranchBackdrop("COMMANDER", 0.5, "#FFD700")
	CreateBranchBackdrop("TITAN", 0.83, "#AA55FF")

	-- [[ STRICT ABSOLUTE POSITIONING DETAIL PANEL ]]
	DetailPanel = Instance.new("Frame", MainFrame)
	DetailPanel.Size = UDim2.new(0.96, 0, 0, 220) 
	DetailPanel.AnchorPoint = Vector2.new(0.5, 1)
	DetailPanel.Position = UDim2.new(0.5, 0, 1, -10) 
	DetailPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	DetailPanel.ZIndex = 50 
	DetailPanel.Visible = false
	Instance.new("UICorner", DetailPanel).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", DetailPanel).Color = Color3.fromRGB(80, 80, 100)

	DTitle = Instance.new("TextLabel", DetailPanel)
	DTitle.Size = UDim2.new(1, -100, 0, 25)
	DTitle.Position = UDim2.new(0, 15, 0, 15)
	DTitle.BackgroundTransparency = 1
	DTitle.Font = Enum.Font.GothamBlack
	DTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	DTitle.TextSize = 16
	DTitle.TextXAlignment = Enum.TextXAlignment.Left
	DTitle.ZIndex = 51

	DCost = Instance.new("TextLabel", DetailPanel)
	DCost.Size = UDim2.new(0, 60, 0, 25)
	DCost.AnchorPoint = Vector2.new(1, 0)
	DCost.Position = UDim2.new(1, -45, 0, 15)
	DCost.BackgroundTransparency = 1
	DCost.Font = Enum.Font.GothamBlack
	DCost.TextColor3 = Color3.fromRGB(255, 215, 100)
	DCost.TextSize = 14
	DCost.TextXAlignment = Enum.TextXAlignment.Right
	DCost.ZIndex = 51

	local CloseBtn = Instance.new("TextButton", DetailPanel)
	CloseBtn.Size = UDim2.new(0, 25, 0, 25)
	CloseBtn.AnchorPoint = Vector2.new(1, 0)
	CloseBtn.Position = UDim2.new(1, -15, 0, 15)
	CloseBtn.BackgroundTransparency = 1
	CloseBtn.Font = Enum.Font.GothamBlack
	CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
	CloseBtn.TextSize = 18
	CloseBtn.Text = "X"
	CloseBtn.ZIndex = 51
	CloseBtn.MouseButton1Click:Connect(function() 
		DetailPanel.Visible = false 
		TreeScroll.Size = UDim2.new(1, 0, 1, -55) 
	end)

	DDesc = Instance.new("TextLabel", DetailPanel)
	DDesc.Size = UDim2.new(1, -30, 0, 45)
	DDesc.Position = UDim2.new(0, 15, 0, 45)
	DDesc.BackgroundTransparency = 1
	DDesc.Font = Enum.Font.GothamMedium
	DDesc.TextColor3 = Color3.fromRGB(180, 180, 190)
	DDesc.TextSize = 12
	DDesc.TextWrapped = true
	DDesc.TextXAlignment = Enum.TextXAlignment.Left
	DDesc.TextYAlignment = Enum.TextYAlignment.Top
	DDesc.ZIndex = 51

	StatCardContainer = Instance.new("ScrollingFrame", DetailPanel)
	StatCardContainer.Size = UDim2.new(1, -30, 0, 50)
	StatCardContainer.Position = UDim2.new(0, 15, 0, 95)
	StatCardContainer.BackgroundTransparency = 1
	StatCardContainer.ScrollingDirection = Enum.ScrollingDirection.X
	StatCardContainer.ScrollBarThickness = 0
	StatCardContainer.ZIndex = 51
	local scLayout = Instance.new("UIListLayout", StatCardContainer)
	scLayout.FillDirection = Enum.FillDirection.Horizontal
	scLayout.Padding = UDim.new(0, 10)
	scLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
		StatCardContainer.CanvasSize = UDim2.new(0, scLayout.AbsoluteContentSize.X, 0, 0) 
	end)

	DReq = Instance.new("TextLabel", DetailPanel)
	DReq.Size = UDim2.new(1, -120, 0, 40)
	DReq.Position = UDim2.new(0, 15, 0, 160)
	DReq.BackgroundTransparency = 1
	DReq.Font = Enum.Font.GothamBold
	DReq.TextColor3 = Color3.fromRGB(255, 100, 100)
	DReq.TextSize = 12
	DReq.TextWrapped = true
	DReq.TextXAlignment = Enum.TextXAlignment.Left
	DReq.ZIndex = 51

	UnlockBtn = Instance.new("TextButton", DetailPanel)
	UnlockBtn.Size = UDim2.new(0, 100, 0, 40)
	UnlockBtn.AnchorPoint = Vector2.new(1, 0)
	UnlockBtn.Position = UDim2.new(1, -15, 0, 160)
	UnlockBtn.Font = Enum.Font.GothamBlack
	UnlockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	UnlockBtn.TextSize = 14
	UnlockBtn.Text = "UNLOCK"
	UnlockBtn.ZIndex = 51
	ApplyButtonGradient(UnlockBtn, Color3.fromRGB(60, 60, 60), Color3.fromRGB(30, 30, 30), Color3.fromRGB(80, 80, 90))

	UnlockBtn.MouseButton1Click:Connect(function()
		if SelectedNodeId then Network.UnlockPrestigeNode:FireServer(SelectedNodeId) end
	end)

	local drawnLines = {}
	for id, node in pairs(GameData.PrestigeNodes) do
		local posX, posY = ExtractPos(node.Pos)

		local adjX = posX
		if adjX == 0.2 then adjX = 0.17 elseif adjX == 0.8 then adjX = 0.83 end

		local mappedY = GetSafeYScale(posY) * CANVAS_HEIGHT

		if node.Req and GameData.PrestigeNodes[node.Req] then
			local reqNode = GameData.PrestigeNodes[node.Req]
			local _, reqPosY = ExtractPos(reqNode.Pos)
			local reqMappedY = GetSafeYScale(reqPosY) * CANVAS_HEIGHT

			local startY = math.min(mappedY, reqMappedY)
			local diffY = math.abs(mappedY - reqMappedY)

			local line = Instance.new("Frame", TreeScroll)
			line.Size = UDim2.new(0, 5, 0, diffY) 
			line.Position = UDim2.new(adjX, 0, 0, startY) 
			line.AnchorPoint = Vector2.new(0.5, 0)
			line.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
			line.BorderSizePixel = 0; line.ZIndex = 1
			drawnLines[id] = line
		end

		local btn = Instance.new("TextButton", TreeScroll)
		btn.Size = UDim2.new(0, 55, 0, 55)
		btn.Position = UDim2.new(adjX, 0, 0, mappedY) 
		btn.AnchorPoint = Vector2.new(0.5, 0.5)
		btn.Text = ""
		btn.ZIndex = 3
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

		local btnGrad = Instance.new("UIGradient", btn)
		btnGrad.Color = ColorSequence.new(Color3.fromRGB(80, 80, 90), Color3.fromRGB(20, 20, 25)); btnGrad.Rotation = 45

		local shadow = Instance.new("ImageLabel", btn)
		shadow.BackgroundTransparency = 1; shadow.Image = "rbxassetid://1316045217"; shadow.ImageColor3 = Color3.new(0,0,0); shadow.ImageTransparency = 0.5; shadow.Size = UDim2.new(1, 24, 1, 24); shadow.Position = UDim2.new(0.5, 0, 0.5, 4); shadow.AnchorPoint = Vector2.new(0.5, 0.5); shadow.ZIndex = 1

		local glow = Instance.new("ImageLabel", btn)
		glow.BackgroundTransparency = 1; glow.Image = "rbxassetid://1316045217"; glow.ImageColor3 = Color3.fromHex((node.Color or "#FFFFFF"):gsub("#", "")); glow.ImageTransparency = 1; glow.Size = UDim2.new(1, 30, 1, 30); glow.Position = UDim2.new(0.5, 0, 0.5, 0); glow.AnchorPoint = Vector2.new(0.5, 0.5); glow.ZIndex = 2

		local ring = Instance.new("Frame", btn)
		ring.Size = UDim2.new(1, -6, 1, -6); ring.Position = UDim2.new(0.5, 0, 0.5, 0); ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.BackgroundColor3 = Color3.fromRGB(40, 40, 50); ring.ZIndex = 4
		Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

		local core = Instance.new("Frame", ring)
		core.Size = UDim2.new(1, -8, 1, -8); core.Position = UDim2.new(0.5, 0, 0.5, 0); core.AnchorPoint = Vector2.new(0.5, 0.5); core.BackgroundColor3 = Color3.fromRGB(255, 255, 255); core.ZIndex = 5
		Instance.new("UICorner", core).CornerRadius = UDim.new(1, 0)

		local coreGrad = Instance.new("UIGradient", core)
		coreGrad.Color = ColorSequence.new(Color3.fromRGB(20, 20, 25), Color3.fromRGB(10, 10, 12)); coreGrad.Rotation = -45

		local iconLbl = Instance.new("TextLabel", core)
		iconLbl.Size = UDim2.new(1, 0, 1, 0); iconLbl.BackgroundTransparency = 1; iconLbl.Font = Enum.Font.GothamBlack; iconLbl.TextColor3 = Color3.fromRGB(100, 100, 100); iconLbl.TextSize = 18; iconLbl.ZIndex = 6
		local num = tostring(id):match("%d+")
		if num then iconLbl.Text = num else iconLbl.Text = "★" end

		btn.MouseButton1Click:Connect(function()
			SelectedNodeId = id

			-- Shrink the tree scroll window so the pop up doesn't cover nodes you want to see
			TreeScroll.Size = UDim2.new(1, 0, 1, -285) 

			DetailPanel.Visible = true; DTitle.Text = node.Name or "Unknown"; DTitle.TextColor3 = Color3.fromHex((node.Color or "#FFFFFF"):gsub("#", ""))
			DDesc.Text = node.Desc or ""; DCost.Text = tostring(node.Cost or 0) .. " PTS"

			for _, c in ipairs(StatCardContainer:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end

			if node.BuffType == "FlatStat" and node.BuffStat then
				local cleanStatName = tostring(node.BuffStat):gsub("_Val", ""):gsub("_", " ")
				CreateStatCard(StatCardContainer, cleanStatName, "+" .. tostring(node.BuffValue or 0), node.Color)
			elseif node.BuffType == "Special" then
				if node.BuffStat == "DodgeBonus" then CreateStatCard(StatCardContainer, "Dodge", "+" .. tostring(node.BuffValue) .. "%", node.Color)
				elseif node.BuffStat == "DmgMult" then CreateStatCard(StatCardContainer, "DMG", "+" .. tostring((node.BuffValue or 0)*100) .. "%", node.Color)
				elseif node.BuffStat == "CritBonus" then CreateStatCard(StatCardContainer, "Crit", "+" .. tostring(node.BuffValue) .. "%", node.Color)
				elseif node.BuffStat == "IgnoreArmor" then CreateStatCard(StatCardContainer, "Penetration", "+" .. tostring((node.BuffValue or 0)*100) .. "%", node.Color)
				else CreateStatCard(StatCardContainer, "Passive", "UNLOCKED", node.Color) end
			end

			local isOwned = player:GetAttribute("PrestigeNode_" .. id)
			local hasReq = node.Req == nil or player:GetAttribute("PrestigeNode_" .. node.Req)

			if isOwned then 
				DReq.Text = "OWNED"; DReq.TextColor3 = Color3.fromRGB(100, 255, 100); UnlockBtn.Text = "OWNED"
				ApplyButtonGradient(UnlockBtn, Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 50, 20), Color3.fromRGB(30, 80, 30)); UnlockBtn.Active = false
			elseif not hasReq then 
				DReq.Text = "REQUIRES: " .. (GameData.PrestigeNodes[node.Req] and GameData.PrestigeNodes[node.Req].Name or "Unknown")
				DReq.TextColor3 = Color3.fromRGB(255, 100, 100); UnlockBtn.Text = "LOCKED"
				ApplyButtonGradient(UnlockBtn, Color3.fromRGB(100, 40, 40), Color3.fromRGB(50, 20, 20), Color3.fromRGB(80, 30, 30)); UnlockBtn.Active = false
			else 
				DReq.Text = "AVAILABLE"; DReq.TextColor3 = Color3.fromRGB(200, 200, 200); UnlockBtn.Text = "UNLOCK"
				local btnColor = Color3.fromHex((node.Color or "#FFFFFF"):gsub("#", ""))
				ApplyButtonGradient(UnlockBtn, btnColor, Color3.new(btnColor.R*0.4, btnColor.G*0.4, btnColor.B*0.4), btnColor); UnlockBtn.Active = true 
			end
		end)
		NodeGuis[id] = { Btn = btn, Ring = ring, CoreGrad = coreGrad, Icon = iconLbl, Glow = glow, Line = drawnLines[id], BaseColor = Color3.fromHex((node.Color or "#FFFFFF"):gsub("#", "")) }
	end

	local function UpdateUI()
		local pts = player:GetAttribute("PrestigePoints") or 0
		PointsLabel.Text = "AVAILABLE POINTS: " .. pts

		for id, gui in pairs(NodeGuis) do
			local isOwned = player:GetAttribute("PrestigeNode_" .. id)
			local node = GameData.PrestigeNodes[id]
			local hasReq = node.Req == nil or player:GetAttribute("PrestigeNode_" .. node.Req)

			if isOwned then
				gui.Ring.BackgroundColor3 = gui.BaseColor
				gui.CoreGrad.Color = ColorSequence.new(Color3.new(gui.BaseColor.R*0.4, gui.BaseColor.G*0.4, gui.BaseColor.B*0.4), Color3.fromRGB(20, 20, 25))
				gui.Icon.TextColor3 = Color3.fromRGB(255, 255, 255)
				gui.Glow.ImageTransparency = 0.4
				if gui.Line then gui.Line.BackgroundColor3 = gui.BaseColor; gui.Line.ZIndex = 2 end
			elseif hasReq then
				gui.Ring.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
				gui.CoreGrad.Color = ColorSequence.new(Color3.fromRGB(30, 30, 35), Color3.fromRGB(15, 15, 18))
				gui.Icon.TextColor3 = gui.BaseColor
				gui.Glow.ImageTransparency = 1
				if gui.Line then gui.Line.BackgroundColor3 = Color3.fromRGB(80, 80, 90); gui.Line.ZIndex = 1 end
			else
				gui.Ring.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
				gui.CoreGrad.Color = ColorSequence.new(Color3.fromRGB(20, 20, 25), Color3.fromRGB(10, 10, 12))
				gui.Icon.TextColor3 = Color3.fromRGB(100, 100, 100)
				gui.Glow.ImageTransparency = 1
				if gui.Line then gui.Line.BackgroundColor3 = Color3.fromRGB(40, 40, 50); gui.Line.ZIndex = 1 end
			end
		end

		if SelectedNodeId then
			local node = GameData.PrestigeNodes[SelectedNodeId]
			local isOwned = player:GetAttribute("PrestigeNode_" .. SelectedNodeId)
			local hasReq = node.Req == nil or player:GetAttribute("PrestigeNode_" .. node.Req)

			if isOwned then 
				DReq.Text = "OWNED"; DReq.TextColor3 = Color3.fromRGB(100, 255, 100); UnlockBtn.Text = "OWNED"
				ApplyButtonGradient(UnlockBtn, Color3.fromRGB(40, 100, 40), Color3.fromRGB(20, 50, 20), Color3.fromRGB(30, 80, 30)); UnlockBtn.Active = false
			elseif not hasReq then 
				DReq.Text = "REQUIRES: " .. (GameData.PrestigeNodes[node.Req] and GameData.PrestigeNodes[node.Req].Name or "Unknown")
				DReq.TextColor3 = Color3.fromRGB(255, 100, 100); UnlockBtn.Text = "LOCKED"
				ApplyButtonGradient(UnlockBtn, Color3.fromRGB(100, 40, 40), Color3.fromRGB(50, 20, 20), Color3.fromRGB(80, 30, 30)); UnlockBtn.Active = false
			else 
				DReq.Text = "AVAILABLE"; DReq.TextColor3 = Color3.fromRGB(200, 200, 200); UnlockBtn.Text = "UNLOCK"
				local btnColor = Color3.fromHex((node.Color or "#FFFFFF"):gsub("#", ""))
				ApplyButtonGradient(UnlockBtn, btnColor, Color3.new(btnColor.R*0.4, btnColor.G*0.4, btnColor.B*0.4), btnColor); UnlockBtn.Active = true 
			end
		end
	end

	player.AttributeChanged:Connect(function(attr) if string.find(attr, "Prestige") then UpdateUI() end end)
	UpdateUI()
end

function PrestigeTab.Show() if MainFrame then MainFrame.Visible = true end end

return PrestigeTab