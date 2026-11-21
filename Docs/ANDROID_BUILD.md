# Android build (APK)

Export postavke su već u projektu (`export_presets.cfg`, preset **Android**):
- paket `com.royalarena.game`, verzija 0.1.0;
- arm64-v8a, uspravna orijentacija, immersive mode;
- Compatibility renderer, ETC2/ASTC teksture;
- ikone u `Assets/UI/icon_*.png`.

Godot je provjerio preset: nedostaju samo export template-i i Android SDK.

## Jednokratno podešavanje (na tvom računaru)

1. **Godot 4.3**: Editor → Manage Export Templates → *Download and Install* (4.3.stable).
2. **Java JDK 17** (npr. Temurin 17).
3. **Android SDK**: najlakše preko Android Studija (SDK Platform 34, Build-Tools 34, Platform-Tools,
   Command-line Tools).
4. U Godotu: Editor → Editor Settings → Export → Android:
   - **Java SDK Path**: folder JDK 17;
   - **Android SDK Path**: npr. `C:\Users\<ti>\AppData\Local\Android\Sdk`.

   Debug keystore Godot napravi sam.

## Izrada i pokretanje

- **APK**: Project → Export… → Android → *Export Project* → `build/android/RoyalArena.apk`.
- **Direktno na telefon**: uključi *Developer options → USB debugging*, poveži telefon kablom
  i u Godotu klikni Android ikonu (Remote Debug) gore desno.

## Šta javiti nakon testa

- Model telefona i koliko je glatko (osjećaj ili FPS iz Debug → Monitor).
- Da li se karte lako biraju i prevlače prstom.
- Da li je nešto odsječeno na ekranu (notch, zaobljeni uglovi).

## Performanse (već urađeno)

- Mesh LOD prag 6 px: ~38% manje trouglova u gužvi, bez vidljive razlike na kameri bitke.
- Meshy teksture: max 1024 px, VRAM kompresija.
- Statično spajanje dekoracija arene i jedan skinovani mesh po modelu.
