--!strict
-- Glassline Server v2.11.0 - Water stays outside glass walls

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsService = game:GetService("PhysicsService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Collision groups for test mode pass-through
PhysicsService:RegisterCollisionGroup("Obstacles")
PhysicsService:RegisterCollisionGroup("TestModePlayers")
PhysicsService:CollisionGroupSetCollidable("Obstacles", "TestModePlayers", false)

-- Per-player mode (randomized on each respawn)
local playerModes: { [Player]: boolean } = {}  -- true = test mode, false = normal

--[[
	ZONE FRAMEWORK - Single source of truth for all boundaries

	Zone Layout (Z axis):
	Z < -15      : VOID (behind back wall, nothing here)
	Z = -15 to 0 : SPAWN ZONE - flat floor at Y=0, Part-based walls
	Z = 0 to 100 : TRANSITION ZONE - floor blends from Y=0 to wave, no side terrain
	Z > 100      : GAME ZONE - full wave terrain, side terrain, water, obstacles
]]
local ZONES = {
	SPAWN_START = -15,      -- Back wall of spawn room
	SPAWN_END = 0,          -- Where spawn room opens to corridor
	TRANSITION_END = 100,   -- Where full wave terrain begins
	SPAWN_FLOOR_Y = 0,      -- Spawn room floor height (top surface)
}

-- Calculate raw wave height (before zone blending)
local function getRawWaveHeight(z: number): number
	local mainWave = math.sin(z * Config.waveFrequency) * Config.waveAmplitude
	local secondWave = math.sin(z * Config.waveFrequency * 2.7) * (Config.waveAmplitude * 0.3)
	local thirdWave = math.cos(z * Config.waveFrequency * 0.5) * (Config.waveAmplitude * 0.5)
	return mainWave + secondWave + thirdWave
end

-- Calculate corridor floor height with zone blending
local function getFloorHeight(z: number): number
	if z <= ZONES.SPAWN_END then
		-- Spawn zone: flat at spawn floor level
		return ZONES.SPAWN_FLOOR_Y
	elseif z <= ZONES.TRANSITION_END then
		-- Transition zone: blend from spawn floor to wave height
		local t = (z - ZONES.SPAWN_END) / (ZONES.TRANSITION_END - ZONES.SPAWN_END)
		local waveHeight = getRawWaveHeight(z)
		return ZONES.SPAWN_FLOOR_Y + (waveHeight - ZONES.SPAWN_FLOOR_Y) * t
	else
		-- Game zone: full wave
		return getRawWaveHeight(z)
	end
end

-- Calculate side terrain height (locked at wall, undulates outward)
local function getSideTerrainHeight(z: number, distFromWall: number): number
	local baseHeight = getFloorHeight(z)  -- Locked to corridor at wall

	-- Add variety based on distance from wall
	-- Multiple wave frequencies for natural look
	local wave1 = math.sin(z * 0.01 + distFromWall * 0.05) * (distFromWall * 0.3)
	local wave2 = math.sin(z * 0.025 + distFromWall * 0.08) * (distFromWall * 0.15)
	local wave3 = math.cos(z * 0.007) * (distFromWall * 0.2)

	return baseHeight + wave1 + wave2 + wave3
end

-- Build obstacles (thin, on undulating floor, forgiving hitbox)
-- Obstacles only appear in GAME ZONE (after TRANSITION_END)
local function buildObstacles()
	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = workspace

	local z = ZONES.TRANSITION_END  -- Obstacles start in game zone
	local count = 0
	local pillarHeight = 8
	local w = Config.obstacleWidth

	while z < Config.corridorLength - 50 do
		-- Random X position within corridor
		local xRange = Config.corridorWidth / 2 - 1
		local x = (math.random() * 2 - 1) * xRange

		-- Get floor height at this Z
		local floorY = getFloorHeight(z)

		-- Visible pillar (solid obstacle)
		local pillar = Instance.new("Part")
		pillar.Name = "Obstacle"
		pillar.Anchored = true
		pillar.CanCollide = true  -- Solid - must dodge
		pillar.CollisionGroup = "Obstacles"
		pillar.Size = Vector3.new(w, pillarHeight, w)
		pillar.Position = Vector3.new(x, floorY + pillarHeight/2, z)
		pillar.Material = Enum.Material.Neon
		pillar.Color = Config.obstacleColor
		pillar:SetAttribute("Deadly", true)
		pillar.Parent = obstacles

		count = count + 1
		z = z + Config.obstacleSpacing
	end

	print("[Server] Built " .. count .. " obstacles")
	return obstacles
end

-- Handle death (obstacle touch)
local function setupDeathTouch(obstacles: Folder)
	for _, obstacle in obstacles:GetChildren() do
		if obstacle:GetAttribute("Deadly") then
			obstacle.Touched:Connect(function(hit)
				local character = hit.Parent
				if not character then return end

				local player = Players:GetPlayerFromCharacter(character)
				if player and playerModes[player] then return end  -- Test mode = no death

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

	-- Generate terrain using ZONES framework
	local stripWidth = 12  -- Width of each terrain strip

	-- Corridor floor starts at spawn room exit (Z=0) - spawn room has Part floor
	-- Transition zone (0 to TRANSITION_END): only corridor floor, no side terrain
	-- Game zone (TRANSITION_END+): full corridor + side terrain

	for z = ZONES.SPAWN_END, len, resolution do
		local corridorY = getFloorHeight(z)
		local theme = getThemeAt(z)

		-- Corridor floor (dark matte Asphalt - the "road" through terrain)
		local corridorRegion = Region3.new(
			Vector3.new(-w/2, corridorY - 40, z),
			Vector3.new(w/2, corridorY, z + resolution)
		):ExpandToGrid(resolution)
		terrain:FillRegion(corridorRegion, resolution, Enum.Material.Asphalt)

		-- Side terrain only in GAME ZONE (after transition)
		if z >= ZONES.TRANSITION_END then
			-- Side terrain in strips (height varies with distance from wall)
			for stripStart = 0, sideWidth - stripWidth, stripWidth do
				local distFromWall = stripStart + stripWidth / 2
				local stripY = getSideTerrainHeight(z, distFromWall)

				-- Left side strip (going outward from wall)
				local leftX1 = -w/2 - stripStart - stripWidth
				local leftX2 = -w/2 - stripStart
				local leftRegion = Region3.new(
					Vector3.new(leftX1, stripY - 40, z),
					Vector3.new(leftX2, stripY, z + resolution)
				):ExpandToGrid(resolution)
				terrain:FillRegion(leftRegion, resolution, theme)

				-- Right side strip (mirrors left exactly)
				local rightX1 = w/2 + stripStart
				local rightX2 = w/2 + stripStart + stripWidth
				local rightRegion = Region3.new(
					Vector3.new(rightX1, stripY - 40, z),
					Vector3.new(rightX2, stripY, z + resolution)
				):ExpandToGrid(resolution)
				terrain:FillRegion(rightRegion, resolution, theme)
			end
		end
	end

	-- Glass walls (segmented - Roblox max part size is 2048 studs)
	-- Must cover full height range: from lowest floor to ceiling
	local lowestFloor = -Config.waveAmplitude
	local highestCeiling = Config.waveAmplitude + h
	local wallHeight = highestCeiling - lowestFloor + 20  -- Extra margin
	local wallY = (lowestFloor + highestCeiling) / 2  -- Center of wall

	local MAX_SEGMENT = 2000  -- Stay under Roblox's 2048 limit
	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "Walls"
	wallFolder.Parent = corridor

	for segStart = ZONES.SPAWN_END, len, MAX_SEGMENT do
		local segEnd = math.min(segStart + MAX_SEGMENT, len)
		local segLen = segEnd - segStart
		local segMidZ = segStart + segLen / 2

		-- Left wall segment
		local leftSeg = Instance.new("Part")
		leftSeg.Name = "LeftWall_" .. segStart
		leftSeg.Anchored = true
		leftSeg.Size = Vector3.new(0.5, wallHeight, segLen)
		leftSeg.Position = Vector3.new(-w/2 - 0.25, wallY, segMidZ)
		leftSeg.Material = Enum.Material.Glass
		leftSeg.Color = Color3.fromRGB(200, 230, 255)
		leftSeg.Transparency = 0.7
		leftSeg.Parent = wallFolder

		-- Right wall segment
		local rightSeg = Instance.new("Part")
		rightSeg.Name = "RightWall_" .. segStart
		rightSeg.Anchored = true
		rightSeg.Size = Vector3.new(0.5, wallHeight, segLen)
		rightSeg.Position = Vector3.new(w/2 + 0.25, wallY, segMidZ)
		rightSeg.Material = Enum.Material.Glass
		rightSeg.Color = Color3.fromRGB(200, 230, 255)
		rightSeg.Transparency = 0.7
		rightSeg.Parent = wallFolder
	end

	-- Glass ceiling (starts at SPAWN_END where corridor begins)
	local ceilingFolder = Instance.new("Folder")
	ceilingFolder.Name = "Ceiling"
	ceilingFolder.Parent = corridor

	for z = ZONES.SPAWN_END, len, 20 do
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

	-- Water (outside corridor only - must not penetrate glass walls)
	-- Glass walls are at X = ±(w/2 + 0.25), thickness 0.5
	-- Water must stop outside the glass: at least 1 stud margin for terrain voxels
	local waterDepth = 25
	local waterMargin = 1  -- Keep water 1 stud outside glass wall
	local waterInnerX = w/2 + 0.5 + waterMargin  -- Glass outer edge + margin

	-- Left side water
	terrain:FillRegion(
		Region3.new(
			Vector3.new(-w/2 - sideWidth, Config.waterLevel - waterDepth, ZONES.TRANSITION_END),
			Vector3.new(-waterInnerX, Config.waterLevel, len)
		):ExpandToGrid(4),
		4,
		Enum.Material.Water
	)
	-- Right side water
	terrain:FillRegion(
		Region3.new(
			Vector3.new(waterInnerX, Config.waterLevel - waterDepth, ZONES.TRANSITION_END),
			Vector3.new(w/2 + sideWidth, Config.waterLevel, len)
		):ExpandToGrid(4),
		4,
		Enum.Material.Water
	)

	-- ROBUST: Clear any terrain that leaked into corridor interior
	-- This ensures water/terrain never appears inside the glass walls
	terrain:FillRegion(
		Region3.new(
			Vector3.new(-w/2, -50, ZONES.SPAWN_END),
			Vector3.new(w/2, Config.waterLevel + 10, len)
		):ExpandToGrid(4),
		4,
		Enum.Material.Air
	)
	-- Then re-fill the corridor floor (which we just cleared above water level)
	for z = ZONES.SPAWN_END, len, resolution do
		local corridorY = getFloorHeight(z)
		local corridorRegion = Region3.new(
			Vector3.new(-w/2, corridorY - 40, z),
			Vector3.new(w/2, corridorY, z + resolution)
		):ExpandToGrid(resolution)
		terrain:FillRegion(corridorRegion, resolution, Enum.Material.Asphalt)
	end

	corridor.Parent = workspace

	-- Spawn room using ZONES framework
	local spawnRoom = Instance.new("Model")
	spawnRoom.Name = "SpawnRoom"

	local roomDepth = ZONES.SPAWN_END - ZONES.SPAWN_START  -- 15 studs
	local roomMidZ = (ZONES.SPAWN_START + ZONES.SPAWN_END) / 2  -- -7.5

	-- Back wall (at SPAWN_START)
	local backWall = Instance.new("Part")
	backWall.Name = "BackWall"
	backWall.Anchored = true
	backWall.Size = Vector3.new(w + 2, h, 1)
	backWall.Position = Vector3.new(0, h/2 + ZONES.SPAWN_FLOOR_Y, ZONES.SPAWN_START)
	backWall.Material = Enum.Material.SmoothPlastic
	backWall.Color = Color3.fromRGB(40, 40, 45)
	backWall.Parent = spawnRoom

	-- Left side wall (from SPAWN_START to SPAWN_END)
	local leftBlock = Instance.new("Part")
	leftBlock.Name = "LeftBlock"
	leftBlock.Anchored = true
	leftBlock.Size = Vector3.new(1, h, roomDepth)
	leftBlock.Position = Vector3.new(-w/2 - 0.5, h/2 + ZONES.SPAWN_FLOOR_Y, roomMidZ)
	leftBlock.Material = Enum.Material.SmoothPlastic
	leftBlock.Color = Color3.fromRGB(40, 40, 45)
	leftBlock.Parent = spawnRoom

	-- Right side wall (from SPAWN_START to SPAWN_END)
	local rightBlock = Instance.new("Part")
	rightBlock.Name = "RightBlock"
	rightBlock.Anchored = true
	rightBlock.Size = Vector3.new(1, h, roomDepth)
	rightBlock.Position = Vector3.new(w/2 + 0.5, h/2 + ZONES.SPAWN_FLOOR_Y, roomMidZ)
	rightBlock.Material = Enum.Material.SmoothPlastic
	rightBlock.Color = Color3.fromRGB(40, 40, 45)
	rightBlock.Parent = spawnRoom

	-- Floor for spawn room (top surface at SPAWN_FLOOR_Y)
	local spawnFloor = Instance.new("Part")
	spawnFloor.Name = "SpawnFloor"
	spawnFloor.Anchored = true
	spawnFloor.Size = Vector3.new(w, 1, roomDepth)
	spawnFloor.Position = Vector3.new(0, ZONES.SPAWN_FLOOR_Y - 0.5, roomMidZ)
	spawnFloor.Material = Enum.Material.SmoothPlastic
	spawnFloor.Color = Color3.fromRGB(35, 35, 40)
	spawnFloor.Parent = spawnRoom

	spawnRoom.Parent = workspace

	-- Spawn location (in spawn room, facing +Z into corridor)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, ZONES.SPAWN_FLOOR_Y + 0.5, roomMidZ) * CFrame.Angles(0, math.pi, 0)
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = workspace

	print("[Server] Corridor built: " .. len .. " studs")
end

-- Spawn position and direction using ZONES (lookAt is foolproof)
local SPAWN_POS = Vector3.new(0, ZONES.SPAWN_FLOOR_Y + 3, (ZONES.SPAWN_START + ZONES.SPAWN_END) / 2)
local LOOK_AT = Vector3.new(0, ZONES.SPAWN_FLOOR_Y + 3, ZONES.TRANSITION_END)  -- Look down the corridor (+Z)
local SPAWN_CFRAME = CFrame.lookAt(SPAWN_POS, LOOK_AT)

-- Set collision group for all character parts
local function setCharacterCollisionGroup(character: Model, groupName: string)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
	end
end

-- Fast player setup
local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")

		-- Randomize mode on each respawn
		playerModes[player] = math.random() > 0.5
		local isTestMode = playerModes[player]
		local mode = isTestMode and "TEST" or "NORMAL"
		print("[Server] " .. player.Name .. " respawned in " .. mode .. " mode")

		-- Set collision group based on mode
		if isTestMode then
			setCharacterCollisionGroup(character, "TestModePlayers")
		end

		-- Force exact spawn position and orientation
		hrp.CFrame = SPAWN_CFRAME

		humanoid.WalkSpeed = Config.runSpeed
		humanoid.JumpPower = Config.jumpPower
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
