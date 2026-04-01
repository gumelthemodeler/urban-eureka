-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")

local RaidAction = Network:FindFirstChild("RaidAction") or Instance.new("RemoteEvent", Network); RaidAction.Name = "RaidAction"
local RaidUpdate = Network:FindFirstChild("RaidUpdate") or Instance.new("RemoteEvent", Network); RaidUpdate.Name = "RaidUpdate"

local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local CombatCore = require(script.Parent:WaitForChild("CombatCore"))

local ActiveRaids = {}
local TURN_DURATION = 15

local AoESkills = { ["Colossal Steam"] = 0.40, ["Titan Roar"] = 0.30, ["Stomp"] = 0.25, ["Crushed Boulders"] = 0.35 }

local function CreateCombatant(player)
	local wpnName = player:GetAttribute("EquippedWeapon") or "None"
	local accName = player:GetAttribute("EquippedAccessory") or "None"
	local wpnBonus = (ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Bonus) or {}
	local accBonus = (ItemData.Equipment[accName] and ItemData.Equipment[accName].Bonus) or {}

	local safeWpnName = wpnName:gsub("[^%w]", "")
	local awakenedString = player:GetAttribute(safeWpnName .. "_Awakened")
	local awakenedStats = { DmgMult = 1.0, DodgeBonus = 0, CritBonus = 0, HpBonus = 0, SpdBonus = 0, GasBonus = 0, HealOnKill = 0, IgnoreArmor = 0 }

	if awakenedString then
		for stat in string.gmatch(awakenedString, "[^|]+") do
			stat = stat:match("^%s*(.-)%s*$")
			if stat:find("DMG") then awakenedStats.DmgMult += tonumber(stat:match("%d+")) / 100
			elseif stat:find("DODGE") then awakenedStats.DodgeBonus += tonumber(stat:match("%d+"))
			elseif stat:find("CRIT") then awakenedStats.CritBonus += tonumber(stat:match("%d+"))
			elseif stat:find("MAX HP") then awakenedStats.HpBonus += tonumber(stat:match("%d+"))
			elseif stat:find("SPEED") then awakenedStats.SpdBonus += tonumber(stat:match("%d+"))
			elseif stat:find("GAS CAP") then awakenedStats.GasBonus += tonumber(stat:match("%d+"))
			elseif stat:find("IGNORE") then awakenedStats.IgnoreArmor += tonumber(stat:match("%d+")) / 100
			end
		end
	end

	local pMaxHP = ((player:GetAttribute("Health") or 10) + (wpnBonus.Health or 0) + (accBonus.Health or 0)) * 10 + awakenedStats.HpBonus
	local pMaxGas = ((player:GetAttribute("Gas") or 10) + (wpnBonus.Gas or 0) + (accBonus.Gas or 0)) * 10 + awakenedStats.GasBonus

	return {
		IsPlayer = true, Name = player.Name, PlayerObj = player, UserId = player.UserId,
		Clan = player:GetAttribute("Clan") or "None", Titan = player:GetAttribute("Titan") or "None",
		Style = ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Style or "None",
		HP = pMaxHP, MaxHP = pMaxHP, Gas = pMaxGas, MaxGas = pMaxGas, TitanEnergy = 100, MaxTitanEnergy = 100,
		TotalStrength = (player:GetAttribute("Strength") or 10) + (wpnBonus.Strength or 0) + (accBonus.Strength or 0),
		TotalDefense = (player:GetAttribute("Defense") or 10) + (wpnBonus.Defense or 0) + (accBonus.Defense or 0),
		TotalSpeed = (player:GetAttribute("Speed") or 10) + (wpnBonus.Speed or 0) + (accBonus.Speed or 0),
		TotalResolve = (player:GetAttribute("Resolve") or 10) + (wpnBonus.Resolve or 0) + (accBonus.Resolve or 0),
		Statuses = {}, Cooldowns = {}, Move = nil, TargetLimb = "Body", Aggro = 0
	}
end

