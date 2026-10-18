--[[
    Finalizing Market:
      Note: Feel free to work on any area and submit
            it as a pull request from your git fork.

      BeniS's Skype: benjiz69

      List:
      * Add offer management:
        - Current Offers
        - Offer History

      * Clean up the interface building
        - Add a new market interface file to handle building?

      * Extend information features
        - Hover over offers for purchase information (balance after transaction, etc)
  ]] Market = {}

local protocol = runinsandbox('marketprotocol')

marketWindow = nil
mainTabBar = nil
displaysTabBar = nil
offersTabBar = nil
selectionTabBar = nil

marketOffersPanel = nil
browsePanel = nil
overviewPanel = nil
itemOffersPanel = nil
itemDetailsPanel = nil
itemStatsPanel = nil
myOffersPanel = nil
currentOffersPanel = nil
offerHistoryPanel = nil
activeOffersPanel = nil
itemsPanel = nil
selectedOffer = {}
selectedMyOffer = {}
lastKnownTab = nil
lastOfferTab = nil

nameLabel = nil
feeLabel = nil
balanceLabel = nil
totalPriceEdit = nil
piecePriceEdit = nil
amountEdit = nil
radioItemSet = nil
selectedItem = nil
offerTypeList = nil
categoryList = nil
tierList = nil
searchEdit = nil
searchAllFilter = nil
createOfferButton = nil
buyButton = nil
sellButton = nil
anonymous = nil
depotFilter = nil

buyOfferTable = nil
sellOfferTable = nil
detailsTable = nil
buyStatsTable = nil
sellStatsTable = nil

buyCancelButton = nil
sellCancelButton = nil
buyMyOfferTable = nil
sellMyOfferTable = nil

buyMyHistoryTable = nil
sellMyHistoryTable = nil
activeOffersTable = nil
activeOffers = {}
selectedActiveOffer = nil
local MARKET_ERROR_OPCODE = 204

local function onMarketError(protocol, opcode, buffer)
    if opcode == MARKET_ERROR_OPCODE and buffer == 'market_same_account' then
        local messageBox
        local close = function() messageBox:ok() end
        messageBox = displayGeneralBox(tr('Market'), utf8ToCp1250('Handel pomiędzy postaciami z tego samego konta jest zablokowany.'), {{
            text = tr('Close'),
            callback = close
        }}, close, close)
        messageBox:lock()
    end
end

refreshTimeout = 0
updateEvent = nil
offerExhaust = {}
marketOffers = {}
marketItems = {}
information = {}
currentItems = {}
lastCreatedOffer = 0
fee = 0
averagePrice = 0

loaded = false
local function addMarketItemId(ids, seenIds, id)
    id = tonumber(id)
    if id and id > 0 and not seenIds[id] then
        table.insert(ids, id)
        seenIds[id] = true
    end
end

local function getMarketItemIds(item)
    local ids = {}
    local seenIds = {}
    if not item then
        return ids
    end

    if item.marketData then
        addMarketItemId(ids, seenIds, item.marketData.tradeAs)
    end
    if item.thingType then
        addMarketItemId(ids, seenIds, item.thingType:getId())
    end
    if item.displayItem then
        addMarketItemId(ids, seenIds, item.displayItem:getId())
    end
    if item.marketData then
        addMarketItemId(ids, seenIds, item.marketData.showAs)
    end

    return ids
end

local function getPrimaryMarketItemId(item, preferDepot)
    local ids = getMarketItemIds(item)
    if preferDepot and information.depotItems then
        for _, id in ipairs(ids) do
            local entry = information.depotItems and information.depotItems[tonumber(id)]
            local count = entry and (item.tier and entry.tiers and entry.tiers[item.tier] or not item.tier and entry.itemCount) or 0
            if count > 0 then
                return id
            end
        end
    end
    return ids[1] or 0
end

local function isItemValid(item, category, searchFilter)
    if not item or not item.marketData then
        return false
    end

    if not category then
        category = MarketCategory.All
    end
    if item.marketData.category ~= category and category ~= MarketCategory.All then
        return false
    end

    if depotFilter:isChecked() and Market.getDepotCount(item) <= 0 then
        return false
    end
    if searchFilter and not item.marketData.name:lower():find(searchFilter, 1, true) then
        return false
    end
    return true
end

local function clearItems()
    currentItems = {}
    Market.refreshItemsWidget()
end

local function clearOffers()
    marketOffers[MarketAction.Buy] = {}
    marketOffers[MarketAction.Sell] = {}
    buyOfferTable:clearData()
    sellOfferTable:clearData()
end

local function clearMyOffers()
    marketOffers[MarketAction.Buy] = {}
    marketOffers[MarketAction.Sell] = {}
    buyMyOfferTable:clearData()
    sellMyOfferTable:clearData()
end

local function clearMyHistory()
    marketOffers[MarketAction.Buy] = {}
    marketOffers[MarketAction.Sell] = {}
    buyMyHistoryTable:clearData()
    sellMyHistoryTable:clearData()
end
local function clearFee()
    feeLabel:setText('')
    fee = 20
end

local function refreshTypeList()
    offerTypeList:clearOptions()
    offerTypeList:addOption('Buy')

    if Market.isItemSelected() then
        if Market.getDepotCount(selectedItem.item) > 0 then
            offerTypeList:addOption('Sell')
        end
    end
end

