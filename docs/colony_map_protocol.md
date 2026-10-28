# Mapa kolonii — kontrakt klienta

Klient 1098 i serwer obsługują mapę w bibliotece przez domenę `territories`.
Serwer odczytuje istniejący stan aren (`CampPvPArenaService.states`), bez zmian
zasad walki, bonusów ani HUD areny (opcode 220). Dane są globalne: dostępne
każdemu graczowi online, niezależnie od obozu i uczestnictwa w walce.

## Żądanie

Extended JSON opcode **217**, domena **territories**, akcja **status**, wersja **1**.
Jedno nowe żądanie przy każdym otwarciu zakładki online, również po przejściu
na inną zakładkę i powrocie lub po ponownym otwarciu biblioteki na mapie.
Otwarta mapa zachowuje otrzymany stan do następnego wejścia. Nie ma okresowego
odświeżania ani automatycznego ponawiania po błędach. Zamknięcie biblioteki,
zmiana zakładki i wylogowanie anulują oczekujące żądanie. Zoom, przesuwanie,
wybór areny i centrowanie nie wysyłają zapytań.

```json
{
  "version": 1,
  "domain": "territories",
  "action": "status",
  "requestId": "library-territories-status-1",
  "data": {}
}
```

## Odpowiedź

```json
{
  "version": 1,
  "domain": "territories",
  "action": "status",
  "requestId": "library-territories-status-1",
  "ok": true,
  "data": {
    "territories": [
      { "arenaId": "old_mine_arena", "owner": "oldCamp", "remainingSeconds": 86400 }
    ]
  }
}
```

`requestId` musi odpowiadać aktualnemu żądaniu. Właściciele:

| owner | Kolor | Obóz |
| --- | --- | --- |
| oldCamp | czerwony | Stary Obóz |
| newCamp | niebieski | Nowy Obóz |
| swampCamp | zielony | Obóz na Bagnie (przyszła obsługa serwera) |
| neutral | jasnoszary | Brak obozu |

`remainingSeconds` to skończona liczba całkowita: dodatnia dla właściciela,
zero dla `neutral`. Określa czas kontroli w chwili odczytu przez serwer.
Klient nie zmienia koloru automatycznie po upływie tego czasu. Ponowne wejście
do zakładki pobiera aktualny stan. Serwer zwraca `neutral`, gdy
czas kontroli upłynął, również jeśli cykl areny jeszcze nie wyczyścił stanu.
Odczyt nie zmienia flag, bonusów, właściciela ani zapisu w bazie danych.
Odpowiedź zawiera tylko włączone, poprawnie skonfigurowane areny z wczytanym
stanem; brak takich aren oznacza pustą tablicę `territories: []`.
Brak sektora, błędne dane, `ok: false` lub upływ 5 sekund bez odpowiedzi
również oznaczają brak danych, a nie potwierdzoną neutralność.
Akcja inna niż `status` zwraca `INVALID_ACTION`; brak usługi aren zwraca
`SERVICE_UNAVAILABLE`. Po błędzie lub timeoutcie należy ponownie wejść
do zakładki, aby pobrać dane.

Klient ignoruje obce terytoria i spóźnione odpowiedzi. Wylogowanie usuwa dane
i oczekujące żądanie. Plac Wymian (`exchange_square`) jest lokalnym sektorem,
zawsze szarym i niedostępnym do przejęcia; odpowiedź nie może go zmienić.
Tak samo działają nowe sektory: Bagna (`swamp`), Las na wschodzie (`east_forest`),
Wolna kopalnia (`free_mine`), Ziemie orków (`orc_lands`) i Stara forteca
(`old_fortress`). Wszystkie siedem terytoriów ma granice odtworzone z
`Sectors.png`, dymek z nazwą oraz przycisk centrujący na liście aren.
Nowe sektory nie mają bonusów ani obsługi własności po stronie serwera.
Opis bonusu Starej Kopalni (+5% szansy na trafienie krytyczne) jest lokalny,
zgodny z obecną konfiguracją areny. Klient nie przyznaje bonusów.

## Walidacja

- `lua tools/test_colony_map.lua` — geometria, kolory właścicieli,
  reset sesji, błędne dane, timeout, spóźnione odpowiedzi, pobieranie stanu
  przy ponownym wejściu i brak odświeżania w tle.
- W katalogu serwera: `lua tests/test_colony_map_status.lua ../GTClient` —
  globalny odczyt, zmiana właściciela, wygaśnięcie, wyłączone areny i błędy;
  dodatkowo prawdziwa odpowiedź JSON serwera zdekodowana i odebrana przez klienta.
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools/generate_colony_map_masks.ps1`
  — odtworzenie masek i obrysów z `colony_map_geometry.lua`.
  Opcja `-OutlinesOnly` odtwarza wyłącznie obrysy, zachowując ręcznie
  edytowane maski PNG. Po zmianie maski trzeba również dopasować wielokąt
  w `colony_map_geometry.lua`, aby dymek i granica pokrywały się z wypełnieniem.
- Ręcznie w kliencie: biblioteka → Map; najechanie na
  sektory i poza ich obrysy; zmiana zakładek; zamknięcie i ponowne otwarcie;
  wylogowanie i logowanie. Sprawdzić brak zmian w HUD.
- Mapa: zoom kółkiem myszy lub przyciskami +/− w prawym górnym rogu mapy
  (100–600%), przesuwanie lewym przyciskiem myszy. Przycisk „Centruj”
  w prawym dolnym rogu przywraca widok początkowy. Lewy panel zawiera tylko areny.
  Kliknięcie areny w lewym panelu centruje jej sektor i ustawia zoom 300%.
  Legenda obozów została usunięta. Zweryfikować tooltipy po powiększeniu,
  przycinanie obrazu do panelu i zwalnianie myszy po zamknięciu zakładki.
- Sprawdzić na dwóch kontach, w tym na graczu spoza areny: po wygranej Starego
  Obozu sektor czerwony, po wygranej Nowego Obozu niebieski. Ponowne otwarcie
  pobiera nowy stan od razu; mapa pozostawiona otwarta zachowuje poprzedni stan.
- Po wdrożeniu uruchomić ponownie serwer oraz klienta. Restart serwera
  wczytuje dotychczas zapisanego
  właściciela i czas kontroli; nie wymaga nowej walki ani migracji bazy.
