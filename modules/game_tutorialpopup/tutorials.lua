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
    },
    [4] = {
        title = 'Jumping',
        image = '/game_tutorialpopup/images/jump.png',
        text = 'Skakanie:\n\nW grze możesz korzystać z komend jump "up" oraz jump "down", aby wskakiwać na wyższe poziomy lub zeskakiwać na niższe.\n\n- Skakanie w górę i w dół jest możliwe tylko przy prostych krawędziach, dlatego podczas eksploracji warto ich wypatrywać. Niektóre miejsca mogą być dostępne wyłącznie dzięki wykorzystaniu tej mechaniki.\n\nAkrobatyka:\n\n- Po nauczeniu się akrobatyki gracz może używać komendy jump "forward", aby przeskoczyć kilka pól do przodu, stojąc przy odpowiedniej krawędzi.\n\n- Znajomość akrobatyki pozwala dostać się do trudno dostępnych miejsc i jest potrzebna, aby w pełni odkrywać świat gry.'
    },
    [5] = {
        title = 'Hunt tasks',
        image = '/game_tutorialpopup/images/hunt_task_tutorial.png',
        text = 'Hunt taski to zadania polegające na polowaniu na określone rodzaje potworów. Zadania te można otrzymać od NPC oznaczonych ikoną łuku.\n\nWszystkie przyjęte i aktualnie wykonywane hunt taski znajdują się w Quest Logu, gdzie można sprawdzić wymagany cel oraz postęp polowania.\n\nAktywny hunt task można anulować, jeżeli gracz nie chce go dalej wykonywać.\n\nPo ukończeniu hunt taska gracz otrzymuje dostęp do powiązanego z nim bossa oraz Punkty Łowcy.\n\nPunkty Łowcy pozwalają uzyskać dostęp do Obozu Myśliwych i odblokowują kolejne możliwości handlu ze specjalnym NPC. W zależności od liczby zdobytych Punktów Łowcy NPC może skupować od gracza zdobyte przedmioty oraz oferować coraz szerszy asortyment.'
    },
    [6] = {
        title = 'Training',
        image = '/game_tutorialpopup/images/training_tutorial_window.png',
        text = 'W obozach znajdują się trainery, na których można trenować umiejętności podczas pozostawania online. Po 15 minutach bezczynności postać zostanie automatycznie wylogowana.\n\nW pobliżu trainerów znajduje się również Offline Training Dummy. Po jego użyciu pojawi się okno pozwalające wybrać trenowaną umiejętność: broń jednoręczną, broń dwuręczną, łuki, kusze lub poziom magiczny. Po zatwierdzeniu wyboru postać zostanie wylogowana i rozpocznie trening offline.\n\nKażda postać może zgromadzić maksymalnie 12 godzin czasu treningu offline. Podczas treningu zapas jest zużywany w proporcji 1:1 — jedna minuta treningu zużywa jedną minutę zgromadzonego czasu.\n\nCzas treningu offline odnawia się również w proporcji 1:1, czyli jedna minuta bez korzystania z treningu przywraca jedną minutę zapasu. Czas ładuje się zarówno podczas gry online, jak i podczas zwykłego wylogowania bez aktywnego treningu. Pełne odnowienie pustego zapasu trwa 12 godzin.\n\nAby trening offline został naliczony, postać musi pozostać wylogowana przez co najmniej 10 minut.'
    }
}
