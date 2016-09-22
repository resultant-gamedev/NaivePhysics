local uetorch = require 'uetorch'
local config = require 'config'
local utils = require 'utils'
local block = {}

local camera = uetorch.GetActor("MainMap_CameraActor_Blueprint_C_0")
local floor = uetorch.GetActor('Floor')
local sphere = uetorch.GetActor("Sphere_4")
local sphere2 = uetorch.GetActor("Sphere9_4")
local sphere3 = uetorch.GetActor("Sphere10_7")
local spheres = {sphere, sphere2, sphere3}
local wall1 = uetorch.GetActor("Wall_400x200_8")
local wall_boxY
local wall2 = uetorch.GetActor("Wall_400x201_7")
block.actors = {sphere=sphere, wall1=wall1, wall2=wall2}

local iterationId,iterationType,iterationBlock
local params = {}
local isHidden1,isHidden2

local visible1 = true
local visible2 = true
local possible = true
local trick1 = false
local trick2 = false

local t_rotation = 0
local t_rotation_change = 0

local function WallRotationDown(dt)
	local angle = (t_rotation - t_rotation_change) * 20 * 0.125
	local succ = uetorch.SetActorRotation(wall1, 0, 0, angle)
	local succ2 = uetorch.SetActorRotation(wall2, 0, 0, angle)
	--uetorch.SetActorLocation(wall1, 50 - 200 * params.scaleW, -350, 20 + math.sin(angle * math.pi / 180) * wall_boxY)
	uetorch.SetActorLocation(wall1, 50 - 200 * params.scaleW, -350, 20 + math.sin((90 - angle) * math.pi / 180) * wall_boxY)
	uetorch.SetActorLocation(wall2, 300 - 200 * params.scaleW, -350, 20 + math.sin(angle * math.pi / 180) * wall_boxY)
	if angle >= 90 then
		utils.RemoveTickHook(WallRotationDown)
		t_rotation_change = t_rotation
	end
	t_rotation = t_rotation + dt
end

local function RemainUp(dt)
	params.framesRemainUp = params.framesRemainUp - 1
	if params.framesRemainUp == 0 then
		utils.RemoveTickHook(RemainUp)
		utils.AddTickHook(WallRotationDown)
	end
end

local function WallRotationUp(dt)
	local angle = (t_rotation - t_rotation_change) * 20 * 0.125
	local succ = uetorch.SetActorRotation(wall1, 0, 0, 90 - angle)
	local succ2 = uetorch.SetActorRotation(wall2, 0, 0, 90 - angle)
	--uetorch.SetActorLocation(wall1, 50 - 200 * params.scaleW, -350, 20 + math.sin((90 - angle) * math.pi / 180) * wall_boxY)
	uetorch.SetActorLocation(wall1, 50 - 200 * params.scaleW, -350, 20 + math.sin(angle * math.pi / 180) * wall_boxY)
	uetorch.SetActorLocation(wall2, 300 - 200 * params.scaleW, -350, 20 + math.sin((90 - angle) * math.pi / 180) * wall_boxY)
	if angle >= 90 then
		utils.RemoveTickHook(WallRotationUp)
		utils.AddTickHook(RemainUp)
		t_rotation_change = t_rotation
	end
	t_rotation = t_rotation + dt
end

local function StartDown(dt)
	params.framesStartDown = params.framesStartDown - 1
	if params.framesStartDown == 0 then
		utils.RemoveTickHook(StartDown)
		utils.AddTickHook(WallRotationUp)
	end
end

local tCheck, tLastCheck = 0, 0
local step = 0

local function Trick(dt)
	if tCheck - tLastCheck >= config.GetBlockCaptureInterval(iterationBlock) then
		step = step + 1

		if not trick1 and isHidden1[step] then
			trick1 = true
			uetorch.SetActorVisible(spheres[params.index], visible2)
		end

		if trick1 and not trick2 and isHidden2[step] then
			trick2 = true
			uetorch.SetActorVisible(spheres[params.index], visible1)
		end

		tLastCheck = tCheck
	end
	tCheck = tCheck + dt
end

local mainActor

function block.MainActor()
	return mainActor
end

