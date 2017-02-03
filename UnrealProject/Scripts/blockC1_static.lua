-- Copyright 2016, 2017 Mario Ynocente Castro, Mathieu Bernard
--
-- You can redistribute this file and/or modify it under the terms of
-- the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any
-- later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see <http://www.gnu.org/licenses/>.


-- This module defines a test configuration for the block C1: a single
-- change and a single occluder, with static spheres.

local uetorch = require 'uetorch'
local config = require 'config'
local utils = require 'utils'
local tick = require 'tick'

local material = require 'material'
local backwall = require 'backwall'
local occluders = require 'occluders'
local spheres = require 'spheres'
local floor = require 'floor'
local light = require 'light'
local camera = require 'camera'

local M = {}

local iteration
local params = {}

local is_hidden
local visible1 = true
local visible2 = true
local possible = true
local trick1 = false
local trick2 = false
local can_do_trick2 = false

local step, t_check, t_last_check = 0, 0, 0
local function trick(dt)
   if t_check - t_last_check >= config.get_capture_interval() then
      step = step + 1

      local main_actor = M.get_main_actor()

      if not trick1 and is_hidden[step] then
         trick1 = true
         uetorch.SetActorVisible(main_actor, visible2)
      end

      if trick1 and can_do_trick2 and not trick2 and is_hidden[step] then
         trick2 = true
         uetorch.SetActorVisible(M.get_main_actor(), visible1)
      end
      t_last_check = t_check
   end
   t_check = t_check + dt
end


function M.is_possible()
   return possible
end

-- Return random parameters for the C1 block, static test
function M.get_random_parameters()
   local params = {}

   -- occluder
   params.occluders = {}
   params.occluders.n_occluders = 1
   params.occluders.occluder_1 = {
      material = occluders.random_material(),
      movement = 1,
      scale = {
         x = 1 - 0.4 * math.random(),
         y = 1,
         z = 1 - 0.5 * math.random()},
      rotation = 0,
      start_position = 'down',
      pause = {math.random(20), math.random(20)}
   }
   params.occluders.occluder_1.location = {
      x = 100 - 200 * params.occluders.occluder_1.scale.x, y = -350}

   -- spheres
   params.spheres = {}
   params.spheres.n_spheres = spheres.random_n_spheres()
   local x_loc = {150, 40, 260}
   for i = 1, params.spheres.n_spheres do
      local p = {}

      p.material = spheres.random_material()
      p.scale = 1
      p.is_static = true
      p.location = {x = x_loc[i], y = -550, z = 70}

      params.spheres['sphere_' .. i] = p
   end
   params.index = math.random(1, params.spheres.n_spheres)

   -- others
   params.floor = floor.random()
   params.light = light.random()
   params.backwall = backwall.random()

   return params
end


function M.get_main_actor()
   return spheres.get_sphere(params.index)
end


function M.is_main_actor_visible()
   return (possible and visible1) -- visible all time
      or (not possible and visible1 and not trick1) -- visible 1st half
      or (not possible and visible2 and trick1) -- visible 2nd half
end


function M.set_block(iteration, params)
   if iteration.type == 5 then
      for i = 1,3 do
         if i ~= params.index then
            uetorch.DestroyActor(spheres.get_sphere(i))
         end
      end
   else
      is_hidden = torch.load(iteration.path .. '../hidden_5.t7')
      tick.add_tick_hook(trick)

      if iteration.type == 1 then
         visible1 = false
         visible2 = false
         possible = true
      elseif iteration.type == 2 then
         visible1 = true
         visible2 = true
         possible = true
      elseif iteration.type == 3 then
         visible1 = false
         visible2 = true
         possible = false
      elseif iteration.type == 4 then
         visible1 = true
         visible2 = false
         possible = false
      end
   end
end


function M.check()
   local iteration = config.get_current_iteration()
   local status = true

   torch.save(iteration.path .. '../check_' .. iteration.type .. '.t7', check_data)

   if iteration.type == 1 then
      local found_hidden = false
      for i = 1,#is_hidden do
         if is_hidden[i] then
            found_hidden = true
         end
      end

      if not found_hidden then
         -- print("Iteration check failed on condition 1\n")
         status = false
      end

      if status then
         local size = config.get_block_size(iteration)
         local ticks = config.get_scene_ticks()
         local all_data = {}

         for i = 1,size do
            local aux = torch.load(iteration.path .. '../check_' .. i .. '.t7')
            all_data[i] = aux
         end

         local max_diff = 1e-6
         for t = 1, ticks do
            for i = 2, size do
               -- check location and rotation values
               if((math.abs(all_data[i][t].location.x - all_data[1][t].location.x) > max_diff) or
                     (math.abs(all_data[i][t].location.y - all_data[1][t].location.y) > max_diff) or
                     (math.abs(all_data[i][t].location.z - all_data[1][t].location.z) > max_diff) or
                     (math.abs(all_data[i][t].rotation.pitch - all_data[1][t].rotation.pitch) > max_diff) or
                     (math.abs(all_data[i][t].rotation.yaw - all_data[1][t].rotation.yaw) > max_diff) or
                     (math.abs(all_data[i][t].rotation.roll - all_data[1][t].rotation.roll) > max_diff)) then
                  status = false
               end
            end
         end
      end
   end

   config.update_iterations_counter(status)
end


return M


-- function M.is_possible()
--    return possible
-- end

-- function M.get_status()
--    local nactors = M.get_nactors()
--    local _, _, actors = M.get_masks()
--    actors = backwall.get_updated_actors(actors)

--    local masks = {}
--    masks[0] = "sky"
--    for n, m in pairs(actors) do
--       masks[math.floor(255 * n / nactors)] = m
--    end

--    local status = {}
--    status['possible'] = M.is_possible()
--    status['floor'] = floor.get_status()
--    status['camera'] = camera.get_status()
--    status['lights'] = light.get_status()
--    status['masks_grayscale'] = masks

--    return status
-- end

-- function M.get_masks()
--    local active, inactive, text = {}, {}, {}

--    floor.insert_masks(active, text)
--    backwall.insert_masks(active, text, params.backwall)
--    occluders.insert_masks(active, text, params.occluders)

--    -- on test, the main actor only can be inactive (when hidden)
--    for i = 1, params.spheres.n_spheres do
--       table.insert(text, "sphere_" .. i)
--       if i ~= params.index then
--          table.insert(active, spheres.get_sphere(i))
--       end
--    end

--    -- We add the main actor as active only when it's not hidden
--    if M.is_main_actor_visible() then
--       table.insert(active, main_actor)
--    else
--       table.insert(inactive, main_actor)
--    end

--    return active, inactive, text
-- end


-- function M.get_nactors()
--    local max = 2 -- floor + occluder
--    if params.backwall.is_active then
--       max = max + 1
--    end
--    return max + params.spheres.n_spheres
-- end


-- function M.run_block()
--    -- camera, floor, occluder, lights and background wall
--    camera.setup(config.get_current_iteration(), 150)
--    floor.setup(params.floor)
--    occluders.setup(params.occluders)
--    light.setup(params.light)
--    backwall.setup(params.backwall)
--    spheres.setup(params.spheres)

--    uetorch.SetActorVisible(spheres.get_sphere(params.index), visible1)
-- end
