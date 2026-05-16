-- UI.lua
-- Main window for FocusRollManager. Button-driven layout: top action bar
-- (import/export/clear/sync/reload), active-loot section with one Award
-- button per interested player, full player list with inline strike +/-,
-- and the recent-rolls section.
--
-- Award workflow: lootmaster clicks "Verrollen" on a banked drop, raid types
-- /roll 101-200, the table fills up sorted by fewest strikes + highest roll,
-- one click on "Award" → MarkWin → Sync broadcast → strike counter ticks up.

local FRM = FocusRollManager

local FRAME_W, FRAME_H = 940, 640
local CONTENT_PAD       = 14

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function MakeButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w or 90); b:SetHeight(h or 22); b:SetText(text)
    return b
end

local function MakeLabel(parent, text, size, anchor)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text or "")
    if size then fs:SetFont(fs:GetFont(), size) end
    return fs
end

local function MakeScroll(parent, contentName)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", contentName, scroll)
    content:SetWidth(FRAME_W - 60)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    return scroll, content
end

function FRM:ClassColorName(name, class)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
    if not color then
        return "|cffffffff" .. tostring(name or "") .. "|r"
    end
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor((color.r or 1) * 255),
        math.floor((color.g or 1) * 255),
        math.floor((color.b or 1) * 255),
        tostring(name or ""))
end

------------------------------------------------------------
-- CONFIRM DIALOGS
------------------------------------------------------------

StaticPopupDialogs["FRM_CONFIRM_SYNC_START"] = {
    text = "Live Sync starten?\n\n|cffffd96bChatlog wird aktiviert|r (Logs/WoWChatLog.txt).\n"
        .. "Externes Strichliste-Tool empfaengt dann live alle Awards.",
    button1 = "Ja, starten",
    button2 = "Abbrechen",
    OnAccept = function() FRM:SyncStart(); FRM:RefreshUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["FRM_CONFIRM_RELOAD"] = {
    text = "UI neu laden fuer externen Vollsync?\n\n|cffffd96bNur zwischen Bossen, nicht in Kampf.|r",
    button1 = "Ja, reloaden",
    button2 = "Abbrechen",
    OnAccept = function() FRM:ReloadForSync() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

------------------------------------------------------------
-- ACTIVE ROLL HELPERS  (extends Data.lua state)
------------------------------------------------------------

function FRM:SetActiveRoll(itemLink, itemName)
    local db = self:GetDB()
    db.activeRoll = { item = itemName or itemLink or "?", link = itemLink, started = time() }
    db.rolls = {}   -- fresh roll buffer per item
    if self.RefreshUI then self:RefreshUI() end
end

function FRM:ClearActiveRoll()
    local db = self:GetDB()
    db.activeRoll = nil
    db.rolls = {}
    if self.RefreshUI then self:RefreshUI() end
end

function FRM:GetActiveRoll()
    return self:GetDB().activeRoll
end

-- Announce a roll in raid chat. Falls back to /say if not in a raid so the
-- LM can test outside a real raid pull.
function FRM:AnnounceRoll(itemLink)
    local chan = "SAY"
    if IsInRaid and IsInRaid() then chan = "RAID_WARNING" end
    if not IsInRaid and self:GetNumRaidMembers and self:GetNumRaidMembers() > 0 then
        chan = "RAID"
    end
    if SendChatMessage then
        SendChatMessage("[Fokusroll] " .. tostring(itemLink or "?")
            .. " — /roll 101-200 (nur Focus)", chan)
    end
end

------------------------------------------------------------
-- COPY / IMPORT BOXES (kept from old UI)
------------------------------------------------------------

function FRM:ShowCopyBox(titleText, value)
    value = tostring(value or "")
    if not self.copyFrame then
        local f = CreateFrame("Frame", "FocusRollManagerCopyFrame", UIParent)
        f:SetWidth(760); f:SetHeight(150)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        f:SetMovable(true); f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
        f:Hide()
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -18)
        f.title = title
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 28, -48)
        hint:SetText("Text markiert. Ctrl+C zum Kopieren.")
        local edit = CreateFrame("EditBox", "FocusRollManagerCopyEditBox", f, "InputBoxTemplate")
        edit:SetWidth(690); edit:SetHeight(32)
        edit:SetPoint("TOPLEFT", 34, -78)
        edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
        edit:SetScript("OnEnterPressed",  function(self) self:HighlightText() end)
        edit:SetScript("OnMouseUp",       function(self) self:HighlightText() end)
        f.edit = edit
        local close = MakeButton(f, "Schliessen", 90, 24)
        close:SetPoint("BOTTOMRIGHT", -28, 22)
        close:SetScript("OnClick", function() f:Hide() end)
        self.copyFrame = f
    end
    self.copyFrame.title:SetText(titleText or "FRM Export")
    self.copyFrame.edit:SetText(value)
    self.copyFrame:Show()
    self.copyFrame.edit:SetFocus()
    self.copyFrame.edit:HighlightText()
