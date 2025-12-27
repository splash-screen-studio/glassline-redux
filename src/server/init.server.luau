--!strict
-- Glassline Server v2.1.0 - Continuous terrain, corridor cuts through landscape

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Calculate floor height at Z position (sine wave)
local function getFloorHeight(z: number): number
	return math.sin(z * Config.waveFrequency) * Config.waveAmplitude
end

-- Build obstacles (thin, on undulating floor, forgiving hitbox)
local function buildObstacles()
	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = workspace

	local z = Config.obstacleStartZ
	local count = 0
	local pillarHeight = 8
	local w = Config.obstacleWidth

	while z < Config.corridorLength - 50 do
		-- Random X position within corridor
		local xRange = Config.corridorWidth / 2 - 1
		local x = (math.random() * 2 - 1) * xRange

		-- Get floor height at this Z
		local floorY = getFloorHeight(z)

		-- Visible pillar (thin, non-collidable)
		local pillar = Instance.new("Part")
		pillar.Name = "Obstacle"
		pillar.Anchored = true
		pillar.CanCollide = false  -- Visual only
		pillar.Size = Vector3.new(w, pillarHeight, w)
		pillar.Position = Vector3.new(x, floorY + pillarHeight/2, z)
		pillar.Material = Enum.Material.Neon
		pillar.Color = Config.obstacleColor
		pillar.Parent = obstacles

		-- Smaller invisible hitbox (forgiving)
		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Anchored = true
		hitbox.CanCollide = false
		hitbox.Transparency = 1
		local shrink = Config.hitboxShrink
		hitbox.Size = Vector3.new(w - shrink, pillarHeight - 1, w - shrink)
		hitbox.Position = Vector3.new(x, floorY + pillarHeight/2, z)
		hitbox.Parent = pillar
		hitbox:SetAttribute("Deadly", true)

		count = count + 1
		z = z + Config.obstacleSpacing
	end

	print("[Server] Built " .. count .. " obstacles")
	return obstacles
end

-- Handle death (checks hitboxes inside obstacles)
local function setupDeathTouch(obstacles: Folder)
	for _, obstacle in obstacles:GetChildren() do
		-- Find hitbox child
		local hitbox = obstacle:FindFirstChild("Hitbox")
		if hitbox and hitbox:GetAttribute("Deadly") then
			hitbox.Touched:Connect(function(hit)
				local character = hit.Parent
				if not character then return end
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health > 0 then
					humanoid.Health = 0
				end
			end)
		end
	end
end

-- Scene themes (radically different)
local THEMES = {
	Enum.Material.Grass,      -- Green meadow
	Enum.Material.Snow,       -- Winter
	Enum.Material.Sand,       -- Desert
	Enum.Material.Rock,       -- Rocky
	Enum.Material.Mud,        -- Swamp
	Enum.Material.Ice,        -- Frozen
	Enum.Material.Limestone,  -- Pale cliffs
	Enum.Material.Basalt,     -- Dark volcanic
	Enum.Material.CrackedLava,-- Hellscape
	Enum.Material.Glacier,    -- Arctic
}

-- Get theme for a Z position (left and right always match)
local function getThemeAt(z: number): Enum.Material
	local zoneIndex = math.floor(z / Config.zoneLength) % #THEMES + 1
	return THEMES[zoneIndex]
end

