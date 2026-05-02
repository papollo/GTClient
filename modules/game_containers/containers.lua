local CONTAINER_META_OPCODE = 218
local OPEN_CONTAINERS_SETTINGS_NODE = 'OpenContainersV2'
local RESTORE_DELAY_MS = 10
local RESTORE_RETRY_DELAY_MS = 100

local pendingContainerMeta = {}
local uidByContainerId = {}
local containerByUid = {}
local restoreEvent = nil
local restoreRetryEvent = nil
local endingGame = false

local function normalizeUid(uid)
    if uid == nil then
        return nil
    end

    uid = tostring(uid)
    if uid:len() == 0 then
        return nil
    end

    return uid
end

local function getContainerSettingsKey()
    local characterName = g_game.getCharacterName()
    if not characterName or characterName:len() == 0 then
        return nil
    end

    local worldName = g_game.getWorldName()
    if not worldName or worldName:len() == 0 then
        worldName = 'unknown'
    end

    return characterName .. '@' .. worldName
end

local function getSavedOpenContainerUids()
    local key = getContainerSettingsKey()
    if not key then
        return {}
    end

    local settings = g_settings.getNode(OPEN_CONTAINERS_SETTINGS_NODE)
    if not settings or not settings[key] then
        return {}
    end

    local uids = {}
    local savedValue = settings[key]
    if type(savedValue) == 'table' and savedValue.uids then
        savedValue = savedValue.uids
    end

    if type(savedValue) == 'string' then
        for uid in savedValue:gmatch('[^,]+') do
            uid = normalizeUid(uid)
            if uid then
                table.insert(uids, uid)
            end
        end
        return uids
    end

    if type(savedValue) ~= 'table' then
        return {}
    end

    for _, uid in ipairs(savedValue) do
        uid = normalizeUid(uid)
        if uid then
            table.insert(uids, uid)
        end
    end

    return uids
end

local function setSavedOpenContainerUids(uids)
    local key = getContainerSettingsKey()
    if not key then
        return
    end

    local settings = g_settings.getNode(OPEN_CONTAINERS_SETTINGS_NODE)
    if not settings then
        settings = {}
    end

    local normalizedUids = {}
    local seenUids = {}
    for _, uid in ipairs(uids) do
        uid = normalizeUid(uid)
        if uid and not seenUids[uid] then
            table.insert(normalizedUids, uid)
            seenUids[uid] = true
        end
    end

    settings[key] = table.concat(normalizedUids, ',')
    g_settings.setNode(OPEN_CONTAINERS_SETTINGS_NODE, settings)
    g_settings.save()
end

local function getContainerWindowId(uid, fallbackId)
    uid = normalizeUid(uid)
    if uid then
        return 'container_uid_' .. uid:gsub('[^%w_%-]', '_')
    end

    return 'container' .. fallbackId
end

local function collectOpenContainerUids()
    local uids = {}
    local seenUids = {}

    local function appendUid(uid)
        uid = normalizeUid(uid)
        if uid and not seenUids[uid] then
            table.insert(uids, uid)
            seenUids[uid] = true
        end
    end

    local panelIds = {
        'gameLeftPanel',
        'gameLeftExtraPanel',
        'gameRightPanel',
        'gameRightExtraPanel'
    }

    for _, panelId in ipairs(panelIds) do
        local panel = rootWidget:recursiveGetChildById(panelId)
        if panel then
            for _, child in ipairs(panel:getChildren()) do
                appendUid(child.containerUid)
            end
        end
    end

    for containerId, uid in pairs(uidByContainerId) do
        local container = g_game.getContainer(containerId)
        if container and container.window then
            appendUid(uid)
        end
    end

    return uids
end

local function saveOpenContainerSnapshot()
    if endingGame then
        return
    end

    setSavedOpenContainerUids(collectOpenContainerUids())
end

