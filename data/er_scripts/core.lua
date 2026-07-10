local version = {major = 1, minor = 20}
if not (Hyperspace.version and Hyperspace.version.major == version.major and Hyperspace.version.minor >= version.minor) then
	error("Incorrect Hyperspace version detected! Minelauncher Rebalance requires Hyperspace "..version.major.."."..version.minor.."+")
end
mods.er = {}

local time_increment = mods.multiverse.time_increment
local vter = mods.multiverse.vter

local COLOUR_WHITE = Graphics.GL_Color(1, 1, 1, 1)
local COLOUR_TEXT = Graphics.GL_Color(235/255, 245/255, 229/255, 1)
local text_size = 10
local text_pos_x = 92
local text_pos_y = 10
local evasion_x = 1
local evasion_y = 89
local evasion_image = {
	blue = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_evade.png", evasion_x, evasion_y, 0, COLOUR_WHITE, 1.0, false),
	green = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_evade_green.png", evasion_x, evasion_y, 0, COLOUR_WHITE, 1.0, false),
	red = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_evade_red.png", evasion_x, evasion_y, 0, COLOUR_WHITE, 1.0, false),
	purple = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_evade_purple.png", evasion_x, evasion_y, 0, COLOUR_WHITE, 1.0, false),
}
local enemy_text_pos_x = 72
local enemy_evasion_x = 1178
local enemy_evasion_y = 108
local enemy_evasion_image = {
	blue = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_enemy_evade.png", enemy_evasion_x, enemy_evasion_y, 0, COLOUR_WHITE, 1.0, false),
	green = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_enemy_evade_green.png", enemy_evasion_x, enemy_evasion_y, 0, COLOUR_WHITE, 1.0, false),
	red = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_enemy_evade_red.png", enemy_evasion_x, enemy_evasion_y, 0, COLOUR_WHITE, 1.0, false),
	purple = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/er_enemy_evade_purple.png", enemy_evasion_x, enemy_evasion_y, 0, COLOUR_WHITE, 1.0, false),
}

local scale = 5

local manning_bonus_data = {[0] = 0, [1] = 5, [2] = 7, [3] = 10, [4] = 15}

local start_ftl = 0.75
local scale_ftl = 0.25

local level_string = Hyperspace.Text:GetText("er_lua_engine_level")
local level_string_sensors_3 = Hyperspace.Text:GetText("er_lua_sensor_level_3")

local function get_range(level, add)
	local base = add + scale * level
	if level == 6 then base = base - 2
	elseif level == 7 then base = base - 4
	elseif level >= 8 then base = base - 5 end
	if base >= 75 then
		return math.floor(3 * 90), math.ceil(3 * 110)
	end
	local target = (base) / (100 - base)
	return math.floor(target * 90), math.ceil(target * 110)
end

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, function(currentId, level, tooltip)
	if currentId == 1 then
		local min, max = get_range(level, 0)
		return string.format(level_string, min, max, start_ftl + scale_ftl * level)
	elseif currentId == 7 and level == 3 then
		return string.format(level_string_sensors_3)
	end
end)

local currentEvasion = {[0] = 0, [1] = 0}
local enable_evasion = {[0] = false, [1] = false}

local function save_evasion()
	Hyperspace.playerVariables.er_player_evasion = currentEvasion[0]
	Hyperspace.playerVariables.er_enemy_evasion = currentEvasion[1]
end

local function load_evasion()
	currentEvasion[0] = Hyperspace.playerVariables.er_player_evasion
	currentEvasion[1] = Hyperspace.playerVariables.er_enemy_evasion
end

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 0 then
		currentEvasion[0] = math.random(0, 100)
	end
	currentEvasion[1] = 0
end)

script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(shipManager, value)
	if currentEvasion[shipManager.iShipId] >= 100 and enable_evasion[shipManager.iShipId] then
		--enable_evasion[shipManager.iShipId] = false
		--print("QUEURY DODGE FACTOR")
		return Defines.Chain.HALT, 100
	end
	return Defines.Chain.HALT, -100
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if enable_evasion[shipManager.iShipId] then
		--print("DISABLE EVASION SHIP LOOP")
		enable_evasion[shipManager.iShipId] = false
	end
