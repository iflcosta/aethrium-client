-- ============================================================
-- Battle Pass — Minimalist Dashboard Implementation
-- Opcode: 150 (Extended, JSON)
-- ============================================================

local BATTLEPASS_OPCODE = 150

BattlePassHtml = Controller:new()

-- ── Reactive Data (property binding) ─────────────────────────

BattlePassHtml.seasonLabel     = "Season 1"
BattlePassHtml.daysLeft        = "60 days left"
BattlePassHtml.currentLevel    = 1
BattlePassHtml.xpLabel         = "0 / 0 XP"
BattlePassHtml.xpPercent       = 0
BattlePassHtml.eliteStatusText = "Standard Pass"
BattlePassHtml.eliteBtnText    = "Buy Elite Pass"
BattlePassHtml.eliteBtnEnabled = true

-- Mission List
BattlePassHtml.tasks = {}

-- Internal State
BattlePassHtml._isElite = false

-- ── Lifecycle ────────────────────────────────────────────────

function BattlePassHtml:onInit()
    self:registerExtendedOpcode(BATTLEPASS_OPCODE, function(protocol, opcode, buffer)
        self:onExtendedOpcode(protocol, opcode, buffer)
    end)
end

function BattlePassHtml:onGameEnd()
    self:hide()
end

-- ── Opcode handler ────────────────────────────────────────────

function BattlePassHtml:onExtendedOpcode(protocol, opcode, buffer)
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" then return end

    if data.action == "open" or data.action == "update" then
        self:show(data)
    end
end

-- ── UI Control ───────────────────────────────────────────────

function BattlePassHtml:toggle()
    if self.ui and self.ui:isVisible() then
        self:hide()
    else
        self:sendExtendedOpcode(BATTLEPASS_OPCODE, json.encode({ action = "open_request" }))
    end
end

function BattlePassHtml:show(data)
    if not self.ui then
        -- Explicitly load HTML + CSS
        self:loadHtml("game_battlepass_html.html", "game_battlepass_html.css")
    end
    self:populate(data)
    self.ui:centerIn('parent')
    self.ui:setDraggable(true)
    self.ui:show()
    self.ui:raise()
    self.ui:focus()
end

function BattlePassHtml:hide()
    if self.ui then
        self.ui:hide()
    end
end

-- ── Data Population ──────────────────────────────────────────

function BattlePassHtml:populate(data)
    self._isElite = data.elite or false
    self.currentLevel = data.level or 1
    
    -- Header
    self.seasonLabel = "Season " .. tostring(data.season or 1)
    local days = data.daysLeft or 0
    self.daysLeft = tostring(days) .. (days == 1 and " day" or " days") .. " left"

    -- XP & Elite Status
    local xp = data.xp or 0
    local xpNext = data.xpNext or 1000
    self.xpLabel = string.format("%d / %d XP", xp, xpNext)
    self.xpPercent = math.min(100, math.floor((xp / math.max(xpNext, 1)) * 100))
    self.eliteStatusText = self._isElite and "Elite Status: ACTIVE" or "Standard Pass"

    -- Elite Pass Button
    if self._isElite then
        self.eliteBtnText = "Elite Active"
        self.eliteBtnEnabled = false
    else
        local cost = data.eliteCost or 500
        local disc = data.vipDiscount or 0
        self.eliteBtnText = disc > 0 and string.format("Upgrade to Elite (-%d%%)", disc) 
                                    or string.format("Upgrade to Elite (%d TC)", cost)
        self.eliteBtnEnabled = true
    end

    -- Process Daily Tasks
    local tasks = {}
    local receivedTasks = data.dailyTasks or {}
    for i = 1, 4 do -- Support up to 4 tasks in the dashboard
        local t = receivedTasks[i]
        if t then
            table.insert(tasks, {
                label = t.label or "Unknown Task",
                progress = string.format("%d / %d", t.current or 0, t.target or 1),
                percent = math.min(100, math.floor(((t.current or 0) / math.max(t.target or 1, 1)) * 100)),
                done = t.completed or false,
                statusColor = (t.completed) and "#50e050" or "#ffffff"
            })
        end
    end
    self.tasks = tasks
end

-- ── Callbacks ────────────────────────────────────────────────

function BattlePassHtml:openWebsite()
    -- Subistitua pelo seu link real
    g_platform.openUrl("https://aethrium-baiak.com/battlepass")
end

function BattlePassHtml:buyElite()
    self:sendExtendedOpcode(BATTLEPASS_OPCODE, json.encode({ action = "buy_elite" }))
end

function BattlePassHtml:close()
    self:hide()
end
