QuickLoot = {}

local quickLootButton = nil

local function getFilter(id)
    local filter = {
        [1] = 0, -- skipped/blacklist = 0
        [2] = 1  -- accepted/whitelist = 1
    }
    return filter[id]
end

local function normalizeLootLists(data)
    data = data or {}
    data.loots = data.loots or {}

    -- Keep the client-side representation consistent:
    -- [1] = skipped blacklist, [2] = accepted whitelist
    -- Handle JSON libraries that may decode arrays as 0-indexed
    local skipped = data.loots[1]
    local accepted = data.loots[2]

    if data.loots[0] ~= nil then
        -- JSON decoded as 0-indexed: [0]=skipped, [1]=accepted
        skipped = data.loots[0]
        if accepted == nil then
            accepted = data.loots[1]
        end
    end

    if skipped == nil then
        skipped = {}
    end

    if accepted == nil then
        accepted = {}
    end

    data.loots = {
        [1] = skipped,
        [2] = accepted
    }

    if data.filter ~= 1 and data.filter ~= 2 then
        data.filter = 1
    end

    return data
end

local function getQuickLootBagWidget(categoryId)
    if not quickLootController or not quickLootController.ui then
        return nil
    end

    for _, child in ipairs(quickLootController.ui.list:getChildren()) do
        if child:getId() == categoryId then
            return child
        end
    end

    return nil
end

quickLootController = Controller:new()
quickLootController:setUI('quickloot')
function quickLootController:onInit()

    QuickLoot.Define()

    QuickLoot.data = normalizeLootLists({
        filter = 1,
        loots = {
            [1] = {},
            [2] = {}
        }
    })

    quickLootController.ui:hide()

    quickLootController:registerEvents(g_game, {
        onQuickLootContainers = QuickLoot.start
    })

    quickLootButton = modules.game_mainpanel.addToggleButton('quickLootButton', tr('Quick Loot'),
        '/images/options/button_quick_loot', QuickLoot.toggle, false, 4)
    quickLootButton:setOn(false)

    Keybind.new("Loot", "Quick Loot Nearby Corpses", "Alt+Q", "")
    Keybind.bind("Loot", "Quick Loot Nearby Corpses", {
      {
        type = KEY_DOWN,
        callback = function()
            g_game.sendQuickLoot(2)
        end,
      }
    })

end

function quickLootController:onTerminate()
    Keybind.delete("Loot", "Quick Loot Nearby Corpses")
    if quickLootButton then
        quickLootButton:destroy()
        quickLootButton = nil
    end
    if QuickLoot.mouseGrabberWidget then
        QuickLoot.mouseGrabberWidget:destroy()
        QuickLoot.mouseGrabberWidget = nil
    end

    QuickLoot = {}
end

