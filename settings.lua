data:extend({
  {
    type = "double-setting",
    name = "broodmother-mother-scale",
    setting_type = "startup",
    default_value = 1.8,
  },{
    type = "double-setting",
    name = "broodmother-baby-scale",
    setting_type = "startup",
    default_value = 0.5,
  },{
    type = "int-setting",
    name = "broodmother-baby-max-hp",
    setting_type = "startup",
    default_value = 100,
    -- localised_name = ""
  },{
    type = "int-setting",
    name = "broodmother-max-babies",
    setting_type = "runtime-global",
    default_value = 20,
  },{
    type = "int-setting",
    name = "broodmother-spawn-every-nth-tick",
    setting_type = "runtime-global",
    default_value = 20,
  },{
    type = "double-setting",
    name = "broodmother-spawning-hurts-mother-hp",
    setting_type = "runtime-global",
    default_value = 20,
  },{
    type = "double-setting",
    name = "broodmother-mother-hp-regen-per-second",
    setting_type = "runtime-global",
    default_value = 20,
  },{
    type = "double-setting",
    name = "broodmother-baby-distance-multiplier",
    setting_type = "runtime-global",
    default_value = 2,
  },{
    type = "bool-setting",
    name = "broodmother-mother-calls-for-help-when-hurt",
    setting_type = "runtime-global",
    default_value = true,
  },
})