# Royal Arena: izvještaji po fazama

Okruženje u kojem je rađen razvoj: Linux kontejner, Godot 4.3 (headless + Xvfb sa softverskim OpenGL-om).
Svi screenshotovi i mjerenja napravljeni su iz stvarne igre alatima iz `Tools/`.

---

## FAZA 1: struktura, arena, čudovišta, prizivanje, borba, kule

**Završeno**
- Godot 4.3 projekat (Compatibility renderer: radi na PC-u i Androidu), portret layout 9:16.
- Modularna struktura: `Scenes/`, `Scripts/`, `Assets/`, `Data/`. Podaci o kartama su u `Data/Cards/*.tres` (`MonsterData`), odvojeni od logike.
- Arena: zelena trava s pločicama i stazama, plava rijeka (animirani shader), dva kamena mosta s lampama,
  dva mala vodopada sa stijenama i pjenom, drveće, stijene, grmlje, cvijeće, gljive, zidovi i dvorski zid iza kraljeve kule.
- Kamera pod ~70° koja automatski uklapa cijelu arenu između gornje trake i panela s kartama, za bilo koji omjer ekrana, uz blago treskanje ekrana pri udarcima.
- 6 kula (2 princess + 1 king po strani). Princess kule imaju strijelca, a kraljeva kula kralja s topom. Kralj spava dok ga ne pogodiš ili dok ne padne princess kula.
- Prizivanje, kretanje (pronalazi most), kolizije (jedinica–jedinica, jedinica–kula, rijeka, granice), ciljanje, napad i šteta.

**Modeli (originalni, proceduralni, chibi stil: velika glava i velike oči)**

| Čudovište | Silueta / detalji | Napad | Posebna animacija pri odabiru karte |
|---|---|---|---|
| Fire Knight | crveno-zlatni oklop, šlem s otvorenim licem, plamena perjanica, plašt, ogroman vatreni mač | sječa iznad glave, vatreni luk + splash | podiže mač i skače |
| Shadow Assassin | kapuljača s lisičjim ušima, svijetleće cijan oči, maska, magenta šal, dva ljubičasta bodeža | brzi dvostruki rez, prvi udarac x2 | skok s okretom i vrtnjom bodeža |
| Stone Golem | ogroman škriljac-kamen, mahovina s cvijećem, kristali na leđima, ogromne šake, smiješne oči | udarac obje šake u tlo, udarni val, potres | lupa se u prsa i riče |
| Frost Dragon | debeljuškasti plavi zmajić, ledeni rogovi, prozirna krila, kristal na repu | trzaj glave i ledeni projektil (splash + usporavanje 35%) | salto u zraku |
| Poison Witch | ogroman savijeni šešir, kosa boje mente, nestašan osmijeh, štap s otrovnom kuglom | zamah štapom, otrovna kugla (otrov 32 dmg/s, 3 s) | vrti štap i poskakuje |

Svaki model ima animacije Idle, Walk/Run/Fly, Attack, Hit (bijeli bljesak + spljoštavanje) i Death (skok, prevrtanje, nestajanje), treptanje očiju i particle efekte.

**Greške pronađene i ispravljene**
- Rim-light je kamene materijale (Golem, kule) prikazivao gotovo bijelim. Rim je smanjen za hrapave materijale, a Golem je dobio prepoznatljivu škriljac-plavu boju.
- Krila zmaja su odozgo izgledala kao tanke linije. Promijenjeni su ugao i opseg mahanja i povećane membrane.
- Vanjska livada je prekrivala rijeku. Napravljen je otvor za korito.

---

## FAZA 2: karte, elixir, AI, funkcionalna bitka

**Završeno**
- 5 karata u donjem panelu: ilustracija renderovana iz pravog 3D modela, okvir u boji rijetkosti (legendarna se presijava), elixir kap s cijenom, ime i level.
- Odabir karte tapom ili drag & dropom. Ponovni tap na kartu ili desni klik poništava odabir.
  Pri odabiru se iznad karata pojavljuje 3D pregled čudovišta s posebnom animacijom, a u areni „ghost” s domet-krugom i crvenom zonom gdje se ne smije postaviti.
- Elixir: start 5, maksimum 10, +1 svakih 2.8 s, dupli elixir u zadnjoj minuti. Karta je siva dok nema dovoljno elixira. Bar ima 10 segmenata i brojač.
- Meč traje 3:00, zatim dolazi produžetak 1:00 (sudden death), pa tie-break po najoštećenijoj kuli. Krune: 1 po princess kuli, 3 za kraljevu kulu (trenutna pobjeda).
- Kad padne princess kula, otvara se „džep” u toj traci gdje pobjednik smije postavljati jedinice.
- Protivnički AI (jedan nivo težine):
  - procjenjuje prijetnje na svojoj polovini;
  - bira kontru po formuli (brzina ubijanja naspram preživljavanja, imunitet na zrak, cijena);
  - brani se između prijetnje i kule;
  - napada naizmjenično teškim tank-pushom (Golem + podrška iza) i brzim pushom preko mosta;
  - kažnjava protivnika kad ostane bez elixira (s pauzom između dva takva napada) i nikad ne „sjedi” na punom elixiru.
- Zvuk: 22 proceduralno sintetizovana efekta i 2 muzičke petlje (`Tools/generate_sfx.py`).

**Greške pronađene i ispravljene (log AI odluka)**
- „Punish” taktika se okidala skoro stalno, pa je AI spamovao Assassina. Uvedena je pauza od 25 s i stroži uslovi.
- Bonus za raznovrsnost se dodavao i kartama koje uopšte ne mogu pogoditi metu (Assassin protiv zmaja). Ispravljeno.
- AI nikad nije igrao Golema. Uvedeni su naizmjenični tipovi napada, pa AI sada koristi svih 5 karata.

