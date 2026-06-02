-- Hunt Analyzer opcode 202: client sends action request_state/start/stop.
-- Server responds with state; kill pushes may include event='kill',
-- request_state may include expPerHourHistory with up to 60 graph samples.
local HUNT_ANALYZER_OPCODE = 202
local MIN_CONTENT_HEIGHT = 202
local CONTENT_HEIGHT = 326
local KILL_ROW_HEIGHT = 14
local GRAPH_CAPACITY = 60
local DEFAULT_COLOR = '#bbbbbb'
local WARNING_COLOR = '#e5c300'
local GOOD_COLOR = '#89F013'
local GRAPH_COLOR = '#89F013'
local START_BUTTON_COLOR = '#6fbf5f'
local STOP_BUTTON_COLOR = '#e84a4a'

local huntAnalyzerWindow
local huntAnalyzerButton
local lastState = {
    active = false,
    expGain = 0,
    expPerHour = 0,
    damage = 0,
    damagePerHour = 0,
    kills = {},
    expPerHourHistory = {}
}

local function formatNumber(value)
    value = math.floor(tonumber(value) or 0)
    local sign = ''
    if value < 0 then
        sign = '-'
        value = math.abs(value)
    end

    local text = tostring(value)
    while true do
        local formatted, count = text:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        text = formatted
        if count == 0 then
            break
        end
    end
    return sign .. text
end

local function formatShortNumber(value)
    value = math.floor(tonumber(value) or 0)
    local sign = ''
    if value < 0 then
        sign = '-'
        value = math.abs(value)
    end

    if value >= 1000000 then
        local rounded = math.floor(value / 100000 + 0.5) / 10
        if rounded == math.floor(rounded) then
            rounded = math.floor(rounded)
        end
        return sign .. rounded .. 'm'
    elseif value >= 1000 then
        return sign .. math.floor(value / 1000 + 0.5) .. 'k'
    end

    return sign .. value
end

local function getStatValueLabel(id)
    if not huntAnalyzerWindow then
        return nil
    end

    local row = huntAnalyzerWindow:recursiveGetChildById(id)
    if not row then
        return nil
    end

    return row:getChildById('value')
end

local function setStatValue(id, value, color)
    local label = getStatValueLabel(id)
    if label then
        label:setText(value)
        label:setColor(color or DEFAULT_COLOR)
    end
end

local function clearKillsList()
    if not huntAnalyzerWindow then
        return
    end

    local killsList = huntAnalyzerWindow:recursiveGetChildById('killsList')
    if killsList then
        killsList:destroyChildren()
    end
end

local function addEmptyKillRow()
    local killsList = huntAnalyzerWindow and huntAnalyzerWindow:recursiveGetChildById('killsList')
    if not killsList then
        return
    end

    local label = g_ui.createWidget('HuntAnalyzerKillLabel', killsList)
    label:setText(tr('No kills'))
end

local function addKillRow(name, count)
    local killsList = huntAnalyzerWindow and huntAnalyzerWindow:recursiveGetChildById('killsList')
    if not killsList then
        return
    end

    local row = g_ui.createWidget('HuntAnalyzerKillRow', killsList)
    local nameLabel = row:getChildById('name')
    local countLabel = row:getChildById('count')

    if nameLabel then
        nameLabel:setText(name)
    end

    if countLabel then
        countLabel:setText('x' .. count)
    end

    local rowHeight = KILL_ROW_HEIGHT
    if nameLabel then
        local textHeight = nameLabel:getTextSize().height
        if textHeight and textHeight > rowHeight then
            rowHeight = textHeight
        end
    end
    row:setHeight(rowHeight)
end

local function addKillSeparator()
    local killsList = huntAnalyzerWindow and huntAnalyzerWindow:recursiveGetChildById('killsList')
    if killsList then
        g_ui.createWidget('HuntAnalyzerKillSeparator', killsList)
    end
end

