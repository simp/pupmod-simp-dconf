# Manage 'dconf' and associated entries
#
# A bare `include dconf` only installs the `dconf` package. All other
# behavior is opt-in: set `user_profile` and/or `user_settings` directly, or
# enforce the shipped `simp:defaults` compliance profile to restore the
# pre-3.0.0 defaults.
#
# @param user_profile
#   The contents of the default user profile that will be added
#
#   * When set, a `dconf::profile` named `$user_profile_defaults_name` is
#     created targeting `$user_profile_target`
#   * When `undef` (the default), no profile entries are managed
#
# @param user_settings
#   Custom user settings that can be provided via Hiera globally
#
#   * When set, a `dconf::settings` named `$user_settings_defaults_name` is
#     created
#   * When `undef` (the default), no settings are managed
#
# @param package_ensure
#   The version of `dconf` to install
#
#   * Accepts any valid `ensure` parameter value for the `package` resource
#
# @param use_user_profile_defaults
#   **Deprecated** - will be removed in a future release
#
#   * The default profile is now managed whenever `user_profile` is set
#   * Setting this parameter issues a deprecation warning
#   * `false` still suppresses the `dconf::profile` (and, unless overridden by
#     `use_user_settings_defaults`, the `dconf::settings`) for transitional
#     compatibility
#
# @param user_profile_defaults_name
#   The name that should be used for the custom `dconf::profile` in
#   `user_profile`
#
# @param user_profile_target
#   The name of the profile that should be targeted for the defaults
#
# @param use_user_settings_defaults
#   **Deprecated** - will be removed in a future release
#
#   * The default settings are now managed whenever `user_settings` is set
#   * Setting this parameter issues a deprecation warning
#   * `false` still suppresses the `dconf::settings` for transitional
#     compatibility (when unset, follows `use_user_profile_defaults` as
#     before)
#
# @param user_settings_defaults_name
#   The name that should be used for the custom 'dconf::settings' as well as
#   the target profile for those settings
#
# @param tidy
#   If set to true, any files in the profile directories managed by
#   `dconf::settings` that aren't managed by puppet will be purged
#
#   * WARNING: This is destructive - it removes drop-in files placed by the
#     OS, other modules, or administrators. It is disabled by default and
#     should only be enabled deliberately (the `simp:defaults` profile
#     restores the pre-3.0.0 value of `true`)
#   * Only takes effect on directories that `dconf::settings` resources
#     manage - with no `dconf::settings` (or `user_settings`) in the
#     catalog, nothing is purged
#
# @param authselect
#   Flip this parameter to true if you are using authselect and receiving
#   resource conflicts
class dconf (
  Optional[Dconf::DBSettings]   $user_profile                = undef,
  Optional[Dconf::SettingsHash] $user_settings               = undef,
  Variant[String[1],Boolean]    $package_ensure              = 'installed',
  Optional[Boolean]             $use_user_profile_defaults   = undef,
  String[1]                     $user_profile_defaults_name  = 'Defaults',
  String[1]                     $user_profile_target         = 'user',
  Optional[Boolean]             $use_user_settings_defaults  = undef,
  String[1]                     $user_settings_defaults_name = $user_profile_defaults_name,
  Boolean                       $tidy                        = false,
  Boolean                       $authselect                  = false,
) {
  include 'dconf::install'

  if $use_user_profile_defaults =~ NotUndef {
    deprecation(
      'dconf::use_user_profile_defaults',
      "${module_name}: 'dconf::use_user_profile_defaults' is deprecated and will be removed in a future release; the default profile is managed whenever 'dconf::user_profile' is set",
      false,
    )
  }

  if $use_user_settings_defaults =~ NotUndef {
    deprecation(
      'dconf::use_user_settings_defaults',
      "${module_name}: 'dconf::use_user_settings_defaults' is deprecated and will be removed in a future release; the default settings are managed whenever 'dconf::user_settings' is set",
      false,
    )
  }

  if $user_profile =~ NotUndef and $use_user_profile_defaults != false {
    dconf::profile { $user_profile_defaults_name:
      target  => $user_profile_target,
      entries => $user_profile,
    }
  }

  if $user_settings =~ NotUndef and pick($use_user_settings_defaults, $use_user_profile_defaults, true) {
    dconf::settings { $user_settings_defaults_name:
      settings_hash => $user_settings,
      profile       => $user_settings_defaults_name,
    }
  }

  # If using authselect, the following files need to managed or there will be conflicts
  if $authselect {
    file { '/etc/dconf/db/distro.d/20-authselect': }
    file { '/etc/dconf/db/distro.d/locks/20-authselect': }
  }
}
