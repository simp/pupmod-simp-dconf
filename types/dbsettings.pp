# @summary Valid dconf database settings
#
# At least one database entry is required: an empty hash would render an
# empty profile file over the vendor-shipped one.
type Dconf::DBSettings = Hash[
  String[1],                                              # The name of the database
  Struct[{
    'type'  => Enum['user', 'system', 'service', 'file'], # The type of database
    'order' => Optional[Integer[1]]                       # The order of the entry in the list
  }],
  1
]
