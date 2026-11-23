# Install the dconf packages
#
# @api private
class dconf::install {
  assert_private()

  stdlib::ensure_packages( $dconf::package_name, { 'ensure' => $dconf::package_ensure })
}
