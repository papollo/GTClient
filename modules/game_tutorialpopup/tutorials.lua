-- The server sends only an unsigned byte ID through player:sendTutorial(id).
-- Keep this table synchronized with the tutorial ID constants on the server.
TutorialHints = {
    [1] = {
        title = 'Chapter I',
        image = '/game_tutorialpopup/images/chapter_1.png',
        text = nil
    },
    [2] = {
        title = 'Crafting',
        image = '/game_tutorialpopup/images/crafting.png',
        text = 'Crafting:\n\nPrzy stołach rzemieślniczych gracz może tworzyć bronie, zbroje czy amunicję oraz warzyć mikstury.\n\nZanim jednak gracz będzie mógł stworzyć przedmiot, musi poznać jego przepis lub schemat. Przepisy oraz schematy można znaleźć w świecie gry lub otrzymać od innych graczy.\n\nAlchemia:\n\n- Dzięki alchemii gracz może tworzyć mikstury, które dają natychmiastowe efekty, takie jak mikstury życia lub many, oraz mikstury zapewniające tymczasowe efekty, np. zwiększające zdobywane doświadczenie, szczęście czy zdolności bojowe.\n\nKucie broni:\n\n- Przy pomocy kowadła gracz może wykuwać różnego rodzaju bronie do walki wręcz. Do ich stworzenia potrzebne są odpowiednie schematy oraz materiały zdobywane podczas eksploracji świata.\n\nTworzenie łuków i kusz:\n\n- Przy odpowiednim stole rzemieślniczym gracz może tworzyć łuki, kusze oraz amunicję. Każdy przedmiot wymaga poznania właściwego schematu oraz zebrania potrzebnych materiałów.\n\nUlepszanie ekwipunku:\n\n- Zdobyty lub wytworzony ekwipunek może być dodatkowo ulepszany. Ulepszenia pozwalają zwiększyć właściwości broni i pancerzy, dzięki czemu nawet wcześniej zdobyte przedmioty mogą pozostać przydatne na późniejszych etapach gry.'
    },
    [3] = {
        title = 'Resources',
        image = '/game_tutorialpopup/images/resources.png',
        text = 'Zbieranie surowców:\n\nPodczas eksploracji świata gracz może znaleźć różnego rodzaju surowce wykorzystywane w rzemiośle, alchemii oraz ulepszaniu ekwipunku.\n\nRośliny:\n\n- W świecie gry można znaleźć rośliny potrzebne do warzenia mikstur. Surowe rośliny można również zjadać bezpośrednio, aby otrzymać krótkotrwałe bonusy do wybranych właściwości postaci.\n\nWydobywanie minerałów:\n\n- W różnych miejscach na mapie znajdują się złoża minerałów, z których gracz może wydobywać między innymi żelazo, węgiel oraz magiczną rudę. Zdobyte minerały są potrzebne do tworzenia nowych przedmiotów oraz ulepszania posiadanego ekwipunku.'
    }
}