local function removeSavedOpenContainerUid(uid)
    uid = normalizeUid(uid)
    if not uid then
        return
    end

    local remainingUids = {}
    for _, savedUid in ipairs(getSavedOpenContainerUids()) do
        if savedUid ~= uid then
            table.insert(remainingUids, savedUid)
        end
    end

    setSavedOpenContainerUids(remainingUids)
end

local function clearRuntimeContainerState()
    pendingContainerMeta = {}
    uidByContainerId = {}
    containerByUid = {}
end

local function stopRestore()
    if restoreEvent then
        removeEvent(restoreEvent)
        restoreEvent = nil
    end

    if restoreRetryEvent then
        removeEvent(restoreRetryEvent)
        restoreRetryEvent = nil
    end
end

local function requestRestore(isRetry)
    if isRetry then
        restoreRetryEvent = nil
    else
        restoreEvent = nil
    end

    if not g_game.isOnline() then
        return
    end

    local uids = getSavedOpenContainerUids()
    if #uids == 0 then
        return
    end

    local protocol = g_game.getProtocolGame()
    if not protocol then
        return
    end

    protocol:sendExtendedJSONOpcode(CONTAINER_META_OPCODE, {
        action = 'restore',
        uids = uids
    })
end

local function startRestore()
    endingGame = false
    clearRuntimeContainerState()
    stopRestore()
    restoreEvent = scheduleEvent(requestRestore, RESTORE_DELAY_MS)
    restoreRetryEvent = scheduleEvent(function()
        requestRestore(true)
    end, RESTORE_RETRY_DELAY_MS)
end

local function onGameEnd()
    endingGame = true
    stopRestore()
    clean()
    clearRuntimeContainerState()
end

local function onContainerMeta(protocol, opcode, data)
    if type(data) ~= 'table' or data.action ~= 'containerMeta' then
        return
    end

    local containerId = tonumber(data.containerId)
    local uid = normalizeUid(data.uid)
    if not containerId or not uid then
        return
    end

    pendingContainerMeta[containerId] = {
        uid = uid,
        parentUid = normalizeUid(data.parentUid)
    }
end

function init()
    g_ui.importStyle('container')

    connect(Container, {
        onOpen = onContainerOpen,
        onClose = onContainerClose,
        onSizeChange = onContainerChangeSize,
        onUpdateItem = onContainerUpdateItem
    })
    connect(g_game, {
        onGameStart = startRestore,
        onGameEnd = onGameEnd
    })

    ProtocolGame.registerExtendedJSONOpcode(CONTAINER_META_OPCODE, onContainerMeta)

    reloadContainers()
end

function terminate()
    disconnect(Container, {
        onOpen = onContainerOpen,
        onClose = onContainerClose,
        onSizeChange = onContainerChangeSize,
        onUpdateItem = onContainerUpdateItem
    })
    disconnect(g_game, {
        onGameStart = startRestore,
        onGameEnd = onGameEnd
    })
    ProtocolGame.unregisterExtendedJSONOpcode(CONTAINER_META_OPCODE)

    stopRestore()
    clean()
    clearRuntimeContainerState()
end

function reloadContainers()
    clean()
    for _, container in pairs(g_game.getContainers()) do
        onContainerOpen(container)
    end
end

function clean()
    for containerid, container in pairs(g_game.getContainers()) do
        destroy(container)
    end
end

function destroy(container)
    if container.window then
        container.window:destroy()
        container.window = nil
        container.itemsPanel = nil
    end
end

function refreshContainerItems(container)
    for slot = 0, container:getCapacity() - 1 do
        local slotWidget = container.itemsPanel:getChildById('item' .. slot)
        local itemWidget = slotWidget:getChildById('item')
        local item = container:getItem(slot)
        itemWidget:setItem(item)
        itemWidget.position = container:getSlotPosition(slot)
        ItemsDatabase.setRarityItem(slotWidget, item)
        ItemsDatabase.setTier(itemWidget, item)
        ItemsDatabase.setTierFrame(slotWidget, item)
        if modules.client_options.getOption('showExpiryInContainers') then
            ItemsDatabase.setCharges(itemWidget, item)
            ItemsDatabase.setDuration(itemWidget, item)
        end
    end

    if container:hasPages() then
        refreshContainerPages(container)
    end
