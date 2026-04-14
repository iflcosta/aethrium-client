-- ============================================================
-- Aethrium Battle Pass — UI Controller
-- Opcode 150 | Dark Premium Theme
-- ============================================================

local BATTLEPASS_OPCODE = 150

-- Module-level state
local battlePassWindow = nil
local battlePassButton = nil
local currentTab       = "daily"   -- "daily" | "season"
local dailyTimerEvent  = nil
local cachedData       = nil       -- last payload from server

-- ── Lifecycle ────────────────────────────────────────────────

function init()
    g_ui.importStyle("game_battlepass_otui.otui")

    ProtocolGame.registerExtendedOpcode(BATTLEPASS_OPCODE, onExtendedOpcode)

    battlePassWindow = g_ui.createWidget("BattlePassWindow", g_ui.getRootWidget())
    if battlePassWindow then
        battlePassWindow:hide()
    end

    battlePassButton = modules.game_mainpanel.addToggleButton(
        "battlePassButton",
        tr("Battle Pass"),
        "/modules/game_cyclopedia/images/boss/icon_star_gold.png",
        toggle
    )
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(BATTLEPASS_OPCODE)
    stopDailyTimer()

    if battlePassWindow then
        battlePassWindow:destroy()
        battlePassWindow = nil
    end

    if battlePassButton then
        battlePassButton:destroy()
        battlePassButton = nil
    end

    cachedData = nil
end

-- ── Network ──────────────────────────────────────────────────

function toggle()
    if not g_game.isOnline() then return end

    if battlePassWindow:isVisible() then
        battlePassWindow:hide()
        stopDailyTimer()
    else
        -- Request fresh payload; window shows after server responds
        g_game.getProtocolGame():sendExtendedOpcode(BATTLEPASS_OPCODE,
            json.encode({ action = "open_request" }))
    end
end

function onExtendedOpcode(protocol, opcode, buffer)
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" then
        g_logger.error("[BattlePass] Bad JSON: " .. tostring(buffer))
        return
    end

    if data.action == "open" or data.action == "update" then
        cachedData = data
        refresh(data)

        if not battlePassWindow:isVisible() then
            battlePassWindow:show()
            battlePassWindow:raise()
            battlePassWindow:focus()
            startDailyTimer()
        end
    end
end

-- ── Actions ──────────────────────────────────────────────────

function claimReward(tier, track)
    if not g_game.isOnline() then return end
    g_game.getProtocolGame():sendExtendedOpcode(BATTLEPASS_OPCODE,
        json.encode({ action = "claim", tier = tier, track = track }))
end

function buyElite()
    if not g_game.isOnline() then return end

    local cost = (cachedData and cachedData.eliteCost) or 0
    local msg  = tr("Upgrade to Elite Pass for %d Tibia Coins?", cost)

    local messageBox
    local function onConfirm()
        messageBox:ok()
        g_game.getProtocolGame():sendExtendedOpcode(BATTLEPASS_OPCODE,
            json.encode({ action = "buy_elite" }))
    end
    local function onCancel()
        messageBox:cancel()
    end

    messageBox = displayGeneralBox(tr("Elite Pass"), msg,
        { { text = tr("Confirm"), callback = onConfirm },
          { text = tr("Cancel"),  callback = onCancel  } },
        onConfirm, onCancel)
end

-- ── Tab Switching ────────────────────────────────────────────

function switchTab(name)
    currentTab = name
    local win = battlePassWindow

    local tabDaily  = win:recursiveGetChildById("tabDaily")
    local tabSeason = win:recursiveGetChildById("tabSeason")
    local daily     = win:recursiveGetChildById("dailyPanel")
    local season    = win:recursiveGetChildById("seasonPanel")

    if name == "daily" then
        daily:show()
        season:hide()
        -- Active tab style (cyan)
        tabDaily:setColor("#00E5FF")
        tabDaily:setBorderColor("#00E5FF")
        tabDaily:setBackgroundColor("#1A1A2E")
        -- Inactive tab
        tabSeason:setColor("#888888")
        tabSeason:setBorderColor("#333333")
        tabSeason:setBackgroundColor("#0D0D14")
    else
        season:show()
        daily:hide()
        -- Active tab style (gold tint for season)
        tabSeason:setColor("#FFD700")
        tabSeason:setBorderColor("#FFD700")
        tabSeason:setBackgroundColor("#1A1A1A")
        -- Inactive tab
        tabDaily:setColor("#888888")
        tabDaily:setBorderColor("#333333")
        tabDaily:setBackgroundColor("#0D0D14")
    end
end

