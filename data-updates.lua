local mod_name = 'Broodmother'

local map = require('lib.functional').map
local fnn = require('lib.functional').fnn

function mult(v, s)
    return {v[1] * s, v[2] * s}
end

function mult_area(v, s)
    return {mult(v[1], s), mult(v[2], s)}
end


function rescale_graphics(o, scale)
    o.scale = (o.scale or 1) * scale
    o.shift = mult(o.shift or {0, 0}, scale)
end

function rescale_graphics_and_hr(o, scale)
    rescale_graphics(o, scale)
    if o.hr_version then
        rescale_graphics(o.hr_version, scale)
    end
end

function recursive_modify_graphics(o, scaler)
    if type(o) ~= 'table' then return end
    scaler(o)
    for k, v in pairs(o) do
        recursive_modify_graphics(v, scaler)
    end
end

function delta(i, total, scale)
    if scale == nil then scale = total end
    return mult({math.cos(math.pi * 2 * i / total), math.sin(math.pi * 2 * i / total)}, scale)
end

local factor = {
    mother = {scale = settings.startup['broodmother-mother-scale'].value, color = {r = 1, g = 0, b = 0, a = 1}, leg_speed_scale = 1, inventory_size = 160, max_health = 1500},
    baby   = {scale = settings.startup['broodmother-baby-scale'].value,   color = {r = 0, g = 0, b = 0, a = 1}, leg_speed_scale = 3, inventory_size = 0,   max_health = settings.startup['broodmother-baby-max-hp'].value, no_result = true, alert = false}
}


-- for i, leg in pairs(data.raw['spider-leg']) do
--   leg.initial_movement_speed = leg.initial_movement_speed * speed_multiplier
--   leg.movement_acceleration  = leg.movement_acceleration  * speed_multiplier
-- end

function tint_icon(thing, tint)
    thing.icons = {{
        icon = thing.icon or (thing.icons and thing.icons[1] and thing.icons[1].icon) or nil,
        icon_size = thing.icon_size or (thing.icons and thing.icons[1] and thing.icons[1].icon_size) or nil,
        tint = tint,
        dark_background_icon = thing.dark_background_icon or (thing.icons and thing.icons[1] and thing.icons[1].dark_background_icon) or nil,
    }}
    thing.icon = nil
    thing.icon_size = nil
    thing.dark_background_icon = nil
end

function multi_composition_icon(thing, tint_scale_position_list)
    local icons = {{
        icon = '__'..mod_name..'__/graphics/0.png',
        icon_size = 1,
        scale = 1, -- scale is bugged, so we need a blank scale 1 image first
        -- https://forums.factorio.com/viewtopic.php?f=7&t=71480&p=433700&hilit=scale#p433700
    }}
    for i, properties in ipairs(tint_scale_position_list) do
        local size = thing.icon_size or (thing.icons and thing.icons[1] and thing.icons[1].icon_size) or nil
        local scale = properties.scale or 1
        table.insert(icons, {
            icon = thing.icon or (thing.icons and thing.icons[1] and thing.icons[1].icon) or nil,
            icon_size = size,
            tint = properties.tint or {r = 1, g = 1, b = 1, a = 1},
            scale = scale / size,
            shift = mult(properties.position or {0, 0}, properties.shift_scale or 1),
            dark_background_icon = thing.dark_background_icon or (thing.icons and thing.icons[1] and thing.icons[1].dark_background_icon) or nil,
        })
    end
    thing.icons = icons
    thing.icon = nil
    thing.icon_size = nil
    thing.dark_background_icon = nil
end

