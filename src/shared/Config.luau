--!strict
-- Config v2.1.0 - Slower undulations, continuous terrain through corridor

return {
	-- Corridor
	corridorWidth = 8,        -- Slightly wider for comfort
	corridorHeight = 30,      -- Taller for undulations
	corridorLength = 2000,    -- Start shorter for testing

	-- Movement (FAST)
	runSpeed = 100,           -- Very fast
	jumpPower = 60,           -- Snappy jump

	-- Obstacles
	obstacleStartZ = 100,     -- Clear zone before first obstacle
	obstacleSpacing = 50,     -- Studs between obstacles
	obstacleColor = Color3.fromRGB(255, 50, 50),  -- Red = danger
	obstacleWidth = 0.6,      -- Thin pillars (was 1.5)
	hitboxShrink = 0.3,       -- Shrink hitbox for forgiving collision

	-- Terrain undulation (slower, gentler waves)
	segmentLength = 20,       -- Length of each floor segment
	waveAmplitude = 20,       -- How high/low the terrain goes
	waveFrequency = 0.003,    -- Slower waves (was 0.008)
	waterLevel = -8,          -- Y level where water exists

	-- Scene themes (left and right always identical - continuous terrain)
	zoneLength = 300,         -- How often themes change
	sideWidth = 120,          -- Terrain width on each side
}
