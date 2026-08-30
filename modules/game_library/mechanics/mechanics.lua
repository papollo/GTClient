MechanicsGuide = {}
MechanicsGuide.DOMAIN = 'mechanics'

local CONTENT_FILE = '/game_library/mechanics/mechanics.json'
local IMAGE_DIRECTORY = '/game_library/mechanics/images/'
local TEXT_WIDTH = 410

local ui = nil
local mechanics = {}
local selectedId = nil

local function prepareText(text)
    text = tostring(text or '')
    text = text:gsub('\\r\\n', '\n'):gsub('\\n', '\n')
    return utf8ToCp1250(text)
end

local function setStatus(text, color)
    if not ui or not ui.statusLabel then
        return
    end

    ui.statusLabel:setText(prepareText(text))
    ui.statusLabel:setColor(color or '#BDBDBD')
    ui.statusLabel:setVisible(text ~= nil and text ~= '')
end

local function clearContent()
    if not ui then
        return
    end

    ui.content:destroyChildren()
    ui.titleLabel:setText('')
    setStatus(nil)
end

local function createMessage(text, color)
    local label = g_ui.createWidget('Label', ui.content)
    label:setText(prepareText(text))
    label:setColor(color or '#BDBDBD')
    label:setTextWrap(true)
    label:setTextVerticalAutoResize(true)
    label:setWidth(TEXT_WIDTH)
    return label
end

local function isValidImageFile(fileName)
    return type(fileName) == 'string' and fileName ~= '' and
        not fileName:find('..', 1, true) and
        not fileName:find('/', 1, true) and
        not fileName:find('\\', 1, true)
end

local function renderImage(fileName)
    if not isValidImageFile(fileName) then
        createMessage('Nieprawidłowa nazwa pliku obrazu.', '#e84a4a')
        g_logger.warning('[MechanicsGuide] Invalid image filename: ' .. tostring(fileName))
        return
    end

    local imagePath = IMAGE_DIRECTORY .. fileName
    if not g_resources.fileExists(imagePath) then
        createMessage(string.format('Brak obrazu: %s', fileName), '#e84a4a')
        g_logger.warning('[MechanicsGuide] Missing image: ' .. imagePath)
        return
    end

    local image = g_ui.createWidget('UIWidget', ui.content)
    image:setImageSmooth(true)
    image:setImageSource(imagePath)

    local sourceWidth = image:getImageTextureWidth()
    local sourceHeight = image:getImageTextureHeight()

    if sourceWidth <= 0 or sourceHeight <= 0 then
        image:destroy()
        createMessage(string.format('Nie udało się wczytać obrazu: %s', fileName), '#e84a4a')
        g_logger.warning('[MechanicsGuide] Unable to load image: ' .. imagePath)
        return
    end

    local targetWidth = math.min(sourceWidth, TEXT_WIDTH)
    local targetHeight = math.max(1, math.floor(sourceHeight * targetWidth / sourceWidth + 0.5))
    image:resize(targetWidth, targetHeight)
    image:setImageWidth(targetWidth)
    image:setImageHeight(targetHeight)
end

local function renderMechanic(mechanic)
    clearContent()
    ui.titleLabel:setText(prepareText(mechanic.title))

    if #mechanic.blocks == 0 then
        createMessage('Opis tej mechaniki nie został jeszcze dodany.', '#9A9A9A')
        return
    end

    local renderedBlocks = 0
    for _, block in ipairs(mechanic.blocks) do
        if type(block) == 'table' and block.type == 'text' and type(block.text) == 'string' and block.text ~= '' then
            createMessage(block.text)
            renderedBlocks = renderedBlocks + 1
        elseif type(block) == 'table' and block.type == 'image' then
            renderImage(block.file)
            renderedBlocks = renderedBlocks + 1
        else
            g_logger.warning('[MechanicsGuide] Skipping invalid content block in: ' .. mechanic.id)
        end
    end

    if renderedBlocks == 0 then
        createMessage('Opis tej mechaniki nie został jeszcze dodany.', '#9A9A9A')
    end
end

local function selectMechanic(mechanic)
    if not mechanic or not ui then
        return
    end

    selectedId = mechanic.id
    for _, widget in ipairs(ui.list:getChildren()) do
        widget:setChecked(widget.mechanicId == selectedId)
    end
    renderMechanic(mechanic)
end

local function normalizeMechanics(data)
    if type(data) ~= 'table' or type(data.mechanics) ~= 'table' then
        return nil, 'JSON mechanik musi zawierać tablicę "mechanics".'
    end

    local normalized = {}
    local seenIds = {}
    for index, mechanic in ipairs(data.mechanics) do
        if type(mechanic) == 'table' and type(mechanic.id) == 'string' and mechanic.id ~= '' and
            type(mechanic.title) == 'string' and mechanic.title ~= '' and not seenIds[mechanic.id] then
            table.insert(normalized, {
                id = mechanic.id,
                title = mechanic.title,
                blocks = type(mechanic.blocks) == 'table' and mechanic.blocks or {}
            })
            seenIds[mechanic.id] = true
        else
            g_logger.warning(string.format('[MechanicsGuide] Skipping invalid or duplicate entry at index %d.', index))
        end
    end

    if #normalized == 0 then
        return nil, 'JSON mechanik nie zawiera żadnych prawidłowych wpisów.'
    end
    return normalized
end

local function loadMechanics()
    if not g_resources.fileExists(CONTENT_FILE) then
        return nil, 'Brakuje pliku z opisami mechanik.'
    end

    local success, result = pcall(function()
        return json.decode(g_resources.readFileContents(CONTENT_FILE))
    end)
    if not success then
        g_logger.error('[MechanicsGuide] Unable to parse ' .. CONTENT_FILE .. ': ' .. tostring(result))
        return nil, 'Nie udało się wczytać opisów mechanik. Sprawdź składnię JSON.'
    end

    return normalizeMechanics(result)
end

local function renderMenu()
    ui.list:destroyChildren()

    for _, mechanic in ipairs(mechanics) do
        local item = g_ui.createWidget('LibraryCategoryItem', ui.list)
        item:setText(prepareText(mechanic.title))
        item.mechanicId = mechanic.id
        item.onClick = function()
            selectMechanic(mechanic)
        end
    end
end

function MechanicsGuide.bind(widgets)
    ui = widgets
end

function MechanicsGuide.activate()
    if not ui then
        return
    end

    local loadedMechanics, errorMessage = loadMechanics()
    ui.list:destroyChildren()
    clearContent()

    if not loadedMechanics then
        mechanics = {}
        selectedId = nil
        setStatus(errorMessage, '#e84a4a')
        return
    end

    mechanics = loadedMechanics
    renderMenu()

    local selection = nil
    for _, mechanic in ipairs(mechanics) do
        if mechanic.id == selectedId then
            selection = mechanic
            break
        end
    end
    selectMechanic(selection or mechanics[1])
end

function MechanicsGuide.reset()
    mechanics = {}
    selectedId = nil
    if ui then
        ui.list:destroyChildren()
        clearContent()
    end
end

function MechanicsGuide.terminate()
    MechanicsGuide.reset()
    ui = nil
end