local function EndRaid(raidId, isVictory)
	local raid = ActiveRaids[raidId]
	if not raid then return end

	local bData = EnemyData.RaidBosses[raid.BossId]

	for _, pData in ipairs(raid.Party) do
		local player = pData.PlayerObj
		if player and player.Parent then
			if isVictory then
				local drops = bData.Drops
				local dews = drops.Dews
				local xp = drops.XP

				-- Dead Player Penalty
				local isDead = (pData.HP <= 0)
				if isDead then
					dews = math.floor(dews * 0.5)
					xp = math.floor(xp * 0.5)
				end

				player.leaderstats.Dews.Value += dews
				player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + xp)

				local lootMsg = "\nLoot: " .. dews .. " Dews, " .. xp .. " XP"
				if isDead then lootMsg = lootMsg .. " (Reduced: Died in Combat)" end

				if not isDead and drops.ItemChance then
					for iName, chance in pairs(drops.ItemChance) do
						if math.random(1, 100) <= chance then
							local safeName = iName:gsub("[^%w]", "") .. "Count"
							player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + 1)
							lootMsg = lootMsg .. "\n[RARE DROP] " .. iName .. "!"
						end
					end
				end
				Network.NotificationEvent:FireClient(player, "RAID CLEARED!" .. lootMsg, "Success")
				RaidUpdate:FireClient(player, "RaidEnded", true)
			else
				Network.NotificationEvent:FireClient(player, "Your party was wiped out...", "Error")
				RaidUpdate:FireClient(player, "RaidEnded", false)
			end
		end
	end
	ActiveRaids[raidId] = nil
end

