local addonName, ns = ...

local function UpdateSystemFontSize()
    if NamePlateSetupOptions then
        if NamePlateSetupOptions.healthBarFontHeight then
            ns.systemFontSize = NamePlateSetupOptions.healthBarFontHeight
        end
        if NamePlateSetupOptions.castBarFontHeight then
            ns.systemCastBarFontSize = NamePlateSetupOptions.castBarFontHeight
        end
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

    -- Re-position the rightmost health text; RightText and Text chain from it.
    healthBar.LeftText:ClearAllPoints()
    if anchorStyle == anchorStyles.InsideHealthBar then
        PixelUtil.SetPoint(healthBar.LeftText, "RIGHT", healthBar, "RIGHT", -4 + xOffset, yOffset)
    elseif anchorStyle == anchorStyles.CenteredAboveHealthBar then
        local baseYOffset = setupOptions.useClassicHealthBar and -0.5 or 0
        PixelUtil.SetPoint(healthBar.LeftText, "RIGHT", healthBar, "RIGHT", -4 + xOffset, baseYOffset + yOffset)
    elseif anchorStyle == anchorStyles.AboveHealthBar then
        PixelUtil.SetPoint(healthBar.LeftText, "BOTTOMRIGHT", healthBar, "TOPRIGHT", -4 + xOffset, 2 + yOffset)
    end
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
    local nameSpacing = setupOptions.healthBarToNameAboveSpacing or 2
    local healthBarText
    if not isShowOnlyName and anchorStyle ~= anchorStyles.CenteredAboveHealthBar then
        healthBarText = container.healthBar and container.healthBar.Text
        if not healthBarText then
            return
        end
    end

    -- Clear existing anchors before setting new ones to prevent accumulation.
    name:ClearAllPoints()

    if isShowOnlyName then
        name:SetJustifyH("CENTER")
        if anchorStyle == anchorStyles.InsideHealthBar then
            PixelUtil.SetPoint(name, "LEFT", container, "LEFT", 4, 0)
            PixelUtil.SetPoint(name, "RIGHT", container, "RIGHT", -4 + increase, 0)
        elseif anchorStyle == anchorStyles.CenteredAboveHealthBar then
            local halfIncrease = increase / 2
            PixelUtil.SetPoint(name, "BOTTOMLEFT", container, "TOPLEFT", 4 - halfIncrease, 2)
            PixelUtil.SetPoint(name, "BOTTOMRIGHT", container, "TOPRIGHT", -4 + halfIncrease, 2)
        elseif anchorStyle == anchorStyles.AboveHealthBar then
            PixelUtil.SetPoint(name, "BOTTOMLEFT", container, "TOPLEFT", 4, 2)
            PixelUtil.SetPoint(name, "BOTTOMRIGHT", container, "TOPRIGHT", -4 + increase, 2)
        end
    else
        if anchorStyle == anchorStyles.InsideHealthBar then
            name:SetJustifyH("LEFT")
            PixelUtil.SetPoint(name, "LEFT", container, "LEFT", 4, 0)
            PixelUtil.SetPoint(name, "RIGHT", healthBarText, "LEFT", -2 + increase, 0)
        elseif anchorStyle == anchorStyles.CenteredAboveHealthBar then
            local halfIncrease = increase / 2
            name:SetJustifyH("CENTER")
            PixelUtil.SetPoint(name, "BOTTOMLEFT", container, "TOPLEFT", -halfIncrease, nameSpacing)
            PixelUtil.SetPoint(name, "BOTTOMRIGHT", container, "TOPRIGHT", halfIncrease, nameSpacing)
        elseif anchorStyle == anchorStyles.AboveHealthBar then
            name:SetJustifyH("LEFT")
            PixelUtil.SetPoint(name, "BOTTOMLEFT", container, "TOPLEFT", 4, nameSpacing)
            PixelUtil.SetPoint(name, "BOTTOMRIGHT", healthBarText, "BOTTOMLEFT", -2 + increase, 0)
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
            CallSafely("UpdateAnchors", unitFrame.UpdateAnchors, unitFrame)
            CallSafely("ApplyFontSizeToUnitFrame", ApplyFontSizeToUnitFrame, unitFrame, unitId)
            CallSafely("ApplyCastBarFontSize", ApplyCastBarFontSize, unitFrame)
            CallSafely("ApplyHealthTextOffset", ApplyHealthTextOffset, unitFrame)
            CallSafely("ApplyEnemyNameWidth", ApplyEnemyNameWidth, unitFrame, unitId)
            CallSafely("ApplyHealthBarHeight", ApplyHealthBarHeight, unitFrame)
            CallSafely("ApplyHealthBarBorder", ApplyHealthBarBorder, unitFrame)

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
