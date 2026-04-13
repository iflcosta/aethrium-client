-- ============================================================
-- VIP System — Client Module
-- Opcode: 181 (Extended, JSON)
-- ============================================================

local VIP_OPCODE = 181

VipController = Controller:new()

local TIER_COLORS = {
    [0] = "#a0a0a0",
    [1] = "#cd7f32", -- bronze
    [2] = "#c0c0c0", -- silver
    [3] = "#ffd700", -- gold
}

-- ── Data defaults ────────────────────────────────────────────
VipController.tierName      = "No VIP"
VipController.tierColor     = "#a0a0a0"
VipController.statusText    = "Inactive"
VipController.daysRemaining = "0 days"
VipController.expiresAt     = ""
VipController.xpBonus       = "+0%"
VipController.lootBonus     = "+0%"
VipController.depot         = "15,000"
VipController.autoloot      = "10 slots"
VipController.blessDiscount = "No discount"
VipController.hasVip        = false

-- ── Lifecycle ────────────────────────────────────────────────

function VipController:onInit()
    self:registerExtendedOpcode(VIP_OPCODE, function(protocol, opcode, buffer)
        self:onExtendedOpcode(protocol, opcode, buffer)
    end)
end

function VipController:onGameStart()
end

function VipController:onGameEnd()
    self:hide()
end

-- ── Opcode handler ────────────────────────────────────────────

function VipController:onExtendedOpcode(protocol, opcode, buffer)
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" then 
        return 
    end

    if data.action == "open" then
        self:show(data)
    end
end

-- ── Show / Hide ───────────────────────────────────────────────

function VipController:show(data)
    if not self.ui then
        self:loadHtml("game_vip.html")
    end
    self:populate(data)
    self.ui:show()
    self.ui:raise()
    self.ui:focus()
end

function VipController:hide()
    if self.ui then
        self.ui:hide()
    end
end

-- ── Populate ─────────────────────────────────────────────────

function VipController:populate(data)
    local tier = data.tier or 0
    local active = data.active or false

    self.hasVip        = active
    self.tierName      = data.tierName or "No VIP"
    self.tierColor     = TIER_COLORS[tier] or "#a0a0a0"
    self.statusText    = active and "Active" or "Inactive"
    local days = data.daysRemaining or 0
    self.daysRemaining = active and (days .. (days == 1 and " day remaining" or " days remaining")) or "—"
    self.expiresAt     = data.expiresAt and ("Expires: " .. data.expiresAt) or ""
    self.xpBonus       = "+" .. tostring(data.xpBonus or 0) .. "%"
    self.lootBonus     = "+" .. tostring(data.lootBonus or 0) .. "%"
    self.depot         = self:formatNumber(data.depot or 15000)
    self.autoloot      = tostring(data.autoloot or 10) .. " slots"
    self.blessDiscount = (data.blessDiscount and data.blessDiscount > 0)
                            and (tostring(data.blessDiscount) .. "% off")
                            or "No discount"
end

function VipController:formatNumber(n)
    local s = tostring(n)
    local result = ""
    local count = 0
    for i = #s, 1, -1 do
        if count > 0 and count % 3 == 0 then
            result = "," .. result
        end
        result = s:sub(i, i) .. result
        count = count + 1
    end
    return result
end

-- ── Close button ─────────────────────────────────────────────

function VipController:closeVip()
    self:hide()
end
