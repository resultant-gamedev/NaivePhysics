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


local uetorch = require 'uetorch'
local config = require 'config'
local utils = require 'utils'
local material = require 'material'
local backwall = require 'backwall'
local occluders = require 'occluders'
local spheres = require 'spheres'
local floor = require 'floor'
local light = require 'light'
local camera = require 'camera'


local M = {}

local iteration = nil
local block = nil
local params = nil
local actors = {}
local check_data = {}

function M.initialize(_iteration)
   iteration = _iteration
   block = assert(require(iteration.block))

   local params_file = iteration.path .. 'params.json'
   if config.is_first_iteration_of_block(iteration) then
      params = block.get_random_parameters()
      utils.write_json(params, params_file)
   else
      params = utils.read_json(params_file)
   end

   if block.set_block then
      block.set_block(iteration, params)
   end

   for i = 1, params.occluders.n_occluders do
      actors['occluder_' .. i] = occluders.get_occluder(i)
   end

   for i = 1, params.spheres.n_spheres do
      actors['sphere_' .. i] = spheres.get_sphere(i)
   end
end


-- Return true if iteration is physically possible, false otherwise
function M.is_possible()
   return block.is_possible()
end


function M.get_masks()
   local active, inactive, text = {}, {}, {}

   floor.insert_masks(active, text)
   backwall.insert_masks(active, text, params.backwall)
   occluders.insert_masks(active, text, params.occluders)

   if iteration.type == -1 then  -- on train
      spheres.insert_masks(active, text, params.spheres)
   else
      -- on test, the main actor only can be inactive (when hidden)
      for i = 1, params.spheres.n_spheres do
         table.insert(text, "sphere_" .. i)
         if i ~= params.index then
            table.insert(active, spheres.get_sphere(i))
         end
      end

      -- We add the main actor as active only when it's not hidden
      local main_actor = block.get_main_actor()
      if block.is_main_actor_visible() then
         table.insert(active, main_actor)
      else
         table.insert(inactive, main_actor)
      end
   end

   return active, inactive, text
end


function M.get_nactors()
   -- spheres + occluders + floor + backwall
   local n = 1 -- floor
   if params.backwall.is_active then
      n = n + 1
   end

   return n + params.spheres.n_spheres + params.occluders.n_occluders
end


function M.get_status()
   local nactors = M.get_nactors()
   local _, _, actors = M.get_masks()
   actors = backwall.get_updated_actors(actors)

   local masks = {}
   masks[0] = "sky"
   for n, m in pairs(actors) do
      masks[math.floor(255 * n / nactors)] = m
   end

   local status = {}
   status['possible'] = M.is_possible()
   status['floor'] = floor.get_status()
   status['camera'] = camera.get_status()
   status['lights'] = light.get_status()
   status['masks_grayscale'] = masks

   return status
end


function M.run()
   camera.setup(iteration, 150, params.camera)
   spheres.setup(params.spheres)
   floor.setup(params.floor)
   light.setup(params.light)
   backwall.setup(params.backwall)
   occluders.setup(params.occluders)

   if block.visible1 ~= nil then
      uetorch.SetActorVisible(spheres.get_sphere(params.index), visible1)
   end
end


function M.save_check_info(dt)
   local main_actor = block.get_main_actor()
   table.insert(check_data, {location = uetorch.GetActorLocation(main_actor),
                             rotation = uetorch.GetActorRotation(main_actor)})
end




return M