end)

local function get_room_at_location(shipManager, location, includeWalls)
	return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, forcehit, friendlyFire)
	if enable_evasion[shipManager.iShipId] then
		for projectileOld in vter(Hyperspace.App.world.space.projectiles) do
			if projectileOld.selfId == enable_evasion[shipManager.iShipId] and projectileOld.missed then
				currentEvasion[projectileOld.destinationSpace] = math.max(0, currentEvasion[projectileOld.destinationSpace] - 100)
				projectileOld.table.er_counted = true
				save_evasion()
				enable_evasion[projectile.destinationSpace] = false
				--print("DISABLE EVASION DAMAGE_AREA")
				break
			end
		end
	end
	local fake = true
	do
		local custom_damage = projectile.extend.customDamage.def
		if 
			damage.iDamage > 0 or
			damage.iShieldPiercing > 0 or
			damage.fireChance > 0 or
			damage.breachChance > 0 or
			damage.stunChance > 0 or
			damage.iIonDamage > 0 or
			damage.iSystemDamage > 0 or
			damage.bHullBuster or
			damage.bLockdown or
			damage.crystalShard or
			damage.iStun > 0 or
			custom_damage.statBoostChance > 0 or
			custom_damage.roomStatBoostChance > 0 or
			custom_damage.erosionChance > 0 or
			custom_damage.crewSpawnChance > 0
			then
			fake = false
		end
	end
	print(projectile.selfId.." DAMAGE_AREA:"..tostring(fake))
	if projectile and not fake and not projectile.table.er_counted and get_room_at_location(shipManager, location, true) >= 0 and not projectile.table.er_shield_post then
		projectile.table.er_damage_pre = true
		enable_evasion[shipManager.iShipId] = projectile.selfId
		--print("ENABLE_EVASION_DAMAGE")
	end
	return Defines.Chain.CONTINUE, Defines.Evasion.NONE
end)
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION_PRE, function(shipManager, projectile, damage, response)
	if enable_evasion[shipManager.iShipId] then
		for projectileOld in vter(Hyperspace.App.world.space.projectiles) do
			if projectileOld.selfId == enable_evasion[shipManager.iShipId] and projectileOld.missed then
				currentEvasion[projectileOld.destinationSpace] = math.max(0, currentEvasion[projectileOld.destinationSpace] - 100)
				projectileOld.table.er_counted = true
				save_evasion()
				enable_evasion[projectile.destinationSpace] = false
				--print("DISABLE EVASION SHIELD_COLLISION_PRE")
				break
			end
		end
	end
	local fake = true
	do
		local custom_damage = projectile.extend.customDamage.def
		if 
			damage.iDamage > 0 or
			damage.iShieldPiercing > 0 or
			damage.fireChance > 0 or
			damage.breachChance > 0 or
			damage.stunChance > 0 or
			damage.iIonDamage > 0 or
			damage.iSystemDamage > 0 or
			damage.bHullBuster or
			damage.bLockdown or
			damage.crystalShard or
			damage.iStun > 0 or
			custom_damage.statBoostChance > 0 or
			custom_damage.roomStatBoostChance > 0 or
			custom_damage.erosionChance > 0 or
			custom_damage.crewSpawnChance > 0
			then
			fake = false
		end
	end
	--print(projectile.selfId.." SHIELD_COLLISION_PRE:"..tostring(fake))
	if projectile and not fake and projectile:GetType() ~= 5 and not projectile.table.er_damage_post then
		projectile.table.er_shield_pre = true
		enable_evasion[shipManager.iShipId] = projectile.selfId
		--print("ENABLE_EVASION_SHIELD")
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
			if shipManager:HasSystem(6) and shipManager:GetSystem(6).bManned then
				local pilot = shipManager:GetSystem(6)
				manning_bonus = manning_bonus + manning_bonus_data[pilot.iActiveManned]
			end

			if shipManager.ship.bCloaked then
				manning_bonus = manning_bonus + 60
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
		elseif shipManager.ship.bCloaked then
			local min, max = get_range(engine_level, 60)
			evasion_change = math.random(min, max)
		end
	elseif shipManager.ship.bCloaked then
		local min, max = get_range(engine_level, 60)
		evasion_change = math.random(min, max)
	end

	if projectile.extend.customDamage.accuracyMod then
		evasion_change = evasion_change - projectile.extend.customDamage.accuracyMod
	end

	currentEvasion[shipManager.iShipId] = math.min(300, currentEvasion[shipManager.iShipId] + evasion_change)
	--print(string.format("ADD EVASION: final:%d", evasion_change))
