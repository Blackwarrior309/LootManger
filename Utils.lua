local FRM = FocusRollManager

function FRM:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99FRM|r: " .. tostring(msg))
end

function FRM:Trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function FRM:Lower(s)
    return string.lower(s or "")
end

function FRM:Split(str, sep)
    local t = {}
    sep = sep or "|"
    if not str then return t end
    local pattern = "([^" .. sep .. "]+)"
    string.gsub(str, pattern, function(c) table.insert(t, c) end)
    return t
end

function FRM:SplitSemi(str)
    local out = {}
    local current = ""
    for i = 1, string.len(str or "") do
        local c = string.sub(str, i, i)
        if c == ";" then
            table.insert(out, current)
            current = ""
        else
            current = current .. c
        end
    end
    table.insert(out, current)
    return out
end

function FRM:EscapeField(s)
    s = tostring(s or "")
    s = s:gsub("|", "/")
    s = s:gsub(";", ",")
    return s
end

function FRM:GetItemID(itemLink)
    if not itemLink then return nil end
    local id = itemLink:match("item:(%d+):")
    return tonumber(id)
end

function FRM:GetItemNameFromLink(itemLink)
    if not itemLink then return "" end
    local name = itemLink:match("%[(.-)%]")
    return name or itemLink
end

function FRM:NormalizeItem(item)
    if not item then return "" end
    local key = self:Lower(self:Trim(item))
    if self.itemSynonyms and self.itemSynonyms[key] then
        return self.itemSynonyms[key]
    end
    return self:Trim(item)
end
