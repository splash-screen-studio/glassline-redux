# Glassline - Development Guide

A fast-paced runner game through a narrow glass corridor with radically shifting scenery.

## Game Concept

**Core Loop**: Run through a long glass corridor, avoid obstacles, accumulate lifetime points.

- **Corridor**: Single avatar width, tall glass ceiling, glass side walls, very long straight shot
- **Death**: Touch any obstacle = instant death, respawn at start
- **Scoring**: Forward state (1x points), Backward state after reaching end (2x points)
- **End Zone**: Opens to narrow side exploration areas (no points), teleport back resets to forward state
- **Multiplayer**: Ghost mode (see others, no collision)
- **Vehicles**: Appear mid-run with different handling
- **Progressive Difficulty**: Harder the further you go
- **Visuals**: Radically shifting scenery outside glass (realistic, surreal, dreamy, scary, girly, etc.)

---

## Game Modes

### Ranked Mode (Default)
The competitive mode where players earn lifetime points and compete on the leaderboard.

- **Predators Active**: Dual predators chase the player (see Predator System below)
- **Points Earned**: Only for reaching NEW highest distance (not replaying same areas)
- **Death Enabled**: Obstacles and predators kill instantly
- **Leaderboard Impact**: All progress counts toward lifetime points ranking

### Fun Mode
A relaxed exploration mode with no competitive pressure.

- **No Predators**: Predators are completely disabled
- **No Death**: Collision detection active but player bounces back instead of dying
- **No Points**: Zero points accumulated, no leaderboard impact
- **Full Game Access**: All obstacles, zones, and vehicles still present
- **Go At Your Own Pace**: Practice routes, explore zones, learn patterns

**Design Philosophy**: Fun Mode lets players experience the full game without pressure. The ONLY way to earn leaderboard points is Ranked Mode with predators active.

---

## Predator System

### Dual Predator Design
Each player has TWO predators assigned (only visible to that player):

| Predator | Role | Behavior |
|----------|------|----------|
| **HUNTER** | Chases from behind | Follows player, triggers grab sequence |
| **STALKER** | Flanks to front | Moves ahead to block escape |

### Predator Variants
5 unique predator pairs, randomly assigned per player:

1. **The Devourer** - Crimson/orange glow
2. **The Phantom** - Purple/violet ethereal
3. **The Crawler** - Green/toxic
4. **The Shade** - Dark blue/black
5. **The Inferno** - Orange/red flames

### Kill Sequence (Trap Mechanic)
1. HUNTER catches up from behind
2. STALKER flanks and positions in front
3. Player is **TRAPPED** between both predators
4. 1.5 second pause (tension building)
5. If player **JUMPS** during trap → **INSTANT DEATH**
6. If player stays still → Predators attack and kill

### Respawn Rules
- **HUNTER starts at**: Z = -200 (behind spawn)
- **STALKER starts at**: Z = -220 (further behind)
- **Chase delay**: 8 seconds after spawn
- **isChasing**: Reset to false on respawn

---

## Scoring System (Robust)

### Core Rule
**Only NEW distance progress earns points.** Replaying the same area earns nothing.

```lua
-- PlayerDataManager tracks per player:
playerData = {
    lifetimePoints = 0,      -- Total accumulated (leaderboard metric)
    highestDistance = 0,     -- Furthest Z position ever reached
}

-- Points only awarded when:
if currentZ > data.highestDistance then
    local newPoints = currentZ - data.highestDistance
    data.highestDistance = currentZ
    data.lifetimePoints = data.lifetimePoints + newPoints
end
```

### Data Persistence
- Uses **DataStoreService** for cross-session persistence
- Auto-saves every 60 seconds
- Saves on player disconnect
- Exposes via `_G.PlayerData` API

### Leaderboard
- Shows **Lifetime Points** only
- Only Ranked Mode (with predators) earns points
- Fun Mode = 0 points always

---

## Spawn System

### Spawn Room
- Small starting area behind corridor entrance
- **No barriers** blocking movement
- Player faces positive Z (into corridor)
- Arch entrance (non-collidable, decorative)

### Respawn Timing
- `Players.RespawnTime = 0.5` (half second)
- All UI overlays cleared immediately on spawn
- UICleaner handles stuck dialogs

