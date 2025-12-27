--!strict
-- Glassline Server v2.16.0 - Altitude-based terrain + dual water system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsService = game:GetService("PhysicsService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Collision group for obstacles (used for collision detection)
PhysicsService:RegisterCollisionGroup("Obstacles")

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

-- Zone palettes: each zone has materials for different altitudes
-- Progresses from realistic natural scenes to bizarre alien landscapes
local ZONE_PALETTES = {
	-- REALISTIC NATURE (zones 1-4)
	{ low = Enum.Material.Grass, mid = Enum.Material.Rock, high = Enum.Material.Snow },
	{ low = Enum.Material.LeafyGrass, mid = Enum.Material.Slate, high = Enum.Material.Snow },
	{ low = Enum.Material.Ground, mid = Enum.Material.Rock, high = Enum.Material.Ice },
	{ low = Enum.Material.Sand, mid = Enum.Material.Sandstone, high = Enum.Material.Snow },

	-- HARSHER ENVIRONMENTS (zones 5-8)
	{ low = Enum.Material.Mud, mid = Enum.Material.Rock, high = Enum.Material.Slate },
	{ low = Enum.Material.Ground, mid = Enum.Material.Slate, high = Enum.Material.Ice },
	{ low = Enum.Material.Snow, mid = Enum.Material.Ice, high = Enum.Material.Glacier },
	{ low = Enum.Material.Ice, mid = Enum.Material.Glacier, high = Enum.Material.Snow },

	-- STRANGE (zones 9-12)
	{ low = Enum.Material.Mud, mid = Enum.Material.Limestone, high = Enum.Material.Salt },
	{ low = Enum.Material.Limestone, mid = Enum.Material.Sandstone, high = Enum.Material.Salt },
	{ low = Enum.Material.Sandstone, mid = Enum.Material.Salt, high = Enum.Material.Limestone },
	{ low = Enum.Material.Salt, mid = Enum.Material.Glacier, high = Enum.Material.Ice },

	-- ALIEN/HELLSCAPE (zones 13-16)
	{ low = Enum.Material.Basalt, mid = Enum.Material.Slate, high = Enum.Material.Glacier },
	{ low = Enum.Material.Basalt, mid = Enum.Material.CrackedLava, high = Enum.Material.Slate },
	{ low = Enum.Material.CrackedLava, mid = Enum.Material.Basalt, high = Enum.Material.Slate },
	{ low = Enum.Material.CrackedLava, mid = Enum.Material.CrackedLava, high = Enum.Material.Basalt },
}

-- Altitude thresholds for material selection
local ALTITUDE = {
	waterLevel = Config.waterLevel,  -- Below this = Water
	lowToMid = 5,                    -- Below this = low material
	midToHigh = 15,                  -- Below this = mid material, above = high
}

-- Get material based on zone (Z) and altitude (Y)
local function getMaterialAt(z: number, y: number): Enum.Material
	-- Below water level = terrain water
	if y < ALTITUDE.waterLevel then
		return Enum.Material.Water
	end

	-- Get zone palette (progresses, doesn't cycle)
	local zoneIndex = math.floor(z / Config.zoneLength) + 1
	zoneIndex = math.min(zoneIndex, #ZONE_PALETTES)
	local palette = ZONE_PALETTES[zoneIndex]

	-- Select material based on altitude
	if y < ALTITUDE.lowToMid then
		return palette.low
	elseif y < ALTITUDE.midToHigh then
		return palette.mid
	else
		return palette.high
	end
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

				-- Get material based on altitude (snow high, grass low, water underwater)
				local material = getMaterialAt(z, stripY)

				-- Left side strip (going outward from wall)
				local leftX1 = -w/2 - stripStart - stripWidth
				local leftX2 = -w/2 - stripStart
				local leftRegion = Region3.new(
					Vector3.new(leftX1, stripY - 40, z),
					Vector3.new(leftX2, stripY, z + resolution)
				):ExpandToGrid(resolution)
				terrain:FillRegion(leftRegion, resolution, material)

				-- Right side strip (mirrors left exactly)
				local rightX1 = w/2 + stripStart
				local rightX2 = w/2 + stripStart + stripWidth
				local rightRegion = Region3.new(
					Vector3.new(rightX1, stripY - 40, z),
					Vector3.new(rightX2, stripY, z + resolution)
				):ExpandToGrid(resolution)
				terrain:FillRegion(rightRegion, resolution, material)
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

	-- UNDERWATER CORRIDOR SECTIONS (Part-based water inside corridor)
	-- When corridor floor dips below water level, fill that section with water Part
	-- Player runs through it (visual only, no swimming)
	local underwaterFolder = Instance.new("Folder")
	underwaterFolder.Name = "UnderwaterSections"
	underwaterFolder.Parent = corridor

	local waterColor = Color3.fromRGB(30, 100, 180)
	local waterTransparency = 0.4

	-- Scan corridor for underwater sections
	local underwaterStart = nil
	for z = ZONES.TRANSITION_END, len, resolution do
		local floorY = getFloorHeight(z)
		local isUnderwater = floorY < Config.waterLevel

		if isUnderwater and not underwaterStart then
			-- Start of underwater section
			underwaterStart = z
		elseif not isUnderwater and underwaterStart then
			-- End of underwater section - create water Part
			local sectionLen = z - underwaterStart
			local midZ = underwaterStart + sectionLen / 2
			local waterHeight = Config.waterLevel - getFloorHeight(midZ) + 5  -- Extend above surface

			local waterPart = Instance.new("Part")
			waterPart.Name = "UnderwaterSection_" .. underwaterStart
			waterPart.Anchored = true
			waterPart.CanCollide = false
			waterPart.Size = Vector3.new(w - 0.5, waterHeight, sectionLen)
			waterPart.Position = Vector3.new(0, Config.waterLevel - waterHeight/2 + 2, midZ)
			waterPart.Material = Enum.Material.Glass
			waterPart.Color = waterColor
			waterPart.Transparency = waterTransparency
			waterPart.Parent = underwaterFolder

			underwaterStart = nil
		end
	end

	-- Handle case where corridor ends while still underwater
	if underwaterStart then
		local sectionLen = len - underwaterStart
		local midZ = underwaterStart + sectionLen / 2
		local waterHeight = Config.waterLevel - getFloorHeight(midZ) + 5

		local waterPart = Instance.new("Part")
		waterPart.Name = "UnderwaterSection_" .. underwaterStart
		waterPart.Anchored = true
		waterPart.CanCollide = false
		waterPart.Size = Vector3.new(w - 0.5, waterHeight, sectionLen)
		waterPart.Position = Vector3.new(0, Config.waterLevel - waterHeight/2 + 2, midZ)
		waterPart.Material = Enum.Material.Glass
		waterPart.Color = waterColor
		waterPart.Transparency = waterTransparency
		waterPart.Parent = underwaterFolder
	end

	-- NOTE: Terrain water for outside pools is handled by getMaterialAt()
	-- returning Water material for terrain below waterLevel

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

	-- Bridge floor: covers spawn-to-corridor transition
	-- Terrain voxels may not align perfectly, this Part guarantees no gap
	local bridgeLength = 20  -- Covers Z=0 to Z=20
	local bridgeFloor = Instance.new("Part")
	bridgeFloor.Name = "BridgeFloor"
	bridgeFloor.Anchored = true
	bridgeFloor.Size = Vector3.new(w, 1, bridgeLength)
	bridgeFloor.Position = Vector3.new(0, ZONES.SPAWN_FLOOR_Y - 0.5, bridgeLength / 2)
	bridgeFloor.Material = Enum.Material.SmoothPlastic
	bridgeFloor.Color = Color3.fromRGB(35, 35, 40)
	bridgeFloor.Parent = workspace

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

-- Fast player setup
local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		local hrp = character:WaitForChild("HumanoidRootPart")

		-- Randomize mode on each respawn (70% test mode for easier testing)
		playerModes[player] = math.random() < 0.7
		local isTestMode = playerModes[player]
		local mode = isTestMode and "TEST (no death)" or "NORMAL (deadly)"
		print("[Server] " .. player.Name .. " spawned in " .. mode .. " mode")

		-- Test mode: collide with obstacles but don't die
		-- (Death prevention is handled in setupDeathTouch via playerModes check)
		-- No collision group change needed - we WANT collision, just no death

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