---

## FAZA 3: meniji

**Završeno**
- **Glavni meni**: 3D kraljevstvo (zamak s kulama i zastavama, selo, rijeka, lebdeća ostrva, oblaci, kamera se polako njiše), logo ROYAL ARENA, profil (level, XP bar, trofeji), gold i gems, Battle Deck, veliko pulsirajuće BATTLE dugme, 4 slota za chestove s pravim tajmerima otključavanja, donja navigacija (Shop, Cards, Battle, Quests) i Quests popup sa značkom.
- **Cards meni**: svih 5 karata s brojem kopija. Detaljni prikaz ima 3D model koji se vrti i izvodi posebnu animaciju, rijetkost, level, ulogu, opis i statistike (elixir, HP, damage, DPS, attack speed, attack range, brzina kretanja, mete, freeze/poison/ambush) te dugme Upgrade (kopije + gold).
- **Shop**: Daily Deals (mijenjaju se svaki dan), Special Offers, Chests (otvaraju se odmah, uz animaciju), Cards, Gold i Gems.
  Sve kupovine su simulirane lokalnom valutom, a gemovi su „FREE (test)”.
- **Victory**: zlatni zraci, konfete, krune koje padaju jedna po jedna, brojanje trofeja i golda, osvojeni chest, Continue.
- **Defeat**: hladna paleta, izgubljeni trofeji, Try Again i Menu.
- Ekonomija se snima u `user://save.cfg`: trofeji (+30 / −20), gold, XP i level, kopije i leveli karata (+10% HP i damage po levelu), chestovi, dnevni questovi.

---

## FAZA 4: optimizacija, animacije, efekti, zvuk, rezolucije

**Optimizacija (izmjereno u `Tools/Perf.tscn`, gužva od 19–20 jedinica)**

| | Prije | Poslije |
|---|---|---|
| MeshInstance3D | 1927 | 200 |
| Draw-callovi (max) | 6350 | ~1570 |

- Statičko spajanje mesheva (`MeshBatcher`) primijenjeno je na arenu i meni-kraljevstvo.
- Svaki model čudovišta i kule pretvara se u jedan skinovani mesh sa `Skeleton3D` (`SkinBaker`): zglobovi postaju kosti, a dijelovi iste boje jedan surface.
- „Hit flash” overlay se dodaje samo dok je vidljiv (prije je bio stalni dodatni prolaz).
- Smanjen je broj poligona dekoracija i sfera.

**Rezolucije provjerene screenshotovima**: 720×1280, 1080×2400 (telefon 20:9), 1536×2048 (tablet), 1600×900 (PC landscape).
Na landscapeu su ispravljene veličina health barova, preklapanje karata s elixir barom i odsječena navigacija u meniju.

---

## Obavezni testovi (automatski, `Tests/TestRunner.tscn`): **121 / 121 prolazi**

| # | Test | Rezultat |
|---|---|---|
| 1 | Svih 5 karata se pravilno prikazuje (podaci, ilustracije, cijene, 5 widgeta u HUD-u) | ✅ |
| 2 | Svaka karta priziva odgovarajuće čudovište i naplaćuje tačnu cijenu; zabranjena polovina odbijena | ✅ |
| 3 | Svih 5 čudovišta se kreće, prelazi rijeku samo preko mosta (zmaj leti pravo) | ✅ |
| 4 | Svako čudovište ima različit napad (melee/projektil, splash, slow, poison, ambush) | ✅ |
| 5 | HP se smanjuje za tačan damage; smrt i uklanjanje jedinice | ✅ |
| 6 | Kule napadaju zemaljske i zračne jedinice; kruna; buđenje kralja; otvaranje trake | ✅ |
| 7 | Elixir: start, regeneracija, max 10, odbijanje bez elixira, dupli elixir | ✅ |
| 8 | AI igra karte, troši elixir, brani pravu traku, koristi svih 5 karata | ✅ |
| 9 | Pobjeda, poraz, pobjeda na krune po isteku vremena, produžetak, cijeli AI-vs-AI meč do kraja | ✅ |
| 10 | Svi meniji se učitavaju i njihovi tokovi rade (questovi, chest, upgrade, kupovina, result ekrani) | ✅ |

## Šta NIJE urađeno ili ograničenja (iskreno)

- **Meshy AI nije korišten.** API traži plaćeni plan i ključ, a kredite nisam kupovao. Svi modeli su originalni proceduralni modeli.
  Sistem je spreman za zamjenu GLB-om (`Docs/MESHY_PIPELINE.md`, gotovi promptovi).
- Materijali su PBR bez teksturnih mapa (boja, hrapavost, metal, rim i outline). Nema ručno slikanih tekstura.
- Animacije su proceduralne (kod pomjera kosti). Nisu ručno keyframeovane.
- Android build nije napravljen ni testiran na uređaju: ovdje nema Android SDK-a ni export templatea. Mobilni ekrani su testirani samo kroz rezolucije.
- Performanse su mjerene softverskim GPU-om, pa frame-time ne predstavlja pravi telefon. Draw-callovi i broj poligona jesu stvarni.
- Zvukovi su jednostavni sintetizovani efekti, nisu studijski.
- Jedan nivo težine AI-a, bez multiplayera.
- Na landscape ekranu (PC) arena je manja. Igra je dizajnirana za portret prozor.
