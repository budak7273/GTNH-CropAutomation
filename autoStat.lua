local gps = require("gps")
local action = require("action")
local database = require("database")
local scanner = require("scanner")
local posUtil = require("posUtil")
local config = require("config")

local lowestGr
local lowestGrSlot
local lowestGa
local lowestGaSlot

local function updateLowest()
    lowestGr = 100
    lowestGrSlot = 0
    lowestGa = 100
    lowestGaSlot = 0
    local farm = database.getFarm()
    local farmArea = config.farmSize^2
    for slot=1, farmArea, 2 do
        local crop = farm[slot]
        if crop ~= nil then
            if crop.gr < lowestGr then
                lowestGr = crop.gr
                lowestGrSlot = slot
            end
        end
    end
    for slot=1, farmArea, 2 do
        local crop = farm[slot]
        if crop ~= nil then
            if crop.gr == lowestGr then
                if crop.ga < lowestGa then
                    lowestGa = crop.ga
                    lowestGaSlot = slot
                end
            end
        end
    end
end

local function findSuitableFarmSlot(crop)
    if crop.gr > lowestGr then
        return lowestGrSlot
    elseif crop.gr == lowestGr then
        if crop.ga > lowestGa then
            return lowestGaSlot
        end
    end
    return 0
end

local function breedOnce()
    -- return true if all stats are maxed out
    if lowestGr == 21 and lowestGa == 31 then
        return true
    end

    for slot=2, config.farmSize^2, 2 do
        gps.go(posUtil.farmToGlobal(slot))
        local crop = scanner.scan()
        if crop.name == "air" then
            action.cross()
            action.cross()
        elseif crop.name == "crop" then
            action.cross()
        elseif crop.isCrop then
            if crop.name == "weed" or crop.gr > 21 or
              (crop.name == "venomilia" and crop.ga > 7) then
                action.deweed()
                action.cross()
            elseif crop.name == database.getFarm()[1].name then
                local suitableSlot = findSuitableFarmSlot(crop)
                if suitableSlot == 0 or crop.re > 0 then
                    action.deweed()
                    action.cross()
                else
                    action.transplant(posUtil.farmToGlobal(slot), posUtil.farmToGlobal(suitableSlot))
                    action.cross()
                    action.cross()
                    database.updateFarm(suitableSlot, crop)
                    updateLowest()
                end
            elseif config.keepNewCropWhileMinMaxing and (not database.existInStorage(crop)) then
                action.transplant(posUtil.farmToGlobal(slot), posUtil.storageToGlobal(database.nextStorageSlot()))
                action.cross()
                action.cross()
                database.addToStorage(crop)
            else
                action.deweed()
                action.cross()
            end
        end
    end
    return false
end

local function init()
    database.scanFarm()
    if config.keepNewCropWhileMinMaxing then
        database.scanStorage()
    end
    updateLowest()
    action.restockAll()
end

local function main()
    init()
    while true do
        if breedOnce() then
            break
        end
        gps.go({0,0})
        action.restockAll()
    end
    gps.go({0,0})
    print("done.")
end

main()