function quickLootController:onGameStart()
    local hasQuickLoot = g_game.getFeature(GameThingQuickLoot)
    if quickLootButton then
        quickLootButton:setVisible(hasQuickLoot)
        quickLootButton:setOn(false)
    end

    if not hasQuickLoot then
        return
    end
    if not QuickLoot.mouseGrabberWidget then
        QuickLoot.mouseGrabberWidget = g_ui.createWidget("UIWidget")
    end
    QuickLoot.mouseGrabberWidget:setVisible(false)
    QuickLoot.mouseGrabberWidget:setFocusable(false)

    QuickLoot.mouseGrabberWidget.onMouseRelease = QuickLoot.onChooseItem
    QuickLoot.lastSelectBag = nil
    QuickLoot.lastSelectBagCategory = nil
    QuickLoot.ErrorWindow = nil

    quickLootController.ui.information.vipPanel.premium:setOn(not g_game.getLocalPlayer():isPremium())
    QuickLoot.load()

    -- Send both lists to the server on login so it has the full state,
    -- then send the active filter last so the server uses the correct mode
    local inactiveFilter = (QuickLoot.data.filter == 1) and 2 or 1
    if #QuickLoot.data.loots[inactiveFilter] > 0 then
        g_game.requestQuickLootBlackWhiteList(getFilter(inactiveFilter),
            #QuickLoot.data.loots[inactiveFilter], QuickLoot.data.loots[inactiveFilter])
    end
    g_game.requestQuickLootBlackWhiteList(getFilter(QuickLoot.data.filter),
        #QuickLoot.data.loots[QuickLoot.data.filter], QuickLoot.data.loots[QuickLoot.data.filter])
end

function quickLootController:onGameEnd()
    if quickLootButton then
        quickLootButton:setOn(false)
    end
    if not g_game.getFeature(GameThingQuickLoot) then
        return
    end
    QuickLoot.save()
    QuickLoot.toggle()
    if quickLootController.ui:isVisible() then
        quickLootController.ui:hide()
    end
end

function QuickLoot.Define()
    function QuickLoot.filter(widget, isChecked)
        widget:setChecked(true)

        isChecked = true

        local accepted = quickLootController.ui.filters.accepted
        local skipped = quickLootController.ui.filters.skipped
        local add_text = string.format("Add to %s Loot List", widget:getId():gsub("^%l", string.upper))
        local clear_text = string.format("Clear %s Loot List", widget:getId():gsub("^%l", string.upper))

        if widget == skipped and isChecked then
            quickLootController.ui.filters.accepted:setChecked(false)
            quickLootController.ui.filters.add:setText(add_text)
            quickLootController.ui.filters.clear:setText(clear_text)

            QuickLoot.data.filter = 1
        end

        if widget == accepted and isChecked then
            quickLootController.ui.filters.skipped:setChecked(false)
            quickLootController.ui.filters.add:setText(add_text)
            quickLootController.ui.filters.clear:setText(clear_text)

            QuickLoot.data.filter = 2
        end

        g_game.requestQuickLootBlackWhiteList(getFilter(QuickLoot.data.filter),
            #QuickLoot.data.loots[QuickLoot.data.filter], QuickLoot.data.loots[QuickLoot.data.filter])
        QuickLoot.loadFilterItems()
    end

    function QuickLoot.lootExists(itemId, filter)
        if not filter then
            filter = QuickLoot.data.filter
        end
        return table.contains(QuickLoot.data.loots[filter], itemId)
    end

    function QuickLoot.addLootList(itemId,filter)
        if not filter then
            filter = QuickLoot.data.filter
        end
        if table.contains(QuickLoot.data.loots[filter], itemId) then
            return
        end

        table.insert(QuickLoot.data.loots[filter], itemId)

        g_game.requestQuickLootBlackWhiteList(getFilter(filter),
            #QuickLoot.data.loots[filter], QuickLoot.data.loots[filter])
        if quickLootController.ui:isVisible() then
            QuickLoot.loadFilterItems()
        end
    end
    function QuickLoot.clearFilterItems()
        QuickLoot.data.loots[QuickLoot.data.filter] = {}

        g_game.requestQuickLootBlackWhiteList(getFilter(QuickLoot.data.filter),
            #QuickLoot.data.loots[QuickLoot.data.filter], QuickLoot.data.loots[QuickLoot.data.filter])
        QuickLoot.loadFilterItems()
    end

    function QuickLoot.removeLootList(itemId, filter)
        if not filter then
            filter = QuickLoot.data.filter
        end
        if not table.contains(QuickLoot.data.loots[filter], itemId) then
            return
        end

        table.removevalue(QuickLoot.data.loots[filter], itemId)

        g_game.requestQuickLootBlackWhiteList(getFilter(filter),
            #QuickLoot.data.loots[filter], QuickLoot.data.loots[filter])
        if quickLootController.ui:isVisible() then
            QuickLoot.loadFilterItems()
        end
    end

    function QuickLoot.load()
        local file = string.format("/settings/%s_containers.json",
            g_game.getLocalPlayer():getName():lower():gsub("%s+", "_"))

        if g_resources.fileExists(file) then
            local status, result = pcall(function()
                return json.decode(g_resources.readFileContents(file))
            end)

            if not status then
                return g_logger.error("Error while reading containers settings file. " .. result)
            end

            if result == nil then
                QuickLoot.data = normalizeLootLists({
                    filter = 1,
                    loots = {
                        [1] = {},
                        [2] = {}
                    }
                })
            else
                QuickLoot.data = normalizeLootLists(result)
            end

        else
            QuickLoot.data = normalizeLootLists({
                filter = 1,
                loots = {
                    [1] = {},
                    [2] = {}
                }
            })
        end
    end

    function QuickLoot.save()
        local file = string.format("/settings/%s_containers.json",
            g_game.getLocalPlayer():getName():lower():gsub("%s+", "_"))
        local status, result = pcall(function()
            return json.encode(QuickLoot.data, 2)
        end)

        if not status then
            return g_logger.warning("Error while saving QuickLoot settings. Data won't be saved. Details: " .. result)
        end

        if result:len() > 104857600 then
            return g_logger.error("Something went wrong, file is above 100MB, won't be saved")
        end

        g_resources.writeFileContents(file, result)
    end

    function QuickLoot.start(quickLootFallbackToMainContainer, lootContainers)
        local player = g_game.getLocalPlayer()
        local vipPanel = quickLootController.ui.information.vipPanel
        local loots = lootContainers
        local fallback = quickLootFallbackToMainContainer

        QuickLoot.loadFilterItems()

        local filter = {
            [1] = "skipped",
            [2] = "accepted"
        }

        QuickLoot.filter(quickLootController.ui.filters[filter[QuickLoot.data.filter]], true)
        quickLootController.ui.list:getLayout():disableUpdates()
        QuickLoot.lastSelectBag = nil
        quickLootController.ui.list:destroyChildren()

        quickLootController.ui.fallbackPanel.checkbox:setChecked(fallback)
        -- LuaFormatter off
		local slotBags = {
			{ color = "#484848", name = "Unassigned", type = 31 },
			{ color = "#414141", name = "Gold", type = 30 },
			{ color = "#484848", name = "Armors", type = 1 },
			{ color = "#414141", name = "Amulets", type = 2  },
			{ color = "#484848", name = "Boots", type = 3 },
			{ color = "#414141", name = "Containers", type = 4 },
			{ color = "#484848", name = "Creature\nProducts", type = 24 },
			{ color = "#414141", name = "Decoration", type = 5 },
			{ color = "#484848", name = "Food", type = 6 },
			{ color = "#414141", name = "Helmets\nand Hats", type =7 },
			{ color = "#484848", name = "Legs", type = 8 },
			{ color = "#414141", name = "Others", type = 9 },

			{ color = "#414141", name = "Potions", type = 10 },
			{ color = "#484848", name = "Rings", type = 11 },
			{ color = "#414141", name = "Runes", type = 12 },
			{ color = "#484848", name = "Shields", type = 13 },
			{ color = "#414141", name = "Tools", type = 14 },
			{ color = "#484848", name = "Valuables", type = 15 },
			{ color = "#414141", name = "Weapons:\nAmmo", type = 16 },
			{ color = "#484848", name = "Weapons:\nAxes", type = 17 },
			{ color = "#414141", name = "Weapons:\nClubs", type = 18 },
			{ color = "#484848", name = "Weapons:\nDistance", type = 19 },
			{ color = "#414141", name = "Weapons:\nSwords", type = 20 },
			{ color = "#484848", name = "Weapons:\nWands", type = 21 },
			--{ color = "#414141", name = "Quivers" , type = 25 },

		}
		-- LuaFormatter on

        for _, slot in ipairs(slotBags) do
            local widget = g_ui.createWidget("QuicklootBagLabel", quickLootController.ui.list)
            local id = slot.type and slot.type or 0

            widget:setId(id)
            widget:setBackgroundColor(slot.color)
            widget.label:setText(slot.name)

            for _, container in pairs(lootContainers) do
                if container[1] == id then
                    local lootContainerId = container[3]
                    local obtainerContainerId = container[2]

                    widget.item:setItemId(lootContainerId)
                    widget.item2:setItemId(obtainerContainerId)
                    break
                end
            end
        end
        quickLootController.ui.list:getLayout():enableUpdates()
        quickLootController.ui.list:getLayout():update()
    end

    function QuickLoot.loadFilterItems()
        quickLootController.ui.ignoreList:destroyChildren()

        local color = "#484848"

        for _, itemId in ipairs(QuickLoot.data.loots[QuickLoot.data.filter]) do
            local internalData = g_things.getThingType(itemId, ThingCategoryItem):getMarketData()
            local widget = g_ui.createWidget("QuicLootIgnoreItem", quickLootController.ui.ignoreList)

            widget:setId(itemId)
            widget:setBackgroundColor(color)
            widget.label:setText(internalData.name)
            widget.item:setItemId(itemId)

            color = color == "#484848" and "#414141" or "#484848"
        end
    end

    function QuickLoot.search(text)
        if not quickLootController.ui then
            return
        end

        local filter = text:lower()
        for _, child in ipairs(quickLootController.ui.ignoreList:getChildren()) do
            if filter == "" then
                child:setVisible(true)
            else
                local name = child.label:getText():lower()
                child:setVisible(name:find(filter, 1, true) ~= nil)
            end
        end
    end

    function QuickLoot.clearSearch()
        local search = quickLootController.ui.search
        search:clearText()
    end

    function QuickLoot.fallback(widget, isChecked)
        g_game.openContainerQuickLoot(3, nil, {}, nil, nil, isChecked)
    end

    function QuickLoot:chooseItem()
        if g_ui.isMouseGrabbed() then
            return
        end

        QuickLoot.mouseGrabberWidget:grabMouse()
        g_mouse.pushCursor("target")

        QuickLoot.lastSelectBag = nil
        QuickLoot.lastSelectBagCategory = self:getParent():getId()
        QuickLoot.actionsId = self.Select

        quickLootController.ui:hide()
    end

    function QuickLoot.confirmError()
        QuickLoot.ErrorWindow:destroy()
        quickLootController.ui:show()
    end

    function QuickLoot:onChooseItem(mousePosition, mouseButton)
        local item

        if mouseButton == MouseLeftButton then
            local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)

            if clickedWidget then
                if clickedWidget:getClassName() == "UIGameMap" then
                    local tile = clickedWidget:getTile(mousePosition)

                    if tile then
                        local thing = tile:getTopMoveThing()

                        if thing and thing:isContainer() then
                            item = thing
                        else
                            QuickLoot.ErrorWindow = displayGeneralBox(tr("Invalid Loot Container"), tr(
                                "You can only select containers you carry in your inventory."), {
                                {
                                    text = tr("Ok"),
                                    callback = QuickLoot.confirmError
                                },
                                anchor = AnchorHorizontalCenter
                            })
                        end
                    end
                elseif clickedWidget:getClassName() == "UIItem" and not clickedWidget:isVirtual() then
                    if clickedWidget:getItem() and clickedWidget:getItem():isContainer() then
                        item = clickedWidget:getItem()
                        g_game.openContainerQuickLoot(QuickLoot.actionsId, QuickLoot.lastSelectBagCategory,
                            item:getPosition(), item:getId(), item:getStackPos())
                    else
                        QuickLoot.ErrorWindow = displayGeneralBox(tr("Invalid Loot Container"), tr(
                            "You can only select containers you carry in your inventory."), {
                            {
                                text = tr("Ok"),
                                callback = QuickLoot.confirmError
                            },
                            anchor = AnchorHorizontalCenter
                        })
                    end
                end
            end
        end

        if item then
            local bagWidget = getQuickLootBagWidget(QuickLoot.lastSelectBagCategory)
            if bagWidget then
                if QuickLoot.actionsId == 0 then
                    bagWidget.item2:setItem(item)
                else
                    bagWidget.item:setItem(item)
                end
            end
            quickLootController.ui:show()
        end

        QuickLoot.lastSelectBagCategory = nil

        g_mouse.popCursor("target")
        self:ungrabMouse()

        return true
    end

    function QuickLoot:openContainer()
        for _, container in pairs(g_game.getContainers()) do
            if container:getContainerItem():getId() == self:getItemId() then
                return false
            end
        end
        g_game.openContainerQuickLoot(self.click, self:getParent():getId(), {}, nil, nil, nil)
        return true
    end

    function QuickLoot:clearItem()
        if self.borrar == 1 then
            self:getParent().item2:setItem(nil)
        else
            self:getParent().item:setItem(nil)
        end
        g_game.openContainerQuickLoot(self.borrar, self:getParent():getId(), {}, nil, nil, nil)
    end

    function QuickLoot:clearFilterItem()
        QuickLoot.removeLootList(self:getParent().item:getItemId())

        QuickLoot.loadFilterItems()
    end

    function QuickLoot.toggle()
        if not quickLootController.ui then
            return
        end

        if quickLootController.ui:isVisible() then
            return QuickLoot.hide()
        end
        QuickLoot.show()
        QuickLoot.loadFilterItems()
        if QuickLoot.data.filter == 2 and not quickLootController.ui.filters.accepted:isChecked() then
            quickLootController.ui.filters.accepted:onClick()
        end
    end

    function QuickLoot.show()
        if not quickLootController.ui then
            return
        end

        if quickLootButton then
            quickLootButton:setOn(true)
        end
        quickLootController.ui:show()
        quickLootController.ui:raise()
        quickLootController.ui:focus()

    end

    function QuickLoot.hide()
        if not quickLootController.ui then
            return
        end
        if quickLootButton then
            quickLootButton:setOn(false)
        end
        quickLootController.ui:hide()
    end

end
