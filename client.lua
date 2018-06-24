local UTILS
local vehicles = {}
local NOOP = function () end

RegisterNetEvent("onDeliveryCreated")
AddEventHandler("onDeliveryCreated", function(net, vehs)
	-- Store latest table of net ids
	vehicles = vehs

	-- A new vehicle was created
	if net > 0 then
		local data = vehs[net]

		vehs[net] = nil --  Wait until exists on this client
		while not DoesEntityExist(NetToObj(net)) do
			Citizen.Wait(1)
		end
		vehs[net] = data

		local vehicle = NetToObj(net)

		-- Add blips
		if DoesBlipExist(GetBlipFromEntity(vehicle)) ~= 1 then
			AddBlipForEntity(vehicle)
		end

		print('Delivery vehicle created: ', vehicle, net)
	end
end)


function Sequence (ped, onTick, cb)
	onTick = onTick or NOOP
	cb = cb or NOOP
	Citizen.CreateThread(function ()
		local cv
		local lv
		while true do
			cv = GetSequenceProgress(ped)
			onTick(cv, lv)
			if cv == -1 then return cb(cv, lv) end
			lv = cv
			Wait(0)
		end
	end)
end

function GoToBackOfVehicle (ped, vehicle)
	local empty, sequence = OpenSequenceTask(0)
	--[[0]] TaskLeaveAnyVehicle(0, 0, 256) --TaskLeaveVehicle(0, vehicle, 1)
	--[[1]] TaskGoToCoordAnyMeans(0, GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -3.75, 0.0), 1.0, 0, 0, 786603, 0xbf800000)
	--[[2]] TaskAchieveHeading(0, GetEntityHeading(vehicle), 1500)
	--[[3]] TaskOpenVehicleDoor(0, vehicle, -1, 2, 1.0)
	--[[4]] TaskPause(0, 1000)
	--[[5]] TaskPause(0, 1000)
	CloseSequenceTask(sequence)
	ClearPedTasks(ped)
	ClearPedTasksImmediately(ped)
	TaskPerformSequence(ped, sequence)
	ClearSequenceTask(sequence)
	return sequence
end

function GoToATM (ped, vehicle, atm)
	local empty, sequence = OpenSequenceTask(0)
	--[[0]] TaskLeaveVehicle(0, vehicle, 1)
	--[[1]] TaskClearLookAt(0)
	--[[2]]	TaskGoToEntity(0, atm, -1, 1.0, 1.0, 1073741824.0, 0)
	--[[3]] TaskAchieveHeading(0, GetEntityHeading(atm), 1500)
	CloseSequenceTask(sequence)
	ClearPedTasks(ped)
	ClearPedTasksImmediately(ped)
	TaskPerformSequence(ped, sequence)
	ClearSequenceTask(sequence)
	return sequence
end

