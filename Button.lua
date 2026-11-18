-- One member: health over power, name, missing health, range, raid mark,
-- leader crown and the aggro corner. Each part is written only when it changes.
local _, R = ...
if not R.apply then return end -- no ClassicAPI: Core.lua said so

local db = RaidFramesDB
local Text = R.Text
local BAR, WHITE = "Interface\\AddOns\\RaidFrames\\img\\bar.tga", "Interface\\Buttons\\WHITE8X8"
local BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 } }
local GREEN = { r = 0.2, g = 0.9, b = 0.2 }
local CROWNS = { "Interface\\GroupFrame\\UI-Group-AssistantIcon", "Interface\\GroupFrame\\UI-Group-LeaderIcon" }
-- Health states other than a number of missing points.
local OFF, GHOST, DEAD = -1, -2, -3
local STATES = { [OFF] = "|cff888888Off|r", [GHOST] = "|cffaaaaaaGhost|r", [DEAD] = "|cffff2020Dead|r" }

local function Bar(parent, a, b, y)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetPoint(a, parent, a, 1, y)
    bar:SetPoint(b, parent, b, -1, y)
    bar:SetStatusBarTexture(BAR)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetTexture(BAR)
    return bar
end

-- A bar and its background, a fifth as bright, in colour `c` (a table that stays).
local function Paint(bar, c)
    if bar.c == c then return end
    bar.c = c
    bar:SetStatusBarColor(c.r, c.g, c.b)
    bar.bg:SetVertexColor(c.r * 0.2, c.g * 0.2, c.b * 0.2)
end

local function Fill(bar, value, max)
    if bar.max ~= max then bar.max = max; bar:SetMinMaxValues(0, max) end
    bar:SetValue(value)
end

local function Font(parent, point, x)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint(point, parent, point, x, -2)
    fs:SetJustifyH(x > 0 and "LEFT" or "RIGHT")
    fs:SetShadowOffset(0.8, -0.8)
    return fs
end

local function Square(parent, size, point, x, y)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetWidth(size); t:SetHeight(size)
    t:SetPoint(point, parent, point, x, y)
    t:Hide()
    return t
end

-- The unit attributes make a click target the member (or cast the spell on the
-- cursor on it), a right-click open its menu, and hovering it the mouseover
-- (Frame section, "Click actions"). This only shows the tooltip.
local function Enter()
    if not this.unit then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, this)
    GameTooltip:SetUnit(this.unit)
    GameTooltip:Show()
end
local function Leave() GameTooltip:Hide() end

function R.NewButton(parent, name)
    local b = CreateFrame("Button", name, parent)
    b:SetBackdrop(BACKDROP)
    b:SetBackdropColor(0, 0, 0, 0.9)
    b:SetBackdropBorderColor(0, 0, 0, 1)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetAttribute("type1", "target")
    b:SetAttribute("type2", "menu")
    b:SetScript("OnEnter", Enter)
    b:SetScript("OnLeave", Leave)
    b.health, b.power = Bar(b, "TOPLEFT", "TOPRIGHT", -1), Bar(b, "BOTTOMLEFT", "BOTTOMRIGHT", 1)
    local hb = b.health
    b.nameText, b.hp = Font(hb, "TOPLEFT", 3), Font(hb, "TOPRIGHT", -3)
    b.mark = Square(hb, 12, "TOP", 0, 5)
    b.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    b.crown = Square(hb, 8, "TOPRIGHT", 3, 4)
    b.aggro = Square(b.power, 4, "BOTTOMLEFT", 0, 0)
    b.aggro:SetTexture(1, 0, 0, 1)
    R.NewIcons(b)
    R.Size(b)
    b:Hide()
    return b
end

-- The page's width and height; the icons follow at their next layout.
function R.Size(b)
    local w, h = db.width, db.height
    local ph = math.max(3, math.floor(h * 0.12))
    b:SetWidth(w); b:SetHeight(h)
    b.health:SetHeight(h - ph - 3)
    b.power:SetHeight(ph)
    b.nameText:SetWidth(math.floor((w - 8) * 0.6))
    b.hp:SetWidth(math.floor((w - 8) * 0.4))
end

