function add(p, q) return {p[1] + q[1], p[2] + q[2]} end
function mult(v, s) return {v[1] * s, v[2] * s} end
function neg(p) return {-p[1], -p[2]} end
function sub(p, q) return add(p, neg(q)) end
function apos(pos) return {pos.x, pos.y} end
function length(p) return (p[1]^2 + p[2]^2)^0.5 end
function distance(p, q) return length(sub(p, q)) end

function on_init(event)
    global.babydata = {}
    global.motherdata = {}
end

script.on_init(on_init)

function delta(i, total, scale)
    if scale == nil then scale = total end
    return mult({math.cos(math.pi * 2 * i / total), math.sin(math.pi * 2 * i / total)}, scale)
end

function has_active_defense(grid)
    for k, _ in pairs(grid.get_contents()) do
        if game.equipment_prototypes[k].type == 'active-defense-equipment' then
            return true
        end
    end
end

script.on_event(defines.events.on_player_removed_equipment, function(event)
    --[[
Contains
player_index :: uint
grid :: LuaEquipmentGrid: The equipment grid removed from.
equipment :: string: The equipment removed.
count :: uint: The count of equipment removed.
    --]]

    if event.grid.prototype.name == 'baby'..'-'..'spidertron-equipment-grid' then
        game.players[event.player_index].remove_item{name = event.equipment, count = event.count}
        for i = 1, event.count do
            event.grid.put{name = event.equipment}
        end
    end
end)

script.on_event(defines.events.on_pre_player_mined_item, function(event)
    local baby = event.entity
    baby.grid.clear()
end, {{filter = 'name', name = 'spider-baby'}})

script.on_event(defines.events.on_built_entity, function(event)
    --[[
 Called when player builds something. Can be filtered using LuaPlayerBuiltEntityEventFilters

Contains
created_entity :: LuaEntity
player_index :: uint
stack :: LuaItemStack
item :: LuaItemPrototype (optional): The item prototype used to build the entity. Note this won't exist in some situations (built from blueprint, undo, etc).
tags :: Tags (optional): The tags associated with this entity if any.
    --]]

    -- if event.created_entity.name ~= 'spider-mother' then return end
    local mother = event.created_entity
    mother.color = {r = 1, g = 0, b = 0}
    mother.vehicle_automatic_targeting_parameters = {auto_target_without_gunner = false, auto_target_with_gunner = false}

    global.motherdata[mother.unit_number] = {babies = {}, babylist = {}, mother = mother, sortvalue_reuse_list = {}}
end, {{filter = 'name', name = 'spider-mother'}})


