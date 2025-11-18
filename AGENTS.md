# AGENTS.md

_LinkStack monorepo briefing — generated 18 Nov 2025 for GPT-5 Codex agents._

---

## 1. Product Snapshot

- **What this is:** A Laravel 9 (PHP 8+) application that powers LinkStack, an open‑source Linktree alternative with user‑hosted profile pages, an admin “panel”, and a themed front end (see `README.md` for public messaging, `LICENSE` for GPL‑3.0 obligations, `version.json` for build number `4.8.4`).
- **Key concepts:**  
  - Public link pages rendered from Blade (`resources/views/linkstack/*`) using data from `links`, `buttons`, `pages`, `users`, and `UserData`.  
  - Authenticated “Studio” for end users (`routes/web.php` → `/studio/*`) to curate links, upload assets, configure icons, backgrounds, and themes.  
  - Admin console (`/dashboard`, `/admin/*`) for statistics, configuration, page content, theme lifecycle, backup/update orchestration, and impersonation.
- **Compliance:** GPL requires that downstream consumers keep source available; ensure modifications retain notices.

---

## 2. Tech Stack & Major Packages

| Layer | Key tooling | Notes / files |
| --- | --- | --- |
| Backend | Laravel ^9.52 (`composer.json`), PHP ≥ 8.0 | Standard MVC, uses `routes/web.php`, `app/Http/*`, `app/Models/*`. |
| Packages | `awssat/laravel-visits` (analytics), `simplesoftwareio/simple-qrcode` (QR), `livewire/livewire` + `rappasoft/laravel-livewire-tables` (interactive tables), `spatie/laravel-backup`, `geo-sot/laravel-env-editor`, `laravel/socialite`, `cohensive/oembed`, `jeroendesloovere/vcard`, `guzzlehttp/guzzle`. | Review composer constraints when upgrading PHP or Laravel. |
| Frontend build | Laravel Mix 6 (`webpack.mix.js`), Tailwind 2, Alpine.js optional, Axios/Lodash (`resources/js/app.js`). | CSS entry is `resources/css/app.css`. JS compiled to `public/js/app.js`. |
| Static assets | Pre-built CSS/JS, icons, fonts under `assets/` (Hope UI dashboard theme, LinkStack brand pack, button editor dependencies). | Many admin screens load assets directly from `assets/` rather than Mix pipeline. |

---

## 3. Directory Map & Ownership

| Path | Purpose | Hot files |
| --- | --- | --- |
| `app/Console/Commands/` | CLI helpers for translations (`Translate.php`, `CheckTranslations.php`). | Keep tokens safe; both scripts hit external services. |
| `app/Functions/functions.php` | Global helper set (asset discovery, `findAvatar`, `footer`, block helpers). | Any helper used in Blade is declared here and autoloaded via `composer.json`. |
| `app/Http/Controllers/` | Core controllers (Installer, User, Admin, Auth, LinkType). | `UserController.php`, `AdminController.php` are the deepest files; read fully before touching flows. |
| `app/Http/Middleware/` | Request guards (HTTPS forcing, cookie stripping, impersonation overlay, user caps). | `DisableCookies.php`, `Headers.php`, `Impersonate.php`, `LinkId.php`. |
| `app/Http/Livewire/UserTable.php` | Livewire user list powering `/admin/users`. | Extends Rappasoft table, defines columns/formatting. |
| `app/Models/` | Eloquent models. | `User`, `Link`, `Button`, `Page`, `LinkType` (filesystem-backed), `UserData` (JSON store). |
| `blocks/` | Declarative “link types”. Each subfolder provides `config.yml`, `form.blade.php`, `handler.php`, optional `display.blade.php`. | Loader defined in `LinkType` model and `LinkTypeViewController`. |
| `database/migrations/`, `database/seeders/` | Schema and seed data (admin user, button catalog, default pages). | Review 2022–2023 migrations for schema expansions (`type_params`, social logins). |
| `public/` equivalents | The project serves from root (`index.php`, `server.php`). Shared hosting copies contents directly to web root—keep permissions in mind. |
| `resources/views/` | Blade templates for home/demo, installer, Studio, admin panel, link pages, updater, emails. | See sections below for layout hierarchy. |
| `resources/lang/` | Localized `messages.php` (14 locales). | Extend via translation commands. |
| `resources/css|js/`, `webpack.mix.js` | Build inputs for Mix/Tailwind. | Minimal custom JS; most UI uses vendor assets. |
| `themes/` | Packaged front-end themes with `config.php`, CSS, optional custom code fragments. | Default `galaxy`, `PolySleek`. |
| `assets/` | Deployed static bundle (Hope UI CSS, icons, fonts, button editor, brand imagery). | Many references use `asset('assets/...')`; keep structure stable. |
| `storage/templates/advanced-config.php` | Default template copied to `config/advanced-config.php` on first boot. | Defines meta tags, custom buttons, analytics injection settings. |

---

## 4. Bootstrapping & Configuration Flow