for name2, spiderdata in pairs(factor) do
    local scale = spiderdata.scale
    local color = spiderdata.color

    local tron_parts = {}


    local tron_item = table.deepcopy(data.raw['item-with-entity-data']['spidertron'])
    tron_item.name = 'spider-'..name2
    tron_item.place_result = 'spider-'..name2
    tint_icon(tron_item, color)
    tron_item.icon_tintable = nil
    tron_item.icon_tintable_mask = nil
    table.insert(tron_parts, tron_item)

    if not spiderdata.no_result then
        local tron_recipe = table.deepcopy(data.raw['recipe']['spidertron'])
        tron_recipe.name = 'spider-'..name2
        tron_recipe.enabled = false
        tron_recipe.result = 'spider-'..name2
        tron_recipe.ingredients = {
            {"spidertron", 30},
            {"raw-fish", 1000},
        }
        -- tron_recipe.icon = tron_item.icon
        -- tron_recipe.icon_size = tron_item.icon_size
        -- tint_icon(tron_recipe, color)
        table.insert(tron_parts, tron_recipe)

        local tron_tech = table.deepcopy(data.raw.technology.spidertron)
        local composition = {{tint = factor.mother.color}}
        local babies = 8
        for i = 1, babies do table.insert(composition, {tint = factor.baby.color, scale = 0.25, position = delta(i + 0.5, babies, 0.45)}) end
        multi_composition_icon(tron_tech, composition)
        tron_tech.name = 'spider-'..name2
        tron_tech.prerequisites = {'spidertron'}
        tron_tech.effects = {
          {
            type = 'unlock-recipe',
            recipe = 'spider-'..name2
          },
        }
        table.insert(tron_parts, tron_tech)
    end

    local tron_corpse = table.deepcopy(data.raw['corpse']['spidertron-remnants'])
    tron_corpse.name = name2..'-'..tron_corpse.name
    tint_icon(tron_corpse, color)
    recursive_modify_graphics(tron_corpse.animation, function(o) if o.filename then rescale_graphics(o, scale) end end)
    tron_corpse.selection_box = mult_area(tron_corpse.selection_box, scale)
    table.insert(tron_parts, tron_corpse)

    local tron_grid = table.deepcopy(data.raw['equipment-grid']['spidertron-equipment-grid'])
    tron_grid.name = name2..'-'..tron_grid.name
    table.insert(tron_parts, tron_grid)
    -- log(serpent.block(tron_grid))

    local tron = table.deepcopy(data.raw['spider-vehicle'].spidertron)
    tron.name = 'spider-'..name2
    tron.minable.result = not spiderdata.no_result and 'spider-'..name2 or nil
    tron.equipment_grid = tron_grid.name
    tron.corpse = tron_corpse.name
    tint_icon(tron, color)
    tron.map_color = color
    tron.collision_box = mult_area(tron.collision_box, scale)
    tron.selection_box = mult_area(tron.selection_box, scale)
    tron.height = tron.height * scale
    tron.inventory_size = spiderdata.inventory_size
    tron.max_health = spiderdata.max_health
    if spiderdata.alert ~= nil then
        tron.alert_when_damaged = spiderdata.alert
    end
    -- tron.chain_shooting_cooldown_modifier = tron.chain_shooting_cooldown_modifier / scale
    -- tron.chunk_exploration_radius = math.ceil(tron.chunk_exploration_radius * scale)
    -- tron.movement_energy_consumption = "10kW"
    recursive_modify_graphics(tron.graphics_set, function(o) if o.filename then rescale_graphics(o, scale) end end)

    for j, leg in pairs(tron.spider_engine.legs) do
        leg.leg = name2..'-'..leg.leg
        leg.ground_position = mult(leg.ground_position, scale)
        leg.mount_position = mult(leg.mount_position, scale)
    end
    table.insert(tron_parts, tron)
    -- log(serpent.block(tron))

    local tron_legs = {}
    for k, v in pairs(data.raw['spider-leg']) do
        table.insert(tron_legs, {k = k, v = v})
    end
    tron_legs = map(tron_legs, function(o)
        o.v = table.deepcopy(o.v)
        local leg = o.v
        leg.name = name2..'-'..leg.name
        leg.part_length = leg.part_length * scale

        local leg_scale = scale >= 1 and scale or (1 + scale) / 2 -- super thin legs with perfect scaling doesn't look as good on scaled down spiders

        recursive_modify_graphics(leg.graphics_set, function(o)
            if o.filename --[[and string.match(o.filename, 'stretch')--]] then
                rescale_graphics(o, leg_scale)
            else
                for k, v in pairs(o) do
                    if type(v) == 'number' and (string.match(k, 'length') or (string.match(k, 'offset') and not string.match(k, 'turn'))) then
                        o[k] = o[k] * leg_scale
                    end
                end
            end
        end)

        leg.initial_movement_speed = leg.initial_movement_speed * spiderdata.leg_speed_scale
        leg.movement_acceleration  = leg.movement_acceleration  * spiderdata.leg_speed_scale

        return leg
    end)

    data:extend(tron_parts)
    data:extend(tron_legs)
end



