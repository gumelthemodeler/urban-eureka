-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local CosmeticData = require(ReplicatedStorage:WaitForChild("CosmeticData"))
local Network = ReplicatedStorage:WaitForChild("Network")
local NotificationEvent = Network:WaitForChild("NotificationEvent")

local SellValues = { Common = 10, Uncommon = 25, Rare = 75, Epic = 200, Legendary = 500, Mythical = 1500, Transcendent = 0 }

Network:WaitForChild("EquipItem").OnServerEvent:Connect(function(player, itemName)
	if string.match(itemName, "^Unequip_") then
		local slotType = string.gsub(itemName, "Unequip_", "")
		if slotType == "Weapon" then
			player:SetAttribute("EquippedWeapon", "None")
			player:SetAttribute("FightingStyle", "None")
		elseif slotType == "Accessory" then
			player:SetAttribute("EquippedAccessory", "None")
		end
		return
	end

	local itemInfo = ItemData.Equipment[itemName]
	if itemInfo then
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		local count = player:GetAttribute(safeName) or 0
		if count > 0 then
			if itemInfo.Type == "Weapon" then
				player:SetAttribute("EquippedWeapon", itemName)
				player:SetAttribute("FightingStyle", itemInfo.Style or "None")
			elseif itemInfo.Type == "Accessory" then
				player:SetAttribute("EquippedAccessory", itemName)
			end
		end
	end
end)

Network:WaitForChild("SellItem").OnServerEvent:Connect(function(player, itemName, sellAll)
	local itemInfo = ItemData.Equipment[itemName] or ItemData.Consumables[itemName]
	if itemInfo then
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		local count = player:GetAttribute(safeName) or 0
		if count > 0 then
			local sellPrice = SellValues[itemInfo.Rarity or "Common"] or 10
			local amountToSell = sellAll and count or 1

			player:SetAttribute(safeName, count - amountToSell)
			player.leaderstats.Dews.Value += (sellPrice * amountToSell)
		end
	end
end)

Network:WaitForChild("AutoSell").OnServerEvent:Connect(function(player, rarity)
	local attrName = "AutoSell_" .. rarity
	player:SetAttribute(attrName, not player:GetAttribute(attrName))
end)

Network:WaitForChild("ConsumeItem").OnServerEvent:Connect(function(player, itemName)
	local itemInfo = ItemData.Consumables[itemName]
	if itemInfo and itemInfo.Action then
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		local count = player:GetAttribute(safeName) or 0
		if count > 0 then
			player:SetAttribute(safeName, count - 1)

			if itemInfo.Action == "EquipTitan" then
				player:SetAttribute("Titan", itemInfo.TitanName)
				NotificationEvent:FireClient(player, "Inherited the " .. itemInfo.TitanName .. "!", "Success")
			elseif itemInfo.Buff == "Dews" then
				local amt = math.random(itemInfo.MinAmount or 5000, itemInfo.MaxAmount or 20000)
				player.leaderstats.Dews.Value += amt
				NotificationEvent:FireClient(player, "Gained " .. amt .. " Dews!", "Success")
			elseif itemInfo.Buff == "Gamepass" then
				player:SetAttribute("Has" .. itemInfo.Unlock, true)
				NotificationEvent:FireClient(player, "Unlocked " .. itemInfo.Unlock .. "!", "Success")
			else
				local expiryAttr = "Buff_" .. itemInfo.Buff .. "_Expiry"
				player:SetAttribute(expiryAttr, os.time() + (itemInfo.Duration or 900))
			end
		end
	end
end)

Network:WaitForChild("ManageStorage").OnServerEvent:Connect(function(player, gType, slotIndex)
	slotIndex = tonumber(slotIndex)
	if not slotIndex or slotIndex < 1 or slotIndex > 6 then return end
	if slotIndex > 3 and not player:GetAttribute("Has" .. gType .. "Vault") then return end

	local currentAttr = (gType == "Titan") and "Titan" or "Clan"
	local slotAttr = currentAttr .. "_Slot" .. slotIndex

	local currentVal = player:GetAttribute(currentAttr) or "None"
	local slotVal = player:GetAttribute(slotAttr) or "None"

	player:SetAttribute(currentAttr, slotVal)
	player:SetAttribute(slotAttr, currentVal)
end)

local EquipCosmetic = Network:FindFirstChild("EquipCosmetic") or Instance.new("RemoteEvent", Network)
EquipCosmetic.Name = "EquipCosmetic"

EquipCosmetic.OnServerEvent:Connect(function(player, cosType, cosKey)
	local dataPool = (cosType == "Title") and CosmeticData.Titles or CosmeticData.Auras
	local data = dataPool[cosKey]

	if data then
		if CosmeticData.CheckUnlock(player, data.ReqType, data.ReqValue) then
			player:SetAttribute("Equipped" .. cosType, cosKey)
			NotificationEvent:FireClient(player, "Equipped " .. data.Name .. "!", "Success")
		else
			NotificationEvent:FireClient(player, "You have not unlocked this cosmetic.", "Error")
		end
	end
end)