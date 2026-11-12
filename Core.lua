local addonName, ns = ...

local function UpdateSystemFontSize()
    if NamePlateSetupOptions then
        if NamePlateSetupOptions.healthBarFontHeight then
            ns.systemFontSize = NamePlateSetupOptions.healthBarFontHeight
        end
        if NamePlateSetupOptions.castBarFontHeight then
            ns.systemCastBarFontSize = NamePlateSetupOptions.castBarFontHeight
        end
        ns.systemLevelFontSize = NamePlateSetupOptions.levelFontHeight
    end
end

ns.UpdateSystemFontSize = UpdateSystemFontSize

local debugMode = false

local function DebugPrint(...)
    if debugMode then
        print("|cff00ccff[MPlate]|r", ...)
    end
end

local function CallSafely(label, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok then
        DebugPrint(label, "failed:", err)
    end
    return ok, err
end

local function GetUnitCategory()
    return "enemy"
end

local function GetFontSizeForCategory(category)
    local custom = MPlateDB.fontSize[category]
    if custom then
        return custom
    end
    return ns.systemFontSize
end

local function ApplyFontSizeToUnitFrame(unitFrame, unitId)
    local unitName = unitId and UnitName(unitId) or "?"
    local name = unitFrame.name
    if not name then
        DebugPrint(unitName, "- unitFrame.name is nil")
        return
    end
    local category = GetUnitCategory(unitId)
    if not category then
        DebugPrint(unitName, "- category is nil")
        return
    end
    local size = GetFontSizeForCategory(category)
    if not size then
        DebugPrint(unitName, "- fontSize is nil")
        return
    end
    local fontFile, _, fontFlags = name:GetFont()
    if not fontFile then
        DebugPrint(unitName, "- GetFont() returned nil")
        return
    end
    DebugPrint(unitName, "- SetFont size:", size, "file:", fontFile)
    name:SetFont(fontFile, size, fontFlags)
end

local function ApplyCastBarFontSize(unitFrame)
    local castBar = unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar
    if not castBar then
        return
    end
    local size = MPlateDB.castBarFontSize or ns.systemCastBarFontSize
    if not size then
        return
    end
    for _, fontString in ipairs({ castBar.Text, castBar.CastTargetNameText }) do
        if fontString then
            local fontFile, _, fontFlags = fontString:GetFont()
            if fontFile then
                fontString:SetFont(fontFile, size, fontFlags)
            end
        end
    end
end

local function ApplyLevelFontSize(unitFrame)
    local size = MPlateDB.levelFontSize or (NamePlateSetupOptions and NamePlateSetupOptions.levelFontHeight)
    if not size then return end

    -- Forever's level badge uses PlayerLevelDiffFrame. Retail's similarly named
    -- difficulty indicator has no skull and is not an absolute level display.
    local badge = unitFrame.PlayerLevelDiffFrame
    if badge and badge.highLevelTexture and badge.playerLevelDiffText then
        badge.playerLevelDiffText:SetTextHeight(size)
    end
    local levelFrame = unitFrame.LevelFrame
    if levelFrame and levelFrame.LevelText then
        levelFrame.LevelText:SetTextHeight(size)
    end
end

local function ApplyHealthFontSize(unitFrame)
    local size = MPlateDB.levelFontSize or (NamePlateSetupOptions and NamePlateSetupOptions.healthBarFontHeight)
    local healthBar = unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar
    if not size or not healthBar then return end

    -- Cover numeric, percentage, and combined text layouts, including hidden
    -- strings that Blizzard may reuse when the health display mode changes.
    for _, key in ipairs({ "Text", "LeftText", "RightText" }) do
        local text = healthBar[key]
        if text then text:SetTextHeight(size) end
    end
end

local function HideLevelBadgeBackground(unitFrame)
    local badge = unitFrame.PlayerLevelDiffFrame
    if not badge or not badge.highLevelTexture then return end

    -- Keep the anchor textures and the frame itself: level text, skulls, and
    -- adjacent controls depend on their geometry. Alpha also survives Blizzard's
    -- Show/SetShown calls when the target or focus selection changes.
    if badge.playerLevelDiffIcon then badge.playerLevelDiffIcon:SetAlpha(0) end
    if badge.selectedBorder then badge.selectedBorder:SetAlpha(0) end
end

local function ApplyHealthTextOffset(unitFrame)
    -- Skip show-only-name mode (health texts not positioned by Blizzard).
    if unitFrame.IsShowOnlyName and unitFrame:IsShowOnlyName() then
        return
    end
    local healthBar = unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar
    if not healthBar or not healthBar.LeftText then
        return
    end

    local xOffset = MPlateDB.healthTextOffset or 0
    local yOffset = MPlateDB.healthTextYOffset or 0
    if xOffset == 0 and yOffset == 0 then
        return
    end

    -- Called once after Blizzard's UpdateAnchors. Preserve the client's layout:
    -- Forever can place health text inside the bar while the name is above it.
    local point, relativeTo, relativePoint, x, y = healthBar.LeftText:GetPoint(1)
    if not point then
        return
    end
    healthBar.LeftText:ClearAllPoints()
    -- RightText and Text chain from LeftText.
    PixelUtil.SetPoint(healthBar.LeftText, point, relativeTo, relativePoint, x + xOffset, y + yOffset)
end

local function ApplyEnemyNameWidth(unitFrame, unitId)
    if not UnitIsEnemy("player", unitId) then
        return
    end
    local name = unitFrame.name
    local container = unitFrame.HealthBarsContainer
    if not name or not container then
        return
    end

    local increase = MPlateDB.enemyNameWidthIncrease or 0
    if increase == 0 then
        return
    end

    local setupOptions = NamePlateSetupOptions
    local anchorStyles = NamePlateConstants and NamePlateConstants.NAME_ANCHOR_STYLES
    local anchorStyle = setupOptions and setupOptions.unitNameAnchorStyle
    if not anchorStyles or not anchorStyle then
        return
    end
    if anchorStyle ~= anchorStyles.InsideHealthBar
        and anchorStyle ~= anchorStyles.CenteredAboveHealthBar
        and anchorStyle ~= anchorStyles.AboveHealthBar then
        return
    end

    local isShowOnlyName = unitFrame.IsShowOnlyName and unitFrame:IsShowOnlyName()
    if anchorStyle == anchorStyles.CenteredAboveHealthBar then
        local halfIncrease = increase / 2
        local padding = isShowOnlyName and 4 or 0
        local nameSpacing = isShowOnlyName and 2 or (setupOptions.healthBarToNameAboveSpacing or 2)
        name:ClearAllPoints()
        PixelUtil.SetPoint(name, "BOTTOMLEFT", container, "TOPLEFT", padding - halfIncrease, nameSpacing)
        PixelUtil.SetPoint(name, "BOTTOMRIGHT", container, "TOPRIGHT", -padding + halfIncrease, nameSpacing)
    else
        -- Keep Blizzard's alignment and anchor target, including Forever's
        -- level indicator. Only extend the existing right edge.
        for index = 1, name:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = name:GetPoint(index)
            if point == "RIGHT" or point == "BOTTOMRIGHT" or point == "TOPRIGHT" then
                PixelUtil.SetPoint(name, point, relativeTo, relativePoint, x + increase, y)
            end
        end
    end
end

local function ApplyHealthBarHeight(unitFrame)
    local heightDelta = MPlateDB.healthBarHeightDelta or 0
    if heightDelta == 0 then return end
    local container = unitFrame.HealthBarsContainer
    if not container then return end
    local baseHeight = NamePlateSetupOptions and NamePlateSetupOptions.healthBarHeight
    if not baseHeight then return end
    PixelUtil.SetHeight(container, math.max(1, baseHeight + heightDelta))
end

local function ApplyHealthBarBorder(unitFrame)
    local healthBar = unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar
    if not healthBar or not healthBar.bgTexture then return end
    local hidden = MPlateDB.healthBarBorderHidden
    healthBar.bgTexture:SetAlpha(hidden and 0 or 1)
end

local applyingSizeOverride = false
local hasAppliedSizeOverride = false
local pendingNamePlateSizeUpdate = false
local eventFrame

local function QueueNamePlateSizeUpdate()
    pendingNamePlateSizeUpdate = true
    if eventFrame then
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local function CalculateBaseNamePlateSize(driver, namePlateStyle, ignoreBaseOverride)
    local savedBaseW = driver.baseNamePlateWidth
    local savedBaseH = driver.baseNamePlateHeight

    if ignoreBaseOverride then
        driver.baseNamePlateWidth = nil
        driver.baseNamePlateHeight = nil
    end

    local ok, widthOrError, height = pcall(function()
        local namePlateScale = driver:GetNamePlateScale(namePlateStyle)
        local width = driver:GetNamePlateWidth(namePlateStyle, namePlateScale)
        local calculatedHeight = driver:GetNamePlateHeight(namePlateStyle, namePlateScale)
        return width, calculatedHeight
    end)

    driver.baseNamePlateWidth = savedBaseW
    driver.baseNamePlateHeight = savedBaseH

    if not ok then
        return nil, nil, widthOrError
    end
    return widthOrError, height
end

local function ApplyNamePlateSize()
    if applyingSizeOverride then return end
    local widthDelta = MPlateDB.healthBarWidthDelta or 0
    local heightDelta = MPlateDB.healthBarHeightDelta or 0
    local hasCustomSize = widthDelta ~= 0 or heightDelta ~= 0
    if not hasCustomSize and not hasAppliedSizeOverride then return end

    if InCombatLockdown and InCombatLockdown() then
        QueueNamePlateSizeUpdate()
        DebugPrint("Nameplate size update deferred until combat ends")
        return
    end

    local driver = NamePlateDriverFrame
    if not driver then return end

    local namePlateStyle = CVarCallbackRegistry:GetCVarNumberOrDefault(NamePlateConstants.STYLE_CVAR)
    local baseWidth, baseHeight, calculationError = CalculateBaseNamePlateSize(driver, namePlateStyle, hasCustomSize)
    if not baseWidth or not baseHeight then
        DebugPrint("CalculateBaseNamePlateSize failed:", calculationError)
        return
    end

    local width = math.max(50, baseWidth + widthDelta)
    local height = math.max(1, baseHeight + heightDelta)

    applyingSizeOverride = true
    local ok, err = pcall(C_NamePlate.SetNamePlateSize, width, height)
    applyingSizeOverride = false

    if not ok then
        DebugPrint("C_NamePlate.SetNamePlateSize failed:", err)
        if InCombatLockdown and InCombatLockdown() then
            QueueNamePlateSizeUpdate()
        end
        return
    end

    hasAppliedSizeOverride = hasCustomSize
    pendingNamePlateSizeUpdate = false
    if eventFrame then
        eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
    DebugPrint("Nameplate size applied:", width, height)
end

function ns:RefreshAllNameplates()
    UpdateSystemFontSize()
    CallSafely("ApplyNamePlateSize", ApplyNamePlateSize)
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        local unitId = nameplate.namePlateUnitToken
        if unitId and nameplate.UnitFrame then
            local unitFrame = nameplate.UnitFrame
            -- The UpdateAnchors hook applies layout overrides exactly once,
            -- after Blizzard restores the baseline (also used by Reset).
            CallSafely("UpdateAnchors", unitFrame.UpdateAnchors, unitFrame)
            CallSafely("ApplyFontSizeToUnitFrame", ApplyFontSizeToUnitFrame, unitFrame, unitId)
            CallSafely("ApplyCastBarFontSize", ApplyCastBarFontSize, unitFrame)
        end
    end
end

local function GetUnitIdFromUnitFrame(unitFrame)
    local unitId = unitFrame.unit
    if not unitId then
        local ok, parent = pcall(unitFrame.GetParent, unitFrame)
        if ok and parent then
            unitId = parent.unitToken or parent.namePlateUnitToken
        end
    end
    return unitId
end

-- Hook: re-apply custom anchors after Blizzard sets them.
-- pcall protects against errors when frames are in transitional states (e.g. OnSizeChanged).
hooksecurefunc(NamePlateUnitFrameMixin, "UpdateAnchors", function(self)
    if not MPlateDB then
        return
    end
    local unitId = GetUnitIdFromUnitFrame(self)
    if unitId then
        CallSafely("ApplyEnemyNameWidth", ApplyEnemyNameWidth, self, unitId)
    end
    CallSafely("ApplyHealthTextOffset", ApplyHealthTextOffset, self)
    CallSafely("ApplyHealthBarHeight", ApplyHealthBarHeight, self)
    CallSafely("ApplyHealthBarBorder", ApplyHealthBarBorder, self)
    CallSafely("ApplyLevelFontSize", ApplyLevelFontSize, self)
    CallSafely("ApplyHealthFontSize", ApplyHealthFontSize, self)
    CallSafely("HideLevelBadgeBackground", HideLevelBadgeBackground, self)
end)

-- Hook: re-apply custom font sizes after Blizzard resets them via SetFontObject + SetTextHeight.
-- Covers: NAME_PLATE_UNIT_ADDED, CVAR_UPDATE, DISPLAY_SIZE_CHANGED, VARIABLES_LOADED.
hooksecurefunc(NamePlateUnitFrameMixin, "ApplyFrameOptions", function(self)
    if not MPlateDB or not MPlateDB.fontSize then
        return
    end
    CallSafely("UpdateSystemFontSize", UpdateSystemFontSize)

    local unitId = GetUnitIdFromUnitFrame(self)
    if not unitId then
        return
    end

    DebugPrint("ApplyFrameOptions hook - unitId:", unitId)
    CallSafely("ApplyFontSizeToUnitFrame", ApplyFontSizeToUnitFrame, self, unitId)
    CallSafely("ApplyCastBarFontSize", ApplyCastBarFontSize, self)
    CallSafely("ApplyHealthBarBorder", ApplyHealthBarBorder, self)

end)

-- Hook: re-apply custom nameplate size after Blizzard sets it via C_NamePlate.SetNamePlateSize.
-- Must hook the frame directly (not the mixin) because NamePlateDriverFrame is a singleton
-- created in XML before addon Lua loads — Mixin() already copied the original function onto
-- the frame, so hooking the mixin table would not intercept calls on the frame.
hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateSize", function()
    if not MPlateDB then
        return
    end
    CallSafely("ApplyNamePlateSize", ApplyNamePlateSize)
end)

eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UNIT_FACTION")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            self:UnregisterEvent("ADDON_LOADED")

            if not MPlateDB then
                MPlateDB = {}
            end
            if not MPlateDB.fontSize then
                MPlateDB.fontSize = {}
            end
            local levelSize = MPlateDB.levelFontSize
            if levelSize ~= nil and (type(levelSize) ~= "number" or levelSize ~= levelSize
                or levelSize < 8 or levelSize > 36) then
                MPlateDB.levelFontSize = nil
            end

            -- Migration: clear removed settings, restore system defaults
            MPlateDB.fontSize.player = nil
            MPlateDB.fontSize.friendlyPlayer = nil
            MPlateDB.fontSize.friendlyNpc = nil
            MPlateDB.enemyHealthBarScale = nil
            MPlateDB.systemFontSize = nil
            MPlateDB.systemCastBarFontSize = nil
            -- Merge neutral into enemy
            if not MPlateDB.fontSize.enemy and MPlateDB.fontSize.neutral then
                MPlateDB.fontSize.enemy = MPlateDB.fontSize.neutral
            end
            MPlateDB.fontSize.neutral = nil

            UpdateSystemFontSize()
            ns:InitOptions()
            CallSafely("ApplyNamePlateSize", ApplyNamePlateSize)
        end
    elseif event == "UNIT_FACTION" then
        local unitId = ...
        if not unitId or not string.find(unitId, "^nameplate") then return end
        local nameplate = C_NamePlate.GetNamePlateForUnit(unitId)
        if nameplate and nameplate.UnitFrame then
            CallSafely("ApplyFontSizeToUnitFrame", ApplyFontSizeToUnitFrame, nameplate.UnitFrame, unitId)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if pendingNamePlateSizeUpdate then
            pendingNamePlateSizeUpdate = false
            CallSafely("ApplyNamePlateSize", ApplyNamePlateSize)
        end
    end
end)

SLASH_MPLATE1 = "/mplate"
SlashCmdList["MPLATE"] = function(msg)
    if msg == "debug" then
        debugMode = not debugMode
        print("|cff00ccff[MPlate]|r Debug:", debugMode and "ON" or "OFF")
        if debugMode then
            ns:RefreshAllNameplates()
        end
        return
    end
    Settings.OpenToCategory(ns.settingsCategoryID)
end