-- ── Full Refresh ─────────────────────────────────────────────

function refresh(data)
    refreshHeader(data)
    populateDailyTab(data.dailyTasks or {})
    populateSeasonTab(data.rewards or {}, data.elite or false, data.level or 1)
    refreshEliteBanner(data)
    -- Restore the last active tab (don't reset on update)
    switchTab(currentTab)
end

-- ── Header ───────────────────────────────────────────────────

function refreshHeader(data)
    local win = battlePassWindow

    -- Level badge
    local lvl = data.level or 1
    win:recursiveGetChildById("levelNumber"):setText(tostring(lvl))

    -- XP bar
    local xp     = data.xp    or 0
    local xpNext = math.max(data.xpNext or 1000, 1)
    local pct    = math.min(100, math.floor(xp / xpNext * 100))
    local xpBar  = win:recursiveGetChildById("xpBar")
    xpBar:setMinimum(0)
    xpBar:setMaximum(100)
    xpBar:setValue(pct)
    win:recursiveGetChildById("xpLabel"):setText(
        string.format("%d / %d XP  (%d%%)", xp, xpNext, pct))

    -- Season info
    local season   = data.season   or 1
    local daysLeft = data.daysLeft or 0
    win:recursiveGetChildById("seasonLabel"):setText(tr("Season %d", season))
    win:recursiveGetChildById("seasonTimer"):setText(tr("%d days left", daysLeft))
end

-- ── Daily Countdown Timer ─────────────────────────────────────

function stopDailyTimer()
    if dailyTimerEvent then
        removeEvent(dailyTimerEvent)
        dailyTimerEvent = nil
    end
end

function startDailyTimer()
    stopDailyTimer()

    -- Calculate seconds until next midnight (local time)
    local now    = os.time()
    local t      = os.date("*t", now)
    local todayMidnight = os.time({ year = t.year, month = t.month, day = t.day,
                                    hour = 0, min = 0, sec = 0 })
    local nextMidnight  = todayMidnight + 86400
    local remaining     = nextMidnight - now

    local function tick()
        if not battlePassWindow or not battlePassWindow:isVisible() then
            dailyTimerEvent = nil
            return
        end

        remaining = remaining - 1
        if remaining < 0 then remaining = 0 end

        local h = math.floor(remaining / 3600)
        local m = math.floor((remaining % 3600) / 60)
        local s = remaining % 60

        local label = battlePassWindow:recursiveGetChildById("dailyTimer")
        if label then
            label:setText(tr("Daily reset: %02d:%02d:%02d", h, m, s))
        end

        if remaining > 0 then
            dailyTimerEvent = scheduleEvent(tick, 1000)
        else
            dailyTimerEvent = nil
        end
    end

    dailyTimerEvent = scheduleEvent(tick, 1000)
end

-- ── Daily Tab ────────────────────────────────────────────────

function populateDailyTab(tasks)
    local list = battlePassWindow:recursiveGetChildById("missionList")
    list:destroyChildren()

    if #tasks == 0 then
        local empty = g_ui.createWidget("Label", list)
        empty:setText(tr("No daily missions today."))
        empty:setColor("#666666")
        return
    end

    for _, t in ipairs(tasks) do
        local row = g_ui.createWidget("MissionTask", list)

        local label = row:getChildById("taskLabel")
        label:setText(t.label or t.type or "Task")
        if t.completed then
            label:setColor("#50E050")
        else
            label:setColor("#DDDDDD")
        end

        local cur    = t.current or 0
        local target = math.max(t.target or 1, 1)
        row:getChildById("taskProgress"):setText(
            string.format("%d / %d", cur, target))

        local pct = math.min(100, math.floor(cur / target * 100))
        local bar = row:getChildById("taskBar")
        bar:setMinimum(0)
        bar:setMaximum(100)
        bar:setValue(pct)
        if t.completed then
            bar:setBackgroundColor("#50E05099")  -- green tint when done
        end

        if t.xp then
            row:getChildById("taskXp"):setText(string.format("+%d BP XP", t.xp))
        end
    end
end

-- ── Season Tab ───────────────────────────────────────────────

-- Returns the display name for a reward table
local function rewardName(reward)
    if not reward or not reward.type then return tr("None") end
    local t = reward.type
    if t == "item"   then return string.format("Item #%d x%d", reward.id or 0, reward.count or 1) end
    if t == "coins"  then return string.format("%d Coins",     reward.amount or 0) end
    if t == "outfit" then return string.format("Outfit #%d",   reward.id or 0) end
    if t == "mount"  then return string.format("Mount #%d",    reward.id or 0) end
    if t == "xp"     then return tr("XP Boost") end
    return tostring(t)
end

-- Applies a color overlay to an icon widget to signal locked/dim state
local function dimWidget(widget, dimmed)
    if dimmed then
        widget:setImageColor("#FFFFFF44")
    else
        widget:setImageColor("#FFFFFFFF")
    end
end

-- Sets the state of a claim button: "claim_free", "claim_elite", "claimed", "locked", "no_elite"
local function applyButtonState(btn, state, tier, track)
    btn:setEnabled(true)
    if state == "claim_free" then
        btn:setStyle("BpButtonClaim")
        btn:setText(tr("CLAIM"))
        btn.onClick = function() claimReward(tier, "free") end
    elseif state == "claim_elite" then
        btn:setStyle("BpButtonEliteClaim")
        btn:setText(tr("CLAIM"))
        btn.onClick = function() claimReward(tier, "elite") end
    elseif state == "claimed" then
        btn:setStyle("BpButtonLocked")
        btn:setText(tr("CLAIMED"))
        btn:setEnabled(false)
    elseif state == "no_elite" then
        btn:setStyle("BpButtonLocked")
        btn:setText(tr("ELITE"))
        btn:setEnabled(false)
    else  -- "locked"
        btn:setStyle("BpButtonLocked")
        btn:setText(tr("LOCKED"))
        btn:setEnabled(false)
    end
end

function populateSeasonTab(rewards, isElite, playerLevel)
    local list = battlePassWindow:recursiveGetChildById("rewardList")
    list:destroyChildren()

    for _, r in ipairs(rewards) do
        local tier       = r.tier
        local locked     = (playerLevel < tier)
        local freeReward  = r.free  or {}
        local eliteReward = r.elite or {}

        local row = g_ui.createWidget("RewardRow", list)

        -- Tier badge
        local badge = row:getChildById("tierBadge")
        badge:setText(tostring(tier))
        if locked then
            badge:setColor("#555555")
        else
            badge:setColor("#AAAAAA")
        end

        -- ── Free slot ────────────────────────────────
        local freeSlot = row:getChildById("freeSlot")
        local freeIcon = freeSlot:getChildById("freeIcon")
        local freeName = freeSlot:getChildById("freeName")
        local freeBtn  = freeSlot:getChildById("freeBtn")

        freeName:setText(rewardName(freeReward))
        dimWidget(freeIcon, locked)

        -- Load item icon if applicable
        if freeReward.type == "item" and freeReward.id then
            freeIcon:setItemId(freeReward.id)
        end

        if locked then
            applyButtonState(freeBtn, "locked", tier, "free")
        elseif r.claimedFree then
            applyButtonState(freeBtn, "claimed", tier, "free")
            freeName:setColor("#50E05088")
        else
            applyButtonState(freeBtn, "claim_free", tier, "free")
        end

        -- ── Elite slot ───────────────────────────────
        local eliteSlot = row:getChildById("eliteSlot")
        local eliteIcon = eliteSlot:getChildById("eliteIcon")
        local eliteName = eliteSlot:getChildById("eliteName")
        local eliteBtn  = eliteSlot:getChildById("eliteBtn")

        eliteName:setText(rewardName(eliteReward))
        dimWidget(eliteIcon, locked or not isElite)

        if eliteReward.type == "item" and eliteReward.id then
            eliteIcon:setItemId(eliteReward.id)
        end

        if locked then
            applyButtonState(eliteBtn, "locked", tier, "elite")
        elseif not isElite then
            applyButtonState(eliteBtn, "no_elite", tier, "elite")
        elseif r.claimedElite then
            applyButtonState(eliteBtn, "claimed", tier, "elite")
            eliteName:setColor("#FFD70044")
        else
            applyButtonState(eliteBtn, "claim_elite", tier, "elite")
        end
    end
end

-- ── Elite Banner ─────────────────────────────────────────────

function refreshEliteBanner(data)
    local banner = battlePassWindow:getChildById("eliteBanner")
    if not banner then return end

    if data.elite then
        banner:hide()
        return
    end

    banner:show()
    local cost     = data.eliteCost   or 0
    local discount = data.vipDiscount or 0

    local labelText
    if discount > 0 then
        labelText = tr("Go Elite! Unlock exclusive rewards — %d TC  (-%d%% VIP discount)", cost, discount)
    else
        labelText = tr("Go Elite! Unlock exclusive rewards — %d TC", cost)
    end

    local lbl = banner:recursiveGetChildById("eliteBannerLabel")
    if lbl then lbl:setText(labelText) end
end