function OpenBackOfVehicle (ped, vehicle, case, eject)
	DetachEntity(case, 1, false)
	SetEntityCollision(case, true, 0)
	ActivatePhysics(case)
	SetActivateObjectPhysicsAsSoonAsItIsUnfrozen(case, 1)
	PlaySoundFromCoord(-1, "DOORS_BLOWN", GetWorldPositionOfEntityBone(vehicle, 13), "RE_SECURITY_VAN_SOUNDSET", 0, 0, 0);

	if eject then
		ApplyForceToEntity(case, 1, 0.0, -10.0, 5.0, 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
	end

	SetVehicleDoorOpen(vehicle, 2, 0, 0)
	SetVehicleDoorOpen(vehicle, 3, 0, 0)
end

-- Destroy the delivery
function HostDestroyDelivery (net)
	if vehicles[net] == nil then return end
	if NetworkIsHost() then
		print("Destroy delivery", net)

		local vehicle = NetToObj(net)
		local ped = NetToObj(vehicles[net].ped)
		local case = NetToObj(vehicles[net].case)

		SetEntityAsMissionEntity(ped, false, true)
		DeletePed(ped)

		SetEntityAsMissionEntity(case, false, true)
		DeleteObject(case)

		SetEntityAsMissionEntity(vehicle, false, true)
		DeleteVehicle(vehicle)
	end
end

RegisterNetEvent("HostDestroyDelivery")
AddEventHandler("HostDestroyDelivery", HostDestroyDelivery)

AddEventHandler("onResourceStop", function(resource)
	if resource == GetCurrentResourceName() then
		if NetworkIsHost() then
			for net, ids in pairs(vehicles) do HostDestroyDelivery(net) end
		end
	end
end)

local empty, security_group = AddRelationshipGroup("Security_guards")

function SecurityGuard (ped)
	SetEntityAsMissionEntity(ped,  true,  false)

	-- Helmet
	SetPedPropIndex(ped, 0, 1, 0, false)
	SetPedSuffersCriticalHits(ped, 0)
	SetPedMoney(ped, 0)

	-- Combat
	SetPedCombatAttributes(ped, 1, false) --BF_CanUseVehicles
	SetPedCombatAttributes(ped, 13, false)
	SetPedCombatAttributes(ped, 6, true)
	SetPedCombatAttributes(ped, 8, false)
	SetPedCombatAttributes(ped, 10, true)

	SetPedFleeAttributes(ped, 512, true)
	SetPedConfigFlag(ped, 118, false)
	SetPedFleeAttributes(ped, 128, true)

	SetPedCanRagdollFromPlayerImpact(ped, 0)
	SetEntityIsTargetPriority(ped, 1, 0)
	SetPedGetOutUpsideDownVehicle(ped, 1)
	SetPedPlaysHeadOnHornAnimWhenDiesInVehicle(ped, 1)
	GiveWeaponToPed(ped, GetHashKey("weapon_pistol"), -1, false, true)
	SetPedRelationshipGroupHash(ped, security_group)
	SetPedKeepTask(ped, true)
	SetEntityLodDist(ped, 250)
	Citizen.InvokeNative --[[SetEntityLoadCollisionFlag]](0x0DC7CABAB1E9B67E, ped, true, 1)

	SetRelationshipBetweenGroups(1, GetHashKey("COP"), security_group) -- Respect
	SetRelationshipBetweenGroups(1, security_group, GetHashKey("COP")) -- Respect
	-- SetRelationshipBetweenGroups(2, security_group, GetHashKey("PLAYER")) -- Like
	-- SetRelationshipBetweenGroups(2, GetHashKey("PLAYER"), security_group) -- Like

	return ped
end













function HostCreateDelivery(props)
	local dest = props.dest or GetEntityCoords(PlayerPedId())
	local coords = props.coords or GetEntityCoords(PlayerPedId())

	coords = { x = coords.x, y = coords.y, z = coords.z }

	local vehicle = UTILS.SpawnVehicle(props.vehicleModel or "stockade", coords, props.heading or 0.0, true)

	SetEntityAsMissionEntity(vehicle,  true,  false)
	SetVehicleOnGroundProperly(vehicle)
	SetVehicleProvidesCover(vehicle, true)
	SetVehicleEngineOn(vehicle, true, true, 0)
	SetVehicleAutomaticallyAttaches(vehicle, false, 0)
	Citizen.InvokeNative --[[SetEntityLoadCollisionFlag]](0x0DC7CABAB1E9B67E, vehicle, true, 1)
	--VEHICLE::SET_VEHICLE_DOORS_LOCKED(vehicle, 3);

	local case = UTILS.SpawnObject("prop_security_case_01", coords, true, true, false)
	SetEntityAsMissionEntity(case,  true,  false)
	AttachEntityToEntity(case, vehicle, 0, 0.0, -2.4589, 1.2195, 0.0, 0.0, 0.0, 0, 0, 0, 0, 2, 1)
	SetEntityProofs(case, false, true, true, true, true, true, 0, false) -- not bullet proof
	SetEntityNoCollisionEntity(case, vehicle, 0)
	-- ENTITY::SET_ENTITY_VISIBLE(case, false, 0);
	-- print("Case attached", IsEntityAttached(case) == 1)

	local pedModel = props.pedModel or GetHashKey("s_m_m_armoured_01")
	RequestModel(pedModel)
	while not HasModelLoaded(pedModel) do Wait(0) end

	local ped = SecurityGuard(CreatePedInsideVehicle(vehicle, 1, pedModel, -1, true, false))

	LoadAllPathNodes(true)
	while not AreAllNavmeshRegionsLoaded() do Wait(1) end

	local pedNet = PedToNet(ped)
	local vehicleNet = ObjToNet(vehicle)
	pedNet = NetworkGetNetworkIdFromEntity(ped)
	SetNetworkIdCanMigrate(pedNet, true)

	TaskVehicleDriveToCoordLongrange(ped, vehicle, dest.x, dest.y, dest.z, 15.0, 1074004284, 2.0)
	TriggerServerEvent("onDeliveryCreated", vehicleNet, {
		vehicle = vehicleNet,
		ped = pedNet,
		case = ObjToNet(case)
	})
end

-- local AwaitTask = function (ped, id)
-- 	Wait(17)
-- 	while GetIsTaskActive(ped, id) do Wait(0) end
-- end

-- function GetActivePedTasks (ped, setclipboard)
-- 	local activeTasks = {}
--
-- 	for i = 0, 528, 1 do
-- 		if GetIsTaskActive(ped, i) then activeTasks[i] = true end
-- 	end
--
-- 	if setclipboard then exports.clipboard:SetClipboard(activeTasks, function (err)
-- 		if not err then
-- 			print('clipboard set')
-- 		end
-- 	end) end
--
-- 	return activeTasks
-- end


RegisterCommand('fleeca', function ()
	local ped = PlayerPedId()
	SetPlayerWantedLevel(PlayerId(), 0, false)
	SetPlayerWantedLevelNow(PlayerId(), 0, false)
	SetEntityCoords(ped, -2966.2092285156, 490.24746704102, 15.282291412354)
	GiveWeaponToPed(ped, GetHashKey("weapon_pistol"), -1, false, true)
end)

Citizen.CreateThread(
	function()
		local arrived = false -- TODO FIX THIS (DECORATORS AND HOST ONLY)

		while true do
			Wait(0)
			for netid, settings in pairs(vehicles) do
				local vehicle = NetToObj(settings.vehicle)
				local ped = NetToObj(settings.ped)
				local pathing = GetIsTaskActive(ped, 169)
				local case = NetToObj(settings.case)

				if not pathing then
					if not arrived then
						arrived = true
						print("Arrived at dest")
						ClearPedTasks(ped)
						Wait(1000)

						-- ClearPedAlternateWalkAnim(ped, -1056964608)
						local atm = GetClosestObjectOfType(GetEntityCoords(vehicle), 35.0, --[[-1364697528]] GetHashKey('prop_atm_03'), false)

						-- Go to back of vehicle and wait for sequence to stop
						GoToBackOfVehicle(ped, vehicle)
						Sequence(ped, function (cv, lv)
							if cv == 5 and lv ~= cv then
								print('Attaching case')
								AttachEntityToEntity(case, ped, GetPedBoneIndex(ped, 28422), 0.1, 0.0, -0.03, -90.0, 0.0, 90.0, 1, 0, 0, true, 2, true) -- close enough
							end
						end, function (cv, lv)
							print('DONE?', cv, lv)
							-- Sequence ended
							if lv == 5 then
								print('Arrived at back of vehicle')
								-- TaskStartScenarioAtPosition(ped, "PROP_HUMAN_ATM", GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -4.5, 0.4), GetEntityHeading(vehicle), 1000, true, true)
								-- Wait(300)
								--OpenBackOfVehicle(ped, vehicle, case)
								--Wait(800)


								-- Open doors and grab case
								ClearPedTasks(ped)
								ClearPedTasksImmediately(ped)
								GoToATM(ped, vehicle, atm)
								Sequence(ped, false, function (cv, lv)
									print('Arrived at atm')
									ClearPedTasks()
									TaskStartScenarioAtPosition(ped, "PROP_HUMAN_PARKING_METER", GetOffsetFromEntityInWorldCoords(atm, 0.0, -1.0, 1.0), GetEntityHeading(atm), 0, true, true)
									Wait(5000)

									if lv == 3 then
										GoToBackOfVehicle(ped, vehicle)
										Sequence(ped, false, function (cv, lv)
											if lv == 5 then
												print('Arrived back at back of vehicle')
												DetachEntity(case, 1, false)
												AttachEntityToEntity(case, vehicle, 0, 0.0, -2.4589, 1.2195, 0.0, 0.0, 0.0, 0, 0, 0, 0, 2, 1)
												Wait(500)

												SetVehicleDoorShut(vehicle, 2, 0, 0)
												SetVehicleDoorShut(vehicle, 3, 0, 0)
												-- Enter vehicle
												Wait(1000)

												ClearPedTasks(ped)
												TaskEnterVehicle(ped, vehicle, -1, -1, 1.0, 1, 0)
											end
										end)
									end
								end)
							end
						end)
					end
				else
					if arrived then
						arrived = false
					end
				end
			end
		end
	end
)

TriggerEvent(
	"glue:GetExports",
	function(module)
		UTILS = module.UTILS
		Citizen.CreateThread(
			function()
				local dest = GetEntityCoords(PlayerPedId())
				HostCreateDelivery(
				{
					vehicleModel = GetHashKey("stockade"),
					pedModel = GetHashKey("s_m_m_armoured_01"),
					coords = {
						z = 18.354583740234,
						y = 576.20074462891,
						x = -3002.3640136719,
					},
					dest = {
						z = 14.831346511841,
						y = 492.81072998047,
						x = -2952.046875,
					},
					heading = -90.0 + 266.6369934082
				}
				)
			end
		)
	end
)


--   local drivable = IsVehicleDriveable(vehicle) == 1