### UI Clearing (Robust System)
On every spawn/respawn, UICleaner:
1. Immediately hides all death/respawn overlays
2. Clears again at 0.05s, 0.1s, 0.2s (catch late spawns)
3. Periodic 0.5s check for stuck overlays
4. Forces `Visible = false` and `Transparency = 1`

---

## Project Structure

```
glassline/
├── src/
│   ├── server/
│   │   ├── init.server.luau     # Server initialization
│   │   ├── Data/                # PlayerDataService (lifetime points)
│   │   ├── Network/             # Handlers, RateLimiter, Validators
│   │   ├── Run/                 # RunService, ScoreService, DifficultyService
│   │   ├── Corridor/            # CorridorGenerator, Obstacles, Zones
│   │   ├── Vehicle/             # VehicleService, VehicleDefinitions
│   │   ├── Death/               # DeathService
│   │   └── Character/           # SpawnService
│   ├── client/
│   │   ├── init.client.luau
│   │   ├── Audio/               # MusicService, SFXService
│   │   ├── HUD/                 # ScoreDisplay, DirectionIndicator, ProgressBar
│   │   ├── Effects/             # ZoneTransition, SpeedLines
│   │   └── Input/               # InputController
│   └── shared/
│       ├── PlaceConfig.luau     # All game configuration
│       ├── Network/             # Event definitions, Types
│       └── Audio/               # AudioConfig, Types
├── tests/                       # TestEZ specs
└── assets/music/                # WAV/MP3 for upload reference
```

---

## Implemented Systems

### Server-Side (`src/server/`)
| Module | Purpose | Key APIs |
|--------|---------|----------|
| `Data/PlayerDataService` | Lifetime points, ProfileService | `:getData()`, `:addPoints()` |
| `Network/Handlers` | Server event handlers | Auto-initializes |
| `Network/Validators` | Input sanitization | `Validators.validate*()` |
| `Network/RateLimiter` | Exploit prevention | `RateLimiter:check()` |
| `Run/RunService` | Run state machine | `:getState()`, `:setState()` |
| `Run/ScoreService` | Directional scoring | `:addProgress()`, `:getMultiplier()` |
| `Run/DifficultyService` | Progressive difficulty | `:getDifficulty()`, `:getSpeedBonus()` |
| `Run/CheckpointService` | Progress tracking | `:getProgress()`, `:reachedEnd()` |
| `Death/DeathService` | Collision, respawn | `:onDeath()`, `:respawn()` |
| `Corridor/CorridorGenerator` | Procedural corridor | `:generate()`, `:getObstacles()` |
| `Vehicle/VehicleService` | Vehicle spawning | `:mount()`, `:dismount()` |
| `Character/SpawnService` | Player spawning | `:spawn()` |

### Client-Side (`src/client/`)
| Module | Purpose | Key APIs |
|--------|---------|----------|
| `Audio/MusicService` | Custom music playback | `:play()`, `:stop()` |
| `Audio/SFXService` | Sound effects | `:play()`, `:playAt()` |
| `HUD/Components/ScoreDisplay` | Lifetime + run points | `.create()`, `:update()` |
| `HUD/Components/DirectionIndicator` | Forward/backward state | `.create()`, `:setState()` |
| `HUD/Components/ProgressBar` | Distance progress | `.create()`, `:setProgress()` |
| `HUD/Components/DeathScreen` | Death overlay | `.create()`, `:show()` |
| `Effects/ZoneTransition` | Zone shift effects | `:transition()` |
| `Effects/SpeedLines` | Speed feedback | `:setIntensity()` |
| `Input/InputController` | Movement, jump, vehicle | `:init()` |

### Shared (`src/shared/`)
| Module | Purpose |
|--------|---------|
| `PlaceConfig` | Corridor, movement, scoring, difficulty, zones |
| `Network/` | RemoteEvent/Function creation, types |
| `Audio/AudioConfig` | Music tracks, SFX definitions |

---

## Key Configuration (PlaceConfig.luau)