local function addOffer(offer, offerType)
    if not offer then
        return false
    end
    local id = offer:getId()
    local player = offer:getPlayer()
    local amount = offer:getAmount()
    local price = offer:getPrice()
    local timestamp = offer:getTimeStamp()
    local itemName = offer:getItem():getMarketData().name
    local action = offer:getState()

    buyOfferTable:toggleSorting(false)
    sellOfferTable:toggleSorting(false)

    buyMyOfferTable:toggleSorting(false)
    sellMyOfferTable:toggleSorting(false)

    buyMyHistoryTable:toggleSorting(false)
    sellMyHistoryTable:toggleSorting(false)

    if amount < 1 then
        return false
    end
    if offerType == MarketAction.Buy then
        if offer.warn then
            buyOfferTable:setColumnStyle('OfferTableWarningColumn', true)
        end

        local row = nil
        if offer.var == MarketRequest.MyOffers or offer.var == MarketRequest.OldMyOffers then
            row = buyMyOfferTable:addRow({{
                text = itemName
            }, {
                text = price * amount
            }, {
                text = price
            }, {
                text = amount
            }, {
                text = string.gsub(os.date('%c', timestamp), ' ', '  '),
                sortvalue = timestamp
            }})
        elseif offer.var == MarketRequest.MyHistory or offer.var == MarketRequest.OldMyHistory then
            row = buyMyHistoryTable:addRow({{
                text = itemName
            }, {
                text = price * amount
            }, {
                text = price
            }, {
                text = amount
            }, {
                text = MarketOfferStateString[action],
                sortvalue = timestamp
            }})
        else
            row = buyOfferTable:addRow({{
                text = player
            }, {
                text = amount
            }, {
                text = price * amount
            }, {
                text = price
            }, {
                text = string.gsub(os.date('%c', timestamp), ' ', '  ')
            }})
        end
        row.ref = id

        if offer.warn then
            row:setTooltip(tr('This offer is 25%% below the average market price'))
            buyOfferTable:setColumnStyle('OfferTableColumn', true)
        end
    else
        if offer.warn then
            sellOfferTable:setColumnStyle('OfferTableWarningColumn', true)
        end

        local row = nil
        if offer.var == MarketRequest.MyOffers or offer.var == MarketRequest.OldMyOffers then
            row = sellMyOfferTable:addRow({{
                text = itemName
            }, {
                text = price * amount
            }, {
                text = price
            }, {
                text = amount
            }, {
                text = string.gsub(os.date('%c', timestamp), ' ', '  '),
                sortvalue = timestamp
            }})
        elseif offer.var == MarketRequest.MyHistory or offer.var == MarketRequest.OldMyHistory then
            row = sellMyHistoryTable:addRow({{
                text = itemName
            }, {
                text = price * amount
            }, {
                text = price
            }, {
                text = amount
            }, {
                text = MarketOfferStateString[action],
                sortvalue = timestamp
            }})
        else
            row = sellOfferTable:addRow({{
                text = player
            }, {
                text = amount
            }, {
                text = price * amount
            }, {
                text = price
            }, {
                text = string.gsub(os.date('%c', timestamp), ' ', '  '),
                sortvalue = timestamp
            }})
        end
        row.ref = id

        if offer.warn then
            row:setTooltip(tr('This offer is 25%% above the average market price'))
            sellOfferTable:setColumnStyle('OfferTableColumn', true)
        end
    end

    buyOfferTable:toggleSorting(false)
    sellOfferTable:toggleSorting(false)
    buyOfferTable:sort()
    sellOfferTable:sort()

    buyMyOfferTable:toggleSorting(false)
    sellMyOfferTable:toggleSorting(false)
    buyMyOfferTable:sort()
    sellMyOfferTable:sort()

    buyMyHistoryTable:toggleSorting(false)
    sellMyHistoryTable:toggleSorting(false)
    buyMyHistoryTable:sort()
    sellMyHistoryTable:sort()

    return true
end

local function mergeOffer(offer)
    if not offer then
        return false
    end

    local id = offer:getId()
    local offerType = offer:getType()
    local amount = offer:getAmount()
    local replaced = false

    if offerType == MarketAction.Buy then
        if averagePrice > 0 then
            offer.warn = offer:getPrice() <= averagePrice - math.floor(averagePrice / 4)
        end

        for i = 1, #marketOffers[MarketAction.Buy] do
            local o = marketOffers[MarketAction.Buy][i]
            -- replace existing offer
            if o:isEqual(id) then
                marketOffers[MarketAction.Buy][i] = offer
                replaced = true
            end
        end
        if not replaced then
            table.insert(marketOffers[MarketAction.Buy], offer)
        end
    else
        if averagePrice > 0 then
            offer.warn = offer:getPrice() >= averagePrice + math.floor(averagePrice / 4)
        end

        for i = 1, #marketOffers[MarketAction.Sell] do
            local o = marketOffers[MarketAction.Sell][i]
            -- replace existing offer
            if o:isEqual(id) then
                marketOffers[MarketAction.Sell][i] = offer
                replaced = true
            end
        end
        if not replaced then
            table.insert(marketOffers[MarketAction.Sell], offer)
        end
    end
    return true
end

local function updateOffers(offers)
    if not buyOfferTable or not sellOfferTable then
        return
    end

    balanceLabel:setColor('#bbbbbb')
    selectedOffer[MarketAction.Buy] = nil
    selectedOffer[MarketAction.Sell] = nil

    selectedMyOffer[MarketAction.Buy] = nil
    selectedMyOffer[MarketAction.Sell] = nil

    -- clear existing offer data
    buyOfferTable:clearData()
    buyOfferTable:setSorting(4, TABLE_SORTING_DESC)
    sellOfferTable:clearData()
    sellOfferTable:setSorting(4, TABLE_SORTING_ASC)

    sellButton:setEnabled(false)
    buyButton:setEnabled(false)

    buyCancelButton:setEnabled(false)
    sellCancelButton:setEnabled(false)
    for _, offer in pairs(offers) do
        mergeOffer(offer)
    end
    for type, offers in pairs(marketOffers) do
        for i = 1, #offers do
            addOffer(offers[i], type)
        end
    end
end