local function renderKills(kills)
    clearKillsList()

    if type(kills) ~= 'table' or #kills == 0 then
        addEmptyKillRow()
        return
    end

    local addedRows = 0
    for _, entry in ipairs(kills) do
        if type(entry) == 'table' and type(entry.name) == 'string' then
            local count = tonumber(entry.count) or 0
            if count > 0 then
                if addedRows > 0 then
                    addKillSeparator()
                end
                addKillRow(entry.name, count)
                addedRows = addedRows + 1
            end
        end
    end

    local killsList = huntAnalyzerWindow and huntAnalyzerWindow:recursiveGetChildById('killsList')
    if killsList then
        local children = killsList:getChildren()
        if #children == 0 then
            addEmptyKillRow()
        end
    end
end

local function getRateColor(value, warningThreshold, goodThreshold)
    value = tonumber(value) or 0
    if value > goodThreshold then
        return GOOD_COLOR
    elseif value > warningThreshold then
        return WARNING_COLOR
    end
    return DEFAULT_COLOR
end

local function getExpGraph()
    if not huntAnalyzerWindow then
        return nil
    end

    return huntAnalyzerWindow:recursiveGetChildById('expGraph')
end

local function setupExpGraph()
    local graph = getExpGraph()
    if not graph then
        return nil
    end

    graph:clear()
    graph:createGraph()
    graph:setCapacity(GRAPH_CAPACITY)
    graph:setLineWidth(1, 1)
    graph:setLineColor(1, GRAPH_COLOR)
    graph:setInfoText(1, tr('XP/h:'))
    graph:setShowLabels(false)
    graph:setShowInfo(false)
    return graph
end

local function setGraphAxisValue(id, value)
    if not huntAnalyzerWindow then
        return
    end

    local label = huntAnalyzerWindow:recursiveGetChildById(id)
    if label then
        label:setText(formatShortNumber(value))
    end
end

local function renderExpGraphAxis(history)
    local minValue = 0
    local maxValue = tonumber(lastState.expPerHour) or 0

    if type(history) == 'table' then
        for _, value in ipairs(history) do
            value = tonumber(value) or 0
            if value > maxValue then
                maxValue = value
            end
            if value < minValue then
                minValue = value
            end
        end
    end

    local midValue = math.floor((minValue + maxValue) / 2)
    setGraphAxisValue('expGraphAxisMax', maxValue)
    setGraphAxisValue('expGraphAxisMid', midValue)
    setGraphAxisValue('expGraphAxisMin', minValue)
end

local function renderExpGraphHistory(history)
    local graph = setupExpGraph()
    if not graph then
        return
    end

    if type(history) ~= 'table' then
        return
    end

    for _, value in ipairs(history) do
        graph:addValue(1, tonumber(value) or 0)
    end
    renderExpGraphAxis(history)
end

local function appendExpGraphValue(value)
    local graph = getExpGraph()
    if not graph then
        return
    end

    if graph:getGraphsCount() == 0 then
        setupExpGraph()
    end

    value = tonumber(value) or 0
    table.insert(lastState.expPerHourHistory, value)
    while #lastState.expPerHourHistory > GRAPH_CAPACITY do
        table.remove(lastState.expPerHourHistory, 1)
    end

    graph:addValue(1, value)
    renderExpGraphAxis(lastState.expPerHourHistory)
end

local function renderState()
    if not huntAnalyzerWindow then
        return
    end

    local button = huntAnalyzerWindow:recursiveGetChildById('startStopButton')
    if button then
        button:setText(lastState.active and tr('Stop') or tr('Start'))
        button:setImageColor(lastState.active and STOP_BUTTON_COLOR or START_BUTTON_COLOR)
        button:setColor('#ffffff')
        button:setEnabled(g_game.isOnline())
    end

    setStatValue('expGain', formatNumber(lastState.expGain))
    setStatValue('expGainHour', formatNumber(lastState.expPerHour), getRateColor(lastState.expPerHour, 50000, 100000))
    setStatValue('damage', formatNumber(lastState.damage))
    setStatValue('damageHour', formatNumber(lastState.damagePerHour), getRateColor(lastState.damagePerHour, 20000, 50000))
    renderExpGraphAxis(lastState.expPerHourHistory)
    renderKills(lastState.kills)
end