end

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, friendlyFire)
	print(projectile.selfId.." DAMAGE_AREA_HIT"..tostring(projectile and projectile.table.er_damage_pre))
	if projectile and projectile.table.er_damage_pre then
		projectile.table.er_damage_post = true
		if not projectile.table.er_shield_post then
			add_evasion(shipManager, projectile)
			save_evasion()
			if enable_evasion[shipManager.iShipId] then
				enable_evasion[shipManager.iShipId] = false
				--print("DISABLE EVASION DAMAGE_AREA_HIT")
			end
		end
	end
	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
	--print(projectile.selfId.." SHIELD_COLLISION:"..tostring(projectile and projectile.table.er_shield_pre))
	--print(projectile:GetType())
	if projectile and projectile:GetType() ~= 5 and projectile.table.er_shield_pre then
		projectile.table.er_shield_post = true
		if not projectile.table.er_damage_post then
			add_evasion(shipManager, projectile)
			save_evasion()
			if enable_evasion[shipManager.iShipId] then
				enable_evasion[shipManager.iShipId] = false
				--print("DISABLE EVASION SHIELD_COLLISION")
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_POST, function(projectile, preempted)
	if projectile.table.er_shield_pre and not projectile.table.er_counted then
		if not projectile.table.er_shield_post then
			--print(projectile.selfId.." PROJECTILE_UPDATE_POST 1")
			currentEvasion[projectile.destinationSpace] = math.max(0, currentEvasion[projectile.destinationSpace] - 100)
			projectile.table.er_counted = true
			save_evasion()
			if enable_evasion[projectile.destinationSpace] then
				enable_evasion[projectile.destinationSpace] = false
				--print("DISABLE EVASION UPDATE POST SHIELD")
			end
		end
	end
	if projectile.table.er_damage_pre and not projectile.table.er_counted then
		if not projectile.table.er_damage_post then
			--print(projectile.selfId.." PROJECTILE_UPDATE_POST 2")
			currentEvasion[projectile.destinationSpace] = math.max(0, currentEvasion[projectile.destinationSpace] - 100)
			projectile.table.er_counted = true
			save_evasion()
			if enable_evasion[projectile.destinationSpace] then
				enable_evasion[projectile.destinationSpace] = false
				--print("DISABLE EVASION UPDATE POST DAMAGE")
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

local last_cloaked = {[0] = false, [1] = true}
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.ship.bCloaked and not last_cloaked[shipManager.iShipId] then
		currentEvasion[shipManager.iShipId] = currentEvasion[shipManager.iShipId] + 60
		save_evasion()
	elseif (not shipManager.ship.bCloaked) and last_cloaked[shipManager.iShipId] then
		currentEvasion[shipManager.iShipId] = math.min(100, currentEvasion[shipManager.iShipId])
	end
	last_cloaked[shipManager.iShipId] = shipManager.ship.bCloaked

	if shipManager:HasSystem(1) and shipManager:GetSystem(1).iHackEffect > 0 and currentEvasion[shipManager.iShipId] > 0 then
		currentEvasion[shipManager.iShipId] = currentEvasion[shipManager.iShipId] - 10 * time_increment(true)
	end
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
	Graphics.freetype.easy_printRightAlign(text_size, evasion_x + text_pos_x, evasion_y + text_pos_y, string.format("%d%%", math.floor(currentEvasion[0])))
	Graphics.CSurface.GL_SetColor(COLOUR_WHITE)
