# CookieOS Branding Patches

Place branding patches used by the CI workflow here:

- `settings.patch` → applied in `packages/apps/Settings`
- `systemui.patch` → applied in `frameworks/base/packages/SystemUI`

The workflow (`.github/workflows/build-rpi4.yml`) will apply these patches if present.
