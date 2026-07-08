local version = {major = 1, minor = 20}
if not (Hyperspace.version and Hyperspace.version.major == version.major and Hyperspace.version.minor >= version.minor) then
	error("Incorrect Hyperspace version detected! Minelauncher Rebalance requires Hyperspace "..version.major.."."..version.minor.."+")
end
mods.er = {}

local COLOUR_WHITE = Graphics.GL_Color(1, 1, 1, 1)
local COLOUR_TEXT = Graphics.GL_Color(235/255, 245/255, 229/255, 1)
local text_size = 10
local text_pos_x = 93
local text_pos_y = 99
local evasion_image = {
	blue = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_evade.png", 1, 89, 0, COLOUR_WHITE, 1.0, false),
	green = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_evade_green.png", 1, 89, 0, COLOUR_WHITE, 1.0, false),
	red = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_evade_red.png", 1, 89, 0, COLOUR_WHITE, 1.0, false),
	purple = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_evade_purple.png", 1, 89, 0, COLOUR_WHITE, 1.0, false),
}

local start_min = 6
local scale_min = 3

local start_max = 10
local scale_max = 5

local start_ftl = 0.75
local scale_ftl = 0.25

local level_string = Hyperspace.Text:GetText("er_lua_engine_level")

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, function(currentId, level, tooltip)
	if currentId == 1 then
		return string.format(level_string, start_min + scale_min * level, start_max + scale_max * level, start_ftl + scale_ftl * level)
	end
end)

local currentEvasion = {[0] = 0, [1] = 0}

script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(shipManager, value)
	if currentEvasion[shipManager.iShipId] >= 100 and shipManager:HasSystem(1) and shipsManager:HasSystem(6) then
		if shipManager:GetSystem(1):GetEffectivePower() > 0 and shipManager:GetSystem(6).bFriendlies or shipManager:GetSystem(6).powerState.first > 1 then
			return Defines.Chain.HALT, 100
		end
	end
	return Defines.Chain.HALT, 0
end)

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION_PRE, function(shipManager, projectile, damage, response)
	print("SHIELD_COLLISION_PRE"..response.collision_type)
	if projectile and projectile:GetType() ~= 5 then
		projectile.table.er_shield_pre = true
	end
	--[[if projectile and projectile:GetType() ~= 5 and projectile.missed then
		currentEvasion[shipManager.iShipId] = currentEvasion[shipManager.iShipId] - 100
		projectile.table.er_counted = true
	end]]
	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, forcehit, friendlyFire)
	print("DAMAGE_AREA:"..tostring(projectile.missed))
	if currentEvasion[shipManager.iShipId] >= 100 and not projectile.table.er_counted then
		currentEvasion[shipManager.iShipId] = currentEvasion[shipManager.iShipId] - 100
		projectile.table.er_counted = true
		return Defines.Chain.CONTINUE, Defines.Evasion.MISS
	end
	return Defines.Chain.CONTINUE, Defines.Evasion.NONE
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, friendlyFire)
	print("DAMAGE_AREA_HIT")
	if projectile then
		local evasion_change = 0
		local engines_active = false
		if shipManager:HasSystem(1) then
			local engine = shipManager:GetSystem(1)
			local engine_level = engine:GetEffectivePower()
			if engine_level and engine_level > 0 and engine.iHackEffect <= 0 then
				engines_active = true
				evasion_change = evasion_change + math.random(start_min + scale_min * engine_level, start_max + scale_max * engine_level)
				if engine.bManned then
					evasion_change = evasion_change + 5 * engine.iActiveManned
				end
			end
		end

		if engines_active and shipManager:HasSystem(6) then
			local pilot = shipManager:GetSystem(6)
			if pilot.bManned then
				evasion_change = evasion_change
			elseif pilot.powerState.first == 2 then
				evasion_change = evasion_change * 0.5
			elseif pilot.powerState.first == 3 then
				evasion_change = evasion_change * 0.8
			else 
				evasion_change = 0
			end
		end

		if shipManager.ship.bCloaked then
			evasion_change = evasion_change + 60
		end

		if projectile.extend.customDamage.accuracyMod then
			evasion_change = evasion_change - projectile.extend.customDamage.accuracyMod
		end

		currentEvasion[shipManager.iShipId] = currentEvasion[shipManager.iShipId] + evasion_change
	end
	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
	print("SHIELD_COLLISION")
	--print(projectile:GetType())
	if projectile and projectile:GetType() ~= 5 then
		projectile.table.er_shield_post = true
	end
	if projectile and projectile:GetType() ~= 5 and not projectile.missed then
		local evasion_change = 0
		if shipManager:HasSystem(1) then
			local engine_level = shipManager:GetSystem(1):GetEffectivePower()
			if engine_level and engine_level > 0 and shipManager:GetSystem(1).iHackEffect <= 0 then
				evasion_change = evasion_change + math.random(start_min + scale_min * engine_level, start_max + scale_max * engine_level)
			end
		end

		if shipManager.ship.bCloaked then
			evasion_change = evasion_change + 60
		end

		if projectile.extend.customDamage.accuracyMod then
			evasion_change = evasion_change - projectile.extend.customDamage.accuracyMod
		end

		currentEvasion[shipManager.iShipId] = currentEvasion[shipManager.iShipId] + evasion_change
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_POST, function(projectile, preempted)
	if projectile.table.er_shield_pre and not projectile.table.er_counted then
		if  not projectile.table.er_shield_post then
			print("PROJECTILE_UPDATE_POST")
			--print("projectile.missed:"..tostring(projectile.missed))
			print("projectile.table.er_shield_pre:"..tostring(projectile.table.er_shield_pre))
			print("projectile.table.er_shield_post:"..tostring(projectile.table.er_shield_post))
			currentEvasion[projectile.destinationSpace] = currentEvasion[projectile.destinationSpace] - 100
			projectile.table.er_counted = true
		end
	end
	return Defines.Chain.CONTINUE
end)

script.on_render_event(Defines.RenderEvents.SHIP_STATUS, function() end, function()
	local engine_system = Hyperspace.ships.player:GetSystem(1)
	if engine_system and engine_system.iHackEffect > 0 then
		Graphics.CSurface.GL_RenderPrimitive(evasion_image.purple)
	elseif (not engine_system) or engine_system:GetEffectivePower() <= 0 then
		Graphics.CSurface.GL_RenderPrimitive(evasion_image.red)
	elseif currentEvasion[0] >= 100 then
		Graphics.CSurface.GL_RenderPrimitive(evasion_image.green)
	else
		Graphics.CSurface.GL_RenderPrimitive(evasion_image.blue)
	end
	Graphics.CSurface.GL_SetColor(COLOUR_TEXT)
	Graphics.freetype.easy_printRightAlign(text_size, text_pos_x, text_pos_y, string.format("%d%%", math.floor(currentEvasion[0])))
	Graphics.CSurface.GL_SetColor(COLOUR_WHITE)
end)