local function normalizeState(data)
    lastState = {
        active = data.active == true,
        expGain = tonumber(data.expGain) or 0,
        expPerHour = tonumber(data.expPerHour) or 0,
        damage = tonumber(data.damage) or 0,
        damagePerHour = tonumber(data.damagePerHour) or 0,
        kills = type(data.kills) == 'table' and data.kills or {},
        expPerHourHistory = type(data.expPerHourHistory) == 'table' and data.expPerHourHistory or lastState.expPerHourHistory
    }
end

local function updateExpGraph(data)
    if type(data.expPerHourHistory) == 'table' then
        renderExpGraphHistory(data.expPerHourHistory)
    elseif data.event == 'kill' or data.addGraphPoint == true then
        appendExpGraphValue(data.expPerHour)
    elseif data.resetGraph == true then
        renderExpGraphHistory({})
    end
end

local function sendAction(action)
    if not g_game.isOnline() then
        return
    end

    local protocol = g_game.getProtocolGame()
    if not protocol then
        return
    end

    protocol:sendExtendedJSONOpcode(HUNT_ANALYZER_OPCODE, {
        action = action
    })
end

local function requestState()
    sendAction('request_state')
end

local function onExtendedOpcode(protocol, opcode, data)
    if opcode ~= HUNT_ANALYZER_OPCODE or type(data) ~= 'table' then
        return
    end

    if data.type == 'state' then
        normalizeState(data)
        updateExpGraph(data)
        renderState()
    elseif data.type == 'error' and data.message then
        print('[Hunt Analyzer] ' .. data.message)
    end
end

function init()
    huntAnalyzerWindow = g_ui.loadUI('huntanalyzer')
    huntAnalyzerWindow:setup()
    huntAnalyzerWindow:setContentMinimumHeight(MIN_CONTENT_HEIGHT)
    huntAnalyzerWindow:setContentMaximumHeight(CONTENT_HEIGHT)
    huntAnalyzerWindow:setHeight(huntAnalyzerWindow:getMaximumHeight())
    huntAnalyzerWindow:close()
    setupExpGraph()

    huntAnalyzerButton = modules.game_mainpanel.addToggleButton('huntAnalyzerButton', tr('Hunt Analyzer'),
        '/images/options/button_huntanalyzer_', toggle, false, 6)
    huntAnalyzerButton:setOn(false)

    ProtocolGame.registerExtendedJSONOpcode(HUNT_ANALYZER_OPCODE, onExtendedOpcode)
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    renderState()
    if g_game.isOnline() then
        requestState()
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
    pcall(ProtocolGame.unregisterExtendedJSONOpcode, HUNT_ANALYZER_OPCODE)

    if huntAnalyzerButton then
        huntAnalyzerButton:destroy()
        huntAnalyzerButton = nil
    end

    if huntAnalyzerWindow then
        huntAnalyzerWindow:destroy()
        huntAnalyzerWindow = nil
    end
end

function toggle()
    if not huntAnalyzerWindow then
        return
    end

    if huntAnalyzerButton and huntAnalyzerButton:isOn() then
        huntAnalyzerWindow:close()
        huntAnalyzerButton:setOn(false)
    else
        if not huntAnalyzerWindow:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(huntAnalyzerWindow, huntAnalyzerWindow:getMinimumHeight())
            if not panel then
                return
            end

            panel:addChild(huntAnalyzerWindow)
        end
        huntAnalyzerWindow:open()
        if huntAnalyzerButton then
            huntAnalyzerButton:setOn(true)
        end
        requestState()
    end
end

function onMiniWindowOpen()
    if huntAnalyzerButton then
        huntAnalyzerButton:setOn(true)
    end
    requestState()
end

function onMiniWindowClose()
    if huntAnalyzerButton then
        huntAnalyzerButton:setOn(false)
    end
end

function onStartStopClick()
    if lastState.active then
        sendAction('stop')
    else
        lastState.expPerHourHistory = {}
        renderExpGraphHistory(lastState.expPerHourHistory)
        sendAction('start')
    end
end

function onGameStart()
    renderState()
    requestState()
end

function onGameEnd()
    lastState.active = false
    renderState()
end
