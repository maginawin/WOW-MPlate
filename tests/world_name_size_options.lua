-- Run from the addon root with Lua 5.1:
-- lua tests/world_name_size_options.lua
-- Loads the actual locales and options; mocks only the frame and CVar boundary.
local cases = 0
local function session(current, default, locale)
    local state = { current = current, default = default, writes = {}, messages = {}, frames = {}, refreshes = 0 }
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
    env.print = function(message) state.messages[#state.messages + 1] = message end
    env.MPlateDB = { fontSize = { enemy = 22 }, castBarFontSize = 18, healthBarWidthDelta = 30 }
    env.C_CVar = {
        GetCVar = function(name)
            assert(name == "WorldTextMinSize", "Read unrelated CVar")
            if state.readError then error("Read unavailable") end
            return state.current
        end,
        GetCVarDefault = function(name)
            assert(name == "WorldTextMinSize")
            if state.defaultError then error("Default unavailable") end
            return state.default
        end,
        SetCVar = function(name, value)
            assert(name == "WorldTextMinSize", "Changed unrelated game setting")
            state.writes[#state.writes + 1] = value
            if state.writeMode == "error" then error("Write restricted") end
            if state.writeMode == "reject" then return false end
            if state.writeMode ~= "ignore" then state.current = tostring(value) end
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
        systemFontSize = 14, systemCastBarFontSize = 12,
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
        for _, item in ipairs(self.frames) do
            local point = item.points[1]
            if self.slider and point and point[2] == self.slider then
                if item.kind == "Button" then self.reset = item end
                if item.kind == "FontString" and point[1] == "TOP" then self.valueText = item end
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
