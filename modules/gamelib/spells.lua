SpelllistSettings = {
    ['Gothic'] = {
        iconFile = '/images/game/spells/defaultspells',
        iconSize = {
            width = 32,
            height = 32
        },
        spellListWidth = 210,
        spellWindowWidth = 550,
        spellOrder = {
           'Jump - up',
           'Jump - down',
            'Melee - Warrior speed',
            'Melee - Weapon Throw',
            'Melee - Challenge',
            'One Hand - Shockwave',
            'One Hand - Shield',
            'Two Hand - Ground shake',
            'Two Hand - Berserk',
            'Dist - Throw Spear',
            'Dist - Divine spear',
            'Dist - sprint',
            'Bow - Protect',
            'Bow - Stun',
            'Crossbow - Strong Spear',
            'Crossbow - Focus'
        }
    }
}

SpellInfo = {
    ['Gothic'] = {
        ['Jump - up'] = {
            id = 23,
            words = 'jump up',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'levitate',
            mana = 0,
            level = 1,
            soul = 0,
            group = {[3] = 2000},
            parameter = false,
            vocations = {1, 2, 3, 4, 5, 6, 7, 8}
        },
        ['Jump - down'] = {
            id = 24,
            words = 'jump down',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'levitate',
            mana = 0,
            level = 1,
            soul = 0,
            group = {[3] = 2000},
            parameter = false,
            vocations = {1, 2, 3, 4, 5, 6, 7, 8}
        },
        ['Melee - Warrior speed'] = {
            id = 25,
            words = ':run:',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'stronghaste',
            mana = 50,
            level = 0,
            soul = 0,
            group = {[3] = 2000},
            parameter = false,
            vocations = {1, 2, 3, 4, 5, 6, 7, 8}
        },
        ['Melee - Weapon Throw'] = {
            id = 26,
            words = ':throw:',
            exhaustion = 6000,
            premium = false,
            type = 'Instant',
            icon = 'whirlwindthrow',
            mana = 30,
            level = 0,
            soul = 0,
            group = {[1] = 2000},
            parameter = false,
            vocations = {1, 2, 3, 4, 5, 6, 7, 8}
        },
        ['Melee - Challenge'] = {
            id = 27,
            words = ':challenge:',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'challenge',
            mana = 50,
            level = 0,
            soul = 0,
            group = {[3] = 2000},
            parameter = false,
            vocations = {1, 2, 3, 4, 5, 6, 7, 8}
        },
        ['One Hand - Shockwave'] = {
            id = 28,
            words = ':shockwave:',
            exhaustion = 4000,
            premium = false,
            type = 'Instant',
            icon = 'groundshaker',
            mana = 125,
            level = 0,
            soul = 0,
            group = {[1] = 2000},
            parameter = false,
            vocations = {1, 5}
        },
        ['One Hand - Shield'] = {
            id = 29,
            words = ':shield:',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'magicshield',
            mana = 200,
            level = 0,
            soul = 0,
            group = {[3] = 2000},
            parameter = false,
            vocations = {1, 5}
        },
        ['Two Hand - Ground shake'] = {
            id = 30,
            words = ':groundshake:',
            exhaustion = 4000,
            premium = false,
            type = 'Instant',
            icon = 'groundshaker',
            mana = 125,
            level = 0,
            soul = 0,
            group = {[1] = 2000},
            parameter = false,
            vocations = {2, 6}
        },
        ['Two Hand - Berserk'] = {
            id = 31,
            words = ':berserk:',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'berserk',
            mana = 200,
            level = 0,
            soul = 0,
            group = {[3] = 2000},
            parameter = false,
            vocations = {2, 6}
        },
        ['Dist - Throw Spear'] = {
            id = 32,
            words = ':spear:',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'etherealspear',
            mana = 50,
            level = 0,
            soul = 0,
            group = {[1] = 2000},
            parameter = false,
            vocations = {3, 4, 7, 8}
        },
        ['Dist - Divine spear'] = {
            id = 33,
            words = ':divine:',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'divinemissile',
            mana = 75,
            level = 0,
            soul = 0,
            group = {[1] = 2000},
            parameter = false,
            vocations = {3, 4, 7, 8}
        },
        ['Dist - sprint'] = {
            id = 34,
            words = ':sprint:',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'swiftfoot',
            mana = 100,
            level = 0,
            soul = 0,
            group = {[3] = 2000},
            parameter = false,
            vocations = {3, 4, 7, 8}
        },
        ['Bow - Protect'] = {
            id = 35,
            words = ':protect:',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'protector',
            mana = 125,
            level = 0,
            soul = 0,
            group = {[3] = 2000},
            parameter = false,
            vocations = {4, 8}
        },
        ['Bow - Stun'] = {
            id = 36,
            words = ':stun:',
            exhaustion = 40000,
            premium = false,
            type = 'Instant',
            icon = 'paralyze',
            mana = 200,
            level = 0,
            soul = 0,
            group = {[1] = 2000},
            parameter = false,
            vocations = {4, 8}
        },
        ['Crossbow - Strong Spear'] = {
            id = 37,
            words = ':strongspear:',
            exhaustion = 8000,
            premium = false,
            type = 'Instant',
            icon = 'strongetherealspear',
            mana = 125,
            level = 0,
            soul = 0,
            group = {[1] = 2000},
            parameter = false,
            vocations = {3, 7}
        },
        ['Crossbow - Focus'] = {
            id = 38,
            words = ':focus:',
            exhaustion = 2000,
            premium = false,
            type = 'Instant',
            icon = 'sharpshooter',
            mana = 200,
            level = 0,
            soul = 0,
            group = {[3] = 10000},
            parameter = false,
            vocations = {3, 7}
        }
    }
}

