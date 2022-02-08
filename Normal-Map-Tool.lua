-------------------------------------------------------------------------------
--        N A M E : Normal Map Tool
--    A U T H O R : Alexandr 'JFAexe' Konichenko, Martin Sandgren
--  V E R S I O N : 2022.02.09.5
-- B A S E D  O N : https://github.com/carlmartus/aseprite_normalmap
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

local min   = math.min
local max   = math.max
local rgba  = pixelColor.rgba
local rgbaR = pixelColor.rgbaR
local rgbaG = pixelColor.rgbaG
local rgbaB = pixelColor.rgbaB
local rgbaA = pixelColor.rgbaA

local function clamp( v, l, h )
    return min( max( v, l ), h )
end

local function crossProduct( a, b )
    return {
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x
    }
end

local function normalize( v )
    local ilen = 1 / ( ( v.x ^ 2  + v.y ^ 2 + v.z ^ 2 ) ^ 0.5 )

    return {
        x = v.x * ilen,
        y = v.y * ilen,
        z = v.z * ilen
    }
end

local function createNormal( dx, dy, dz )
    return crossProduct( normalize( { x = dy, y = -dx, z = 0 } ), normalize( { x = dx, y = dy, z = dz } ) )
end

local function checkTransparency( value )
    return rgbaA( value ) < 255
end

local function createLayer( sprite, data )
    local layer = nil

    if layer == nil then
        layer      = sprite:newLayer( )
        layer.name = app.activeLayer.name .. ' Normal'
                                          .. ( data.invertX and ' -X' or ' X' )
                                          .. ( data.invertY and ' -Y' or ' Y' )
                                          .. ( data.invertZ and ' -Z' or ' Z' )
    end

    return layer
end

local function processButtonClick( func, data, win )
    if not func then
        alert 'There is no function to run.'

        return
    end

    local time = os.clock( )

    func( data )

    if not win then
        return
    end

    win:modify {
        id   = 'time',
        text = 'Generated in ' .. string.format( '%.3f', os.clock( ) - time ) .. ' seconds'
    }
end

local function generateNormalFromCel( data, cel )
    local image, clone, position = cel.image, cel.image:clone( ), cel.position

    local invertX, invertY, invertZ = data.invertX and -1 or 1, data.invertY and -1 or 1, data.invertZ and -1 or 1

    for pixel in clone:pixels( ) do
        if checkTransparency( pixel( ) ) then
            pixel( rgbaA( 0 ) )
        else
            local x, y = pixel.x, pixel.y

            local normals = { }

            local function addPixel( dx, dy )
                normals[ #normals + 1 ] = createNormal( dx, dy, ( rgbaR( image:getPixel( x + dx, y + dy ) ) - rgbaR( pixel ) ) * 0.02 )
            end

            if x > 0 then
                addPixel( -1, 0 )

                if y > 0 then
                    addPixel( -1, -1 )
                end

                if y < clone.height - 1 then
                    addPixel( -1, 1 )
                end
            end

            if x < clone.width - 1 then
                addPixel( 1, 0 )

                if y > 0 then
                    addPixel( 1, -1 )
                end

                if y < clone.height - 1 then
                    addPixel( 1, 1 )
                end
            end

            if y > 0 then
                addPixel( 0, -1 )
            end

            if y < clone.height - 1 then
                addPixel( 0, 1 )
            end

            local plane = { x = 0, y = 0, z = 0 }

            for i = 1, #normals do
                plane.x = plane.x + normals[ i ].x
                plane.y = plane.y + normals[ i ].y
                plane.z = plane.z + normals[ i ].z
            end

            plane   = normalize( plane )
            plane.x = clamp( 128 + 127 * plane.x,   0, 255 ) * invertX
            plane.y = clamp( 128 - 127 * plane.y,   0, 255 ) * invertY
            plane.z = clamp( 128 + 127 * plane.z, 128, 255 ) * invertZ

            pixel( rgba( plane.x, plane.y, plane.z ) )
        end
    end

    return clone, position
end

local function generateNormalMap( data )
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

    app.transaction( function( )
        local clone, position = generateNormalFromCel( data, cel )

        sprite:newCel( createLayer( sprite, data ), app.activeFrame, clone, position )

        app.refresh( )
    end )
end

local function generateLayerNormalMap( data )
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

    app.transaction( function( )
        local layer = createLayer( sprite, data )

        for _, cel in ipairs( cels ) do

            local clone, position = generateNormalFromCel( data, cel )

            sprite:newCel( layer, cel.frame, clone, position )
        end

        app.refresh( )
    end )
end


-------------------------------------------------------------------------------
-- W I N D O W
-------------------------------------------------------------------------------

local Window = Dialog( 'NMT' )

    Window
    :separator {
        text    = 'Invert'
    }
    :check {
        id      = 'invertX',
        text    = 'X axis',
    }
    :check {
        id      = 'invertY',
        text    = 'Y axis',
    }
    :check {
        id      = 'invertZ',
        text    = 'Z axis',
    }
    :separator {
        id      = 'time',
        text    = ' '
    }
    :button {
        id      = 'normalMap',
        text    = 'Generate for Cel',
        focus   = true,
        onclick = function( )
            processButtonClick( generateNormalMap, Window.data, Window )
        end
    }
    :newrow {
        always  = false
    }
    :button {
        id      = 'layerNormalMap',
        text    = 'Generate for Layer',
        onclick = function( )
            processButtonClick( generateLayerNormalMap, Window.data, Window )
        end
    }
    :show {
        wait    = false
    }