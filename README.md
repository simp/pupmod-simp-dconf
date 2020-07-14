[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/dconf.svg)](https://forge.puppetlabs.com/simp/dconf)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/dconf.svg)](https://forge.puppetlabs.com/simp/dconf)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-dconf.svg)](https://travis-ci.org/simp/pupmod-simp-dconf)

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Description](#description)
  * [This is a SIMP module](#this-is-a-simp-module)
* [Setup](#setup)
* [Usage](#usage)
  * [Configuring custom rules](#configuring-custom-rules)
* [> to prevent users from modifying them!](#-to-prevent-users-from-modifying-them)
    * [Using `puppet`](#using-puppet)
    * [Using `hiera`](#using-hiera)
  * [Configuring custom profiles](#configuring-custom-profiles)
    * [Using `puppet`](#using-puppet-1)
    * [Globally With `hiera`](#globally-with-hiera)
* [Reference](#reference)
* [Limitations](#limitations)
* [Development](#development)

<!-- vim-markdown-toc -->

## Description

`dconf` is a Puppet module that installs and manages `dconf` and associated system settings.

### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com)
a compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our [bug tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but
it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will
   be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by
   default and must be explicitly opted into by administrators.  See
   [simp_options](https://github.com/simp/pupmod-simp-simp_options) for more
   detail.

## Setup

To use the module with, just include the class:

```ruby
include 'dconf'
```

## Usage

### Configuring custom rules

You can configure custom ``dconf`` settings using the ``dconf::settings``
defined type.

---
> Any settings that are configured using this code will automatically be locked
> to prevent users from modifying them!
---

#### Using `puppet`

```puppet
dconf::settings { 'automount_lockdowns':
  settings_hash => {
    'org/gnome/desktop/media-handling' => {
      'automount'      => { 'value' => false, 'lock' => false } # allow users to change this one
      'automount-open' => { 'value' => false }
    }
  }
}
```

#### Using `hiera`

```yaml
---
dconf::user_settings:
  settings_hash:
    org/gnome/desktop/media-handling:
      automount:
        value: false
        lock: false # allow users to change this one
      automount-open:
        value: false
```

### Configuring custom profiles

You can set up a custom [dconf profile](https://help.gnome.org/admin//system-admin-guide/3.8/dconf-profiles.html.en) as follows:

#### Using `puppet`

```puppet
dconf::profile { 'my_profile':
  entries => {
    'user' => {
      'type' => 'user',
      'order' => 1
    },
    'system' => {
      'type' => 'system',
      'order' => 10
    }
  }
```

#### Globally With `hiera`

```yaml
---
dconf::user_profile:
  my_user:
    type: user
    order: 0
  my_system:
    type: system
    order: 10
```

## Reference

See the [API documentation](./REFERENCE.md) or run `puppet strings` for full
details.

## Limitations

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux
and compatible distributions, such as CentOS.

Please see the [`metadata.json` file](./metadata.json) for the most up-to-date
list of supported operating systems, Puppet versions, and module dependencies.

## Development

Please read our [Contribution Guide] (https://simp.readthedocs.io/en/stable/contributors_guide/index.html)
