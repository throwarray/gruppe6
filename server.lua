local vehicles = {}

RegisterNetEvent('onDeliveryCreated')
AddEventHandler('onDeliveryCreated', function (net, props)
  print('Server:Creating delivery', net)

  local source = source
  local net = props.vehicle or 0

  vehicles[net] = props or true

  TriggerClientEvent('onDeliveryCreated', -1, net, vehicles)
end)

AddEventHandler('playerConnecting', function ()
  TriggerClientEvent('onDeliveryCreated', source, 0, vehicles)
end)
