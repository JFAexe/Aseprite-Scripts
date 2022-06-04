-------------------------------------------------------------------------------
--       N A M E : Intravenous UI Icons Tool
--   A U T H O R : Alexandr 'JFAexe' Konichenko
-- V E R S I O N : 2022.06.04.4
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
-- S C H E M E S
-------------------------------------------------------------------------------

local __schemes = {
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
    custom = {
        name = '_custom',
        base = { r = 0  , g = 0,   b = 0   },
        high = { r = 255, g = 255, b = 255 },
        fx   = true
    },
}

local __colors = {
    base = __schemes.idle.base,
    high = __schemes.idle.high
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

local function convertFromColor( color )
    return { r = color.red, g = color.green, b = color.blue }
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

local function applyColors( image, scheme )
    local check = false

    for pixel in image:pixels( ) do
        local pixelValue = pixel( )

        if not checkTransparency( pixelValue ) then
            if checkColor( pixelValue, __colors.high ) then
                pixel( rgba( scheme.high.r, scheme.high.g, scheme.high.b ) )

                check = true
            elseif checkColor( pixelValue, __colors.base ) then
                pixel( rgba( scheme.base.r, scheme.base.g, scheme.base.b ) )

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
    local altered, check = applyColors( cel.image:clone( ), __colors )

    if not check then
        alert 'Wrong colors.'

        return nil
    end

    command.AutocropSprite( )

    command.CanvasSize {
        ui     = false,
        left   = 1,
        right  = 1,
        top    = 1,
        bottom = 1,
    }

    return altered
end

local function createAltered( sprite, cel, base, scheme )
    if not scheme then
        return
    end

    local newSprite = createSprite( sprite, scheme.name )

    local altered = applyColors( base:clone( ), scheme )

    newSprite:newCel( app.activeLayer, app.activeFrame, altered, cel.position )

    if not scheme.fx then
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

local function generateIcons( schemes )
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
        alert 'Failed to process sprite.'

        return
    end

    app.transaction( function( )
        for scheme = 1, #schemes do
            createAltered( sprite, cel, base, schemes[ scheme ] )
        end

        app.refresh( )
    end )
end


-------------------------------------------------------------------------------
-- W I N D O W
-------------------------------------------------------------------------------

local Window = Dialog( 'IVUIIT' )

    Window
    :newrow {
        always   = true
    }
    :separator {
        text     = 'Colors'
    }
    :color {
        id       = 'baseColor',
        color    = Color( __colors.base )
    }
    :color {
        id       = 'highColor',
        color    = Color( __colors.high )
    }
    :separator {
        text     = 'Schemes'
    }
    :check {
        id       = 'schemeIdle',
        text     = 'Idle',
        selected = true
    }
    :check {
        id       = 'schemeActive',
        text     = 'Active',
        selected = true
    }
    :check {
        id       = 'schemeInactive',
        text     = 'Inactive',
        selected = true
    }
    :check {
        id       = 'schemeCustom',
        text     = 'Custom',
        selected = false,
        onclick  = function( )
            local visible = Window.data.schemeCustom

            Window
            :modify {
                id      = 'customBaseColor',
                visible = visible
            }
            :modify {
                id      = 'customHighColor',
                visible = visible
            }
            :modify {
                id      = 'customFx',
                visible = visible
            }
        end
    }
    :color {
        id       = 'customBaseColor',
        color    = Color( __schemes.custom.base ),
        visible  = false
    }
    :color {
        id       = 'customHighColor',
        color    = Color( __schemes.custom.high ),
        visible  = false
    }
    :check {
        id       = 'customFx',
        text     = 'Glow',
        selected = __schemes.custom.fx,
        visible  = false
    }
    :button {
        id       = 'normalMap',
        text     = 'Generate icons',
        focus    = true,
        onclick  = function( )
            local data = Window.data

            if not ( data.schemeIdle or data.schemeActive or data.schemeInactive or data.schemeCustom ) then
                alert 'Select at least one option.'

                return
            end

            __colors.base = convertFromColor( data.baseColor )
            __colors.high = convertFromColor( data.highColor )

            __schemes.custom.base = convertFromColor( data.customBaseColor )
            __schemes.custom.high = convertFromColor( data.customHighColor )
            __schemes.custom.fx   = data.customFx

            generateIcons( {
                data.schemeIdle and __schemes.idle,
                data.schemeActive and __schemes.active,
                data.schemeInactive and __schemes.inactive,
                data.schemeCustom and __schemes.custom,
            } )
        end
    }
    :show {
        wait     = false
    }