script.on_event(defines.events.on_tick, function(event)
    local dist_mult = settings.global["broodmother-baby-distance-multiplier"].value
    local maxbabies = math.max(0, settings.global["broodmother-max-babies"].value)
    local max_dist = maxbabies * 3 * dist_mult

    for unit_number, babydata in pairs(global.babydata) do
        local baby = babydata.baby
        if not baby.valid then
            local motherdata = global.motherdata[babydata.mother_un]
            if motherdata then table.insert(motherdata.sortvalue_reuse_list, babydata.sortvalue) end
            global.babydata[unit_number] = nil
        else
            local mother = babydata.mother
            if not mother.valid or distance(apos(mother.position), apos(baby.position)) > max_dist or (baby.get_inventory(defines.inventory.car_ammo).is_empty() and not has_active_defense(baby.grid)) then
                local mother_force = (mother.valid and mother.force) or (babydata.mother_force.valid and babydata.mother_force) or nil
                if mother_force ~= nil then
                    local mommy = mother.valid and mother or nil
                    if mommy then baby.die(mother_force, mommy) -- because apparently setting nil as 2nd argument crashes the mod !?!? wtf
                    else          baby.die(mother_force) end
                else
                    baby.destroy()
                end
                global.babydata[unit_number] = nil
            end
        end
    end

    for unit_number, obj in pairs(global.motherdata) do
        if not obj.mother.valid then
            global.motherdata[unit_number] = nil
        else
            local motherdata = global.motherdata[unit_number]
            local mother = obj.mother
            local recall_mult = 1
            if settings.global["broodmother-mother-calls-for-help-when-hurt"].value then
                recall_mult = mother.health / mother.prototype.max_health
            end
            if game.tick % math.max(1, settings.global["broodmother-spawn-every-nth-tick"].value) == 0 then
                local spawned_baby = false
                if (motherdata.babycount or 0) < maxbabies then
                    local p = apos(mother.position)
                    local mother_ammo_inv = mother.get_inventory(defines.inventory.car_ammo)
                    local mother_trunk_inv = mother.get_inventory(defines.inventory.car_trunk)
                    local can_deliver_ammo = false
                    if not mother.vehicle_automatic_targeting_parameters.auto_target_without_gunner and not mother.vehicle_automatic_targeting_parameters.auto_target_with_gunner then
                        for k, v in pairs(mother_ammo_inv.get_contents()) do
                            if mother_trunk_inv.get_item_count(k) > 0 then
                                can_deliver_ammo = true
                                -- break
                            end
                        end
                    end
                    local m = 5
                    if has_active_defense(mother.grid) or can_deliver_ammo then
                        local i = 1
                        while not spawned_baby and i <= m do
                        -- for i = 1, m do
                            local position = add(p, delta(math.random() * m, 1.8^i))
                            local baby = mother.surface.create_entity{name = 'spider-baby', position = position, force = mother.force}
                            if baby ~= nil then
                                spawned_baby = true
                                baby.color = {r = 0, g = 0, b = 0}
                                baby.vehicle_automatic_targeting_parameters = {auto_target_without_gunner = true}
                                if can_deliver_ammo then
                                    local baby_ammo_inv   = baby.get_inventory(defines.inventory.car_ammo)
                                    for i = 1, math.min(#mother_ammo_inv, #baby_ammo_inv) do
                                        local stack = mother_ammo_inv[i]
                                        if stack.valid_for_read and stack.count > 0 then
                                            local count = mother_trunk_inv.remove{name = stack.name, count = stack.count}
                                            if count > 0 then baby_ammo_inv[i].set_stack{name = stack.name, count = count} end
                                        end
                                    end
                                end
                                for _, eq in pairs(mother.grid.equipment) do
                                    baby.grid.put{name = eq.name, position = eq.position}
                                end
                                -- baby.insert{name = 'explosive-rocket', count = 200*4}
                                global.babydata[baby.unit_number] = {baby = baby, mother = mother, mother_un = mother.unit_number, mother_force = mother.force,
                                    sortvalue = (recall_mult < 0.9 and table.remove(motherdata.sortvalue_reuse_list) or {math.random(), math.random()})}
                                if #motherdata.sortvalue_reuse_list > maxbabies then motherdata.sortvalue_reuse_list = {} end
                                motherdata.babies[baby.unit_number] = {baby = baby}
                                -- break
                            end
                            i = i + 1
                        end
                    end

                end
                if spawned_baby then
                    mother.health = mother.health - settings.global["broodmother-spawning-hurts-mother-hp"].value
                end
            end
            mother.health = mother.health + settings.global["broodmother-mother-hp-regen-per-second"].value / 60

            local sorted_babies = {}
            local count = 0
            for unit_number, mothers_babydata in pairs(motherdata.babies) do
                local baby = mothers_babydata.baby
                if not baby.valid then
                    motherdata.babies[unit_number] = nil
                else
                    count = count + 1
                    table.insert(sorted_babies, baby.unit_number)
                end
            end
            motherdata.babycount = count
            table.sort(sorted_babies, function(a, b) return global.babydata[a].sortvalue[1] < global.babydata[b].sortvalue[1] end)

            -- game.print(count..' '..table_size(sorted_babies))
            -- game.print(game.table_to_json(sorted_babies))

            local manual_recall = 1
            local commanders = {
                mother.last_user,
                mother.get_driver(),
                -- mother.get_passenger()
            }
            for _, commander in pairs(commanders) do
                if commander ~= nil and commander.selected == mother then
                    manual_recall = 0
                    break
                end
            end
            for i, unit_number in pairs(sorted_babies) do
                local baby = global.babydata[unit_number].baby
                local baby_pos = apos(baby.position)
                local d = delta(i + 0.5, count, math.max(6, math.max(10, count * dist_mult * (i % 2 == 0 and recall_mult or 1)) * manual_recall))
                local p1 = add(apos(mother.position), d)

                -- local p2 = add(apos(mother.autopilot_destination or mother.position), d)
                -- if distance(baby_pos, p1) > max_dist / 2 then p2 = p1 end
                -- baby.autopilot_destination = p2

                baby.autopilot_destination = p1
            end
        end
    end
end)

function clean()
    -- for _, surface in pairs(game.surfaces) do
    --     local spiders = surface.find_entities_filtered{name = {'spider-baby', 'spider-mother'}}
    --     for _, spider in pairs(spiders) do
    --         spider.destroy()
    --     end
    -- end
    -- global = {}
    -- on_init()
end

script.on_configuration_changed(function(event)
    local cmc = event.mod_changes['Broodmother']
    if cmc and cmc.old_version ~= cmc.new_version then clean() end
end)