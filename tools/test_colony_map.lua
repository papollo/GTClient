-- Run from GTClient: lua tools/test_colony_map.lua
local events = {}
MouseWheelUp, MouseWheelDown, MouseLeftButton = 1, 2, 1
function scheduleEvent(callback, delay)
    local event = { callback = callback, delay = delay }
    events[#events + 1] = event
    return event
end
function removeEvent(event) event.cancelled = true end
local function latestEvent(delay)
    for index = #events, 1, -1 do
        if events[index].delay == delay and not events[index].cancelled then return events[index] end
    end
    error('Missing event: ' .. delay)
end
function utf8ToCp1250(text) return text end
g_game = { isOnline = function() return true end }
g_tooltip = { hide = function() end, display = function() end }
dofile('modules/game_library/colony_map_geometry.lua')
dofile('modules/game_library/colony_map.lua')

local map = ColonyMap
assert(map.containsPoint(ColonyMapGeometry.old_mine_arena, 320, 150))
assert(not map.containsPoint(ColonyMapGeometry.old_mine_arena, 380, 95))
assert(map.containsPoint(ColonyMapGeometry.exchange_square, 550, 110))
assert(not map.containsPoint(ColonyMapGeometry.exchange_square, 480, 90))
for id, point in pairs({ swamp = { 825, 445 }, east_forest = { 680, 250 },
    free_mine = { 160, 295 }, orc_lands = { 350, 490 }, old_fortress = { 550, 550 } }) do
    assert(map.containsPoint(ColonyMapGeometry[id], point[1], point[2]), id)
    assert(not map.containsPoint(ColonyMapGeometry[id], 20, 20), id)
end
assert(not map.containsPoint(ColonyMapGeometry.swamp, 820, 400), 'trimmed swamp north must be outside')
assert(not map.containsPoint(ColonyMapGeometry.swamp, 900, 410), 'trimmed swamp northeast must be outside')
assert(map.containsPoint(ColonyMapGeometry.swamp, 760, 420), 'remaining swamp northwest must be inside')

local serial = 0
local forgotten = {}
map.bind(nil, function(domain, action)
    assert(domain == 'territories' and action == 'status')
    serial = serial + 1
    return tostring(serial)
end, function(id) forgotten[id] = true end)

local function response(id, owner, seconds)
    return { version = 1, domain = 'territories', action = 'status',
        requestId = id, ok = true, data = { territories = {
            { arenaId = 'exchange_square', owner = 'oldCamp', remainingSeconds = 99 },
            { arenaId = 'old_mine_arena', owner = owner, remainingSeconds = seconds }
        } } }
end

for _, owner in ipairs({ 'oldCamp', 'newCamp', 'swampCamp', 'neutral' }) do
    map.activate()
    local id = tostring(serial)
    local seconds = owner == 'neutral' and 0 or 60
    assert(map.handleResponse(response(id, owner, seconds)))
    assert(map.getOwner() == owner)
    assert(forgotten[id])
    assert(events[#events].cancelled, 'snapshot must not schedule background timers')
end
map.activate()
local stale = tostring(serial)
map.reset()
map.activate()
map.handleResponse(response(stale, 'oldCamp', 60))
assert(map.getOwner() == nil, 'old session response must be ignored')
map.handleResponse(response(tostring(serial), 'invalid', 60))
assert(map.getOwner() == nil)
map.activate()
map.handleResponse(response(tostring(serial), 'oldCamp', -1))
assert(map.getOwner() == nil)
map.activate()
events[#events].callback()
map.handleResponse(response(tostring(serial), 'oldCamp', 60))
assert(map.getOwner() == nil, 'late response must be ignored')
map.activate()
map.handleResponse({ domain = 'territories', requestId = tostring(serial), ok = false })
assert(map.getOwner() == nil)
assert(not map.handleResponse({ domain = 'items' }))

map.activate()
map.handleResponse(response(tostring(serial), 'oldCamp', 60))
local snapshotEventCount = #events
assert(events[#events].cancelled, 'received snapshot must have no active timers')
map.handleResponse(response(tostring(serial), 'newCamp', 60))
assert(map.getOwner() == 'oldCamp', 'unsolicited changes must not replace snapshot')
map.resetView()
assert(#events == snapshotEventCount, 'centering must not request or schedule refresh')
map.deactivate()
local previousSerial = serial
map.activate()
assert(serial == previousSerial + 1, 'returning to tab must fetch once')
map.handleResponse(response(tostring(serial), 'newCamp', 60))
assert(map.getOwner() == 'newCamp', 'returning to tab must receive current owner')
map.activate()
local pendingId = tostring(serial)
local pendingTimeout = latestEvent(5000)
map.deactivate()
assert(pendingTimeout.cancelled and forgotten[pendingId])
map.handleResponse(response(pendingId, 'oldCamp', 60))
assert(map.getOwner() == nil, 'response after closing must be ignored')
map.activate()
local beforeTimeout = serial
local timeout = latestEvent(5000)
timeout.cancelled = true
local beforeTimeoutEvents = #events
timeout.callback()
assert(serial == beforeTimeout and #events == beforeTimeoutEvents, 'timeout must not retry')
assert(map.getOwner() == nil)
map.reset()

-- Exercise the real widget callbacks without starting a server or client.
local function image()
    return { setImageWidth = function(self, width) self.imageWidth = width end,
        setImageHeight = function(self, height) self.imageHeight = height end,
        setImageColor = function(self, color) self.color = color end }
end
local canvas, mine, exchange, outline = image(), image(), image(), image()
canvas.resize = function(self, width, height) self.width, self.height = width, height end
canvas.getWidth = function(self) return self.width end
canvas.getHeight = function(self) return self.height end
canvas.setPosition = function(self, position) self.x, self.y = position.x, position.y end
canvas.getX = function(self) return self.x end
canvas.getY = function(self) return self.y end
canvas.grabMouse = function(self) self.grabbed = true end
canvas.ungrabMouse = function(self) self.grabbed = false end
local viewport = { getWidth = function() return 500 end, getHeight = function() return 300 end,
    getX = function() return 100 end, getY = function() return 50 end }
local displayed
g_tooltip.display = function(value) displayed = value end
g_tooltip.hide = function() displayed = nil end
local newImages, newButtons = {}, {}
local images = { canvas, mine, exchange, outline }
for _, id in ipairs({ 'swamp', 'east_forest', 'free_mine', 'orc_lands', 'old_fortress' }) do
    newImages[id] = image()
    newButtons[id] = {}
    images[#images + 1] = newImages[id]
end
map.bind({ viewport = viewport, canvas = canvas, mine = mine, exchange = exchange,
    outline = outline, images = images, sectorButtons = newButtons }, function()
    serial = serial + 1
    return tostring(serial)
end, function(id) forgotten[id] = true end)
assert(canvas.width <= 500 and canvas.height <= 300)
assert(mine.imageWidth == canvas.width and outline.imageHeight == canvas.height)
for _, overlay in pairs(newImages) do
    assert(overlay.imageWidth == canvas.width and overlay.imageHeight == canvas.height)
end
local function move(x, y)
    canvas.onMouseMove(canvas, { x = canvas.x + x * canvas.width / 1013,
        y = canvas.y + y * canvas.height / 701 })
end
move(320, 150)
assert(displayed and displayed:find('Stara Kopalnia', 1, true))
move(380, 95)
assert(displayed == nil, 'outside polygon, inside bounding box')
move(550, 110)
assert(displayed and displayed:find('Plac Wymian', 1, true))
for id, entry in pairs({ swamp = { 825, 445, 'Bagna' },
    east_forest = { 680, 250, 'Las na wschodzie' }, free_mine = { 160, 295, 'Wolna kopalnia' },
    orc_lands = { 350, 490, 'Ziemie orków' }, old_fortress = { 550, 550, 'Stara forteca' } }) do
    move(entry[1], entry[2])
    assert(displayed and displayed:find(entry[3], 1, true), id .. ' tooltip')
    assert(not displayed:find('+5%', 1, true), 'inactive sectors have no mine bonus')
    newButtons[id].onClick()
    local minX, minY, maxX, maxY = 1013, 701, 0, 0
    for _, point in ipairs(ColonyMapGeometry[id]) do
        minX, minY = math.min(minX, point[1]), math.min(minY, point[2])
        maxX, maxY = math.max(maxX, point[1]), math.max(maxY, point[2])
    end
    local x = canvas.x + (minX + maxX) / 2 * canvas.width / 1013
    local y = canvas.y + (minY + maxY) / 2 * canvas.height / 701
    -- Edge sectors stop at the map boundary rather than exposing empty space.
    assert(math.abs(x - 350) < 125 and math.abs(y - 200) < 75, id .. ' centering')
    map.resetView()
end
canvas.onHoverChange(canvas, false)
assert(displayed == nil)
local fitWidth = canvas.width
map.setZoom(2)
assert(canvas.width > fitWidth * 1.9)
move(320, 150)
assert(displayed and displayed:find('Stara Kopalnia', 1, true))
map.setZoom(100)
assert(canvas.width <= fitWidth * 6 + 6, 'zoom must be bounded')
map.selectSector('old_mine_arena')
local mineCenter = canvas.x + 320 * canvas.width / 1013
assert(math.abs(mineCenter - 350) < 35, 'selection must center the sector')
map.resetView()
assert(canvas.width == fitWidth)
assert(canvas.x >= viewport.getX())
local mouse = { x = 350, y = 200 }
assert(canvas.onMouseWheel(canvas, mouse, MouseWheelUp))
assert(canvas.width > fitWidth)
map.setZoom(3)
local beforeDrag = canvas.x
assert(canvas.onMousePress(canvas, mouse, MouseLeftButton))
assert(canvas.grabbed)
canvas.onMouseMove(canvas, mouse, { x = 20, y = 10 })
assert(canvas.x > beforeDrag, 'drag must move map with cursor')
assert(canvas.onMouseRelease(canvas, mouse, MouseLeftButton))
assert(not canvas.grabbed)
canvas.onMousePress(canvas, mouse, MouseLeftButton)
map.deactivate()
assert(not canvas.grabbed, 'closing tab must release mouse')
map.resetView()
for owner, color in pairs({ oldCamp = '#e05252', newCamp = '#528fe0',
    swampCamp = '#54be69', neutral = '#dddddd' }) do
    map.activate()
    map.handleResponse(response(tostring(serial), owner, owner == 'neutral' and 0 or 60))
    assert(mine.color == color)
    assert(exchange.color == nil, 'response must not recolor exchange square')
    for _, overlay in pairs(newImages) do
        assert(overlay.color == nil, 'response must not recolor inactive sectors')
        assert(overlay.imageWidth == canvas.width)
    end
end
map.activate()
map.handleResponse(response(tostring(serial), 'oldCamp', 60))
map.setZoom(2)
assert(events[#events].cancelled, 'zoom must not schedule background updates')
map.terminate()
assert(canvas.onMouseMove == nil and viewport.onGeometryChange == nil)
print('Colony map: seven sectors, zoom, owners, snapshots on opening, closing and errors OK')
