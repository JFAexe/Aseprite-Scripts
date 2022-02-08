-------------------------------------------------------------------------------
--       N A M E : Intravenous UI Icons Tool
--   A U T H O R : Alexandr 'JFAexe' Konichenko
-- V E R S I O N : 2022.02.09.2
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
-- T Y P E S
-------------------------------------------------------------------------------

local types = {
    idle = {
        name = '_idle',
        base = { r = 70,  g = 84,  b = 86  },
        high = { r = 100, g = 135, b = 140 },
        fx   = false
    },
    active = {
        name = '_active',
        base = { r = 204, g = 175, b = 85  },
        high = { r = 219, g = 229, b = 148 },
        fx   = true
    },
    inactive = {
        name = '_inactive',
        base = { r = 183, g = 38,  b = 38  },
        high = { r = 231, g = 116, b = 40  },
        fx   = true
    },
}


-------------------------------------------------------------------------------
-- F U N C T I O N S
-------------------------------------------------------------------------------

local rgba  = pixelColor.rgba
local rgbaR = pixelColor.rgbaR
local rgbaG = pixelColor.rgbaG
local rgbaB = pixelColor.rgbaB
local rgbaA = pixelColor.rgbaA

local function checkTransparency( value )
    return rgbaA( value ) < 255
end

local function checkColor( value, color )
    return rgbaR( value ) == color.r and rgbaG( value ) == color.g and rgbaB( value ) == color.b
end

local function createLayer( sprite )
    local layer = nil

    if layer == nil then
        layer      = sprite:newLayer( )
        layer.name = app.activeLayer.name
    end

    return layer
end

local function createSprite( sprite, name )
    local newSprite = Sprite( sprite )

    newSprite.filename = tostring( sprite.filename ):gsub( '.png', name .. '.png' )

    return newSprite
end

local function applyColors( image, type )
    local check = false

    for pixel in image:pixels( ) do
        local pixelValue = pixel( )

        if not checkTransparency( pixelValue ) then
            if checkColor( pixelValue, types.idle.high ) then
                pixel( rgba( type.high.r, type.high.g, type.high.b ) )

                check = true
            elseif checkColor( pixelValue, types.idle.base ) then
                pixel( rgba( type.base.r, type.base.g, type.base.b ) )

                check = true
            else
                pixel( rgbaA( 0 ) )
            end
        else
            pixel( rgbaA( 0 ) )
        end
    end

    return image, check
end

local function createBase( cel )
    local altered, check = applyColors( cel.image:clone( ), types.idle )

    if not check then
        alert 'Wrong colors.'

        return nil
    end

    return altered
end

local function createAltered( sprite, cel, base, type )
    if not type then
        return
    end

    local newSprite = createSprite( sprite, type.name )

    local altered = applyColors( base:clone( ), type )

    newSprite:newCel( app.activeLayer, app.activeFrame, altered, cel.position )

    if not type.fx then
        command.AutocropSprite( )

        command.CanvasSize {
            ui     = false,
            left   = 1,
            right  = 1,
            top    = 1,
            bottom = 1,
        }

        return
    end

    command.ConvolutionMatrix {
        ui           = false,
        fromResource = 'blur-3x3'
    }

    newSprite:newCel( createLayer( newSprite ), app.activeFrame, altered, cel.position )

    command.MergeDownLayer( )

    command.AutocropSprite( )
end

local function generateIcons( data )
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

    local base = createBase( cel )

    if base == nil then
        return
    end

    app.transaction( function( )
        createAltered( sprite, cel, base, data.typeIdle and types.idle )

        createAltered( sprite, cel, base, data.typeActive and types.active )

        createAltered( sprite, cel, base, data.typeInactive and types.inactive )

        app.refresh( )
    end )
end


-------------------------------------------------------------------------------
-- W I N D O W
-------------------------------------------------------------------------------

local Window = Dialog( 'IVUIIT' )

    Window
    :separator {
        text     = 'Type'
    }
    :newrow {
        always   = true
    }
    :check {
        id       = 'typeIdle',
        text     = 'Idle',
        selected = true
    }
    :check {
        id       = 'typeActive',
        text     = 'Active',
        selected = true
    }
    :check {
        id       = 'typeInactive',
        text     = 'Inactive',
        selected = true
    }
    :button {
        id       = 'normalMap',
        text     = 'Generate icons',
        focus    = true,
        onclick  = function( )
            local data = Window.data

            if not ( data.typeIdle or data.typeActive or data.typeInactive ) then
                alert 'Select at least one option.'

                return
            end

            generateIcons( data )
        end
    }
    :show {
        wait     = false
    }