1. **Entry point** – `index.php` lives at repo root and runs the usual Laravel bootstrap. On first run it also verifies PHP extensions if `INSTALLING` flag exists.
2. **Installer guard** – `routes/web.php` immediately branches:  
   - If `INSTALLING` or `INSTALLERLOCK` exists, only the installer routes (rendered via `resources/views/installer/installer.blade.php`) are served.  
   - Once a first admin is created, `INSTALLING` is removed and `storage/app/ISINSTALLED` is dropped to mark completion.
3. **`.env` & EnvEditor** – Configuration entries are mutated at runtime through `GeoSot\EnvEditor` (see `app/Http/Controllers/AdminController::editConfig()` and `resources/views/components/config/config.blade.php`). Admin UI exposes toggles for boolean env keys as well as a full-text `.env` editor (`components/config/alternative-config`). **Never edit `.env` directly in production without coordinating with EnvEditor** – its cache assumes it owns the file.
4. **Advanced config** – `config/advanced-config.php` extends the normal config bag with theme/homepage customization (meta tags, `custom_domains`, custom buttons, `custom_url_prefix`, etc.). The admin UI exposes this file via Ace editor (`components/config/advanced-config`). Default template is under `storage/templates` and is auto-copied if missing.
5. **Pre-update & Finishing scripts** – Two Blade partials do heavy lifting outside the Laravel lifecycle when you click “Update” or after an update:  
   - `resources/views/components/pre-update.blade.php` runs before pulling new code, ensuring schema changes exist (adds `links.type`, `type_params`, sets `storage/RSTAC`).  
   - `resources/views/components/finishing.blade.php` runs after updates to add new env keys, rebuild `buttons` via seeders, migrate legacy assets, and ensure advanced config defaults. **If you add new env/config keys or structural migrations, wire them here so upgrades remain hands‑free.**
6. **Updater view** – `resources/views/update.blade.php` orchestrates downloads from the primary or beta update servers via HTTP (see env keys `UPDATE_SERVER`, `BETA_SERVER`, `JOIN_BETA`). It uses `pre-update`/`finishing`, writes `storage/update.zip`, extracts, then cleans up.
7. **Maintenance mode** – `resources/views/maintenance.blade.php` renders when `MAINTENANCE_MODE` is true or `storage/framework/maintenance.php` exists. Admins get quick links to disable the mode.
8. **Home routing** – `routes/home.php` decides what `/` serves (`home` hero page, custom user page via `HOME_URL`, redirect, or disabled). It also handles per-domain overrides described in `config/advanced-config.php` under `custom_domains`.

---

## 5. Database Schema & Models (see `database/migrations/*`)

| Table | Columns (abridged) | Used by | Notes |
| --- | --- | --- | --- |
| `users` | `id` (custom randomizable), `name`, `email`, `password` (nullable for social), `littlelink_name/description`, `role` (`user`, `vip`, `admin`), `block`, `theme`, `auth_as`, timestamps. | `User` model implements `MustVerifyEmail`. | Random IDs controlled via `config('linkstack.*')` toggles; `auth_as` enables impersonation. |
| `buttons` | `name`, `alt`, `exclude`, `group`, `mb`. | `Button` model + `ButtonSeeder`. | Button `id` referenced everywhere; ID 94 reserved for user-defined social icons. |
| `links` | `id`, `user_id`, `button_id`, `title`, `link`, `order`, `click_number`, `up_link`, `custom_css`, `custom_icon`, `type`, `type_params` (JSON), timestamps. | `Link` model, `UserController`. | `type/type_params` describe block metadata; `type_params` also stores booleans such as `custom_html`. |
| `pages` | `terms`, `privacy`, `contact`, `home_message`, `register`. | `Page` model, `AdminController::showSitePage`, public `pages.blade.php`. | Admin UI uses CKEditor for editing. |
| `social_accounts` | `user_id`, `provider_name`, `provider_id`. | `SocialAccount` model, `Auth\SocialLoginController`. | Maintains Socialite link. |
| `visits` | Provided by `awssat/laravel-visits` – `primary_key`, `secondary_key`, `score`, `list`, `expired_at`. | Stats in `AdminController`/`UserController`. | Keep table trimmed if volume grows. |
| `password_resets`, `failed_jobs`, `personal_access_tokens`, etc. | Default Laravel tables. | — | — |
| `UserData` pseudo-table | Actually reuses `users.image` column to store JSON, cached via `Cache::remember`. | `UserData` helper writes per-user “flags” (share button disable, checkmark, open links in tab, notifications). | Understand this before repurposing the `image` column—non-file values sit inside JSON. |

> **Seeds:** `database/seeders/AdminSeeder.php` (default admin account), `ButtonSeeder.php` (button catalog), `PageSeeder.php` (Terms/Privacy/Contact boilerplate). Installer runs seeds when empty.

---

## 6. Routing & Middleware Highlights