end

function FRM:ShowImportBox()
    if not self.importFrame then
        local f = CreateFrame("Frame", "FocusRollManagerImportFrame", UIParent)
        f:SetWidth(760); f:SetHeight(260)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        f:SetMovable(true); f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
        f:Hide()
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -18); title:SetText("FRM Import")
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 28, -48)
        hint:SetText("FRM1-String einfuegen (Ctrl+V) und auf Import klicken.")
        local edit = CreateFrame("EditBox", "FocusRollManagerImportEditBox", f, "InputBoxTemplate")
        edit:SetWidth(690); edit:SetHeight(100)
        edit:SetPoint("TOPLEFT", 34, -78)
        edit:SetAutoFocus(false); edit:SetMultiLine(true)
        edit:SetMaxLetters(999999); edit:SetFontObject(ChatFontNormal)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
        f.edit = edit
        local imp = MakeButton(f, "Import", 120, 24)
        imp:SetPoint("BOTTOMRIGHT", -126, 24)
        imp:SetScript("OnClick", function()
            FRM:ImportString(f.edit:GetText() or "")
        end)
        local close = MakeButton(f, "Schliessen", 90, 24)
        close:SetPoint("BOTTOMRIGHT", -28, 24)
        close:SetScript("OnClick", function() f:Hide() end)
        self.importFrame = f
    end
    self.importFrame.edit:SetText("")
    self.importFrame:Show()
    self.importFrame.edit:SetFocus()
end

------------------------------------------------------------
-- MAIN WINDOW
------------------------------------------------------------

