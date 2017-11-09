proto multi-await($) is export  { * }
multi multi-await(Promise $p)   { multi-await await $p }
multi multi-await($p)           { $p }