function block.SetBlock(currentIteration)
	iterationId, iterationType, iterationBlock = config.GetIterationInfo(currentIteration)

	if iterationType == 0 then
		if config.GetLoadParams() then
			params = torch.load(config.GetDataPath() .. iterationId .. '/params.t7')
		else
			params = {
				ground = 1,--math.random(#utils.ground_materials),
				sphereZ = 200,--70 + math.random(200),
				forceX = 2000000,--2500000,--math.random(800000, 1100000),
				forceY = 0,
				forceZ = math.random(800000, 1000000),
				signZ = 1,--2 * math.random(2) - 3,
				left = 1,--math.random(0,1),
				framesStartDown = math.random(5),
				framesRemainUp = math.random(5),
				scaleW = 0.5,--1 - 0.5 * math.random(),
				scaleH = 1 - 0.4 * math.random(),
				n = 1,
				index = 1
			}

			torch.save(config.GetDataPath() .. iterationId .. '/params.t7', params)
		end

		uetorch.DestroyActor(wall2)
	else
		params = torch.load(config.GetDataPath() .. iterationId .. '/params.t7')

		if iterationType == 5 then
			uetorch.DestroyActor(wall1)
		else
			isHidden1 = torch.load(config.GetDataPath() .. iterationId .. '/hidden_0.t7')
			isHidden2 = torch.load(config.GetDataPath() .. iterationId .. '/hidden_5.t7')
			utils.AddTickHook(Trick)

			if iterationType == 1 then
				visible1 = false
				visible2 = false
				possible = true
			elseif iterationType == 2 then
				visible1 = true
				visible2 = true
				possible = true
			elseif iterationType == 3 then
				visible1 = false
				visible2 = true
				possible = false
			elseif iterationType == 4 then
				visible1 = true
				visible2 = false
				possible = false
			end
		end
	end

	mainActor = sphere
end

function block.RunBlock()
	utils.SetActorMaterial(floor, utils.ground_materials[params.ground])
	utils.AddTickHook(StartDown)
	uetorch.SetActorLocation(camera, 150, 30, 80)

	uetorch.SetActorScale3D(wall1, params.scaleW, 1, params.scaleH)
	uetorch.SetActorScale3D(wall2, params.scaleW, 1, params.scaleH)
	wall_boxY = uetorch.GetActorBounds(wall1).boxY
	uetorch.SetActorLocation(wall1, 50 - 200 * params.scaleW, -350, 20 + wall_boxY)
	uetorch.SetActorLocation(wall2, 300 - 200 * params.scaleW, -350, 20 + wall_boxY)
	uetorch.SetActorRotation(wall1, 0, 0, 90)
	uetorch.SetActorRotation(wall2, 0, 0, 90)

	uetorch.SetActorVisible(sphere, visible1)

	if params.left == 1 then
		uetorch.SetActorLocation(sphere, -400, -550, params.sphereZ)
	else
		uetorch.SetActorLocation(sphere, 500, -550, params.sphereZ)
		params.forceX = -params.forceX
	end

	uetorch.AddForce(sphere, params.forceX, params.forceY, params.signZ * params.forceZ)
end

local checkData = {}
local saveTick = 1

function block.SaveCheckInfo(dt)
	local aux = {}
	aux.location = uetorch.GetActorLocation(mainActor)
	aux.rotation = uetorch.GetActorRotation(mainActor)
	table.insert(checkData, aux)
	saveTick = saveTick + 1
end

local maxDiff = 1e-6

function block.Check()
	local status = true
	torch.save(config.GetDataPath() .. iterationId .. '/check_' .. iterationType .. '.t7', checkData)

	if iterationType == 1 then
		print("Run iteration Check")

		local foundHidden1 = false
		for i = 1,#isHidden1 do
			if isHidden1[i] then
				foundHidden = true
			end
		end

		local foundHidden2 = false
		for i = 1,#isHidden2 do
			if isHidden2[i] then
				foundHidden2 = true
			end
		end

		if not foundHidden1 or not foundHidden2 then
			status = false
		end

		local iteration = utils.GetCurrentIteration()
		local size = config.GetBlockSize(iterationBlock)
		local ticks = config.GetBlockTicks(iterationBlock)
		local allData = {}

		for i = 0,size - 1 do
			local aux = torch.load(config.GetDataPath() .. iterationId .. '/check_' .. i .. '.t7')
			table.insert(allData, aux)
		end

		for t = 1,ticks do
			for i = 2,size do
				-- check location values
				if(math.abs(allData[i][t].location.x - allData[1][t].location.x) > maxDiff) then
					status = false
				end
				if(math.abs(allData[i][t].location.y - allData[1][t].location.y) > maxDiff) then
					status = false
				end
				if(math.abs(allData[i][t].location.z - allData[1][t].location.z) > maxDiff) then
					status = false
				end
				-- check rotation values
				if(math.abs(allData[i][t].rotation.pitch - allData[1][t].rotation.pitch) > maxDiff) then
					status = false
				end
				if(math.abs(allData[i][t].rotation.yaw - allData[1][t].rotation.yaw) > maxDiff) then
					status = false
				end
				if(math.abs(allData[i][t].rotation.roll - allData[1][t].rotation.roll) > maxDiff) then
					status = false
				end
			end
		end
	end

	utils.UpdateIterationsCounter(status)
end

function block.IsPossible()
	return possible
end

return block