end)

script.on_render_event(Defines.RenderEvents.SPACE_STATUS, function() 
	if Hyperspace.ships.enemy and Hyperspace.ships.enemy.ship.hullIntegrity.first > 0 and (not Hyperspace.ships.enemy.bJumping) and (not Hyperspace.ships.player.bJumping) then
		local player_sensor = Hyperspace.ships.player:GetSystem(7)
		if player_sensor.powerState.first >= 3 or (player_sensor.powerState.first >= 2 and player_sensor.bManned) then
			local enemy_engine_system = Hyperspace.ships.player:GetSystem(1)
			if enemy_engine_system and enemy_engine_system.iHackEffect > 0 then
				Graphics.CSurface.GL_RenderPrimitive(enemy_evasion_image.purple)
			elseif (not enemy_engine_system) or enemy_engine_system:GetEffectivePower() <= 0 then
				Graphics.CSurface.GL_RenderPrimitive(enemy_evasion_image.red)
			elseif currentEvasion[1] >= 100 then
				Graphics.CSurface.GL_RenderPrimitive(enemy_evasion_image.green)
			else
				Graphics.CSurface.GL_RenderPrimitive(enemy_evasion_image.blue)
			end
			Graphics.CSurface.GL_SetColor(COLOUR_TEXT)
			Graphics.freetype.easy_printRightAlign(text_size, enemy_evasion_x + enemy_text_pos_x, enemy_evasion_y + text_pos_y, string.format("%d%%", math.floor(currentEvasion[1])))
			Graphics.CSurface.GL_SetColor(COLOUR_WHITE)
		end
	end
end, function() end)

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
				if shipManager:HasSystem(6) and shipManager:GetSystem(6).bManned then
					local pilot = shipManager:GetSystem(6)
					manning_bonus = manning_bonus + manning_bonus_data[pilot.iActiveManned]
				end

				if shipManager.ship.bCloaked then
					manning_bonus = manning_bonus + 60
				end

				min, max = get_range(engine_level, manning_bonus)
				if max == min then max = max + 1 end

				if shipManager:HasSystem(6) then
					local pilot = shipManager:GetSystem(6)
					if not pilot.bManned then
						if pilot.powerState.first == 2 then
							min = math.floor(min * 0.5)
							max = math.ceil(max * 0.5)
						elseif pilot.powerState.first == 3 then
							min = math.floor(min * 0.8)
							max = math.ceil(max * 0.8)
						else
							min, max = 0
						end
					end
				else
					min, max = 0
				end
			elseif shipManager.ship.bCloaked then
				min, max = get_range(engine_level, 60)
			end
		end
		Hyperspace.Mouse.tooltip = string.format(evasion_tooltip, min, max)
	end
end)

