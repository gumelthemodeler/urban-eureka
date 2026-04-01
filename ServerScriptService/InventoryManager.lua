-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local Network = ReplicatedStorage:WaitForChild("Network")
local NotificationEvent = Network:WaitForChild("NotificationEvent")

-- [[ TRAINING & STATS ]]
Network:WaitForChild("TrainAction").OnServerEvent:Connect(function(player, combo, isTitan)
	combo = tonumber(combo) or 0
	combo = math.clamp(combo, 0, 150)

	local prestige = player.leaderstats and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
	local totalStats = (player:GetAttribute("Strength") or 10) + (player:GetAttribute("Defense") or 10) + (player:GetAttribute("Speed") or 10) + (player:GetAttribute("Resolve") or 10)

	local baseXP = 1 + (prestige * 50) + math.floor(totalStats / 4)
	local xpGain = math.floor(baseXP * (1.0 + (combo * 0.02)))

	local targetAttr = isTitan and "TitanXP" or "XP"
	player:SetAttribute(targetAttr, (player:GetAttribute(targetAttr) or 0) + xpGain)
end)

Network:WaitForChild("UpgradeStat").OnServerEvent:Connect(function(player, statName, amount)
	local validStats = {
		["Strength"]=true, ["Defense"]=true, ["Speed"]=true, ["Resolve"]=true,
		["Titan_Power_Val"]=true, ["Titan_Speed_Val"]=true, ["Titan_Hardening_Val"]=true, 
		["Titan_Endurance_Val"]=true, ["Titan_Precision_Val"]=true, ["Titan_Potential_Val"]=true
	}
	if not validStats[statName] then return end

	amount = tonumber(amount) or 1
	amount = math.clamp(amount, 1, 100)

	local isTitanStat = string.match(statName, "Titan_.*_Val$")
	local xpAttr = isTitanStat and "TitanXP" or "XP"

	local currentStat = player:GetAttribute(statName) or 10
	if type(currentStat) == "string" then currentStat = GameData.TitanRanks[currentStat] or 10 end

	local prestige = player.leaderstats and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
	local cleanName = statName:gsub("_Val", ""):gsub("Titan_", "")
	local base = (prestige == 0) and (GameData.BaseStats[cleanName] or 10) or (prestige * 5)
	local statCap = GameData.GetStatCap(prestige)

	local totalCost = 0
	local pXP = player:GetAttribute(xpAttr) or 0

	for i = 0, amount - 1 do
		if currentStat + i >= statCap then break end
		totalCost += GameData.CalculateStatCost(currentStat + i, base, prestige)
	end

	if pXP >= totalCost and totalCost > 0 then
		player:SetAttribute(xpAttr, pXP - totalCost)
		player:SetAttribute(statName, currentStat + amount)
	end
end)

-- [[ PRESTIGE & SKILL TREE ]]
local UnlockPrestigeNode = Network:FindFirstChild("UnlockPrestigeNode") or Instance.new("RemoteEvent", Network)
UnlockPrestigeNode.Name = "UnlockPrestigeNode"

UnlockPrestigeNode.OnServerEvent:Connect(function(player, nodeId)
	local node = GameData.PrestigeNodes[nodeId]
	if not node then return end

	if player:GetAttribute("PrestigeNode_" .. nodeId) then
		NotificationEvent:FireClient(player, "You already own this talent!", "Error")
		return
	end

	local points = player:GetAttribute("PrestigePoints") or 0
	if points < node.Cost then
		NotificationEvent:FireClient(player, "Not enough Prestige Points!", "Error")
		return
	end

	if node.Req and not player:GetAttribute("PrestigeNode_" .. node.Req) then
		NotificationEvent:FireClient(player, "You must unlock the previous node first!", "Error")
		return
	end

	player:SetAttribute("PrestigePoints", points - node.Cost)
	player:SetAttribute("PrestigeNode_" .. nodeId, true)

	if node.BuffType == "FlatStat" then
		player:SetAttribute(node.BuffStat, (player:GetAttribute(node.BuffStat) or 10) + node.BuffValue)
	elseif node.BuffType == "Special" then
		player:SetAttribute("Prestige_" .. node.BuffStat, (player:GetAttribute("Prestige_" .. node.BuffStat) or 0) + node.BuffValue)
	end

	NotificationEvent:FireClient(player, "Unlocked " .. node.Name .. "!", "Success")
end)

Network:WaitForChild("PrestigeEvent").OnServerEvent:Connect(function(player)
	local currentPart = player:GetAttribute("CurrentPart") or 1
	if currentPart > 8 then
		if player.leaderstats and player.leaderstats:FindFirstChild("Prestige") then
			player.leaderstats.Prestige.Value += 1
		end
		player:SetAttribute("CurrentPart", 1)
		player:SetAttribute("CurrentWave", 1)
		player:SetAttribute("PathsFloor", 1)
		player:SetAttribute("PrestigePoints", (player:GetAttribute("PrestigePoints") or 0) + 1)

		NotificationEvent:FireClient(player, "You have Prestiged! +1 Prestige Point acquired!", "Success")
	else
		NotificationEvent:FireClient(player, "You must clear the Campaign (Part 8) before you can Prestige!", "Error")
	end
end)