-- Buff and debuff icons inside each member, and the heal-over-time corner.
-- Read with ClassicAPI's C_UnitAuras (the UnitAuras section); kept current by
-- UNIT_AURA_DELTA.
local _, R = ...
if not R.apply then return end

local db = RaidFramesDB
local GAP, DARK = 2, { r = 0.15, g = 0.15, b = 0.15 } -- the gap between icons; a buff's border

-- A heal over time or an absorb shield, by the spell's own effects: aura code 8
-- (periodic heal) or 69 (absorb) (### C_Spell.GetSpellEffectInfo). Asked once
-- per spell. UNVERIFIED: the two codes are the 1.12 client's aura list; the
-- docs give no names for the codes (NamPower's EVENTS.md uses the same list).
local heals = {}
local function Heal(id)
    if heals[id] == nil then
        local fx = C_Spell.GetSpellEffectInfo(id)
        heals[id] = false
        for i = 1, fx and 3 or 0 do
            if fx[i].auraName == 8 or fx[i].auraName == 69 then heals[id] = true end
        end
    end
    return heals[id]
end
local slots, yours = {}, {}
-- Debuffs you can dispel first, as Grid2 and VuhDo do: the spells of those
-- that pass the RAID filter ("only debuffs that you can dispel", ### Filter parsing).
local function Yours(id) return yours[id] == true end
local function LearnYours(unit)
    table.wipe(yours)
    local _, count = C_UnitAuras.GetAuraSlots(unit, "HARMFUL|RAID", nil, nil, slots)
    for i = 1, count do
        local id = select(10, C_UnitAuras.UnitAuraBySlot(unit, slots[i]))
        if id then yours[id] = true end
    end
end

-- A member's auras of one kind into `list` (records reused): those `first`
-- picks ahead, then the rest, each in the game's order, which puts your own
-- first (### Aura order). One GetAuraSlots call (### C_UnitAuras.GetAuraSlots).
local function Read(b, filter, list, first)
    local n, unit = 0, b.unit
    local _, count = C_UnitAuras.GetAuraSlots(unit, filter, nil, nil, slots)
    for pass = 1, 2 do
        for i = 1, count do
            local _, icon, stacks, dispel, duration, expires, source, _, _, id = C_UnitAuras.UnitAuraBySlot(unit, slots[i])
            if icon and first(id, dispel) == (pass == 1) then
                n = n + 1
                local a = list[n] or {}
                list[n] = a
                a.icon, a.stacks, a.dispel, a.duration, a.expires, a.source, a.id =
                    icon, stacks, dispel, duration, expires, source, id
            end
        end
    end
    list.n = n
end

local function NewIcon(b)
    local icon = CreateFrame("Frame", nil, b.health)
    icon:SetFrameLevel(b.health:GetFrameLevel() + 2)
    icon.border = icon:CreateTexture(nil, "BACKGROUND")
    icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    icon.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints(icon)
    icon.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- The client counts down (the Cooldown section).
    icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cd:SetAllPoints(icon)
    icon.cd:SetReverse(true)
    icon.cd:SetDrawBling(false)
    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 0)
    b.icons[#b.icons + 1] = icon
    return icon
end

-- The pool of icons (made as auras need them), the two lists and the corner.
function R.NewIcons(b)
    b.icons, b.buffs, b.debuffs = {}, { n = 0 }, { n = 0 }
    b.hot = b.health:CreateTexture(nil, "OVERLAY")
    b.hot:SetWidth(5); b.hot:SetHeight(5)
    b.hot:SetPoint("TOPLEFT", b.health, "TOPLEFT", 0, 0)
    b.hot:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    b.hot:Hide()
    b.more = b.health:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
end

-- Icon `i` showing record `a` at `size`, `x` from the bar's bottom `side`.
local function Show(b, i, a, size, side, x, debuff)
    local icon = b.icons[i] or NewIcon(b)
    if icon.size ~= size or icon.x ~= x then
        icon.size, icon.x = size, x
        icon:SetWidth(size); icon:SetHeight(size)
        icon:ClearAllPoints()
        icon:SetPoint(side, b.health, side, x, 2)
        icon.cd:GetCountdownFontString():SetFont(STANDARD_TEXT_FONT, math.max(6, math.min(9, size - 3)), "OUTLINE")
    end
    if icon.path ~= a.icon then icon.path = a.icon; icon.tex:SetTexture(a.icon) end
    local c = debuff and DebuffTypeColor[a.dispel or "none"] or DARK
    if icon.c ~= c then icon.c = c; icon.border:SetVertexColor(c.r, c.g, c.b) end
    local stacks = a.stacks and a.stacks > 1 and a.stacks or nil
    if icon.stacks ~= stacks then icon.stacks = stacks; icon.count:SetText(stacks or "") end
    -- Small icons keep the stack count and the sweep; the numbers would not fit.
    icon.cd:SetHideCountdownNumbers(size < 8 or stacks ~= nil and size < 14)
    if icon.expires ~= a.expires then
        icon.expires = a.expires
        if a.duration > 0 then icon.cd:SetCooldown(a.expires - a.duration, a.duration) else icon.cd:Clear() end
    end
    icon:Show()
end

-- Debuffs first, from the right, leaving room for one buff; buffs from the left
-- in the room left; "+N" counts what did not fit (of the page's counts).
function R.Place(b)
    local buffs, debuffs = b.buffs, b.debuffs
    local hot = db.hots and buffs.n > 0 and Heal(buffs[1].id) and buffs[1].icon
    if hot then b.hot:SetTexture(hot) end
    b.hot:SetShown(hot and true or false)
    local nb = db.buffs and math.min(buffs.n, db.buffCount) or 0
    local nd = math.min(debuffs.n, db.debuffCount)
    local top = math.max(4, b.health:GetHeight() - 14)
    local bs, ds = math.min(db.buffSize, top), math.min(db.debuffSize, top)
    local room = db.width - 6
    if nb * (bs + GAP) + nd * (ds + GAP) - GAP > room then room = room - 12 end
    local sd = math.min(nd, math.floor((room - (nb > 0 and bs + GAP or 0) + GAP) / (ds + GAP))) -- room for one buff
    local sb = math.min(nb, math.max(0, math.floor((room - sd * (ds + GAP) + GAP) / (bs + GAP))))
    for i = 1, sb do Show(b, i, buffs[i], bs, "BOTTOMLEFT", 2 + (i - 1) * (bs + GAP)) end
    for i = 1, sd do Show(b, sb + i, debuffs[i], ds, "BOTTOMRIGHT", -2 - (i - 1) * (ds + GAP), true) end
    for i = sb + sd + 1, #b.icons do
        local icon = b.icons[i]
        if icon:IsShown() then icon:Hide(); icon.expires = nil; icon.cd:Clear() end
    end
    local more, at = nb + nd - sb - sd, 2 + sb * (bs + GAP)
    if b.moreAt ~= at then
        b.moreAt = at
        b.more:ClearAllPoints()
        b.more:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", at, 2)
    end
    if b.moreN ~= more then b.moreN = more; b.more:SetText(more > 0 and "+" .. more or "") end
end

-- Read the member's auras again and lay them out.
function R.Auras(b)
    if db.buffs or db.hots then Read(b, "HELPFUL", b.buffs, Heal) else b.buffs.n = 0 end
    if db.debuffs then LearnYours(b.unit); Read(b, "HARMFUL", b.debuffs, Yours) else b.debuffs.n = 0 end
    R.Place(b)
end

-- A refresh or a new stack count rewrites its own record (it keeps its place
-- in the order); a new or lost aura reads the member again (### UNIT_AURA_DELTA event).
-- Both lists are searched: a debuff the game parks in a buff slot is in the
-- buffs, but its AuraData says harmful (### AuraData table shape, isHarmful).
local buf = {}
local function Update(list, d)
    for j = 1, list.n do
        local a = list[j]
        if a.id == d.spellId and a.source == d.sourceUnit then
            a.stacks, a.duration, a.expires = d.applications, d.duration, d.expirationTime
            return true
        end
    end
end
function R.AuraDelta(b, info)
    local ids = info.updatedAuraInstanceIDs
    if info.isFullUpdate or info.addedAuraInstanceIDs or info.removedAuraInstanceIDs or not ids then
        return R.Auras(b)
    end
    for i = 1, #ids do
        local d = C_UnitAuras.GetAuraDataByAuraInstanceID(b.unit, ids[i], buf)
        if d and not Update(b.buffs, d) then Update(b.debuffs, d) end
    end
    R.Place(b)
end

-- The test grid: a full row of sample buffs, a Magic debuff on the second
-- member and two on the third.
local SAMPLES = { "Interface\\Icons\\Spell_Holy_Renew", "Interface\\Icons\\Spell_Nature_Rejuvenation",
    "Interface\\Icons\\Spell_Holy_PowerWordShield", "Interface\\Icons\\Spell_Holy_WordFortitude" }
local function Fill(list, n, dispel)
    for i = 1, n do
        list[i] = list[i] or {}
        local a = list[i]
        a.icon, a.stacks, a.dispel, a.duration, a.expires, a.source, a.id = SAMPLES[(i - 1) % 4 + 1], i == 2 and 3 or 1,
            dispel, 0, 0, nil, 0
    end
    list.n = n
end
function R.SampleAuras(b, m)
    Fill(b.buffs, db.buffs and db.buffCount or 0)
    Fill(b.debuffs, db.debuffs and (m == 2 and 1 or m == 3 and 2) or 0, "Magic")
    R.Place(b)
    b.hot:Hide()
end