```lua
Corridor = {
    width = 6,              -- Avatar width + margin
    height = 50,            -- Tall glass ceiling
    length = 10000,         -- Very long
    wallTransparency = 0.3, -- Glass effect
}

Movement = {
    baseRunSpeed = 80,      -- Very fast
    baseJumpPower = 80,     -- Very fast jumping
    vehicleSpeedMultiplier = 1.5,
}

Scoring = {
    forwardMultiplier = 1,
    backwardMultiplier = 2,
    pointsPerStud = 1,
}

Difficulty = {
    speedIncreasePerZone = 5,
    obstacleFrequencyBase = 0.1,
    obstacleFrequencyMax = 0.5,
    timingWindowShrink = 0.95,
}
```

---

## Development Workflow

### Tool Responsibilities

| Tool | Purpose | Examples |
|------|---------|----------|
| **Rojo** (`src/*.luau`) | All game logic, version controlled | Scripts, modules, services, config |
| **MCP** (`run_code`) | Place settings, testing | Lighting, Atmosphere, Sky, debugging |
| **rbxcloud** | Publishing & cloud APIs | Deploy to Roblox, DataStore, messaging |

### The Rule
```
If it has LOGIC → Rojo (src/)
If it's PLACE SETTINGS → MCP (run_code)
If you're TESTING → MCP (run_code)
If you're PUBLISHING → rbxcloud
```

### Division of Work

**MCP creates (one-time place setup):**
- `Lighting` - Ambient, Brightness, ColorShift
- `Atmosphere` - Fog, Haze, Glare
- `Sky` - Skybox properties
- `SoundService` - Volume settings
- `Terrain` - If needed

**Rojo creates (all game code):**
- `src/server/` - All server scripts and modules
- `src/client/` - All client scripts and modules
- `src/shared/` - Shared config and utilities

**rbxcloud handles:**
- `rbxcloud place publish` - Deploy place file
- `rbxcloud experience` - Update experience settings
- `rbxcloud datastore` - Manage player data
- `rbxcloud messaging` - Cross-server messaging

### Daily Commands

```bash
# Start Rojo live sync
rojo serve

# Install dependencies
wally install

# Lint
selene src/

# Format
stylua src/

# Build place file
rojo build -o glassline.rbxl

# Publish to Roblox
source .env && rbxcloud place publish -p $ROBLOX_PLACE_ID -u $ROBLOX_EXPERIENCE_ID -a "$ROBLOX_API_KEY" -f glassline.rbxl
```

### Environment Variables (.env)

```bash
ROBLOX_EXPERIENCE_ID=9447917120
ROBLOX_PLACE_ID=83423593675985
ROBLOX_API_KEY=<your-api-key>
```

### Run Tests (in Studio command bar)

```lua
require(game.ReplicatedStorage.Tests)()
```

---

## Scoring System

### Direction States

1. **Forward State** (default from start)
   - Earn points moving forward
   - No points moving backward
   - Active until reaching end zone

2. **Backward State** (after reaching end)
   - Earn 2x points moving backward
   - No points moving forward
   - Resets to Forward State on teleport to start

### Lifetime Points

- Points persist across runs and sessions (ProfileService)
- Accumulate from all forward/backward progress
- Display: Current run points + Lifetime total

---

## Visual Zones

Scenery outside glass shifts radically every 500 studs:

| Zone | Theme | Difficulty |
|------|-------|------------|
| 0-500 | Realistic Forest | 1 |
| 500-1000 | Surreal Geometric | 2 |
| 1000-1500 | Underwater Depths | 3 |
| 1500-2000 | Dreamy Clouds | 4 |
| 2000-2500 | Scary Shadows | 5 |
| 2500-3000 | Girly Pastel | 6 |
| 3000-3500 | Neon City | 7 |
| 3500-4000 | Abstract Art | 8 |
| ... | More zones | ... |

**Performance**: Use Roblox lighting, fog, weather, colors - minimal geometry.

---

## Obstacle System

### Width Rules (Robust System)
Vertical obstacles get **skinnier the closer to center** they are placed.