function FRM:BuildUI()
    if self.ui then return end

    local f = CreateFrame("Frame", "FocusRollManagerFrame", UIParent)
    f:SetWidth(FRAME_W); f:SetHeight(FRAME_H)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Focus Roll Manager")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    -- Row 1: data actions
    local importBtn = MakeButton(f, "Import",  80, 22); importBtn:SetPoint("TOPLEFT", CONTENT_PAD, -40)
    importBtn:SetScript("OnClick", function() FRM:ShowImportBox() end)
    local exportBtn = MakeButton(f, "Export",  80, 22); exportBtn:SetPoint("LEFT", importBtn, "RIGHT", 4, 0)
    exportBtn:SetScript("OnClick", function() FRM:PrintExportString() end)
    local rosterBtn = MakeButton(f, "Roster",  80, 22); rosterBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
    rosterBtn:SetScript("OnClick", function() FRM:PrintRosterExport() end)
    local clearBtn  = MakeButton(f, "Clear",   80, 22); clearBtn:SetPoint("LEFT", rosterBtn, "RIGHT", 4, 0)
    clearBtn:SetScript("OnClick", function() FRM:ClearFocus() end)
    local missingBtn= MakeButton(f, "Missing", 80, 22); missingBtn:SetPoint("LEFT", clearBtn, "RIGHT", 4, 0)
    missingBtn:SetScript("OnClick", function() FRM:PrintMissingFocus() end)

    -- Row 2: sync controls
    local syncBtn = MakeButton(f, "Live Sync: AUS", 140, 22)
    syncBtn:SetPoint("TOPLEFT", importBtn, "BOTTOMLEFT", 0, -6)
    syncBtn:SetScript("OnClick", function()
        if FRM:SyncIsActive() then
            FRM:SyncStop(); FRM:RefreshUI()
        else
            StaticPopup_Show("FRM_CONFIRM_SYNC_START")
        end
    end)

    local reloadBtn = MakeButton(f, "Reload Vollsync", 130, 22)
    reloadBtn:SetPoint("LEFT", syncBtn, "RIGHT", 6, 0)
    reloadBtn:SetScript("OnClick", function()
        if UnitAffectingCombat and UnitAffectingCombat("player") then
            FRM:Print("|cffff5555In Kampf — Reload erst nach Boss.|r")
            return
        end
        StaticPopup_Show("FRM_CONFIRM_RELOAD")
    end)

    local syncStatus = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    syncStatus:SetPoint("LEFT", reloadBtn, "RIGHT", 10, 0)
    syncStatus:SetWidth(280); syncStatus:SetJustifyH("LEFT")

    -- Sections: active roll (top half), full player list (bottom half)
    local rollHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rollHdr:SetPoint("TOPLEFT", syncBtn, "BOTTOMLEFT", 0, -10)
    rollHdr:SetTextColor(1, 0.85, 0.2)
    rollHdr:SetText("Aktive Verrollung")

    local rollSubLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rollSubLbl:SetPoint("TOPLEFT", rollHdr, "BOTTOMLEFT", 0, -4)
    rollSubLbl:SetWidth(FRAME_W - 40); rollSubLbl:SetJustifyH("LEFT")

    local rollScroll, rollContent = MakeScroll(f, "FRMRollScrollContent")
    rollScroll:SetPoint("TOPLEFT",  rollSubLbl, "BOTTOMLEFT", -4, -4)
    rollScroll:SetPoint("RIGHT",    f, "RIGHT", -28, 0)
    rollScroll:SetHeight(170)

    -- Recent rolls + cancel
    local cancelBtn = MakeButton(f, "Verrollung beenden", 150, 20)
    cancelBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -68)
    cancelBtn:SetScript("OnClick", function() FRM:ClearActiveRoll() end)

    -- Full player list section
    local listHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    listHdr:SetPoint("TOPLEFT", CONTENT_PAD, -300)
    listHdr:SetTextColor(1, 0.85, 0.2)
    listHdr:SetText("Focus-Liste (Striche aufsteigend)")

    local listScroll, listContent = MakeScroll(f, "FRMListScrollContent")
    listScroll:SetPoint("TOPLEFT",     listHdr, "BOTTOMLEFT", -4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, CONTENT_PAD)

    -- Stash refs for refresh
    f._syncBtn      = syncBtn
    f._syncStatus   = syncStatus
    f._rollSubLbl   = rollSubLbl
    f._rollContent  = rollContent
    f._listContent  = listContent
    self.ui = f
    self:RefreshUI()
end

------------------------------------------------------------
-- REFRESH
------------------------------------------------------------

local function ClearChildren(frame)
    if not frame then return end
    for _, child in ipairs({frame:GetChildren()}) do
        child:Hide(); child:SetParent(nil)
    end
    for _, region in ipairs({frame:GetRegions()}) do
        if region.SetText then region:Hide() end
    end
    frame:SetHeight(1)
end

-- Build the prioritised interested list for an item: only players who have
-- it as focus1 or focus2 and aren't off. Sorted by fewest strikes first,
-- then by highest current roll, then by name.
local function BuildInterestedRanked(db, itemName)
    local norm = FRM:NormalizeItem(itemName or "")
    local rollMap = {}
    for _, r in ipairs(db.rolls or {}) do
        local cur = rollMap[r.player]
        if not cur or (r.roll or 0) > cur then rollMap[r.player] = r.roll end
    end
    local rows = {}
    for name, p in pairs(db.players) do
        if p.status ~= "off" and p.status ~= "absent" then
            local f1 = FRM:NormalizeItem(p.focus1 or "")
            local f2 = FRM:NormalizeItem(p.focus2 or "")
            if norm ~= "" and (f1 == norm or f2 == norm) then
                rows[#rows + 1] = {
                    name = name, class = p.class or "UNKNOWN",
                    strikes = tonumber(p.strikes) or 0,
                    roll = rollMap[name],
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.strikes ~= b.strikes then return a.strikes < b.strikes end
        local ra, rb = a.roll or -1, b.roll or -1
        if ra ~= rb then return ra > rb end
        return a.name < b.name
    end)
    return rows
end

