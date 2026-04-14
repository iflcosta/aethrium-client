-- Battle Pass Dashboard (Standard Sorky)
local BATTLEPASS_OPCODE = 150

battlePassWindow = nil
battlePassButton = nil

function init()
    -- Native Styles
    g_ui.importStyle('game_battlepass_otui.otui')
    
    -- OpCode Registration
    ProtocolGame.registerExtendedOpcode(BATTLEPASS_OPCODE, onExtendedOpcode)
    
    -- UI Setup
    battlePassWindow = g_ui.createWidget('BattlePassWindow', rootWidget)
    battlePassWindow:hide()
    
    -- Main Panel Integration
    battlePassButton = modules.game_mainpanel.addToggleButton('battlePassButton', tr('Battle Pass'), 
        '/modules/game_cyclopedia/images/boss/icon_star_gold.png', toggle)
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(BATTLEPASS_OPCODE)
    
    if battlePassWindow then
        battlePassWindow:destroy()
        battlePassWindow = nil
    end
    
    if battlePassButton then
        battlePassButton:destroy()
        battlePassButton = nil
    end
end

function toggle()
    if not g_game.isOnline() then return end
    
    if battlePassWindow:isVisible() then
        battlePassWindow:hide()
    else
        -- Request fresh data on Open
        g_game.getProtocolGame():sendExtendedOpcode(BATTLEPASS_OPCODE, json.encode({action = "open_request"}))
    end
end

function onExtendedOpcode(protocol, opcode, buffer)
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" then
        g_logger.error("BattlePass: Failed to decode JSON buffer")
        return 
    end

    if data.action == "open" or data.action == "update" then
        refresh(data)
        if not battlePassWindow:isVisible() then
            battlePassWindow:show()
            battlePassWindow:raise()
            battlePassWindow:focus()
        end
    end
end

-- Modular refresh function following Sorky's best practices
function refresh(data)
    -- 1. Metadata
    local season = data.season or 1
    local days = data.daysLeft or 0
    battlePassWindow:getChildById('seasonLabel'):setText(string.format("Season %d - %d days left", season, days))

    -- 2. Level Section
    battlePassWindow:recursiveGetChildById('levelNumber'):setText(data.level or 1)
    
    local xp = data.xp or 0
    local xpNext = data.xpNext or 1000
    local percent = math.min(100, math.floor((xp / math.max(xpNext, 1)) * 100))
    
    local xpBar = battlePassWindow:recursiveGetChildById('xpBar')
    xpBar:setMinimum(0)
    xpBar:setMaximum(100)
    xpBar:setValue(percent)
    battlePassWindow:recursiveGetChildById('xpLabel'):setText(string.format("%d / %d XP", xp, xpNext))

    -- 3. Missions List (Template-based)
    local missionList = battlePassWindow:recursiveGetChildById('missionList')
    missionList:destroyChildren() -- Memory safety: clear old widgets

    local receivedTasks = data.dailyTasks or {}
    for _, t in ipairs(receivedTasks) do
        -- Create widget from 'MissionTask' template defined in .otui
        local task = g_ui.createWidget('MissionTask', missionList)
        
        -- Bind data
        task:getChildById('label'):setText(t.label or "Task")
        task:getChildById('progressLabel'):setText(string.format("%d/%d", t.current or 0, t.target or 1))
        
        -- Visual Status
        if t.completed then
            task:getChildById('label'):setColor('#50e050')
        end
        
        local p = math.min(100, math.floor(((t.current or 0) / math.max(t.target or 1, 1)) * 100))
        local progressBar = task:getChildById('progressBar')
        progressBar:setMinimum(0)
        progressBar:setMaximum(100)
        progressBar:setValue(p)
    end
end
