-- The grid: the roster, the events, the test grid, moving it, and the game's
-- own party frames and group grid kept out of the way while it is on.
local _, R = ...
if not R.apply then return end

local db = FostercareRaidDB
local RAID, PARTY = {}, { "party1", "party2", "party3", "party4" }
for i = 1, 40 do RAID[i] = "raid" .. i end
-- While a member shows: only its own unit events (### frame:RegisterUnitEvent).
local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_IN_RANGE_UPDATE", "UNIT_AURA_DELTA" }

local grid = CreateFrame("Frame", "FostercareRaidFrame", UIParent)
grid:SetMovable(true)
grid:SetClampedToScreen(true)
grid:SetFrameStrata("LOW")
grid:Hide()

local buttons, count = {}, {} -- buttons[g][m]; members per group in this pass
local units, byUnit = {}, {}   -- the shown members' tokens; token -> button
local test, owned, pending

-- Every button made so far, as fn(button, group, member).
local function Each(fn)
    for g, list in pairs(buttons) do
        for m, b in pairs(list) do fn(b, g, m) end
    end
end

local function Spot(b, g, m)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", grid, "TOPLEFT", (g - 1) * (db.width + db.gapX), -(m - 1) * (db.height + db.gapY))
end

local function Get(g, m)
    buttons[g] = buttons[g] or {}
    if not buttons[g][m] then
        buttons[g][m] = R.NewButton(grid, "FostercareRaidG" .. g .. "M" .. m)
        Spot(buttons[g][m], g, m)
    end
    return buttons[g][m]
end

local function Clear(b)
    if not b.unit and not b:IsShown() then return end
    b.unit, b.name = nil, nil
    b:SetAttribute("unit", nil)
    b:Hide()
end

local function Hostile()
    return db.aggro and UnitCanAttack("player", "target") and UnitExists("targettarget") and true or false
end

-- A member's button changes only when its member, name, rank or online state did.
local function Assign(g, unit, name, class, rank, online)
    local m = count[g] + 1
    if m > 5 then return end
    count[g] = m
    local b = Get(g, m)
    units[#units + 1], byUnit[unit] = unit, b
    if b.unit == unit and b.name == name and b.rank == rank and b.online == online and b:IsShown() then return end
    b.unit, b.name, b.class, b.rank, b.online = unit, name, class, rank, online
    b:SetAttribute("unit", unit)
    b:Show()
    R.Refresh(b, Hostile())
end

-- Unit events for exactly the shown members; the group's own events only in a group.
local function Listen()
    local on = #units > 0
    for _, e in ipairs(UNIT_EVENTS) do
        if on then grid:RegisterUnitEvent(e, unpack(units)) else grid:UnregisterEvent(e) end
    end
    for _, e in ipairs({ "PARTY_LEADER_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED" }) do
        if on and (db.aggro or e ~= "PLAYER_TARGET_CHANGED") then grid:RegisterEvent(e) else grid:UnregisterEvent(e) end
    end
    if on and db.aggro then grid:RegisterUnitEvent("UNIT_TARGET", "target") else grid:UnregisterEvent("UNIT_TARGET") end
end

-- The holder's size and scale, its top left kept on screen through a scale change.
local function Fit(columns, rows)
    local old, left, top = grid:GetScale(), grid:GetLeft(), grid:GetTop()
    grid:SetScale(db.scale)
    grid:ClearAllPoints()
    if left and grid:IsUserPlaced() then
        grid:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * old / db.scale, top * old / db.scale)
    else -- until the player moves it; then the client saves it (### frame:SetDontSavePosition)
        grid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -180)
    end
    grid:SetWidth(math.max(1, columns * (db.width + db.gapX) - db.gapX))
    grid:SetHeight(math.max(1, rows * (db.height + db.gapY) - db.gapY))
end

-- Everyone in the group, raid groups as columns, the party as one.
local function Roster()
    pending = nil
    if test or not db.enabled then return end
    for g = 1, 8 do count[g] = 0 end
    table.wipe(units)
    table.wipe(byUnit)
    local raid = GetNumRaidMembers()
    if raid > 0 then
        for i = 1, raid do
            local name, rank, group, _, _, class, _, online = GetRaidRosterInfo(i)
            Assign(group, RAID[i], name, class, rank, online and true or false)
        end
    elseif GetNumPartyMembers() > 0 then
        Assign(1, "player", UnitName("player"), nil, UnitIsPartyLeader("player") and 2 or 0, true)
        for i = 1, GetNumPartyMembers() do
            local unit = PARTY[i]
            Assign(1, unit, UnitName(unit), nil, UnitIsPartyLeader(unit) and 2 or 0, UnitIsConnected(unit) and true or false)
        end
    end
    local rows = 0
    Each(function(b, g, m)
        if m > count[g] then Clear(b) end
        rows = math.max(rows, count[g])
    end)
    Listen()
    Fit(raid > 0 and 8 or 1, rows)
    grid:SetShown(rows > 0)
end

-- Roster events come in bursts (a battleground filling): one pass, next frame.
local function Soon()
    if not pending then pending = true; C_Timer.After(0, Roster) end
end

grid:SetScript("OnEvent", function(_, e, unit, a2)
    local b = byUnit[unit]
    if b then
        if e == "UNIT_HEALTH" or e == "UNIT_MAXHEALTH" then R.Health(b)
        elseif e == "UNIT_AURA_DELTA" then R.AuraDelta(b, a2)
        elseif e == "UNIT_IN_RANGE_UPDATE" then R.Range(b, a2)
        elseif e == "UNIT_NAME_UPDATE" then R.Identity(b)
        elseif e == "UNIT_CONNECTION" then R.Health(b); R.Range(b, UnitInRange(unit))
        else R.Power(b) end
    elseif e == "PLAYER_TARGET_CHANGED" or e == "UNIT_TARGET" then
        local hostile = Hostile()
        for _, member in pairs(byUnit) do R.Aggro(member, hostile) end
    elseif e == "RAID_TARGET_UPDATE" then
        for token, member in pairs(byUnit) do R.Mark(member, GetRaidTargetIndex(token)) end
    else
        Soon() -- the roster, the leader, a loading screen
    end
end)

-- The stock party frames and the client's grid (Turtle_GroupUI, FrameXML) ------

for i = 1, 4 do
    _G["PartyMemberFrame" .. i]:HookScript("OnShow", function(frame) if owned then frame:Hide() end end)
end

-- Its saved choice (GROUP_ENABLED) is left alone. Its one-time setup at the
-- first PLAYER_ENTERING_WORLD still runs (Turtle_GroupUI.lua 299-330); then
-- these do nothing while ours is on. Its options call them by name (OptionsFrame.lua 111).
local nativeToggle = GroupFrame_Toggle
for _, name in ipairs({ "GroupFrame_Toggle", "GroupFrame_Update", "GroupFrame_UpdateLayout" }) do
    local native = _G[name]
    _G[name] = function(a) if not owned then return native(a) end end
end

-- Its member and pet frames' events and range OnUpdate stop (Turtle_GroupUI.lua
-- 182, 521-535, 669-678), and come back when ours goes.
local function Members(on)
    for i = 1, 80 do
        local pet = i > 40
        local frame = _G[pet and "GroupPetsClusterFramePet" .. (i - 40)
            or "GroupClusterFrame" .. math.ceil(i / 5) .. "MemberFrame" .. ((i - 1) % 5 + 1)]
        if frame and on then
            frame:UnregisterAllEvents()
            frame:SetScript("OnUpdate", nil)
            frame.unit = nil
            frame:Hide()
        elseif pet and frame then
            frame:RegisterEvent("UNIT_HEALTH")
        elseif frame then
            local old = this
            this = frame
            GroupMemberFrame_OnLoad()
            this = old
        end
    end