-- Class colour and name. The raid roster knows both for every member;
-- UnitName says "Unknown" until the client has loaded that player, and the
-- player cache knows the class of a party member out of range.
function R.Identity(b)
    local class = b.class or select(2, UnitClass(b.unit))
    if not class and b.name then class = select(2, C_PlayerCache.GetPlayerInfoByName(b.name)) end
    Paint(b.health, class and C_ClassColor.GetClassColor(class) or GREEN)
    local name = b.name
    if not name or name == UNKNOWNOBJECT then name = UnitName(b.unit) end
    Text(b.nameText, name or "")
end

-- `state`: missing points, or OFF, GHOST, DEAD. The text is built only when it changes.
local function HealthText(b, state)
    if b.missing == state then return end
    b.missing = state
    Text(b.hp, STATES[state] or state > 0 and "-" .. AbbreviateNumbers(state) or "")
end

function R.Health(b)
    local unit = b.unit
    Fill(b.health, UnitHealth(unit), UnitHealthMax(unit))
    HealthText(b, not UnitIsConnected(unit) and OFF or UnitIsGhost(unit) and GHOST
        or UnitIsDead(unit) and DEAD or UnitHealthMissing(unit))
end

function R.Power(b)
    local max = UnitManaMax(b.unit)
    Fill(b.power, UnitMana(b.unit), max > 0 and max or 1)
    Paint(b.power, ManaBarColor[UnitPowerType(b.unit)] or ManaBarColor[0])
end

-- `inRange`: UNIT_IN_RANGE_UPDATE's, or UnitInRange's when the member shows.
local function Alpha(b, alpha)
    if b.alpha ~= alpha then b.alpha = alpha; b:SetAlpha(alpha) end
end
function R.Range(b, inRange)
    Alpha(b, not UnitIsConnected(b.unit) and 0.4 or (inRange or b.me) and 1 or 0.45)
end

function R.Mark(b, index)
    if index then SetRaidTargetIconTexture(b.mark, index) end
    b.mark:SetShown(index and true or false)
end

-- rank: 2 the leader, 1 an assistant.
function R.Crown(b, rank)
    if CROWNS[rank] then b.crown:SetTexture(CROWNS[rank]) end
    b.crown:SetShown(CROWNS[rank] and true or false)
end

-- `hostile`: your target is an enemy with a target; the corner shows on that target.
function R.Aggro(b, hostile)
    local on = hostile and UnitIsUnit(b.unit, "targettarget") and true or false
    if b.aggroOn ~= on then b.aggroOn = on; b.aggro:SetShown(on) end
end

-- Everything, when a member takes the button.
function R.Refresh(b, hostile)
    b.missing, b.alpha, b.aggroOn = nil, nil, nil
    b.me = UnitIsUnit(b.unit, "player") and true or false
    R.Identity(b)
    R.Health(b)
    R.Power(b)
    R.Range(b, UnitInRange(b.unit))
    R.Mark(b, GetRaidTargetIndex(b.unit))
    R.Crown(b, b.rank)
    R.Aggro(b, hostile)
    R.Auras(b)
end

-- The test grid's member `m` of group `g`: the fourth is dead, the last of the
-- last group offline, the fifth of each out of range.
local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "HUNTER", "WARLOCK", "SHAMAN" }
local SAMPLE = { 0, 1500, 600, DEAD, 0 }
function R.Sample(b, g, m)
    local class = CLASSES[(g + m) % 8 + 1]
    Paint(b.health, C_ClassColor.GetClassColor(class))
    Text(b.nameText, string.sub(class, 1, 1) .. string.lower(string.sub(class, 2)) .. m)
    local state = g == 8 and m == 5 and OFF or SAMPLE[m]
    Fill(b.health, state < 0 and 0 or 4000 - state, 4000)
    HealthText(b, state)
    Fill(b.power, 2100, 3000)
    Paint(b.power, ManaBarColor[0])
    Alpha(b, m == 5 and 0.45 or 1)
    R.Mark(b, m == 1 and g or nil)
    R.Crown(b, g == 1 and m == 1 and 2 or 0)
    b.aggroOn = false
    b.aggro:Hide()
    R.SampleAuras(b, m)
end
