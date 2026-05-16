local FRM = FocusRollManager

FRM.debugRaidRoster = {
    { name = "Blackpanther", class = "DRUID" },
    { name = "Healbot", class = "PRIEST" },
    { name = "Tankyx", class = "WARRIOR" },
    { name = "Mageone", class = "MAGE" },
    { name = "Svenn", class = "PALADIN" },
    { name = "Matze", class = "ROGUE" },
    { name = "Shadowkeks", class = "WARLOCK" },
    { name = "Hunterjoe", class = "HUNTER" },
    { name = "Schamix", class = "SHAMAN" },
    { name = "Deathgrip", class = "DEATHKNIGHT" },
}

FRM.debugFocusImportString = table.concat({
    "FRM1",
    "Blackpanther;DRUID;Deathbringer's Will Heroic;Sharpened Twilight Scale Heroic;active;0",
    "Healbot;PRIEST;Phylactery of the Nameless Lich Heroic;;active;0",
    "Tankyx;WARRIOR;;;off;0",
    "Mageone;MAGE;Charred Twilight Scale Heroic;Tiny Abomination in a Jar Heroic;active;0",
    "Svenn;PALADIN;Tier Token;;active;0",
    "Matze;ROGUE;Deathbringer's Will;;active;0",
    "Shadowkeks;WARLOCK;Phylactery of the Nameless Lich Heroic;Charred Twilight Scale Heroic;active;0",
    "Hunterjoe;HUNTER;Sharpened Twilight Scale Heroic;Deathbringer's Will Heroic;active;0",
    "Schamix;SHAMAN;Tiny Abomination in a Jar Heroic;;active;0",
    "Deathgrip;DEATHKNIGHT;Protector Token;;active;0",
}, "|")

FRM.debugTSText = table.concat({
    "<20:11:02> Blackpanther: focus DBW HC > STS HC",
    "<20:11:08> Healbot: fr Phyl HC",
    "<20:11:14> Tankyx off",
    "<20:11:22> Mageone: fokus CTS HC / Tiny Abo HC",
    "<20:11:31> Svenn: SR Token",
    "<20:11:39> Matze: roll DBW",
    "<20:11:44> Shadowkeks: focus Phyl HC > CTS HC",
    "<20:11:53> Hunterjoe: fr STS HC > DBW HC",
    "<20:12:01> Schamix: focus Tiny Abo HC",
    "<20:12:09> Deathgrip: softres Protector Token",
}, "\n")

local function createLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function createEditBox(parent, name, width, x, y, defaultText)
    local edit = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    edit:SetWidth(width)
    edit:SetHeight(24)
    edit:SetPoint("TOPLEFT", x, y)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetText(defaultText or "")
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return edit
end

