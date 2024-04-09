local component = require('component')
local sides = require('sides')
local config = require('config')
local geolyzer = component.geolyzer


local function scan()
    local rawResult = geolyzer.analyze(sides.down)

    -- AIR
    if rawResult.name == 'minecraft:air' or rawResult.name == 'GalacticraftCore:tile.brightAir' then
        return {isCrop=true, name='air'}

    elseif rawResult.name == 'IC2:blockCrop' then

        -- EMPTY CROP STICK
        if rawResult['crop:name'] == nil then
            return {isCrop=true, name='emptyCrop'}

        -- FILLED CROP STICK
        else
            return {
                isCrop=true,
                name = rawResult['crop:name'],
                gr = rawResult['crop:growth'],
                ga = rawResult['crop:gain'],
                re = rawResult['crop:resistance'],
                tier = rawResult['crop:tier']
            }
        end

    -- RANDOM BLOCK
    else
        return {isCrop=false, name='block'}
    end
end


-- Check if a crop is considered a weed, and if so, also return the reason why.
-- Returns: shouldBreak, reason, isPureWeed
local function weedLogic(crop, farm)
    local maxGrowth
    local maxResist
    if farm == 'working' then
        maxGrowth = config.workingMaxGrowth
        maxResist = config.workingMaxResistance
    elseif farm == 'storage' then
        maxGrowth = config.storageMaxGrowth
        maxResist = config.storageMaxResistance
    end

    if crop.name == 'weed' or crop.name == 'Grass' then
        return true, "isPureWeed", true
    elseif crop.name == 'venomilia' and crop.gr > 7 then
        return true, "isDangerousVenomilia", false
    elseif crop.gr > maxGrowth then
        return true, string.format("%s_isOverMaxGrowthOf_%s", crop.gr, maxGrowth), false
    elseif crop.re > maxResist then
        return true, string.format("%s_isOverMaxResistOf_%s", crop.re, maxResist), false
    end
end


local function isWeed(crop, farm)
    local shouldBreak, reason, isPureWeed = weedLogic(crop, farm)

    -- Always remove pure weeds with no logging
    if isPureWeed then
        return true
    end

    if shouldBreak then
        if config.explainCropRemoval then
            print("Removing " .. farm .. " plant: " .. crop.name .. " because " .. reason)
        end
        if config.debugDoNotRemoveAnyNonPureWeedParents == false then
            return true
        end
    end
    return false
end


return {
    scan = scan,
    isWeed = isWeed
}
