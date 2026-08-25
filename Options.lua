local addonName, ns = ...
local L = ns.L

local FONT_SIZE_MIN = 12
local FONT_SIZE_MAX = 36
local FONT_SIZE_STEP = 1

local sliders = {}
local checkboxes = {}

local function GetEffectiveFontSize(key)
    return MPlateDB.fontSize[key] or ns.systemFontSize or 14
end

local function FormatFontValueText(key)
    local custom = MPlateDB.fontSize[key]
    local sys = ns.systemFontSize
    if custom then
        return tostring(math.floor(custom))
    elseif sys then
        return L["SystemDefault"] .. " (" .. math.floor(sys) .. ")"
    else
        return L["SystemDefault"]
    end
end

local function GetEffectiveCastBarFontSize()
    return MPlateDB.castBarFontSize or ns.systemCastBarFontSize or 12
end

local function FormatCastBarValueText()
    local custom = MPlateDB.castBarFontSize
    local sys = ns.systemCastBarFontSize
    if custom then
        return tostring(math.floor(custom))
    elseif sys then
        return L["SystemDefault"] .. " (" .. math.floor(sys) .. ")"
    else
        return L["SystemDefault"]
    end
end

local function RoundToStep(value, step)
    local inv = 1 / step
    return math.floor(value * inv + 0.5) / inv
end

local function CreateSliderRow(parent, sliderKey, label, anchor, offsetY, getVal, setVal, resetVal, formatVal, sliderMin, sliderMax, sliderStep)
    sliderMin = sliderMin or FONT_SIZE_MIN
    sliderMax = sliderMax or FONT_SIZE_MAX
    sliderStep = sliderStep or FONT_SIZE_STEP

    local nameText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    nameText:SetText(label)

    local slider = CreateFrame("Slider", "MPlateSlider_" .. sliderKey, parent)
    slider:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 4, -10)
    slider:SetSize(200, 16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(sliderMin, sliderMax)
    slider:SetValueStep(sliderStep)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(false)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    track:SetSize(200, 8)
    track:SetPoint("CENTER")

    local minLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    minLabel:SetText(sliderMin)

    local maxLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    maxLabel:SetText(sliderMax)

    local valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetPoint("LEFT", slider, "RIGHT", 20, 0)
    resetBtn:SetSize(120, 22)
    resetBtn:SetText(L["ResetCategory"])
    resetBtn:SetScript("OnClick", function()
        resetVal()
        slider:SetValue(getVal())
        valueText:SetText(formatVal())
        ns:RefreshAllNameplates()
    end)

    slider:SetValue(getVal())
    valueText:SetText(formatVal())

    slider:SetScript("OnValueChanged", function(self, value)
        value = RoundToStep(value, sliderStep)
        setVal(value)
        valueText:SetText(formatVal())
        ns:RefreshAllNameplates()
    end)

    sliders[sliderKey] = {
        slider = slider,
        valueText = valueText,
        getVal = getVal,
        formatVal = formatVal,
    }

    local rowAnchor = CreateFrame("Frame", nil, parent)
    rowAnchor:SetSize(1, 1)
    rowAnchor:SetPoint("TOPLEFT", minLabel, "BOTTOMLEFT", -4, 0)
    return rowAnchor
end

local function CreateCheckboxRow(parent, checkboxKey, label, anchor, offsetY, getVal, setVal, resetVal)
    local checkbox = CreateFrame("CheckButton", "MPlateCheckbox_" .. checkboxKey, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)

    local nameText = checkbox.text or checkbox.Text
    if nameText then
        nameText:SetFontObject("GameFontNormal")
        nameText:SetText(label)
    end

    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetPoint("LEFT", checkbox, "LEFT", 224, 0)
    resetBtn:SetSize(120, 22)
    resetBtn:SetText(L["ResetCategory"])
    resetBtn:SetScript("OnClick", function()
        resetVal()
        checkbox:SetChecked(getVal())
        ns:RefreshAllNameplates()
    end)

    checkbox:SetChecked(getVal())
    checkbox:SetScript("OnClick", function(self)
        setVal(self:GetChecked())
        ns:RefreshAllNameplates()
    end)

    checkboxes[checkboxKey] = {
        checkbox = checkbox,
        getVal = getVal,
    }

    local rowAnchor = CreateFrame("Frame", nil, parent)
    rowAnchor:SetSize(1, 1)
    rowAnchor:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 0, -4)
    return rowAnchor
end

