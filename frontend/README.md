# Ark-ERP Flutter client

Web, desktop and Android client for the Ark-ERP API (`/api/v1`).

## Pointing the app at the API

The API address is chosen at build time with `--dart-define` (see `lib/core/config/app_config.dart`):

| Profile | Command flags | API address |
|---|---|---|
| Android emulator | `--dart-define=API_ENV=emulator` (default for Android debug) | `http://10.0.2.2:3000/api/v1` |
| Physical phone on the same Wi-Fi | `--dart-define=API_ENV=device --dart-define=API_HOST=<PC Wi-Fi IP>` | `http://<PC IP>:3000/api/v1` |
| Desktop / web on the same PC | `--dart-define=API_ENV=local` (default for desktop/web) | `http://localhost:3000/api/v1` |
| Production | `--dart-define=API_ENV=production --dart-define=API_BASE_URL=https://api.example.com` | must be HTTPS |

`API_BASE_URL` always overrides the profile. In debug/profile builds the address can also be changed on the
device from the sign-in screen (**Server: …** → enter `192.168.x.x:3000` → **Test connection** → **Save**).
Release builds only accept HTTPS and allow plain HTTP nowhere (`android/app/src/main/res/xml/network_security_config.xml`);
plain HTTP is enabled for debug builds only (`android/app/src/debug/res/xml/network_security_config.xml`).

## Running on a physical Android phone

1. Start the backend (`cd backend && npm run start:dev`); it listens on all interfaces, port 3000.
2. Find the PC's Wi-Fi IPv4 address: `ipconfig` → *Wireless LAN adapter Wi-Fi* → *IPv4 Address*.
3. Allow inbound TCP 3000 on the PC firewall (once, in an **administrator** PowerShell):
   `New-NetFirewallRule -DisplayName "Ark-ERP API 3000" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow -Profile Private`
4. Connect the phone to the same Wi-Fi (Private network profile on the PC), then
   `flutter run --dart-define=API_ENV=device --dart-define=API_HOST=<PC IP>`
   or build `flutter build apk --debug --dart-define=API_ENV=device --dart-define=API_HOST=<PC IP>`.
5. Check from the phone's browser that `http://<PC IP>:3000/api/v1/tenant-discovery` returns JSON.

## Tests

```bash
flutter analyze
flutter test                      # unit + widget tests (no backend needed)
LIVE_TEST_PASSWORD=<seed password> \
LIVE_TEST_ACCOUNTS="SCHOOL_ADMIN=admin@school.test,PARENT=parent@school.test" \
  flutter test --tags live --run-skipped test/live   # against a running backend
```

## Structure

- `lib/core/config` – API environment resolution and the saved server override
- `lib/core/network/api_client.dart` – Dio client, readable errors, single-flight token refresh
- `lib/core/auth` – sign-in, secure session storage (Android Keystore), restore/expiry/logout, roles
- `lib/core/navigation/role_navigation.dart` – which screens each of the 8 roles can open
- `lib/core/widgets/mobile_shell.dart` – phone layout (bottom bar + drawer); tablets/desktop use `shell_layout.dart`
- `lib/features/home` – role-specific phone home dashboards built from live API data
