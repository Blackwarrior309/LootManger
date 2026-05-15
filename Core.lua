FocusRollManager = FocusRollManager or {}
local FRM = FocusRollManager

FRM.version = "0.1.0"
FRM.prefix = "FRM"

local frame = CreateFrame("Frame")
FRM.frame = frame

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

frame:SetScript("OnEvent", function(self, event, ...)
    if FRM[event] then
        FRM[event](FRM, ...)
    end
end)

function FRM:ADDON_LOADED(addonName)
    if addonName ~= "FocusRollManager" then return end
    self:InitDB()
end

function FRM:PLAYER_LOGIN()
    self:Print("geladen. /frm help")
    self:BuildUI()
    self:BuildMinimapButton()
end

SLASH_FOCUSROLLMANAGER1 = "/frm"
SLASH_FOCUSROLLMANAGER2 = "/focusrollmanager"

SlashCmdList["FOCUSROLLMANAGER"] = function(msg)
    FRM:HandleSlash(msg or "")
end

function FRM:HandleSlash(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")

    if cmd == "" or cmd == "show" then
        self:ToggleUI()
    elseif cmd == "help" then
        self:PrintHelp()
    elseif cmd == "import" then
        if self:Trim(rest or "") == "" then
            self:ShowImportBox()
        else
            self:ImportString(rest)
        end
    elseif cmd == "export" then
        self:PrintExportString()
    elseif cmd == "roster" then
        self:PrintRosterExport()
    elseif cmd == "loot" then
        self:PrintLoot()
    elseif cmd == "clear" then
        self:ClearFocus()
    elseif cmd == "reset" then
        self:ResetRaidData()
    elseif cmd == "player" then
        self:PrintPlayer(rest)
    elseif cmd == "item" then
        self:PrintItem(rest)
    elseif cmd == "win" then
        local player, item = rest:match("^(%S+)%s+(.+)$")
        self:MarkWin(player, item)
    elseif cmd == "missing" then
        self:PrintMissingFocus()
    elseif cmd == "debug" then
        self:HandleDebug(rest)
    else
        self:Print("Unbekannter Befehl. /frm help")
    end
end

function FRM:PrintHelp()
    self:Print("/frm show - Fenster öffnen")
    self:Print("/frm roster - Raidroster als Exportstring ausgeben")
    self:Print("/frm import - Importfenster oeffnen")
    self:Print("/frm import <FRM1...> - kurzer Import ueber Chat")
    self:Print("/frm export - Focusdaten exportieren")
    self:Print("/frm loot - letzten Loot anzeigen")
    self:Print("/frm item <item> - Interessenten anzeigen")
    self:Print("/frm player <name> - Spieler anzeigen")
    self:Print("/frm win <player> <item> - Gewinner markieren")
    self:Print("/frm missing - Raider ohne Focus anzeigen")
    self:Print("/frm debug - Debug-Fenster oeffnen")
    self:Print("/frm clear - Focusdaten löschen")
end
