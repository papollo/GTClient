
function Cyclopedia.formatGold(value)
    local number = tostring(value)
    number = string.reverse(number)
    number = string.gsub(number, "(%d%d%d)", "%1,")
    number = string.reverse(number)

    if string.sub(number, 1, 1) == "," then
        number = string.sub(number, 2)
    end

    return number
end

function Cyclopedia.calculateCombatValues(percent)
    local values = {}
    if percent == 0 then
        values.color = "#AE0F0F"
        values.tooltip = "0% (immune)"
    elseif percent < 100 then
        values.color = "#E4C00A"
        values.tooltip = percent .. "% (strong)"
    elseif percent == 100 then
        values.color = "#FFFFFF"
        values.tooltip = "100% (neutral)"
    else
        values.color = "#18CE18"
        values.tooltip = percent .. "% (weak)"
    end

    if percent > 100 then
        values.margin = 15 + (125 - percent) * 0.28
    else
        values.margin = 22 + (100 - percent) * 0.21
    end

    if values.margin < 0 then
        values.margin = 0
    elseif values.margin > 65 then
        values.margin = 65
    end

    return values
end

function Cyclopedia.formatSaleData(data)
    local s, sell, b, buy = {}, {}, {}, {}

    for i = 1, #data do
        local value = data[i]

        if value then
            if value.salePrice > 0 then
                if s[value.name] and value.name == "Rashid" then
                    s[value.name].various = true
                end

                if not s[value.name] then
                    local formated = {
                        various = false,
                        price = value.salePrice,
                        location = value.location
                    }

                    s[value.name] = formated
                end
            end

            if value.buyPrice > 0 then
                if b[value.name] and value.name == "Rashid" then
                    b[value.name].various = true
                end

                if not b[value.name] then
                    local formated = {
                        various = false,
                        price = value.buyPrice,
                        location = value.location
                    }

                    b[value.name] = formated
                end
            end
        end
    end

    for name, value in pairs(s) do
        if value.various then
            table.insert(sell,
                string.format("%s gp, %s\nResidence: %s", Cyclopedia.formatGold(value.price), name, "Various Locations"))
        else
            table.insert(sell, string.format("%s gp, %s\nResidence: %s", Cyclopedia.formatGold(value.price), name, value.location))
        end
    end

    for name, value in pairs(b) do
        if value.various then
            table.insert(buy,
                string.format("%s gp, %s\nResidence: %s", Cyclopedia.formatGold(value.price), name, "Various Locations"))
        else
            table.insert(buy, string.format("%s gp, %s\nResidence: %s", Cyclopedia.formatGold(value.price), name, value.location))
        end
    end

    return sell, buy
end

function Cyclopedia.compareItems(item1, item2)
    local marketData1 = item1:getMarketData()
    local marketData2 = item2:getMarketData()

    return marketData1.name:lower() < marketData2.name:lower()
end

function Cyclopedia.hasHandedFilter(categoryId)
    local ids = {17, 18, 19, 20, 21, 1000}
    if table.contains(ids, categoryId) then
        return true
    end

    return false
end

function Cyclopedia.hasClassificationFilter(categoryId)
    local ids = {1, 24, 7, 15, 17, 18, 19, 20, 21, 1000}
    if table.contains(ids, categoryId) then
        return true
    end

    return false
end

Cyclopedia.House.Data = {
    {id = 1001, name = "Cozy Cottage", description = "A small, charming house perfect for new adventurers.", rent = 1000, beds = 1, sqm = 25, gh = false, shop = false, visible = true, state = 0, owner = "?", isYourBid = false, hasBid = true, bidEnd = 1628097600, hightestBid = 50000, bidName = "Explorer123", bidHolderLimit = nil, canBid = 1, rented = false, paidUntil = nil, isYourOwner = false, inTransfer = false, transferName = nil, transferTime = 0, transferValue = 0, isTransferOwner = false, canAcceptTransfer = 0},
    {id = 1002, name = "Merchant's Haven", description = "A spacious house with room for a shop.", rent = 5000, beds = 4, sqm = 100, gh = false, shop = true, visible = true, state = 2, owner = "Trader_Joe", isYourBid = false, hasBid = false, bidEnd = nil, hightestBid = nil, bidName = nil, bidHolderLimit = nil, canBid = 0, rented = true, paidUntil = 1630689600, isYourOwner = false, inTransfer = false, transferName = nil, transferTime = 0, transferValue = 0, isTransferOwner = false, canAcceptTransfer = 0}
}

local combatStates= {
	CLIENT_COMBAT_PHYSICAL = 0,
	CLIENT_COMBAT_FIRE = 1,
	CLIENT_COMBAT_EARTH = 2,
	CLIENT_COMBAT_ENERGY = 3,
	CLIENT_COMBAT_ICE = 4,
	CLIENT_COMBAT_HOLY = 5,
	CLIENT_COMBAT_DEATH = 6,
	CLIENT_COMBAT_HEALING = 7,
	CLIENT_COMBAT_DROWN = 8,
	CLIENT_COMBAT_LIFEDRAIN = 9,
	CLIENT_COMBAT_MANADRAIN = 10,
}

Cyclopedia.clientCombat ={}
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_PHYSICAL] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-physical-resist', id = 'Physical' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_FIRE] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-fire-resist', id = 'Fire' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_EARTH] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-earth-resist', id = 'Earth' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_ENERGY] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-energy-resist', id = 'Energy' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_ICE] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-ice-resist', id = 'Ice' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_HOLY] = {path = '/game_cyclopedia/images/bestiary/icons/monster-icon-holy-resist', id = 'Holy' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_DEATH] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-death-resist', id = 'Death' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_HEALING] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-healing-resist', id = 'Healing' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_DROWN] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-drown-resist', id = 'Drown' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_LIFEDRAIN] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-lifedrain-resist', id = 'Lifedrain ' }
Cyclopedia.clientCombat[combatStates.CLIENT_COMBAT_MANADRAIN] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-manadrain-resist', id = 'Manadrain' }
