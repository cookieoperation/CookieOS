# CookieOS Slime v1 — System Architecture Blueprint

## Scope
CookieOS is a LineageOS 23-derived distribution with:
- native Rust + Kotlin system services,
- CookieOS branding using Material 3,
- a `.cos` package format,
- multi-runtime support for `.apk`, `.deb`, and `.rpm`/Fedora binaries,
- read-write system partitions by default.

---

## 1) Platform Baseline (LineageOS 23)

### Branching strategy
- Track upstream LineageOS 23 (Android 16 generation) with a clean downstream branch model:
  - `upstream/los23`
  - `cookieos/slime-v1`
- Keep invasive features modular via Product overlays and optional services to simplify rebases.

### Product definition
- Add `product/cookieos/` with product makefiles and feature flags:
  - `PRODUCT_BRAND := CookieOS`
  - `PRODUCT_NAME := cookieos_slime`
  - `PRODUCT_SYSTEM_DEFAULT_PROPERTIES += ro.cookieos.version=Slime-v1`

---

## 2) Native Rust + Kotlin Integration

### Service model
Use **AIDL-bound system services** where possible, JNI only for leaf native libraries:

1. Kotlin framework/system_server stub
2. AIDL interface (stable)
3. Native Rust daemon/service implementation
4. SELinux domain + Binder policy

This provides strict IPC boundaries and avoids monolithic JNI bridges.

### Rust placement
- `system/cookieos/rust/`:
  - `cookie_memd` (memory policy / pressure analytics)
  - `cookie_pkgd` (`.cos` verifier/parser)
  - `cookie_runtimed` (container/runtime broker)

### Build integration
- Use Soong `rust_binary` / `rust_library` modules.
- Keep unsafe code isolated in tiny adapter crates.
- Expose minimal FFI surface (for JNI) and prefer AIDL for long-lived APIs.

### Memory policy targets
- Replace high-churn Java/Kotlin components in hot paths with Rust-backed services.
- Add perf gates in CI:
  - PSS median under workload
  - LMKD kill rate
  - app launch latency regression budget

---

## 3) CookieOS Branding (Material 3)

### UI surfaces
- SystemUI overlays (quick settings shapes/colors/typography)
- Settings app theme overlays + CookieOS panel
- Boot animation, wallpapers, icon pack

### Theming stack
- Dynamic Color-compatible Material 3 palette
- `RRO` overlays for device-independent branding
- Accessibility checks (contrast + large text)

### Identity assets
- `vendor/cookieos/overlay/`
- `vendor/cookieos/branding/`

---

## 4) `.cos` Package Format

### Design goals
- Signed package container for privileged or policy-rich app deployment.
- Deterministic, auditable metadata.

### Proposed file structure
`.cos` as a signed bundle (zip-like container):
- `manifest.toml`
- `payload/` (`base.apk` or split APK set, optional native payload)
- `policy/permissions.json`
- `signature/` (Ed25519 + certificate chain)

### Install flow
1. `PackageInstaller` detects `.cos` MIME.
2. Delegates parse/verify to `cookie_pkgd` (Rust).
3. Policy engine checks:
   - signature trust root
   - declared privileged capabilities
   - compatibility constraints
4. Converts to standard install session + policy grants under explicit user/admin control.

### Security constraints
- No silent privileged grants without explicit trust anchor and policy confirmation.
- Every `.cos` install emits attested audit log entries.

---

## 5) Multi-Runtime (`.apk` + `.deb` + `.rpm`)

### Architecture
Use a **sandboxed Linux container subsystem** with translation/runtime broker:

- `cookie_runtimed` (Rust) orchestrates runtime backends:
  - Android native (`.apk`) via PackageManager.
  - Debian backend (`.deb`) in rootfs container.
  - Fedora backend (`.rpm`) in rootfs container.

### Runtime components
- Namespaced container (user, mount, pid, net namespaces where available)
- Wayland/X11 bridge optional; for Android UI use app streaming/proxy surfaces
- Filesystem broker for controlled host path access

### Packaging UX
- Unified “Install App” flow:
  - detect extension
  - route to backend
  - show permission/resource profile before install

### Risk management
- `.deb`/`.rpm` compatibility is best-effort and device-class dependent.
- Gate with feature flag for Slime v1 and ship to selected devices first.

---

## 6) Full Read-Write by Default

### Behavior
- Userdebug-like flexibility for power users while preserving recoverability.
- Provide first-boot disclosure and rollback guidance.

### Implementation direction
- Disable forced read-only remount policy in product config.
- Provide managed toggles:
  - “RW mode active” status
  - one-tap remount RO
  - snapshot/rollback integration (where supported)

### Safety controls
- Warn on verified boot degradation.
- Offer automated backup checkpoint before major system writes.

---

## 7) Security & SELinux

- New domains:
  - `u:r:cookie_memd:s0`
  - `u:r:cookie_pkgd:s0`
  - `u:r:cookie_runtimed:s0`
- Binder allowlists per-service.
- Neverallow rules to prevent broad filesystem access from runtime daemons.
- Signed policy bundles for `.cos` trust roots.

---

## 8) CI/CD (GitHub Actions)

### Pipeline stages
1. Source sync + repo manifest pin
2. Build (target matrix by device)
3. Rust unit/integration tests
4. Compatibility tests (`.cos` parser/verifier, install flow)
5. Artifact signing
6. Release: flashable images + checksums + SBOM

### Additional quality gates
- Boot smoke test (emulator/device farm)
- CTS/VTS subset gate
- Memory regression gate for Rust-migrated services

---

## 9) Slime v1 Milestones

### M1: Foundation
- Product definition + branding base
- Rust toolchain + first native daemon skeleton
- RW mode toggle MVP

### M2: `.cos` Alpha
- Parser/verifier + installer hook
- Trust root provisioning + audit logs

### M3: Multi-runtime Preview
- `.deb` container backend
- basic app launch and file broker

### M4: Hardening
- SELinux tightening
- telemetry/perf tuning
- release candidate images

---

## 10) Recommended Repo Layout

- `product/cookieos/`
- `vendor/cookieos/overlay/`
- `vendor/cookieos/branding/`
- `system/cookieos/rust/cookie_memd/`
- `system/cookieos/rust/cookie_pkgd/`
- `system/cookieos/rust/cookie_runtimed/`
- `system/cookieos/framework/` (Kotlin/AIDL bridge stubs)
- `.github/workflows/`

This blueprint is intended to be implementation-ready and rebase-friendly for a downstream LineageOS 23 project.