end

function toggleContainerPages(containerWindow, pages)
    containerWindow:getChildById('miniwindowScrollBar'):setMarginTop(pages and 42 or 22)
    containerWindow:getChildById('contentsPanel'):setMarginTop(pages and 42 or 22)
    containerWindow:getChildById('pagePanel'):setVisible(pages)
end

function refreshContainerPages(container)
    local currentPage = 1 + math.floor(container:getFirstIndex() / container:getCapacity())
    local pages = 1 + math.floor(math.max(0, (container:getSize() - 1)) / container:getCapacity())
    container.window:recursiveGetChildById('pageLabel'):setText(string.format('Page %i of %i', currentPage, pages))

    local prevPageButton = container.window:recursiveGetChildById('prevPageButton')
    if currentPage == 1 then
        prevPageButton:setEnabled(false)
    else
        prevPageButton:setEnabled(true)
        prevPageButton.onClick = function()
            g_game.seekInContainer(container:getId(), container:getFirstIndex() - container:getCapacity())
        end
    end

    local nextPageButton = container.window:recursiveGetChildById('nextPageButton')
    if currentPage >= pages then
        nextPageButton:setEnabled(false)
    else
        nextPageButton:setEnabled(true)
        nextPageButton.onClick = function()
            g_game.seekInContainer(container:getId(), container:getFirstIndex() + container:getCapacity())
        end
    end
end

local function isLockerContainer(container)
    local name = container:getName()
    if not name or name:len() == 0 then
        return false
    end

    return name:lower():find('locker', 1, true) ~= nil
end

local function setupLockerBankSlot(containerPanel)
    if containerPanel:getChildById('bankItem') then
        return containerPanel:getChildById('bankItem')
    end

    local bankItem = g_ui.createWidget('ContainerItemSlot')
    bankItem:setId('bankItem')
    bankItem:setTooltip(tr('Bank'))

    local itemWidget = bankItem:getChildById('item')
    if itemWidget then
        itemWidget:setItemId(23721)
        itemWidget:setItemCount(1)
    end

    g_mouse.bindPress(bankItem, function()
        local protocol = g_game.getProtocolGame()
        if protocol then
            protocol:sendExtendedJSONOpcode(215, { action = 'open' })
        else
            g_logger.warning('Cannot open bank modal: no protocol game available.')
        end
    end, MouseLeftButton)

    return bankItem
end