local function createButton(parent, text, width, x, y, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(width)
    btn:SetHeight(24)
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function countTableValues(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
end

function FRM:GetDebugFocusImportString()
    return self.debugFocusImportString
end

function FRM:GetDebugTSText()
    return self.debugTSText
end

function FRM:LoadDebugRaid()
    local db = self:GetDB()
    db.settings.debugLiveRaid = true
    db.settings.debugLastRosterEvent = nil
    self:RAID_ROSTER_UPDATE()
    self:Print("Debug-Raid ueber RAID_ROSTER_UPDATE geladen: " .. tostring(#self.debugRaidRoster) .. " Spieler.")
    self:RefreshDebugUI()
end

function FRM:ClearDebugRaid()
    local db = self:GetDB()
    db.settings.debugLiveRaid = false
    db.roster = {}
    self:RefreshRoster()
    self:Print("Debug-Raid deaktiviert.")
    self:RefreshUI()
    self:RefreshDebugUI()
end

function FRM:DebugRollSet()
    self:DebugRoll("Blackpanther", 88)
    self:DebugRoll("Hunterjoe", 71)
    self:DebugRoll("Svenn", 99)
    self:DebugRoll("Healbot", 77)
    self:DebugRoll("Mageone", 64)
    self:Print("Debug-Rolls simuliert.")
    self:RefreshDebugUI()
end

function FRM:DebugAssignLoot(item)
    item = self:NormalizeItem(self:Trim(item or ""))
    local db = self:GetDB()
    if item == "" and db.loot.items and db.loot.items[1] then
        item = db.loot.items[1].name or db.loot.items[1].link or ""
    end
    if item == "" then
        self:Print("Kein Item fuer Loot-Zuteilung vorhanden.")
        return nil
    end

    local interested = self:FindInterested(item)
    if #interested == 0 then
        self:Print("Keine Focus-Interessenten fuer: " .. item)
        return nil
    end

    local interestedByName = {}
    for _, player in ipairs(interested) do
        interestedByName[player.name] = true
    end

    local winner = nil
    for _, roll in ipairs(db.rolls or {}) do
        if interestedByName[roll.player] then
            winner = roll.player
            break
        end
    end

    if not winner then
        winner = interested[1].name
    end

    self:MarkWin(winner, item)
    self:Print("Debug Loot zugeteilt: " .. winner .. " -> " .. item)
    self:RefreshDebugUI()
    return winner
end

function FRM:BuildDebugSummary()
    local db = self:GetDB()
    local lines = {}

    table.insert(lines, "|cffffff00Debug Simulation|r")
    table.insert(lines, "Debug-Raid: " .. (db.settings.debugLiveRaid and "aktiv" or "aus"))
    table.insert(lines, "Live-Events: Roster=" .. tostring(db.settings.debugLastRosterEvent or "-") ..
        " Loot=" .. tostring(db.settings.debugLastLootEvent or "-") ..
        " Roll=" .. tostring(db.settings.debugLastRollEvent or "-"))
    table.insert(lines, "Roster-Spieler: " .. tostring(countTableValues(db.roster)))
    table.insert(lines, "Focus-Spieler: " .. tostring(countTableValues(db.players)))
    table.insert(lines, "")
    table.insert(lines, "Boss: " .. ((db.loot and db.loot.lastBoss ~= "" and db.loot.lastBoss) or "-"))

    table.insert(lines, "")
    table.insert(lines, "Loot:")
    if db.loot and db.loot.items and #db.loot.items > 0 then
        for _, item in ipairs(db.loot.items) do
            local itemName = item.name or item.link or ""
            table.insert(lines, "- " .. itemName)
            local interested = self:FindInterested(itemName)
            if #interested == 0 then
                table.insert(lines, "  keine Focus-Interessenten")
            else
                for _, player in ipairs(interested) do
                    table.insert(lines, "  -> " .. player.name .. " (" .. player.class .. ", Striche: " .. tostring(player.strikes or 0) .. ")")
                end
            end
        end
    else
        table.insert(lines, "- kein Loot simuliert")
    end

    table.insert(lines, "")
    table.insert(lines, "Rolls:")
    if db.rolls and #db.rolls > 0 then
        for i = 1, math.min(6, #db.rolls) do
            local roll = db.rolls[i]
            table.insert(lines, i .. ". " .. roll.player .. " - " .. tostring(roll.roll))
        end
    else
        table.insert(lines, "- keine Rolls simuliert")
    end

    table.insert(lines, "")
    table.insert(lines, "Gewinne:")
    local hasWin = false
    local names = {}
    for name in pairs(db.players or {}) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
        local player = db.players[name]
        if player.wins and #player.wins > 0 then
            hasWin = true
            for _, win in ipairs(player.wins) do
                table.insert(lines, "- " .. name .. " -> " .. (win.item or ""))
            end
        end
    end
    if not hasWin then
        table.insert(lines, "- keine")
    end

    return table.concat(lines, "\n")
end

function FRM:RefreshDebugUI()
    if not self.debugFrame or not self.debugFrame.output then return end
    self.debugFrame.output:SetText(self:BuildDebugSummary())
end

function FRM:ShowDebugUI()
    if not self.debugFrame then
        local f = CreateFrame("Frame", "FocusRollManagerDebugFrame", UIParent)
        f:SetWidth(760)
        f:SetHeight(560)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
        f:Hide()

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("FRM Debug")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -5, -5)

        createLabel(f, "Workflow", 30, -52)
        createButton(f, "Fake Raid", 105, 120, -48, function()
            FocusRollManager:LoadDebugRaid()
        end)
        createButton(f, "Roster Export", 115, 232, -48, function()
            FocusRollManager:ShowCopyBox("FRM Debug Roster Export", FocusRollManager:BuildRosterExport())
        end)
        createButton(f, "Fake Focus Import", 130, 354, -48, function()
            FocusRollManager:ImportString(FocusRollManager:GetDebugFocusImportString())
            FocusRollManager:RefreshDebugUI()
        end)
        createButton(f, "Focus Export", 110, 492, -48, function()
            FocusRollManager:PrintExportString()
        end)
        createButton(f, "Liste", 80, 610, -48, function()
            FocusRollManager:RefreshUI()
            if not FocusRollManager.ui or not FocusRollManager.ui:IsShown() then
                FocusRollManager:ToggleUI()
            end
        end)

        createButton(f, "Fake TS Daten", 115, 120, -82, function()
            FocusRollManager:ShowCopyBox("Fake TS Daten fuer Desktop-App", FocusRollManager:GetDebugTSText())
        end)
        createButton(f, "Reset Live", 105, 242, -82, function()
            FocusRollManager:ResetRaidData()
            FocusRollManager:RefreshDebugUI()
        end)
        createButton(f, "Debug Raid aus", 120, 354, -82, function()
            FocusRollManager:ClearDebugRaid()
        end)

        createLabel(f, "Boss", 30, -128)
        local bossEdit = createEditBox(f, "FocusRollManagerDebugBossEdit", 280, 120, -124, "Deathbringer Saurfang")
        createButton(f, "Boss tot", 110, 430, -124, function()
            FocusRollManager:DebugBoss(bossEdit:GetText())
            FocusRollManager:RefreshDebugUI()
        end)

        createLabel(f, "Itemdrop", 30, -168)
        local quickItems = {
            { "DBW HC", "DBW HC" },
            { "STS HC", "STS HC" },
            { "Phyl HC", "Phyl HC" },
            { "CTS HC", "CTS HC" },
            { "Tiny HC", "Tiny Abo HC" },
            { "Token", "Token" },
        }
        for i, entry in ipairs(quickItems) do
            local label = entry[1]
            local item = entry[2]
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            createButton(f, label, 90, 120 + (col * 98), -164 - (row * 30), function()
                FocusRollManager:DebugItem(item)
                FocusRollManager:RefreshDebugUI()
            end)
        end

        local itemEdit = createEditBox(f, "FocusRollManagerDebugItemEdit", 280, 120, -234, "")
        createButton(f, "Item Drop", 110, 430, -234, function()
            FocusRollManager:DebugItem(itemEdit:GetText())
            FocusRollManager:RefreshDebugUI()
        end)

        createLabel(f, "Roll", 30, -278)
        local playerName = UnitName and UnitName("player") or "Blackpanther"
        local playerEdit = createEditBox(f, "FocusRollManagerDebugRollPlayerEdit", 180, 120, -274, playerName)
        local rollEdit = createEditBox(f, "FocusRollManagerDebugRollValueEdit", 60, 312, -274, "87")
        createButton(f, "Add Roll", 95, 384, -274, function()
            FocusRollManager:DebugRoll(playerEdit:GetText(), rollEdit:GetText())
            FocusRollManager:RefreshDebugUI()
        end)
        createButton(f, "Fake Rolls", 100, 488, -274, function()
            FocusRollManager:DebugRollSet()
        end)
        createButton(f, "Loot zuteilen", 110, 596, -274, function()
            FocusRollManager:DebugAssignLoot(itemEdit:GetText())
        end)

        local output = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        output:SetPoint("TOPLEFT", 30, -318)
        output:SetWidth(700)
        output:SetJustifyH("LEFT")
        output:SetJustifyV("TOP")
        output:SetText("")
        f.output = output

        self.debugFrame = f
    end

    if self.debugFrame:IsShown() then
        self.debugFrame:Hide()
    else
        self:RefreshDebugUI()
        self.debugFrame:Show()
    end
end

function FRM:PrintDebugHelp()
    self:Print("Debug:")
    self:Print("/frm debug - Debug-Fenster oeffnen")
    self:Print("/frm debug raid - Fake-Raid laden")
    self:Print("/frm debug nor raid - Debug-Raid deaktivieren")
    self:Print("/frm debug focus - Fake-Focusdaten importieren")
    self:Print("/frm debug ts - Fake-TS-Daten im Kopierfenster anzeigen")
    self:Print("/frm debug boss <name> - Bosskill simulieren")
    self:Print("/frm debug item <item> - Itemdrop simulieren")
    self:Print("/frm debug roll <player> <1-100> - Roll-Eintrag simulieren")
    self:Print("/frm debug rolls - mehrere Rolls simulieren")
    self:Print("/frm debug assign [item] - Loot zuteilen")
    self:Print("/frm debug clear - Loot/Rolls zuruecksetzen")
    self:Print("Echte Rolls: einfach normal /roll nutzen; FRM liest CHAT_MSG_SYSTEM.")
end

function FRM:HandleDebug(rest)
    rest = self:Trim(rest or "")
    local sub, value = rest:match("^(%S*)%s*(.-)$")
    sub = string.lower(sub or "")

    if sub == "" then
        self:ShowDebugUI()
    elseif sub == "help" then
        self:PrintDebugHelp()
    elseif sub == "raid" then
        self:LoadDebugRaid()
    elseif sub == "nor" and string.lower(value or "") == "raid" then
        self:ClearDebugRaid()
    elseif sub == "focus" then
        self:ImportString(self:GetDebugFocusImportString())
    elseif sub == "ts" then
        self:ShowCopyBox("Fake TS Daten fuer Desktop-App", self:GetDebugTSText())
    elseif sub == "boss" then
        self:DebugBoss(value)
    elseif sub == "item" or sub == "drop" or sub == "loot" then
        self:DebugItem(value)
    elseif sub == "roll" then
        local player, roll = value:match("^(%S+)%s+(%d+)$")
        self:DebugRoll(player, roll)
    elseif sub == "rolls" then
        self:DebugRollSet()
    elseif sub == "assign" or sub == "winloot" then
        self:DebugAssignLoot(value)
    elseif sub == "clear" or sub == "reset" then
        self:ResetRaidData()
    else
        self:Print("Unbekannter Debug-Befehl.")
        self:PrintDebugHelp()
    end
end

function FRM:DebugBoss(name)
    name = self:Trim(name or "")
    if name == "" then
        self:Print("Nutzung: /frm debug boss <name>")
        return
    end

    local db = self:GetDB()
    db.loot.lastBoss = name
    self:Print("Debug Bosskill: " .. name)
    self:RefreshUI()
end

function FRM:DebugItem(item)
    item = self:NormalizeItem(self:Trim(item or ""))
    if item == "" then
        self:Print("Nutzung: /frm debug item <item>")
        return
    end

    local db = self:GetDB()
    db.settings.debugLiveLoot = true
    db.settings.debugLastLootEvent = nil
    self.debugLootLinks = {
        "|cffa335ee|Hitem:0:0:0:0:0:0:0:0|h[" .. item .. "]|h|r"
    }
    self:Print("Debug Itemdrop ueber LOOT_OPENED: " .. item)
    self:LOOT_OPENED()
end

function FRM:DebugRoll(player, roll)
    player = self:Trim(player or "")
    roll = tonumber(roll)
    if player == "" or not roll then
        self:Print("Nutzung: /frm debug roll <player> <1-100>")
        return
    end

    local db = self:GetDB()
    db.settings.debugLiveRoll = true
    db.settings.debugLastRollEvent = nil
    self:CHAT_MSG_SYSTEM(player .. " rolls " .. tostring(roll) .. " (1-100)")
end
