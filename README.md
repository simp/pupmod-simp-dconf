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

All `dconf` settings are locked by default so that users can't change them.

This can be disabled on a per setting basis, like in this entry for wallpaper
taken from the `simp-gnome` module.

```yaml
gnome::dconf_hash:
  org/dconf/desktop/background:
    picture-uri:
      value: file:///usr/local/corp/puppies.jpg
      lock: false
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

Please read our [Contribution Guide] (http://simp-doc.readthedocs.io/en/stable/contributors_guide/index.html)
