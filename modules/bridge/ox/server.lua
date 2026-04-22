if not lib.checkDependency('kt_core', '0.21.3', true) then return end

local kt = require '@kt_core.lib.init' --[[@as ktServer]]

local Inventory = require 'modules.inventory.server'

AddEventHandler('kt:playerLogout', server.playerDropped)

AddEventHandler('kt:setGroup', function(source, name, grade)
	local inventory = Inventory(source)

	if not inventory then return end

	inventory.player.groups[name] = grade
end)

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    player.groups = kt.GetPlayer(player.source)?.getGroups()
    return player
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, name)
	local player = kt.GetPlayer(inv.id)

    if not player then return end

	return player.getLicense(name)
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
	local player = kt.GetPlayer(inv.id)

    if not player then return end


	if player.getLicense(license.name) then
		return false, 'already_have'
	elseif Inventory.GetItemCount(inv, 'money') < license.price then
		return false, 'can_not_afford'
	end

	Inventory.RemoveItem(inv, 'money', license.price)
	player.addLicense(license.name)

	return true, 'have_purchased'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group, grade)
	local groupData = GlobalState[('group.%s'):format(group)]

	return groupData and grade >= groupData.adminGrade
end

---@param entityId number
---@return number | string
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    return kt.GetVehicle(entityId)?.id
end