local function updateDetails(itemId, descriptions, purchaseStats, saleStats)
    local purchaseOfferStatistic = {}
    local saleOfferStatistic = {}
    if not selectedItem then
        return
    end

    -- update item details
    detailsTable:clearData()
    for k, desc in pairs(descriptions) do
        local columns = {{
            text = getMarketDescriptionName(k) .. ':'
        }, {
            text = desc
        }}
        detailsTable:addRow(columns)
    end

    if not table.empty(saleStats) then
        for i = 1, #purchaseStats do
            table.insert(saleOfferStatistic, OfferStatistic.new(saleStats[i][1], saleStats[i][2], saleStats[i][3], saleStats[i][4], saleStats[i][5], saleStats[i][6]))
        end
    end
    if not table.empty(purchaseStats) then
        for i = 1, #purchaseStats do
            table.insert(purchaseOfferStatistic, OfferStatistic.new(purchaseStats[i][1], purchaseStats[i][2], purchaseStats[i][3], purchaseStats[i][4], purchaseStats[i][5], purchaseStats[i][6]))
        end
    end
    
    -- update sale item statistics
    sellStatsTable:clearData()
    if table.empty(saleStats) then
        sellStatsTable:addRow({{
            text = 'No information'
        }})
    else
        local offerAmount = 0
        local transactions, totalPrice, highestPrice, lowestPrice = 0, 0, 0, 0
        for _, stat in pairs(saleOfferStatistic) do
            if not stat:isNull() then
                offerAmount = offerAmount + 1
                transactions = transactions + stat:getTransactions()
                totalPrice = totalPrice + stat:getTotalPrice()
                local newHigh = stat:getHighestPrice()
                if newHigh > highestPrice then
                    highestPrice = newHigh
                end
                local newLow = stat:getLowestPrice()
                -- ?? getting '0xffffffff' result from lowest price in 9.60 cipsoft
                if (lowestPrice == 0 or newLow < lowestPrice) and newLow ~= 0xffffffff then
                    lowestPrice = newLow
                end
            end
        end

        if offerAmount >= 5 and transactions >= 10 then
            averagePrice = math.round(totalPrice / transactions)
        else
            averagePrice = 0
        end

        sellStatsTable:addRow({{
            text = 'Total Transations:'
        }, {
            text = transactions
        }})
        sellStatsTable:addRow({{
            text = 'Highest Price:'
        }, {
            text = highestPrice
        }})

        if totalPrice > 0 and transactions > 0 then
            sellStatsTable:addRow({{
                text = 'Average Price:'
            }, {
                text = math.floor(totalPrice / transactions)
            }})
        else
            sellStatsTable:addRow({{
                text = 'Average Price:'
            }, {
                text = 0
            }})
        end

        sellStatsTable:addRow({{
            text = 'Lowest Price:'
        }, {
            text = lowestPrice
        }})
    end

    -- update buy item statistics
    buyStatsTable:clearData()
    if table.empty(purchaseOfferStatistic) then
        buyStatsTable:addRow({{
            text = 'No information'
        }})
    else
        local transactions, totalPrice, highestPrice, lowestPrice = 0, 0, 0, 0
        for _, stat in pairs(purchaseOfferStatistic) do
            if not stat:isNull() then
                transactions = transactions + stat:getTransactions()
                totalPrice = totalPrice + stat:getTotalPrice()
                local newHigh = stat:getHighestPrice()
                if newHigh > highestPrice then
                    highestPrice = newHigh
                end
                local newLow = stat:getLowestPrice()
                -- ?? getting '0xffffffff' result from lowest price in 9.60 cipsoft
                if (lowestPrice == 0 or newLow < lowestPrice) and newLow ~= 0xffffffff then
                    lowestPrice = newLow
                end
            end
        end

        buyStatsTable:addRow({{
            text = 'Total Transations:'
        }, {
            text = transactions
        }})
        buyStatsTable:addRow({{
            text = 'Highest Price:'
        }, {
            text = highestPrice
        }})

        if totalPrice > 0 and transactions > 0 then
            buyStatsTable:addRow({{
                text = 'Average Price:'
            }, {
                text = math.floor(totalPrice / transactions)
            }})
        else
            buyStatsTable:addRow({{
                text = 'Average Price:'
            }, {
                text = 0
            }})
        end

        buyStatsTable:addRow({{
            text = 'Lowest Price:'
        }, {
            text = lowestPrice
        }})
    end
end

local function updateSelectedItem(widget)
    selectedItem.item = widget.item
    selectedItem.ref = widget

    Market.resetCreateOffer()
    if Market.isItemSelected() then
        selectedItem:setItem(selectedItem.item.displayItem)
        nameLabel:setText(selectedItem.item.marketData.name)
        clearOffers()

        Market.enableCreateOffer(true) -- update offer types
        MarketProtocol.sendMarketBrowse(MarketRequest.BrowseItem, getPrimaryMarketItemId(selectedItem.item, true), selectedItem.item.tier) -- send browsed msg
    else
        Market.clearSelectedItem()
    end
end

local function updateBalance(balance)
    local balance = tonumber(balance)
    if not balance then
        return
    end

    if balance < 0 then
        balance = 0
    end
    information.balance = balance

    balanceLabel:setText('Balance: ' .. balance .. ' gold')
    balanceLabel:resizeToText()
end

local function updateFee(price, amount)
    fee = math.ceil(price / 100 * amount)
    if fee < 20 then
        fee = 20
    elseif fee > 1000 then
        fee = 1000
    end
    feeLabel:setText('Fee: ' .. fee)
    feeLabel:resizeToText()
end

local function destroyAmountWindow()
    if amountWindow then
        amountWindow:destroy()
        amountWindow = nil
    end
end

local function cancelMyOffer(actionType)
    local offer = selectedMyOffer[actionType]
    g_game.cancelMarketOffer(offer:getTimeStamp(), offer:getCounter())
    Market.refreshMyOffers()
end

local function openAmountWindow(callback, actionType, actionText)
    if not Market.isOfferSelected(actionType) then
        return
    end

    amountWindow = g_ui.createWidget('AmountWindow', rootWidget)
    amountWindow:lock()

    local offer = selectedOffer[actionType]
    local item = offer:getItem()

    local maximum = offer:getAmount()
    if actionType == MarketAction.Sell then
        local depot = Market.getDepotCount(selectedItem.item)
        if maximum > depot then
            maximum = depot
        end
    else
        maximum = math.min(maximum, math.floor(information.balance / offer:getPrice()))
    end

    if item:isStackable() then
        maximum = math.min(maximum, MarketMaxAmountStackable)
    else
        maximum = math.min(maximum, MarketMaxAmount)
    end

    local itembox = amountWindow:getChildById('item')
    itembox:setItemId(item:getId())

    local scrollbar = amountWindow:getChildById('amountScrollBar')
    scrollbar:setText(offer:getPrice() .. 'gp')

    scrollbar.onValueChange = function(widget, value)
        widget:setText((value * offer:getPrice()) .. 'gp')
        itembox:setText(value)
    end

    scrollbar:setRange(1, maximum)
    scrollbar:setValue(1)

    local okButton = amountWindow:getChildById('buttonOk')
    if actionText then
        okButton:setText(actionText)
    end

    local okFunc = function()
        local counter = offer:getCounter()
        local timestamp = offer:getTimeStamp()
        callback(scrollbar:getValue(), timestamp, counter)
        destroyAmountWindow()
    end

    local cancelButton = amountWindow:getChildById('buttonCancel')
    local cancelFunc = function()
        destroyAmountWindow()
    end

    amountWindow.onEnter = okFunc
    amountWindow.onEscape = cancelFunc

    okButton.onClick = okFunc
    cancelButton.onClick = cancelFunc
end

local function onSelectSellOffer(table, selectedRow, previousSelectedRow)
    updateBalance()
    for _, offer in pairs(marketOffers[MarketAction.Sell]) do
        if offer:isEqual(selectedRow.ref) then
            selectedOffer[MarketAction.Buy] = offer
        end
    end

    local offer = selectedOffer[MarketAction.Buy]
    if offer then
        local price = offer:getPrice()
        if price > information.balance then
            balanceLabel:setColor('#b22222') -- red
            buyButton:setEnabled(false)
        else
            local slice = (information.balance / 2)
            if (price / slice) * 100 <= 40 then
                color = '#008b00' -- green
            elseif (price / slice) * 100 <= 70 then
                color = '#eec900' -- yellow
            else
                color = '#ee9a00' -- orange
            end
            balanceLabel:setColor(color)
            buyButton:setEnabled(true)
        end
    end
end

