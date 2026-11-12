-- Run from the addon root with Lua 5.1:
-- lua tests/world_name_size_options.lua
-- Loads the actual locales and options; mocks only the frame and CVar boundary.
local cases = 0
local function session(current, default, locale, selected)
    local state = { current = current, default = default, writes = {}, messages = {}, frames = {}, refreshes = 0 }
    state.selected = selected or {}
    state.selected.writes = {}
    local env = setmetatable({}, { __index = _G })
    local methods = {}
    local function node(kind, name)
        local item = setmetatable({ kind = kind, name = name, points = {}, scripts = {}, enabled = true }, { __index = methods })
        state.frames[#state.frames + 1] = item
        if name then env[name] = item end
        return item
    end
    function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function methods:ClearAllPoints() self.points = {} end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetWidth(w) self.width = w end
    function methods:GetWidth() return self.width or 600 end
    function methods:SetText(value) self.text = value end
    function methods:SetScript(event, callback) self.scripts[event] = callback end
    function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function methods:SetValueStep(step) self.step = step end
    function methods:SetValue(value)
        self.value = math.min(self.maximum, math.max(self.minimum, value))
        -- Deliberately notify even on unchanged values, exercising refresh guards.
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, self.value) end
    end
    function methods:SetEnabled(value) self.enabled = value end
    function methods:SetChecked(value) self.checked = value end
    function methods:GetChecked() return self.checked end
    function methods:CreateFontString() return node("FontString") end
    function methods:CreateTexture() return node("Texture") end
    for _, name in ipairs({ "Hide", "SetOrientation", "SetObeyStepOnDrag", "EnableMouseWheel",
        "SetThumbTexture", "SetTexture", "SetScrollChild", "SetFontObject", "SetJustifyH", "SetWordWrap" }) do
        methods[name] = function() end
    end
    env.CreateFrame = node
    env.GetLocale = function() return locale or "enUS" end
    env.InCombatLockdown = function() return state.combat end
    env.print = function(message) state.messages[#state.messages + 1] = message end
    env.MPlateDB = { fontSize = { enemy = 22 }, castBarFontSize = 18, healthBarWidthDelta = 30 }
    local function cvarState(name)
        if name == "nameplateSelectedScale" then return state.selected end
        assert(name == "WorldTextMinSize", "Accessed unrelated CVar")
        return state
    end
    env.C_CVar = {
        GetCVar = function(name)
            local item = cvarState(name)
            if item.readError then error("Read unavailable") end
            return item.current
        end,
        GetCVarDefault = function(name)
            local item = cvarState(name)
            if item.defaultError then error("Default unavailable") end
            return item.default
        end,
        SetCVar = function(name, value)
            local item = cvarState(name)
            item.writes[#item.writes + 1] = value
            if item.writeMode == "error" then error("Write restricted") end
            if item.writeMode == "reject" then return false end
            if item.writeMode ~= "ignore" then item.current = tostring(value) end
            return true
        end,
    }
    env.Settings = {
        RegisterCanvasLayoutCategory = function(panel)
            state.panel = panel
            return { GetID = function() return 1 end }
        end,
        RegisterAddOnCategory = function() end,
    }
    local ns = {
        systemFontSize = 14, systemCastBarFontSize = 12, systemLevelFontSize = 10,
        UpdateSystemFontSize = function() end,
        RefreshAllNameplates = function() state.refreshes = state.refreshes + 1 end,
    }
    for _, path in ipairs({ "Locales/enUS.lua", "Locales/zhCN.lua", "Init.lua", "Options.lua" }) do
        setfenv(assert(loadfile(path)), env)("MPlate", ns)
    end
    state.env, state.ns = env, ns
    function state:init()
        ns:InitOptions()
        self.slider = env.MPlateSlider_worldNameMinSize
        self.selectedSlider = env.MPlateSlider_selectedScale
        for _, item in ipairs(self.frames) do
            local point = item.points[1]
            if self.slider and point and point[2] == self.slider then
                if item.kind == "Button" then self.reset = item end
                if item.kind == "FontString" and point[1] == "TOP" then self.valueText = item end
            end
            if self.selectedSlider and point and point[2] == self.selectedSlider then
                if item.kind == "Button" then self.selectedReset = item end
                if item.kind == "FontString" and point[1] == "TOP" then self.selectedText = item end
            end
            if item.kind == "Button" and item.text == ns.L.ResetAll then self.resetAll = item end
        end
    end
    function state:open() self.panel.scripts.OnShow(self.panel) end
    function state:click(button)
        assert(button.enabled, "Attempt to click a disabled control")
        button.scripts.OnClick(button)
    end
    return state
end

for _, locale in ipairs({ "enUS", "zhCN" }) do
    for _, current in ipairs({ "0.000000", "20", "32", "21.5", "80" }) do
        local s = session(current, "0", locale)
        s:init()
        assert(s.slider.minimum == 0 and s.slider.maximum == 64 and s.slider.step == 2)
        for _ = 1, 3 do s:open() end
        assert(#s.writes == 0 and s.current == current, "Opening panel overwrote game setting")
        assert(s.valueText.text == tostring(tonumber(current)), "Did not show actual external value")
        assert(s.env.MPlateDB.fontSize.enemy == 22 and s.env.MPlateDB.healthBarWidthDelta == 30)
        assert(s.refreshes == 0, "Opening panel refreshed nameplates")
        s.current = "27.5"
        s:open()
        assert(s.valueText.text == "27.5" and #s.writes == 0)
        s.slider:SetValue(29)
        assert(#s.writes == 1 and tonumber(s.current) == 30 and s.slider.value == 30)
        assert(s.refreshes == 0, "CVar slider unnecessarily refreshed nameplates")
        -- Default is intentionally nonzero and not on the slider step.
        s.default = "7.5"
        s:click(s.reset)
        assert(#s.writes == 2 and tonumber(s.current) == 7.5 and s.valueText.text == "7.5")
        s:click(s.resetAll)
        assert(#s.writes == 3 and tonumber(s.current) == 7.5)
        assert(s.env.MPlateDB.fontSize.enemy == nil and s.env.MPlateDB.healthBarWidthDelta == nil)
        assert(s.env.MPlateSlider_enemy.value == 14 and s.env.MPlateSlider_castBarFontSize.value == 12)
        assert(s.env.MPlateDB.worldNameMinSize == nil, "Duplicated game setting in SavedVariables")
        cases = cases + 1
    end
end

for _, invalid in ipairs({ false, "bad", "nan", "inf" }) do
    local s = session(invalid, "0")
    s:init()
    s:open()
    assert(not s.slider, "Created control for unavailable CVar")
    s:click(s.resetAll)
    assert(#s.writes == 0 and #s.messages == 0)
    cases = cases + 1
end
for _, missing in ipairs({ "api", "parameter", "getter", "readError" }) do
    local s = session("20", "0")
    if missing == "api" then s.env.C_CVar = false end
    if missing == "parameter" then s.current = nil end
    if missing == "getter" then s.env.C_CVar.GetCVar = nil end
    if missing == "readError" then s.readError = true end
    s:init()
    s:open()
    s:click(s.resetAll)
    assert(not s.slider and #s.writes == 0)
    cases = cases + 1
end

for _, failure in ipairs({ "error", "ignore", "reject", "noSetter" }) do
    local s = session("20", "0")
    s:init()
    s.writeMode = failure
    if failure == "noSetter" then s.env.C_CVar.SetCVar = nil end
    s.slider:SetValue(32)
    assert(tonumber(s.current) == 20 and s.slider.value == 20 and s.valueText.text == "20")
    assert(#s.messages == 1, "Failed write did not report failure")
    -- Retry only on the next explicit interaction.
    s.writeMode = nil
    if failure ~= "noSetter" then
        s.slider:SetValue(32)
        assert(tonumber(s.current) == 32 and #s.messages == 1)
    end
    cases = cases + 1
end

for _, missingDefault in ipairs({ "value", "api", "error" }) do
    local s = session("20", nil)
    if missingDefault == "api" then s.env.C_CVar.GetCVarDefault = nil end
    if missingDefault == "error" then s.defaultError = true end
    s:init()
    assert(not s.reset.enabled, "Enabled reset without a real game default")
    s:click(s.resetAll)
    assert(#s.writes == 0 and s.current == "20" and #s.messages == 1)
    assert(s.env.MPlateDB.fontSize.enemy == nil, "Failed CVar reset blocked other resets")
    cases = cases + 1
end

local s = session("20", "0")
s:init()
s.current = nil
s:open()
assert(not s.slider.enabled and not s.reset.enabled and s.valueText.text == s.ns.L.Unavailable)
s:click(s.resetAll)
assert(#s.writes == 0 and #s.messages == 1)
s.current = "32"
s:open()
assert(s.slider.enabled and s.reset.enabled and s.slider.value == 32)
s.writeMode = "error"
s:click(s.resetAll)
assert(#s.messages == 2 and s.valueText.text == "32")
assert(s.env.MPlateDB.fontSize.enemy == nil)
cases = cases + 1

local rejected = session("20", "20")
rejected:init()
rejected.writeMode = "reject"
rejected:click(rejected.reset)
assert(#rejected.messages == 1, "Ignored explicit API failure when readback already matched")
cases = cases + 1

-- Existing font interactions still mutate their DB entry and reset cleanly.
local old = session("20", "0")
old:init()
old.env.MPlateSlider_enemy:SetValue(25)
assert(old.env.MPlateDB.fontSize.enemy == 25 and old.refreshes == 1)
old:click(old.resetAll)
assert(old.env.MPlateDB.fontSize.enemy == nil and old.env.MPlateSlider_enemy.value == 14)
cases = cases + 1
print("world name size options: " .. cases .. " behavior cases passed")

for _, locale in ipairs({ "enUS", "zhCN" }) do
    local level = session("20", "0", locale)
    level:init()
    local slider = level.env.MPlateSlider_levelFontSize
    assert(slider.minimum == 8 and slider.maximum == 36 and slider.step == 1)
    level:open()
    assert(slider.value == 10 and level.env.MPlateDB.levelFontSize == nil and level.refreshes == 0)
    local reset, label
    for _, item in ipairs(level.frames) do
        local point = item.points[1]
        if point and point[2] == slider then
            if item.kind == "Button" then reset = item end
            if item.kind == "FontString" and point[1] == "TOP" then label = item end
        end
    end
    slider:SetValue(24)
    assert(level.env.MPlateDB.levelFontSize == 24 and level.refreshes == 1)
    assert(level.env.MPlateDB.fontSize.enemy == 22 and level.env.MPlateDB.castBarFontSize == 18)
    assert(level.env.MPlateDB.healthBarWidthDelta == 30 and #level.writes == 0)
    level:open()
    assert(slider.value == 24 and level.refreshes == 1)
    -- Choosing the current default still means fixed size until explicitly reset.
    slider:SetValue(10)
    level.ns.systemLevelFontSize = 12.5
    level:open()
    assert(slider.value == 10 and level.env.MPlateDB.levelFontSize == 10)
    level:click(reset)
    assert(level.env.MPlateDB.levelFontSize == nil and slider.value == 12.5)
    assert(label.text == string.format(level.ns.L.LevelHealthDefault, "12.5", "14"))
    assert(level.env.MPlateDB.fontSize.enemy == 22)
    slider:SetValue(36)
    level:click(level.resetAll)
    assert(level.env.MPlateDB.levelFontSize == nil and slider.value == 12.5)
    -- Reopening with a saved choice reads it without rewriting or refreshing plates.
    local restored = session("20", "0", locale)
    restored.env.MPlateDB.levelFontSize = 28
    restored:init()
    restored:open()
    assert(restored.env.MPlateSlider_levelFontSize.value == 28 and restored.refreshes == 0)
end
print("level and health text options: both locales passed default, fixed size, reopen and reset checks")

local scaleCases = 0
for _, locale in ipairs({ "enUS", "zhCN" }) do
    for _, current in ipairs({ "0.5", "1.000000", "1.200000", "1.237", "2", "2.5" }) do
        local s = session("20", "0", locale, { current = current, default = "1.15" })
        s:init()
        local slider = s.selectedSlider
        assert(slider.minimum == 0.5 and slider.maximum == 2 and slider.step == 0.05)
        for _ = 1, 3 do s:open() end
        assert(#s.selected.writes == 0 and #s.writes == 0 and s.refreshes == 0)
        assert(s.selected.current == current and s.selectedText.text == tostring(tonumber(current)) .. "x")
        s.selected.current = "1.333"
        s:open()
        assert(s.selectedText.text == "1.333x" and #s.selected.writes == 0)
        slider:SetValue(1.27)
        assert(tonumber(s.selected.current) == 1.25 and #s.selected.writes == 1)
        assert(#s.writes == 0 and s.refreshes == 0 and s.env.MPlateDB.healthBarWidthDelta == 30)
        s:click(s.selectedReset)
        assert(math.abs(tonumber(s.selected.current) - 1.15) < 0.00001 and #s.selected.writes == 2)
        s.selected.default = "1.175"
        s:click(s.resetAll)
        assert(tonumber(s.selected.current) == 1.175 and #s.selected.writes == 3)
        assert(s.env.MPlateDB.fontSize.enemy == nil and s.env.MPlateDB.healthBarWidthDelta == nil)
        assert(s.env.MPlateDB.selectedScale == nil, "Duplicated CVar in SavedVariables")
        scaleCases = scaleCases + 1
    end
end

for _, invalid in ipairs({ false, "invalid", "nan", "inf", "0", "-1" }) do
    local s = session("20", "0", nil, { current = invalid, default = "1.2" })
    s:init()
    s:open()
    assert(not s.selectedSlider)
    s:click(s.resetAll)
    assert(#s.selected.writes == 0 and #s.messages == 0)
    scaleCases = scaleCases + 1
end

for _, mode in ipairs({ "error", "reject", "ignore", "noSetter" }) do
    local s = session("20", "0", nil, { current = "1.2", default = "1.2", writeMode = mode })
    s:init()
    local setter = s.env.C_CVar.SetCVar
    if mode == "noSetter" then s.env.C_CVar.SetCVar = nil end
    s.selectedSlider:SetValue(1.5)
    assert(s.selectedSlider.value == 1.2 and s.selectedText.text == "1.2x" and #s.messages == 1)
    assert(tonumber(s.selected.current) == 1.2)
    s.selected.writeMode = nil
    s.env.C_CVar.SetCVar = setter
    s.selectedSlider:SetValue(1.5)
    assert(tonumber(s.selected.current) == 1.5)
    scaleCases = scaleCases + 1
end

for _, missing in ipairs({ "value", "api", "error" }) do
    local s = session("20", "0", nil, { current = "1.4" })
    if missing == "api" then s.env.C_CVar.GetCVarDefault = nil end
    if missing == "error" then s.selected.defaultError = true end
    s:init()
    assert(not s.selectedReset.enabled)
    s:click(s.resetAll)
    assert(s.selected.current == "1.4" and #s.selected.writes == 0)
    assert(s.messages[#s.messages] == "|cff00ccff[MPlate]|r " .. s.ns.L.SelectedScaleDefaultUnavailable)
    assert(s.env.MPlateDB.fontSize.enemy == nil)
    scaleCases = scaleCases + 1
end

local combat = session("20", "0", nil, { current = "1.2", default = "1.1" })
combat:init()
combat.combat = true
combat.selectedSlider:SetValue(1.5)
assert(#combat.selected.writes == 0 and combat.selectedSlider.value == 1.2)
combat:click(combat.selectedReset)
combat:click(combat.resetAll)
assert(#combat.selected.writes == 0 and #combat.messages == 3)
assert(combat.env.MPlateDB.fontSize.enemy == nil and tonumber(combat.current) == 0)
combat.combat = false
combat:open()
assert(#combat.selected.writes == 0, "Queued combat change unexpectedly applied")
combat.selectedSlider:SetValue(1)
assert(tonumber(combat.selected.current) == 1)
combat.selected.current = nil
combat:open()
assert(not combat.selectedSlider.enabled and not combat.selectedReset.enabled)
combat.selected.current = "1.3"
combat:open()
assert(combat.selectedSlider.enabled and combat.selectedSlider.value == 1.3)
combat.selected.readError = true
combat:open()
assert(not combat.selectedSlider.enabled and combat.selectedText.text == combat.ns.L.Unavailable)
scaleCases = scaleCases + 1
print("selected nameplate scale: " .. scaleCases .. " behavior cases passed")