local function BuildRollRow(parent, rank, row, item, y)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(22); f:SetWidth(parent:GetWidth())
    f:SetPoint("TOPLEFT", 0, -y)

    local rk = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rk:SetPoint("LEFT", 0, 0); rk:SetWidth(30)
    rk:SetText("|cffaaaaaa#" .. rank .. "|r")

    local nameLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLbl:SetPoint("LEFT", rk, "RIGHT", 4, 0); nameLbl:SetWidth(180)
    nameLbl:SetText(FRM:ClassColorName(row.name, row.class))

    local statLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statLbl:SetPoint("LEFT", nameLbl, "RIGHT", 4, 0); statLbl:SetWidth(110)
    local rollStr = row.roll and ("Roll:|cffffd96b" .. row.roll .. "|r") or "Roll:|cff666666—|r"
    statLbl:SetText("Striche:" .. row.strikes .. "   " .. rollStr)

    local awardBtn = MakeButton(f, "Award", 70, 20)
    awardBtn:SetPoint("LEFT", statLbl, "RIGHT", 6, 0)
    local capturedName = row.name
    local capturedItem = item
    awardBtn:SetScript("OnClick", function()
        FRM:MarkWin(capturedName, capturedItem)
        FRM:ClearActiveRoll()
    end)
    return 24
end

local function BuildListRow(parent, p, name, y)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(22); f:SetWidth(parent:GetWidth())
    f:SetPoint("TOPLEFT", 0, -y)

    local nameLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLbl:SetPoint("LEFT", 0, 0); nameLbl:SetWidth(160)
    nameLbl:SetText(FRM:ClassColorName(name, p.class))

    local focLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    focLbl:SetPoint("LEFT", nameLbl, "RIGHT", 4, 0); focLbl:SetWidth(380)
    focLbl:SetText("|cffffd96b" .. (p.focus1 or "—") .. "|r   |cffaaaaaa" .. (p.focus2 or "—") .. "|r")

    local strikes = tonumber(p.strikes) or 0
    local strColor
    if     strikes == 0 then strColor = "|cff55ff55"
    elseif strikes <= 2 then strColor = "|cffffffff"
    elseif strikes <= 4 then strColor = "|cffffaa00"
    else                     strColor = "|cffff5555" end

    local strLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    strLbl:SetPoint("LEFT", focLbl, "RIGHT", 4, 0); strLbl:SetWidth(60)
    strLbl:SetText("Str: " .. strColor .. strikes .. "|r")

    local minus = MakeButton(f, "-", 22, 20); minus:SetPoint("LEFT", strLbl, "RIGHT", 0, 0)
    minus:SetScript("OnClick", function()
        local p2 = FRM:GetDB().players[name]
        if not p2 then return end
        p2.strikes = math.max(0, (tonumber(p2.strikes) or 0) - 1)
        if FRM.BroadcastPlayer then FRM:BroadcastPlayer(name) end
        FRM:RefreshUI()
    end)
    local plus = MakeButton(f, "+", 22, 20); plus:SetPoint("LEFT", minus, "RIGHT", 1, 0)
    plus:SetScript("OnClick", function()
        local p2 = FRM:GetDB().players[name]
        if not p2 then return end
        p2.strikes = (tonumber(p2.strikes) or 0) + 1
        if FRM.BroadcastPlayer then FRM:BroadcastPlayer(name) end
        FRM:RefreshUI()
    end)

    local statusBtn = MakeButton(f, p.status == "off" and "Da" or "Off", 32, 20)
    statusBtn:SetPoint("LEFT", plus, "RIGHT", 3, 0)
    statusBtn:SetScript("OnClick", function()
        local p2 = FRM:GetDB().players[name]
        if not p2 then return end
        p2.status = (p2.status == "off") and "active" or "off"
        if FRM.BroadcastPlayer then FRM:BroadcastPlayer(name) end
        FRM:RefreshUI()
    end)
    return 24
end

