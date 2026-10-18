MarketProtocol = {}

-- private functions

local silent
local protocol
local marketTierCapability = false
local tieredMarketItemIds = {}
local statistics = runinsandbox('offerstatistic')
local MARKET_TIER_OPCODE = 203
local MARKET_TIER_CAPABILITY = 'market_tiers_v1'

local function onMarketTierCapability(_, opcode, buffer)
    local itemIds = opcode == MARKET_TIER_OPCODE and buffer:match('^' .. MARKET_TIER_CAPABILITY .. ':(.*)$')
    if opcode == MARKET_TIER_OPCODE and (buffer == MARKET_TIER_CAPABILITY or itemIds) then
        marketTierCapability = true
        tieredMarketItemIds = {}
        for id, tier in (itemIds or ''):gmatch('(%d+)=(%d+)') do
            tieredMarketItemIds[tonumber(id)] = tonumber(tier)
        end
    end
end

local function send(msg)
    if protocol and not silent then
        protocol:send(msg)
    end
end

-- public functions
function initProtocol()
    ProtocolGame.registerExtendedOpcode(MARKET_TIER_OPCODE, onMarketTierCapability)
    connect(g_game, {
        onGameStart = MarketProtocol.registerProtocol,
        onGameEnd = MarketProtocol.unregisterProtocol
    })

    -- reloading module
    if g_game.isOnline() then
        MarketProtocol.registerProtocol()
    end

    MarketProtocol.silent(false)
end

function terminateProtocol()
    disconnect(g_game, {
        onGameStart = MarketProtocol.registerProtocol,
        onGameEnd = MarketProtocol.unregisterProtocol
    })

    -- reloading module
    MarketProtocol.unregisterProtocol()
    pcall(ProtocolGame.unregisterExtendedOpcode, MARKET_TIER_OPCODE)
    MarketProtocol = nil
end

function MarketProtocol.updateProtocol(_protocol)
    protocol = _protocol
end

function MarketProtocol.registerProtocol()
    MarketProtocol.updateProtocol(g_game.getProtocolGame())
    marketTierCapability = false
    if protocol then
        protocol:sendExtendedOpcode(MARKET_TIER_OPCODE, MARKET_TIER_CAPABILITY)
    end
end

function MarketProtocol.unregisterProtocol()
    MarketProtocol.updateProtocol(nil)
    marketTierCapability = false
    tieredMarketItemIds = {}
end

function MarketProtocol.hasTierCapability()
    return marketTierCapability
end

function MarketProtocol.getMarketItemTier(item)
    if not item then return nil end
    return item.thingType and tieredMarketItemIds[item.thingType:getId()]
end

function MarketProtocol.silent(mode)
    silent = mode
end

-- sending protocols

function MarketProtocol.sendMarketBrowse(browseId, browseType, itemTier)
    if g_game.getFeature(GamePlayerMarket) then
        local msg = OutputMessage.create()
        msg:addU8(ClientOpcodes.ClientMarketBrowse)
        if g_game.getClientVersion() >= 1251 then
            msg:addU8(browseId)
            if browseType > 0 then
                msg:addU16(browseType)
                if browseId == MarketRequest.BrowseItem and marketTierCapability and itemTier and itemTier > 0 then
                    msg:addU8(itemTier)
                end
            end
        else
            msg:addU16(browseType)
            if browseId == MarketRequest.BrowseItem and marketTierCapability and itemTier and itemTier > 0 then
                msg:addU8(itemTier)
            end
        end
        send(msg)
    else
        g_logger.error('MarketProtocol.sendMarketBrowse does not support the current protocol.')
    end
end

function MarketProtocol.sendMarketBrowseMyOffers()
    if g_game.getClientVersion() >= 1251 then
        MarketProtocol.sendMarketBrowse(MarketRequest.MyOffers, 0)
    else
        MarketProtocol.sendMarketBrowse(0, MarketRequest.OldMyOffers)
    end
end
function MarketProtocol.sendMarketBrowseOfferHistory()
    if g_game.getClientVersion() >= 1251 then
        MarketProtocol.sendMarketBrowse(MarketRequest.MyHistory, 0)
    else
        MarketProtocol.sendMarketBrowse(0, MarketRequest.OldMyHistory)
    end
end

function MarketProtocol.sendMarketBrowseAllActive()
    if g_game.getClientVersion() >= 1251 then
        MarketProtocol.sendMarketBrowse(MarketRequest.AllActive, 0)
    else
        MarketProtocol.sendMarketBrowse(0, MarketRequest.OldAllActive)
    end
end
