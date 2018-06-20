local UTILS
local vehicles = {}

RegisterNetEvent("onDeliveryCreated")
AddEventHandler(
	"onDeliveryCreated",
	function(net, vehs)
		local vehicle

		-- Store latest vehicles
		vehicles = vehs

		-- A new vehicle was created
		if net > 0 then
			vehicle = NetToObj(net)

			print("Created delivery", net, vehicle)

			-- Add blips
			if DoesBlipExist(GetBlipFromEntity(vehicle)) ~= 1 then
				AddBlipForEntity(vehicle)
			end
		end
	end
)

-- Destroy the delivery
function HostDestroyDelivery(net)
	if vehicles[net] == nil then
		return
	end

	print("Destroy Delivery", net)

	local vehicle = NetToObj(net)
	local ped = NetToObj(vehicles[net].ped)
	local case = NetToObj(vehicles[net].case)

	SetEntityAsMissionEntity(ped, false, true)
	DeletePed(ped)

	UTILS.DestroyObject(case)

	UTILS.DestroyVehicle(vehicle)
end

RegisterNetEvent("HostDestroyDelivery")
AddEventHandler("HostDestroyDelivery", HostDestroyDelivery)

local empty, security_group = AddRelationshipGroup("Security_guards")

function SecurityGuard(ped)
	-- Helmet
	SetPedPropIndex(ped, 0, 1, 0, false)
	SetPedSuffersCriticalHits(ped, 0)
	SetPedMoney(ped, 0)
	-- Combat
	SetPedCombatAttributes(ped, 1, false)
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
	SetRelationshipBetweenGroups(2, security_group, GetHashKey("PLAYER")) -- Like
	SetRelationshipBetweenGroups(2, GetHashKey("PLAYER"), security_group) -- Like
end

function HostCreateDelivery(props)
	local dest = props.dest or GetEntityCoords(PlayerPedId())
	local coords = props.coords or GetEntityCoords(PlayerPedId())

	coords = {
		x = coords.x,
		y = coords.y,
		z = coords.z
	}

	local vehicle = UTILS.SpawnVehicle(props.vehicleModel or "stockade", coords, props.heading or 0.0, true)

	local pedModel = props.pedModel or GetHashKey("s_m_m_armoured_01")
	local vehicleNet = ObjToNet(vehicle)

	Citizen.InvokeNative --[[SetVehicleOnGroudProperly]](0x49733E92263139D1, vehicle, 1084227584)
	SetVehicleProvidesCover(vehicle, true)
	SetVehicleCreatesMoneyPickupsWhenExploded(vehicle, 0)
	SetVehicleEngineOn(vehicle, true, true, 0)

	local case = UTILS.SpawnObject("prop_security_case_01", coords, true, true, false)
	-- ENTITY::SET_ENTITY_VISIBLE(case, false, 0);

	AttachEntityToEntity(case, vehicle, 0, 0.0, -2.4589, 1.2195, 0.0, 0.0, 0.0, 0, 0, 0, 0, 2, 1)
	SetEntityProofs(case, false, true, true, true, true, true, 0, false) -- not bullet proof ?
	SetEntityNoCollisionEntity(case, vehicle, 0)
	SetVehicleAutomaticallyAttaches(vehicle, false, 0)
	Citizen.InvokeNative --[[SetEntityLoadCollisionFlag]](0x0DC7CABAB1E9B67E, vehicle, true, 1)

	--VEHICLE::SET_VEHICLE_DOORS_LOCKED(vehicle, 3);

	print("Case attached", IsEntityAttached(case) == 1)

	UTILS.LoadModel(pedModel)

	local ped = CreatePedInsideVehicle(vehicle, 1, pedModel, -1, true, false)
	local pedNet = PedToNet(ped)

	pedNet = NetworkGetNetworkIdFromEntity(ped)

	SecurityGuard(ped)

	SetNetworkIdCanMigrate(pedNet, true)
	-- SetBlockingOfNonTemporaryEvents(ped, true)

	TaskVehicleDriveToCoordLongrange(ped, vehicle, dest.x, dest.y, dest.z, 15.0, 1074004284, 2.0)

	Wait(100)

	TriggerServerEvent(
		"onDeliveryCreated",
		vehicleNet,
		{
			vehicle = vehicleNet,
			ped = pedNet,
			case = ObjToNet(case)
		}
	)
end

Citizen.CreateThread(
	function()
		local arrived = false

		while true do
			Wait(0)
			for k, v in pairs(vehicles) do
				local vehicle = NetToObj(k)
				local ped = GetPedInVehicleSeat(vehicle, -1)
				local pathing = GetIsTaskActive(ped, 169)

				if not pathing then
					if not arrived then
						arrived = true
						print("Arrived at dest")

						ClearPedAlternateWalkAnim(ped, -1056964608)
						ClearPedTasks(ped)

						SetVehicleDoorOpen(vehicle, 2, 0, 0)
						SetVehicleDoorOpen(vehicle, 3, 0, 0)
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
						coords = {x = -221.50, y = 6517.67, z = 11.03},
						dest = {x = dest.x, y = dest.y, z = dest.z},
						heading = 131.0
					}
				)
			end
		)
	end
)

AddEventHandler(
	"onResourceStop",
	function(resource)
		if resource == GetCurrentResourceName() then
			for net, settings in pairs(vehicles) do
				HostDestroyDelivery(net)
			end
		end
	end
)

--   local drivable = IsVehicleDriveable(vehicle) == 1
