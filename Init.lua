local addonName, ns = ...

ns.addonName = addonName

ns.categories = { "enemy" }

ns.categoryLabels = function()
    local L = ns.L
    return {
        enemy = L["AllNameplateText"],
    }
end
