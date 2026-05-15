local FRM = FocusRollManager

function FRM:CHAT_MSG_SYSTEM(msg)
    -- WotLK roll format often localized; this catches English style:
    -- Player rolls 87 (1-100)
    local player, roll, low, high = string.match(msg or "", "^(%S+) rolls (%d+) %((%d+)%-(%d+)%)")
    if not player then
        -- German client style:
        -- Player würfelt. Ergebnis: 87 (1-100)
        player, roll, low, high = string.match(msg or "", "^(%S+) w\195\188rfelt%. Ergebnis: (%d+) %((%d+)%-(%d+)%)")
    end
    if player and roll then
        local db = self:GetDB()
        table.insert(db.rolls, {
            player = player,
            roll = tonumber(roll),
            low = tonumber(low),
            high = tonumber(high),
            time = date("%H:%M:%S")
        })
        table.sort(db.rolls, function(a,b) return (a.roll or 0) > (b.roll or 0) end)
        self:RefreshUI()
    end
end

function FRM:PrintPlayer(name)
    name = self:Trim(name or "")
    if name == "" then
        self:Print("Nutzung: /frm player <name>")
        return
    end
    local db = self:GetDB()
    local p = db.players[name]
    if not p then
        self:Print("Nicht gefunden: " .. name)
        return
    end
    self:Print(name .. " | " .. (p.class or "UNKNOWN") .. " | " .. (p.focus1 or "") .. " | " .. (p.focus2 or "") .. " | Striche: " .. tostring(p.strikes or 0))
end
