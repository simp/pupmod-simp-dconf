# Add a dconf rule to the profile of your choice
#
# This adds a configuration file to the /etc/dconf/db/<profile>.d directory.
# The dconf database is updated when any rule is added.  You can also elect to
# lock a value so that general users cannot change it.
#
# @param settings_hash
#   A Hash to define the settings to be generated. You can set whether to lock
#   each setting like in the exmaple
#
#   @example
#     {
#       'org/gnome/desktop/media-handling' => {
#         'automount' => { 'value' => false, 'lock' => false },
#         'automount-open' => { 'value' => false }
#       }
#     }
#
# @param key_val_separator
#   The character(s) that should be placed between the key and value, default will be '='.
#
# @param profile
#   The dconf profile where you want to place the key/value.
#
# @param ensure
#   Ensure the entire settings Hash is present or absent
#
# @param base_dir
#   The database base directory. This probably shouldn't be changed.
#
define dconf::settings (
  Dconf::SettingsHash      $settings_hash     = {},
  Optional[String[1]]      $profile           = undef,
  String                   $key_val_separator = '=',
  Enum['present','absent'] $ensure            = 'present',
  Stdlib::AbsolutePath     $base_dir          = '/etc/dconf/db',
) {
  include 'dconf'

  if $profile {
    $_profile = $profile
  }
  elsif $dconf::use_user_profile_defaults {
    $_profile = $dconf::user_profile_defaults_name
  }
  else {
    fail("You must specifiy a '${profile}' for '${title}'")
  }

  $_name = regsubst($name.downcase, '( |/|!|@|#|\$|%|\^|&|\*|[|])', '_', 'G')

  $_profile_dir = "${base_dir}/${_profile}.d"
  $_target = "${_profile_dir}/${_name}"

  ensure_resource('file', $_profile_dir, {
      'ensure'  => 'directory',
      'owner'   => 'root',
      'group'   => 'root',
      'mode'    => '0644',
      'recurse' => true,
      'purge'   => $dconf::tidy,
      require   => Class['dconf::install']
  })

  ensure_resource('file', $_target, {
      'ensure' => 'file',
      'owner'  => 'root',
      'group'  => 'root',
      'mode'   => '0644'
  })

  $_lock_content = flatten($settings_hash.map |$_schema, $_settings| {
      $_settings.keys.each |$_key| {
        ini_setting { "${_target} [${_schema}] ${_key}":
          ensure            => $ensure,
          path              => $_target,
          section           => $_schema,
          setting           => $_key,
          value             => $_settings[$_key]['value'],
          key_val_separator => $key_val_separator,
          notify            => Exec["dconf update ${title}"],
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
        purge   => $dconf::tidy
    })

    ensure_resource('file', "${_profile_dir}/locks/${_name}", {
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        content => $_lock_content,
        notify  => Exec["dconf update ${title}"]
    })
  }

  # `dconf update` doesn't return anything besides 0, so we have to figure out
  # if it was successful
  exec { "dconf update ${title}":
    command     => '/bin/dconf update |& /bin/tee /dev/fd/2 | /bin/wc -c | /bin/grep ^0$',
    logoutput   => true,
    umask       => '0033',
    refreshonly => true,
  }
}
