modalDialog = nil

function init()
    g_ui.importStyle('modaldialog')

    connect(g_game, {
        onModalDialog = onModalDialog,
        onGameEnd = destroyDialog
    })

    local dialog = rootWidget:recursiveGetChildById('modalDialog')
    if dialog then
        modalDialog = dialog
    end
end

function terminate()
    disconnect(g_game, {
        onModalDialog = onModalDialog,
        onGameEnd = destroyDialog
    })
end

function destroyDialog()
    if modalDialog then
        modalDialog:destroy()
        modalDialog = nil
    end
end

function onModalDialog(id, title, message, buttons, enterButton, escapeButton, choices, priority)
    -- priority parameter is unused, not sure what its use is.
    if modalDialog then
        return
    end

    modalDialog = g_ui.createWidget('ModalDialog', rootWidget)

    local messageLabel = modalDialog:getChildById('messageLabel')
    local choiceList = modalDialog:getChildById('choiceList')
    local choiceScrollbar = modalDialog:getChildById('choiceScrollBar')
    local buttonsPanel = modalDialog:getChildById('buttonsPanel')

    local baseDialogHeight = modalDialog:getHeight()
    local baseMessageHeight = messageLabel:getHeight()
    local baseChoiceListHeight = choiceList:getHeight()
    local baseChoiceListArea = baseChoiceListHeight + choiceList:getMarginTop() + choiceList:getMarginBottom()

    modalDialog:setText(title)
    messageLabel:setText(message)

    local choiceLabels = {}
    local baseChoiceLabelHeight = 0
    for i = 1, #choices do
        local choiceId = choices[i][1]
        local choiceName = choices[i][2]

        local label = g_ui.createWidget('ChoiceListLabel', choiceList)
        label.choiceId = choiceId
        label:setText(choiceName)
        label:setPhantom(false)
        if baseChoiceLabelHeight == 0 or math.min(baseChoiceLabelHeight, label:getHeight()) == label:getHeight() then
            baseChoiceLabelHeight = label:getHeight()
        end
        table.insert(choiceLabels, label)
    end

    local firstChoice = choiceList:getFirstChild()
    if firstChoice then
        choiceList:focusChild(firstChoice)
    end

    g_keyboard.bindKeyPress('Down', function()
        choiceList:focusNextChild(KeyboardFocusReason)
    end, modalDialog)
    g_keyboard.bindKeyPress('Up', function()
        choiceList:focusPreviousChild(KeyboardFocusReason)
    end, modalDialog)

    local buttonsWidth = buttonsPanel:getPaddingLeft() + buttonsPanel:getPaddingRight()
    for i = 1, #buttons do
        local buttonId = buttons[i][1]
        local buttonText = buttons[i][2]

        local button = g_ui.createWidget('ModalButton', buttonsPanel)
        button:setText(buttonText)
        button.onClick = function(self)
            local focusedChoice = choiceList:getFocusedChild()
            local choice = 0xFF
            if focusedChoice then
                choice = focusedChoice.choiceId
            end
            g_game.answerModalDialog(id, buttonId, choice)
            destroyDialog()
        end
        buttonsWidth = buttonsWidth + button:getWidth() + button:getMarginLeft() + button:getMarginRight()
    end

    local additionalHeight = 0
    if #choices > 0 then
        choiceList:setVisible(true)
    end

    local horizontalPadding = modalDialog:getPaddingLeft() + modalDialog:getPaddingRight()
    local messageWidth = messageLabel:getTextSize().width + messageLabel:getPaddingLeft() + messageLabel:getPaddingRight()
    local choiceListPadding = choiceList:getPaddingLeft() + choiceList:getPaddingRight()
    local choiceListMargins = choiceList:getMarginLeft() + choiceList:getMarginRight()

    local requiresScrollbar = #choices > modalDialog.maximumChoices
    choiceScrollbar:setVisible(requiresScrollbar and #choices > 0)
    local scrollbarWidth = 0
    if choiceScrollbar:isVisible() then
        scrollbarWidth = choiceScrollbar:getWidth()
        if scrollbarWidth == 0 then
            scrollbarWidth = 20
        end
    end

    local choicesWidth = 0
    for _, label in ipairs(choiceLabels) do
        local labelWidth = label:getTextSize().width + label:getPaddingLeft() + label:getPaddingRight() +
            label:getMarginLeft() + label:getMarginRight()
        choicesWidth = math.max(choicesWidth, labelWidth)
    end

    local dialogWidth = math.max(modalDialog.minimumWidth, buttonsWidth + horizontalPadding,
        messageWidth + horizontalPadding)
    if choicesWidth > 0 then
        dialogWidth = math.max(dialogWidth,
            choicesWidth + choiceListPadding + choiceListMargins + scrollbarWidth + horizontalPadding)
    end

    if modalDialog.maximumWidth > 0 then
        dialogWidth = math.min(dialogWidth, modalDialog.maximumWidth)
    end

    modalDialog:setWidth(dialogWidth)

    local messageAreaWidth = math.max(0, dialogWidth - horizontalPadding)
    messageLabel:setWidth(messageAreaWidth)
    if messageLabel:getText():len() > 0 then
        messageLabel:setText('', true)
        messageLabel:setText(message)
    end

    local messageHeight = messageLabel:getTextSize().height + messageLabel:getPaddingTop() + messageLabel:getPaddingBottom()
    messageLabel:setHeight(messageHeight)

    if #choiceLabels > 0 then
        local availableChoiceWidth = dialogWidth - horizontalPadding - choiceListPadding - scrollbarWidth
        for _, label in ipairs(choiceLabels) do
            local width = math.max(0, availableChoiceWidth - label:getMarginLeft() - label:getMarginRight())
            label:setWidth(width)
        end

        local totalChoiceHeight = 0
        local heightForMaxChoices = 0
        for index, label in ipairs(choiceLabels) do
            local height = label:getHeight()
            totalChoiceHeight = totalChoiceHeight + height
            if index <= modalDialog.maximumChoices then
                heightForMaxChoices = heightForMaxChoices + height
            end
        end
        
        local choiceContentHeight = totalChoiceHeight
        if #choiceLabels > modalDialog.maximumChoices then
            choiceContentHeight = heightForMaxChoices
        end

        if baseChoiceLabelHeight and baseChoiceLabelHeight > 0 then
            choiceContentHeight = math.max(choiceContentHeight, modalDialog.minimumChoices * baseChoiceLabelHeight)
        end
        
        local listInnerHeight = choiceContentHeight + choiceList:getPaddingTop() + choiceList:getPaddingBottom()
        choiceList:setHeight(listInnerHeight)

        local desiredChoiceArea = listInnerHeight + choiceList:getMarginTop() + choiceList:getMarginBottom()
        local baseChoiceArea = baseChoiceListArea
        additionalHeight = math.max(0, desiredChoiceArea - baseChoiceArea)
    else
        choiceScrollbar:setVisible(false)
    end

    local messageHeightDelta = math.max(0, messageLabel:getHeight() - baseMessageHeight)
    modalDialog:setHeight(baseDialogHeight + additionalHeight + messageHeightDelta)

    local enterFunc = function()
        local focusedChoice = choiceList:getFocusedChild()
        local choice = 0xFF
        if focusedChoice then
            choice = focusedChoice.choiceId
        end
        g_game.answerModalDialog(id, enterButton, choice)
        destroyDialog()
    end

    local escapeFunc = function()
        local focusedChoice = choiceList:getFocusedChild()
        local choice = 0xFF
        if focusedChoice then
            choice = focusedChoice.choiceId
        end
        g_game.answerModalDialog(id, escapeButton, choice)
        destroyDialog()
    end

    choiceList.onDoubleClick = enterFunc

    modalDialog.onEnter = enterFunc
    modalDialog.onEscape = escapeFunc
end
