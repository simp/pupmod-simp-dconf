# Updates a ``dconf`` profile entry to ``/etc/dconf/profile/$name``
#
# @see man 7 dconf
#
# @param name
#   A globally unique name for the entry
#
# @param target
#   The name of the profile file in ``base_dir``
#
# @param entries
#   One or entries in the following Hash format:
#
#   @example Profile Hierarchy Hash
#     'user':          # Name of the database
#       'type': 'user' # DB Type
#       'order': 0     # Priority order (optional, defaults to 15)
#
#   * The suggested default hierarchy used by the module data is as follows:
#     * User DB   => 0
#     * SIMP DB   => 10
#     * System DB => Between 11 and 39
#     * Distro DB => 40
#
# @param target
#   The target directory within which to create the profile
#
# @param base_dir
#   The base directory that will hold the resulting file
#
define dconf::profile (
  Dconf::DBSettings    $entries,
  String[1]            $target = $name,
  Stdlib::AbsolutePath $base_dir = '/etc/dconf/profile'
) {
  include 'dconf'

  ensure_resource('file', $base_dir, {
    'ensure' => 'directory',
    'owner'  => 'root',
    'group'  => 'root',
    'mode'   => '0644',
    require  => Class['dconf::install']
  })

  ensure_resource('concat', "${base_dir}/${target}", {
    'ensure' => 'present',
    'order'  => 'numeric'
  })

  $_default_order = 15

  $entries.each |String[1] $db_name, Hash $attrs| {
    concat::fragment { "${module_name}::profile::${target}::${db_name}":
      target  => "${base_dir}/${target}",
      content => "${attrs['type']}-db:${db_name}\n",
      order   => pick($attrs['order'], $_default_order)
    }
  }
}
