-- ============================================================
-- Reset System — Client Module
-- Opcode: 180 (Extended, JSON)
-- ============================================================

local RESET_OPCODE = 180

ResetController = Controller:new()

local resetButton = nil

local ORDINALS = {"First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"}

local SKILL_NAMES_BY_ID = {
    [0]  = "fist",
    [1]  = "club",
    [2]  = "sword",
    [3]  = "axe",
    [4]  = "distance",
    [5]  = "shielding",
    [6]  = "fishing",
    [12] = "magic",
}

-- ── Data defaults ────────────────────────────────────────────
ResetController.resetTitle    = "? RESET"
ResetController.resetSubtitle = "Nível necessário: ?   Cap de XP: ?"
ResetController.reduxPct      = "-30%"
ResetController.bonusHP       = "+0"
ResetController.bonusMana     = "+0"
ResetController.bonusCap      = "+0"
ResetController.accHP         = "+0"
ResetController.accMana       = "+0"
ResetController.accCap        = "+0"
ResetController.milestone     = ""
ResetController.hasMilestone  = false
ResetController.skills        = {}

-- ── Lifecycle ────────────────────────────────────────────────

function ResetController:onInit()
    self:registerExtendedOpcode(RESET_OPCODE, function(protocol, opcode, buffer)
        self:onExtendedOpcode(protocol, opcode, buffer)
    end)
end

function ResetController:onGameStart()
end

function ResetController:onGameEnd()
    self:hide()
end

-- ── Opcode handler ────────────────────────────────────────────

function ResetController:onExtendedOpcode(protocol, opcode, buffer)
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" then return end

    if data.action == "open" then
        self:show(data)
    elseif data.action == "done" then
        self:hide()
    elseif data.action == "error" then
        self:hide()
        if data.message then
            displayErrorBox(tr("Reset"), tr(data.message))
        end
    end
end

-- ── Show / Hide / Toggle ─────────────────────────────────────

function ResetController:show(data)
    if not self.ui then
        self:loadHtml("game_reset.html")
    end

    self:populate(data)
    self.ui:show()
    self.ui:raise()
    self.ui:focus()
    if resetButton then resetButton:setOn(true) end
end

function ResetController:hide()
    if self.ui then
        self.ui:hide()
    end
    if resetButton then resetButton:setOn(false) end
end

function ResetController:toggle()
    if self.ui and self.ui:isVisible() then
        self:hide()
    else
        self:sendExtendedOpcode(RESET_OPCODE, json.encode({ action = "request" }))
        if resetButton then resetButton:setOn(true) end
    end
end

-- ── Populate (data binding) ───────────────────────────────────

function ResetController:populate(data)
    local ord = ORDINALS[data.resetNum] or tostring(data.resetNum)
    local reduxPct = data.reduxPct or 30

    self.resetTitle    = ord .. " RESET"
    self.resetSubtitle = "Required: " .. (data.requiredLevel or "?") ..
                         "   XP Limit: " .. (data.xpCap or "?")
    self.reduxPct      = "-" .. reduxPct .. "%"
    self.bonusHP       = "+" .. tostring(data.bonusHP  or 0)
    self.bonusMana     = "+" .. tostring(data.bonusMana or 0)
    self.bonusCap      = "+" .. tostring(data.bonusCap  or 0)
    self.accHP         = "+" .. tostring(data.accHP   or 0)
    self.accMana       = "+" .. tostring(data.accMana  or 0)
    self.accCap        = "+" .. tostring(data.accCap   or 0)
    self.hasMilestone  = data.milestone ~= nil
    self.milestone     = data.milestone or ""
    self.skills        = data.skills or {}
end

-- ── Buttons (called from HTML onclick) ───────────────────────

function ResetController:confirmReset()
    self:sendExtendedOpcode(RESET_OPCODE, json.encode({ action = "confirm" }))
    self:hide()
end

function ResetController:cancelReset()
    self:hide()
end

-- ── Buy Skill Seal ────────────────────────────────────────────

function ResetController:buySeal(skillId)
    local skillName = SKILL_NAMES_BY_ID[skillId] or tostring(skillId)
    displayGeneralBox(
        tr("Skill Seal"),
        tr(string.format("Selar '%s' por 50 Tibia Coins?", skillName)),
        {
            { text = tr("Confirmar"), callback = function()
                g_game.talk("!sealskill " .. skillName)
                scheduleEvent(function()
                    self:sendExtendedOpcode(RESET_OPCODE, json.encode({ action = "request" }))
                end, 500)
            end},
            { text = tr("Cancelar"), callback = function() end },
        }, true)
end
