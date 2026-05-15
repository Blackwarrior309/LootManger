local FRM = FocusRollManager

function FRM:BuildUI()
    if self.ui then return end

    local f = CreateFrame("Frame", "FocusRollManagerFrame", UIParent)
    f:SetWidth(940)
    f:SetHeight(620)
    f:SetPoint("CENTER")
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
    title:SetPoint("TOP", 0, -15)
    title:SetText("Focus Roll Manager")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 22, -48)
    text:SetWidth(895)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetText("")

    f.text = text
    self.ui = f
    self:RefreshUI()
end

function FRM:BuildMinimapButton()
    if self.minimapButton then return end

    local btn = CreateFrame("Button", "FocusRollManagerMinimapButton", Minimap)
    btn:SetWidth(31)
    btn:SetHeight(31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 4, 4)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TOPLEFT", -11, 11)

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            FocusRollManager:ShowDebugUI()
        else
            FocusRollManager:ToggleUI()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("FocusRollManager")
        GameTooltip:AddLine("Linksklick: Uebersicht", 1, 1, 1)
        GameTooltip:AddLine("Rechtsklick: Debug", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = btn
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

function FRM:FormatFocusRow(name, player)
    local status = player.status or "active"
    local statusText = status
    if status == "off" or status == "absent" then
        statusText = "|cffff5555" .. status .. "|r"
    else
        statusText = "|cff55ff55" .. status .. "|r"
    end

    return self:ClassColorName(name, player.class) ..
        "  |  " .. (player.class or "UNKNOWN") ..
        "  |  F1: " .. (player.focus1 or "-") ..
        "  |  F2: " .. (player.focus2 or "-") ..
        "  |  " .. statusText ..
        "  |  Striche: " .. tostring(player.strikes or 0)
end

function FRM:ShowCopyBox(titleText, value)
    value = tostring(value or "")

    if not self.copyFrame then
        local f = CreateFrame("Frame", "FocusRollManagerCopyFrame", UIParent)
        f:SetWidth(760)
        f:SetHeight(150)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
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
        title:SetPoint("TOP", 0, -18)
        f.title = title

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 28, -48)
        hint:SetText("Text ist markiert. Mit Ctrl+C kopieren, dann im externen Tool einfuegen.")

        local edit = CreateFrame("EditBox", "FocusRollManagerCopyEditBox", f, "InputBoxTemplate")
        edit:SetWidth(690)
        edit:SetHeight(32)
        edit:SetPoint("TOPLEFT", 34, -78)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
        edit:SetScript("OnEnterPressed", function(self) self:HighlightText() end)
        edit:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        f.edit = edit

        local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        close:SetWidth(90)
        close:SetHeight(24)
        close:SetPoint("BOTTOMRIGHT", -28, 22)
        close:SetText("Schliessen")
        close:SetScript("OnClick", function() f:Hide() end)

        self.copyFrame = f
    end

    self.copyFrame.title:SetText(titleText or "FocusRollManager Export")
    self.copyFrame.edit:SetText(value)
    self.copyFrame:Show()
    self.copyFrame.edit:SetFocus()
    self.copyFrame.edit:HighlightText()
end

function FRM:ShowImportBox()
    if not self.importFrame then
        local f = CreateFrame("Frame", "FocusRollManagerImportFrame", UIParent)
        f:SetWidth(760)
        f:SetHeight(260)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
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
        title:SetPoint("TOP", 0, -18)
        title:SetText("FRM Import")

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 28, -48)
        hint:SetText("FRM1-String hier mit Ctrl+V einfuegen. Danach Import klicken.")

        local edit = CreateFrame("EditBox", "FocusRollManagerImportEditBox", f, "InputBoxTemplate")
        edit:SetWidth(690)
        edit:SetHeight(100)
        edit:SetPoint("TOPLEFT", 34, -78)
        edit:SetAutoFocus(false)
        edit:SetMultiLine(true)
        edit:SetMaxLetters(999999)
        edit:SetFontObject(ChatFontNormal)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
        f.edit = edit

        local importButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        importButton:SetWidth(120)
        importButton:SetHeight(24)
        importButton:SetPoint("BOTTOMRIGHT", -126, 24)
        importButton:SetText("Import")
        importButton:SetScript("OnClick", function()
            FocusRollManager:ImportString(f.edit:GetText() or "")
        end)

        local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        close:SetWidth(90)
        close:SetHeight(24)
        close:SetPoint("BOTTOMRIGHT", -28, 24)
        close:SetText("Schliessen")
        close:SetScript("OnClick", function() f:Hide() end)

        self.importFrame = f
    end

    self.importFrame.edit:SetText("")
    self.importFrame:Show()
    self.importFrame.edit:SetFocus()
end

function FRM:ToggleUI()
    self:BuildUI()
    if self.ui:IsShown() then
        self.ui:Hide()
    else
        self:RefreshUI()
        self.ui:Show()
    end
end

function FRM:RefreshUI()
    if not self.ui or not self.ui.text then return end

    local db = self:GetDB()
    local lines = {}

    table.insert(lines, "|cffffff00Focus-Liste|r")
    table.insert(lines, "Name  |  Klasse  |  Focus 1  |  Focus 2  |  Status  |  Striche")
    table.insert(lines, "--------------------------------------------------------------------------------")

    local names = {}
    for name in pairs(db.players) do table.insert(names, name) end
    table.sort(names)

    for _, name in ipairs(names) do
        local p = db.players[name]
        table.insert(lines, self:FormatFocusRow(name, p))
    end

    table.insert(lines, "")
    table.insert(lines, "|cffffff00Letzter Loot|r")
    if db.loot.lastBoss and db.loot.lastBoss ~= "" then
        table.insert(lines, "Boss: " .. db.loot.lastBoss)
    end
    if db.loot.items and #db.loot.items > 0 then
        for _, item in ipairs(db.loot.items) do
            table.insert(lines, "- " .. (item.link or item.name or ""))
            local interested = self:FindInterested(item.name or item.link or "")
            if #interested == 0 then
                table.insert(lines, "  keine Focus-Interessenten")
            else
                for _, p in ipairs(interested) do
                    table.insert(lines, "  -> " .. self:ClassColorName(p.name, p.class) .. " | Striche: " .. tostring(p.strikes or 0))
                end
            end
        end
    else
        table.insert(lines, "- kein Loot erkannt")
    end

    table.insert(lines, "")
    table.insert(lines, "|cffffff00Fehlende Focuses im aktuellen Raid|r")
    local missing = self:GetMissingFocus()
    if #missing == 0 then
        table.insert(lines, "- keine")
    else
        for _, name in ipairs(missing) do
            table.insert(lines, "- " .. name)
        end
    end

    table.insert(lines, "")
    table.insert(lines, "|cffffff00Top Rolls|r")
    for i = 1, math.min(8, #(db.rolls or {})) do
        local r = db.rolls[i]
        table.insert(lines, i .. ". " .. r.player .. " - " .. tostring(r.roll))
    end

    self.ui.text:SetText(table.concat(lines, "\n"))
end