local function ResolveRaidTurn(raidId)
	local raid = ActiveRaids[raidId]
	if not raid or raid.State == "Resolving" then return end
	raid.State = "Resolving"

	local turnDelay = 1.5

	for _, actor in ipairs(raid.Party) do
		if actor.HP > 0 and raid.Boss.HP > 0 then
			if actor.Statuses and (actor.Statuses["Blinded"] or actor.Statuses["TrueBlind"] or actor.Statuses["Stun"]) then
				local logMsg = "<font color='#555555'>" .. actor.Name .. " is INCAPACITATED and lost their turn!</font>"
				for _, p in ipairs(raid.Party) do
					if p.PlayerObj and p.PlayerObj.Parent then
						RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
					end
				end
				task.wait(turnDelay)
				continue
			end

			local skill = SkillData.Skills[actor.Move]
			if skill then
				if skill.GasCost then actor.Gas = math.max(0, actor.Gas - skill.GasCost) end
				if skill.EnergyCost then actor.TitanEnergy = math.max(0, actor.TitanEnergy - skill.EnergyCost) end
				if skill.Effect == "Rest" or actor.Move == "Recover" then actor.Gas = math.min(actor.MaxGas, actor.Gas + (actor.MaxGas * 0.40)) end

				if skill.Effect == "Flee" or actor.Move == "Retreat" then
					actor.HP = 0 
					local logMsg = "<font color='#AAAAAA'>" .. actor.Name .. " fired a smoke signal and retreated from the Raid!</font>"
					for _, p in ipairs(raid.Party) do
						if p.PlayerObj and p.PlayerObj.Parent then
							RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
						end
					end
					task.wait(turnDelay)
					continue
				end

				if actor.Move == "Fall Back" then
					raid.Range = "Long"
					local logMsg = "<font color='#55FFFF'>" .. actor.Name .. " fell back! The party is now at LONG RANGE!</font>"
					for _, p in ipairs(raid.Party) do
						if p.PlayerObj and p.PlayerObj.Parent then
							RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
						end
					end
					task.wait(turnDelay)
					continue
				end

				if actor.Move == "Close In" then
					raid.Range = "Close"
					local logMsg = "<font color='#55FF55'>" .. actor.Name .. " fired ODM gear! The party closed the gap to MELEE RANGE!</font>"
					for _, p in ipairs(raid.Party) do
						if p.PlayerObj and p.PlayerObj.Parent then
							RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
						end
					end
					task.wait(turnDelay)
					continue
				end

				local sRange = skill.Range or "Close"
				if sRange ~= "Any" and sRange ~= raid.Range then
					local logMsg = "<font color='#AAAAAA'>" .. actor.Name .. " used " .. actor.Move:upper() .. ", but the boss is at " .. string.upper(raid.Range) .. " RANGE! The attack missed completely!</font>"
					for _, p in ipairs(raid.Party) do
						if p.PlayerObj and p.PlayerObj.Parent then
							RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
						end
					end
					task.wait(turnDelay)
					continue
				end
			end

			local startingBossHP = raid.Boss.HP
			local logMsg, didHit, shakeType = CombatCore.ExecuteStrike(actor, raid.Boss, actor.Move, actor.TargetLimb, actor.Name, raid.Boss.Name, "#55FFFF", "#FF5555")

			local damageDealt = startingBossHP - raid.Boss.HP
			if damageDealt > 0 then actor.Aggro += damageDealt end

			for _, p in ipairs(raid.Party) do
				if p.PlayerObj and p.PlayerObj.Parent then
					RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = shakeType, BossData = raid.Boss, SkillUsed = actor.Move, Attacker = actor.Name, PartyData = raid.Party, Range = raid.Range })
				end
			end
			task.wait(turnDelay)
		end
	end

	local target = nil
	for _, p in ipairs(raid.Party) do
		if p.HP > 0 then
			if not target or p.Aggro > target.Aggro then target = p end
		end
	end

	if raid.Boss.HP > 0 and target then
		if raid.Boss.Statuses then
			if raid.Boss.Statuses["Stun"] then raid.Boss.Statuses["Crippled"] = raid.Boss.Statuses["Stun"]; raid.Boss.Statuses["Stun"] = nil end
			if raid.Boss.Statuses["Blinded"] then raid.Boss.Statuses["Weakened"] = raid.Boss.Statuses["Blinded"]; raid.Boss.Statuses["Blinded"] = nil end
			if raid.Boss.Statuses["TrueBlind"] then raid.Boss.Statuses["Weakened"] = raid.Boss.Statuses["TrueBlind"]; raid.Boss.Statuses["TrueBlind"] = nil end
		end

		local bSkills = raid.Boss.Skills
		local chosenSkill = bSkills[math.random(1, #bSkills)]

		if AoESkills[chosenSkill] then
			local aoePct = AoESkills[chosenSkill]
			local logMsg = "<font color='#FFAA00'><b>" .. raid.Boss.Name .. " unleashes " .. chosenSkill:upper() .. "! It hits the entire party!</b></font>\n"

			for _, p in ipairs(raid.Party) do
				if p.HP > 0 then
					if p.Statuses and (tonumber(p.Statuses["Dodge"]) or 0) > 0 then
						logMsg = logMsg .. "- " .. p.Name .. " maneuvered out of the way!\n"
					else
						local rawDmg = math.floor(p.MaxHP * aoePct)
						local survived, hitGate, gateBroken, finalDmg, gateName = CombatCore.TakeDamage(p, rawDmg, "AoE")

						logMsg = logMsg .. "- " .. p.Name .. " takes " .. finalDmg .. " damage!"
						if hitGate then logMsg = logMsg .. " (Mitigated by " .. gateName .. ")" end
						if survived then logMsg = logMsg .. " <font color='#FF55FF'>...TATAKAE!</font>" end
						logMsg = logMsg .. "\n"
					end
				end
			end

			for _, p in ipairs(raid.Party) do
				if p.PlayerObj and p.PlayerObj.Parent then
					RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "Heavy", BossData = raid.Boss, SkillUsed = chosenSkill, Attacker = raid.Boss.Name, PartyData = raid.Party, Range = raid.Range })
				end
			end
			task.wait(turnDelay + 1)
		else
			local sData = SkillData.Skills[chosenSkill]
			local sRange = sData and sData.Range or "Close"

			if raid.Range == "Long" and sRange == "Close" then
				local logMsg = "<font color='#AAAAAA'>" .. raid.Boss.Name .. " used " .. chosenSkill:upper() .. ", but the party is at LONG RANGE! The attack missed completely!</font>"
				for _, p in ipairs(raid.Party) do
					if p.PlayerObj and p.PlayerObj.Parent then
						RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
					end
				end
				task.wait(turnDelay)
			else
				local logMsg, didHit, shakeType = CombatCore.ExecuteStrike(raid.Boss, target, chosenSkill, "Body", raid.Boss.Name, target.Name, "#FF5555", "#FFFFFF")
				for _, p in ipairs(raid.Party) do
					if p.PlayerObj and p.PlayerObj.Parent then
						RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = shakeType, BossData = raid.Boss, SkillUsed = chosenSkill, Attacker = raid.Boss.Name, PartyData = raid.Party, Range = raid.Range })
					end
				end
				task.wait(turnDelay)
			end
		end
	end

	-- [[ NEW: Replaced local function with modular CombatCore.TickStatuses ]]
	for _, p in ipairs(raid.Party) do 
		if p.HP > 0 then 
			local dotDmg, dotLog = CombatCore.TickStatuses(p) 
			if dotDmg > 0 then p.HP -= dotDmg end

			if dotLog ~= "" and p.PlayerObj and p.PlayerObj.Parent then
				local logMsg = p.Name .. " took damage from status effects!" .. dotLog
				RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
			end
		end 
	end

	if raid.Boss.HP > 0 then
		local bDotDmg, bDotLog = CombatCore.TickStatuses(raid.Boss)
		if bDotDmg > 0 then raid.Boss.HP -= bDotDmg end

		if bDotLog ~= "" then
			local logMsg = raid.Boss.Name .. " took damage from status effects!" .. bDotLog
			for _, p in ipairs(raid.Party) do
				if p.PlayerObj and p.PlayerObj.Parent then
					RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
				end
			end
		end
	end

	-- Gate dissipation logic
	if raid.Boss.GateType == "Steam" and raid.Boss.GateHP <= 0 and not raid.Boss.GateBrokenFlag then
		raid.Boss.GateBrokenFlag = true -- Prevent spamming the message
		local logMsg = "<font color='#55FFFF'><b>The intense steam surrounding " .. raid.Boss.Name .. " has completely dissipated! The nape is exposed!</b></font>"
		for _, p in ipairs(raid.Party) do
			if p.PlayerObj and p.PlayerObj.Parent then
				RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
			end
		end
		task.wait(1.5)
	end

	if raid.Boss.HP <= 0 then EndRaid(raidId, true); return end

	local aliveCount = 0
	for _, p in ipairs(raid.Party) do if p.HP > 0 then aliveCount += 1 end end
	if aliveCount == 0 then EndRaid(raidId, false); return end

	for _, p in ipairs(raid.Party) do p.Move = nil end
	raid.Turn += 1
	raid.TurnEndTime = os.time() + TURN_DURATION
	raid.State = "WaitingForMoves"

	for _, p in ipairs(raid.Party) do
		if p.PlayerObj and p.PlayerObj.Parent then
			RaidUpdate:FireClient(p.PlayerObj, "NextTurnStarted", { EndTime = raid.TurnEndTime, BossData = raid.Boss, PartyData = raid.Party, Range = raid.Range })
		end
	end
