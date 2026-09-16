[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/dconf.svg)](https://forge.puppetlabs.com/simp/dconf)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/dconf.svg)](https://forge.puppetlabs.com/simp/dconf)

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Description](#description)
  * [How it works](#how-it-works)
  * [This is a SIMP module](#this-is-a-simp-module)
* [Breaking changes in 3.0.0](#breaking-changes-in-300)
* [Setup](#setup)
* [Usage](#usage)
  * [Configuring custom rules](#configuring-custom-rules)
    * [Using `puppet`](#using-puppet)
    * [Using `hiera`](#using-hiera)
    * [What this creates on disk](#what-this-creates-on-disk)
  * [Configuring custom profiles](#configuring-custom-profiles)
    * [Using `puppet`](#using-puppet-1)
    * [Globally with `hiera`](#globally-with-hiera)
    * [What this creates on disk](#what-this-creates-on-disk-1)
  * [Restoring the pre-3.0.0 behavior (`simp:defaults`)](#restoring-the-pre-300-behavior-simpdefaults)
* [Reference](#reference)
* [Limitations](#limitations)
* [Development](#development)

<!-- vim-markdown-toc -->

## Description

`dconf` is a Puppet module that installs and manages
[`dconf`](https://wiki.gnome.org/Projects/dconf) - the low-level configuration
system used by GNOME and other desktop components on Enterprise Linux. Its main
hardening value is the **lock** mechanism: a locked key cannot be changed by
the logged-in user, which is how screensaver, media-automount, and similar
settings get enforced.

### How it works

The module manages three things:

1. **The `dconf` package** - all that a bare `include dconf` does.
2. **dconf profiles** (`/etc/dconf/profile/*`) - the ordered list of databases
   consulted for a session. Managed by the `dconf::profile` defined type
   (one `concat` fragment per database entry, sorted by `order`), or globally
   via the `dconf::user_profile` class parameter.
3. **dconf settings and locks** (`/etc/dconf/db/<profile>.d/*`) - the
   key/value rules written into a database, plus a companion `locks/` file for
   every key not explicitly `lock => false`. Managed by the `dconf::settings`
   defined type (or globally via `dconf::user_settings`). Whenever a settings
   or lock file changes, the module runs `dconf update` to rebuild the binary
   database that sessions actually read.

### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our
[bug tracker](https://github.com/simp/pupmod-simp-dconf/issues).

## Breaking changes in 3.0.0

As of 3.0.0, a bare `include dconf` **only installs the `dconf` package**.
The following behaviors are no longer automatic:

* No default user profile is written to `/etc/dconf/profile/user`
  (`dconf::user_profile` now defaults to `undef`)
* No `/etc/dconf/db/<profile>.d/` directories or settings files are created
* Unmanaged files in managed profile directories are no longer purged
  (`dconf::tidy` now defaults to `false`)
* The `use_user_profile_defaults` and `use_user_settings_defaults` parameters
  are **deprecated** and issue a warning when set - behavior is now driven by
  whether `user_profile` / `user_settings` are set (an explicit `false` still
  suppresses the corresponding resources)
* The automatic cleanup resource (`dconf::settings { ...: ensure => 'absent' }`)
  that a bare include declared when `user_settings` was unset is gone; existing
  files are left alone
* The unused `simp/simp_options` metadata dependency was dropped, the
  runtime `puppetlabs/concat` + `puppetlabs/inifile` dependencies are now
  declared, and the `puppetlabs/stdlib` floor was raised to `9.2.0`
* `Dconf::DBSettings` now requires at least one database entry: an empty
  `dconf::user_profile`/`dconf::profile` entries hash is now a compile error

There are two recovery paths:

1. **Per-parameter**: set `dconf::user_profile`, `dconf::tidy`, etc. in Hiera
   yourself, or
2. **The `simp:defaults` compliance profile** (drop-in restoration of the old
   behavior) - see
   [Restoring the pre-3.0.0 behavior](#restoring-the-pre-300-behavior-simpdefaults)

## Setup

To use the module, just include the class:

```puppet
include 'dconf'
```

This installs the `dconf` package and nothing else.

## Usage

### Configuring custom rules

You can configure custom `dconf` settings using the `dconf::settings` defined
type.

> **NOTE**: Locking is *opt-out*: any setting configured through this module
> will automatically be locked (so users cannot modify it) unless you
> explicitly set `lock => false` on that setting.

#### Using `puppet`

```puppet
dconf::settings { 'automount_lockdowns':
  profile       => 'site',
  settings_hash => {
    'org/gnome/desktop/media-handling' => {
      'automount'      => { 'value' => false, 'lock' => false }, # allow users to change this one
      'automount-open' => { 'value' => false },
    },
  },
}
```

The `profile` parameter is optional: when omitted, it falls back to
`dconf::user_profile_defaults_name` (default `Defaults`), as before 3.0.0.

#### Using `hiera`

`dconf::user_settings` takes the settings Hash directly and writes it through
a `dconf::settings` resource named `dconf::user_settings_defaults_name`
(default `Defaults`):

```yaml
---
dconf::user_settings:
  org/gnome/desktop/media-handling:
    automount:
      value: false
      lock: false # allow users to change this one
    automount-open:
      value: false
```

#### What this creates on disk

For the `automount_lockdowns` example above (profile `site`):

```
/etc/dconf/db/site.d/automount_lockdowns        # keyfile with the settings
/etc/dconf/db/site.d/locks/automount_lockdowns  # lock entries (unless everything is lock => false)
/etc/dconf/db/site                              # binary database, rebuilt by `dconf update`
```

`/etc/dconf/db/site.d/automount_lockdowns` contains:

```ini
[org/gnome/desktop/media-handling]
automount=false
automount-open=false
```

`/etc/dconf/db/site.d/locks/automount_lockdowns` contains one line per locked
key (here only `automount-open`, since `automount` set `lock => false`):

```
/org/gnome/desktop/media-handling/automount-open
```

Resource titles are sanitized into filenames: they are lowercased, and
spaces/shell-special characters become `_` (`'Enable lock delay'` →
`enable_lock_delay`). Whenever a settings or lock file changes, the module
runs `dconf update` to rebuild the binary database.

If `dconf::tidy` is `true`, any files in `/etc/dconf/db/<profile>.d/` and its
`locks/` directory that Puppet does not manage are **removed**.

### Configuring custom profiles

You can set up a custom
[dconf profile](https://help.gnome.org/admin//system-admin-guide/3.8/dconf-profiles.html.en)
as follows:

#### Using `puppet`

```puppet
dconf::profile { 'my_profile':
  entries => {
    'user' => {
      'type'  => 'user',
      'order' => 1,
    },
    'system' => {
      'type'  => 'system',
      'order' => 10,
    },
  },
}
```

#### Globally with `hiera`

```yaml
---
dconf::user_profile:
  my_user:
    type: user
    order: 1
  my_system:
    type: system
    order: 10
```

#### What this creates on disk

For the `my_profile` example above:

```
/etc/dconf/profile/my_profile
```

containing one `<type>-db:<name>` line per entry, sorted by `order` (lowest
first, default `15`):

```
user-db:user
system-db:system
```

The Hiera `dconf::user_profile` variant writes `/etc/dconf/profile/user`
(the `dconf::user_profile_target`, default `user`) the same way.

`dconf::user_profile` is looked up with a **deep merge** (set in the module's
`data/common.yaml`), so values from different Hiera levels **merge rather than
replace** each other. To extend a profile set at a lower level, only list your
additions or the fields you want to change:

```yaml
---
dconf::user_profile:
  company:        # added to whatever the lower level defined
    type: system
    order: 25
  site:
    order: 35     # tweaks just this field of the lower level's 'site' entry
```

Note that a database **cannot be removed** through the merge - a deep merge
only adds or overrides keys. To fully replace the hash instead of merging,
override the lookup behavior in your own Hiera:

```yaml
---
lookup_options:
  dconf::user_profile:
    merge: first
```

### Restoring the pre-3.0.0 behavior (`simp:defaults`)

The module ships a `simp:defaults` [Sicura Compliance Engine](https://github.com/simp/rubygem-simp-compliance_engine)
profile (`SIMP/compliance_profiles/`) that restores the pre-3.0.0 defaults as
a drop-in. Activate it with one Hiera key:

```yaml
---
compliance_engine::enforcement:
  - simp:defaults
```

This restores:

* `dconf::user_profile`: the old user (1) / local (20) / site (30) /
  distro (40) hierarchy, written to `/etc/dconf/profile/user`
* `dconf::tidy: true` - **including the destructive purge** of unmanaged
  files in the directories that `dconf::settings` resources manage. `tidy`
  only takes effect where a `dconf::settings` (or `dconf::user_settings`) is
  declared.

To override an individual toggle, set it in your own Hiera, which outranks
the profile:

```yaml
---
compliance_engine::enforcement:
  - simp:defaults
dconf::tidy: false
```

Because `dconf::user_profile` deep-merges (see
[Configuring custom profiles](#globally-with-hiera)), a partial
`dconf::user_profile` hash in your own Hiera extends or tweaks the profile's
hierarchy rather than replacing it.

## Reference

See the [API documentation](./REFERENCE.md) or run `puppet strings` for full
details.

## Limitations

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux
and compatible distributions, such as CentOS.

Please see the [`metadata.json` file](./metadata.json) for the most up-to-date
list of supported operating systems, Puppet versions, and module dependencies.

## Development

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html)
