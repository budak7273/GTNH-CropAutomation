local component = require('component')
local robot = require('robot')
local sides = require('sides')
local computer = require('computer')
local os = require('os')
local gps = require('gps')
local config = require('config')
local signal = require('signal')
local scanner = require('scanner')
local posUtil = require('posUtil')
local database = require('database')
local inventory_controller = component.inventory_controller


local function needCharge()
    return computer.energy() / computer.maxEnergy() < config.needChargeLevel
end


local function fullyCharged()
    return computer.energy() / computer.maxEnergy() > 0.99
end


local function fullInventory()
    for i=1, robot.inventorySize() do
        if robot.count(i) == 0 then
            return false
        end
    end
    return true
end

local function charge()
    gps.go(config.chargerPos)
    gps.turnTo(1)

    local chargeCounter = 0
    local hasPrintedWarning = false
    repeat
        os.sleep(0.5)
        chargeCounter = chargeCounter + 1
        if chargeCounter > config.chargeTimeWarning and not hasPrintedWarning then
            print("Charging taking longer than expected. Is the charger powered and given a redstone signal?")
            hasPrintedWarning = true
        end
    until fullyCharged()
    if hasPrintedWarning then
        print("Resuming normal operation.")
    end
end


local function restockStick()
    local selectedSlot = robot.select()

    gps.go(config.stickContainerPos)
    robot.select(robot.inventorySize()+config.stickSlot)
    for i=1, inventory_controller.getInventorySize(sides.down) do
        inventory_controller.suckFromSlot(sides.down, i, 64-robot.count())
        if robot.count() == 64 then
            break
        end
    end

    robot.select(selectedSlot)
end


local function dumpInventory()
    local selectedSlot = robot.select()

    gps.go(config.storagePos)
    for i=1, (robot.inventorySize() + config.storageStopSlot) do
        if robot.count(i) > 0 then
            robot.select(i)
            for e=1, inventory_controller.getInventorySize(sides.down) do
                if inventory_controller.getStackInSlot(sides.down, e) == nil then
                    inventory_controller.dropIntoSlot(sides.down, e)
                    break
                end
            end
        end
    end

    robot.select(selectedSlot)
end


local function restockAll()
    dumpInventory()
    restockStick()
    charge()
end


local function placeCropStick(count)
    if count == nil then
        count = 1
    end
    local selectedSlot = robot.select()
    if robot.count(robot.inventorySize()+config.stickSlot) < count + 1 then
        restockStick()
    end
    robot.select(robot.inventorySize()+config.stickSlot)
    inventory_controller.equip()
    for _=1, count do
        robot.useDown()
    end
    inventory_controller.equip()
    robot.select(selectedSlot)
end


local function deweed()
    local selectedSlot = robot.select()
    if config.keepDrops and fullInventory() then
        dumpInventory()
    end
    robot.select(robot.inventorySize()+config.spadeSlot)
    inventory_controller.equip()
    robot.useDown()
    if config.keepDrops then
        robot.suckDown()
    end
    inventory_controller.equip()
    robot.select(selectedSlot)
end


local function transplant(src, dest)
    local selectedSlot = robot.select()
    gps.save()
    robot.select(robot.inventorySize()+config.binderSlot)
    inventory_controller.equip()

    -- TRANSFER TO RELAY LOCATION
    gps.go(config.dislocatorPos)
    robot.useDown(sides.down)
    gps.go(src)
    robot.useDown(sides.down, true)
    gps.go(config.dislocatorPos)
    signal.pulseDown()

    -- TRANSFER CROP TO DESTINATION
    robot.useDown(sides.down, true)
    gps.go(dest)

    local crop = scanner.scan()
    if crop.name == 'air' then
        placeCropStick()

    elseif crop.isCrop == false then
        database.addToStorage(crop)
        gps.go(posUtil.storageSlotToPos(database.nextStorageSlot()))
        placeCropStick()
    end

    robot.useDown(sides.down, true)
    gps.go(config.dislocatorPos)
    signal.pulseDown()

    -- DESTROY ORIGINAL CROP
    inventory_controller.equip()
    gps.go(config.relayFarmlandPos)
    robot.swingDown()
    if config.KeepDrops then
        robot.suckDown()
    end

    gps.resume()
    robot.select(selectedSlot)
end


local function cleanUp()
    for slot=1, config.workingFarmArea, 1 do

        -- Scan
        gps.go(posUtil.workingSlotToPos(slot))
        local crop = scanner.scan()

        -- Remove all children and empty parents
        if slot % 2 == 0 or crop.name == 'emptyCrop' then
            robot.swingDown()

        -- Remove bad parents
        elseif crop.isCrop and crop.name ~= 'air' then
            if scanner.isWeed(crop, 'working') then
                robot.swingDown()
            end
        end

        -- Pickup
        if config.KeepDrops then
            robot.suckDown()
        end
    end
    restockAll()
end


return {
    needCharge = needCharge,
    charge = charge,
    restockStick = restockStick,
    dumpInventory = dumpInventory,
    restockAll = restockAll,
    placeCropStick = placeCropStick,
    deweed = deweed,
    transplant = transplant,
    cleanUp = cleanUp
}