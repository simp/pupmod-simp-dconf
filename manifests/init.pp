# Manage 'dconf' and associated entries
#
# @param user_profile
#   The contents of the user profile that will be added
#
#   @see data/common.yaml
#
# @param package_ensure
#   The version of `dconf` to install
#
#   * Accepts any valid `ensure` parameter value for the `package` resource
#
# @param use_user_profile_defaults
#   Add the default `user_profile` settings to the system
#
# @param user_profile_target
#   The name of the profile that should be targeted for the defaults
#
class dconf (
  Dconf::DBSettings      $user_profile,
  Simplib::PackageEnsure $package_ensure            = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  Boolean                $use_user_profile_defaults = true,
  String[1]              $user_profile_target       = 'user'
) {
  simplib::assert_metadata($module_name)

  include 'dconf::install'

  if $use_user_profile_defaults {
    dconf::profile { 'Defaults':
      target  => $user_profile_target,
      entries => $user_profile
    }
  }
}
