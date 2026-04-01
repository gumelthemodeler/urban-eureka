-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local TradeMenu = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local MainFrame
local PlayerListFrame

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}
	grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 4)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn)
		stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.LineJoinMode = Enum.LineJoinMode.Miter
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

local function DrawOfferItems(parentFrame, offerItems, canRemove)
	for _, child in ipairs(parentFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for itemName, amount in pairs(offerItems) do
		local itemBtn = Instance.new("TextButton", parentFrame)
		-- [[ FIX: Scaled up slightly for mobile tap targets ]]
		itemBtn.Size = UDim2.new(0, 65, 0, 65)

		local rColor = Color3.fromRGB(200, 200, 200)
		local iData = ItemData.Equipment[itemName] or ItemData.Consumables[itemName]
		if iData and iData.Rarity then
			if iData.Rarity == "Uncommon" then rColor = Color3.fromRGB(80, 220, 80)
			elseif iData.Rarity == "Rare" then rColor = Color3.fromRGB(80, 140, 255)
			elseif iData.Rarity == "Epic" then rColor = Color3.fromRGB(180, 80, 255)
			elseif iData.Rarity == "Legendary" then rColor = Color3.fromRGB(255, 180, 40)
			elseif iData.Rarity == "Mythic" then rColor = Color3.fromRGB(255, 80, 80) end
		end

		itemBtn.Text = "<font color='#" .. rColor:ToHex() .. "'>" .. itemName .. "</font>\n<font color='#AAFFAA'>x" .. amount .. "</font>"
		itemBtn.RichText = true
		itemBtn.TextScaled = true
		itemBtn.Font = Enum.Font.GothamBold
		itemBtn.TextColor3 = Color3.fromRGB(255,255,255)
		ApplyButtonGradient(itemBtn, Color3.fromRGB(40,40,50), Color3.fromRGB(20,20,30), Color3.fromRGB(100,100,120))

		if canRemove then
			itemBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("RemoveItem", itemName) end)
		end
	end
end

local function DrawInventorySelector(parentFrame, currentOffer)
	for _, child in ipairs(parentFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local function ProcessInv(dict)
		for itemName, iData in pairs(dict) do
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			local owned = player:GetAttribute(safeName) or 0
			local offered = currentOffer[itemName] or 0
			local available = owned - offered

			if available > 0 then
				local itemBtn = Instance.new("TextButton", parentFrame)
				itemBtn.Size = UDim2.new(0, 65, 0, 65)

				local rColor = Color3.fromRGB(200, 200, 200)
				if iData.Rarity == "Uncommon" then rColor = Color3.fromRGB(80, 220, 80)
				elseif iData.Rarity == "Rare" then rColor = Color3.fromRGB(80, 140, 255)
				elseif iData.Rarity == "Epic" then rColor = Color3.fromRGB(180, 80, 255)
				elseif iData.Rarity == "Legendary" then rColor = Color3.fromRGB(255, 180, 40)
				elseif iData.Rarity == "Mythic" then rColor = Color3.fromRGB(255, 80, 80) end

				itemBtn.Text = "<font color='#" .. rColor:ToHex() .. "'>" .. itemName .. "</font>\n<font color='#CCCCCC'>Owned: " .. available .. "</font>"
				itemBtn.RichText = true
				itemBtn.TextScaled = true
				itemBtn.Font = Enum.Font.GothamBold
				itemBtn.TextColor3 = Color3.fromRGB(255,255,255)
				ApplyButtonGradient(itemBtn, Color3.fromRGB(30,30,40), Color3.fromRGB(15,15,25), Color3.fromRGB(80,80,100))

				itemBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("AddItem", itemName) end)
			end
		end
	end

	ProcessInv(ItemData.Equipment)
	ProcessInv(ItemData.Consumables)
end

