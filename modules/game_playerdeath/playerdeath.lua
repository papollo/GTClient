local deathTexts = {
    regular = {
        text = 'Straciles przytomnosc.\n\nOdrodzisz sie w bezpiecznym miejcu,\nale nastepnym razem lepiej uwazaj.\n\nMozesz nie miec tyle szczescia.',
        height = 185,
        width = 0
    },
    unfair = {
        text = 'Straciles przytomnosc.\n\nOdrodzisz sie w bezpiecznym miejcu,\nale nastepnym razem lepiej uwazaj.\n\nMozesz nie miec tyle szczescia.',
        height = 185,
        width = 0
    },
    blessed = {
        text = 'Straciles przytomnosc.\n\nOdrodzisz sie w bezpiecznym miejcu,\nale nastepnym razem lepiej uwazaj.\n\nMozesz nie miec tyle szczescia.',
        height = 185,
        width = 90
    }
}

deathController = Controller:new()
function deathController:onInit()
    deathController:registerEvents(g_game, {
        onDeath = display,
    })
end

function deathController:onTerminate()
   deathController.ui = destroyWindows()
end

function deathController:onGameEnd()
    deathController.ui = destroyWindows()
end

function destroyWindows()
    if deathController.ui and not deathController.ui:isDestroyed() then
        deathController.ui:destroy()
    end
    return nil
end

function display(deathType, penalty)
    displayDeadMessage()
    openWindow(deathType, penalty)
    scheduleReconnect()
end

function displayDeadMessage()
    local advanceLabel = modules.game_interface.getRootPanel():recursiveGetChildById('middleCenterLabel')
    if advanceLabel:isVisible() then
        return
    end

    modules.game_textmessage.displayGameMessage(tr('You are dead.'))
end

function openWindow(deathType, penalty)
    deathController.ui = destroyWindows()
    deathController.ui = g_ui.displayUI('deathwindow', rootWidget)

    local textLabel = deathController.ui:getChildById('labelText')
    if deathType == DeathType.Regular then
        if penalty == 100 then
            textLabel:setText(deathTexts.regular.text)
            deathController.ui:setHeight(deathController.ui.baseHeight + deathTexts.regular.height)
            deathController.ui:setWidth(deathController.ui.baseWidth + deathTexts.regular.width)
        else
            textLabel:setText(string.format(deathTexts.unfair.text, 100 - penalty))
            deathController.ui:setHeight(deathController.ui.baseHeight + deathTexts.unfair.height)
            deathController.ui:setWidth(deathController.ui.baseWidth + deathTexts.unfair.width)
        end
    elseif deathType == DeathType.Blessed then
        textLabel:setText(deathTexts.blessed.text)
        deathController.ui:setHeight(deathController.ui.baseHeight + deathTexts.blessed.height)
        deathController.ui:setWidth(deathController.ui.baseWidth + deathTexts.blessed.width)
    end

    local okButton = deathController.ui:getChildById('buttonOk')
    local cancelButton = deathController.ui:getChildById('buttonCancel')

    local okFunc = function()
        CharacterList.doLogin()
        deathController.ui = destroyWindows()
    end
    local cancelFunc = function()
        g_game.safeLogout()
        deathController.ui = destroyWindows()
    end

    deathController.ui.onEnter = okFunc
    deathController.ui.onEscape = cancelFunc

    okButton.onClick = okFunc
    cancelButton.onClick = cancelFunc
end

function scheduleReconnect()
    if not g_settings.getBoolean('autoReconnect') then
        return
    end
    deathController:scheduleEvent(function()
        deathController.ui = destroyWindows()
        g_game.cancelLogin()
        CharacterList.doLogin()
    end, 2000, 'scheduleAutoReconnect')
end
