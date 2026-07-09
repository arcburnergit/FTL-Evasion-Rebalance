local version = {major = 1, minor = 20}
if not (Hyperspace.version and Hyperspace.version.major == version.major and Hyperspace.version.minor >= version.minor) then
	error("Incorrect Hyperspace version detected! Minelauncher Rebalance requires Hyperspace "..version.major.."."..version.minor.."+")
end
mods.er = {}

local time_increment = mods.multiverse.time_increment

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

local scale = 5

local manning_bonus_data = {[0] = 0, [1] = 5, [2] = 7, [3] = 10, [4] = 15}

local start_ftl = 0.75
local scale_ftl = 0.25

local level_string = Hyperspace.Text:GetText("er_lua_engine_level")

local function get_range(level, add)
	local base = add + scale * level
	if level == 6 then base = base - 2
	elseif level == 7 then base = base - 4
	elseif level >= 8 then base = base - 5 end
	local target = (base) / (100 - base)
	return math.floor(target * 90), math.ceil(target * 110)
end

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, function(currentId, level, tooltip)
	if currentId == 1 then
		local min, max = get_range(level, 0)
		return string.format(level_string, min, max, start_ftl + scale_ftl * level)
	end
end)

local currentEvasion = {[0] = 0, [1] = 0}
local enable_evasion = false

script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(shipManager, value)
	if currentEvasion[shipManager.iShipId] >= 100 and enable_evasion then
		return Defines.Chain.HALT, 100
	end
	return Defines.Chain.HALT, 0
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if enable_evasion then
		--print("DISABLE_EVASION")
		enable_evasion = false
	end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, forcehit, friendlyFire)
	--print("DAMAGE_AREA:"..tostring(projectile.missed))
	if projectile and not projectile.table.er_counted then
		projectile.table.er_damage_pre = true
		enable_evasion = true
	end
	return Defines.Chain.CONTINUE, Defines.Evasion.NONE
end)
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION_PRE, function(shipManager, projectile, damage, response)
	--print("SHIELD_COLLISION_PRE"..response.collision_type)
	if projectile and projectile:GetType() ~= 5 then
		projectile.table.er_shield_pre = true
		enable_evasion = true
	end
	return Defines.Chain.CONTINUE
end)

local function add_evasion(shipManager, projectile)
	local evasion_change = 0
	if shipManager:HasSystem(1) then
		local engine = shipManager:GetSystem(1)
		local engine_level = engine:GetEffectivePower()
		if engine_level and engine_level > 0 and engine.iHackEffect <= 0 then
			local manning_bonus = 0
			if engine.bManned then
				manning_bonus = manning_bonus_data[engine.iActiveManned]
			end
			local min, max = get_range(engine_level, manning_bonus)
			if max == min then max = max + 1 end
			evasion_change = math.random(min, max)	

			if shipManager:HasSystem(6) then
				local pilot = shipManager:GetSystem(6)
				if not pilot.bManned then
					if pilot.powerState.first == 2 then
						evasion_change = evasion_change * 0.5
					elseif pilot.powerState.first == 3 then
						evasion_change = evasion_change * 0.8
					else 
						evasion_change = 0
					end
				end
			else
				evasion_change = 0
			end
			--print(string.format("ADD EVASION: min:%g max:%g added:%d", min, max, evasion_change))
		end
	end

	if shipManager.ship.bCloaked then
		evasion_change = evasion_change + 60
	end

	if projectile.extend.customDamage.accuracyMod then
		evasion_change = evasion_change - projectile.extend.customDamage.accuracyMod
	end

	currentEvasion[shipManager.iShipId] = math.min(300, currentEvasion[shipManager.iShipId] + evasion_change)
	--print(string.format("ADD EVASION: final:%d", evasion_change))
end

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, friendlyFire)
	--print("DAMAGE_AREA_HIT")
	if projectile then
		projectile.table.er_damage_post = true
	end
	if projectile then
		add_evasion(shipManager, projectile)
	end
	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
	--print("SHIELD_COLLISION")
	--print(projectile:GetType())
	if projectile and projectile:GetType() ~= 5 then
		projectile.table.er_shield_post = true
	end
	if projectile and projectile:GetType() ~= 5 then
		add_evasion(shipManager, projectile)
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_POST, function(projectile, preempted)
	if projectile.table.er_shield_pre and not projectile.table.er_counted then
		if not projectile.table.er_shield_post then
			--print("PROJECTILE_UPDATE_POST 1")
			currentEvasion[projectile.destinationSpace] = currentEvasion[projectile.destinationSpace] - 100
			projectile.table.er_counted = true
			add_evasion(Hyperspace.ships(projectile.destinationSpace), projectile)
		end
	end
	if projectile.table.er_damage_pre and not projectile.table.er_counted then
		if not projectile.table.er_damage_post then
			--print("PROJECTILE_UPDATE_POST 2")
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

local last_cloaked = {[0] = false, [1] = true}
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.ship.bCloaked and not last_cloaked[shipManager.iShipId] then
		currentEvasion[shipManager.iShipId] = currentEvasion[shipManager.iShipId] + 60
	end
	last_cloaked[shipManager.iShipId] = shipManager.ship.bCloaked

	if shipManager:HasSystem(1) and shipManager:GetSystem(1).iHackEffect > 0 and currentEvasion[shipManager.iShipId] > 0 then
		currentEvasion[shipManager.iShipId] = currentEvasion[shipManager.iShipId] - 10 * time_increment(true)
	end
end)

local evasion_tooltip = Hyperspace.Text:GetText("tooltip_evadeDisplay")
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if Hyperspace.Mouse.tooltip == evasion_tooltip then
		local shipManager = Hyperspace.ships.player
		local min, max = 0
		if shipManager:HasSystem(1) then
			local engine = shipManager:GetSystem(1)
			local engine_level = engine:GetEffectivePower()
			if engine_level and engine_level > 0 and engine.iHackEffect <= 0 then
				local manning_bonus = 0
				if engine.bManned then
					manning_bonus = manning_bonus_data[engine.iActiveManned]
				end
				min, max = get_range(engine_level, manning_bonus)
				if max == min then max = max + 1 end

				if shipManager:HasSystem(6) then
					local pilot = shipManager:GetSystem(6)
					if not pilot.bManned then
						if pilot.powerState.first == 2 then
							min = min * 0.5
							max = max * 0.5
						elseif pilot.powerState.first == 3 then
							min = min * 0.8
							max = max * 0.8
						else
							min, max = 0
						end
					end
				else
					min, max = 0
				end
			end
		end

		if shipManager.ship.bCloaked then
			min = min + 60
			max = max + 60
		end

		Hyperspace.Mouse.tooltip = string.format(evasion_tooltip, min, max)
	end
end)