function TradeMenu.Init(parentFrame, tooltipMgr)
	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "TradeMenuFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local Title = Instance.new("TextLabel", MainFrame)
	Title.Size = UDim2.new(1, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Font = Enum.Font.GothamBlack; Title.TextColor3 = Color3.fromRGB(150, 200, 255); Title.TextSize = 20; Title.Text = "SECURE TRADE HUB"
	ApplyGradient(Title, Color3.fromRGB(150, 200, 255), Color3.fromRGB(50, 150, 255))

	PlayerListFrame = Instance.new("ScrollingFrame", MainFrame)
	PlayerListFrame.Size = UDim2.new(0.96, 0, 1, -60); PlayerListFrame.Position = UDim2.new(0.02, 0, 0, 60); PlayerListFrame.BackgroundTransparency = 1; PlayerListFrame.ScrollBarThickness = 0; PlayerListFrame.BorderSizePixel = 0

	local plLayout = Instance.new("UIGridLayout", PlayerListFrame)
	plLayout.CellSize = UDim2.new(0.98, 0, 0, 75); plLayout.CellPadding = UDim2.new(0, 0, 0, 10); plLayout.SortOrder = Enum.SortOrder.Name; plLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function RefreshPlayers()
		for _, child in ipairs(PlayerListFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local row = Instance.new("Frame", PlayerListFrame)
				row.Name = p.Name; row.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
				local stroke = Instance.new("UIStroke", row); stroke.Color = Color3.fromRGB(50, 50, 60); stroke.Thickness = 1; stroke.Transparency = 0.55; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

				local avatar = Instance.new("ImageLabel", row)
				avatar.Size = UDim2.new(0, 50, 0, 50); avatar.Position = UDim2.new(0, 10, 0.5, 0); avatar.AnchorPoint = Vector2.new(0, 0.5); avatar.BackgroundColor3 = Color3.fromRGB(15, 15, 20); avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..p.UserId.."&w=150&h=150"
				Instance.new("UICorner", avatar).CornerRadius = UDim.new(0, 6)

				local nLbl = Instance.new("TextLabel", row)
				nLbl.Size = UDim2.new(1, -160, 1, 0); nLbl.Position = UDim2.new(0, 70, 0, 0); nLbl.BackgroundTransparency = 1; nLbl.Font = Enum.Font.GothamBlack; nLbl.TextColor3 = Color3.fromRGB(230, 230, 240); nLbl.TextSize = 14; nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.Text = string.upper(p.Name)

				local reqBtn = Instance.new("TextButton", row)
				reqBtn.Size = UDim2.new(0, 80, 0, 30); reqBtn.Position = UDim2.new(1, -10, 0.5, 0); reqBtn.AnchorPoint = Vector2.new(1, 0.5); reqBtn.Font = Enum.Font.GothamBlack; reqBtn.TextColor3 = Color3.fromRGB(150, 200, 255); reqBtn.TextSize = 11; reqBtn.Text = "REQUEST"
				ApplyButtonGradient(reqBtn, Color3.fromRGB(20, 25, 35), Color3.fromRGB(10, 15, 25), Color3.fromRGB(80, 140, 220))

				reqBtn.MouseButton1Click:Connect(function()
					Network.TradeAction:FireServer("SendRequest", p.Name)

					reqBtn.Text = "SENT"; reqBtn.TextColor3 = Color3.fromRGB(150, 255, 150)
					ApplyButtonGradient(reqBtn, Color3.fromRGB(25, 35, 25), Color3.fromRGB(15, 20, 15), Color3.fromRGB(80, 180, 80))
					task.delay(3, function() 
						reqBtn.Text = "REQUEST"; reqBtn.TextColor3 = Color3.fromRGB(150, 200, 255)
						ApplyButtonGradient(reqBtn, Color3.fromRGB(20, 25, 35), Color3.fromRGB(10, 15, 25), Color3.fromRGB(80, 140, 220)) 
					end)
				end)
			end
		end
		task.delay(0.05, function() PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, (#Players:GetPlayers() - 1) * 85 + 20) end)
	end

	MainFrame:GetPropertyChangedSignal("Visible"):Connect(function() if MainFrame.Visible then RefreshPlayers() end end)
	Players.PlayerAdded:Connect(function() if MainFrame.Visible then RefreshPlayers() end end)
	Players.PlayerRemoving:Connect(function() if MainFrame.Visible then RefreshPlayers() end end)

	Network.TradeUpdate.OnClientEvent:Connect(function(action, data)
		local AOT_UI = playerGui:WaitForChild("AOT_Interface")

		if action == "Open" then
			if AOT_UI:FindFirstChild("TradeOverlay") then AOT_UI.TradeOverlay:Destroy() end

			local overlay = Instance.new("Frame", AOT_UI)
			overlay.Name = "TradeOverlay"; overlay.Size = UDim2.new(1, 0, 1, 0); overlay.BackgroundColor3 = Color3.new(0,0,0); overlay.BackgroundTransparency = 0.6; overlay.Active = true

			local mainPanel = Instance.new("Frame", overlay)
			mainPanel.Name = "Frame"
			mainPanel.Size = UDim2.new(0.95, 0, 0.95, 0); mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0); mainPanel.AnchorPoint = Vector2.new(0.5, 0.5); mainPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
			Instance.new("UICorner", mainPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", mainPanel).Color = Color3.fromRGB(80, 140, 220); mainPanel.UIStroke.Thickness = 2

			local title = Instance.new("TextLabel", mainPanel)
			title.Size = UDim2.new(1, 0, 0, 40); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextColor3 = Color3.fromRGB(150, 200, 255); title.TextSize = 16; title.Text = "SESSION: " .. string.upper(data.OtherPlayer)
			ApplyGradient(title, Color3.fromRGB(150, 200, 255), Color3.fromRGB(50, 150, 255))

			-- [[ FIX: Shortened Content Area to make room for bottom buttons on mobile ]]
			local tradeContentArea = Instance.new("Frame", mainPanel)
			tradeContentArea.Name = "TradeContentArea"
			tradeContentArea.Size = UDim2.new(1, -20, 1, -120); tradeContentArea.Position = UDim2.new(0, 10, 0, 50); tradeContentArea.BackgroundTransparency = 1

			local myOfferFrame = Instance.new("ScrollingFrame", tradeContentArea)
			myOfferFrame.Name = "MyOffer"
			myOfferFrame.Size = UDim2.new(0.48, 0, 0.45, 0); myOfferFrame.Position = UDim2.new(0,0,0,0)
			myOfferFrame.BackgroundColor3 = Color3.fromRGB(15,15,20); myOfferFrame.ScrollBarThickness = 0
			Instance.new("UICorner", myOfferFrame).CornerRadius = UDim.new(0,6); Instance.new("UIStroke", myOfferFrame).Color = Color3.fromRGB(60,60,70)
			local mg = Instance.new("UIGridLayout", myOfferFrame); mg.CellSize = UDim2.new(0, 65, 0, 65); mg.CellPadding = UDim2.new(0,5,0,5)
			local mPad = Instance.new("UIPadding", myOfferFrame); mPad.PaddingTop = UDim.new(0,5); mPad.PaddingLeft = UDim.new(0,5)

			local theirOfferFrame = Instance.new("ScrollingFrame", tradeContentArea)
			theirOfferFrame.Name = "TheirOffer"
			theirOfferFrame.Size = UDim2.new(0.48, 0, 0.45, 0); theirOfferFrame.Position = UDim2.new(0.52,0,0,0)
			theirOfferFrame.BackgroundColor3 = Color3.fromRGB(15,15,20); theirOfferFrame.ScrollBarThickness = 0
			Instance.new("UICorner", theirOfferFrame).CornerRadius = UDim.new(0,6); Instance.new("UIStroke", theirOfferFrame).Color = Color3.fromRGB(60,60,70)
			local tg = Instance.new("UIGridLayout", theirOfferFrame); tg.CellSize = UDim2.new(0, 65, 0, 65); tg.CellPadding = UDim2.new(0,5,0,5)
			local tPad = Instance.new("UIPadding", theirOfferFrame); tPad.PaddingTop = UDim.new(0,5); tPad.PaddingLeft = UDim.new(0,5)

			local inventorySelector = Instance.new("ScrollingFrame", tradeContentArea)
			inventorySelector.Name = "InventorySelector"
			inventorySelector.Size = UDim2.new(1, 0, 0.5, 0); inventorySelector.Position = UDim2.new(0,0,0.5,0)
			inventorySelector.BackgroundColor3 = Color3.fromRGB(12,12,15); inventorySelector.ScrollBarThickness = 0
			Instance.new("UICorner", inventorySelector).CornerRadius = UDim.new(0,6); Instance.new("UIStroke", inventorySelector).Color = Color3.fromRGB(100,100,150)
			local ig = Instance.new("UIGridLayout", inventorySelector); ig.CellSize = UDim2.new(0, 65, 0, 65); ig.CellPadding = UDim2.new(0,5,0,5)
			local iPad = Instance.new("UIPadding", inventorySelector); iPad.PaddingTop = UDim.new(0,5); iPad.PaddingLeft = UDim.new(0,5)

			-- [[ FIX: Anchored buttons exactly to the bottom so they don't clip beneath the UI bounds ]]
			local ButtonArea = Instance.new("Frame", mainPanel)
			ButtonArea.Size = UDim2.new(1, -20, 0, 50)
			ButtonArea.Position = UDim2.new(0, 10, 1, -60)
			ButtonArea.BackgroundTransparency = 1

			local confirmBtn = Instance.new("TextButton", ButtonArea)
			confirmBtn.Name = "ConfirmBtn"; confirmBtn.Size = UDim2.new(0.48, 0, 1, 0); confirmBtn.Position = UDim2.new(0, 0, 0, 0); confirmBtn.Font = Enum.Font.GothamBlack; confirmBtn.TextColor3 = Color3.fromRGB(150, 255, 150); confirmBtn.TextSize = 12; confirmBtn.Text = "LOCK IN OFFER"
			ApplyButtonGradient(confirmBtn, Color3.fromRGB(20, 35, 20), Color3.fromRGB(10, 20, 10), Color3.fromRGB(80, 180, 80))
			confirmBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("ToggleConfirm") end)

			local cancelBtn = Instance.new("TextButton", ButtonArea)
			cancelBtn.Size = UDim2.new(0.48, 0, 1, 0); cancelBtn.Position = UDim2.new(1, 0, 0, 0); cancelBtn.AnchorPoint = Vector2.new(1, 0); cancelBtn.Font = Enum.Font.GothamBlack; cancelBtn.TextColor3 = Color3.fromRGB(255, 150, 150); cancelBtn.TextSize = 12; cancelBtn.Text = "ABORT"
			ApplyButtonGradient(cancelBtn, Color3.fromRGB(35, 20, 20), Color3.fromRGB(20, 10, 10), Color3.fromRGB(180, 60, 60))
			cancelBtn.MouseButton1Click:Connect(function() Network.TradeAction:FireServer("Cancel") end)

		elseif action == "Sync" then
			local overlay = AOT_UI:FindFirstChild("TradeOverlay")
			if not overlay then return end

			local isP1 = (data.P1 == player)
			local myOffer = isP1 and data.P1Offer or data.P2Offer
			local theirOffer = isP1 and data.P2Offer or data.P1Offer
			local amReady = isP1 and data.P1Confirmed or data.P2Confirmed
			local theyReady = isP1 and data.P2Confirmed or data.P1Confirmed

			local mainPanel = overlay:FindFirstChild("Frame")
			local ButtonArea = mainPanel and mainPanel:FindFirstChild("Frame") -- Actually we didn't name ButtonArea, it will be the only other Frame besides TradeContentArea. Let's just search globally in mainPanel.
			local confirmBtn = nil
			for _, child in ipairs(mainPanel:GetDescendants()) do
				if child.Name == "ConfirmBtn" then confirmBtn = child break end
			end

			local contentArea = mainPanel and mainPanel:FindFirstChild("TradeContentArea")

			if confirmBtn then
				if not amReady then
					confirmBtn.Text = "LOCK IN OFFER"
					ApplyButtonGradient(confirmBtn, Color3.fromRGB(80, 80, 180), Color3.fromRGB(40, 40, 100))
				elseif amReady and not theyReady then
					confirmBtn.Text = "WAITING ON PARTNER..."
					ApplyButtonGradient(confirmBtn, Color3.fromRGB(180, 180, 80), Color3.fromRGB(100, 100, 40))
				elseif amReady and theyReady then
					confirmBtn.Text = "READY TO TRADE"
					ApplyButtonGradient(confirmBtn, Color3.fromRGB(80, 180, 80), Color3.fromRGB(40, 100, 40))
				end

				if data.Countdown > 0 then
					confirmBtn.Text = "TRADING IN " .. data.Countdown .. "..."
				end
			end

			if contentArea then
				local myFr = contentArea:FindFirstChild("MyOffer")
				local theirFr = contentArea:FindFirstChild("TheirOffer")
				local invFr = contentArea:FindFirstChild("InventorySelector")
				if myFr then 
					DrawOfferItems(myFr, myOffer.Items, true) 
					local cCount = 0; for k,v in pairs(myOffer.Items) do cCount += 1 end
					myFr.CanvasSize = UDim2.new(0,0,0, math.ceil(cCount/3)*70 + 10)
				end
				if theirFr then 
					DrawOfferItems(theirFr, theirOffer.Items, false) 
					local cCount = 0; for k,v in pairs(theirOffer.Items) do cCount += 1 end
					theirFr.CanvasSize = UDim2.new(0,0,0, math.ceil(cCount/3)*70 + 10)
				end
				if invFr then 
					DrawInventorySelector(invFr, myOffer.Items)
					local cCount = 0; for _, child in ipairs(invFr:GetChildren()) do if child:IsA("TextButton") then cCount += 1 end end
					invFr.CanvasSize = UDim2.new(0,0,0, math.ceil(cCount/4)*70 + 10)
				end
			end

		elseif action == "TradeComplete" or action == "TradeCancelled" then
			if AOT_UI:FindFirstChild("TradeOverlay") then AOT_UI.TradeOverlay:Destroy() end
		end
	end)
end

Network:WaitForChild("TradeRequest").OnClientEvent:Connect(function(senderName)
	local AOT_UI = playerGui:WaitForChild("AOT_Interface", 5)
	if not AOT_UI then return end

	if AOT_UI:FindFirstChild("IncomingTradePrompt_" .. senderName) then return end

	local prompt = Instance.new("Frame", AOT_UI)
	prompt.Name = "IncomingTradePrompt_" .. senderName
	prompt.Size = UDim2.new(0, 300, 0, 120)
	prompt.Position = UDim2.new(0.5, 0, 0.85, 0)
	prompt.AnchorPoint = Vector2.new(0.5, 0.5)
	prompt.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	Instance.new("UICorner", prompt).CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke", prompt)
	stroke.Color = Color3.fromRGB(150, 200, 255); stroke.Thickness = 2

	local lbl = Instance.new("TextLabel", prompt)
	lbl.Size = UDim2.new(1, 0, 0, 50); lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack; lbl.TextColor3 = Color3.fromRGB(255, 255, 255); lbl.TextSize = 14
	lbl.Text = senderName .. " sent a trade request!"

	local accBtn = Instance.new("TextButton", prompt)
	accBtn.Size = UDim2.new(0.4, 0, 0, 40); accBtn.Position = UDim2.new(0.05, 0, 1, -50)
	accBtn.Font = Enum.Font.GothamBlack; accBtn.TextColor3 = Color3.fromRGB(150, 255, 150); accBtn.Text = "ACCEPT"; accBtn.TextSize = 14
	ApplyButtonGradient(accBtn, Color3.fromRGB(20, 40, 20), Color3.fromRGB(10, 20, 10), Color3.fromRGB(80, 180, 80))

	local decBtn = Instance.new("TextButton", prompt)
	decBtn.Size = UDim2.new(0.4, 0, 0, 40); decBtn.Position = UDim2.new(0.55, 0, 1, -50)
	decBtn.Font = Enum.Font.GothamBlack; decBtn.TextColor3 = Color3.fromRGB(255, 150, 150); decBtn.Text = "DECLINE"; decBtn.TextSize = 14
	ApplyButtonGradient(decBtn, Color3.fromRGB(40, 20, 20), Color3.fromRGB(20, 10, 10), Color3.fromRGB(180, 80, 80))

	accBtn.MouseButton1Click:Connect(function()
		Network.TradeAction:FireServer("AcceptRequest", senderName)
		prompt:Destroy()
	end)

	decBtn.MouseButton1Click:Connect(function()
		Network.TradeAction:FireServer("DeclineRequest", senderName)
		prompt:Destroy()
	end)

	task.delay(15, function()
		if prompt and prompt.Parent then prompt:Destroy() end
	end)
end)

function TradeMenu.Show() if MainFrame then MainFrame.Visible = true end end

return TradeMenu