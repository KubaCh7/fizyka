# Magnet & Steal a Brainrot — grywalny prototyp (Roblox)

Łowisz magnesem zardzewiałe Brainroty z kanału, niesiesz je przez bezprawną
ulicę do garażu, gdzie zarabiają na sekundę — a inni gracze mogą ci je wyrwać
własnym magnesem w przeciąganiu liny.

## Jak uruchomić w Roblox Studio

**Najprościej:** otwórz plik `build/MagnetStealBrainrot.rbxlx` w Roblox Studio
(File → Open from File) i kliknij **Play**. Mapa (ulica, 8 garaży, kanał z wodą,
3 pomosty, most) buduje się kodem przy starcie serwera — w edytorze przed
naciśnięciem Play scena jest pusta i tak ma być.

**Do dalszej pracy nad kodem:** [Rojo](https://rojo.space) 7.4+.

```bash
cd magnet-steal-brainrot
rojo serve                      # potem w Studio: plugin Rojo → Connect
rojo build -o build/MagnetStealBrainrot.rbxlx   # przebudowanie pliku miejsca
```

**Zapisy postępu:** Game Settings → Security → *Enable Studio Access to API
Services*. Bez tego gra działa, tylko nie zapisuje postępu (pojawi się komunikat).

**Test PvP (kradzieży):** zakładka Test → Clients and Servers → 2 Players → Start.

## Sterowanie

| Akcja | PC | Telefon |
| --- | --- | --- |
| Rzut magnesem | Weź **Wędkę Magnetyczną**, stań na pomoście lub brzegu, przytrzymaj LPM i puść na zielonym (Perfect Cast = +10% Luck) | Przytrzymaj i puść |
| Zaczepienie | Po „KLANG!” kliknij w ciągu 0,8 s | Dotknij |
| Wyciąganie | Trzymaj LPM/Spację = pole w prawo, puść = w lewo. Trzymaj obiekt w polu, napięcie w białej strefie (40–70%) daje +25% postępu, 100% = zerwana lina | Przytrzymaj/puść |
| Skill-check | Kliknij, gdy wskazówka jest na zielonym | Dotknij |
| Kradzież | Weź **Hak do Kradzieży** i kliknij gracza niosącego łup (poza garażem) | Dotknij gracza |
| Przeciąganie liny | Klik/Spacja w rytm, gdy pierścień dotknie środka. Obrońca może też uciec do garażu | Przycisk SZARP! |
| Pułapka | **Skórka od Banana** — kliknij, by położyć pod nogami | Dotknij |
| Odbiór pieniędzy | Wejdź na zielone pole **KASA** w garażu | to samo |

Łup odkłada się na stojaki automatycznie po wejściu do własnego garażu. Gdy
stojaki są pełne, słabszy przedmiot idzie do Skupu (15 × CPS). Stojak można też
sprzedać ręcznie (przytrzymaj E przy stojaku).

## Co jest w prototypie

- **Łowienie:** 5 stref kanału (Płycizna → Przeklęty Ściek), wymagany zasięg
  magnesu, minigra z polem, napięciem liny i skill-checkami, „za ciężkie” —
  sylwetka obiektu, gdy magnes jest za słaby.
- **Łup:** 30 Brainrotów (5 stref × 6 rzadkości), 6 mutacji (do Tęczowego ×25),
  4 rozmiary, Index kolekcji, pity (Epic w pierwszych 25 rzutach, Secret
  najpóźniej co 500 rzutów).
- **Transport i PvP:** przedmioty widoczne na plecach, Secret+ w rękach ze
  słupem światła widocznym z całej mapy, spowolnienie za każdy przedmiot,
  kradzież przez przeciąganie liny w rytm, Zemsta (+25% siły przez 90 s),
  Ochrona Nowicjusza (10 min lub $5,000).
- **Chaos do klipów:** wpadnięcie do kanału topi 50% łupu (każdy może go
  wyłowić), skórki od banana, odrzut przegranego, alerty SECRET/CURSED/MYTHIC
  dla całego serwera, „NA HACZYKU” ze słupem światła z wody.
- **Tycoon:** 8 garaży, do 24 stojaków, Kasa z limitem 30 min dochodu, dochód
  offline (50%, maks. 2 h), sklep (9 magnesów, 6 lin, 8 transportów, 8 poziomów
  garażu), Rebirth (+50% CPS, +10% Luck).
- **Event:** Burza Magnetyczna co 10 min (Luck ×2 przez 90 s).

## Balans

Wszystkie liczby są w `src/shared/Config.luau`. Ceny pochodzą z symulacji
200 graczy (z 15% utraconych łupów i 40% przestojów):

| Kamień milowy | Mediana czasu gry |
| --- | --- |
| Magnes Głośnikowy ($300) | ok. 3 min |
| Strefa 2 — Neodym N35 ($10K) | ok. 13 min |
| Strefa 3 — Neodym N52 ($500K) | ok. 50 min |
| Strefa 4 — Magnes „Czołg” ($30M) | ok. 3 h |
| Strefa 5 — Czarna Dziura ($2B) | ok. 11 h |
| Rebirth 1 ($5B) | ok. 14–15 h |

Do testów: `Config.Debug.LuckMultiplier = 50` szybko pokazuje Secret/Mythic,
a w Studio przycisk **DEV x10 $** mnoży gotówkę.

## Struktura

```
src/shared/   Config (balans), Brainrots (katalog), Loot (losowanie/wycena), Geo (mapa), Format
src/server/   init (start), MapBuilder, Session (DataStore), Inventory (niesione przedmioty),
              Garage (stojaki/CPS), Fishing, Steal (Tug-of-War), Hazards (banany/woda/łup), Shop, Events
src/client/   init, UI (HUD), Minigame, Tug, ShopUI, IndexUI, Tools, Effects
```

Serwer jest jedynym źródłem prawdy: losuje łup w chwili rzutu, sprawdza zasięg,
cooldowny, miejsce w plecaku, minimalny czas minigry i odległość przy kradzieży.

## Przed publikacją (świadome uproszczenia prototypu)

- Modele Brainrotów są składane z prymitywów, a dźwięki to wbudowane pliki
  Robloxa — podmień na własne assety (`Config.Sounds`).
- Zapis to prosty `GetAsync`/`UpdateAsync` bez blokady sesji — na produkcję
  przejdź na ProfileStore, żeby wykluczyć duplikację przy szybkim przeskakiwaniu
  między serwerami.
- Ocena trafienia w takt przy przeciąganiu liny jest raportowana przez klienta;
  przed publikacją warto dodać serwerową kontrolę statystyk (np. podejrzanie
  długie serie PERFECT).
- Brak monetyzacji (gamepassy, boostery Luck) i NPC z samouczka — tylko
  komunikaty startowe.
