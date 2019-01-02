# Add a dconf rule to the profile of your choice
#
# This adds a configuration file to the /etc/dconf/db/<profile>.d directory.
# The dconf datbase is updated when any rule is added.  You can also elect to
# lock a value so that general users cannot change it.
#
# @param settings_hash A hash to define the settings to be generated. You can set
#   whether to lock each setting like in the exmaple
#   An example hash would look like:
#   ```
#   {
#     'org/gnome/desktop/media-handling' => {
#       'automount' => { 'value' => false, 'lock' => false },
#       'automount-open' => { 'value' => false }
#     }
#   }
#   ```
#
# @param profile The dconf profile where you want to place the key/value.
# @param ensure Ensure the setting is present or absent
# @param base_dir The database base directory. This probably shouldn't be changed.
#
define dconf::settings (
  Dconf::SettingsHash      $settings_hash,
  String[1]                $profile,
  Enum['present','absent'] $ensure         = 'present',
  Stdlib::AbsolutePath     $base_dir       = '/etc/dconf/db',
) {

  include 'dconf'

  $_name = regsubst($name.downcase, '( |/|!|@|#|\$|%|\^|&|\*|[|])', '_', 'G')

  $_profile_dir = "${base_dir}/${profile}.d"
  $_target = "${_profile_dir}/${_name}"

  ensure_resource('file', $_profile_dir, {
    'ensure'  => 'directory',
    'owner'   => 'root',
    'group'   => 'root',
    'mode'    => '0644',
    'recurse' => true,
    'purge'   => true,
    require  => Class['dconf::install']
  })

  ensure_resource('file', $_target, {
    'ensure' => 'file',
    'owner'  => 'root',
    'group'  => 'root',
    'mode'   => '0644'
  })

  $_lock_content = flatten($settings_hash.map |$_schema, $_settings| {

    $_settings.keys.each |$_key| {
      ini_setting { "${_target} [${_schema}] $_key":
        ensure  => 'present',
        path    => $_target,
        section => $_schema,
        setting => $_key,
        value   => $_settings[$_key]['value'],
        notify  => Exec["dconf update ${name}"]
      }
    }

    $_settings_to_lock = $_settings.map |$_item, $_setting| {
      if $_setting['lock'] == false {
        $_ret = undef
      }
      else {
        $_ret = "/${$_schema}/${_item}"
      }
      $_ret
    }

    $_settings_to_lock.delete_undef_values
  }).join("\n")

  if $_lock_content == '' {
    ensure_resource('file', "${_profile_dir}/locks/${_name}", {
      ensure => absent
    })
  }
  else {
    ensure_resource('file', "${_profile_dir}/locks", {
      ensure  => 'directory',
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      recurse => true,
      purge   => true
    })

    ensure_resource('file', "${_profile_dir}/locks/${_name}", {
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => $_lock_content,
      notify  => Exec["dconf update ${name}"]
    })
  }

  # `dconf update` doesn't return anything besides 0, so we have to figure out
  # if it was successful
  exec { "dconf update ${name}":
    command     => '/bin/dconf update |& /bin/tee /dev/fd/2 | /bin/wc -c | /bin/grep ^0$',
    logoutput   => true,
    umask       => '0033',
    refreshonly => true
  }
}
