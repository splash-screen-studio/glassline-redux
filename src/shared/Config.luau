--!strict
-- Config v2.0.0 - Core gameplay config with terrain undulation and themed zones

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

	-- Terrain undulation
	segmentLength = 20,       -- Length of each floor segment
	waveAmplitude = 15,       -- How high/low the floor goes
	waveFrequency = 0.008,    -- How often waves occur (lower = longer waves)
	waterLevel = -5,          -- Y level where water starts

	-- Scene themes (left and right match, change every zoneLength)
	zoneLength = 200,         -- How often themes change
	sideWidth = 100,          -- Terrain width on each side
}