```lua
-- Width calculation based on X position
CONFIG = {
    corridorWidth = 6,      -- Total corridor width
    minWidth = 0.8,         -- Width at center (X=0)
    maxWidth = 2.5,         -- Width at edges (X=±3)
}

function calculateMaxWidth(xPosition)
    local distFromCenter = math.abs(xPosition)
    local normalizedDist = distFromCenter / (corridorWidth / 2)
    return minWidth + (maxWidth - minWidth) * normalizedDist
end
```

| X Position | Max Allowed Width |
|------------|-------------------|
| 0 (center) | 0.80 studs |
| ±1 | 1.37 studs |
| ±2 | 1.93 studs |
| ±3 (edge) | 2.50 studs |

### Starting Clear Zone
- **First 500 studs**: No obstacles (player gets up to speed)
- Obstacle spacing: 40-80 studs random

### Obstacle Types

#### Static (Memorizable Patterns)
- Walls, pillars, gaps
- Spikes
- Low beams (duck/slide)
- High beams (jump)

#### Moving (Timing Challenges)
- Swinging pendulums
- Sliding walls
- Rising/falling platforms
- Rotating bars

---

## Vehicle Types

| Vehicle | Speed | Jump | Notes |
|---------|-------|------|-------|
| Hoverboard | Faster | Lower | Smooth handling |
| Rocket | Much faster | Normal | Hard to control |
| Bouncer | Normal | Super high | For obstacle variety |

---

## Multiplayer

- **Ghost Mode**: See other players as semi-transparent ghosts
- No physical collision between players
- Leaderboard shows lifetime points
- Chaos comes from seeing others dodge/die

---

## Design Principles

### Rojo-First Development (MANDATE)
**All game code MUST live in `src/` as Luau files managed by Rojo.**

- **NEVER** leave game logic in MCP workspace scripts
- **ALWAYS** migrate MCP-created scripts to proper Rojo structure
- **DELETE** workspace scripts after migrating to Rojo
- Rojo syncs `src/` to Studio - this is the source of truth

```
src/
├── server/           → ServerScriptService/Server
├── client/           → StarterPlayerScripts/Client
└── shared/           → ReplicatedStorage/Shared
```

**Why Rojo-First:**
- Version control (git tracks all changes)
- Code review possible
- No lost work from Studio crashes
- Proper module organization
- Team collaboration

### Robust Systems, Not One-Offs
- **Never create one-off solutions** - every feature should be a reusable system
- **No magic numbers** - all values must come from named constants in config
- **One source of truth** - each concern has exactly ONE authoritative location
- **Config-driven** - behavior changes come from config, not code changes

### Single Source of Truth Examples
| Concern | Source of Truth | Location |
|---------|-----------------|----------|
| Corridor dimensions | `CONFIG.corridor` | ObstacleGenerator |
| Obstacle widths | `calculateMaxWidth()` | ObstacleGenerator |
| Respawn timing | `Players.RespawnTime` | RespawnHandler |
| Player data | `_G.PlayerData` | PlayerDataManager |
| Fun mode state | `_G.IsFunMode()` | FunModeManager |
| UI clearing | UICleaner | StarterPlayerScripts |

### Performance First
- Narrow scenery on sides (minimal geometry)
- Use Roblox lighting, fog, colors for visual impact
- Stream corridor segments

### Mobile-First Design
- **Landscape only** - forced via StarterGui.ScreenOrientation
- **Non-overlapping HUD zones** - TopLeft, TopRight, BottomLeft, BottomRight, Center
- **Compact elements** - small fonts (9-14px), minimal screen coverage
- **Safe areas** - respect notch/inset areas on phones
- **Touch-friendly** - minimum 36px touch targets

### Version Numbers
- Include version in all modules
- Format: `local VERSION = "X.Y.Z"`
- Log: `print("[ModuleName v" .. VERSION .. "] Initialized")`

---

## Audio System

### Music
- **Single track**: "Swept Ribbons" (custom uploaded)
- **Looping**: Continuous loop, no other music
- **No Roblox default sounds**: All SoundService children removed

### Configuration
```lua
-- AudioConfig.luau
MUSIC = {
    sweptRibbons = "rbxassetid://XXXXXXXXX", -- Upload ID
    volume = 0.5,
    looped = true,
}
```

### Adding New Music
1. Upload to Roblox Creator Hub (Audio section)
2. Get asset IDs
3. Configure in `src/shared/Audio/AudioConfig.luau`

