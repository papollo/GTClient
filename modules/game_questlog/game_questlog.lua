questLogController = Controller:new()
-- The current module may be unavailable while dependencies are being loaded.
questLogController.name = 'game_questlog'
questLogController.currentSortOrders = {
    quests = 'Alphabetically (A-Z)',
    information = 'Alphabetically (A-Z)'
}

-- @ todo
-- test tracker onUpdateQuestTracker
-- test 14.10
-- questLogController:bindKeyPress('Down' // 'up') focusNextChild // focusPreviousChild
-- PopMenu Miniwindows "Remove completed quests // Automatically track new quests // Automatically untrack completed quests"

-- @  windows
local trackerMiniWindow = nil
local questLogButton = nil
local buttonQuestLogTrackerButton = nil
local activeTab = 'character'
local updatingTrackerCheck = false
local characterRows = {}
local characterSections = {}
local SORT_OPTIONS = { 'Alphabetically (A-Z)', 'Alphabetically (Z-A)', 'Completed on Top', 'Completed on Bottom' }
local INFORMATION_SORT_OPTIONS = { 'Alphabetically (A-Z)', 'Alphabetically (Z-A)' }
local CATEGORY_QUEST = 0
local CATEGORY_INFORMATION = 1
local TRACKER_SETTINGS_VERSION = 2

-- @widgets
local UICheckBox = {
    showComplete = nil,
    showShidden = nil,
    showInQuestTracker = nil
}

local UIlabel = {
    numberQuestComplete = nil,
    numberQuestHidden = nil
}

local UITextList = {
    questLogList = nil,
    questLogLine = nil,
    questLogInfo = nil
}

local UITextEdit = {
    search = nil
}

-- variable
local settings = {
    version = TRACKER_SETTINGS_VERSION,
    characters = {}
}
local namePlayer = ""
local journalLists = {
    quests = {},
    information = {}
}
local questItemState = {}
local selectedJournalId = nil
local trackerValidationPending = {}
local trackerValidationChanged = false
local updatingSortOptions = false
local questLogCache = {
    items = {},
    completed = 0,
    hidden = 0,
    visible = 0
}

-- const
local COLORS = {
    BASE_1 = "#484848",
    BASE_2 = "#414141",
    SELECTED = "#585858"
}
local file = "/settings/questtracking.json"

--[[=================================================
=               Local Functions                     =
=================================================== ]] --

local function isIdInTracker(key, id)
    local entries = settings.characters and settings.characters[key]
    if not entries then
        return false
    end
    return table.findbyfield(entries, 'missionId', tonumber(id)) ~= nil
end

local function setTrackerChecked(checked)
    updatingTrackerCheck = true
    UICheckBox.showInQuestTracker:setChecked(checked)
    updatingTrackerCheck = false
end

local function addUniqueIdQuest(key, id, name, questId)
    if not settings.characters[key] then
        settings.characters[key] = {}
    end

    if not isIdInTracker(key, id) then
        table.insert(settings.characters[key], {
            missionId = tonumber(id),
            missionName = name,
            questId = tonumber(questId)
        })
    end
end

local function removeNumber(key, id)
    if settings.characters and settings.characters[key] then
        table.remove_if(settings.characters[key], function(_, v)
            return v.missionId == tonumber(id)
        end)
    end
end

local function emptyTrackerSettings()
    return {
        version = TRACKER_SETTINGS_VERSION,
        characters = {}
    }
end

local function load()
    if g_resources.fileExists(file) then
        local status, result = pcall(function()
            return json.decode(g_resources.readFileContents(file))
        end)
        if not status then
            g_logger.error(
                "Error while reading quest tracker settings. The tracker will be reset. Details: " .. result)
            return emptyTrackerSettings(), true
        end
        local version = type(result) == 'table' and tonumber(result.version) or nil
        if not version or version < TRACKER_SETTINGS_VERSION or type(result.characters) ~= 'table' then
            return emptyTrackerSettings(), true
        end
        return result, false
    end
    return emptyTrackerSettings(), false
end

local function save()
    local status, result = pcall(function()
        return json.encode(settings, 2)
    end)
    if not status then
        return g_logger.error("Error while saving profile settings. Data won't be saved. Details: " .. result)
    end
    if result:len() > 100 * 1024 * 1024 then
        return g_logger.error("Something went wrong, file is above 100MB, won't be saved")
    end
    g_resources.writeFileContents(file, result)
end

local sortFunctions = {
    ["Alphabetically (A-Z)"] = function(a, b)
        return a:getText() < b:getText()
    end,
    ["Alphabetically (Z-A)"] = function(a, b)
        return a:getText() > b:getText()
    end,
    ["Completed on Top"] = function(a, b)
        local aCompleted = a.isComplete or false
        local bCompleted = b.isComplete or false

        if aCompleted and not bCompleted then
            return true
        elseif not aCompleted and bCompleted then
            return false
        else
            return a:getText() < b:getText()
        end
    end,
    ["Completed on Bottom"] = function(a, b)
        local aCompleted = a.isComplete or false
        local bCompleted = b.isComplete or false

        if aCompleted and not bCompleted then
            return false
        elseif not aCompleted and bCompleted then
            return true
        else
            return a:getText() < b:getText()
        end
    end
}

local function sendQuestTracker(listToMap)
    local map = {}
    for _, entry in ipairs(listToMap) do
        map[entry.missionId] = entry.missionName
    end
    g_game.sendRequestTrackerQuestLog(map)
end

local function destroyWindows(windows)
    if type(windows) == "table" then
        for _, window in pairs(windows) do
            if window and not window:isDestroyed() then
                window:destroy()
            end
        end
    else
        if windows and not windows:isDestroyed() then
            windows:destroy()
        end
    end
    return nil
end

local function resetItemCategorySelection(list)
    for _, child in pairs(list:getChildren()) do
        child:setChecked(false)
        child:setBackgroundColor(child.BaseColor)
        if child.iconShow then
            child.iconShow:setVisible(child.isHiddenQuestLog)
        end
        if child.iconPin then
            child.iconPin:setVisible(child.isPinned)
        end
    end
end

local function createQuestItem(parent, id, text, color, icon, trackQuestState)
    local item = g_ui.createWidget("QuestLogLabel", parent)
    item:setId(id)
    item:setText(text)
    item:setBackgroundColor(color)
    item:setPhantom(false)
    item:setFocusable(true)
    item.BaseColor = color
    item.isPinned = false
    item.isComplete = false
    item.isHiddenQuestLog = false
    if icon then
        item:setIcon(icon)
    end
    if parent == UITextList.questLogList then
        table.insert(questLogCache.items, item)
        if trackQuestState and icon ~= "" then
            item.isComplete = true
            questLogCache.completed = questLogCache.completed + 1
        end
    end
    return item
end

local function updateQuestCounter()
    UIlabel.numberQuestComplete:setText(tr('Completed: %d', questLogCache.completed))
    UIlabel.numberQuestHidden:setText(tr('Hidden: %d', questLogCache.hidden))
end

local function recolorVisibleItems()
    local categoryColor = COLORS.BASE_1
    local visibleIndex = 0

    for _, item in pairs(questLogCache.items) do
        if item:isExplicitlyVisible() then
            visibleIndex = visibleIndex + 1
            item:setBackgroundColor(visibleIndex % 2 == 1 and COLORS.BASE_1 or COLORS.BASE_2)
            item.BaseColor = item:getBackgroundColor()
        end
    end
end

local function sortQuestList(questList, sortOrder)
    if activeTab == 'quests' or activeTab == 'information' then
        questLogController.currentSortOrders[activeTab] = sortOrder
    end
    local pinnedItems = {}
    local regularItems = {}
    for _, child in pairs(questLogCache.items) do
        if child.isPinned then
            table.insert(pinnedItems, child)
        else
            table.insert(regularItems, child)
        end
    end
    local sortFunc = sortFunctions[sortOrder]
    if sortFunc then
        table.sort(regularItems, sortFunc)
    end
    questLogCache.items = {}
    local index = 1
    for _, item in ipairs(pinnedItems) do
        questList:moveChildToIndex(item, index)
        table.insert(questLogCache.items, item)
        index = index + 1
    end
    for _, item in ipairs(regularItems) do
        questList:moveChildToIndex(item, index)
        table.insert(questLogCache.items, item)
        index = index + 1
    end
    recolorVisibleItems()
    updateQuestCounter()
end


local function setupQuestItemClickHandler(item, isQuestList, questControls)
    function item:onClick()
        local list = isQuestList and UITextList.questLogList or UITextList.questLogLine
        resetItemCategorySelection(list)
        self:setChecked(true)
        self:setBackgroundColor(COLORS.SELECTED)
        if isQuestList then
            selectedJournalId = tonumber(self:getId())
            g_game.requestQuestLine(self:getId())
            self.iconShow:setVisible(questControls == true)
            self.iconPin:setVisible(questControls == true)
            questLogController.ui.panelQuestLineSelected:setText(self:getText())
        else
            local text = self.description:gsub("\\n", "\n")
            UITextList.questLogInfo:setText(text)
        end
        setTrackerChecked(activeTab == 'quests' and not isQuestList and
            isIdInTracker(g_game.getCharacterName():lower(), tonumber(self:getId())))
    end

    if isQuestList and questControls then
        function item.iconPin:onClick(mousePos)
            local parent = self:getParent()
            parent.isPinned = not parent.isPinned
            if parent.isPinned then
                self:setImageColor("#00ff00")
                local list = UITextList.questLogList
                list:removeChild(parent)
                list:insertChild(1, parent)

                table.removevalue(questLogCache.items, parent)
                table.insert(questLogCache.items, 1, parent)
                recolorVisibleItems()
            else
                self:setImageColor("#ffffff")
                self:setVisible(false)
                sortQuestList(UITextList.questLogList,
                    questLogController.currentSortOrders.quests or "Alphabetically (A-Z)")
            end
            return true
        end

        function item.iconShow:onClick(mousePos, mouseButton)
            local parent = self:getParent()
            parent.isHiddenQuestLog = not parent.isHiddenQuestLog
            if parent.isHiddenQuestLog then
                questLogCache.hidden = questLogCache.hidden + 1
                self:setImageColor("#ff0000")
                if not UICheckBox.showShidden:isChecked() then
                    parent:setVisible(false)
                    questLogCache.visible = questLogCache.visible - 1
                end
            else
                questLogCache.hidden = questLogCache.hidden - 1
                self:setImageColor("#ffffff")
                if UICheckBox.showShidden:isChecked() then
                    parent:setVisible(false)
                    questLogCache.visible = questLogCache.visible - 1
                else
                    local isCompleted = parent.isComplete
                    local shouldBeVisible = UICheckBox.showComplete:isChecked() or not isCompleted
                    parent:setVisible(shouldBeVisible)
                    if shouldBeVisible then
                        questLogCache.visible = questLogCache.visible + 1
                    end
                end
            end

            if parent.iconShow then
                parent.iconShow:setVisible(parent.isHiddenQuestLog)
            end
            if parent.iconPin then
                parent.iconPin:setVisible(parent.isPinned)
            end

            updateQuestCounter()
            recolorVisibleItems()
            return true
        end
    end
end

local function rememberQuestItemState()
    if activeTab ~= 'quests' then
        return
    end
    for _, item in ipairs(questLogCache.items) do
        questItemState[tonumber(item:getId())] = {
            pinned = item.isPinned == true,
            hidden = item.isHiddenQuestLog == true
        }
    end
end

local function resetJournalDetails()
    selectedJournalId = nil
    UITextList.questLogLine:destroyChildren()
    UITextList.questLogInfo:setText('')
    local emptyLabel = activeTab == 'information' and 'No information selected' or 'No quest line Selected'
    questLogController.ui.panelQuestLineSelected:setText(tr(emptyLabel))
    setTrackerChecked(false)
end

local function configureSortOptions(tab)
    local filter = questLogController.ui.panelQuestLog.comboBoxFilter
    local options = tab == 'information' and INFORMATION_SORT_OPTIONS or SORT_OPTIONS
    local sortOrder = questLogController.currentSortOrders[tab] or options[1]
    updatingSortOptions = true
    filter:clearOptions()
    for _, option in ipairs(options) do
        filter:addOption(tr(option), option)
    end
    filter:setCurrentOption(tr(sortOrder), true)
    updatingSortOptions = false
end

local function configureJournalControls(tab)
    local quests = tab == 'quests'
    local filterPanel = questLogController.ui.panelQuestLog.filterPanel
    questLogController.ui.panelQuestLog.title:setText(tr(quests and 'Quests' or 'Information'))
    filterPanel:setVisible(quests)
    filterPanel:setHeight(quests and 44 or 0)
    questLogController.ui.trackerButton:setVisible(quests and g_game.getClientVersion() >= 1280)
    UICheckBox.showInQuestTracker:setVisible(quests and g_game.getClientVersion() >= 1280)
    UICheckBox.showInQuestTracker:setHeight(quests and 18 or 0)
    configureSortOptions(tab)
end

local function renderJournalList(tab)
    rememberQuestItemState()
    UITextList.questLogList:destroyChildren()
    resetJournalDetails()

    local list = journalLists[tab] or {}
    local quests = tab == 'quests'
    questLogCache = {
        items = {},
        completed = 0,
        hidden = 0,
        visible = #list
    }

    local categoryColor = COLORS.BASE_1
    for _, data in ipairs(list) do
        local id, entryName, completed = unpack(data)
        local icon = quests and completed and "/game_cyclopedia/images/checkmark-icon" or ""
        local item = createQuestItem(UITextList.questLogList, id, entryName, categoryColor, icon, quests)
        if quests then
            local state = questItemState[tonumber(id)]
            if state then
                item.isPinned = state.pinned
                item.isHiddenQuestLog = state.hidden
                item.iconPin:setImageColor(state.pinned and '#00ff00' or '#ffffff')
                item.iconShow:setImageColor(state.hidden and '#ff0000' or '#ffffff')
                if state.hidden then
                    questLogCache.hidden = questLogCache.hidden + 1
                end
            end
        end
        setupQuestItemClickHandler(item, true, quests)
        categoryColor = categoryColor == COLORS.BASE_1 and COLORS.BASE_2 or COLORS.BASE_1
    end

    local options = quests and SORT_OPTIONS or INFORMATION_SORT_OPTIONS
    local sortOrder = questLogController.currentSortOrders[tab] or options[1]
    sortQuestList(UITextList.questLogList, sortOrder)
    filterQuestList(UITextEdit.search.SearchEdit:getText())
    updateQuestCounter()
end

--[[=================================================
=                        Windows                     =
=================================================== ]] --
local function hide()
    if not questLogController.ui then
        return
    end
    questLogController.ui:hide()
    if questLogButton then
        questLogButton:setOn(false)
    end
end

function questLogController:refreshCharacter()
    if not self.ui or activeTab ~= 'character' or not self.ui:isVisible() then
        return
    end
    local snapshot = modules.game_skills.SkillData.getSnapshot()
    for id, row in pairs(characterRows) do
        local state = snapshot[id]
        local visible = state ~= nil and state.visible
        row:setVisible(visible == true)
        if visible then
            local label = tr(state.label or row.labelKey)
            local value = state.text
            local valueColor = state.color
            if state.specializationRank ~= nil then
                local rank = modules.game_skills.SkillData.specializationRanks[state.specializationRank]
                value = rank and tr(rank) or tostring(state.specializationRank)
                valueColor = modules.game_skills.SkillData.specializationRankColors[state.specializationRank]
                    or state.color
            end
            if state.maximum then
                value = value .. ' / ' .. state.maximum
            end
            row:getChildById('name'):setText(label)
            row:getChildById('value'):setText(value)
            row:getChildById('value'):setColor(valueColor)
            local progress = row:getChildById('progress')
            progress:setVisible(state.hasProgress and state.percent ~= nil)
            if state.hasProgress and state.percent then
                progress:setPercent(state.percent)
                progress:setBackgroundColor(state.progressColor or '#008b00')
            end
            local tooltip = label .. ': ' .. value
            for _, key in ipairs({'tooltip', 'valueTooltip', 'progressTooltip'}) do
                if state[key] and state[key] ~= '' then
                    tooltip = tooltip .. '\n' .. state[key]
                end
            end
            row:setTooltip(tooltip)
        end
    end
    for _, section in ipairs(characterSections) do
        local visible = false
        for _, definition in ipairs(section.rows) do
            local state = snapshot[definition[1]]
            visible = visible or (state ~= nil and state.visible)
        end
        section.widget:setVisible(visible)
    end
end

function questLogController:selectTab(tab, requestQuests)
    if not self.ui or (tab ~= 'character' and tab ~= 'quests' and tab ~= 'information') then
        return
    end
    rememberQuestItemState()
    local changed = activeTab ~= tab
    activeTab = tab
    local journal = tab == 'quests' or tab == 'information'
    self.ui.characterTab:setOn(tab == 'character')
    self.ui.questsTab:setOn(tab == 'quests')
    self.ui.informationTab:setOn(tab == 'information')
    self.ui.characterPanel:setVisible(not journal)
    self.ui.panelQuestLog:setVisible(journal)
    self.ui.panelQuestLineSelected:setVisible(journal)
    if journal then
        configureJournalControls(tab)
        renderJournalList(tab)
    end
    if journal and g_game.isOnline() and (changed or requestQuests) then
        g_game.requestQuestLog()
    elseif not journal then
        self:refreshCharacter()
    end
end

function show(tab)
    if not questLogController.ui or not g_game.isOnline() then
        return
    end
    questLogController.ui:show()
    questLogController:selectTab(tab or activeTab, true)
    questLogController.ui:raise()
    questLogController.ui:focus()
    questLogButton:setOn(true)
end

local function toggle()
    if not questLogController.ui then
        return
    end
    if questLogController.ui:isVisible() then
        return hide()
    end
    show()
end

local function toggleTracker()
    if trackerMiniWindow:isOn() then
        trackerMiniWindow:close()
    else
        if not trackerMiniWindow:getParent() then
            local panel = modules.game_interface
                              .findContentPanelAvailable(trackerMiniWindow, trackerMiniWindow:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(trackerMiniWindow)
        end
        trackerMiniWindow:open()
    end
end
--[[=================================================
=                        miniWindows                     =
=================================================== ]] --
function onOpenTracker()
    buttonQuestLogTrackerButton:setOn(true)
end

function onCloseTracker()
    buttonQuestLogTrackerButton:setOn(false)
end

local function showQuestTracker()
    if trackerMiniWindow then
        toggleTracker()
        return
    end
    trackerMiniWindow = g_ui.createWidget('QuestLogTracker')
    trackerMiniWindow.menuButton.onClick = function(widget, mousePos)
        local menu = g_ui.createWidget('PopupMenu')
        menu:setGameMenu(true)
        menu:addOption('Remove All quest', function()
            if settings.characters[namePlayer] then
                table.clear(settings.characters[namePlayer])
                sendQuestTracker(settings.characters[namePlayer])
                trackerMiniWindow.contentsPanel.list:getLayout():enableUpdates()
                trackerMiniWindow.contentsPanel.list:getLayout():update()
            end
        end)
        menu:addOption('Remove completed quests', function()
            print("to-do")
        end)
        menu:addSeparator()
        menu:addCheckBox('Automatically track new quests', false, function(a, b)
            print(a, b)
        end):disable()
        menu:addCheckBox('Automatically untrack completed quests', false, function(a, b)
            print(a, b)
        end):disable()

        menu:display(mousePos)
        return true
    end
    trackerMiniWindow.cyclopediaButton.onClick = function()
        show('quests')
        return true
    end
    trackerMiniWindow:moveChildToIndex(trackerMiniWindow.menuButton, 4)
    trackerMiniWindow:moveChildToIndex(trackerMiniWindow.cyclopediaButton, 5)
    trackerMiniWindow:setContentMinimumHeight(80)
    trackerMiniWindow:setup()
    toggleTracker()
end

--[[=================================================
=                      onParse                      =
=================================================== ]] --
local function completeTrackerValidation()
    if next(trackerValidationPending) then
        return
    end
    local changed = trackerValidationChanged
    if changed then
        save()
        trackerValidationChanged = false
    end
    local entries = settings.characters[namePlayer] or {}
    if #entries > 0 or (changed and trackerMiniWindow) then
        sendQuestTracker(entries)
    elseif trackerMiniWindow then
        trackerMiniWindow.contentsPanel.list:destroyChildren()
    end
end

local function validateTrackerParents(availableQuestIds)
    local storedEntries = settings.characters[namePlayer]
    local entries = {}
    settings.characters[namePlayer] = entries
    trackerValidationPending = {}
    trackerValidationChanged = false

    if storedEntries ~= nil and type(storedEntries) ~= 'table' then
        trackerValidationChanged = true
        storedEntries = {}
    end
    for _, entry in pairs(storedEntries or {}) do
        local valid = type(entry) == 'table' and tonumber(entry.missionId) and
            type(entry.missionName) == 'string' and tonumber(entry.questId) and
            availableQuestIds[tonumber(entry.questId)] == true
        if not valid then
            trackerValidationChanged = true
        else
            entry.missionId = tonumber(entry.missionId)
            entry.questId = tonumber(entry.questId)
            table.insert(entries, entry)
            trackerValidationPending[entry.questId] = true
        end
    end

    if not next(trackerValidationPending) then
        completeTrackerValidation()
        return
    end
    for questId in pairs(trackerValidationPending) do
        g_game.requestQuestLine(questId)
    end
end

local function onQuestLog(questList)
    local availableQuestIds = {}
    journalLists = {
        quests = {},
        information = {}
    }

    for _, data in ipairs(questList) do
        local id, entryName, completed, category = unpack(data)
        if category == CATEGORY_QUEST then
            table.insert(journalLists.quests, {id, entryName, completed})
            availableQuestIds[tonumber(id)] = true
        elseif category == CATEGORY_INFORMATION then
            table.insert(journalLists.information, {id, entryName, false})
        else
            g_logger.warning(string.format('Ignoring journal entry %s with unknown category %s',
                tostring(id), tostring(category)))
        end
    end

    if g_game.getClientVersion() >= 1280 then
        validateTrackerParents(availableQuestIds)
    end
    if activeTab == 'quests' or activeTab == 'information' then
        renderJournalList(activeTab)
    end
end

local function onQuestLine(questId, questMissions)
    questId = tonumber(questId)
    if trackerValidationPending[questId] then
        local availableMissions = {}
        for _, data in ipairs(questMissions) do
            local missionId = tonumber(data[3])
            if missionId then
                availableMissions[missionId] = true
            end
        end
        local entries = settings.characters[namePlayer] or {}
        for index = #entries, 1, -1 do
            local entry = entries[index]
            if entry.questId == questId and not availableMissions[entry.missionId] then
                table.remove(entries, index)
                trackerValidationChanged = true
            end
        end
        trackerValidationPending[questId] = nil
        completeTrackerValidation()
    end

    if selectedJournalId ~= questId or (activeTab ~= 'quests' and activeTab ~= 'information') then
        return
    end
    UITextList.questLogLine:destroyChildren()
    local categoryColor = COLORS.BASE_1
    for _, data in ipairs(questMissions) do
        local missionName, missionDescription, missionId = unpack(data)
        local itemCat = createQuestItem(UITextList.questLogLine, missionId, missionName, categoryColor)
        itemCat.description = missionDescription
        setupQuestItemClickHandler(itemCat, false, activeTab == 'quests')
        categoryColor = categoryColor == COLORS.BASE_1 and COLORS.BASE_2 or COLORS.BASE_1
    end
end

local function onQuestTracker(remainingQuests, missions)
    if not trackerMiniWindow then
        showQuestTracker()
    end
    if not missions or type(missions[1]) ~= "table" then
        trackerMiniWindow.contentsPanel.list:destroyChildren()
        return
    end
    trackerMiniWindow.contentsPanel.list:destroyChildren()
    for index, mission in ipairs(missions) do
        local missionId, questName, questIsCompleted, missionName, missionDesc = unpack(mission)
        local trackerLabel = g_ui.createWidget('QuestTrackerLabel', trackerMiniWindow.contentsPanel.list)
        trackerLabel:setId(missionId)
        trackerLabel.description:setText(missionDesc)
    end
end

local function onUpdateQuestTracker(missionId, missionName, questIsCompleted, missionDesc)
    -- untest
    -- print(missionId, missionName, questIsCompleted, missionDesc)
    local trackerLabel = trackerMiniWindow.contentsPanel.list:getChildById(missionId)
    if trackerLabel then
        trackerLabel.description:setText(missionDesc)
    end
end
--[[=================================================
=               onCall otui / html                  =
=================================================== ]] --
function filterQuestList(searchText)
    local quests = activeTab == 'quests'
    local showComplete = not quests or UICheckBox.showComplete:isChecked()
    local showHidden = quests and UICheckBox.showShidden:isChecked()
    local searchPattern = searchText and string.lower(searchText) or nil
    questLogCache.visible = 0
    for _, child in pairs(questLogCache.items) do
        local isCompleted = child.isComplete
        local isHidden = child.isHiddenQuestLog
        local text = child:getText()
        local visible = true
        if searchPattern and text then
            visible = string.find(string.lower(text), searchPattern, 1, true) ~= nil
        end
        if not showComplete and isCompleted then
            visible = false
        end
        if showHidden then
            visible = visible and isHidden
        else
            visible = visible and not isHidden
        end
        child:setVisible(visible)
        if visible then
            questLogCache.visible = questLogCache.visible + 1
        end
        if child.iconShow then
            child.iconShow:setVisible(child.isHiddenQuestLog)
        end
        if child.iconPin then
            child.iconPin:setVisible(child.isPinned)
        end
    end
    recolorVisibleItems()
end

function questLogController:onCheckChangeQuestTracker(event)
    if updatingTrackerCheck or activeTab ~= 'quests' or g_game.getClientVersion() < 1280 then
        return
    end
    if UITextList.questLogLine:hasChildren() and UITextList.questLogLine:getFocusedChild() then
        local id = tonumber(UITextList.questLogLine:getFocusedChild():getId())
        if event.checked then
            if not trackerMiniWindow then
                showQuestTracker()
            elseif not trackerMiniWindow:isVisible() then
                toggleTracker()
            end
            addUniqueIdQuest(namePlayer, id, UITextList.questLogLine:getFocusedChild():getText(), selectedJournalId)
        else
            removeNumber(namePlayer, id, UITextList.questLogLine:getFocusedChild():getText())
            local trackerLabel = trackerMiniWindow and trackerMiniWindow.contentsPanel.list:getChildById(tostring(id))
            if trackerLabel then
                trackerLabel:destroy()
                trackerLabel = nil
            end
        end
        if settings.characters[namePlayer] and (event.checked == isIdInTracker(namePlayer, id)) then
            sendQuestTracker(settings.characters[namePlayer])
        end
    end
end

function questLogController:onFilterQuestLog(event)
    if not updatingSortOptions and sortFunctions[event.text] then
        sortQuestList(UITextList.questLogList, event.text)
    end
end

function questLogController:close()
    hide()
end

function questLogController:toggleMiniWindowsTracker()
    if not trackerMiniWindow then
        showQuestTracker()
        return
    end
    if trackerMiniWindow:isVisible() then
        if buttonQuestLogTrackerButton then
            buttonQuestLogTrackerButton:setOn(false)
        end
        return trackerMiniWindow:hide()
    end
    if buttonQuestLogTrackerButton then
        buttonQuestLogTrackerButton:setOn(true)
    end
    showQuestTracker()
end

function questLogController:filterQuestListShowComplete()
    filterQuestList(UITextEdit.search.SearchEdit:getText())
end

function questLogController:filterQuestListShowHidden()
    filterQuestList(UITextEdit.search.SearchEdit:getText())
end

function onSearchTextChange(text)
    if text and text:len() > 0 then
        filterQuestList(text)
    else
        filterQuestList()
    end
end

function onQuestLogMousePress(widget, mousePos, mouseButton)
    if mouseButton ~= MouseRightButton then
        return
    end
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('remove'), function()
        removeNumber(namePlayer, widget:getParent():getId())
        if settings.characters[namePlayer] then
            sendQuestTracker(settings.characters[namePlayer])
        end
        widget:getParent():destroy()
    end)
    menu:display(mousePos)
    return true
end

--[[=================================================
=               Controller                     =
=================================================== ]] --
function questLogController:onInit()
    g_ui.importStyle("styles/game_questlog.otui")
    questLogController:loadUI('journal')
    questLogController.ui:centerIn('parent')
    hide()

    UITextList.questLogList = questLogController.ui.panelQuestLog.areaPanelQuestList.questList
    UITextList.questLogLine = questLogController.ui.panelQuestLineSelected.ScrollAreaQuestList.questList
    UITextList.questLogInfo = questLogController.ui.panelQuestLineSelected.panelQuestInfo.questList

    UITextEdit.search = questLogController.ui.panelQuestLog.textEditSearchQuest
    UIlabel.numberQuestComplete = questLogController.ui.panelQuestLog.filterPanel.lblCompleteNumber
    UIlabel.numberQuestHidden = questLogController.ui.panelQuestLog.filterPanel.lblHiddenNumber
    UICheckBox.showComplete = questLogController.ui.panelQuestLog.filterPanel.checkboxShowComplete
    UICheckBox.showShidden = questLogController.ui.panelQuestLog.filterPanel.checkboxShowShidden
    UICheckBox.showInQuestTracker = questLogController.ui.panelQuestLineSelected.checkboxShowInQuestTracker

    local filter = self.ui.panelQuestLog.comboBoxFilter
    for _, option in ipairs(SORT_OPTIONS) do
        filter:addOption(tr(option), option)
    end
    filter.onOptionChange = function(widget, text, data)
        self:onFilterQuestLog({ text = data })
    end
    UICheckBox.showComplete.onCheckChange = function() self:filterQuestListShowComplete() end
    UICheckBox.showShidden.onCheckChange = function() self:filterQuestListShowHidden() end
    UICheckBox.showInQuestTracker.onCheckChange = function(widget, checked)
        self:onCheckChangeQuestTracker({ checked = checked })
    end
    updateQuestCounter()

    local skillData = modules.game_skills.SkillData
    for _, group in ipairs(skillData.groups) do
        local column = self.ui.characterPanel:getChildById(group.column)
        local section = g_ui.createWidget('JournalSection', column)
        section:getChildById('title'):setText(tr(group.title))
        table.insert(characterSections, { widget = section, rows = group.rows })
        for _, definition in ipairs(group.rows) do
            local row = g_ui.createWidget('JournalStat', section)
            row:setId(definition[1])
            row.labelKey = definition[2]
            characterRows[definition[1]] = row
        end
    end
    self:registerEvents(skillData, { onChange = function() self:refreshCharacter() end })
    self:selectTab('character')

    questLogController:registerEvents(g_game, {
        onQuestLog = onQuestLog,
        onQuestLine = onQuestLine,
        onQuestTracker = onQuestTracker,
        onUpdateQuestTracker = onUpdateQuestTracker
    })

    questLogButton = modules.game_mainpanel.addToggleButton('questLogButton', tr('Journal'),
        '/images/options/button_questlog', function()
            toggle()
        end, false, 1000)
    -- Keep the action ID so existing user key assignments continue to work.
    Keybind.new("Windows", "Show/hide quest Log", "", "")
    Keybind.bind("Windows", "Show/hide quest Log", {{
        type = KEY_DOWN,
        callback = function()
            toggle()
        end
    }})
end

function questLogController:onTerminate()
    characterRows, characterSections = {}, {}
    questLogButton, trackerMiniWindow, buttonQuestLogTrackerButton = destroyWindows(
        {questLogButton, trackerMiniWindow, buttonQuestLogTrackerButton})
    Keybind.delete("Windows", "Show/hide quest Log")
end

function questLogController:onGameStart()
    activeTab = 'character'
    namePlayer = g_game.getCharacterName():lower()
    UICheckBox.showInQuestTracker:setVisible(g_game.getClientVersion() >= 1280)
    self:selectTab('character')
    if g_game.getClientVersion() >= 1280 then
        namePlayer = g_game.getCharacterName():lower()
        local migrated
        settings, migrated = load()
        if migrated then
            g_logger.info('Quest tracker settings migrated to version ' .. TRACKER_SETTINGS_VERSION ..
                '; previous tracked missions were cleared.')
            save()
        end
        if not buttonQuestLogTrackerButton then
            buttonQuestLogTrackerButton = modules.game_mainpanel.addToggleButton("QuestLogTracker",
                tr("Open QuestLog Tracker"), "/images/options/button_questlog_tracker", function()
                    questLogController:toggleMiniWindowsTracker()
                end, false, 1001)
        end
        if trackerMiniWindow then
            trackerMiniWindow:setupOnStart()
        end
        -- The list is needed to validate persisted tracker entries before sending them.
        g_game.requestQuestLog()
    else
        UICheckBox.showInQuestTracker:setVisible(false)
        questLogController.ui.trackerButton:setVisible(false)
    end
end

function questLogController:onGameEnd()
    if g_game.getClientVersion() >= 1280 then
        save()
    end
    hide()
    activeTab = 'character'
    UITextList.questLogList:destroyChildren()
    UITextList.questLogLine:destroyChildren()
    UITextList.questLogInfo:setText('')
    questLogCache = { items = {}, completed = 0, hidden = 0, visible = 0 }
    journalLists = { quests = {}, information = {} }
    questItemState = {}
    selectedJournalId = nil
    trackerValidationPending = {}
    trackerValidationChanged = false
    setTrackerChecked(false)
    UICheckBox.showComplete:setChecked(true)
    UICheckBox.showShidden:setChecked(false)
    UITextEdit.search.SearchEdit:clearText()
    self.currentSortOrders = {
        quests = SORT_OPTIONS[1],
        information = INFORMATION_SORT_OPTIONS[1]
    }
    configureSortOptions('quests')
    self.ui.panelQuestLineSelected:setText(tr('No quest line Selected'))
    updateQuestCounter()
    for _, row in pairs(characterRows) do
        row:getChildById('value'):setText('')
        row:hide()
    end
    self.ui.characterPanel.leftScroll:setValue(0)
    self.ui.characterPanel.rightScroll:setValue(0)
    if trackerMiniWindow then
        trackerMiniWindow:setParent(nil, true)
    end
end
