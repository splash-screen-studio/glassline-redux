--!strict
-- Config v2.6.0 - Longer corridor, more variety

return {
	-- Corridor
	corridorWidth = 8,        -- Slightly wider for comfort
	corridorHeight = 30,      -- Taller for undulations
	corridorLength = 5000,    -- Longer for variety

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
	waveAmplitude = 25,       -- How high/low the terrain goes (bigger for underwater)
	waveFrequency = 0.002,    -- Even slower waves
	waterLevel = 0,           -- Y=0 is water level (terrain dips below)

	-- Scene themes (left and right always identical - continuous terrain)
	zoneLength = 300,         -- How often themes change
	sideWidth = 120,          -- Terrain width on each side
}
