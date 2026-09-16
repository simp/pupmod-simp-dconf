# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`pupmod-simp-dconf` is a SIMP Puppet module that installs and manages
[`dconf`](https://wiki.gnome.org/Projects/dconf) — the low-level configuration
system used by GNOME and other desktop components on Enterprise Linux 8/9/10. It
manages three things:

1. **dconf profiles** (`/etc/dconf/profile/*`) — the ordered list of databases
   consulted for a given profile (`user`, `system`, etc.).
2. **dconf settings** (`/etc/dconf/db/<profile>.d/*`) — the key/value rules
   written into a database, optionally **locked** so unprivileged users cannot
   override them (`/etc/dconf/db/<profile>.d/locks/*`).
3. The `dconf` **package** itself.

It is a desktop-hardening building block (used by e.g. `gnome`/`mate`-style
modules) whose main compliance value is the **lock** mechanism: a locked key
cannot be changed by the logged-in user, which is how screensaver/idle-lock,
media-automount, and similar STIG-type settings get enforced.

**As of 3.0.0 (blast-radius refactor), a bare `include dconf` only installs the
package.** Profiles and settings are opt-in via parameters, and the pre-3.0.0
defaults live in the `simp:defaults` Sicura Compliance Engine profile
(`SIMP/compliance_profiles/`), activated with Hiera
`compliance_engine::enforcement: [simp:defaults]`.

### Business logic

**`dconf` (`manifests/init.pp`)** — the public entry point and the single source
of shared state (`dconf::install`, `dconf::profile`, and `dconf::settings` all
`include 'dconf'` to read its parameters).

- **`user_profile`** (`Optional[Dconf::DBSettings]`, default `undef`) — the
  databases that make up the default user profile. When set, it is rendered
  into a `dconf::profile` named by `user_profile_defaults_name` (default
  `Defaults`) targeting `user_profile_target` (default `user`). The module
  ships **no default value**; the pre-3.0.0 user (1) / local (system, 20) /
  site (system, 30) / distro (system, 40) hierarchy is restored by the
  `simp:defaults` compliance profile. `data/common.yaml` retains deep-merge
  `lookup_options` for this key, so Hiera values merge across levels rather
  than replace.
- **`user_settings`** (`Optional[Dconf::SettingsHash]`, default `undef`) —
  global settings to push via Hiera. When set, a `dconf::settings` resource
  named `user_settings_defaults_name` is created. When unset, nothing is
  declared (the pre-3.0.0 `ensure => absent` cleanup resource is gone).
- **`tidy`** (default `false`) — propagates to `purge` on the managed
  `*.d` and `locks` directories in `dconf::settings`. When `true`, **unmanaged
  files in a managed profile directory are removed** — a footgun if another
  module or an admin drops files there, which is why 3.0.0 flipped the default
  off (the `simp:defaults` profile turns it back on).
- **`authselect`** (default `false`) — when using authselect you can hit resource
  conflicts on `/etc/dconf/db/distro.d/20-authselect` (+ its `locks/` twin);
  flipping this true declares (empty) `file` resources so Puppet "owns" them and
  stops the conflict.
- **`package_ensure`** (default `'installed'`) — passed straight to
  `dconf::install`.
- **`use_user_profile_defaults` / `use_user_settings_defaults`**
  (`Optional[Boolean]`, default `undef`) — **deprecated** (setting either
  issues a `deprecation()` warning, key `dconf::use_user_*_defaults`). Kept
  for transitional compatibility: an explicit `false` still suppresses the
  corresponding `dconf::profile`/`dconf::settings` (settings follow the
  profile param when unset, as pre-3.0.0); `true` adds nothing — data
  presence is the real gate.

**`dconf::install` (`manifests/install.pp`, private — `assert_private()`)** —
`stdlib::ensure_packages('dconf', { ensure => $dconf::package_ensure })`. Nothing
else.

**`dconf::profile` (`manifests/profile.pp`, define)** — writes one profile file
`${base_dir}/${target}` (default base `/etc/dconf/profile`) via **`concat`**. Each
entry in `$entries` (a `Dconf::DBSettings` hash) becomes a `concat::fragment`
emitting a `<type>-db:<db_name>` line, ordered by the entry's `order`
(**default 15** via `pick`). The `simp:defaults` compliance profile orders the
databases user `1`, local `20`, site `30`, distro `40` (lower = higher
priority). **Note the
type forbids `0`:** `order` is declared `Optional[Integer[1]]`, so `profile.pp`'s
docstring (example `order: 0`, "User DB => 0 / SIMP DB => 10 / System DB =>
11–39") is inconsistent with what the type actually accepts — the minimum valid
order is `1`.

**`dconf::settings` (`manifests/settings.pp`, define)** — the workhorse. For a
given profile it:

- Resolves the target profile: explicit `$profile`, else it falls back to
  `$dconf::user_profile_defaults_name` (default `Defaults`) unconditionally —
  same fallback the pre-3.0.0 default configuration provided.
- Sanitizes the resource title into a filename (`regsubst` replaces spaces and
  shell-special chars with `_`), producing
  `/etc/dconf/db/<profile>.d/<name>`.
- Writes each key with an **`ini_setting`** resource (one per schema/key), under
  the schema as the ini section, using `key_val_separator` (default `=`).
- Builds the **lock file** `/etc/dconf/db/<profile>.d/locks/<name>` (mode `0640`):
  every setting is locked as `/<schema>/<key>` **unless** its `lock` is explicitly
  `false`. If nothing ends up locked, the lock file is ensured `absent`.
- Triggers a **`dconf update`** exec, `refreshonly => true`, notified by the
  setting/lock file changes.

**The `dconf update` exec is deliberately convoluted — do not "simplify" it.**
`dconf update` exits `0` even on failure, so success is inferred from output:
```
/bin/dconf update |& /bin/tee /dev/fd/2 | /bin/wc -c | /bin/grep ^0$
```
i.e. it fails the resource unless `dconf update` produced **zero bytes** of
output. Rewriting this to a plain `dconf update` would silently swallow errors.

### Types (`types/`)

- **`Dconf::DBSettings`** — `Hash[String[1], Struct[{ type => Enum[user, system,
  service, file], order => Optional[Integer[1]] }], 1]`. Used for `user_profile` /
  `dconf::profile` entries. **Minimum size 1**: an empty hash is rejected at
  compile time, because it would render an empty profile file over the
  vendor-shipped one.
- **`Dconf::SettingsHash`** — `Hash[String, Hash[String, Struct[{ value =>
  NotUndef, lock => Optional[Boolean] }]]]` — i.e. `schema => { key => { value,
  lock? } }`. Used for `user_settings` / `dconf::settings`.

### Gotchas / non-obvious details

- **`tidy => true`/`purge` deletes unmanaged files** in the profile `*.d` and
  `locks` directories. Anything not declared through `dconf::settings` in a
  managed profile dir is a candidate for removal. Default is `false` since
  3.0.0; the `simp:defaults` profile restores `true`.
- **Locking is opt-out, not opt-in.** In a `dconf::settings` hash a key is locked
  unless you set `lock => false`. A setting with `value` but no `lock` **will be
  locked**.
- `data/common.yaml` ships **no values**, only `lookup_options` giving
  `dconf::user_profile` a **deep merge**; sites extend or tweak the hash
  (including the value the `simp:defaults` profile injects) rather than
  replace it. Don't delete the lookup_options when touching that file —
  losing them silently switches the key to first-found lookup. A deep merge
  cannot *remove* an entry; the escape hatch for full replacement is a site
  `lookup_options` override (`merge: first`). (A `knockout_prefix: '--'` was
  configured pre-3.0.0 but never worked for this key — knockout blanks the
  value, which the `Dconf::DBSettings` struct rejects — so it was dropped.)
- The `simp:defaults` compliance data (`SIMP/compliance_profiles/`) is consumed
  by the `compliance_engine` **gem** via a Hiera lookup_key backend — it is a
  spec **fixture** (`.fixtures.yml`), deliberately NOT a `metadata.json`
  dependency.

## Dependencies

- `puppetlabs/concat` (`>= 6.4.0 < 11.0.0`), `puppetlabs/inifile`
  (`>= 5.0.0 < 7.0.0`), and `puppetlabs/stdlib` (`>= 9.2.0 < 11.0.0`) — the
  declared module deps (`dconf::profile` uses `concat`; `dconf::settings` uses
  `ini_setting`). The stdlib floor is 9.2.0 because `init.pp` uses the
  **3-argument `deprecation()`** (`use_strict_setting`, stdlib 9.2.0+) and
  `install.pp` uses `stdlib::ensure_packages` (9.0.0+); don't lower it. The
  former `simp/simp_options` dep was dropped in 3.0.0 (no lookup ever
  referenced it).
- Spec fixtures (`.fixtures.yml`) additionally pull the `compliance_engine`
  gem repo (for the `simp:defaults` profile specs) — a fixture only, not a
  runtime dep.
- Runtime: **`openvox`** (`>= 8.0.0 < 9.0.0`) — `metadata.json` `requirements`
  targets openvox, not stock `puppet`.
- Supported OS: RedHat/OracleLinux/Rocky/AlmaLinux **8/9/10** and CentOS **9/10**
  (EL7 already removed; see `metadata.json`).

## Repository layout

- `manifests/init.pp` — public `dconf` class (parameters + default profile/settings wiring).
- `manifests/install.pp` — private package-install class.
- `manifests/profile.pp` — `dconf::profile` define (`/etc/dconf/profile/*` via concat).
- `manifests/settings.pp` — `dconf::settings` define (key/value rules + locks + `dconf update`).
- `types/dbsettings.pp`, `types/settingshash.pp` — the two data types above.
- `data/common.yaml` + `hiera.yaml` — module data (no values since 3.0.0; only the deep-merge `lookup_options` for `dconf::user_profile`).
- `SIMP/compliance_profiles/` — the `simp:defaults` compliance profile (`profile-simp_defaults.yaml` lists the checks; `checks.yaml` defines them).
- `spec/classes/init_spec.rb`, `spec/defines/{profile,settings}_spec.rb` — rspec-puppet unit tests (init_spec guards the "bare include only installs the package" contract).
- `spec/classes/dconf_simp_defaults_profile_spec.rb` + `spec/fixtures/hieradata/` — end-to-end specs for the `simp:defaults` profile (enforcement, site override, deep-merge extension).
- `spec/acceptance/suites/default/` — beaker acceptance suite; `nodesets/` holds the per-OS/docker node definitions. **Acceptance runs in CI** (`.github/workflows/pr_tests.yml`).
- `REFERENCE.md` — generated Puppet Strings reference (do not hand-edit; regenerate).
- `metadata.json` — module metadata, dependencies, and supported OS matrix.

## Common commands

This module uses `puppetlabs_spec_helper (~> 8.0)` + `simp-rake-helpers (~> 5.24)`
+ `simp-beaker-helpers (~> 2.0)`; rake tasks come from `Simp::Rake::Pupmod::Helpers`
(see `Rakefile`).

```sh
bundle install

# Unit tests (rspec-puppet)
bundle exec rake spec

# A single spec file
bundle exec rspec spec/defines/settings_spec.rb

# Lint / style
bundle exec rake lint
bundle exec rake rubocop

# Regenerate REFERENCE.md after changing manifest docstrings
bundle exec puppet strings generate --format markdown --out REFERENCE.md

# Acceptance tests (beaker; needs a hypervisor/docker — see spec/acceptance/nodesets)
bundle exec rake beaker:suites[default]
```

## Conventions

- **Keep the `dconf update` exec's output-check.** `dconf update` returns `0` even
  on failure; the `wc -c | grep ^0$` pipeline is how failures are detected. Don't
  replace it with a bare `dconf update`.
- **Locking is opt-out.** Preserve the "locked unless `lock => false`" semantics
  in `dconf::settings`; changing it silently unlocks hardened keys.
- Be deliberate about `tidy`/`purge` — it deletes unmanaged files in managed
  profile directories (off by default since 3.0.0).
- **Keep the bare include inert.** `include dconf` must only install the
  package; new behavior belongs behind `Optional[...] = undef` parameters
  and/or the `simp:defaults` compliance profile, and init_spec.rb enforces
  this.
- Extend `user_profile` via Hiera deep-merge rather than overriding the whole
  hash — and keep the `lookup_options` in `data/common.yaml` that make this
  work (a deep merge cannot remove entries; full replacement needs a site
  `lookup_options` `merge: first` override).
- Keep manifest parameter `@param` docstrings current — `REFERENCE.md` is
  generated from them.
