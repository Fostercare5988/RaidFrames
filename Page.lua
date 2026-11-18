-- The RaidFrames page in ClassicAPI's Settings window (AddOn Options, or /fraid).
local _, R = ...
if not R.apply then return end

local db = RaidFramesDB
local category

-- In play order: a section header, then its rows. A slider is { key, name, tip, low, high, step };
-- `under` names the switch a row greys out with.
local PAGE = {
    { "enabled", "Use the grid", "One grid for party and raid, in place of the party frames and the game's group frames." },
    "Size",
    { "width", "Width", "How wide each member is.", 40, 120, 1 },
    { "height", "Height", "How tall each member is.", 20, 60, 1 },
    { "scale", "Scale", "How large the whole grid is.", 0.5, 2, 0.05 },
    { "gapX", "Gap across", "The space between groups.", 0, 20, 1 },
    { "gapY", "Gap down", "The space between members of a group.", 0, 20, 1 },
    "Corners",
    { "aggro", "Aggro corner", "A red corner on the member your enemy target is attacking." },
    { "hots", "Heal-over-time corner", "A corner with the icon of a heal over time or a shield on the member." },
    "Icons",
    { "buffs", "Buffs", "Buff icons inside each member; heals and your own first." },
    { "buffCount", "Buffs per member", "At most this many; +N counts the rest.", 1, 8, 1, under = "buffs" },
    { "buffSize", "Buff size", "The size of the buff icons.", 8, 18, 1, under = "buffs" },
    { "debuffs", "Debuffs", "Debuff icons inside each member; dispellable ones first." },
    { "debuffCount", "Debuffs per member", "At most this many; +N counts the rest.", 1, 8, 1, under = "debuffs" },
    { "debuffSize", "Debuff size", "The size of the debuff icons.", 8, 18, 1, under = "debuffs" },
}

SettingsRegistrar:AddRegistrant(function()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("RaidFrames")
    local rows = {}
    for _, row in ipairs(PAGE) do
        if type(row) == "string" then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(row))
        else
            local key, name, tip, low, high, step = row[1], row[2], row[3], row[4], row[5], row[6]
            local kind = low and Settings.VarType.Number or Settings.VarType.Boolean
            local setting = Settings.RegisterAddOnSetting(category, "RaidFrames_" .. key, key, db, kind, name,
                R.DEFAULTS[key])
            setting:SetValueChangedCallback(R.apply[key])
            local init
            if low then
                local options = Settings.CreateSliderOptions(low, high, step)
                options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
                init = Settings.CreateSlider(category, setting, options, tip)
            else
                init = Settings.CreateCheckbox(category, setting, tip)
            end
            rows[key] = init
            local parent = row.under or key ~= "enabled" and "enabled"
            if parent then
                init:SetParentInitializer(rows[parent], function() return db.enabled and db[parent] end)
            end
        end
    end
    local sample = CreateSettingsButtonInitializer("Test grid", "Test grid", function() R.Test() end,
        "Show or hide 40 sample members, to set the sizes by.", false)
    sample:SetParentInitializer(rows.enabled, function() return db.enabled end)
    layout:AddInitializer(sample)
    Settings.RegisterAddOnCategory(category)
end)

SLASH_RAIDFRAMES1 = "/fraid"
SlashCmdList.RAIDFRAMES = function()
    if category then Settings.OpenToCategory(category:GetID()) end
end