function FRM:RefreshUI()
    if not self.ui then return end
    local f = self.ui
    local db = self:GetDB()

    -- Sync button + status text
    local active = self:SyncIsActive()
    if f._syncBtn then
        f._syncBtn:SetText(active and "|cff55ff55Live Sync: AN|r" or "Live Sync: AUS")
    end
    if f._syncStatus then
        local s = db.sync or {}
        if active then
            f._syncStatus:SetText("|cff55ff55Chatlog AKTIV|r  Events: " .. (s.sentCount or 0))
        else
            f._syncStatus:SetText("|cffaaaaaaSync inaktiv|r")
        end
    end

    -- Active roll block
    ClearChildren(f._rollContent)
    local ar = self:GetActiveRoll()
    if not ar then
        f._rollSubLbl:SetText("|cffaaaaaaKein aktives Item. Im Loot-Bereich auf 'Verrollen' klicken.|r")

        -- Show banked loot items with [Verrollen] buttons
        local items = (db.loot and db.loot.items) or {}
        local y = 0
        for _, item in ipairs(items) do
            local row = CreateFrame("Frame", nil, f._rollContent)
            row:SetHeight(22); row:SetWidth(f._rollContent:GetWidth())
            row:SetPoint("TOPLEFT", 0, -y)
            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("LEFT", 4, 0); lbl:SetWidth(420)
            lbl:SetText(item.link or item.name or "?")
            local roll = MakeButton(row, "Verrollen", 90, 20)
            roll:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
            local capturedLink = item.link
            local capturedName = item.name or (item.link and item.link:match("%[(.-)%]")) or "?"
            roll:SetScript("OnClick", function()
                FRM:SetActiveRoll(capturedLink or capturedName, capturedName)
                FRM:AnnounceRoll(capturedLink or capturedName)
            end)
            y = y + 24
        end
        if #items == 0 then
            local fs = f._rollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", 4, -4); fs:SetTextColor(0.6, 0.6, 0.6)
            fs:SetText("(noch kein Loot erfasst — Boss looten dann erscheint hier die Liste)")
            y = 20
        end
        f._rollContent:SetHeight(math.max(y, 1))
    else
        f._rollSubLbl:SetText("Item: " .. tostring(ar.link or ar.item or "?")
            .. "   |cffaaaaaaPrio: wenige Striche + hoher Roll oben|r")
        local rows = BuildInterestedRanked(db, ar.item)
        local y = 0
        if #rows == 0 then
            local fs = f._rollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", 4, -4); fs:SetTextColor(0.6, 0.6, 0.6)
            fs:SetText("Keine Interessenten mit passendem Focus.")
            y = 20
        else
            for i, row in ipairs(rows) do
                y = y + BuildRollRow(f._rollContent, i, row, ar.item, y)
            end
        end
        f._rollContent:SetHeight(math.max(y, 1))
    end

    -- Full focus list sorted by strikes asc
    ClearChildren(f._listContent)
    local names = {}
    for name in pairs(db.players) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        local pa, pb = db.players[a], db.players[b]
        local sa, sb = tonumber(pa.strikes) or 0, tonumber(pb.strikes) or 0
        if sa ~= sb then return sa < sb end
        return a < b
    end)
    local y2 = 0
    for _, name in ipairs(names) do
        y2 = y2 + BuildListRow(f._listContent, db.players[name], name, y2)
    end
    if y2 == 0 then
        local fs = f._listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 4, -4); fs:SetTextColor(0.6, 0.6, 0.6)
        fs:SetText("(keine Spieler — Roster importieren + TS-Log analysieren in Desktop-App)")
        y2 = 20
    end
    f._listContent:SetHeight(math.max(y2, 1))
end

------------------------------------------------------------
-- TOGGLE + MINIMAP
------------------------------------------------------------

function FRM:ToggleUI()
    self:BuildUI()
    if self.ui:IsShown() then self.ui:Hide()
    else self:RefreshUI(); self.ui:Show() end
end

function FRM:BuildMinimapButton()
    if self.minimapButton then return end
    local btn = CreateFrame("Button", "FocusRollManagerMinimapButton", Minimap)
    btn:SetWidth(31); btn:SetHeight(31); btn:SetFrameStrata("MEDIUM")
    btn:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 4, 4)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetPoint("CENTER", 0, 0); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53); border:SetHeight(53); border:SetPoint("TOPLEFT", -11, 11)
    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if FocusRollManager.ShowDebugUI then FocusRollManager:ShowDebugUI() end
        else
            FocusRollManager:ToggleUI()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("FocusRollManager")
        GameTooltip:AddLine("Linksklick: Fenster", 1, 1, 1)
        GameTooltip:AddLine("Rechtsklick: Debug", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.minimapButton = btn
end