- **Public scope** (`routes/web.php`, `routes/home.php`):  
  - `@{littlelink}` and optional `/{custom_prefix}{handle}` render link pages via `UserController::littlelink()`.  
  - `/going/{id}` increments click counts (`UserController::clickNumber()`) and respects `+` suffix to show `/info/{id}`.  
  - `/theme/@{handle}` exposes theme metadata (`components/theme.blade.php`).  
  - `/pages/{terms|privacy|contact}` serve CMS content.  
  - `/report` GET/POST for abuse reports.  
  - `/demo-page` loads marketing preview (`HomeController::demo`).  
  - `/block-asset/{type}` streams block-specific static files (`LinkTypeViewController::blockAsset()` sanitizes type/extension).
- **Auth group** (`Route::middleware(['auth','blocked','impersonate'])`):  
  - Nested `env('REGISTER_AUTH')` (either `auth` or `verified`) gate for user Studio actions.  
  - `/dashboard` drives both admin and user dashboards.  
  - `/studio` namespace exposes link management (add/edit/sort), theme tools, profile page, icon editor, import/export, background uploader, etc.  
  - `/export-*` and `/import-data` guarded by `ALLOW_USER_EXPORT/IMPORT`.  
  - `LinkId` middleware enforces ownership for link operations.
- **Admin-only group** (adds `admin` middleware):  
  - `/admin/users` (Livewire table), `/admin/edit-user/{id}`, `/admin/pages`, `/admin/config` (env + advanced config), `/admin/site` (logos/home message), `/admin/theme` (delete), `/auth-as/{id}`, `/update/theme`, `/update`, `/backup`.  
  - Resource routes for Link Types (`Admin\LinkTypeController`) still write to database.
- **Middleware** (`app/Http/Middleware`):  
  - `DisableCookies` strips session cookies for public pages when `disableCookies` middleware is applied (prevents storing sessions for visitors).  
  - `Headers` optionally enforces HTTPS by `FORCE_HTTPS` (global) and `FORCE_ROUTE_HTTPS` (redirect).  
  - `CheckBlockedUser` redirects blocked users to `/blocked`; also enforces `MAINTENANCE_MODE` for non-admins.  
  - `MaxUsers` enforces user caps via `config('linkstack.user_cap')` (configure file manually because there is no default!).  
  - `Impersonate` reads `users.auth_as` to auto-login as another user and renders a persistent bar with exit action.  
  - `LinkId` ensures the requesting user owns the link ID in path.

---

## 7. Controllers & Service Responsibilities

### InstallerController (`app/Http/Controllers/InstallerController.php`)
- Multi-step installer that configures DB credentials, seeds admin via `.env` writes (`EnvEditor`), and toggles `INSTALLERLOCK`.
- Provides helper actions for MySQL testing, skipping steps, editing config prior to finishing.

