ColonyMap = { DOMAIN = 'territories' }

local colors = { oldCamp = '#e05252', newCamp = '#528fe0', swampCamp = '#54be69', neutral = '#dddddd' }
local campNames = { oldCamp = 'Stary Obóz', newCamp = 'Nowy Obóz', swampCamp = 'Obóz na Bagnie', neutral = 'Brak obozu' }
local sectorNames = {
    exchange_square = 'Plac Wymian', swamp = 'Bagna', east_forest = 'Las na wschodzie',
    free_mine = 'Wolna kopalnia', orc_lands = 'Ziemie orków', old_fortress = 'Stara forteca'
}
local ui, sendRequest, forgetRequest
local requestId, timeoutEvent, owner, hoveredSector
local zoom, centerX, centerY = 1, 0.5, 0.5
local dragging = false

local function text(value) return utf8ToCp1250(value) end

function ColonyMap.containsPoint(polygon, x, y)
    local inside = false
    local previous = polygon[#polygon]
    for _, point in ipairs(polygon) do
        if (point[2] > y) ~= (previous[2] > y) and
            x < (previous[1] - point[1]) * (y - point[2]) / (previous[2] - point[2]) + point[1] then
            inside = not inside
        end
        previous = point
    end
    return inside
end

function ColonyMap.getOwner() return owner end

local function tooltip(sector)
    if sectorNames[sector] then
        return text(sectorNames[sector] .. '\nTerytorium niedostępne do przejęcia')
    end
    return text('Stara Kopalnia\n' .. (campNames[owner] or 'Brak danych o kontroli') ..
        '\nBonus dla członków obozu kontrolującego:\n+5% szansy na trafienie krytyczne')
end

function ColonyMap.clearHover()
    if hoveredSector then g_tooltip.hide() end
    hoveredSector = nil
end

local function stopDragging()
    if dragging and ui then ui.canvas:ungrabMouse() end
    dragging = false
    ColonyMap.clearHover()
end

local function render()
    if not ui then return end
    ui.mine:setImageColor(colors[owner] or colors.neutral)
    if hoveredSector then g_tooltip.display(tooltip(hoveredSector)) end
end

local function cancelRequest()
    if timeoutEvent then removeEvent(timeoutEvent) end
    timeoutEvent = nil
    if requestId and forgetRequest then forgetRequest(requestId) end
    requestId = nil
end

function ColonyMap.deactivate()
    cancelRequest()
    stopDragging()
end

function ColonyMap.reset()
    ColonyMap.deactivate()
    owner = nil
    ColonyMap.resetView()
    ColonyMap.clearHover()
    render()
end

function ColonyMap.resize()
    if not ui then return end
    local viewportWidth, viewportHeight = ui.viewport:getWidth(), ui.viewport:getHeight()
    local width = math.max(1, math.floor(math.min(viewportWidth, viewportHeight * 1013 / 701) * zoom))
    local height = math.max(1, math.floor(width * 701 / 1013))
    local function offset(size, viewportSize, center)
        if size <= viewportSize then return math.floor((viewportSize - size) / 2) end
        return math.floor(math.max(viewportSize - size, math.min(0, viewportSize / 2 - center * size)))
    end
    local x, y = offset(width, viewportWidth, centerX), offset(height, viewportHeight, centerY)
    ui.canvas:resize(width, height)
    ui.canvas:setPosition({ x = ui.viewport:getX() + x, y = ui.viewport:getY() + y })
    centerX, centerY = (viewportWidth / 2 - x) / width, (viewportHeight / 2 - y) / height
    for _, image in ipairs(ui.images or { ui.canvas, ui.mine, ui.exchange, ui.outline }) do
        image:setImageWidth(width)
        image:setImageHeight(height)
    end
end

function ColonyMap.setZoom(value, position)
    if not ui then return end
    local x, y
    if position then
        x = (position.x - ui.canvas:getX()) / ui.canvas:getWidth()
        y = (position.y - ui.canvas:getY()) / ui.canvas:getHeight()
    end
    zoom = math.max(1, math.min(6, value))
    ColonyMap.clearHover()
    ColonyMap.resize()
    if position then
        centerX = x + (ui.viewport:getWidth() / 2 - (position.x - ui.viewport:getX())) / ui.canvas:getWidth()
        centerY = y + (ui.viewport:getHeight() / 2 - (position.y - ui.viewport:getY())) / ui.canvas:getHeight()
        ColonyMap.resize()
    end
end

function ColonyMap.resetView()
    stopDragging()
    zoom, centerX, centerY = 1, 0.5, 0.5
    ColonyMap.resize()
end

function ColonyMap.selectSector(id)
    local polygon = ColonyMapGeometry[id]
    if not polygon then return end
    local minX, minY, maxX, maxY = 1013, 701, 0, 0
    for _, point in ipairs(polygon) do
        minX, minY = math.min(minX, point[1]), math.min(minY, point[2])
        maxX, maxY = math.max(maxX, point[1]), math.max(maxY, point[2])
    end
    zoom, centerX, centerY = 3, (minX + maxX) / 2026, (minY + maxY) / 1402
    ColonyMap.clearHover()
    ColonyMap.resize()
end

function ColonyMap.bind(widgets, request, forget)
    ui, sendRequest, forgetRequest = widgets, request, forget
    if not ui then return end
    ui.viewport.onGeometryChange = ColonyMap.resize
    local function wheel(_, position, direction)
        if direction ~= MouseWheelUp and direction ~= MouseWheelDown then return false end
        ColonyMap.setZoom(zoom * (direction == MouseWheelUp and 1.25 or 0.8), position)
        return true
    end
    ui.viewport.onMouseWheel = wheel
    ui.canvas.onMouseWheel = wheel
    ui.canvas.onMousePress = function(widget, _, button)
        if button ~= MouseLeftButton then return false end
        ColonyMap.clearHover()
        dragging = true
        widget:grabMouse()
        return true
    end
    ui.canvas.onMouseRelease = function(widget, _, button)
        if button ~= MouseLeftButton or not dragging then return false end
        dragging = false
        widget:ungrabMouse()
        return true
    end
    ui.canvas.onMouseMove = function(widget, position, moved)
        if dragging then
            centerX = centerX - moved.x / widget:getWidth()
            centerY = centerY - moved.y / widget:getHeight()
            ColonyMap.resize()
            return true
        end
        local x = (position.x - widget:getX()) * 1013 / widget:getWidth()
        local y = (position.y - widget:getY()) * 701 / widget:getHeight()
        local sector
        for id, polygon in pairs(ColonyMapGeometry) do
            if ColonyMap.containsPoint(polygon, x, y) then sector = id break end
        end
        if sector ~= hoveredSector then
            ColonyMap.clearHover()
            hoveredSector = sector
            if sector then g_tooltip.display(tooltip(sector)) end
        end
        return false
    end
    ui.canvas.onHoverChange = function(_, hovered)
        if not hovered then ColonyMap.clearHover() end
    end
    if ui.zoomIn then ui.zoomIn.onClick = function() ColonyMap.setZoom(zoom * 1.25) end end
    if ui.zoomOut then ui.zoomOut.onClick = function() ColonyMap.setZoom(zoom * 0.8) end end
    if ui.resetView then ui.resetView.onClick = ColonyMap.resetView end
    if ui.mineButton then ui.mineButton.onClick = function() ColonyMap.selectSector('old_mine_arena') end end
    if ui.exchangeButton then ui.exchangeButton.onClick = function() ColonyMap.selectSector('exchange_square') end end
    for id, button in pairs(ui.sectorButtons or {}) do
        local sectorId = id
        button.onClick = function() ColonyMap.selectSector(sectorId) end
    end
    ColonyMap.resize()
    render()
end

function ColonyMap.activate()
    ColonyMap.reset()
    if not g_game.isOnline() or not sendRequest then return end
    requestId = sendRequest(ColonyMap.DOMAIN, 'status', {})
    if requestId then
        timeoutEvent = scheduleEvent(function()
            timeoutEvent = nil
            cancelRequest()
            owner = nil
            render()
        end, 5000)
    end
end

function ColonyMap.handleResponse(payload)
    if payload.domain ~= ColonyMap.DOMAIN then return false end
    if not requestId or payload.requestId ~= requestId then return true end
    cancelRequest()
    owner = nil
    if payload.version == 1 and payload.action == 'status' and payload.ok == true and
        type(payload.data) == 'table' and type(payload.data.territories) == 'table' then
        for _, territory in pairs(payload.data.territories) do
            if type(territory) == 'table' and territory.arenaId == 'old_mine_arena' then
                local seconds = territory.remainingSeconds
                if colors[territory.owner] and type(seconds) == 'number' and seconds >= 0 and
                    seconds < math.huge and seconds == math.floor(seconds) and
                    ((territory.owner == 'neutral' and seconds == 0) or (territory.owner ~= 'neutral' and seconds > 0)) then
                    owner = territory.owner
                end
                break
            end
        end
    end
    render()
    return true
end

function ColonyMap.terminate()
    ColonyMap.reset()
    if ui then
        ui.viewport.onGeometryChange = nil
        ui.viewport.onMouseWheel = nil
        ui.canvas.onMouseMove = nil
        ui.canvas.onHoverChange = nil
        ui.canvas.onMouseWheel = nil
        ui.canvas.onMousePress = nil
        ui.canvas.onMouseRelease = nil
    end
    ui, sendRequest, forgetRequest = nil, nil, nil
end