local function onSelectBuyOffer(table, selectedRow, previousSelectedRow)
    updateBalance()
    for _, offer in pairs(marketOffers[MarketAction.Buy]) do
        if offer:isEqual(selectedRow.ref) then
            selectedOffer[MarketAction.Sell] = offer
            if Market.getDepotCount(selectedItem.item) > 0 then
                sellButton:setEnabled(true)
            else
                sellButton:setEnabled(false)
            end
        end
    end
end

local function onSelectMyBuyOffer(table, selectedRow, previousSelectedRow)
    for _, offer in pairs(marketOffers[MarketAction.Buy]) do
        if offer:isEqual(selectedRow.ref) then
            selectedMyOffer[MarketAction.Buy] = offer
            buyCancelButton:setEnabled(true)
        end
    end
end

local function onSelectMySellOffer(table, selectedRow, previousSelectedRow)
    for _, offer in pairs(marketOffers[MarketAction.Sell]) do
        if offer:isEqual(selectedRow.ref) then
            selectedMyOffer[MarketAction.Sell] = offer
            sellCancelButton:setEnabled(true)
        end
    end
end

local function onChangeFilter(combobox, option)
    local selectedTier = tierList:getCurrentOption()
    g_logger.info('[MarketTier] filter changed: tier=' .. tostring(selectedTier and selectedTier.data) .. ', options=' .. #tierList.options)
    Market.updateCurrentItems()
end

local function ensureTierFilterOptions()
    g_logger.info('[MarketTier] ensure options: capability=' .. tostring(MarketProtocol.hasTierCapability()) .. ', current options=' .. tostring(tierList and #tierList.options or 0))
    if not tierList or not MarketProtocol.hasTierCapability() or #tierList.options > 1 then
        return
    end

    for tier, name in ipairs({'Normal', 'Solid', 'Superior', 'Epic', 'Legendary'}) do
        tierList:addOption(tr('Tier %d - %s', tier, name), tier)
    end
end

local function onChangeOfferType(combobox, option)
    local item = selectedItem.item
    local maximum = item.thingType:isStackable() and MarketMaxAmountStackable or MarketMaxAmount

    if option == 'Sell' then
        maximum = math.min(maximum, Market.getDepotCount(item))
        amountEdit:setMaximum(maximum)
    else
        amountEdit:setMaximum(maximum)
    end
end

local function onTotalPriceChange()
    local amount = amountEdit:getValue()
    local totalPrice = totalPriceEdit:getValue()
    local piecePrice = math.floor(totalPrice / amount)

    piecePriceEdit:setValue(piecePrice, true)
    if Market.isItemSelected() then
        updateFee(piecePrice, amount)
    end
end

local function onPiecePriceChange()
    local amount = amountEdit:getValue()
    local totalPrice = totalPriceEdit:getValue()
    local piecePrice = piecePriceEdit:getValue()

    totalPriceEdit:setValue(piecePrice * amount, true)
    if Market.isItemSelected() then
        updateFee(piecePrice, amount)
    end
end

local function onAmountChange()
    local amount = amountEdit:getValue()
    local piecePrice = piecePriceEdit:getValue()
    local totalPrice = piecePrice * amount

    totalPriceEdit:setValue(piecePrice * amount, true)
    if Market.isItemSelected() then
        updateFee(piecePrice, amount)
    end
end

local function onMarketMessage(messageMode, message)
    Market.displayMessage(message)
end

local function initMarketItems()
    for c = MarketCategory.First, MarketCategory.Last do
        marketItems[c] = {}
    end

    -- save a list of items which are already added
    local itemSet = {}

    -- populate all market items
    local types = g_things.findThingTypeByAttr(ThingAttrMarket, 0)
    for i = 1, #types do
        local itemType = types[i]

        local item = Item.create(itemType:getId())
        if item then
            local marketData = itemType:getMarketData()
            local marketItemId = tonumber(marketData.tradeAs)
            if not marketItemId or marketItemId <= 0 then
                marketItemId = itemType:getId()
            end
            local existingMarketItem = itemSet[marketItemId]
            local isCanonicalItem = tonumber(itemType:getId()) == marketItemId
            if not table.empty(marketData) and (not existingMarketItem or (isCanonicalItem and not existingMarketItem.isCanonical)) then
                -- Some items use a different sprite in Market
                item:setId(marketData.showAs)

                -- create new marketItem block
                local marketItem = {
                    displayItem = item,
                    thingType = itemType,
                    marketData = marketData
                }

                -- add new market item
                if not marketItems[marketData.category] then
                    marketItems[marketData.category] = {}
                end

                if existingMarketItem then
                    table.removevalue(marketItems[existingMarketItem.category], existingMarketItem.item)
                end
                table.insert(marketItems[marketData.category], marketItem)
                itemSet[marketItemId] = {
                    category = marketData.category,
                    item = marketItem,
                    isCanonical = isCanonicalItem
                }
            end
        end
    end
end

local function initInterface()
    -- TODO: clean this up
    -- setup main tabs
    mainTabBar = marketWindow:getChildById('mainTabBar')
    mainTabBar:setContentWidget(marketWindow:getChildById('mainTabContent'))

    -- setup 'Market Offer' section tabs
    marketOffersPanel = g_ui.loadUI('ui/marketoffers')
    g_mouse.bindPress(mainTabBar:addTab(tr('Market Offers'), marketOffersPanel), function()
        lastKnownTab = 'market offers'
        if os.time() > refreshTimeout + 1 then
            refreshTimeout = os.time()
            Market.refreshOffers()
        else
            if updateEvent then
                removeEvent(updateEvent)
                updateEvent = nil
            end
            updateEvent = scheduleEvent(function()
                Market.refreshMyOffers()
                refreshTimeout = os.time()
            end, 500)
        end
    end, MouseLeftButton)

    selectionTabBar = marketOffersPanel:getChildById('leftTabBar')
    selectionTabBar:setContentWidget(marketOffersPanel:getChildById('leftTabContent'))

    browsePanel = g_ui.loadUI('ui/marketoffers/browse')
    selectionTabBar:addTab(tr('Browse'), browsePanel)

    -- Currently not used
    -- "Reserved for more functionality later"
    -- overviewPanel = g_ui.loadUI('ui/marketoffers/overview')
    -- selectionTabBar:addTab(tr('Overview'), overviewPanel)

    displaysTabBar = marketOffersPanel:getChildById('rightTabBar')
    displaysTabBar:setContentWidget(marketOffersPanel:getChildById('rightTabContent'))

    itemStatsPanel = g_ui.loadUI('ui/marketoffers/itemstats')
    displaysTabBar:addTab(tr('Statistics'), itemStatsPanel)

    itemDetailsPanel = g_ui.loadUI('ui/marketoffers/itemdetails')
    displaysTabBar:addTab(tr('Details'), itemDetailsPanel)

    itemOffersPanel = g_ui.loadUI('ui/marketoffers/itemoffers')
    displaysTabBar:addTab(tr('Offers'), itemOffersPanel)
    displaysTabBar:selectTab(displaysTabBar:getTab(tr('Offers')))

    -- setup 'My Offer' section tabs
    myOffersPanel = g_ui.loadUI('ui/myoffers')
    g_mouse.bindPress(mainTabBar:addTab(tr('My Offers'), myOffersPanel), function()
        lastKnownTab = lastOfferTab ~= nil and lastOfferTab or 'current offers'
        if os.time() > refreshTimeout + 1 then
            refreshTimeout = os.time()
            Market.refreshMyOffers()
        else
            if updateEvent then
                removeEvent(updateEvent)
                updateEvent = nil
            end
            updateEvent = scheduleEvent(function()
                Market.refreshMyOffers()
                refreshTimeout = os.time()
            end, 500)
        end
    end, MouseLeftButton)

    activeOffersPanel = g_ui.loadUI('ui/activeoffers')
    g_mouse.bindPress(mainTabBar:addTab(tr('Active Offers'), activeOffersPanel), function()
        lastKnownTab = 'active offers'
        Market.refreshActiveOffers()
    end, MouseLeftButton)
    activeOffersTable = activeOffersPanel:getChildById('activeOffersTable')
    activeOffersTable.onSelectionChange = function(widget, row)
        selectedActiveOffer = row and row.offer or nil
        activeOffersPanel:getChildById('buyOfferButton'):setEnabled(selectedActiveOffer ~= nil and selectedActiveOffer:getType() == MarketAction.Sell)
    end
    activeOffersPanel:getChildById('buyOfferButton').onClick = function()
        if not selectedActiveOffer then return end
        local action = selectedActiveOffer:getType() == MarketAction.Sell and MarketAction.Buy or MarketAction.Sell
        selectedOffer[action] = selectedActiveOffer
        openAmountWindow(Market.acceptMarketOffer, action, action == MarketAction.Buy and 'Buy' or 'Sell')
    end
    activeOffersPanel:getChildById('refreshActiveOffersButton').onClick = Market.refreshActiveOffers

    offersTabBar = myOffersPanel:getChildById('offersTabBar')
    offersTabBar:setContentWidget(myOffersPanel:getChildById('offersTabContent'))

    currentOffersPanel = g_ui.loadUI('ui/myoffers/currentoffers')
    g_mouse.bindPress(offersTabBar:addTab(tr('Current Offers'), currentOffersPanel), function()
        lastKnownTab, lastOfferTab = 'current offers'
        if os.time() > refreshTimeout + 1 then
            refreshTimeout = os.time()
            Market.refreshMyOffers()
        else
            if updateEvent then
                removeEvent(updateEvent)
                updateEvent = nil
            end
            updateEvent = scheduleEvent(function()
                Market.refreshMyOffers()
                refreshTimeout = os.time()
            end, 500)
        end
    end, MouseLeftButton)

    offerHistoryPanel = g_ui.loadUI('ui/myoffers/offerhistory')
    g_mouse.bindPress(offersTabBar:addTab(tr('Offer History'), offerHistoryPanel), function()
        lastKnownTab, lastOfferTab = 'offer history'
        if os.time() > refreshTimeout + 1 then
            refreshTimeout = os.time()
            Market.refreshMyOffers()
        else
            if updateEvent then
                removeEvent(updateEvent)
                updateEvent = nil
            end
            updateEvent = scheduleEvent(function()
                Market.refreshOfferHistory()
                refreshTimeout = os.time()
            end, 500)
        end
    end, MouseLeftButton)

    balanceLabel = marketWindow:getChildById('balanceLabel')

    -- setup offers
    buyButton = itemOffersPanel:getChildById('buyButton')
    buyButton.onClick = function()
        openAmountWindow(Market.acceptMarketOffer, MarketAction.Buy, 'Buy')
    end

    sellButton = itemOffersPanel:getChildById('sellButton')
    sellButton.onClick = function()
        openAmountWindow(Market.acceptMarketOffer, MarketAction.Sell, 'Sell')
    end

    -- setup selected item
    nameLabel = marketOffersPanel:getChildById('nameLabel')
    selectedItem = marketOffersPanel:getChildById('selectedItem')

    -- setup create new offer
    totalPriceEdit = marketOffersPanel:getChildById('totalPriceEdit')
    piecePriceEdit = marketOffersPanel:getChildById('piecePriceEdit')
    amountEdit = marketOffersPanel:getChildById('amountEdit')
    feeLabel = marketOffersPanel:getChildById('feeLabel')
    totalPriceEdit.onValueChange = onTotalPriceChange
    piecePriceEdit.onValueChange = onPiecePriceChange
    amountEdit.onValueChange = onAmountChange

    offerTypeList = marketOffersPanel:getChildById('offerTypeComboBox')
    offerTypeList.onOptionChange = onChangeOfferType

    anonymous = marketOffersPanel:getChildById('anonymousCheckBox')
    createOfferButton = marketOffersPanel:getChildById('createOfferButton')
    createOfferButton.onClick = Market.createNewOffer
    Market.enableCreateOffer(false)

    -- setup filters
    depotFilter = browsePanel:getChildById('filterDepot')
    depotFilter.onCheckChange = Market.updateCurrentItems
    categoryList = browsePanel:getChildById('categoryComboBox')
    tierList = browsePanel:getChildById('tierComboBox')
    searchEdit = browsePanel:getChildById('searchEdit')
    searchAllFilter = browsePanel:getChildById('filterSearchAll')
    searchAllFilter:setChecked(searchAllFilter.default)
    for _, category in ipairs(MarketItemCategories) do
        categoryList:addOption(MarketCategoryDisplayNames[category.id] or category.name, category.id)
    end
    tierList:addOption(tr('All'), 0)
    ensureTierFilterOptions()

    categoryList.onOptionChange = onChangeFilter
    tierList.onOptionChange = onChangeFilter
    local function updateSearchAllButton(widget, checked)
        widget:getChildById('searchAllEnabledIcon'):setVisible(checked)
        widget:getChildById('searchCurrentCategoryIcon'):setVisible(not checked)
    end
    searchAllFilter.onCheckChange = function(widget, checked)
        updateSearchAllButton(widget, checked)
    end
    searchAllFilter.onClick = function(widget)
        widget:setChecked(not widget:isChecked())
        updateSearchAllButton(widget, widget:isChecked())
        Market.updateCurrentItems()
    end
    updateSearchAllButton(searchAllFilter, searchAllFilter:isChecked())

    -- setup tables
    buyOfferTable = itemOffersPanel:recursiveGetChildById('buyingTable')
    sellOfferTable = itemOffersPanel:recursiveGetChildById('sellingTable')
    detailsTable = itemDetailsPanel:recursiveGetChildById('detailsTable')
    buyStatsTable = itemStatsPanel:recursiveGetChildById('buyStatsTable')
    sellStatsTable = itemStatsPanel:recursiveGetChildById('sellStatsTable')
    buyOfferTable.onSelectionChange = onSelectBuyOffer
    sellOfferTable.onSelectionChange = onSelectSellOffer

    -- setup my offers
    buyMyOfferTable = currentOffersPanel:recursiveGetChildById('myBuyingTable')
    sellMyOfferTable = currentOffersPanel:recursiveGetChildById('mySellingTable')
    buyMyOfferTable.onSelectionChange = onSelectMyBuyOffer
    sellMyOfferTable.onSelectionChange = onSelectMySellOffer

    buyCancelButton = currentOffersPanel:getChildById('buyCancelButton')
    buyCancelButton.onClick = function()
        cancelMyOffer(MarketAction.Buy)
    end

    sellCancelButton = currentOffersPanel:getChildById('sellCancelButton')
    sellCancelButton.onClick = function()
        cancelMyOffer(MarketAction.Sell)
    end

    buyStatsTable:setColumnWidth({120, 270})
    sellStatsTable:setColumnWidth({120, 270})
    detailsTable:setColumnWidth({80, 330})

    buyOfferTable:setSorting(4, TABLE_SORTING_DESC)
    sellOfferTable:setSorting(4, TABLE_SORTING_ASC)

    buyMyOfferTable:setSorting(3, TABLE_SORTING_DESC)
    sellMyOfferTable:setSorting(3, TABLE_SORTING_DESC)

    -- setup my history
    buyMyHistoryTable = offerHistoryPanel:recursiveGetChildById('myHistoryBuyingTable')
    sellMyHistoryTable = offerHistoryPanel:recursiveGetChildById('myHistorySellingTable')

    buyMyHistoryTable:setSorting(3, TABLE_SORTING_DESC)
    sellMyHistoryTable:setSorting(3, TABLE_SORTING_DESC)
end

function init()
    g_ui.importStyle('market')
    g_ui.importStyle('ui/general/markettabs')
    g_ui.importStyle('ui/general/marketbuttons')
    g_ui.importStyle('ui/general/marketcombobox')
    g_ui.importStyle('ui/general/amountwindow')

    offerExhaust[MarketAction.Sell] = 10
    offerExhaust[MarketAction.Buy] = 20

    registerMessageMode(MessageModes.Market, onMarketMessage)

    protocol.initProtocol()
    ProtocolGame.registerExtendedOpcode(MARKET_ERROR_OPCODE, onMarketError)
    connect(g_game, {
        onGameEnd = Market.reset,
        onMarketEnter = Market.onMarketEnter,
        onMarketBrowse = Market.onMarketBrowse,
        onMarketActiveOffers = Market.onMarketActiveOffers,
        onMarketDetail = Market.onMarketDetail,
        onMarketReadOffer = Market.onMarketReadOffer,
        onMarketLeave = Market.onMarketLeave,
        onResourcesBalanceChange = Market.onResourcesBalanceChange
    })
    connect(g_game, {
        onGameEnd = Market.close
    })
    marketWindow = g_ui.createWidget('MarketWindow', rootWidget)
    marketWindow:hide()

    initInterface() -- build interface
end

function terminate()
    Market.close()

    unregisterMessageMode(MessageModes.Market, onMarketMessage)

    protocol.terminateProtocol()
    pcall(ProtocolGame.unregisterExtendedOpcode, MARKET_ERROR_OPCODE)
    disconnect(g_game, {
        onGameEnd = Market.reset,
        onMarketEnter = Market.onMarketEnter,
        onMarketBrowse = Market.onMarketBrowse,
        onMarketActiveOffers = Market.onMarketActiveOffers,
        onMarketDetail = Market.onMarketDetail,
        onMarketReadOffer = Market.onMarketReadOffer,
        onMarketLeave = Market.onMarketLeave,
        onResourcesBalanceChange = Market.onResourcesBalanceChange
    })
    disconnect(g_game, {
        onGameEnd = Market.close
    })

    destroyAmountWindow()
    marketWindow:destroy()

    Market = nil
end

function Market.reset()
    balanceLabel:setColor('#bbbbbb')
    local firstCategory = MarketItemCategories[1]
    categoryList:setCurrentOption(MarketCategoryDisplayNames[firstCategory.id] or firstCategory.name)
    tierList:setCurrentOption(tr('All'))
    depotFilter:setChecked(depotFilter.default)
    searchEdit:setText('')
    searchAllFilter:setChecked(searchAllFilter.default)
    clearMyOffers()
    if not table.empty(information) then
        Market.updateCurrentItems()
    end
end

function Market.displayMessage(message)
    if marketWindow:isHidden() then
        return
    end

    local infoBox = displayInfoBox(tr('Market Error'), message)
    infoBox:lock()
end

function Market.clearSelectedItem()
    if Market.isItemSelected() then
        Market.resetCreateOffer(true)
        offerTypeList:clearOptions()
        offerTypeList:setText('Please Select')
        offerTypeList:setEnabled(false)

        clearOffers()
        radioItemSet:selectWidget(nil)
        nameLabel:setText('No item selected.')
        selectedItem:setItem(nil)
        selectedItem.item = nil
        selectedItem.ref:setChecked(false)
        selectedItem.ref = nil

        detailsTable:clearData()
        buyStatsTable:clearData()
        sellStatsTable:clearData()

        Market.enableCreateOffer(false)
    end
end

function Market.isItemSelected()
    return selectedItem and selectedItem.item
end

function Market.isOfferSelected(type)
    return selectedOffer[type] and not selectedOffer[type]:isNull()
end

local function getDepotCountById(itemId, tier)
    itemId = tonumber(itemId)
    local entry = itemId and information.depotItems and information.depotItems[itemId]
    if not entry then return 0 end
    if tier then return entry.tiers and entry.tiers[tier] or 0 end
    return entry.itemCount or 0
end

function Market.getDepotCount(itemOrId)
    if type(itemOrId) == 'table' and itemOrId.marketData then
        for _, itemId in ipairs(getMarketItemIds(itemOrId)) do
            local count = getDepotCountById(itemId, itemOrId.tier)
            if count > 0 then
                return count
            end
        end
        return 0
    end

    return getDepotCountById(itemOrId)
end

function Market.enableCreateOffer(enable)
    offerTypeList:setEnabled(enable)
    totalPriceEdit:setEnabled(enable)
    piecePriceEdit:setEnabled(enable)
    amountEdit:setEnabled(enable)
    anonymous:setEnabled(enable)
    createOfferButton:setEnabled(enable)

    local prevAmountButton = marketOffersPanel:recursiveGetChildById('prevAmountButton')
    local nextAmountButton = marketOffersPanel:recursiveGetChildById('nextAmountButton')

    prevAmountButton:setEnabled(enable)
    nextAmountButton:setEnabled(enable)
end

function Market.close(notify)
    if notify == nil then
        notify = true
    end
    if not marketWindow:isHidden() then
        marketWindow:hide()
        modules.game_interface.getRootPanel():focus()
        Market.clearSelectedItem()
        Market.reset()
        if modules.game_inventory and modules.game_inventory.reloadInventory then
            modules.game_inventory.reloadInventory()
        end
        if notify then
            g_game.leaveMarket()
        end
    end
end

function Market.incrementAmount()
    amountEdit:setValue(amountEdit:getValue() + 1)
end

function Market.decrementAmount()
    amountEdit:setValue(amountEdit:getValue() - 1)
end

function Market.updateCurrentItems()
    Market.loadMarketItems(categoryList:getCurrentOption().data)
end

function Market.onMarketTierCapability()
    if not tierList then return end
    tierList:clearOptions()
    tierList:addOption(tr('All'), 0)
    ensureTierFilterOptions()
    tierList:setCurrentOption(tr('All'))
    Market.updateCurrentItems()
end

function Market.resetCreateOffer(resetFee)
    piecePriceEdit:setValue(1)
    totalPriceEdit:setValue(1)
    amountEdit:setValue(1)
    refreshTypeList()

    if resetFee then
        clearFee()
    else
        updateFee(0, 0)
    end
end

function Market.refreshItemsWidget(selectItem)
    local selectItem = selectItem or 0
    itemsPanel = browsePanel:recursiveGetChildById('itemsPanel')

    local layout = itemsPanel:getLayout()
    layout:disableUpdates()

    Market.clearSelectedItem()
    itemsPanel:destroyChildren()

    if radioItemSet then
        radioItemSet:destroy()
    end
    radioItemSet = UIRadioGroup.create()

    local select = nil
    for i = 1, #currentItems do
        local item = currentItems[i]
        local itemBox = g_ui.createWidget('MarketItemBox', itemsPanel)
        itemBox:setWidth(itemsPanel:getWidth())
        itemBox.onCheckChange = Market.onItemBoxChecked
        itemBox.item = item

        if selectItem > 0 and getPrimaryMarketItemId(item, true) == selectItem then
            select = itemBox
            selectItem = 0
        end

        local itemWidget = itemBox:getChildById('item')
        itemWidget:setItem(item.displayItem)
        local itemName = item.marketData.name
        local itemNameLabel = itemBox:getChildById('itemName')
        itemNameLabel:setText(itemName)
        itemNameLabel:setTooltip(itemName)

        local amount = Market.getDepotCount(item)
        if amount > 0 then
            itemWidget:setText(amount)
            itemWidget:setTextOffset(topoint('0 10'))
            itemBox:setTooltip('You have ' .. amount .. ' in your depot.')
        end

        radioItemSet:addWidget(itemBox)
    end

    if select then
        radioItemSet:selectWidget(select, false)
    end

    layout:enableUpdates()
    layout:update()
end

function Market.refreshOffers()
    if (not lastKnownTab or lastKnownTab == 'market offers') and Market.isItemSelected() then
        Market.onItemBoxChecked(selectedItem.ref)
    elseif lastKnownTab == 'active offers' then
        Market.refreshActiveOffers()
    elseif lastKnownTab == 'current offers' then
        Market.refreshMyOffers()
    elseif lastKnownTab == 'offer history' then
        Market.refreshOfferHistory()
    end
end

function Market.refreshMyOffers()
    clearMyOffers()
    MarketProtocol.sendMarketBrowseMyOffers()
end

function Market.refreshOfferHistory()
    clearMyHistory()
    MarketProtocol.sendMarketBrowseOfferHistory()
end

function Market.refreshActiveOffers()
    activeOffers = {}
    selectedActiveOffer = nil
    activeOffersTable:clearData()
    activeOffersPanel:getChildById('buyOfferButton'):setEnabled(false)
    MarketProtocol.sendMarketBrowseAllActive()
end

function Market.loadMarketItems(category)
    ensureTierFilterOptions()
    clearItems()
    local searchFilter = searchEdit:getText():lower()
    if #searchFilter < 3 then searchFilter = nil end
    if searchFilter and searchAllFilter:isChecked() then
        category = MarketCategory.All
    end
    local categories = {}
    if category == MarketCategory.All then
        for itemCategory = MarketCategory.First, MarketCategory.Last do
            categories[#categories + 1] = itemCategory
        end
    elseif category == 1000 then
        categories = {17, 18, 19, 20, 21}
    else
        categories = {category}
    end
    local requestedTier = tierList:getCurrentOption().data
    local tieredItems = 0
    for _, itemCategory in ipairs(categories) do
        for i = 1, #(marketItems[itemCategory] or {}) do
            local item = marketItems[itemCategory][i]
            local itemTier = MarketProtocol.hasTierCapability() and MarketProtocol.getMarketItemTier(item)
            if itemTier then
                tieredItems = tieredItems + 1
                if requestedTier == 0 or requestedTier == itemTier then
                    local variant = table.copy(item)
                    variant.tier = itemTier
                    if isItemValid(variant, itemCategory, searchFilter) then
                        table.insert(currentItems, variant)
                    end
                end
            elseif requestedTier == 0 and isItemValid(item, itemCategory, searchFilter) then
                table.insert(currentItems, item)
            end
        end
    end

    g_logger.info('[MarketTier] loaded category=' .. tostring(category) .. ', capability=' .. tostring(MarketProtocol.hasTierCapability()) .. ', selected tier=' .. tostring(requestedTier) .. ', tiered base items=' .. tieredItems .. ', visible items=' .. #currentItems .. ', filter options=' .. #tierList.options)
    Market.refreshItemsWidget()
end

function Market.createNewOffer()
    local type = offerTypeList:getCurrentOption().text
    if type == 'Sell' then
        type = MarketAction.Sell
    else
        type = MarketAction.Buy
    end

    if not Market.isItemSelected() then
        return
    end

    local spriteId = getPrimaryMarketItemId(selectedItem.item, type == MarketAction.Sell)

    local piecePrice = piecePriceEdit:getValue()
    local amount = amountEdit:getValue()
    local anonymous = anonymous:isChecked() and 1 or 0

    -- error checking
    local errorMsg = ''
    if type == MarketAction.Buy then
        if information.balance < ((piecePrice * amount) + fee) then
            errorMsg = errorMsg .. 'Not enough balance to create this offer.\n'
        end
    elseif type == MarketAction.Sell then
        if information.balance < fee then
            errorMsg = errorMsg .. 'Not enough balance to create this offer.\n'
        end
        if Market.getDepotCount(selectedItem.item) < amount then
            errorMsg = errorMsg .. 'Not enough items in your depot to create this offer.\n'
        end
    end

    if piecePrice > piecePriceEdit.maximum then
        errorMsg = errorMsg .. 'Price is too high.\n'
    elseif piecePrice < piecePriceEdit.minimum then
        errorMsg = errorMsg .. 'Price is too low.\n'
    end

    if amount > amountEdit.maximum then
        errorMsg = errorMsg .. 'Amount is too high.\n'
    elseif amount < amountEdit.minimum then
        errorMsg = errorMsg .. 'Amount is too low.\n'
    end

    if amount * piecePrice > MarketMaxPrice then
        errorMsg = errorMsg .. 'Total price is too high.\n'
    end

    if information.totalOffers >= MarketMaxOffers then
        errorMsg = errorMsg .. 'You cannot create more offers.\n'
    end

    local timeCheck = os.time() - lastCreatedOffer
    if timeCheck < offerExhaust[type] then
        local waitTime = math.ceil(offerExhaust[type] - timeCheck)
        errorMsg = errorMsg .. 'You must wait ' .. waitTime .. ' seconds before creating a new offer.\n'
    end

    if errorMsg ~= '' then
        Market.displayMessage(errorMsg)
        return
    end

    local itemTier = selectedItem.item.tier or 0
    g_game.createMarketOffer(type, spriteId, itemTier, amount, piecePrice, anonymous)
    lastCreatedOffer = os.time()
    Market.resetCreateOffer()
end

function Market.acceptMarketOffer(amount, timestamp, counter)
    if timestamp > 0 and amount > 0 then
        g_game.acceptMarketOffer(timestamp, counter, amount)
        Market.refreshOffers()
    end
end

function Market.onItemBoxChecked(widget)
    if widget:isChecked() then
        updateSelectedItem(widget)
    end
end

-- protocol callback functions

function Market.onMarketEnter(depotItems, offers, balance, vocation)
    g_logger.info('[MarketTier] market entered: capability=' .. tostring(MarketProtocol.hasTierCapability()) .. ', filter options=' .. tostring(tierList and #tierList.options or 0))
    if MarketProtocol.hasTierCapability() then
        Market.onMarketTierCapability()
    end
    if not loaded then
        initMarketItems()
        loaded = true
    end
    if balance == -1 then
        local player = g_game.getLocalPlayer()
        if player then
            updateBalance(player:getTotalMoney())
        end
    else
        updateBalance(balance)
    end
    averagePrice = 0

    information.totalOffers = offers
    local player = g_game.getLocalPlayer()
    if player then
        information.player = player
    end
    if vocation == -1 then
        if player then
            information.vocation = player:getVocation()
        end
    else
        -- vocation must be compatible with < 950
        information.vocation = vocation
    end
    local depotItemsLua = {}
    if type(depotItems) == 'table' and #depotItems >= 1 then
        for i = 1, #depotItems do
            local itemId = depotItems[i][1]
            local count = depotItems[i][2]
            local itClass = depotItems[i][3]
            if MarketProtocol.hasTierCapability() then
                if itemId and count and tonumber(itClass) >= 0 then
                    local entry = depotItemsLua[itemId] or { itemCount = 0, tiers = {} }
                    entry.itemCount = entry.itemCount + count
                    entry.tiers[tonumber(itClass)] = (entry.tiers[tonumber(itClass)] or 0) + count
                    depotItemsLua[itemId] = entry
                end
            else
                if itemId and count then
                    depotItemsLua[itemId] = {
                        itemCount = count
                    }
                end
            end
        end
    end

    -- set list of depot items
    information.depotItems = depotItemsLua

    -- update the items widget to match depot items
    if Market.isItemSelected() then
        local spriteId = getPrimaryMarketItemId(selectedItem.item, true)
        MarketProtocol.silent(true) -- disable protocol messages
        Market.refreshItemsWidget(spriteId)
        MarketProtocol.silent(false) -- enable protocol messages
    else
        Market.refreshItemsWidget()
    end

    if table.empty(currentItems) then
        Market.loadMarketItems(MarketCategory.First)
    end

    if modules.game_inventory and modules.game_inventory.reloadInventory then
        modules.game_inventory.reloadInventory()
    end

    if g_game.isOnline() then
        marketWindow:show()
        marketWindow:raise()
        marketWindow:focus()
    end
end

function Market.onMarketLeave()
    Market.close(false)
end

function Market.onMarketDetail(itemId, descriptions, purchaseStats, saleStats)
    updateDetails(itemId, descriptions, purchaseStats, saleStats)
end

MarketOffers2 = {}

function Market.onMarketBrowse(intOffers, nameOffers)
    local tmpOffers = MarketOffers2
    MarketOffers2 = {}
    updateOffers(tmpOffers)
end

function Market.onMarketActiveOffers(intOffers, nameOffers, total)
    for i, values in ipairs(intOffers) do
        local action, amount, counter, itemId, price, state, timestamp, _, tier, created = unpack(values)
        local item = Item.create(itemId)
        if item and tier and tier > 0 then item:setTier(tier) end
        local offer = MarketOffer.new({timestamp, counter}, action, item, amount, price, nameOffers[i], state, MarketRequest.AllActive)
        table.insert(activeOffers, { offer = offer, created = created })
    end
    if lastKnownTab ~= 'active offers' then return end
    if #activeOffers < total then return end
    activeOffersTable:clearData()
    table.sort(activeOffers, function(a, b) return a.created > b.created end)
    for _, entry in ipairs(activeOffers) do
        local offer = entry.offer
        local name = offer:getItem():getMarketData().name
        local row = activeOffersTable:addRow({
            { text = name }, { text = offer:getPlayer() }, { text = offer:getAmount() },
            { text = offer:getPrice() }, { text = offer:getPrice() * offer:getAmount() },
            { text = os.date('%Y-%m-%d %H:%M', entry.created) }
        })
        row.offer = offer
        row:setTooltip(name .. '\n' .. (offer:getType() == MarketAction.Sell and tr('Click Buy to purchase this offer') or tr('Buy order: use Browse to sell this item')))
    end
end

function Market.onMarketReadOffer(action, amount, counter, itemId, playerName, price, state, timestamp, var, tier)
    local item = Item.create(itemId)
    if item and tier and tier > 0 then item:setTier(tier) end
    table.insert(MarketOffers2, MarketOffer.new({timestamp, counter}, action, item, amount, price,
                                                playerName, state, var))
end

function Market.onResourcesBalanceChange(value, oldBalance, resourceType)
    if resourceType <= 1 then
        local player = g_game.getLocalPlayer()
        if player then
            updateBalance(player:getTotalMoney())
        end
    end
end
