--!strict
--[[
    HUD/HUDConstants.luau
    Consolidated Design System for Glassline HUD

    SINGLE SOURCE OF TRUTH for all HUD styling.
    Mobile-first, iPhone landscape optimized.

    Version: 2.0.0
]]

local VERSION = "2.0.0"

local HUDConstants = {}

-- ============================================
-- TYPOGRAPHY
-- ============================================
HUDConstants.Fonts = {
    Primary = Enum.Font.GothamBold,
    Secondary = Enum.Font.Gotham,
    -- Component-specific aliases
    Title = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
    Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
    Score = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
}

HUDConstants.FontSizes = {
    -- Base sizes
    XS = 8,
    SM = 10,
    MD = 12,
    LG = 16,
    XL = 24,
    XXL = 32,
    -- Semantic aliases
    Small = 10,
    Medium = 14,
    Large = 20,
    Title = 28,
    Score = 36,
}

-- ============================================
-- COLOR PALETTE
-- ============================================
HUDConstants.Colors = {
    -- Backgrounds
    bg = Color3.fromRGB(15, 15, 20),
    bgAlt = Color3.fromRGB(25, 25, 35),
    Background = Color3.fromRGB(15, 15, 20),
    BackgroundTransparency = 0.35,

    -- Text
    text = Color3.fromRGB(220, 220, 220),
    textMuted = Color3.fromRGB(120, 120, 130),
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(180, 180, 190),

    -- Semantic
    accent = Color3.fromRGB(80, 200, 255),   -- Cyan (points, highlights)
    danger = Color3.fromRGB(255, 80, 80),    -- Red (ranked, death)
    success = Color3.fromRGB(80, 255, 120),  -- Green (fun mode)

    -- Direction states
    Forward = Color3.fromRGB(80, 200, 255),  -- Cyan
    Backward = Color3.fromRGB(255, 180, 50), -- Gold

    -- Progress bar
    ProgressBackground = Color3.fromRGB(40, 40, 50),
    ProgressFill = Color3.fromRGB(80, 200, 255),

    -- Death screen
    DeathOverlay = Color3.fromRGB(50, 0, 0),
    DeathText = Color3.fromRGB(255, 50, 50),

    -- Vehicle indicator
    Success = Color3.fromRGB(80, 255, 120),
}

-- ============================================
-- TRANSPARENCY
-- ============================================
HUDConstants.Transparency = {
    bg = 0.35,
    overlay = 0.5,
    solid = 0,
}

-- ============================================
-- SPACING
-- ============================================
HUDConstants.Spacing = {
    xs = 4,
    sm = 6,
    md = 10,
    lg = 16,
    xl = 24,
    ScreenPadding = 10,
}

-- ============================================
-- BORDER RADIUS
-- ============================================
HUDConstants.Radius = {
    sm = 4,
    md = 6,
    lg = 10,
}

-- ============================================
-- SAFE AREAS (iPhone notch/edge)
-- ============================================
HUDConstants.SafeArea = {
    left = 48,
    right = 48,
    top = 8,
    bottom = 8,
}

-- ============================================
-- ELEMENT SIZES
-- ============================================
HUDConstants.Sizes = {
    panelHeight = 44,
    mirrorSize = 60,
    buttonMin = 36,
    touchTarget = 44,
    -- Component-specific
    ScoreHeight = 80,
    DirectionIndicatorSize = 40,
    ProgressBarHeight = 8,
    CornerRadius = 8,
}

-- ============================================
-- Z-INDEX LAYERS
-- ============================================
HUDConstants.ZIndex = {
    base = 1,
    hud = 10,
    overlay = 50,
    death = 100,
    DeathScreen = 100,
}

-- ============================================
-- ANIMATION
-- ============================================
HUDConstants.Animation = {
    fast = 0.15,
    normal = 0.3,
    slow = 0.5,
    easing = Enum.EasingStyle.Quad,
    direction = Enum.EasingDirection.Out,
    -- Aliases for components
    TweenTime = 0.3,
    TweenTimeFast = 0.15,
    EasingStyle = Enum.EasingStyle.Quad,
    EasingDirection = Enum.EasingDirection.Out,
}

-- ============================================
-- LAYOUT POSITIONS
-- ============================================
HUDConstants.Layout = {
    scorePanelWidth = 100,
    modePanelWidth = 70,
    zonePanelWidth = 80,
    mirrorPanelWidth = 72,
    mirrorPanelHeight = 80,
}

print("[HUDConstants v" .. VERSION .. "] Loaded")

return HUDConstants
