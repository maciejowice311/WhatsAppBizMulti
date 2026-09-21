# WhatsAppBizMulti — Tweak dla WhatsApp Business

Multi-container toolkit: random GPS spoof, IDFV rotation, JB bypass, Crane integration.

## Wymagania

- Jailbreak (Dopamine 2, iOS 15.0–16.6.1, A12+)
- Theos zainstalowany
- Crane ($4.99, Havoc repo) — do klonowania WhatsApp Business
- WhatsApp Business zainstalowane z App Store

## Instalacja Theos (jeśli nie masz)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
export THEOS=~/theos
```

## Kompilacja i instalacja

```bash
cd WhatsAppBizMulti
export THEOS=~/theos
export THEOS_DEVICE_IP=192.168.1.X   # IP twojego iPhone
make package THEOS_PACKAGE_SCHEME=rootless
make install
```

Albo ręcznie:
```bash
make package THEOS_PACKAGE_SCHEME=rootless
# Plik .deb pojawi się w folderze packages/
# Prześlij przez Sileo lub filza
```

## Konfiguracja w Ustawieniach

1. Otwórz **Settings.app → WhatsAppBizMulti**
2. **Enable JB Bypass** — WŁĄCZ (ukrywa jailbreak przed WhatsApp)
3. **Enable Random GPS** — WŁĄCZ
4. **Center Latitude** — np. `52.2297` (Warszawa)
5. **Center Longitude** — np. `21.0122` (Warszawa)
6. **Radius (km)** — np. `10` (losowy punkt w promieniu 10 km od centrum)
7. **Enable IDFV Spoof** — WŁĄCZ
8. **Custom IDFV UUID** — wygeneruj: `uuidgen` w terminalu iPhone
9. **Randomize Timing** — WŁĄCZ (dodaje losowe opóźnienia przy klikaniu/pisaniu)

## Konfiguracja z Crane

1. Otwórz **Crane → WhatsApp Business**
2. Stwórz kontenery: **Container 1**, **Container 2**, **Container 3**...
3. Dla każdego kontenera:
   - Wejdź w kontener → włącz **Tweak Injection**
   - W Ustawieniach → WhatsAppBizMulti ustaw **INNE** wartości:
     - Inny IDFV UUID (`uuidgen` w terminalu)
     - Inny środek GPS (inne miasto!) lub ten sam — random i tak wybierze inny punkt
     - Inny promień (opcjonalnie)

## Jak działa Random GPS?

Za każdym razem gdy WhatsApp Business pyta o lokalizację, tweak generuje **NOWY losowy punkt** w okręgu o zadanym promieniu wokół punktu centralnego.

Np. centrum = Warszawa (52.2297, 21.0122), promień = 10 km:
- Container 1 → (52.2345, 21.0089)
- Container 2 → (52.2189, 21.0256)
- Container 3 → (52.2412, 21.0012)

Każde otwarcie aplikacji = nowe losowe współrzędne!

## Uwagi i ograniczenia

| Funkcja | Status |
|---------|--------|
| Jailbreak bypass | Działa |
| Random GPS spoof | Działa — nowe współrzędne za każdym razem |
| IDFV spoof | Działa |
| Behavioral randomization | Działa |
| WhatsApp end-to-end encryption | NIE można przechwycić (Signal Protocol) |
| WhatsApp server-side ban | Tweak tego NIE obchodzi — używaj dobrego proxy |

## Troubleshooting

- **Tweak nie ładuje się**: sprawdź czy WhatsAppBizMulti.plist ma `com.whatsapp.WhatsAppSMB`
- **Crash WhatsApp**: wyłącz funkcje jedna po drugiej w ustawieniach
- **GPS nie działa**: sprawdź czy WhatsApp ma uprawnienia do lokalizacji w iOS Settings
- **Stary IDFV nadal widoczny**: wyloguj się z WhatsApp, wyczyść dane kontenera w Crane, zaloguj ponownie

## Stack polecany

- Dopamine 2 + HideJailbreak (bypass JB detekcji systemowej)
- Choicy (kontrola injection per-app)
- Shadow v3 (dodatkowy bypass)
- Crane (app cloning)
- WhatsAppBizMulti (ten tweak)
- Shadowrocket / Quantumult X (proxy per-app — osobno!)
