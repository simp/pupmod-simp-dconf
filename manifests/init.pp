# Manage 'dconf' and associated entries
#
# @param user_profile
#   The contents of the default user profile that will be added
#
#   @see data/common.yaml
#
# @param user_settings
#   Custom user settings that can be provided via Hiera globally
#
# @param package_ensure
#   The version of `dconf` to install
#
#   * Accepts any valid `ensure` parameter value for the `package` resource
#
# @param use_user_profile_defaults
#   Add the default `user_profile` settings to the system
#
# @param user_profile_defaults_name
#   The name that should be used for the custom `dconf::profile` in
#   `user_profile`
#
# @param user_profile_target
#   The name of the profile that should be targeted for the defaults
#
# @param use_user_settings_defaults
#   Enable creation of custom `dconf::settings` based on the `user_settings` Hash
#
# @param user_settings_defaults_name
#   The name that should be used for the custom 'dconf::settings' as well as
#   the target profile for those settings
#
# @param tidy
#   If set to true, any files in the profile directory that aren't managed by puppet
#   will be purged
#
class dconf (
  Dconf::DBSettings             $user_profile,
  Optional[Dconf::SettingsHash] $user_settings               = undef,
  Simplib::PackageEnsure        $package_ensure              = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  Boolean                       $use_user_profile_defaults   = true,
  String[1]                     $user_profile_defaults_name  = 'Defaults',
  String[1]                     $user_profile_target         = 'user',
  Boolean                       $use_user_settings_defaults  = $use_user_profile_defaults,
  String[1]                     $user_settings_defaults_name = $user_profile_defaults_name,
  Boolean                       $tidy                        = true,
) {
  simplib::assert_metadata($module_name)

  include 'dconf::install'

  if $use_user_profile_defaults {
    dconf::profile { $user_profile_defaults_name:
      target  => $user_profile_target,
      entries => $user_profile,
    }
  }

  if $user_settings and $use_user_settings_defaults {
    dconf::settings { $user_settings_defaults_name:
      settings_hash => $user_settings,
      profile       => $user_settings_defaults_name,
    }
  }
  else {
    dconf::settings { $user_settings_defaults_name:
      ensure => 'absent',
    }
  }

  # If using authselect, the following files need to managed or there will be conflicts
  if $simp_options::authselect {
    file { '/etc/dconf/db/distro.d/20-authselect': }
    file { '/etc/dconf/db/distro.d/locks/20-authselect': }
  }
}
