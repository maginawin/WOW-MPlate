local addonName, ns = ...

if GetLocale() ~= "zhCN" then return end

local L = ns.L

L["MPlate_Desc"] = "自定义姓名板文字大小、生命条尺寸和边框显隐。"
L["AllNameplateText"] = "所有姓名板文字"
L["WorldNameMinSize"] = "头顶姓名最小尺寸"
L["WorldNameMinSizeDescription"] = "调节普通头顶姓名的最小尺寸，无需开启姓名板。全局生效，不能只调整友方玩家。0 表示不额外限制最小尺寸。全部重置也会恢复此项。"
L["Unavailable"] = "不可用"
L["WorldNameSizeWriteFailed"] = "头顶姓名尺寸未能应用，现显示游戏当前值。"
L["WorldNameSizeDefaultUnavailable"] = "无法读取游戏默认值，头顶姓名尺寸未重置。"
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