function ns:InitOptions()
    local panel = CreateFrame("Frame")
    panel:Hide()

    -- Scrollable container
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel)
    scrollFrame:SetPoint("TOPLEFT")
    scrollFrame:SetPoint("BOTTOMRIGHT")
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newScroll = current - delta * 40
        self:SetVerticalScroll(math.max(0, math.min(newScroll, maxScroll)))
    end)

    local content = CreateFrame("Frame")
    content:SetSize(600, 900)
    scrollFrame:SetScrollChild(content)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["MPlate"])

    local desc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText(L["MPlate_Desc"])

    local labels = ns.categoryLabels()
    local lastAnchor = desc

    for _, key in ipairs(ns.categories) do
        lastAnchor = CreateSliderRow(content, key, labels[key], lastAnchor, -20,
            function() return GetEffectiveFontSize(key) end,
            function(value)
                local sys = ns.systemFontSize or 14
                if value == sys then
                    MPlateDB.fontSize[key] = nil
                else
                    MPlateDB.fontSize[key] = value
                end
            end,
            function() MPlateDB.fontSize[key] = nil end,
            function() return FormatFontValueText(key) end
        )
    end

    lastAnchor = CreateSliderRow(content, "castBarFontSize", L["CastBarFontSize"], lastAnchor, -20,
        GetEffectiveCastBarFontSize,
        function(value)
            local sys = ns.systemCastBarFontSize or 12
            if value == sys then
                MPlateDB.castBarFontSize = nil
            else
                MPlateDB.castBarFontSize = value
            end
        end,
        function() MPlateDB.castBarFontSize = nil end,
        FormatCastBarValueText
    )

    lastAnchor = CreateSliderRow(content, "healthBarWidthDelta", L["HealthBarWidthDelta"], lastAnchor, -20,
        function() return MPlateDB.healthBarWidthDelta or 0 end,
        function(value)
            if value == 0 then
                MPlateDB.healthBarWidthDelta = nil
            else
                MPlateDB.healthBarWidthDelta = value
            end
        end,
        function() MPlateDB.healthBarWidthDelta = nil end,
        function()
            local v = MPlateDB.healthBarWidthDelta
            if v then
                return tostring(v)
            else
                return L["SystemDefault"] .. " (0)"
            end
        end,
        -100, 100, 1
    )

    lastAnchor = CreateSliderRow(content, "healthBarHeightDelta", L["HealthBarHeightDelta"], lastAnchor, -20,
        function() return MPlateDB.healthBarHeightDelta or 0 end,
        function(value)
            if value == 0 then
                MPlateDB.healthBarHeightDelta = nil
            else
                MPlateDB.healthBarHeightDelta = value
            end
        end,
        function() MPlateDB.healthBarHeightDelta = nil end,
        function()
            local v = MPlateDB.healthBarHeightDelta
            if v then
                return tostring(v)
            else
                return L["SystemDefault"] .. " (0)"
            end
        end,
        -10, 30, 1
    )

    lastAnchor = CreateSliderRow(content, "healthTextOffset", L["HealthTextOffset"], lastAnchor, -20,
        function() return MPlateDB.healthTextOffset or 0 end,
        function(value)
            if value == 0 then
                MPlateDB.healthTextOffset = nil
            else
                MPlateDB.healthTextOffset = value
            end
        end,
        function() MPlateDB.healthTextOffset = nil end,
        function()
            local offset = MPlateDB.healthTextOffset
            if offset then
                return tostring(offset)
            else
                return L["SystemDefault"] .. " (0)"
            end
        end,
        0, 100, 1
    )

    lastAnchor = CreateSliderRow(content, "healthTextYOffset", L["HealthTextYOffset"], lastAnchor, -20,
        function() return MPlateDB.healthTextYOffset or 0 end,
        function(value)
            if value == 0 then
                MPlateDB.healthTextYOffset = nil
            else
                MPlateDB.healthTextYOffset = value
            end
        end,
        function() MPlateDB.healthTextYOffset = nil end,
        function()
            local offset = MPlateDB.healthTextYOffset
            if offset then
                return tostring(offset)
            else
                return L["SystemDefault"] .. " (0)"
            end
        end,
        -50, 50, 1
    )

    lastAnchor = CreateSliderRow(content, "enemyNameWidthIncrease", L["EnemyNameWidthIncrease"], lastAnchor, -20,
        function() return MPlateDB.enemyNameWidthIncrease or 0 end,
        function(value)
            if value == 0 then
                MPlateDB.enemyNameWidthIncrease = nil
            else
                MPlateDB.enemyNameWidthIncrease = value
            end
        end,
        function() MPlateDB.enemyNameWidthIncrease = nil end,
        function()
            local v = MPlateDB.enemyNameWidthIncrease
            if v then
                return tostring(v)
            else
                return L["SystemDefault"] .. " (0)"
            end
        end,
        0, 200, 1
    )

    lastAnchor = CreateCheckboxRow(content, "healthBarBorderHidden", L["HealthBarBorderHidden"], lastAnchor, -20,
        function() return MPlateDB.healthBarBorderHidden == true end,
        function(v) MPlateDB.healthBarBorderHidden = v or nil end,
        function() MPlateDB.healthBarBorderHidden = nil end
    )

    local resetAllBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetAllBtn:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", -4, -24)
    resetAllBtn:SetSize(200, 26)
    resetAllBtn:SetText(L["ResetAll"])
    resetAllBtn:SetScript("OnClick", function()
        for _, key in ipairs(ns.categories) do
            MPlateDB.fontSize[key] = nil
        end
        MPlateDB.castBarFontSize = nil
        MPlateDB.healthBarWidthDelta = nil
        MPlateDB.healthBarHeightDelta = nil
        MPlateDB.healthTextOffset = nil
        MPlateDB.healthTextYOffset = nil
        MPlateDB.enemyNameWidthIncrease = nil
        MPlateDB.healthBarBorderHidden = nil
        ns:RefreshOptionsSliders()
        ns:RefreshOptionsCheckboxes()
        ns:RefreshAllNameplates()
    end)

    panel:SetScript("OnShow", function()
        content:SetWidth(scrollFrame:GetWidth())
        ns:RefreshOptionsSliders()
        ns:RefreshOptionsCheckboxes()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, L["MPlate"])
    ns.settingsCategoryID = category:GetID()
    Settings.RegisterAddOnCategory(category)
end

function ns:RefreshOptionsSliders()
    ns.UpdateSystemFontSize()
    for _, data in pairs(sliders) do
        data.slider:SetValue(data.getVal())
        data.valueText:SetText(data.formatVal())
    end
end

function ns:RefreshOptionsCheckboxes()
    for _, data in pairs(checkboxes) do
        data.checkbox:SetChecked(data.getVal())
    end
end
