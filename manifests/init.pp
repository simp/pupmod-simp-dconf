# Manage 'dconf' and associated entries
#
# @param package_ensure
#   The version of `dconf` to install
#
#   * Accepts any valid `ensure` parameter value for the `package` resource
#
class dconf (
  String[1] $package_ensure = 'present'
) {
  simplib::assert_metadata($module_name)

  include 'dconf::install'
}