end

task.spawn(function()
	while task.wait(1) do
		local now = os.time()
		for raidId, raid in pairs(ActiveRaids) do
			if raid.State == "WaitingForMoves" and now >= raid.TurnEndTime then
				for _, p in ipairs(raid.Party) do
					if p.HP > 0 and not p.Move then
						p.Move = (p.Statuses and p.Statuses["Transformed"]) and "Titan Punch" or "Basic Slash"
						p.TargetLimb = "Body"
					end
				end
				ResolveRaidTurn(raidId)
			end
		end
	end
end)

RaidAction.OnServerEvent:Connect(function(player, action, data)
	if action == "DeployParty" then
		local getPartyFunc = Network:FindFirstChild("GetPlayerParty")
		if not getPartyFunc then Network.NotificationEvent:FireClient(player, "Party System is still loading.", "Error"); return end

		local partyData = getPartyFunc:Invoke(player)
		if partyData.Leader.UserId ~= player.UserId then Network.NotificationEvent:FireClient(player, "Only the Party Leader can start the Raid.", "Error"); return end

		local bossData = EnemyData.RaidBosses[data.RaidId]
		if not bossData then return end

		local raidId = "Raid_" .. player.UserId .. "_" .. os.time()
		local memberCount = #partyData.Members
		local scale = 1 + ((memberCount - 1) * 0.3)
		local bMaxHP = math.floor(bossData.Health * scale)

		local ctxRange = "Close"
		if bossData.Name:find("Beast Titan") then ctxRange = "Long" end

		ActiveRaids[raidId] = {
			BossId = data.RaidId, Turn = 1, State = "WaitingForMoves", TurnEndTime = os.time() + TURN_DURATION, Party = {}, Range = ctxRange,
			Boss = { 
				IsPlayer = false, Name = bossData.Name, HP = bMaxHP, MaxHP = bMaxHP, 
				GateHP = bossData.GateHP, MaxGateHP = bossData.GateHP, GateType = bossData.GateType,
				TotalStrength = bossData.Strength, TotalDefense = bossData.Defense, TotalSpeed = bossData.Speed, 
				Skills = bossData.Skills, Statuses = {}, Cooldowns = {} 
			}
		}

		for _, member in ipairs(partyData.Members) do table.insert(ActiveRaids[raidId].Party, CreateCombatant(member)) end
		for _, member in ipairs(partyData.Members) do RaidUpdate:FireClient(member, "RaidStarted", { RaidId = raidId, BossData = ActiveRaids[raidId].Boss, PartyData = ActiveRaids[raidId].Party, EndTime = ActiveRaids[raidId].TurnEndTime, Range = ctxRange }) end

	elseif action == "SubmitMove" then
		local raidId = data.RaidId
		local raid = ActiveRaids[raidId]
		if not raid or raid.State ~= "WaitingForMoves" then return end

		local allReady = true
		for _, p in ipairs(raid.Party) do
			if p.UserId == player.UserId then p.Move = data.Move; p.TargetLimb = data.Limb or "Body" end
			if p.HP > 0 and not p.Move then allReady = false end
		end

		if allReady then ResolveRaidTurn(raidId) end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for raidId, raid in pairs(ActiveRaids) do
		for _, p in ipairs(raid.Party) do
			if p.UserId == player.UserId then
				p.HP = 0 
			end
		end
	end
end)