end

local function Own(on)
    if owned == on then return end
    owned = on
    Members(on)
    if not on then return nativeToggle() end -- its grid back as its option says, and the party frames
    GroupFrame:UnregisterAllEvents()
    GroupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    GroupFrame:Hide()
    for g = 1, 8 do _G["GroupClusterFrame" .. g]:Hide() end
    GroupPetsClusterFrame:Hide()
    HidePartyFrame()
end

-- The page ---------------------------------------------------------------------

function R.apply.enabled()
    Own(db.enabled)
    if db.enabled then
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED" }) do
            grid:RegisterEvent(e)
        end
        return Roster()
    end
    test = nil
    grid:UnregisterAllEvents()
    Each(Clear)
    table.wipe(units)
    table.wipe(byUnit)
    grid:Hide()
end

-- The test grid: 40 sample members to set the sizes by. `again` redraws it.
function R.Test(again)
    if not again then test = not test end
    table.wipe(units)
    table.wipe(byUnit)
    for g = 1, 8 do
        for m = 1, 5 do
            local b = Get(g, m)
            Clear(b)
            if test then b:Show(); R.Sample(b, g, m) end
        end
    end
    if not test then return Roster() end
    Listen()
    Fit(8, 5)
    grid:Show()
end

-- Every other row: each button laid out and drawn again.
local function Redraw()
    Each(function(b, g, m) R.Size(b); Spot(b, g, m) end)
    if test then return R.Test(true) end
    Roster()
    local hostile = Hostile()
    for _, b in pairs(byUnit) do R.Auras(b); R.Aggro(b, hostile) end
end
for key in pairs(R.DEFAULTS) do R.apply[key] = R.apply[key] or Redraw end

-- Ctrl+Shift shows a handle over the grid; dragging it moves the grid.
local handle = CreateFrame("Frame", nil, grid)
handle:SetAllPoints(grid)
handle:SetFrameStrata("DIALOG")
handle:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
handle:SetBackdropColor(0.2, 0.6, 1, 0.45)
handle:EnableMouse(true)
handle:Hide()
handle:SetScript("OnMouseDown", function() grid:StartMoving() end)
handle:SetScript("OnMouseUp", function() grid:StopMovingOrSizing() end)
handle:SetScript("OnEvent", function()
    local held = IsShiftKeyDown() and IsControlKeyDown() and true or false
    if not held then grid:StopMovingOrSizing() end -- the keys let go while dragging
    handle:SetShown(held)
end)
grid:SetScript("OnShow", function() handle:RegisterEvent("MODIFIER_STATE_CHANGED") end)
grid:SetScript("OnHide", function() handle:UnregisterEvent("MODIFIER_STATE_CHANGED"); handle:Hide() end)

R.apply.enabled()
