-------------------------------------------------------------------------------
--        N A M E : Bit Depth Tool
--    A U T H O R : Alexandr 'JFAexe' Konichenko, Sandor Drieënhuizen
--  V E R S I O N : 2022.06.05.1
--  L I C E N S E : MIT
-- B A S E D  O N : https://github.com/sandord/aseprite-scripts
-------------------------------------------------------------------------------

local app        = app
local alert      = app.alert
local command    = app.command
local pixelColor = app.pixelColor

if not app.isUIAvailable then
    return
end

if not app.apiVersion or app.apiVersion < 10 then
    alert 'This script is unsupported. Update the Aseprite.'

    return
end


-------------------------------------------------------------------------------
-- F U N C T I O N S
-------------------------------------------------------------------------------

local rgba  = pixelColor.rgba
local rgbaR = pixelColor.rgbaR
local rgbaG = pixelColor.rgbaG
local rgbaB = pixelColor.rgbaB
local rgbaA = pixelColor.rgbaA

local function getValues( data )
    local bits = data.bits
    local mask = ( 0xff << ( 8 - bits ) ) & 0xff
    local mult = data.fix and ( 0xff / mask ) or 1

    return mask, mult, bits
end

local function checkTransparency( value )
    return rgbaA( value ) < 1
end

local function createLayer( sprite, bits )
    local layer = nil

    if layer == nil then
        layer      = sprite:newLayer( )
        layer.name = app.activeLayer.name .. ' ' .. bits .. ' bits'
    end

    return layer
end

local function processButtonClick( func, win )
    if not func then
        alert 'There is no function to run.'

        return
    end

    local time = os.clock( )

    func( win.data )

    if not win then
        return
    end

    win:modify {
        id   = 'time',
        text = 'Generated in ' .. string.format( '%.3f', os.clock( ) - time ) .. ' seconds'
    }
end

local function bitDepthFromCel( cel, mask, mult )
    local image, clone, position = cel.image, cel.image:clone( ), cel.position

    for pixel in clone:pixels( ) do
        local pixelValue = pixel( )

        if not checkTransparency( pixelValue ) then
            local color = { r = 0, g = 0, b = 0 }

            color.r = ( rgbaR( pixelValue ) & mask ) * mult
            color.g = ( rgbaG( pixelValue ) & mask ) * mult
            color.b = ( rgbaB( pixelValue ) & mask ) * mult

            pixel( rgba( color.r, color.g, color.b ) )
        else
            pixel( rgbaA( 0 ) )
        end
    end

    return clone, position
end

local function bitDepth( data )
    local cel = app.activeCel

    if not cel then
        alert 'There is no active cel.'

        return
    end

    if cel.image.colorMode ~= ColorMode.RGB then
        alert 'This script supports only RGB color mode.'

        return
    end

    local sprite = app.activeSprite

    local mask, mult, bits = getValues( data )

    app.transaction( function( )
        local clone, position = bitDepthFromCel( cel, mask, mult )

        sprite:newCel( createLayer( sprite, bits ), app.activeFrame, clone, position )

        app.refresh( )
    end )
end

local function layerBitDepth( data )
    local cels = app.activeLayer.cels

    local cel = cels[ 1 ]

    if not cel then
        alert 'There is no active cel.'

        return
    end

    if cel.image.colorMode ~= ColorMode.RGB then
        alert 'This script supports only RGB color mode.'

        return
    end

    local sprite = app.activeSprite

    local mask, mult, bits = getValues( data )

    app.transaction( function( )
        local layer = createLayer( sprite, bits )

        for _, cel in ipairs( cels ) do
            local clone, position = bitDepthFromCel( cel, mask, mult )

            sprite:newCel( layer, cel.frame, clone, position )
        end

        app.refresh( )
    end )
end

local function paletteBitDepth( data )
    local sprite = app.activeSprite

    if not sprite then
        alert 'There is no active sprite.'

        return
    end

    local palette = sprite.palettes[ 1 ]

    if not palette then
        alert 'There is no active palette.'

        return
    end

    local mask, mult = getValues( data )

    app.transaction( function( )
        for index = 0, #palette - 1 do
            local color = palette:getColor( index )

            color.red   = ( color.red   & mask ) * mult
            color.green = ( color.green & mask ) * mult
            color.blue  = ( color.blue  & mask ) * mult

            palette:setColor( index, color )
        end

        app.refresh( )
    end )
end


-------------------------------------------------------------------------------
-- W I N D O W
-------------------------------------------------------------------------------

local Window = Dialog( 'BDT' )

    Window
    :separator {
        text     = 'Bits'
    }
    :slider{
        id       = 'bits',
        min      = 1,
        max      = 7,
        value    = 3
    }
    :check {
        id       = 'fix',
        text     = 'Fix dynamic range',
        selected = true
    }
    :separator {
        id       = 'time',
        text     = ' '
    }
    :button {
        id       = 'bitDepth',
        text     = 'Generate for Cel',
        focus    = true,
        onclick  = function( )
            processButtonClick( bitDepth, Window )
        end
    }
    :newrow {
        always   = false
    }
    :button {
        id       = 'layerBitDepth',
        text     = 'Generate for Layer',
        onclick  = function( )
            processButtonClick( layerBitDepth, Window )
        end
    }
    :newrow {
        always   = false
    }
    :button {
        id       = 'paletteBitDepth',
        text     = 'Generate for Palette',
        onclick  = function( )
            processButtonClick( paletteBitDepth, Window )
        end
    }
    :show {
        wait     = false
    }