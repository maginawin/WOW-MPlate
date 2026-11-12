-- Run from the addon root with Lua 5.1 and an extracted Blizzard UI source file:
-- lua tests/nameplate_compat.lua path/to/Blizzard_NamePlateUnitFrame.lua retail
-- lua tests/nameplate_compat.lua path/to/Blizzard_NamePlateUnitFrame.lua forever
-- Optional third argument: Camelot/Blizzard_NamePlateLevelFrame.lua to verify target/focus transitions.
-- Uses Blizzard's real UpdateAnchors; mocks only the game frame/API boundary.
local sourcePath, client = arg[1], arg[2]
assert(sourcePath and (client == "retail" or client == "forever"), "Supply UI source path and retail/forever")
local file = assert(io.open(sourcePath))
local source = file:read("*a")
file:close()
local updateAnchors = assert(source:match("(function NamePlateUnitFrameMixin:UpdateAnchors%(%)%s.-)\nfunction NamePlateUnitFrameMixin:"))

local methods = {}
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(point, relativeTo, relativePoint, x, y)
    local value = { point, relativeTo, relativePoint, x or 0, y or 0 }
    for index, old in ipairs(self.points) do
        if old[1] == point then self.points[index] = value; return end
    end
    self.points[#self.points + 1] = value
end
function methods:GetPoint(index) return unpack(self.points[index or 1] or {}) end
function methods:GetNumPoints() return #self.points end
function methods:SetHeight(value) self.height = value end
function methods:SetWidth(value) self.width = value end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:GetWidth() return self.width or 28 end
function methods:GetLineHeight() return self.fontSize or 14 end
function methods:SetJustifyH(value) self.justify = value end
function methods:GetFont() return "font.ttf", self.fontSize or 14, "OUTLINE" end
function methods:SetFont(_, size) self.fontSize = size end
function methods:SetTextHeight(size) self.fontSize = size end
function methods:SetFontObject() end
function methods:SetScale() end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetShown(value) self.display = value end
function methods:SetVertexColor(r, g, b) self.color = { r, g, b } end
function methods:ShouldDisplay() return self.display end
function methods:IsShown() return self.display end
function methods:ShouldUseSelectedBorder() return self.selected end
function methods:SetShouldUseSelectedBorder(value) self.selected = value end
for _, name in ipairs({ "SetFontHeight", "SetAtlas", "SetTexture", "SetTexCoord",
    "SetTextureSliceMargins", "SetDrawLayer", "UpdateSelectionBorder", "ApplyStyleAndAnchoring" }) do
    methods[name] = function() end
end
local function node() return setmetatable({ points = {} }, { __index = methods }) end

NamePlateConstants = {
    NAME_ANCHOR_STYLES = { InsideHealthBar = 1, AboveHealthBar = 2, CenteredAboveHealthBar = 3 },
    SELECTED_BORDER_OFFSETS = { topLeftX = -1, topLeftY = 1, bottomRightX = -3, bottomRightY = 3 },
    STYLE_CVAR = "nameplateStyle",
    TARGET_BORDER_COLOR = { r = 1, g = 1, b = 1 },
    FOCUS_TARGET_BORDER_COLOR = { r = 1, g = 0, b = 0 },
}
if arg[3] then assert(loadfile(arg[3]))() end
NamePlateUnitFrameMixin = {}
local getFontObject = source:match("(local function GetNamePlateFontObject%(setupOptions%).-\nend)") or ""
local applyFrameOptions = assert(source:match("(function NamePlateUnitFrameMixin:ApplyFrameOptions%(setupOptions, frameOptions%).-)\nfunction NamePlateUnitFrameMixin:"))
assert(loadstring("local CAST_BAR_SPARK_EXTRA_HEIGHT = 8\n" .. getFontObject .. "\n" .. applyFrameOptions))()
CompactUnitFrame_SetOptionTable = function() end
TextureKitConstants = { IgnoreAtlasSize = true }
assert(loadstring(updateAnchors))()
local updateControlAnchors = source:match("(function NamePlateUnitFrameMixin:UpdateControlAnchors%(rightManagedAuraOffset%).-)\nfunction NamePlateUnitFrameMixin:")
if updateControlAnchors then assert(loadstring(updateControlAnchors))() end
local originalUpdateAnchors = NamePlateUnitFrameMixin.UpdateAnchors
PixelUtil = { SetPoint = methods.SetPoint, SetHeight = methods.SetHeight, SetWidth = methods.SetWidth,
    SetSize = methods.SetSize }
CVarCallbackRegistry = { GetCVarNumberOrDefault = function() return 1 end }
local combat, sizeCalls, frames = false, 0, {}
InCombatLockdown = function() return combat end
UnitName = function() return "Test" end
UnitIsEnemy = function(_, unit) return unit ~= "nameplateFriend" end
C_NamePlate = {
    GetNamePlates = function() return frames end,
    SetNamePlateSize = function(width, height)
        assert(not combat, "Size write during combat")
        sizeCalls = sizeCalls + 1
        C_NamePlate.width, C_NamePlate.height = width, height
    end,
}
NamePlateDriverFrame = {
    GetNamePlateScale = function() return {} end,
    GetNamePlateWidth = function(self) return self.baseNamePlateWidth or (client == "forever" and 190 or 230) end,
    GetNamePlateHeight = function(self) return self.baseNamePlateHeight or 45 end,
    UpdateNamePlateSize = function(self)
        C_NamePlate.SetNamePlateSize(self:GetNamePlateWidth(), self:GetNamePlateHeight())
    end,
}
function hooksecurefunc(target, name, hook)
    local original = assert(target[name])
    target[name] = function(...) original(...); hook(...) end
end
local eventFrame = { events = {} }
function eventFrame:RegisterEvent(name) self.events[name] = true end
function eventFrame:UnregisterEvent(name) self.events[name] = nil end
function eventFrame:SetScript(_, callback) self.callback = callback end
CreateFrame = function() return eventFrame end
SlashCmdList = {}
local ns = { InitOptions = function() end }
assert(loadfile("Core.lua"))("MPlate", ns)
MPlateDB = { fontSize = { neutral = 24, player = 20 }, healthTextOffset = 9 }
eventFrame:callback("ADDON_LOADED", "MPlate")
assert(MPlateDB.fontSize.enemy == 24 and MPlateDB.fontSize.neutral == nil)
assert(MPlateDB.fontSize.player == nil and MPlateDB.healthTextOffset == 9)

local function frame(showOnlyName, level)
    local unit = node()
    unit.unit = "nameplate1"
    unit.name, unit.HealthBarsContainer, unit.CastBarsContainer = node(), node(), node()
    local health = node()
    unit.HealthBarsContainer.healthBar = health
    for _, key in ipairs({ "Text", "LeftText", "RightText", "bgTexture", "barTexture", "selectedBorder" }) do
        health[key] = node()
    end
    unit.CastBarsContainer.castBar = node()
    unit.CastBarsContainer.castBar.Text = node()
    unit.CastBarsContainer.castBar.CastTargetNameText = node()
    unit.CastBarsContainer.castBar.Spark = node()
    unit.PlayerLevelDiffFrame = node()
    unit.PlayerLevelDiffFrame.playerLevelDiffText = node()
    unit.PlayerLevelDiffFrame.playerLevelDiffText:SetAlpha(1)
    unit.PlayerLevelDiffFrame.playerLevelDiffIcon = node()
    unit.PlayerLevelDiffFrame.playerLevelDiffIcon:SetAlpha(1)
    unit.PlayerLevelDiffFrame.selectedBorder = node()
    unit.PlayerLevelDiffFrame.selectedBorder:SetAlpha(1)
    if client == "forever" then
        unit.PlayerLevelDiffFrame.highLevelTexture = node()
        unit.PlayerLevelDiffFrame.highLevelTexture:SetAlpha(1)
        if arg[3] then
            for _, method in ipairs({ "IsTarget", "SetIsTarget", "IsFocus", "SetIsFocus", "UpdateSelectionBorder" }) do
                unit.PlayerLevelDiffFrame[method] = NameplateLevelFrameMixin[method]
            end
        end
    end
    unit.PlayerLevelDiffFrame.display = level
    unit.PlayerLevelDiffFrame:SetPoint("LEFT", unit.HealthBarsContainer, "RIGHT", 2, 0)
    unit.overAbsorbGlow, unit.overHealAbsorbGlow, unit.RaidTargetFrame = node(), node(), node()
    unit.aggroHighlightTextures = { node() }
    unit.AurasFrame = { DebuffListFrame = node(), CrowdControlListFrame = node(), LossOfControlFrame = node() }
    unit.LevelFrame = node()
    unit.LevelFrame.LevelText = node()
    unit.ClassificationFrame = node()
    unit.UpdateHitTestArea = function() end
    unit.IsShowOnlyName = function() return showOnlyName end
    unit.UpdateAnchors = NamePlateUnitFrameMixin.UpdateAnchors
    unit.UpdateControlAnchors = NamePlateUnitFrameMixin.UpdateControlAnchors
    return unit
end
local function equalPoints(actual, expected, dx, dy)
    assert(#actual == #expected, "Anchor count changed")
    for i, point in ipairs(expected) do
        for j = 1, 3 do assert(actual[i][j] == point[j], "Anchor target changed") end
        assert(actual[i][4] == point[4] + (dx or 0), "Wrong horizontal offset")
        assert(actual[i][5] == point[5] + (dy or 0), "Wrong vertical offset")
    end
end
local cases = 0
local function assertHealthSize(unit, size)
    for _, key in ipairs({ "Text", "LeftText", "RightText" }) do
        assert(unit.HealthBarsContainer.healthBar[key].fontSize == size, key .. " has wrong health font size")
    end
end
local function assertLevelBackground(unit)
    local badge = unit.PlayerLevelDiffFrame
    assert(badge.playerLevelDiffIcon.alpha == (client == "forever" and 0 or 1))
    assert(badge.selectedBorder.alpha == (client == "forever" and 0 or 1))
    assert(badge.playerLevelDiffText.alpha == 1)
    if badge.highLevelTexture then assert(badge.highLevelTexture.alpha == 1) end
end
for style = 1, 3 do
    for _, onlyName in ipairs({ false, true }) do
        for _, level in ipairs({ false, true }) do
            NamePlateSetupOptions = {
                unitNameAnchorStyle = style, useClassicHealthBar = style == 3,
                healthTextInsideBarWhenNameAboveHealthBar = client == "forever",
                nameJustificationWhenAboveHealthBar = client == "forever" and "CENTER" or "LEFT",
                healthBarToNameAboveSpacing = 4, healthBarHeight = 20,
                healthBarFontHeight = 14, castBarFontHeight = 10,
                horizontalScale = 1, verticalScale = 1, insetWidth = 12,
                castBarToHealthBarSpacing = 2,
                levelFontHeight = 10, castBarHeight = 12, castIconHeight = 12,
                playerLevelDiffWidth = 28, playerLevelDiffHeight = 28,
            }
            local unit = frame(onlyName, level)
            originalUpdateAnchors(unit)
            local health = unit.HealthBarsContainer.healthBar
            local baseText, baseName, baseJustify = health.LeftText.points, unit.name.points, unit.name.justify
            frames = { { namePlateUnitToken = unit.unit, UnitFrame = unit } }
            MPlateDB = { fontSize = { enemy = 22 }, castBarFontSize = 18, levelFontSize = 24,
                healthTextOffset = 17, healthTextYOffset = -3, enemyNameWidthIncrease = 40,
                healthBarHeightDelta = 5, healthBarBorderHidden = true }
            for refresh = 1, 3 do
                ns:RefreshAllNameplates()
                equalPoints(health.LeftText.points, baseText, onlyName and 0 or 17, onlyName and 0 or -3)
                assert(unit.name.justify == baseJustify, "Name alignment changed")
                if style == 3 then
                    assert(unit.name.points[1][4] == (onlyName and 4 or 0) - 20)
                    assert(unit.name.points[2][4] == (onlyName and -4 or 0) + 20)
                else
                    for i, point in ipairs(baseName) do
                        local edge = point[1]:find("RIGHT") and 40 or 0
                        equalPoints({ unit.name.points[i] }, { point }, edge, 0)
                    end
                end
                assert(unit.HealthBarsContainer.height == 25 and health.bgTexture.alpha == 0)
                assert(unit.name.fontSize == 22 and unit.CastBarsContainer.castBar.Text.fontSize == 18)
                assert(unit.LevelFrame.LevelText.fontSize == 24)
                assertHealthSize(unit, 24)
                assertLevelBackground(unit)
                assert(unit.PlayerLevelDiffFrame.playerLevelDiffText.fontSize == (client == "forever" and 24 or nil))
            end
            if client == "forever" and arg[3] then
                local badge = unit.PlayerLevelDiffFrame
                badge:SetIsTarget(true)
                assert(badge.selectedBorder:IsShown())
                assertLevelBackground(unit)
                badge:SetIsFocus(true)
                badge:SetIsTarget(false)
                assert(badge.selectedBorder:IsShown())
                assertLevelBackground(unit)
                badge:SetIsFocus(false)
                assert(not badge.selectedBorder:IsShown())
                assertLevelBackground(unit)
            end
            -- A normal Blizzard refresh must also apply customization exactly once.
            unit:UpdateAnchors()
            equalPoints(health.LeftText.points, baseText, onlyName and 0 or 17, onlyName and 0 or -3)
            -- Exercise the actual Blizzard reset path, including style/size changes.
            NamePlateSetupOptions.levelFontHeight = 12.5
            NamePlateSetupOptions.healthBarFontHeight = 17.5
            NamePlateUnitFrameMixin.ApplyFrameOptions(unit, NamePlateSetupOptions, {})
            assert(unit.LevelFrame.LevelText.fontSize == 24)
            assertHealthSize(unit, 24)
            assert(unit.name.fontSize == 22 and unit.CastBarsContainer.castBar.Text.fontSize == 18)
            assert(unit.PlayerLevelDiffFrame.playerLevelDiffText.fontSize == (client == "forever" and 24 or nil))
            -- Restore defaults; also verify friendly name widths are untouched.
            MPlateDB = { fontSize = {} }
            ns:RefreshAllNameplates()
            equalPoints(health.LeftText.points, baseText)
            equalPoints(unit.name.points, baseName)
            assert(unit.HealthBarsContainer.height == 20 and health.bgTexture.alpha == 1)
            assert(unit.name.fontSize == 17.5 and unit.CastBarsContainer.castBar.Text.fontSize == 10)
            assert(unit.LevelFrame.LevelText.fontSize == 12.5)
            assertHealthSize(unit, 17.5)
            assertLevelBackground(unit)
            assert(unit.PlayerLevelDiffFrame.playerLevelDiffText.fontSize == (client == "forever" and 12.5 or nil))
            unit.unit = "nameplateFriend"
            frames[1].namePlateUnitToken = unit.unit
            MPlateDB.enemyNameWidthIncrease = 40
            ns:RefreshAllNameplates()
            equalPoints(unit.name.points, baseName)
            cases = cases + 1
        end
    end
end

-- SavedVariables load: old data needs no migration; explicit sizes survive load.
for _, saved in ipairs({ false, 8, 10, 36, "24", 0, 37, math.huge }) do
    MPlateDB = { fontSize = {}, levelFontSize = saved or nil }
    eventFrame:callback("ADDON_LOADED", "MPlate")
    local expected = type(saved) == "number" and saved >= 8 and saved <= 36 and saved or nil
    assert(MPlateDB.levelFontSize == expected, "Saved level font size was not restored safely")
    local unit = frame(false, true)
    NamePlateUnitFrameMixin.ApplyFrameOptions(unit, NamePlateSetupOptions, {})
    assert(unit.LevelFrame.LevelText.fontSize == (expected or NamePlateSetupOptions.levelFontHeight))
    assertHealthSize(unit, expected or NamePlateSetupOptions.healthBarFontHeight)
end

-- Transitional frames or clients without a level widget must remain safe.
local partial = frame(false, true)
partial.PlayerLevelDiffFrame.playerLevelDiffText = nil
partial.PlayerLevelDiffFrame.highLevelTexture = nil
MPlateDB = { fontSize = {}, levelFontSize = 24 }
partial:UpdateAnchors()
assertHealthSize(partial, 24)

-- Combat deferral uses the latest value, including resetting before combat ends.
frames = {}
MPlateDB = { fontSize = {}, healthBarWidthDelta = 30, healthBarHeightDelta = 5 }
local before = sizeCalls
combat = true
ns:RefreshAllNameplates()
assert(sizeCalls == before and eventFrame.events.PLAYER_REGEN_ENABLED)
MPlateDB.healthBarWidthDelta = 50
combat = false
eventFrame:callback("PLAYER_REGEN_ENABLED")
assert(C_NamePlate.width == (client == "forever" and 190 or 230) + 50 and C_NamePlate.height == 50)
combat = true
MPlateDB.healthBarWidthDelta, MPlateDB.healthBarHeightDelta = nil, nil
ns:RefreshAllNameplates()
combat = false
eventFrame:callback("PLAYER_REGEN_ENABLED")
assert(C_NamePlate.width == (client == "forever" and 190 or 230) and C_NamePlate.height == 45)
assert(not eventFrame.events.PLAYER_REGEN_ENABLED)

-- Failed size writes can be retried by the next refresh.
local setSize = C_NamePlate.SetNamePlateSize
C_NamePlate.SetNamePlateSize = function() error("Simulated restricted API") end
MPlateDB.healthBarWidthDelta = 20
ns:RefreshAllNameplates()
C_NamePlate.SetNamePlateSize = setSize
ns:RefreshAllNameplates()
assert(C_NamePlate.width == (client == "forever" and 190 or 230) + 20)
print(client .. ": " .. cases .. " layout cases plus reset, refresh, combat and retry checks passed")
