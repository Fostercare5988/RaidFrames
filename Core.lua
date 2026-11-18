-- RaidFrames: one grid for party and raid.
-- Doc headings are ClassicAPI's docs/API.md; "FrameXML" is the client's own code.
if not CLASSIC_API_VERSION then error("RaidFrames needs ClassicAPI.", 0) end

local _, R = ...
RaidFramesDB = RaidFramesDB or {} -- restored first: LoadSavedVariablesFirst
local db = RaidFramesDB

-- The page's switches and sliders, filled in here: the grid starts before the
-- Settings window registers the page.
R.DEFAULTS = { enabled = true, aggro = true, hots = true, buffs = true, debuffs = true,
    width = 58, height = 35, scale = 1.05, gapX = 2, gapY = 3,
    buffCount = 8, buffSize = 14, debuffCount = 8, debuffSize = 12 }
for key, value in pairs(R.DEFAULTS) do if db[key] == nil then db[key] = value end end

-- What a page row runs when its value changes: R.apply[key]().
R.apply = {}

-- A font string's text, written only when it changes.
function R.Text(fs, text)
    if fs.written ~= text then fs.written = text; fs:SetText(text) end
end
