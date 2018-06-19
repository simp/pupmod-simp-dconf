# Install the dconf packages
#
# @api private
class dconf::install {
  assert_private()

  ensure_packages( 'dconf', { 'ensure' => $dconf::package_ensure } )
}