-- Build the corridor cutting through continuous terrain
local function buildCorridor()
	local terrain = workspace.Terrain
	local corridor = Instance.new("Model")
	corridor.Name = "Corridor"

	local w = Config.corridorWidth
	local h = Config.corridorHeight
	local len = Config.corridorLength
	local sideWidth = Config.sideWidth

	-- Fill terrain using voxels for smooth undulations
	local resolution = 4  -- Terrain resolution

	-- Generate continuous terrain - corridor cuts through it
	for z = 0, len, resolution do
		-- Same height for corridor and sides (continuous terrain)
		local terrainY = getFloorHeight(z)
		local theme = getThemeAt(z)

		-- Corridor floor (dark matte Asphalt - the "road" through terrain)
		local corridorRegion = Region3.new(
			Vector3.new(-w/2, terrainY - 30, z),
			Vector3.new(w/2, terrainY, z + resolution)
		):ExpandToGrid(resolution)
		terrain:FillRegion(corridorRegion, resolution, Enum.Material.Asphalt)

		-- Left side terrain (same height as corridor - continuous surface)
		local leftRegion = Region3.new(
			Vector3.new(-w/2 - sideWidth, terrainY - 30, z),
			Vector3.new(-w/2 - 0.5, terrainY, z + resolution)
		):ExpandToGrid(resolution)
		terrain:FillRegion(leftRegion, resolution, theme)

		-- Right side terrain (exactly matches left - continuous surface)
		local rightRegion = Region3.new(
			Vector3.new(w/2 + 0.5, terrainY - 30, z),
			Vector3.new(w/2 + sideWidth, terrainY, z + resolution)
		):ExpandToGrid(resolution)
		terrain:FillRegion(rightRegion, resolution, theme)
	end

	-- Glass walls
	local wallHeight = h + Config.waveAmplitude * 2
	local wallY = Config.waveAmplitude

	local leftWall = Instance.new("Part")
	leftWall.Name = "LeftWall"
	leftWall.Anchored = true
	leftWall.Size = Vector3.new(0.5, wallHeight, len)
	leftWall.Position = Vector3.new(-w/2 - 0.25, wallY, len/2)
	leftWall.Material = Enum.Material.Glass
	leftWall.Color = Color3.fromRGB(200, 230, 255)
	leftWall.Transparency = 0.7
	leftWall.Parent = corridor

	local rightWall = Instance.new("Part")
	rightWall.Name = "RightWall"
	rightWall.Anchored = true
	rightWall.Size = Vector3.new(0.5, wallHeight, len)
	rightWall.Position = Vector3.new(w/2 + 0.25, wallY, len/2)
	rightWall.Material = Enum.Material.Glass
	rightWall.Color = Color3.fromRGB(200, 230, 255)
	rightWall.Transparency = 0.7
	rightWall.Parent = corridor

	-- Glass ceiling
	local ceilingFolder = Instance.new("Folder")
	ceilingFolder.Name = "Ceiling"
	ceilingFolder.Parent = corridor

	for z = 0, len, 20 do
		local y1 = getFloorHeight(z) + h
		local y2 = getFloorHeight(z + 20) + h
		local avgY = (y1 + y2) / 2
		local midZ = z + 10
		local angle = math.atan2(y2 - y1, 20)

		local ceilSeg = Instance.new("Part")
		ceilSeg.Name = "CeilingSegment"
		ceilSeg.Anchored = true
		ceilSeg.Size = Vector3.new(w + 1, 0.5, 21)
		ceilSeg.CFrame = CFrame.new(0, avgY, midZ) * CFrame.Angles(angle, 0, 0)
		ceilSeg.Material = Enum.Material.Glass
		ceilSeg.Color = Color3.fromRGB(200, 230, 255)
		ceilSeg.Transparency = 0.8
		ceilSeg.Parent = ceilingFolder
	end

	-- Water plane (continuous across corridor and sides)
	-- Only fills where terrain dips below water level
	terrain:FillRegion(
		Region3.new(
			Vector3.new(-w/2 - sideWidth, Config.waterLevel - 15, 0),
			Vector3.new(w/2 + sideWidth, Config.waterLevel, len)
		):ExpandToGrid(4),
		4,
		Enum.Material.Water
	)

	corridor.Parent = workspace

	-- Spawn room at corridor start (room behind Z=0, opens into corridor at +Z)
	local spawnRoom = Instance.new("Model")
	spawnRoom.Name = "SpawnRoom"

	local roomDepth = 15

	-- Back wall (behind player at negative Z)
	local backWall = Instance.new("Part")
	backWall.Name = "BackWall"
	backWall.Anchored = true
	backWall.Size = Vector3.new(w + 2, h, 1)
	backWall.Position = Vector3.new(0, h/2, -roomDepth)
	backWall.Material = Enum.Material.SmoothPlastic
	backWall.Color = Color3.fromRGB(40, 40, 45)
	backWall.Parent = spawnRoom

	-- Left side wall (from back wall to corridor start)
	local leftBlock = Instance.new("Part")
	leftBlock.Name = "LeftBlock"
	leftBlock.Anchored = true
	leftBlock.Size = Vector3.new(1, h, roomDepth)
	leftBlock.Position = Vector3.new(-w/2 - 0.5, h/2, -roomDepth/2)
	leftBlock.Material = Enum.Material.SmoothPlastic
	leftBlock.Color = Color3.fromRGB(40, 40, 45)
	leftBlock.Parent = spawnRoom

	-- Right side wall (from back wall to corridor start)
	local rightBlock = Instance.new("Part")
	rightBlock.Name = "RightBlock"
	rightBlock.Anchored = true
	rightBlock.Size = Vector3.new(1, h, roomDepth)
	rightBlock.Position = Vector3.new(w/2 + 0.5, h/2, -roomDepth/2)
	rightBlock.Material = Enum.Material.SmoothPlastic
	rightBlock.Color = Color3.fromRGB(40, 40, 45)
	rightBlock.Parent = spawnRoom

	-- Floor for spawn room
	local spawnFloor = Instance.new("Part")
	spawnFloor.Name = "SpawnFloor"
	spawnFloor.Anchored = true
	spawnFloor.Size = Vector3.new(w, 1, roomDepth)
	spawnFloor.Position = Vector3.new(0, -0.5, -roomDepth/2)
	spawnFloor.Material = Enum.Material.SmoothPlastic
	spawnFloor.Color = Color3.fromRGB(35, 35, 40)
	spawnFloor.Parent = spawnRoom

	spawnRoom.Parent = workspace

	-- Spawn location (in room, facing +Z into corridor)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.5, -roomDepth/2) * CFrame.Angles(0, math.pi, 0)
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = workspace

	print("[Server] Corridor built: " .. len .. " studs")
end

-- Spawn position and direction (lookAt is foolproof)
local SPAWN_POS = Vector3.new(0, 3, -7)
local LOOK_AT = Vector3.new(0, 3, 100)  -- Look down the corridor (+Z)
local SPAWN_CFRAME = CFrame.lookAt(SPAWN_POS, LOOK_AT)

-- Fast player setup
local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")

		-- Force exact spawn position and orientation
		hrp.CFrame = SPAWN_CFRAME

		humanoid.WalkSpeed = Config.runSpeed
		humanoid.JumpPower = Config.jumpPower

		print("[Server] " .. player.Name .. " spawned facing +Z")
	end)
end

-- Init
buildCorridor()
local obstacles = buildObstacles()
setupDeathTouch(obstacles)

Players.RespawnTime = 0.5
Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

print("[Glassline] Ready - just run!")
