# MeetSpace Mobile

Flutter Android/iOS room booking client for the existing MeetSpace Laravel API. One app serves employees and permission-authorized approvers.

## Scope

- Home: today's confirmed meetings, next approved personal booking, recent booking notifications, approver shortcut.
- Schedule: day/week/month agenda and month date picker, organizer-department and room filters, display-safe meeting summaries.
- Rooms: date/time, capacity, location/name and resource search, room details and schedule, focused booking flow.
- My Bookings: server-paginated upcoming/ongoing/previous, draft/save/submit, edit pending/draft/revision, cancel, check in/out, extend, history, staff attendees, attachments.
- More: approvals (permission-based), booking notification center, staff profile, English/Khmer, password change, sign out.

Personal schedules, invitations/RSVP, recurring meetings, room relocation, staff/role/room administration, reports, exports, audit investigation, and display configuration are outside this release. Staff attendees are booking records; guests are included in the total attendee count. Guest names/contact entry is not collected by this client. Editing an already approved booking stays on the web to avoid silently releasing approval.

## Run

Start the existing MeetSpace backend first. It must include the companion mobile API changes described in `MeetSpace/docs/mobile-scope.md`.

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` reaches the Windows host from the standard Android emulator. For a physical Android device, use the host's reachable LAN address. For an iOS simulator use the API host reachable from your Mac. iOS development needs macOS/Xcode; this Windows project includes iOS source but cannot build it locally.

For a deployed installation:

```powershell
flutter run --release --dart-define=API_BASE_URL=https://meetspace.example.gov/api/v1
```

The example deployment hostname must be replaced with the actual API hostname. Android permits HTTP only in the debug manifest; release expects HTTPS. iOS follows normal ATS restrictions and needs HTTPS unless a narrowly scoped development exception is configured locally. Never put credentials in dart defines or source.

## Verify

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Build output: `build/app/outputs/flutter-apk/app-debug.apk`. This is a development APK. Configure an installation-specific Android application ID, iOS bundle identifier, release signing, and store/internal distribution before release. The template's debug signing configuration is retained for local development only.

## Architecture

`lib/core` owns the API transport, repository, secure session, configured timezone, translations, attachments, and theme. `lib/features` owns authentication, navigation, schedule/home, room discovery, booking forms/details/approvals, notifications/settings. `lib/shared` contains reusable cards, feedback, status, dialogs, and loading/error states. Views call a repository rather than raw HTTP.

- Sanctum bearer token stored using OS-backed secure storage; no plaintext credential preferences and no persisted meeting cache.
- Session expiry clears navigation and private session data; disabled accounts are rejected by the API on subsequent requests.
- Timezone comes from the installation API (default `Asia/Phnom_Penh`); UTC on the wire, installation wall time in inputs and display. A non-default backend timezone should also be supplied using `--dart-define=APP_TIMEZONE=...` for initial startup.
- Foreground home/schedule/bookings refresh every 45 seconds and on resume. Notification center refreshes on the same session signal. Pull-to-refresh and explicit retries remain available. OS push notifications are not configured.
- Network mutations are never automatically retried. After a timeout, inspect My Bookings before repeating a submission. Buttons are disabled during writes.
- Attachments: up to five new files, 10 MB each; matching backend MIME validation remains authoritative. Downloads use authorization headers and private temporary storage, cleared on sign-out/session expiry. An external viewer receives only the selected file; files copied by an external viewer are outside app control.
- English/Khmer strings are in `assets/i18n`; API validation text can still arrive in English. Noto Sans / Noto Sans Khmer fonts are bundled with their OFL licenses.

Dependencies are limited to HTTP transport, secure OS storage, Flutter localization/Intl, IANA timezone data, native file picking, temporary storage, and opening attachments. State uses Flutter's ChangeNotifier and per-feature state; no additional state framework is required at this scale.

## Testing limits

Mocked HTTP/widget tests exercise permissions, validation, approval reasons, schedule modes, Khmer layout, connectivity, session expiry, and timezone conversion. Backend feature tests verify actual authorization, availability filters, booking-only schedules, and detail redaction. iOS compilation and physical-device attachment viewer behavior require their respective devices.

## Verification checkpoint

On 2026-11-05, static analysis and 10 mobile tests passed, including keyboard focus and booking conflict recovery. English/Khmer phone and tablet previews were inspected. The companion backend passed 39 tests. Android APK compilation and live emulator verification remain unconfirmed because native dependency downloads stalled before the work was interrupted. iOS compilation has not been performed.