--[[local vter = mods.multiverse.vter
script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, bp)
	print("PROJECTILE_INITIALIZE:")
	print("extend.name:"..tostring(projectile.extend.name))
	print("flight_animation:"..tostring(projectile.flight_animation))
	print("flight_animation.animName:"..tostring(projectile.flight_animation.animName))
	print("flight_animation.animationStrip:"..tostring(projectile.flight_animation.animationStrip))
	if projectile.flight_animation.animationStrip then
		print("flight_animation.animationStrip.id_:"..tostring(projectile.flight_animation.animationStrip.id_))
	else
		print("flight_animation.animationStrip.id_:"..tostring(nil))
	end
	print("flight_animation.primitive:"..tostring(projectile.flight_animation.primitive))
	if projectile.flight_animation.primitive then
		print("flight_animation.primitive.id:"..tostring(projectile.flight_animation.primitive.id))
	else
		print("flight_animation.primitive.id:"..tostring(nil))
	end
	print("flight_animation.mirroredPrimitive:"..tostring(projectile.flight_animation.mirroredPrimitive))
	if projectile.flight_animation.mirroredPrimitive then
		print("flight_animation.mirroredPrimitive.id:"..tostring(projectile.flight_animation.mirroredPrimitive.id))
	else
		print("flight_animation.mirroredPrimitive.id:"..tostring(nil))
	end

	print("death_animation:"..tostring(projectile.death_animation))
	print("death_animation.animName:"..tostring(projectile.death_animation.animName).."\n")

	local damage = projectile.damage
	local custom_damage = projectile.extend.customDamage.def
	local fake = true
	do
		if 
			damage.iDamage > 0 or
			damage.iShieldPiercing > 0 or
			damage.fireChance > 0 or
			damage.breachChance > 0 or
			damage.stunChance > 0 or
			damage.iIonDamage > 0 or
			damage.iSystemDamage > 0 or
			damage.bHullBuster or
			damage.bLockdown or
			damage.crystalShard or
			damage.iStun > 0 or
			custom_damage.statBoostChance > 0 or
			custom_damage.roomStatBoostChance > 0 or
			custom_damage.erosionChance > 0 or
			custom_damage.crewSpawnChance > 0
			then
			print("iDamage:"..tostring(damage.iDamage))
			print("iShieldPiercing:"..tostring(damage.iShieldPiercing))
			print("fireChance:"..tostring(damage.fireChance))
			print("breachChance:"..tostring(damage.breachChance))
			print("stunChance:"..tostring(damage.stunChance))
			print("iIonDamage:"..tostring(damage.iIonDamage))
			print("iSystemDamage:"..tostring(damage.iSystemDamage))
			print("bHullBuster:"..tostring(damage.bHullBuster))
			print("bLockdown:"..tostring(damage.bLockdown))
			print("crystalShard:"..tostring(damage.crystalShard))
			print("iStun:"..tostring(damage.iStun))
			print("statBoostChance:"..tostring(custom_damage.statBoostChance))
			print("roomStatBoostChance:"..tostring(custom_damage.roomStatBoostChance))
			print("erosionChance:"..tostring(custom_damage.erosionChance))
			print("crewSpawnChance:"..tostring(custom_damage.crewSpawnChance).."\n")
			fake = false
		end
	end
	--print("fake:"..tostring(fake))
	if fake then
		projectile.table.er_fake = true
	end
	print("dead:"..tostring(projectile.dead))
	print("missed:"..tostring(projectile.missed))
	print("hitTarget:"..tostring(projectile.hitTarget))
	print("passedTarget:"..tostring(projectile.passedTarget))
	print("bBroadcastTarget:"..tostring(projectile.bBroadcastTarget))
	print("GetType():"..tostring(projectile:GetType()))
	print("hitSolidSound:"..tostring(projectile.hitSolidSound))
	print("hitShieldSound:"..tostring(projectile.hitShieldSound))
	print("missSound:"..tostring(projectile.missSound))
	print("startedDeath:"..tostring(projectile.startedDeath))
	print("GetDodged():"..tostring(projectile:GetDodged()).."\n")


	local targetable = projectile._targetable
	print("_targetable.type:"..tostring(targetable.type))
	print("_targetable.hostile:"..tostring(targetable.hostile))
	print("_targetable.targeted:"..tostring(targetable.targeted))
	print("_targetable:ValidTarget():"..tostring(targetable:ValidTarget()))
	print("_targetable:IsCloaked():"..tostring(targetable:IsCloaked()))
	print("_targetable:GetIsDying():"..tostring(targetable:GetIsDying()))
	print("_targetable:GetIsJumping():"..tostring(targetable:GetIsJumping()).."\n\n")
end)]]

local load_active = false
script.on_init(function(newGame)
	if not newGame then
		load_active = true
	end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if load_active and Hyperspace.playerVariables.er_test_variable > 0 then
		load_active = false
		load_evasion()
	end
end)