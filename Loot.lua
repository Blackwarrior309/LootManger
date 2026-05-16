local FRM = FocusRollManager

local wowGetNumLootItems = GetNumLootItems
local wowGetLootSlotLink = GetLootSlotLink

function FRM:GetNumLootItems()
    local db = self:GetDB()
    if db.settings and db.settings.debugLiveLoot then
        return #(self.debugLootLinks or {})
    end
    return wowGetNumLootItems and wowGetNumLootItems() or 0
end

function FRM:GetLootSlotLink(slot)
    local db = self:GetDB()
    if db.settings and db.settings.debugLiveLoot then
        return self.debugLootLinks and self.debugLootLinks[slot] or nil
    end
    return wowGetLootSlotLink and wowGetLootSlotLink(slot) or nil
end

function FRM:AddLootItem(name, link, id)
    local db = self:GetDB()
    db.loot.items = db.loot.items or {}
    table.insert(db.loot.items, {
        link = link,
        name = name,
        id = id
    })
    self:PrintInterestedForItem(name or link)
    if self.RefreshUI then self:RefreshUI() end
end

function FRM:LOOT_OPENED()
    local db = self:GetDB()
    if db.settings and db.settings.debugLiveLoot then
        db.settings.debugLastLootEvent = "LOOT_OPENED"
    end
    db.loot.items = {}

    local count = self:GetNumLootItems()
    for slot = 1, count do
        local link = self:GetLootSlotLink(slot)
        if link then
            local name = self:GetItemNameFromLink(link)
            local id = self:GetItemID(link)
            self:AddLootItem(name, link, id)
            self:Print("Loot erkannt: " .. link)
        end
    end

    if self.RefreshUI then self:RefreshUI() end
end

function FRM:CHAT_MSG_LOOT(msg)
    -- Fallback für Lootmeldungen. Itemlinks aus Chat extrahieren.
    local db = self:GetDB()
    local itemLink = string.match(msg or "", "|c.-|h%[.-%]|h|r")
    if itemLink then
        local name = self:GetItemNameFromLink(itemLink)
        local id = self:GetItemID(itemLink)
        self:AddLootItem(name, itemLink, id)
    end
end

function FRM:FindInterested(item)
    local db = self:GetDB()
    local normalized = self:NormalizeItem(item)
    local result = {}

    for name, p in pairs(db.players) do
        if p.status ~= "off" and p.status ~= "absent" then
            local f1 = self:NormalizeItem(p.focus1 or "")
            local f2 = self:NormalizeItem(p.focus2 or "")
            if f1 == normalized or f2 == normalized then
                table.insert(result, {
                    name = name,
                    class = p.class or "UNKNOWN",
                    strikes = tonumber(p.strikes) or 0
                })
            end
        end
    end

    table.sort(result, function(a,b)
        if a.strikes == b.strikes then return a.name < b.name end
        return a.strikes < b.strikes
    end)

    return result
end

function FRM:PrintInterestedForItem(item)
    local interested = self:FindInterested(item)
    if #interested == 0 then
        self:Print("Keine Focus-Spieler für: " .. tostring(item))
        return
    end

    self:Print("Interessenten für " .. tostring(item) .. ":")
    for _, p in ipairs(interested) do
        self:Print("- " .. p.name .. " (" .. p.class .. ", Striche: " .. p.strikes .. ")")
    end
end

function FRM:PrintItem(item)
    if not item or item == "" then
        self:Print("Nutzung: /frm item <item>")
        return
    end
    self:PrintInterestedForItem(item)
end

function FRM:PrintLoot()
    local db = self:GetDB()
    if not db.loot.items or #db.loot.items == 0 then
        self:Print("Noch kein Loot erkannt.")
        return
    end
    for _, item in ipairs(db.loot.items) do
        self:Print(item.link or item.name)
    end
end