---

## HUD System (Consolidated)

**Single Script**: `GameHUD.luau` - ONE source of truth for all HUD elements.

### Design System Constants
```lua
DESIGN = {
    -- Typography (ONE font family)
    font = Enum.Font.GothamBold,
    fontLight = Enum.Font.Gotham,

    -- Font sizes (mobile-first, small)
    textXS = 8,   textSM = 10,  textMD = 12,
    textLG = 16,  textXL = 24,

    -- Color palette (LIMITED - 5 colors only)
    colors = {
        bg = Color3.fromRGB(15, 15, 20),         -- Dark background
        bgAlt = Color3.fromRGB(25, 25, 35),      -- Alt background
        text = Color3.fromRGB(220, 220, 220),    -- Primary text
        textMuted = Color3.fromRGB(120, 120, 130), -- Muted text
        accent = Color3.fromRGB(80, 200, 255),   -- Cyan (points)
        danger = Color3.fromRGB(255, 80, 80),    -- Red (ranked/death)
        success = Color3.fromRGB(80, 255, 120),  -- Green (fun mode)
    },

    -- Consistent transparency
    bgOpacity = 0.35,

    -- Consistent spacing
    padding = 6,  paddingLG = 10,  gap = 4,
    radius = 6,

    -- iPhone safe areas
    safeLeft = 48,  safeRight = 48,
    safeTop = 8,    safeBottom = 8,

    -- Element sizes
    panelHeight = 44,  mirrorSize = 60,  buttonMinSize = 36,
}
```

### Layout (No Overlaps)
```
┌─────────────────────────────────────┐
│ [SCORE]              [FUN/RANKED] │  ← Top corners
│                                     │
│           (clear center)            │  ← Gameplay
│                                     │
│ [MIRROR]              [ZONE/DIST] │  ← Bottom corners
└─────────────────────────────────────┘
```

### Panels
| Panel | Position | Size | Content |
|-------|----------|------|---------|
| ScorePanel | TopLeft | 100x44 | Lifetime, Best |
| ModePanel | TopRight | 70x44 | FUN/RANKED toggle |
| MirrorPanel | BottomLeft | 72x80 | Rear viewport |
| ZonePanel | BottomRight | 80x44 | Zone, Distance |
| DeathOverlay | Fullscreen | - | Flash only (0.25s) |

### Helper Functions
All panels use shared `createPanel()` and `createLabel()` for consistency.

---

## Monetization: Points Multiplier Pass

**Single focused game pass**: Permanent 1.5x points multiplier on all earnings.

### Why This Works for Glassline
- **Stacks with mechanics**: Forward (1x) becomes 1.5x, Backward (2x) becomes 3x
- **No pay-to-win**: Doesn't make obstacles easier, just rewards dedicated players faster
- **Clear value**: Players see immediate impact in their score display
- **One-time purchase**: No subscription fatigue, builds goodwill

### Implementation

**Game Pass ID**: Create in Creator Hub → Monetization → Passes

**Server-side check** (`src/server/Run/ScoreService.luau`):
```lua
local MarketplaceService = game:GetService("MarketplaceService")
local MULTIPLIER_PASS_ID = 0 -- Replace with real ID

local function getPlayerMultiplier(player: Player): number
    local hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, MULTIPLIER_PASS_ID)
    return if hasPass then 1.5 else 1.0
end

-- Apply in score calculation:
points = points * getPlayerMultiplier(player)
```

**HUD indicator**: Show "1.5x" badge next to score for pass owners.

### Pricing Strategy
- **Price**: 199-299 Robux (impulse buy range)
- **Thumbnail**: Gold/sparkle effect on the multiplier number
- **Description**: "Earn 1.5x points on every run! Stacks with backward bonus for 3x total."

### Future Expansion (not in base project)
- Trail effects (cosmetic)
- Vehicle skins (cosmetic)
- Exclusive zone themes (cosmetic)

---

## Dependencies (wally.toml)

```toml
[server-dependencies]
ProfileService = "etheroit/profileservice@1.2.0"

[dev-dependencies]
TestEZ = "roblox/testez@0.4.1"
```