### UserController (`app/Http/Controllers/UserController.php`)
- One of the most complex classes; handles:
  - Dashboard stats using `visits()` helper.
  - CRUD for links, including custom “link type” flow. `saveLink()` loads handler PHP from `blocks/{typename}/handler.php`, merges validated data, splits `type_params`.
  - Sorting links via AJAX and `order` column.
  - VCard generation (`jeroendesloovere/vcard`), `clickNumber` redirect, share/report endpoints, theme previews, background uploads (with optional Imagick compression), custom icon management (button id 94), user deletion (self‑service only and not admin #1).
  - Profile editing (name/email/password, share button toggles via `UserData`).
  - Import/export JSON (links + optional base64 avatar). `importData()` sanitizes HTML and rewrites avatars.
  - Report submissions send `ReportSubmissionMail`.

### AdminController (`app/Http/Controllers/AdminController.php`)
- Provides admin dashboard stats (global counts + per-user visits).  
- Manages users (block/verify toggle, impersonation, admin-created dummy accounts).  
- Site customization (logo/favicon uploads stored in `assets/linkstack/images`, home message).  
- CMS editing for Terms/Privacy/Contact via CKEditor.  
- Config editing (Env toggles, advanced config Ace editor, `.env` raw view).  
- Theme lifecycle (upload ZIP, delete directory, background removal, theme updater via GitHub README inspection).  
- Backups (hooking into `resources/views/backup.blade.php` + Spatie commands), diag page (`resources/views/components/config/diagnose`).  
- Update orchestrator, send-test-mail, QR/Share, `redirectInfo` (link preview with stats).  
- Many actions mutate `.env` through `EnvEditor`; pay attention to `editConfig()` switch statements.

### Auth controllers (`app/Http/Controllers/Auth/*`)
- `RegisteredUserController` extends default registration to enforce handle regex `/^[\p{L}0-9-_]+$/u`, optional manual verification (`MANUAL_USER_VERIFICATION`), and email notifications to `ADMIN_EMAIL`.  
- `AuthenticatedSessionController` leverages `LoginRequest` to ensure `block == 'no'` before login.  
- `SocialLoginController` wires Laravel Socialite; stores provider info to `social_accounts`, auto-creates handles from provider nickname.

### LinkTypeViewController (`app/Http/Controllers/LinkTypeViewController.php`)
- Renders parameter forms for link types.  
- Streams block assets with strict extension and path validation to avoid traversal.  
- Pulls `LinkType::get()` data (a hybrid of DB entries + file-based `blocks`).

### Admin\LinkTypeController (`app/Http/Controllers/Admin/LinkTypeController.php`)
- Legacy resource controller editing DB-backed link types. When mixing DB + filesystem link types, be explicit which path you follow.

### HomeController (`app/Http/Controllers/HomeController.php`)
- Supplies marketing home (`resources/views/home.blade.php`) and `/demo-page` example.

---

## 8. Feature Modules & Flows

### 8.1 Installer & Upgrade
- **Install**: Flags `INSTALLING`/`INSTALLERLOCK` gate the UI (routes lines 35–52). Installer writes DB creds to `.env`, seeds admin/Buttons/Pages, toggles `ALLOW_REGISTRATION`, `REGISTER_AUTH`, `HOME_URL`, `APP_NAME`.  
- **Update**: `resources/views/update.blade.php` sequences: backup (unless `SKIP_UPDATE_BACKUP`), pre-update script, download ZIP (beta or stable), extract, run `php artisan optimize:clear`, finishing script, redirect. Beta toggles read `JOIN_BETA`.

### 8.2 Authentication & Registration
- `.env` flags:  
  - `ALLOW_REGISTRATION` toggles UI/route availability.  
  - `REGISTER_AUTH` controls middleware (`auth` vs `verified`).  
  - `MANUAL_USER_VERIFICATION` sets new users’ `block` to `yes` until admin approves (and optional email to admin).  
  - Social logins gated by `ENABLE_SOCIAL_LOGIN`.
- Login uses `LoginRequest::authenticate()` to throttle attempts and ensure blocked users can't log in.

### 8.3 User Studio
- Layout `resources/views/layouts/sidebar.blade.php` is shared by both admin and studio screens; it loads Hope UI CSS, QR code modal, notifications, and touches the `user->updated_at` timestamp on every render.
- Core screens (`resources/views/studio/*.blade.php`):
  - `add-link`, `edit-link`, `links`: include icons preview, `Sortable` handles, button editor CTA, icons tab anchored via `#icons`.  
  - `button-editor` (gated by `ENABLE_BUTTON_EDITOR`) loads legacy jQuery color/gradient pickers from `assets/button-editor/`.  
  - `page`: CKEditor editing for description, handle, share button toggles, link opening behavior, checkmark indicator stored in `UserData`.  
  - `profile`: email/password change, data export/import, delayed account deletion countdown.  
  - `theme`: theme selector modal, custom background uploader (honors `ALLOW_CUSTOM_BACKGROUNDS`), file upload for zipped themes, CTA to delete/download new themes, `theme-updater` embed for admins.  
  - `theme-updater.blade.php` lists installed themes + remote version comparison; `update/theme` route downloads ZIPs straight from GitHub “Source code” links referenced in theme README.
- `UserData` JSON (written via `UserData::saveData`) stores booleans such as `checkmark`, `disable-sharebtn`, `links-new-tab`, `hide-star-notification`.

### 8.4 Public Link Views
- Root layout `resources/views/linkstack/layout.blade.php` builds `<head>`, `<body>`, and stacks. 
- Modules included via Blade stacks (all inside `resources/views/linkstack/modules/`):
  - `meta.blade.php` handles custom meta tags and OG/Twitter previews based on `advanced-config`.
  - `assets.blade.php` inlines `fontawesome.css`, `normalize.css`, `animate.css`, `dynamic-contrast` JS, jQuery, and fonts.
  - `theme.blade.php` loads theme CSS per user, handles custom backgrounds (via `findBackground()`), toggles dynamic contrast JS, and optionally injects custom head/body snippets when `ALLOW_CUSTOM_CODE_IN_THEMES` is true.
  - `admin-bar.blade.php` draws a WordPress-style bar when `ENABLE_ADMIN_BAR` allows and viewer is owner/admin.  
  - `share-button.blade.php` toggled by `advanced-config.display_share_button` or per-user `UserData`.
  - `report-icon.blade.php` (env `ENABLE_REPORT_ICON` + `role == user`) adds a floating abuse report CTA.
  - `block-libraries.blade.php` inspects `links` for `include_libraries` (declared in `LinkType->include_libraries`) and conditionally pushes extra JS (e.g., SweetAlert).
  - `dynamic-contrast.blade.php` uses `BackgroundCheck` library for readability.
  - `footer.blade.php` uses env toggles `DISPLAY_FOOTER_*` and `DISPLAY_CREDIT`.
- Elements under `resources/views/linkstack/elements` render avatar, heading, bio, icons (button id 94), and the actual buttons (`buttons.blade.php`). Buttons track clicks via `fetch('/going/{id}')` and respect share button/new-tab preferences.

### 8.5 Admin Panel
- Dashboard view `resources/views/panel/index.blade.php` (shared layout) shows stats, top links, site counts, and admin-only cards.  
- `panel/users.blade.php` instantiates `<livewire:user-table>`; supporting partials (`resources/views/components/table-components/*.blade.php`) format action buttons (view links, edit, impersonate, delete). AJAX actions call controller routes and refresh Livewire.  
- Config editor `panel/config-editor.blade.php` tabs:  
  - **Config** – toggles (via helper `toggle($key)` in `components/config/config.blade.php`) for env flags like `ALLOW_REGISTRATION`, `REGISTER_AUTH`, `FORCE_ROUTE_HTTPS`, `ALLOW_CUSTOM_BACKGROUNDS`, `MAINTENANCE_MODE`, `ENABLE_REPORT_ICON`, `ALLOW_USER_IMPORT`, mail settings, etc.  
  - **Advanced Config** – Ace editor for `config/advanced-config.php`.  
  - **Backup / All Backups** – views under `components/config/backup(s).blade.php`; backup tab triggers `/backup` view (Spatie backup + zipped downloads).  
  - **Diagnosis** – `components/config/diagnose` tests `.env` exposure and file writability (cURL requests to `.env`, SQLite) and lists required PHP modules.  
  - **Alternative Config** – Ace editor for raw `.env`.  
- Site customization (`panel/site.blade.php`) handles site logo, favicon, home message body, via `/admin/site`.
- CMS content editing in `panel/pages.blade.php` uses CKEditor to update Terms/Privacy/Contact.
- Theme deletion view `panel/theme.blade.php` enumerates `themes/` directory.
- Backups are served via `panel/backups.blade.php` which streams files in `backups/updater-backups`.
- Update/backups/maintenance rely on `resources/views/layouts/updater.blade.php` for consistent styles.
- Impersonation:  
  - Admin list has action linking to `AdminController::authAsID()`; `Impersonate` middleware handles swapping sessions and shows top bar with exit form hitting `/auth-as`.  
  - Guard prevents multiple concurrent impersonations.

### 8.6 Theme System

- Each theme folder (`themes/<name>/`) contains:  
  - `config.php` – returns array of switches (`allow_custom_buttons`, `enable_custom_code`, `use_custom_icons`, etc.).  
  - CSS files: `share.button.css`, `brands.css`, `skeleton-auto.css`, `animations.css` (optional).  
  - `extra` directory for custom partials: `custom-head/body/body-end.blade.php`, optional assets under `custom-assets/`.  
  - `preview.png`, `readme.md` describing version and source (used by theme updater).  
- `resources/views/studio/theme.blade.php` handles selection, preview (image or iframe), upload zipped theme (admin only), deletion (redirect to `/admin/theme` form), background management.
- Theme updater compares local README `Theme Version` vs remote README (converted to raw GitHub) and, when newer, downloads zipped release `refs/tags/vX.Y.Z.zip`. The update process temporarily extracts to `themes/<name><version>` and copies back sans suffix.

### 8.7 Block / Link Type System

- `LinkType` model’s `get()` method combines a synthetic “predefined” entry with each filesystem block’s `config.yml` (YAML fields: `id`, `typename`, `title`, `description`, `icon`, `custom_html`, `ignore_container`, `include_libraries`).  
- `UserController::saveLink()` includes `blocks/<typename>/handler.php`, expects it to return `['rules' => ..., 'linkData' => ...]`. Validation runs before saving. Handler decides which button ID to use and which additional params to store. Examples:  
  - `blocks/link` toggles `button_id` based on `GetSiteIcon`.  
  - `blocks/heading` forces `button_id 42`.  
  - Blocks like `email`, `telephone`, `vcard`, `text`, `spacer` specify custom display templates under `blocks/<type>/display.blade.php`.  
- Parameter forms are rendered by `LinkTypeViewController::getParamForm()` loading `blocks::<type>.form` (Blade namespace bound in `AppServiceProvider`). The “predefined” type reuses `resources/views/components/pageitems/predefined-form.blade.php`.
- Front-end display: `resources/views/linkstack/elements/buttons.blade.php` inspects `link->custom_html` and either renders block display partial or fallbacks to button CSS classes.
- `LinkTypeViewController::blockAsset()` serves assets per block with extension white-list to prevent arbitrary file serving.

### 8.8 Reporting & Email Flows

- `/report` GET renders `resources/views/report.blade.php`; includes reason dropdown with localized strings, optional pre-filled URL when query string contains user ID.  
- POST hits `UserController::report()`, which pipes `$formData` into `ReportSubmissionMail` (Blade view `resources/views/layouts/send-report.blade.php`) and emails `ADMIN_EMAIL`.  
- Admin `SendTestMail` action (`/send-test-email`) verifies `.env` SMTP vs built-in mailer.  
- Email templates for auth (verification, password reset) live under `resources/views/auth/*`.

### 8.9 Analytics, Share, QR & Reporting Features

- `awssat/laravel-visits` records page visitors; stats are surfaced in both admin and studio dashboards (`visits('App\Models\User', $littlelink_name)->period('day|week|month|year')`).  
- QR code dropdown in layout uses `SimpleSoftwareIO\QrCode\Facades\QrCode`.  
- Share button uses Web Share API fallback to clipboard.  
- Report icon optional per env; invites abusers to `/report?id=<user_id>`.

### 8.10 Maintenance & Diagnostics

- `MAINTENANCE_MODE` env forces all routes to render `maintenance.blade.php`, except admin (which can jump back).  
- `resources/views/components/config/diagnose.blade.php` warns if `.env` or SQLite DB is publicly accessible, ensures directories are writable, and enumerates required PHP extensions.  
- `resources/views/layouts/notifications.blade.php` continually pings `.env`/SQLite and warns via modal if accessible (set `display_auth_nav` session to show notifications).

### 8.11 Localization & Content

- Strings live in `resources/lang/<locale>/messages.php`. Admin config form references keys (e.g., `messages.ALLOW_REGISTRATION.title`).  
- CLI tools:  
  - `php artisan translation-check <locale>` compares translation keys to English baseline.  
  - `php artisan translate {source} {target}` (from `Translate.php`) hits Google translate via token generator (beware API limits).  
- `resources/views/home.blade.php` pulls `Page::home_message`; default message swapped via `components/finishing`.

### 8.12 Button editor & Icon pipeline

- `resources/views/studio/button-editor.blade.php` (gated by `ENABLE_BUTTON_EDITOR`) loads old jQuery gradient/color pickers to produce CSS strings. Result stored in `links.custom_css` and `custom_icon`.  
- Custom favicons `getFavIcon($linkId)` (from `resources/views/components/favicon.blade.php`) hits Google’s favicon service and caches PNG under `assets/favicon/icons/{id}.png`. `localIcon()` helper locates stored files for `custom_website` buttons.

### 8.13 User Data import/export schema

- Exported JSON for `/export-all` contains `user` fields, `links` array, optionally `image_data` (base64) + `image_extension`. Importer rewrites `littlelink_description` with whitelist tags, ensures `mailto:` and `tel:` protocols, resets `click_number` to 0.  
- `/export-links` only contains `links`.  
- Import replaces all existing links; advise users to export before import. File validation ensures MIME `application/json`.

### 8.14 Asset pipelines

- **Avatars** stored in `assets/img/{userId_timestamp.ext}`; `findAvatar()` searches by user ID prefix. Deletion loops remove any `id*` files.  
- **Backgrounds** stored in `assets/img/background-img/{userId_timestamp.ext}`; `analyzeImageBrightness()` (helper) can determine theme overlay.  
- **Logos & favicon** at `assets/linkstack/images/` (`findFile('avatar')`, `findFile('favicon')`). Admin `delAvatar`/`delFavicon` remove them.

### 8.15 Misc routes

- `/info/{linkId}` shows intermediate page with link target and click stats (`resources/views/linkinfo.blade.php`). Shares same layout as admin pages.
- `/theme/@handle` displays theme README/credit via `resources/views/components/theme.blade.php`.

---

## 9. Frontend Build & Assets

- **Build pipeline** (`webpack.mix.js`):  
  ```bash
  npm install
  npm run dev     # or npm run prod
  ```
  Generates `public/js/app.js` and `public/css/app.css`. Tailwind config is implicit (via `@import 'tailwindcss/*'` in `resources/css/app.css`).
- Admin relies heavily on vendor CSS in `assets/css` (Hope UI). If you modify vendor assets, be mindful they are committed (no package manager).  
- Legacy scripts (jQuery, CKEditor, color pickers) live under `assets/`. Many Blade templates load them directly via `<script src="{{ asset('assets/...') }}">`; ensure they stay accessible (no Mix pipeline).
- `resources/js/bootstrap.js` configures Axios (CSRF header). No Echo/Pusher usage by default.

---

## 10. Console Commands & Automation

- `php artisan translation-check <locale>` – ensures translation parity with `resources/lang/en/messages.php`.  
- `php artisan translate {source} {target}` – auto-translates missing keys via Google. Stored in `app/Console/Commands/Translate.php`; requires outbound HTTP.  
- Default Laravel commands (migrate, queue, etc.) remain available; no custom schedule entries in `app/Console/Kernel.php`.

---

## 11. External Integrations & Services

- **EnvEditor (`geo-sot/laravel-env-editor`)** – central to config UI; editing `.env` manually may desynchronize UI.  
- **Spatie Backup** – `resources/views/backup.blade.php` calls `backup:clean` + `backup:run` (`--only-files`). Backup zips land in `backups/updater-backups`.  
- **awssat/laravel-visits** – tracks anonymized hits per user handle; data stored in `visits` table.  
- **Simple-QrCode** – generates QR in nav.  
- **Laravel Socialite** – google/github/etc logins; ensure provider env keys set when enabling `ENABLE_SOCIAL_LOGIN`.  
- **Guzzle** – theme updater + translation commands rely on HTTP.  
- **JeroenDesloovere\VCard** – exports contact cards for `vcard` links.

---

## 12. Configuration Flags & Storage

| Category | Keys / settings | Where controlled |
| --- | --- | --- |
| Registration & auth | `ALLOW_REGISTRATION`, `REGISTER_AUTH`, `MANUAL_USER_VERIFICATION`, `FORCE_ROUTE_HTTPS`, `FORCE_HTTPS`, `ENABLE_SOCIAL_LOGIN`, `SUPPORTED_DOMAINS`. | Env toggles via config editor. |
| Appearance | `ALLOW_CUSTOM_BACKGROUNDS`, `ALLOW_CUSTOM_CODE_IN_THEMES`, `DISPLAY_FOOTER_*`, `DISPLAY_CREDIT`, `TITLE_FOOTER_*`, `advanced-config.home_theme`, `advanced-config.buttons`. | Env + advanced config file. |
| Share/report | `advanced-config.display_share_button` (`true|false|auth`), per-user `UserData` flags (`disable-sharebtn`, `links-new-tab`, `checkmark`). | Advanced config, Studio page, `UserData`. |
| Admin tooling | `ENABLE_ADMIN_BAR`, `ENABLE_ADMIN_BAR_USERS`, `ENABLE_REPORT_ICON`, `ENABLE_THEME_UPDATER`, `ENABLE_BUTTON_EDITOR`, `JOIN_BETA`, `SKIP_UPDATE_BACKUP`. | Env toggles + config UI. |
| Maintenance | `MAINTENANCE_MODE`, `HOME_URL`, `CUSTOM_META_TAGS`, `HIDE_VERIFICATION_CHECKMARK`. | Config UI / advanced config. |
| Localization | `LOCALE` (default language), translations under `resources/lang`. | Env + translation files. |
| Limits | `linkstack.user_cap` (requires manual config file; create `config/linkstack.php` with returning array), `LINK_ID_LENGTH`, `USER_ID_LENGTH`. | Not shipped—add config manually if you need to change random ID lengths. |

> **Tip:** Because `config('linkstack.*')` is referenced in code but no `config/linkstack.php` is committed, deployments that need user limits or custom random ID lengths should add their own config file returning keys `user_cap`, `disable_random_user_ids`, `user_id_length`, `disable_random_link_ids`, `link_id_length`, `single_user_mode`.

---

## 13. Development Workflow

1. **Install prerequisites:** PHP 8.2+, Composer, Node 18+, npm. Ensure required PHP extensions (BCMath, Ctype, cURL, DOM, Fileinfo, JSON, Mbstring, OpenSSL, PCRE, PDO + SQLite/MySQL, Tokenizer, XML, Imagick optional) are available (see diag page).  
2. **Initial setup:**
   ```bash
   composer install
   cp .env.example .env    # adjust DB/mail/app keys
   php artisan key:generate
   php artisan migrate --seed
   npm install
   npm run dev
   ```
   If you want to simulate installer, delete `.env`, `storage/app/ISINSTALLED`, create `INSTALLING`.
3. **File permissions:** web server must write to `storage/`, `bootstrap/cache/`, `backups/`, `assets/img`, `assets/img/background-img`, `assets/linkstack/images`, `assets/favicon/icons`.  
4. **Serving locally:** Use `php artisan serve` (ships `server.php`). Because app expects to run from web root, ensure `document_root` points to project root or symlink `public/` equivalents.  
5. **Testing flows manually:**  
   - Register, verify email, log in, add links, reorder.  
   - Toggle share button, check `UserData` effects.  
   - Upload avatar/background, check file system.  
   - Use admin config UI to toggle `MAINTENANCE_MODE`, `FORCE_ROUTE_HTTPS`, etc., verifying `.env` updates.  
   - Run `/backup`, `/update` inside sandbox to confirm pre/finishing scripts.  
   - Trigger Livewire table actions (block user, impersonate).  
6. **Translation changes:** After editing `resources/lang`, run `php artisan translation-check <locale>` to confirm parity.

---

## 14. Testing & QA Strategy

- There are no PHP unit/feature tests committed. QA relies on manual smoke suites:  
  - **Installer path** (fresh DB).  
  - **User Studio** flows: add/edit/delete links, icons, import/export, backgrounds, share button.  
  - **Admin operations**: config toggles, advanced config, env editor, CMS pages, theme upload/delete, backup/update, impersonation.  
  - **Public view**: verify dynamic contrast, share/report, admin bar states, analytics increments.  
  - **Mail**: registration, password reset, test email, report submission.  
  - **Localization**: run through `lang` toggles if `LOCALE` is changed.  
- Consider adding automated tests around `UserController::saveLink`, `AdminController::editConfig`, `Impersonate` middleware, and import/export sanitization when time allows.

---

## 15. Extending the Platform – How‑Tos

### Add a new block / link type
1. Create `blocks/<type>/config.yml` with metadata (`typename`, `icon`, `custom_html`, `include_libraries`, etc.).  
2. Add `form.blade.php` to collect inputs via Blade (use Bootstrap classes).  
3. Add `handler.php` returning `['rules' => [...], 'linkData' => [...]]`; reference existing handlers like `blocks/link/handler.php`.  
4. (Optional) Provide `display.blade.php` if block renders custom HTML.  
5. If block needs custom JS/CSS, reference them via `block_asset()` and declare `include_libraries`.  
6. `LinkType::get()` auto-discovers it; do _not_ forget to set unique `id` to avoid collisions.

### Add or update a theme
1. Create folder under `themes/` with `config.php`, CSS, `extra` folder, `preview.png`, `readme.md` that contains `Theme Version:` and `Source code:` lines for the updater.  
2. Upload ZIP via Studio (`/studio/theme`) if admin, or copy folder manually.  
3. To expose theme on home page, set `advanced-config.home_theme`.  
4. Provide README with download URL so `theme-updater` can fetch new releases.

### Add translation strings
1. Edit `resources/lang/en/messages.php`.  
2. Copy missing keys to other locales (or run `php artisan translate en es`).  
3. Run `php artisan translation-check <locale>` before committing.

### Introduce new env/config toggle
1. Add key to `.env.example` and to `resources/views/components/finishing.blade.php` so upgrades create it.  
2. Update `resources/views/components/config/config.blade.php` (and translations) to expose UI.  
3. Handle usage in controllers/models accordingly.  
4. If toggle belongs in advanced config, update `storage/templates/advanced-config.php` and Ace editor instructions.

### Modify admin layout/assets
1. `resources/views/layouts/sidebar.blade.php` controls nav and asset includes.  
2. Keep `@push('sidebar-stylesheets')` and `@push('sidebar-scripts')` sections – many views push into these stacks.  
3. When adding new scripts, prefer bundling them into `assets/js` to mirror existing pattern.

### Create automated maintenance jobs
1. Edit `app/Console/Kernel.php` to schedule Artisan commands (backups, cleanup).  
2. Ensure the command (`app/Console/Commands`) handles shared-hosting restrictions (no shell access).  
3. Document cron entries in this file for operators.

---

## 16. Operational Tips, Pitfalls & TODOs

- **`config('linkstack.*')` missing:** Several classes (`User`, `Link`, `MaxUsers`) expect `config/linkstack.php`. Consider committing a default stub or ensure deployments add one to avoid undefined index notices when toggling random IDs/user caps.  
- **`PagesController` import in `routes/web.php` is unused.** Remove to prevent confusion or implement if needed.  
- **File permissions:** Avatars/backgrounds/logos live inside repo paths (`assets/*`). On read-only deployments you must symlink these to writable storage or adjust code to use `storage/app/public`.  
- **EnvEditor concurrency:** Because config UI writes `.env`, race conditions can occur if multiple admins edit simultaneously. Mitigate by enforcing single-admin rule or adding locking.  
- **Backups & updates assume CLI access.** If PHP `exec` is disabled, the updater may silently fail; check `session(['update_error' => ...])` to debug.  
- **Legacy jQuery components:** Button editor uses jQuery 1.7 and direct DOM manipulation. Replacing it requires revisiting `resources/views/studio/button-editor.blade.php`.  
- **Security monitoring:** `resources/views/layouts/notifications` warns about exposed `.env`/SQLite via HTTP HEAD requests—keep `allow_url_fopen` enabled or adjust to use Guzzle.  
- **Caches:** `UserData` caches JSON via `Cache::remember` for 10 minutes. When updating user data outside helper, remember to call `UserData::cacheUserData` or flush cache.  
- **Large README/HTML fields:** CKEditor content is stored as raw HTML; `UserController::editPage` and `importData` sanitize but rely on helper `strip_tags_except_allowed_protocols`. Keep this function updated as allowed tags evolve.

---

## 17. Pre-Ship Checklist

1. `composer install --optimize-autoloader` & `npm run production` executed.  
2. `php artisan config:cache`, `route:cache`, `view:cache` if hosting allows (note: config UI may require `config:clear` to reflect changes).  
3. Verify `.env` contains `APP_KEY`, `APP_URL`, DB creds, `ADMIN_EMAIL`, mail settings.  
4. Ensure writable directories: `storage`, `bootstrap/cache`, `assets/img`, `assets/linkstack/images`, `assets/img/background-img`, `assets/favicon/icons`, `backups`.  
5. Run through admin config toggles to confirm EnvEditor still functions post changes.  
6. Perform backup/restore dry run via `/backup`.  
7. Test updater on staging (especially after touching `pre-update`/`finishing`).  
8. Validate translations if you added keys.  
9. Confirm share/report/QR features still render on public pages.  
10. Document any manual post-deploy steps (e.g., seeding, custom config file) in release notes.

---

_End of AGENTS.md — keep this file current whenever you add features, migrations, env keys, or external dependencies so future agents can ramp up without rereading the entire codebase._ 
