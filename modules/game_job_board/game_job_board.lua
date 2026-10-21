-- Opcode 205 (daily job board): request `accept:<category>`; response JSON has action, open, message and offers with requirements and rewards.
local JOB_BOARD_OPCODE = 205
local categories = { smithing = true, alchemy = true, cooking = true, bowmaster = true }
local window
local offersPanel
local feedbackLabel
local pending = {}

local function displayText(text)
    return utf8ToCp1250(text or '')
end

local function onGameEnd()
    window:hide()
    pending = {}
end

local function isOffer(offer)
    if type(offer) ~= 'table' or not categories[offer.category]
        or type(offer.categoryName) ~= 'string' or type(offer.npcName) ~= 'string'
        or type(offer.name) ~= 'string' or type(offer.description) ~= 'string'
        or type(offer.requirements) ~= 'table' or type(offer.rewards) ~= 'table' then
        return false
    end
    for _, requirement in ipairs(offer.requirements) do
        if type(requirement.name) ~= 'string' or type(requirement.count) ~= 'number' then
            return false
        end
    end
    return true
end

local function renderOffer(offer)
    local card = g_ui.createWidget('JobBoardOffer', offersPanel)
    card:setId(offer.category)
    card:getChildById('npc'):setText(displayText(offer.categoryName .. ' - ' .. offer.npcName))
    card:getChildById('name'):setText(displayText(offer.name))
    local description = card:getChildById('description')
    description:setText(displayText(offer.description))
    local descriptionHeight = math.max(22, description:getTextSize().height)
    description:setHeight(descriptionHeight)

    local requirementLines = {}
    for _, requirement in ipairs(offer.requirements) do
        requirementLines[#requirementLines + 1] = string.format('%s x %d', requirement.name, requirement.count)
    end
    card:getChildById('requirements'):setText(displayText(table.concat(requirementLines, '  •  ')))
    card:getChildById('rewards'):setText(displayText(string.format('Nagroda: %d exp, %d złota',
        tonumber(offer.rewards.experience) or 0, tonumber(offer.rewards.money) or 0)))

    local accept = card:getChildById('accept')
    accept:setText('Przyjmij')
    accept:setEnabled(not pending[offer.category])
    card:setHeight(116 + descriptionHeight - 22)
end

local function onJobBoardOpcode(protocol, opcode, message)
    if type(message) ~= 'table' or message.action ~= 'board' or type(message.offers) ~= 'table'
        or #message.offers > 4 then
        return
    end
    for _, offer in ipairs(message.offers) do
        if not isOffer(offer) then
            return
        end
    end

    pending = {}
    offersPanel:destroyChildren()
    for _, offer in ipairs(message.offers) do
        renderOffer(offer)
    end
    if #message.offers == 0 then
        local emptyLabel = g_ui.createWidget('Label', offersPanel)
        emptyLabel:setText(displayText('Nie ma już wolnych ogłoszeń.'))
        emptyLabel:setColor('#D9C68C')
        emptyLabel:setTextAlign(AlignCenter)
        emptyLabel:setTextWrap(true)
        emptyLabel:setHeight(30)
    end
    feedbackLabel:setText(displayText(message.message))
    feedbackLabel:setVisible(message.message ~= nil and message.message ~= '')
    if message.open ~= false then
        window:show()
        window:raise()
        window:focus()
    end
end

function init()
    window = g_ui.loadUI('/game_job_board/job_board', g_ui.getRootWidget())
    offersPanel = window:getChildById('offers')
    feedbackLabel = window:getChildById('feedback')
    window:setText(displayText('Tablica ogłoszeń'))
    window:getChildById('intro'):setText(displayText('Codzienne zlecenia od mieszkańców kolonii'))
    window:hide()
    ProtocolGame.registerExtendedJSONOpcode(JOB_BOARD_OPCODE, onJobBoardOpcode)
    connect(g_game, { onGameEnd = onGameEnd })
end

function terminate()
    disconnect(g_game, { onGameEnd = onGameEnd })
    pcall(ProtocolGame.unregisterExtendedJSONOpcode, JOB_BOARD_OPCODE)
    if window then
        window:destroy()
        window = nil
    end
    offersPanel = nil
    feedbackLabel = nil
    pending = {}
end

function acceptOffer(category)
    if not categories[category] or pending[category] then
        return
    end
    local protocol = g_game.getProtocolGame()
    if not protocol then
        return
    end
    pending[category] = true
    for _, card in ipairs(offersPanel:getChildren()) do
        if card:getId() == category then
            card:getChildById('accept'):setEnabled(false)
            break
        end
    end
    protocol:sendExtendedOpcode(JOB_BOARD_OPCODE, 'accept:' .. category)
end

function close()
    if window then
        window:hide()
    end
end