-- ['const_name'] =       {client_id, TFS_id}
-- Conversion from TFS icon id to the id used by client (icons.png order)
SpellIcons = {
    ['levitate'] = {125, 81},
    ['stronghaste'] = {102, 39},
    ['whirlwindthrow'] = {19, 107},
    ['challenge'] = {97, 93},
    ['groundshaker'] = {25, 106},
    ['magicshield'] = {124, 44},
    ['berserk'] = {21, 80},
    ['etherealspear'] = {18, 111},
    ['divinemissile'] = {39, 122},
    ['swiftfoot'] = {119, 134},
    ['protector'] = {122, 132},
    ['paralyze'] = {71, 54},
    ['strongetherealspear'] = {59, 57},
    ['sharpshooter'] = {121, 135},
    ['hellscore'] = {49, 24}
}
VocationNames = {
    [0] = 'None',
    [1] = 'Shadow',
    [2] = 'Guard',
    [3] = 'Ore Baron',
    [4] = 'Fire Mage',
    [5] = 'Fire Archmage',
    [6] = 'Elder Druid',
    [7] = 'Royal Paladin',
    [8] = 'Elite Knight'
}

SpellGroups = {
    [1] = 'Attack',
    [2] = 'Healing',
    [3] = 'Support',
    [4] = 'Special',
    [5] = 'Crippling',
    [6] = 'Focus',
    [7] = 'UltimateStrike',
    [8] = 'GreatBeams',
    [9] = 'BurstOfNature'
}

Spells = {}

function Spells.getClientId(spellName)
    local profile = Spells.getSpellProfileByName(spellName)

    local id = SpellInfo[profile][spellName].icon
    if not tonumber(id) and SpellIcons[id] then
        return SpellIcons[id][1]
    end
    return tonumber(id)
end

function Spells.getSpellByClientId(id)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.id == id then
                return spell, profile, k
            end
        end
    end
    return nil
end

function Spells.getServerId(spellName)
    local profile = Spells.getSpellProfileByName(spellName)

    local id = SpellInfo[profile][spellName].icon
    if not tonumber(id) and SpellIcons[id] then
        return SpellIcons[id][2]
    end
    return tonumber(id)
end

function Spells.getSpellByName(name)
    return SpellInfo[Spells.getSpellProfileByName(name)][name]
end

function Spells.getSpellByWords(words)
    local words = words:lower():trim()
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return spell, profile, k
            end
        end
    end
    return nil
end

function Spells.getSpellByIcon(iconId)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.id == iconId then
                return spell, profile, k
            end
        end
    end
    return nil
end

function Spells.getSpellIconIds()
    local ids = {}
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            table.insert(ids, spell.id)
        end
    end
    return ids
end

function Spells.getSpellProfileById(id)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.id == id then
                return profile
            end
        end
    end
    return nil
end

function Spells.getSpellProfileByWords(words)
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if spell.words == words then
                return profile
            end
        end
    end
    return nil
end

function Spells.getSpellProfileByName(spellName)
    for profile, data in pairs(SpellInfo) do
        if table.findbykey(data, spellName:trim(), true) then
            return profile
        end
    end
    return nil
end

function Spells.getSpellsByVocationId(vocId)
    local spells = {}
    for profile, data in pairs(SpellInfo) do
        for k, spell in pairs(data) do
            if table.contains(spell.vocations, vocId) then
                table.insert(spells, spell)
            end
        end
    end
    return spells
end

function Spells.filterSpellsByGroups(spells, groups)
    local filtered = {}
    for v, spell in pairs(spells) do
        local spellGroups = Spells.getGroupIds(spell)
        if table.equals(spellGroups, groups) then
            table.insert(filtered, spell)
        end
    end
    return filtered
end

function Spells.getGroupIds(spell)
    local groups = {}
    for k, _ in pairs(spell.group) do
        table.insert(groups, k)
    end
    return groups
end

function Spells.getImageClip(id, profile)
    return (((id - 1) % 12) * SpelllistSettings[profile].iconSize.width) .. ' ' ..
               ((math.ceil(id / 12) - 1) * SpelllistSettings[profile].iconSize.height) .. ' ' ..
               SpelllistSettings[profile].iconSize.width .. ' ' .. SpelllistSettings[profile].iconSize.height
end

function Spells.getIconFileByProfile(profile)
    return SpelllistSettings[profile]['iconFile']
end


