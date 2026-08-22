local window
local queue = {}
local displaying = false
local windowDecorationWidth = 0
local windowDecorationHeight = 0

local SCREEN_MARGIN = 80
local TEXT_COLUMN_WIDTH = 280
local SPLIT_CONTENT_SPACING = 16

local function prepareText(text)
    return utf8ToCp1250(text or '')
end

local function fitImageSize(width, height, maxWidth, maxHeight)
    if width <= 0 or height <= 0 then
        return nil, nil
    end

    local scale = math.min(1, maxWidth / width, maxHeight / height)
    return math.max(1, math.floor(width * scale)), math.max(1, math.floor(height * scale))
end

local function resizeToImage(imageWidget, hasText, imageOnlyContent, imageAndTextContent)
    local textureWidth = imageWidget:getImageTextureWidth()
    local textureHeight = imageWidget:getImageTextureHeight()
    if textureWidth <= 0 or textureHeight <= 0 then
        g_logger.warning('[TutorialPopup] Unable to read tutorial image dimensions')
        return
    end

    local rootWidth = rootWidget:getWidth()
    local rootHeight = rootWidget:getHeight()
    local additionalWidth = hasText and (TEXT_COLUMN_WIDTH + SPLIT_CONTENT_SPACING) or 0
    local imageContainer = hasText and imageAndTextContent:getChildById('imagePanel') or imageOnlyContent
    local containerPaddingWidth = imageContainer:getPaddingLeft() + imageContainer:getPaddingRight()
    local containerPaddingHeight = imageContainer:getPaddingTop() + imageContainer:getPaddingBottom()
    local maxImageWidth = math.max(1,
        rootWidth - windowDecorationWidth - additionalWidth - containerPaddingWidth - SCREEN_MARGIN)
    local maxImageHeight = math.max(1,
        rootHeight - windowDecorationHeight - containerPaddingHeight - SCREEN_MARGIN)
    local imageWidth, imageHeight = fitImageSize(textureWidth, textureHeight, maxImageWidth, maxImageHeight)

    if hasText then
        imageContainer:setWidth(imageWidth + containerPaddingWidth)
    end

    window:resize(imageWidth + containerPaddingWidth + additionalWidth + windowDecorationWidth,
        imageHeight + containerPaddingHeight + windowDecorationHeight)
end

local function reset()
    queue = {}

    if not window then
        displaying = false
        return
    end

    if displaying then
        window:unlock()
    end

    window:hide()
    displaying = false
end

local function showNext()
    if displaying or not window or #queue == 0 then
        return
    end

    local tutorial = table.remove(queue, 1)
    local hasText = type(tutorial.text) == 'string' and tutorial.text:len() > 0
    local imageOnlyContent = window:getChildById('imageOnlyContent')
    local imageAndTextContent = window:getChildById('imageAndTextContent')
    local imageOnly = imageOnlyContent and imageOnlyContent:getChildById('tutorialImage')
    local imageWithText = imageAndTextContent and imageAndTextContent:recursiveGetChildById('tutorialImage')
    local tutorialText = imageAndTextContent and imageAndTextContent:recursiveGetChildById('tutorialText')

    if not imageOnlyContent or not imageAndTextContent or not imageOnly or not imageWithText or not tutorialText then
        g_logger.error('[TutorialPopup] Required UI widgets are missing')
        return
    end

    window:setText(prepareText(tutorial.title or 'Information'))
    imageOnlyContent:setVisible(not hasText)
    imageAndTextContent:setVisible(hasText)

    if hasText then
        imageWithText:setImageSource(tutorial.image)
        tutorialText:setText(prepareText(tutorial.text))
        resizeToImage(imageWithText, true, imageOnlyContent, imageAndTextContent)
    else
        imageOnly:setImageSource(tutorial.image)
        resizeToImage(imageOnly, false, imageOnlyContent, imageAndTextContent)
    end

    displaying = true
    window:show()
    window:raise()
    window:focus()
    window:lock()
end

function onTutorialHint(id)
    local tutorial = TutorialHints[tonumber(id)]
    if not tutorial then
        g_logger.warning(string.format('[TutorialPopup] Unknown tutorial hint id: %s', tostring(id)))
        return
    end

    if type(tutorial.image) ~= 'string' or tutorial.image:len() == 0 then
        g_logger.warning(string.format('[TutorialPopup] Tutorial hint %s has no image', tostring(id)))
        return
    end

    if not g_resources.fileExists(tutorial.image) then
        g_logger.warning(string.format('[TutorialPopup] Image not found for tutorial hint %s: %s', tostring(id),
            tutorial.image))
        return
    end

    table.insert(queue, tutorial)
    showNext()
end

function close()
    if not window or not displaying then
        return
    end

    window:unlock()
    window:hide()
    displaying = false
    showNext()
end

function init()
    window = g_ui.loadUI('tutorialpopup', rootWidget)
    if not window then
        error('[TutorialPopup] Unable to load tutorialpopup.otui')
    end

    window:updateLayout()
    local imageOnlyContent = window:getChildById('imageOnlyContent')
    windowDecorationWidth = window:getWidth() - imageOnlyContent:getWidth()
    windowDecorationHeight = window:getHeight() - imageOnlyContent:getHeight()
    window:hide()

    connect(g_game, {
        onTutorialHint = onTutorialHint,
        onGameEnd = reset
    })
end

function terminate()
    disconnect(g_game, {
        onTutorialHint = onTutorialHint,
        onGameEnd = reset
    })

    reset()

    if window then
        window:destroy()
        window = nil
    end
end