function onContainerOpen(container, previousContainer)
    local containerWindow
    if previousContainer then
        containerWindow = previousContainer.window
        previousContainer.window = nil
        previousContainer.itemsPanel = nil
    else
        containerWindow = g_ui.createWidget('ContainerWindow')
    end

    local containerId = container:getId()
    local meta = pendingContainerMeta[containerId]
    pendingContainerMeta[containerId] = nil

    local previousUid = uidByContainerId[containerId]
    if previousUid then
        containerByUid[previousUid] = nil
        uidByContainerId[containerId] = nil
    end

    local containerUid = meta and meta.uid or nil
    if containerUid then
        uidByContainerId[containerId] = containerUid
        containerByUid[containerUid] = container
    end

    containerWindow.containerUid = containerUid
    containerWindow:setId(getContainerWindowId(containerUid, containerId))
    containerWindow.save = containerUid ~= nil
    if containerWindow.save then
        containerWindow:setSettings({ closed = false })
    end

    local containerPanel = containerWindow:getChildById('contentsPanel')
    local containerItemWidget = containerWindow:getChildById('containerItemWidget')
    containerWindow.onClose = function()
        removeSavedOpenContainerUid(containerUid)
        g_game.close(container)
        containerWindow:hide()
    end

    -- this disables scrollbar auto hiding
    local scrollbar = containerWindow:getChildById('miniwindowScrollBar')
    scrollbar:mergeStyle({
        ['$!on'] = {}
    })

    local upButton = containerWindow:getChildById('upButton')
    upButton.onClick = function()
        g_game.openParent(container)
    end
    upButton:setVisible(container:hasParent())

    local name = container:getName()
    name = name:sub(1, 1):upper() .. name:sub(2)

    if name:len() > 14 then
        name = name:sub(1, 14) .. "..."
    end

    containerWindow:setText(name)

    containerItemWidget:setItem(container:getContainerItem())
    containerItemWidget:setPhantom(true)

    containerPanel:destroyChildren()
    for slot = 0, container:getCapacity() - 1 do
        local slotWidget = g_ui.createWidget('ContainerItemSlot', containerPanel)
        slotWidget:setId('item' .. slot)
        local itemWidget = slotWidget:getChildById('item')
        local item = container:getItem(slot)
        itemWidget:setItem(item)
        ItemsDatabase.setRarityItem(slotWidget, item)
        ItemsDatabase.setTier(itemWidget, item)
        ItemsDatabase.setTierFrame(slotWidget, item)
        if modules.client_options.getOption('showExpiryInContainers') then
            ItemsDatabase.setCharges(itemWidget, item)
            ItemsDatabase.setDuration(itemWidget, item)
        end
        slotWidget:setMargin(0)
        itemWidget.position = container:getSlotPosition(slot)

        if not container:isUnlocked() then
            itemWidget:setBorderColor('red')
        end
    end

    if isLockerContainer(container) then
        local bankItem = setupLockerBankSlot(containerPanel)
        if bankItem then
            local insertIndex = math.min(3, containerPanel:getChildCount())
            containerPanel:insertChild(insertIndex, bankItem)
        end
    end

    container.window = containerWindow
    container.itemsPanel = containerPanel

    toggleContainerPages(containerWindow, container:hasPages())
    refreshContainerPages(container)

    local layout = containerPanel:getLayout()
    local cellSize = layout:getCellSize()
    containerWindow:setContentMinimumHeight(cellSize.height)
    containerWindow:setContentMaximumHeight(cellSize.height * layout:getNumLines() + 15)

    if not previousContainer then
        local panel = modules.game_interface.findContentPanelAvailable(containerWindow, cellSize.height)
        panel:addChild(containerWindow)

        if modules.client_options.getOption('openMaximized') then
            containerWindow:setContentHeight(cellSize.height * layout:getNumLines())
        else
            local filledLines = math.max(math.ceil(container:getItemsCount() / layout:getNumColumns()), 1)
            containerWindow:setContentHeight(filledLines * cellSize.height)
        end
    end

    containerWindow:setup()
    if containerWindow.save and not previousContainer then
        containerWindow:setupOnStart()
    end

    if containerUid then
        saveOpenContainerSnapshot()
    end
end

function onContainerClose(container)
    local containerId = container:getId()
    local containerUid = uidByContainerId[containerId]
    if containerUid and containerByUid[containerUid] == container then
        uidByContainerId[containerId] = nil
        containerByUid[containerUid] = nil
    end

    destroy(container)
end

function onContainerChangeSize(container, size)
    if not container.window then
        return
    end
    refreshContainerItems(container)
end

function onContainerUpdateItem(container, slot, item, oldItem)
    if not container.window then
        return
    end
    local slotWidget = container.itemsPanel:getChildById('item' .. slot)
    local itemWidget = slotWidget:getChildById('item')
    itemWidget:setItem(item)
    itemWidget.position = container:getSlotPosition(slot)
    ItemsDatabase.setRarityItem(slotWidget, item)
    ItemsDatabase.setTier(itemWidget, item)
    ItemsDatabase.setTierFrame(slotWidget, item)
    if modules.client_options.getOption('showExpiryInContainers') then
        ItemsDatabase.setCharges(itemWidget, container:getItem(slot))
        ItemsDatabase.setDuration(itemWidget, container:getItem(slot))
    end
end
