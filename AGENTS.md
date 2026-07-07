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

### Business logic

**`dconf` (`manifests/init.pp`)** — the public entry point and the single source
of shared state (`dconf::install`, `dconf::profile`, and `dconf::settings` all
`include 'dconf'` to read its parameters).

- **`user_profile`** (`Dconf::DBSettings`, **required**) — the databases that
  make up the default user profile. Its real value comes from Hiera
  (`data/common.yaml`) as a deep-merge map: `user` (order 1), `local` (system,
  20), `site` (system, 30), `distro` (system, 40). When
  `use_user_profile_defaults` (default `true`), this is rendered into a
  `dconf::profile` named by `user_profile_defaults_name` (default `Defaults`)
  targeting `user_profile_target` (default `user`).
- **`user_settings`** (`Optional[Dconf::SettingsHash]`) — global settings to push
  via Hiera. If set **and** `use_user_settings_defaults` (defaults to
  `use_user_profile_defaults`), a `dconf::settings` resource named
  `user_settings_defaults_name` is created; otherwise that same-named
  `dconf::settings` is declared `ensure => absent` (so toggling the flag cleans
  up previously-managed settings).
- **`tidy`** (default `true`) — propagates to `purge => true` on the managed
  `*.d` and `locks` directories in `dconf::settings`, so **unmanaged files in a
  managed profile directory are removed**. This is a footgun if another module or
  an admin drops files there.
- **`authselect`** (default `false`) — when using authselect you can hit resource
  conflicts on `/etc/dconf/db/distro.d/20-authselect` (+ its `locks/` twin);
  flipping this true declares (empty) `file` resources so Puppet "owns" them and
  stops the conflict.
- **`package_ensure`** (default `'installed'`) — passed straight to
  `dconf::install`.

**`dconf::install` (`manifests/install.pp`, private — `assert_private()`)** —
`stdlib::ensure_packages('dconf', { ensure => $dconf::package_ensure })`. Nothing
else.

**`dconf::profile` (`manifests/profile.pp`, define)** — writes one profile file
`${base_dir}/${target}` (default base `/etc/dconf/profile`) via **`concat`**. Each
entry in `$entries` (a `Dconf::DBSettings` hash) becomes a `concat::fragment`
emitting a `<type>-db:<db_name>` line, ordered by the entry's `order`
(**default 15** via `pick`). The shipped `data/common.yaml` orders the databases
user `1`, local `20`, site `30`, distro `40` (lower = higher priority). **Note the
type forbids `0`:** `order` is declared `Optional[Integer[1]]`, so `profile.pp`'s
docstring (example `order: 0`, "User DB => 0 / SIMP DB => 10 / System DB =>
11–39") is inconsistent with what the type actually accepts — the minimum valid
order is `1`.

**`dconf::settings` (`manifests/settings.pp`, define)** — the workhorse. For a
given profile it:

- Resolves the target profile: explicit `$profile` → else
  `$dconf::user_profile_defaults_name` when `use_user_profile_defaults` → else
  `fail()`.
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

- **`Dconf::DBSettings`** — `Hash[String, Struct[{ type => Enum[user, system,
  service, file], order => Optional[Integer[1]] }]]`. Used for `user_profile` /
  `dconf::profile` entries.
- **`Dconf::SettingsHash`** — `Hash[String, Hash[String, Struct[{ value =>
  NotUndef, lock => Optional[Boolean] }]]]` — i.e. `schema => { key => { value,
  lock? } }`. Used for `user_settings` / `dconf::settings`.

### Gotchas / non-obvious details

- **`metadata.json` declares a `simp/simp_options` dependency, but the manifests
  do not currently use a `simp_options::*` / `simplib::lookup` seam.**
  `package_ensure` is a plain `'installed'` default, not a hiera-lookup default.
  Don't assume a `simp_options` lookup exists to hook into — verify before
  wiring one up. (`simplib` is only present as a spec fixture.)
- **`tidy`/`purge` deletes unmanaged files** in the profile `*.d` and `locks`
  directories. Anything not declared through `dconf::settings` in a managed
  profile dir is a candidate for removal.
- **Locking is opt-out, not opt-in.** In a `dconf::settings` hash a key is locked
  unless you set `lock => false`. A setting with `value` but no `lock` **will be
  locked**.
- The default `user_profile` lives in Hiera with a **deep merge +
  `knockout_prefix: '--'`** (`data/common.yaml`); sites extend rather than
  replace it, and prefix an entry with `--` to knock it out.

## Dependencies

- `simp/simp_options` (`>= 1.6.1 < 3.0.0`) and `puppetlabs/stdlib`
  (`>= 8.0.0 < 10.0.0`) — the declared module deps (see the note above about
  `simp_options` not actually being referenced in the manifests).
- Spec fixtures (`.fixtures.yml`) additionally pull `concat`, `inifile`,
  `polkit`, and `simplib` — `concat` and `inifile` are the runtime-relevant ones
  (`dconf::profile` uses `concat`; `dconf::settings` uses `ini_setting`).
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
- `data/common.yaml` + `hiera.yaml` — module data (the default `user_profile`, with deep-merge lookup options).
- `spec/classes/init_spec.rb`, `spec/defines/{profile,settings}_spec.rb` — rspec-puppet unit tests.
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
  profile directories.
- Extend the default `user_profile` via Hiera deep-merge (`--` knockout) rather
  than overriding the whole hash.
- Keep manifest parameter `@param` docstrings current — `REFERENCE.md` is
  generated from them.
