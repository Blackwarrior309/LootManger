-- Sync.lua
-- Broadcast FRM events into the chat frame so the external Strichliste tool
-- can tail the WoW chat log (LoggingChat). No custom channel, no whispers,
-- no out-of-process API needed — works in WoW 3.3.5a.
--
-- Wire format (one line per event, payload pipe-delimited, fields escaped
-- with FRM:EscapeField — same scheme as the FRM1 import string):
--
--   [FRM] HELLO|<version>|<unixtime>
--   [FRM] AWARD|<player>|<item>|<strikes>
--   [FRM] PLAYER|<player>|<class>|<focus1>|<focus2>|<status>|<strikes>
--   [FRM] CLEAR

local FRM = FocusRollManager

-- Pull the value out of GetAddOnMetadata when available so the version stays
-- in sync with the .toc file.
local function GetAddonVersion()
    if GetAddOnMetadata then
        local v = GetAddOnMetadata("LootManger-main", "Version")
            or GetAddOnMetadata("FocusRollManager", "Version")
        if v and v ~= "" then return v end
    end
    return FRM.version or "0.0.0"
end

local function EnsureSyncState()
    local db = FRM:GetDB()
    db.sync = db.sync or {}
    if db.sync.active == nil      then db.sync.active = false end
    if db.sync.sentCount == nil   then db.sync.sentCount = 0 end
    if db.sync.startedAt == nil   then db.sync.startedAt = 0 end
    return db.sync
end

function FRM:SyncIsActive()
    local s = EnsureSyncState()
    return s.active == true
end

-- Internal: write one tagged line into the default chat frame. With
-- LoggingChat(true) WoW dumps every message that lands in the chat frame to
-- Logs/WoWChatLog.txt, so the external tail picks it up.
function FRM:_Emit(line)
    if not self:SyncIsActive() then return end
    if not line or line == "" then return end
    DEFAULT_CHAT_FRAME:AddMessage("[FRM] " .. line)
    local s = EnsureSyncState()
    s.sentCount = (s.sentCount or 0) + 1
end

function FRM:BroadcastHello()
    self:_Emit("HELLO|" .. self:EscapeField(GetAddonVersion()) .. "|" .. tostring(time()))
end

function FRM:BroadcastAward(player, item, strikes)
    self:_Emit("AWARD|"
        .. self:EscapeField(player or "")
        .. "|" .. self:EscapeField(item or "")
        .. "|" .. self:EscapeField(tostring(strikes or 0)))
end

function FRM:BroadcastPlayer(name)
    local db = self:GetDB()
    local p = db.players[name]
    if not p then return end
    self:_Emit("PLAYER|"
        .. self:EscapeField(name)
        .. "|" .. self:EscapeField(p.class or "UNKNOWN")
        .. "|" .. self:EscapeField(p.focus1 or "")
        .. "|" .. self:EscapeField(p.focus2 or "")
        .. "|" .. self:EscapeField(p.status or "active")
        .. "|" .. self:EscapeField(tostring(p.strikes or 0)))
end

function FRM:BroadcastClear()
    self:_Emit("CLEAR")
end

function FRM:BroadcastAllPlayers()
    local db = self:GetDB()
    local names = {}
    for name in pairs(db.players) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        self:BroadcastPlayer(name)
    end
end

-- Toggle chat logging — the external tool reads from this file.
local function SetChatLog(enabled)
    if type(LoggingChat) == "function" then
        LoggingChat(enabled and true or false)
        return true
    end
    return false
end

function FRM:SyncStart()
    local s = EnsureSyncState()
    if s.active then
        self:Print("Live Sync laeuft bereits.")
        return
    end
    SetChatLog(true)
    s.active = true
    s.startedAt = time()
    s.sentCount = 0
    self:BroadcastHello()
    self:BroadcastClear()       -- external tool starts from a clean slate
    self:BroadcastAllPlayers()  -- then receives the current full state
    self:Print("|cff55ff55Live Sync gestartet|r — Chatlog aktiviert, externer Strichliste empfaengt jetzt Events.")
    if self.RefreshUI then self:RefreshUI() end
end

function FRM:SyncStop()
    local s = EnsureSyncState()
    if not s.active then
        self:Print("Live Sync ist nicht aktiv.")
        return
    end
    s.active = false
    SetChatLog(false)
    self:Print("|cffff5555Live Sync gestoppt|r — Chatlog deaktiviert.")
    if self.RefreshUI then self:RefreshUI() end
end

function FRM:SyncPush()
    local s = EnsureSyncState()
    if not s.active then
        self:Print("Live Sync nicht aktiv. Erst /frm sync start.")
        return
    end
    self:BroadcastClear()
    self:BroadcastAllPlayers()
    self:Print("Vollsync gepusht (" .. (s.sentCount or 0) .. " Events gesamt).")
end

-- Combat-safe ReloadUI for the external "Vollsync" backup path.
function FRM:ReloadForSync()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        self:Print("|cffff5555In Kampf — Reload erst nach Boss.|r")
        return
    end
    self:Print("Reload fuer Vollsync...")
    ReloadUI()
end

-- Slash-command dispatcher: /frm sync start|stop|push|status
function FRM:HandleSync(arg)
    arg = (arg or ""):lower()
    arg = arg:match("^%s*(.-)%s*$") or ""

    if arg == "" or arg == "status" then
        local s = EnsureSyncState()
        if s.active then
            self:Print("Sync: AN | seit " .. tostring(s.startedAt) .. " | " ..
                tostring(s.sentCount or 0) .. " Events")
        else
            self:Print("Sync: AUS")
        end
        return
    end
    if arg == "start" then self:SyncStart(); return end
    if arg == "stop"  then self:SyncStop();  return end
    if arg == "push"  then self:SyncPush();  return end

    self:Print("Nutzung: /frm sync [start|stop|push|status]")
end
