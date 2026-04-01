-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local UIAuraManager = {}

local RunService = game:GetService("RunService")

local activeConnection = nil
local activeParticles = {}
local ambientGlow = nil

local activeStroke = nil
local originalStrokeColor = nil

-- [[ NEW: Advanced Particle Texture Pool ]]
-- Supports mixing standard static particles with animated Sprite Sheet (Flipbook) particles!
local PARTICLE_TEXTURES = {
	{ Image = "rbxassetid://101919176010049", Type = "Static" }, -- Soft Glow (Original)
	{ Image = "rbxassetid://116532017229569", Type = "Static" }, -- Bright Flare
	{ Image = "rbxassetid://91391658964497", Type = "Static" },  -- Small Sparkle
	{ Image = "rbxassetid://14364658838", Type = "Static" },     -- Diamond Star
	{ Image = "rbxassetid://893043860", Type = "Static" },       -- Soft Cross Glow

	-- YOUR ANIMATED FLIPBOOK:
	-- If it looks chopped up, change Cols/Rows to 4, 5, or 6. 
	-- If it looks blurry/off-center, change ImgSize to 512 or 2048.
	{ 
		Image = "rbxassetid://17863940342", 
		Type = "Animated", 
		Cols = 8, 
		Rows = 8, 
		Frames = 64, 
		FPS = 4, 
		ImgSize = 1024 
	}
}

function UIAuraManager.ApplyAura(container, auraData, strokeContainer)
	UIAuraManager.ClearAura()
	if not auraData or auraData.Name == "None" then return end

	local c1 = Color3.fromHex((auraData.Color1 or "#FFFFFF"):gsub("#", ""))
	local c2 = Color3.fromHex((auraData.Color2 or "#FFFFFF"):gsub("#", ""))

	local target = strokeContainer or container
	activeStroke = target:FindFirstChildOfClass("UIStroke")
	if activeStroke then
		originalStrokeColor = activeStroke.Color
		activeStroke.Color = c1
	end

	-- 1. Create a deep, breathing ambient glow ring
	ambientGlow = Instance.new("ImageLabel", container)
	ambientGlow.Size = UDim2.new(1.15, 0, 1.15, 0)
	ambientGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
	ambientGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	ambientGlow.BackgroundTransparency = 1
	ambientGlow.Image = "rbxassetid://2001828033" -- Soft glowing ring
	ambientGlow.ImageColor3 = c1
	ambientGlow.ImageTransparency = 0.2
	ambientGlow.ZIndex = 1

	local rot = 0
	local lastSpawn = 0
	local timeElapsed = 0

	-- 2. Run the internal particle engine
	activeConnection = RunService.RenderStepped:Connect(function(dt)
		timeElapsed = timeElapsed + dt
		rot = (rot + dt * 45) % 360
		if ambientGlow then ambientGlow.Rotation = rot end

		-- Make the profile ring smoothly pulse between the two aura colors
		if activeStroke then
			local pulse = (math.sin(timeElapsed * 3) + 1) / 2
			activeStroke.Color = c1:Lerp(c2, pulse)
		end

		-- Spawn new particles
		local now = tick()
		if now - lastSpawn > 0.05 then
			lastSpawn = now

			local p = Instance.new("ImageLabel", container)
			p.BackgroundTransparency = 1
			p.ImageColor3 = math.random() > 0.5 and c1 or c2
			p.ZIndex = 2

			-- [[ NEW: Apply Texture & Setup Flipbook Data if Animated ]]
			local texData = PARTICLE_TEXTURES[math.random(1, #PARTICLE_TEXTURES)]
			p.Image = texData.Image

			if texData.Type == "Animated" then
				local fw = texData.ImgSize / texData.Cols
				local fh = texData.ImgSize / texData.Rows
				p.ImageRectSize = Vector2.new(fw, fh)
				p.ImageRectOffset = Vector2.new(0, 0)
			end

			local angle = math.rad(math.random(0, 360))
			-- Spawn them in a ring pattern around the avatar
			local radius = (container.AbsoluteSize.X * 0.45) 
			local px = 0.5 + (math.cos(angle) * radius) / math.max(1, container.AbsoluteSize.X)
			local py = 0.5 + (math.sin(angle) * radius) / math.max(1, container.AbsoluteSize.Y)

			p.Position = UDim2.new(px, 0, py, 0)
			p.AnchorPoint = Vector2.new(0.5, 0.5)

			local size = math.random(15, 45)
			p.Size = UDim2.new(0, size, 0, size)

			-- Store particle state, including animation tracking
			table.insert(activeParticles, {
				el = p,
				life = 1.5,
				maxLife = 1.5,
				vx = (math.random() - 0.5) * 0.1,
				vy = -math.random(1, 6) * 0.1, -- Float up dynamically
				rot = math.random(-60, 60),
				isAnimated = texData.Type == "Animated",
				texData = texData,
				currentFrame = 0,
				timeAccumulator = 0
			})
		end

		-- Update existing particles
		for i = #activeParticles, 1, -1 do
			local pd = activeParticles[i]
			pd.life = pd.life - dt

			if pd.life <= 0 then
				if pd.el then pd.el:Destroy() end
				table.remove(activeParticles, i)
			else
				local prog = 1 - (pd.life / pd.maxLife)
				pd.el.Position = pd.el.Position + UDim2.new(pd.vx * dt, 0, pd.vy * dt, 0)
				pd.el.Rotation = pd.el.Rotation + (pd.rot * dt)
				pd.el.ImageTransparency = prog -- Fade out as they float

				-- [[ NEW: Animate the Sprite Sheet frames ]]
				if pd.isAnimated then
					pd.timeAccumulator = pd.timeAccumulator + dt
					local frameTime = 1 / pd.texData.FPS

					if pd.timeAccumulator >= frameTime then
						pd.timeAccumulator = pd.timeAccumulator % frameTime
						pd.currentFrame = (pd.currentFrame + 1) % pd.texData.Frames

						local col = pd.currentFrame % pd.texData.Cols
						local row = math.floor(pd.currentFrame / pd.texData.Cols)
						local fw = pd.texData.ImgSize / pd.texData.Cols
						local fh = pd.texData.ImgSize / pd.texData.Rows

						pd.el.ImageRectOffset = Vector2.new(col * fw, row * fh)
					end
				end
			end
		end
	end)
end

function UIAuraManager.ClearAura()
	if activeConnection then activeConnection:Disconnect(); activeConnection = nil end
	if ambientGlow then ambientGlow:Destroy(); ambientGlow = nil end

	-- Revert the ring back to gray when the aura is removed
	if activeStroke and originalStrokeColor then
		activeStroke.Color = originalStrokeColor
		activeStroke = nil
		originalStrokeColor = nil
	end

	for _, p in ipairs(activeParticles) do if p.el then p.el:Destroy() end end
	activeParticles = {}
end

return UIAuraManager