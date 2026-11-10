-- Register the behaviour
-- for future self, replace the shit inside behaviour with the file name, idiota.
behaviour("main_wfm")

local hitCache = {}
local createdWeapCache = {}

local Euler = Quaternion.Euler
local sin = Mathf.sin

local arma_enabled_aim = false
local is_slow_walk = false

local set_fov = 90
local lerp_fov = 90

local sec_aim_var = 0
local pushback = 0

local weapon_stance = 0

local canted_key = KeyCode.H
local overhead_key = KeyCode.Y
local highready_key = KeyCode.O
local lowready_key = KeyCode.K
local arma_zoom_key = KeyCode.T
local slowwalk_key = KeyCode.LeftAlt

--[[

do note i dont know what the fuck im even doing so bare with me, also ill be using AI to help me understand how certain
things work in ravenscript since documentation is quite a bit confusing for me and im no terry davis, however
i will not be using AI to program my entire project, thats boring, and pathetic.

anyways ima seperate built functions and my functions so i dont have a heart attack and fucking die
update: also added check functions because yes. i should probably learn how to actually improve performance, im just too fucking shy to ask but oh well :(

anyhow seems like my roblox lua skills and other previous skills from making kanzou's modern combat system is coming in clutch, love to see it.

- sum1outbear/Braincell5/Kanzou 
]]

--[[
Called once when the Ravenscript component is instantiated.
It should be safe to interact with other components and scripts which references you gathered in Awake().
in my own words: fires when a battle is started
]]
function main_wfm:Start()
	-- set stuff
	self.enabled = true

	-- set stuff
	self:setup()

	-- add listeners
	GameEvents.onActorSpawn.AddListener(self, "onSpawn")

	-- debug
	print("start, version 0.0.9")
end

--[[
Called once every frame. The bulk of all game logic goes here.
]]
function main_wfm:Update()
	-- do check blocks
	if self.enabled == false then
		return
	end

	if self.character == nil then
		return
	end

	if self.character.isDead == true then
		return
	end

	if self:checkVehicle() == true then
		return
	end

	local actWeap = self.character.activeWeapon
	if actWeap == nil then
		return
	end

	-- handles fov
	local weapName = tostring(actWeap.weaponEntry.name)
	local cutbackFov = self.settings.default_fieldofview - self.settings.zoom_amount
	local isInRestrictionsAim = self.settings.ban_co_useaimz[weapName]

	PlayerCamera.activeCamera.fieldOfView = set_fov

	-- only lerp when there's actual change
	if set_fov ~= lerp_fov then
		set_fov = lerp(set_fov, lerp_fov, Time.deltaTime * self.settings.zoom_speed)
	end

	-- handling the field of view to have support for the arma zoom
	if isInRestrictionsAim == weapName then
		if self.character.isAiming == true then
			lerp_fov = actWeap.aimFov
		else
			if arma_enabled_aim == true then
				lerp_fov = cutbackFov
			else
				lerp_fov = self.settings.default_fieldofview
			end
		end
	else
		if arma_enabled_aim == true then
			lerp_fov = cutbackFov
		else
			lerp_fov = self.settings.default_fieldofview
		end
	end
	
	-- arma style aimming
	if self.settings.allow_arma_zoom == true and Input.GetKeyDown(arma_zoom_key) then
		arma_enabled_aim = not arma_enabled_aim
	end

	-- fire viewmodel related shit
	self:viewmodelOffsets()
	self:specializedAiming()
	self:weaponStances()
	self:slowWalk()

	-- handle aimming position
	if self.character.isAiming == true and self.settings.enable_co ~= 0 then
		if sec_aim_var == 1 and isInRestrictionsAim ~= weapName and self.settings.enable_co ~= 1 then
			self.offset.curPos = self.offset.overhead.pos
			self.offset.curRot = self.offset.overhead.rot
		elseif sec_aim_var == -1 and isInRestrictionsAim ~= weapName and self.settings.enable_co ~= -1 then
			self.offset.curPos = self.offset.canted.pos
			self.offset.curRot = self.offset.canted.rot
		else
			self.offset.curPos = self.offset.aim.pos
			self.offset.curRot = self.offset.aim.rot
		end
	else
		self.offset.curPos = self.offset.idle.pos
		self.offset.curRot = self.offset.idle.rot
	end

	-- handle high/low readies
	if self.settings.enable_hl_ready ~= 0 then
		-- where the weapon stance sets up rotations and positions
		if weapon_stance == 1 and self.character.isAiming == false then
			self.offset.high_low_ready.current.pos = self.offset.high_low_ready.highready.pos
			self.offset.high_low_ready.current.rot = self.offset.high_low_ready.highready.rot
		elseif weapon_stance == -1 and self.character.isAiming == false then
			self.offset.high_low_ready.current.pos = self.offset.high_low_ready.lowready.pos
			self.offset.high_low_ready.current.rot = self.offset.high_low_ready.lowready.rot
		else
			self.offset.high_low_ready.current.pos = Vector3(0, 0, 0)
			self.offset.high_low_ready.current.rot = Vector3(0, 0, 0)
		end
	end

	-- debugging purposes n shit
	--print("RAHH this is my stance " .. tostring(self.character.stance))
end

--[[
Called every frame after animations and game logic update
]]
function main_wfm:LateUpdate()
	-- necessary checks
	if self.enabled == false then
		return
	end

	if self.character == nil then
		return
	end

	if self.character.isDead == true then
		return
	end

	if self:checkVehicle() == true then
		return
	end

	local actWeap = self.character.activeWeapon
	if actWeap == nil then
		return
	end

	-- getting basic stuff
	local playerVelocity = self.character.velocity.magnitude
	local input = Vector2(Input.GetAxisRaw("Mouse X"), Input.GetAxisRaw("Mouse Y"))

	-- if is sprinting then we can set sprinting animations
	if self.character.isSprinting == true then
		self.offset.sprint.current.pos = self.offset.sprint.pos
		self.offset.sprint.current.rot = self.offset.sprint.rot
	else
		self.offset.sprint.current.pos = Vector3(0, 0, 0)
		self.offset.sprint.current.rot = Vector3(0, 0, 0)
	end

	-- bobbing in general
	if playerVelocity > 0 then
		local bobX = sin(Time.time * 12) * playerVelocity
		local vel = Player.actor.velocity
		local right = PlayerCamera.activeCamera.transform.right
		local lateralSpeed = 0

		-- this is where the movement lean happens, basically weapon rolls when walking left/right
		if self.settings.allow_lean_lr == true then
			lateralSpeed = Vector3.Dot(vel, -right) * self.settings.amount_lr_lean
		end
		
		if self.character.isSprinting == true then
			self.offset.bobbing.current.pos = Vector3(0, 0, 0)
			self.offset.bobbing.current.rot = Vector3(0, bobX * 2, lateralSpeed)
		else
			self.offset.bobbing.current.pos = Vector3(0, 0, 0)
			self.offset.bobbing.current.rot = Vector3(0, 0, lateralSpeed)
		end
	else
		self.offset.bobbing.current.pos = Vector3(0, 0, 0)
		self.offset.bobbing.current.rot = Vector3(0, 0, 0)
	end

	-- deadzone shit
	if self.settings.allow_deadzone == true then

		-- decide whether the mutiplier should use default or aim
		local mutiplier = self.settings.deadzone_aim_multiplier
		if mutiplier == 0 then
			mutiplier = self.settings.deadzone_multiplier
		else
			if self.character.isAiming == false then
				mutiplier = self.settings.deadzone_multiplier
			end
		end

		if self.character.isAiming == true and self.settings.allow_deadzone_aim == false then
			self.offset.deadzone = Vector2(0, 0)
		else
			self.offset.deadzone = self.offset.deadzone + Vector2(-input.y * mutiplier, input.x * mutiplier)
		end

		if self.settings.allow_deadzone_aim == true then
			if self.offset.deadzone.magnitude <= self.settings.deadzone_aim_limit then
				self.offset.prevAimDeadzoneOffset = self.offset.deadzone
			else
				if self.character.isAiming == true then
					self.offset.deadzone = self.offset.prevAimDeadzoneOffset
				end
			end
		end

		if self.offset.deadzone.magnitude > self.settings.deadzone_limit then
			self.offset.deadzone = self.offset.prevDeadzoneOffset
		else
			self.offset.prevDeadzoneOffset = self.offset.deadzone
		end
	end

	-- swaying shit
	if self.settings.allow_sway == true then
		self.offset.sway = self.offset.sway + Vector2(input.x * self.settings.sway_multiplier, input.y * self.settings.sway_multiplier)
		self.offset.sway = Vector2.Lerp(self.offset.sway, Vector2(0, 0), Time.deltaTime * 25)
	end
	
	-- weapon collision shit
	if self.settings.allow_weapon_collision == true then
		local target = RaycastTarget.ProjectileHit
		local ray = Ray(PlayerCamera.activeCamera.transform.position, Player.actor.activeWeapon.transform.forward)
		local hit = Physics.Raycast(ray, 0.8, target)

		if hit then
			if hitCache[hit.transform.name] ~= nil then
				pushback = hit.distance - 0.8
			else
				if hit.collider.gameObject.GetComponentInParent(Actor) == nil or hit.collider.gameObject.GetComponentInParent(Actor).isBot then
					hitCache[hit.transform.name] = hit
				end
			end
		else
			pushback = 0
		end
	end
end

--[[
Called when the ScriptedBehaviour is destroyed
in my own words: fires when playa leaves
]]
function main_wfm:OnDestroy()
	-- reset stuff
	self:setup()
	self.enabled = false
end

--[[
setup is where we set up every variable to it's default
fucking hate it
]]
function main_wfm:setup()
	self.character = Player.actor

	self.settings = {
		default_fieldofview = 100,

		enable_co = 0,
		enable_hl_ready = 0,

		allow_arma_zoom = true,
		zoom_amount = 30,
		zoom_speed = 12,

		allow_sprint_anims = true,
		bobbing_frequency = 12,

		allow_lean_lr = true,
		amount_lr_lean = 1,

		allow_slow_walk = true,
		slow_walk_speed = 0.6,

		allow_deadzone = true,
		allow_deadzone_aim = false,
		deadzone_limit = 25,
		deadzone_aim_limit = 8,
		deadzone_multiplier = 27,
		deadzone_aim_multiplier = 8,

		allow_sway = true,
		sway_multiplier = 3.5,

		allow_weapon_collision = true,
		lower_upon_collision = true,
		weapon_upwards_collision = 0,
		weapon_rights_collision = 0,
	}
	
	self.offset = {
		curPos = Vector3(0, 0, 0),
		curRot = Vector3(0, 0, 0),

		idle = {
			pos = Vector3(-0.065, -0.025, -0.055),
			rot = Vector3(0, 0, 2),
		},

		sprint = {
			current = {
				pos = Vector3(0, 0, 0),
				rot = Vector3(0, 0, 0)
			},

			pos = Vector3(0.25, 0, -0.076),
			rot = Vector3(0, -6, 2),
		},

		bobbing = {
			current = {
				pos = Vector3(0, 0, 0),
				rot = Vector3(0, 0, 0)
			},
			sprint = {
				vertical = 6,
				horizontal = 12,
			},
			walk = {
				vertical = 6,
				horizontal = 12,
			},
		},

		aim = {
			pos = Vector3(0, 0, -0.076),
			rot = Vector3(0, 0, 0),
		},

		canted = {
			pos = Vector3(0, -0.1, 0),
			rot = Vector3(0, 0, 35),
		},

		overhead = {
			pos = Vector3(0.05, 0.21, -0.2),
			rot = Vector3(0, 0, 55),
		},

		high_low_ready = {
			current = {
				pos = Vector3(0, 0, 0),
				rot = Vector3(0, 0, 0)
			},

			highready = {
				pos = Vector3(0, -0.45, 0),
				rot = Vector3(-45, 0, 0),
			},
			
			lowready = {
				pos = Vector3(0, 0, 0),
				rot = Vector3(25, 0, 0),
			},
		},

		deadzone = Vector2(0, 0),
		prevDeadzoneOffset = Vector2(0, 0),
		prevAimDeadzoneOffset = Vector2(0, 0),
		sway = Vector2(0, 0),
	}

	self.offset.curPos = self.offset.idle.pos
	self.offset.curRot = self.offset.idle.rot

	self:setConfiguration()
end

--[[
in it's name, i'm just fucking lazy
]]
function main_wfm:setConfiguration()
	-- setting up inputs here
	canted_key = KeyCode[self.script.mutator.GetConfigurationString("bind_canted")]
	overhead_key = KeyCode[self.script.mutator.GetConfigurationString("bind_overhead")]
	highready_key = KeyCode[self.script.mutator.GetConfigurationString("bind_highready")]
	lowready_key = KeyCode[self.script.mutator.GetConfigurationString("bind_lowready")]
	slowwalk_key = KeyCode[self.script.mutator.GetConfigurationString("bind_slowwalk")]
	arma_zoom_key = KeyCode[self.script.mutator.GetConfigurationString("bind_arma_zoom")]

	-- setting up base settings here
	self.settings.default_fieldofview = self.script.mutator.GetConfigurationInt("default_fieldofview")
	self.settings.ban_co_useaimz = self:parseWeaponString(self.script.mutator.GetConfigurationString("turn_off_cao_usedefaultzoom"))

	-- setting up aiming related settings here
	self.settings.enable_co = self.script.mutator.GetConfigurationDropdown("enabled_canted_overhead")
	
	-- setting up the arma style zoom
	self.settings.allow_arma_zoom = self.script.mutator.GetConfigurationBool("allow_arma_zoom")
	self.settings.zoom_amount = self.script.mutator.GetConfigurationInt("zoom_amount")
	self.settings.zoom_speed = self.script.mutator.GetConfigurationFloat("zoom_speed")

	-- setting up sprinting animations
	self.settings.allow_sprint_anims = self.script.mutator.GetConfigurationBool("allow_anim_sprinting")
	self.settings.bobbing_frequency = self.script.mutator.GetConfigurationFloat("bobbing_frequency")

	-- setting up walking (specifically more on bobbing lmao)
	self.settings.allow_lean_lr = self.script.mutator.GetConfigurationBool("allow_lean_lr")
	self.settings.amount_lr_lean = self.script.mutator.GetConfigurationFloat("amount_lr_lean")

	-- setting up slow walking
	self.settings.allow_slow_walk = self.script.mutator.GetConfigurationBool("allow_slow_walk")
	self.settings.slow_walk_speed = self.script.mutator.GetConfigurationFloat("slow_walking_speed")

	-- setting up deadzone
	self.settings.allow_deadzone = self.script.mutator.GetConfigurationBool("allow_deadzone")
	self.settings.allow_deadzone_aim = self.script.mutator.GetConfigurationBool("allow_deadzone_aim")

	self.settings.deadzone_limit = self.script.mutator.GetConfigurationFloat("deadzone_limit")
	self.settings.deadzone_aim_limit = self.script.mutator.GetConfigurationFloat("deadzone_aim_limit")

	self.settings.deadzone_multiplier = self.script.mutator.GetConfigurationFloat("deadzone_multiplier")
	self.settings.deadzone_aim_multiplier = self.script.mutator.GetConfigurationFloat("deadzone_aim_multiplier")

	-- setting up sway
	self.settings.allow_sway = self.script.mutator.GetConfigurationBool("allow_sway")
	self.settings.sway_multiplier = self.script.mutator.GetConfigurationFloat("sway_multiplier")

	-- setting up high/low ready
	self.settings.enable_hl_ready = self.script.mutator.GetConfigurationDropdown("enabled_high_low_ready")

	-- setting up weapon collisions
	self.settings.allow_weapon_collision = self.script.mutator.GetConfigurationBool("allow_weapon_collision")
	self.settings.lower_upon_collision = self.script.mutator.GetConfigurationBool("lower_upon_collision")
	self.settings.weapon_upwards_collision = self.script.mutator.GetConfigurationInt("weapon_upwards_collision")
	self.settings.weapon_rights_collision = self.script.mutator.GetConfigurationInt("weapon_rights_collision")

	-- setting up offsets as a whole
	self.offset.idle.pos = Vector3(
		self.script.mutator.GetConfigurationFloat("idle_x_pos"),
		self.script.mutator.GetConfigurationFloat("idle_y_pos"),
		self.script.mutator.GetConfigurationFloat("idle_z_pos")
	)

	self.offset.idle.rot = Vector3(
		self.script.mutator.GetConfigurationFloat("idle_x_rot"),
		self.script.mutator.GetConfigurationFloat("idle_y_pos"),
		self.script.mutator.GetConfigurationFloat("idle_z_pos")
	)

	self.offset.aim.pos = Vector3(
		self.script.mutator.GetConfigurationFloat("aim_x_pos"),
		self.script.mutator.GetConfigurationFloat("aim_y_pos"),
		self.script.mutator.GetConfigurationFloat("aim_z_pos")
	)

	self.offset.aim.rot = Vector3(
		self.script.mutator.GetConfigurationFloat("aim_x_rot"),
		self.script.mutator.GetConfigurationFloat("aim_y_rot"),
		self.script.mutator.GetConfigurationFloat("aim_z_rot")
	)

	self.offset.canted.pos = Vector3(
		self.script.mutator.GetConfigurationFloat("canted_x_pos"),
		self.script.mutator.GetConfigurationFloat("canted_y_pos"),
		self.script.mutator.GetConfigurationFloat("canted_z_pos")
	)

	self.offset.canted.rot = Vector3(
		self.script.mutator.GetConfigurationFloat("canted_x_rot"),
		self.script.mutator.GetConfigurationFloat("canted_y_rot"),
		self.script.mutator.GetConfigurationFloat("canted_z_rot")
	)

	self.offset.overhead.pos = Vector3(
		self.script.mutator.GetConfigurationFloat("overhead_x_pos"),
		self.script.mutator.GetConfigurationFloat("overhead_y_pos"),
		self.script.mutator.GetConfigurationFloat("overhead_z_pos")
	)

	self.offset.overhead.rot = Vector3(
		self.script.mutator.GetConfigurationFloat("overhead_x_rot"),
		self.script.mutator.GetConfigurationFloat("overhead_y_rot"),
		self.script.mutator.GetConfigurationFloat("overhead_z_rot")
	)

	self.offset.sprint.pos = Vector3(
		self.script.mutator.GetConfigurationFloat("sprint_x_pos"),
		self.script.mutator.GetConfigurationFloat("sprint_y_pos"),
		self.script.mutator.GetConfigurationFloat("sprint_z_pos")
	)

	self.offset.sprint.rot = Vector3(
		self.script.mutator.GetConfigurationFloat("sprint_x_rot"),
		self.script.mutator.GetConfigurationFloat("sprint_y_rot"),
		self.script.mutator.GetConfigurationFloat("sprint_z_rot")
	)
end

--[[
player actor spawning gets handled here
]]
function main_wfm:onSpawn(actor)
	if actor.isPlayer == false then
		return
	end

	if self.enabled == false then
		return
	end

	-- set up shiet (updating purposes)
	self.character = actor
	self:setup()

	local weaponSlots = self.character.weaponSlots

	-- check every single weapon
	-- NOTE TO SELF: this is just to tryn  iouhhhhh be more performant since weapon setup is always being called every frame which isn't good
	for i, weapon in pairs(weaponSlots) do
		self:createNode(weapon)
	end

	-- reset shit
	arma_enabled_aim = false
	is_slow_walk = false

	set_fov = 90
	lerp_fov = 90

	sec_aim_var = 0
	pushback = 0

	weapon_stance = 0
end

--[[
handles everything regarding slow wlaking
]]
function main_wfm:slowWalk()
	--[[
	how the function works, when you hold down a certain keycode, it'll basically let you slow walk.
	]]
	if self.settings.can_slow_walk == false then
			return
		end

	-- blehhh we just resetting it in case we're not standing or running
	if self:restrictWhenSlowWalk() == true then
		if self.character.speedMultiplier ~= 1 then
			self.character.speedMultiplier = 1
		end

		if is_slow_walk == true then
			is_slow_walk = false
		end
		return
	end

	-- main shit
	if not Input:GetKeyDown(slowwalk_key) then
		return
	end
				
	is_slow_walk = not is_slow_walk
	
	if is_slow_walk == true then
		self.character.speedMultiplier = self.settings.slow_walk_speed
	else
		self.character.speedMultiplier = 1
	end
end

--[[
sets up weapon nodes, which allows everything to be moved n shit
]]
function main_wfm:createNode(weap)
	--[[
	if createdWeapCache[test.transform.name] ~= nil then
		return
	end
	]]
	--print("couldn't find weapon handler node")
	--print("creating")

	-- creating the node
	local deadzoneNode = GameObject.instantiate(self.targets.handle, weap.transform.parent.transform)
	local handleNode = GameObject.instantiate(self.targets.handle, deadzoneNode.transform)
	deadzoneNode.name = "Deadzone_Node_3D"
	handleNode.name = "Weapon_Node_3D"

	-- setting up positions/rotations
	deadzoneNode.transform.rotation = weap.transform.rotation
	deadzoneNode.transform.position = weap.transform.position

	handleNode.transform.rotation = weap.transform.rotation
	handleNode.transform.position = weap.transform.position
	weap.transform.parent = handleNode.transform

	createdWeapCache[weap.transform.name] = weap.transform.name

	-- debug purposes
	--print("Creating weapon setup")
end

--[[
handles canted/overhead aimming
]]
function main_wfm:specializedAiming()
	if self.settings.enable_co == 0 then
		return
	end

	if Input.GetKeyDown(overhead_key) then
		if sec_aim_var ==  1 then
			sec_aim_var = 0
		else
			sec_aim_var = 1
		end
	end
	
	if Input.GetKeyDown(canted_key) then
		if sec_aim_var == -1 then
			sec_aim_var = 0
		else
			sec_aim_var = -1
		end
	end
end

--[[
handles high/low ready
]]
function main_wfm:weaponStances()
	if self.settings.enable_hl_ready == 0 then
		return
	end

	if Input.GetKeyDown(highready_key) and self.settings.enable_hl_ready ~= 1 then
		if weapon_stance == 1 then
			weapon_stance = 0
		else
			weapon_stance = 1
		end
	elseif Input.GetKeyDown(lowready_key) and self.settings.enable_hl_ready ~= 2 then
		if weapon_stance == -1 then
			weapon_stance = 0
		else
			weapon_stance = -1
		end
	end
end

--[[
handles viewmodel offsets being updated
]]
function main_wfm:viewmodelOffsets()
	local actWeap = self.character.activeWeapon
	local handleNode = actWeap.transform.parent
	local deadzoneNode = handleNode.transform.parent
	
	-- con is short for converted
	local conRot = Euler(self.offset.curRot)
	local condzRot = Euler(Vector3(self.offset.deadzone.x, self.offset.deadzone.y, 0))
	local consyRot = Euler(Vector3(-self.offset.sway.y, self.offset.sway.x, -self.offset.sway.x))

	-- handling pushback
	-- yeah it's pretty large since it's meant to have support for customizable gun tuck
	local upVecRot = Vector3(0, 0, 0)
	local rightVecRot = Vector3(0, 0, 0)

	local xpBack = 0
	local ypBack = 0

	if self.settings.weapon_upwards_collision == 1 then
		upVecRot = Vector3(0, pushback * 130, 0)
		xpBack = -pushback
	elseif self.settings.weapon_upwards_collision == -1 then
		upVecRot = Vector3(0, -pushback * 130, 0)
		xpBack = -pushback
	end

	if self.settings.weapon_rights_collision == 1 then
		rightVecRot = Vector3(pushback * 130, 0, 0)
		ypBack = pushback * 2
	elseif self.settings.weapon_rights_collision == -1 then
		rightVecRot = Vector3(-pushback * 130, 0, 0)
		ypBack = -pushback / 2
	end

	if self.settings.weapon_rights_collision == 0 and self.settings.weapon_upwards_collision == 0 and self.settings.lower_upon_collision == true then
		ypBack = pushback / 5
	end

	local upRot = Euler(upVecRot)
	local rightRot = Euler(rightVecRot)

	local zpBack = pushback / 5
	local weaponPushBackPos = Vector3(xpBack, ypBack, zpBack)
	
	-- position
	local sprintPos = self.offset.sprint.current.pos
	local bobbingPos = self.offset.bobbing.current.pos
	local highLowReadyPos = self.offset.high_low_ready.current.pos
	
	-- rotation
	local sprintRot = Euler(self.offset.sprint.current.rot)
	local bobbingRot = Euler(self.offset.bobbing.current.rot)
	local highLowReadyRot = Euler(self.offset.high_low_ready.current.rot)

	local pos = self.offset.curPos + weaponPushBackPos + sprintPos + bobbingPos + highLowReadyPos
	local rot = conRot * sprintRot * bobbingRot * highLowReadyRot * upRot * rightRot
	local dzRot = condzRot

	local lerpPos = Vector3.Lerp(handleNode.transform.localPosition, pos, Time.deltaTime * 12)
	local lerpRot = Quaternion.Slerp(handleNode.transform.localRotation, rot, Time.deltaTime * 12)
	local dzLerpRot = Quaternion.Slerp(deadzoneNode.transform.localRotation, dzRot * consyRot, Time.deltaTime * 12)

	deadzoneNode.transform.localRotation = dzLerpRot
	handleNode.transform.localPosition = lerpPos
	handleNode.transform.localRotation = lerpRot
end

--[[
restrictions for slow walking
]]
function main_wfm:restrictWhenSlowWalk()
	if tostring(self.character.stance) ~= "Stand" then
		return true
	end
	if self.character.isSprinting == true then
		return true
	end
	if self.character.isDead == true then
		return true
	end
	if self.character.isFallenOver == true then
		return true
	end
	if self.character.isSeated == true then
		return true
	end
	if self.character.isDead == true then
		return true
	end
	if self.character.isOnLadder == true then
		return true
	end
	if self.character.isInvulnerable == true then
		return true
	end
	return false
end

--[[
does checks whether player is in a wehhickle that could support the functions
]]
function main_wfm:checkVehicle()
	if Player.actor.activeSeat then
		if Player.actor.isDriver == true then
			return true
		end
		if Player.actor.activeWeapon and Player.actor.activeWeapon.slot == -1 then
			return true
		end

		return false
	end
	
	return false
end

--[[
seperating a names within a list with a ;
NOTE: like i said copied and pasted i forgot, ts was definitely ai cuz aint no way i did this
]]
function main_wfm:parseWeaponString(weaponString)
    local weapons = {}
    for weaponName in weaponString:gmatch("[^;]+") do
		local matched = weaponName:match("^%s*(.-)%s*$")
		weapons[matched] = tostring(matched)
		print("_"..weapons[matched].."_")
    end
    return weapons
end

--[[
lerp functions
]]
function lerp(a, b, t)
    return a + (b - a) * t
end