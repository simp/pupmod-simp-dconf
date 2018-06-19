type Dconf::SettingsHash = Hash[
  String[1],
  Hash[
    String[1],
    Struct[{
      'value' => NotUndef,
      'lock'  => Optional[Boolean]
    }]
  ]
]
