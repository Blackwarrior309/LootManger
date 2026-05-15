local FRM = FocusRollManager

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

function FRM:ShowDebugUI()
    if not self.debugFrame then
        local f = CreateFrame("Frame", "FocusRollManagerDebugFrame", UIParent)
        f:SetWidth(560)
        f:SetHeight(350)
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

        createLabel(f, "Boss", 30, -52)
        local bossEdit = createEditBox(f, "FocusRollManagerDebugBossEdit", 280, 100, -48, "Lord Marrowgar")
        createButton(f, "Boss Down", 110, 400, -48, function()
            FocusRollManager:DebugBoss(bossEdit:GetText())
        end)

        createLabel(f, "Itemdrop", 30, -92)
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
            createButton(f, label, 90, 100 + (col * 98), -88 - (row * 30), function()
                FocusRollManager:DebugItem(item)
            end)
        end

        local itemEdit = createEditBox(f, "FocusRollManagerDebugItemEdit", 280, 100, -158, "")
        createButton(f, "Item Drop", 110, 400, -158, function()
            FocusRollManager:DebugItem(itemEdit:GetText())
        end)

        createLabel(f, "Roll", 30, -202)
        local playerEdit = createEditBox(f, "FocusRollManagerDebugRollPlayerEdit", 180, 100, -198, UnitName("player") or "")
        local rollEdit = createEditBox(f, "FocusRollManagerDebugRollValueEdit", 60, 292, -198, "87")
        createButton(f, "Add Roll", 110, 400, -198, function()
            FocusRollManager:DebugRoll(playerEdit:GetText(), rollEdit:GetText())
        end)

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 30, -242)
        hint:SetWidth(500)
        hint:SetJustifyH("LEFT")
        hint:SetText("Echte Rolls testest du normal mit /roll. Dieses Fenster erzeugt nur Testdaten fuer Anzeige und Loot-Matching.")

        createButton(f, "Live Clear", 110, 30, -292, function()
            FocusRollManager:ResetRaidData()
        end)
        createButton(f, "Show Main", 110, 150, -292, function()
            FocusRollManager:ToggleUI()
        end)

        self.debugFrame = f
    end

    if self.debugFrame:IsShown() then
        self.debugFrame:Hide()
    else
        self.debugFrame:Show()
    end
end

function FRM:PrintDebugHelp()
    self:Print("Debug:")
    self:Print("/frm debug - Debug-Fenster oeffnen")
    self:Print("/frm debug boss <name> - Bosskill simulieren")
    self:Print("/frm debug item <item> - Itemdrop simulieren")
    self:Print("/frm debug roll <player> <1-100> - Roll-Eintrag simulieren")
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
    elseif sub == "boss" then
        self:DebugBoss(value)
    elseif sub == "item" or sub == "drop" or sub == "loot" then
        self:DebugItem(value)
    elseif sub == "roll" then
        local player, roll = value:match("^(%S+)%s+(%d+)$")
        self:DebugRoll(player, roll)
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

    self:Print("Debug Itemdrop: " .. item)
    self:AddLootItem(item, nil, nil)
end

function FRM:DebugRoll(player, roll)
    player = self:Trim(player or "")
    roll = tonumber(roll)
    if player == "" or not roll then
        self:Print("Nutzung: /frm debug roll <player> <1-100>")
        return
    end

    local db = self:GetDB()
    table.insert(db.rolls, {
        player = player,
        roll = roll,
        low = 1,
        high = 100,
        time = date("%H:%M:%S")
    })
    table.sort(db.rolls, function(a,b) return (a.roll or 0) > (b.roll or 0) end)
    self:RefreshUI()
end
