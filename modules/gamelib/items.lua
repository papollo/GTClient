ItemsDatabase = {}

ItemsDatabase.rarityColors = {
    [1] = TextColors.white,
    [2] = TextColors.green,
    [3] = TextColors.blue,
    [4] = TextColors.purple,
    [5] = TextColors.yellow
}

ItemsDatabase.rarityImages = {
    [1] = "/images/ui/rarity_white.png",
    [2] = "/images/ui/rarity_green.png",
    [3] = "/images/ui/rarity_blue.png",
    [4] = "/images/ui/rarity_purple.png",
    [5] = "/images/ui/rarity_yellow.png"
}

ItemsDatabase.cornerClips = {
    [1] = "0 0 32 32",
    [2] = "32 0 32 32",
    [3] = "64 0 32 32",
    [4] = "96 0 32 32",
    [5] = "128 0 32 32"
}

local function clampRarity(rarity)
    rarity = math.floor(rarity or 1)
    if rarity < 1 then
        return 1
    elseif rarity > 5 then
        return 5
    end
    return rarity
end

local function resolveItemRarity(item)
    if not item then
        return 1
    end

    local valueType = type(item)
    if valueType == "number" then
        if item <= 5 then
            return clampRarity(item)
        end

        local thing = g_things.getThingType(item, ThingCategoryItem)
        if thing and thing.getRarity then
            local ok, rarity = pcall(function() return thing:getRarity() end)
            if ok and type(rarity) == "number" then
                return clampRarity(rarity)
            end
        end
        return 1
    end

    local ok, rarity = pcall(function()
        if item.getRarity then
            return item:getRarity()
        end

        if item.getThingType then
            local thingType = item:getThingType()
            if thingType and thingType.getRarity then
                return thingType:getRarity()
            end
        end

        if item.getItemId then
            local itemId = item:getItemId()
            if itemId then
                local thingType = g_things.getThingType(itemId, ThingCategoryItem)
                if thingType and thingType.getRarity then
                    return thingType:getRarity()
                end
            end
        end

        return 1
    end)

    if ok and type(rarity) == "number" then
        return clampRarity(rarity)
    end

    return 1
end

function ItemsDatabase.setRarityItem(widget, item, style)
    if not g_game.getFeature(GameColorizedLootValue) or not widget then
        return
    end
    local frameOption = modules.client_options.getOption('framesRarity') or 'frames'
    if frameOption == "none" then
        widget:setImageClip(nil)
        widget:setImageSource("")
        return
    end
    local rarity = resolveItemRarity(item)
    local imageSource = ItemsDatabase.rarityImages[rarity] or ""

    if frameOption == "corners" then
        widget:setImageSource("/images/ui/containerslot-coloredges")
        local clip = ItemsDatabase.cornerClips[rarity]
        if clip and clip ~= "" then
            widget:setImageClip(clip)
        else
            widget:setImageClip(nil)
        end
    else
        widget:setImageClip(nil)
        widget:setImageSource(imageSource)
    end

    if style then
        widget:setStyle(style)
    end
end

function ItemsDatabase.getColorForRarity(rarity)
    return ItemsDatabase.rarityColors[clampRarity(rarity)] or TextColors.white
end

function ItemsDatabase.setColorLootMessage(text)
    local function coloringLootName(match)
        local id, itemName = match:match("(%d+)|(.+)")
        if not id then
            return match
        end

        local thingType = g_things.getThingType(tonumber(id), ThingCategoryItem)
        if thingType and thingType.getRarity then
            local color = ItemsDatabase.getColorForRarity(thingType:getRarity())
            return "{" .. itemName .. ", " .. color .. "}"
        else
            return itemName
        end
    end
    return text:gsub("{(.-)}", coloringLootName)
end

function ItemsDatabase.setTier(widget, item)
    if not g_game.getFeature(GameThingUpgradeClassification) or not widget then
        return
    end
    local tier = type(item) == "number" and item or (item and item:getTier()) or 0
    if tier and tier > 0 then
        local xOffset = (math.min(math.max(tier, 1), 10) - 1) * 9
        widget.tier:setImageClip({
            x = xOffset,
            y = 0,
            width = 10,
            height = 9
        })
        widget.tier:setVisible(true)
    else
        widget.tier:setVisible(false)
    end
end

function ItemsDatabase.setCharges(widget, item, style)
    if not g_game.getFeature(GameThingCounter) or not widget then
        return
    end

    if item and item:getCharges() > 0 then
        widget.charges:setText(item:getCharges())
    else
        widget.charges:setText("")
    end

    if style then
        widget:setStyle(style)
    end
end


function ItemsDatabase.setDuration(widget, item, style)
    if not g_game.getFeature(GameThingClock) or not widget then
        return
    end

    if item and item:getDurationTime() > 0 then
            local durationTimeLeft = item:getDurationTime()
            widget.duration:setText(string.format("%dm%02d", durationTimeLeft / 60, durationTimeLeft % 60))
    else
        widget.duration:setText("")
    end

    if style then
        widget:setStyle(style)
    end
end
