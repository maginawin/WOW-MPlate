local addonName, ns = ...

if GetLocale() ~= "zhCN" then return end

local L = ns.L

L["MPlate_Desc"] = "自定义姓名板文字大小、生命条尺寸和边框显隐。"
L["AllNameplateText"] = "所有姓名板文字"
L["ResetAll"] = "全部重置为系统默认"
L["ResetCategory"] = "重置为系统默认"
L["SystemDefault"] = "系统默认"
L["CastBarFontSize"] = "施法条文字"
L["HealthTextOffset"] = "生命值文字右偏移"
L["HealthTextYOffset"] = "生命值文字垂直偏移"
L["EnemyNameWidthIncrease"] = "敌方姓名增加宽度"
L["HealthBarWidthDelta"] = "生命条宽度增量"
L["HealthBarHeightDelta"] = "生命条高度增量"
L["HealthBarBorderHidden"] = "隐藏生命条边框"
