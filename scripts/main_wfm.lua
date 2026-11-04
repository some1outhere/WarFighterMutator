-- Register the behaviour
-- for future self, replace the shit inside behaviour with the file name, faggot.
behaviour("main_wfm")

local currentHeldString = ""
local currentHeldNumber = 67 -- this is necessary...

--[[

do note i dont know what the fuck im even doing so bare with me, also ill be using AI to help me understand how certain
things work in ravenscript since documentation is quite a bit confusing for me and im no terry davis, however
i will not be using AI to program my entire project, thats boring, and pathetic.

anyways ima seperate built functions and my functions so i dont have a heart attack and fucking die
update: also added check functions because yes. i should probably learn how to actually improve performance, im just too fucking shy to ask but oh well :(

anyhow seems like my roblox lua skills and other previous skills from making kanzou's modern combat system is coming in clutch, love to see it.

fun fact: ayyubid flashed me gore when i was 15
- sum1outbear/Braincell5/Kanzou 
]]

-- BUILT IN FUNCTIONS
--[[
Called once when the Ravenscript component is instantiated.
It should be safe to interact with other components and scripts which references you gathered in Awake().

in my own words: fires when a battle is started
]]
function main_wfm:Start()
	-- set stuff
	self:setup()
	self.enabled = true

	-- add listeners
	GameEvents.onActorSpawn.AddListener(self, "onSpawn")
end

--[[
Called once every frame. The bulk of all game logic goes here.
]]
function main_wfm:Update()
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

	-- fire character related shit
	self:slowWalk()

	local actWeap = self.character.activeWeapon
	if actWeap == nil then
		return
	end

	-- handles fov
	local cutbackFov = self.settings.default_fieldofview - self.settings.arma_zoom_cutback
	local isInRestrictionsAim = self:findStringInTable(actWeap.weaponEntry.name, self.settings.ban_ocz_aimming)
	PlayerCamera.activeCamera.fieldOfView = self.settings.set_fov
	self.settings.set_fov = lerp(self.settings.set_fov, self.settings.lerp_fov, Time.deltaTime * 12)

	if isInRestrictionsAim == true then
		if self.character.isAiming == true then
			self.settings.lerp_fov = actWeap.aimFov
		else
			if self.settings.arma_enabled_aim == true then
				self.settings.lerp_fov = cutbackFov
			else
				self.settings.lerp_fov = self.settings.default_fieldofview
			end
		end
	else
		if self.settings.arma_enabled_aim == true then
			self.settings.lerp_fov = cutbackFov
		else
			self.settings.lerp_fov = self.settings.default_fieldofview
		end
	end
	
	-- arma style aimming
	if self.settings.arma_aim == true and Input.GetKeyDown(KeyCode.T) then
		self.settings.arma_enabled_aim = not self.settings.arma_enabled_aim
	end

	-- handle aimming position
	if self.character.isAiming == true then
		if self.settings.sec_aim_var == 1 and isInRestrictionsAim == false then
			self.offset.curPos = self.offset.overhead.pos
			self.offset.curRot = self.offset.overhead.rot
		elseif self.settings.sec_aim_var == -1 and isInRestrictionsAim == false then
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

	-- fire viewmodel related shit
	self:weapSetup()
	self:offsets()
	self:secAim()
	
	-- debugging purposes n shit
	--print("RAHH this is my stance " .. tostring(self.character.stance))
end

--[[
Called every frame after animations and game logic update
]]
function main_wfm:LateUpdate()
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
	
	-- sprinting
	if self.character.isSprinting == true then
		self.offset.sprint.current.pos = self.offset.sprint.pos
		self.offset.sprint.current.rot = self.offset.sprint.rot
	else
		self.offset.sprint.current.pos = Vector3(0, 0, 0)
		self.offset.sprint.current.rot = Vector3(0, 0, 0)
	end

	-- bobbing in general
	local playerVelocity = self.character.velocity.magnitude

	if playerVelocity > 0 then
		local bobY = math.sin(Time.time * 6) * playerVelocity
		local bobX = math.sin(Time.time * 12) * playerVelocity

		local vel = Player.actor.velocity
		local right = PlayerCamera.activeCamera.transform.right
		local lateralSpeed = Vector3.Dot(vel, -right)
		
		if self.character.isSprinting == true then
			self.offset.bobbing.current.pos = Vector3.new(0, 0, 0)
			self.offset.bobbing.current.rot = Vector3.new(0, bobX * 2, lateralSpeed * 1)
		else
			self.offset.bobbing.current.pos = Vector3.new(0, 0, 0)
			self.offset.bobbing.current.rot = Vector3.new(0, 0, lateralSpeed * 1)
		end
	else
		self.offset.bobbing.current.pos = Vector3.new(0, 0, 0)
		self.offset.bobbing.current.rot = Vector3.new(0, 0, 0)
	end

	-- inputs
	local input = Vector2(Input.GetAxisRaw("Mouse X"), Input.GetAxisRaw("Mouse Y"))
	
	-- deadzone shit
	if self.settings.can_deadzone == true then
		if self.character.isAiming == true and self.settings.sec_aim_var == 0 and self.settings.ignore_deadzone_aim == false then
			self.offset.deadzone = Vector2(0, 0)
		else
			self.offset.deadzone = self.offset.deadzone + Vector2(-input.y * self.settings.deadzone_multiplier, input.x * self.settings.deadzone_multiplier)
		end

		if self.offset.deadzone.magnitude > self.settings.deadzone_limit then
			self.offset.deadzone = prevDeadzoneOffset
		else
			prevDeadzoneOffset = self.offset.deadzone
		end
	end

	-- cool ass sway
	if self.settings.can_sway == true then
		self.offset.sway = self.offset.sway + Vector2(input.x * self.settings.sway_multiplier, input.y * self.settings.sway_multiplier)
		self.offset.sway = Vector2.Lerp(self.offset.sway, Vector2(0, 0), Time.deltaTime * 25)
	end
	
	-- weapon pushback shit
	local distance = 0.8
	local target = RaycastTarget.ProjectileHit
	local ray = Ray(PlayerCamera.activeCamera.transform.position, Player.actor.activeWeapon.transform.forward)
	local hit = Physics.Raycast(ray, distance, target)

	if hit then
		if hit.collider.gameObject.GetComponentInParent(Actor) == nil or hit.collider.gameObject.GetComponentInParent(Actor).isBot then
			self.settings.pushback = hit.distance - distance
		end
	else
		self.settings.pushback = 0
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

-- MY OWN FUNCTIONS
--[[
setup is where we set up every variable to it's default
fucking hate it
]]
function main_wfm:setup()
	self.character = Player.actor
	
	self.settings = {
		default_fieldofview = 100,
		set_fov = 90,
		lerp_fov = 90,

		sec_aim_var = 0,
		pushback = 0,
		
		can_slow_walk = true,
		is_slow_walk = false,
		slow_walk_speed = 0.6,
		
		can_sway = true,
		sway_multiplier = 3.5,

		can_deadzone = true,
		deadzone_multiplier = 3,
		deadzone_limit = 15,
		ignore_deadzone_aim = false,

		arma_aim = true,
		arma_enabled_aim = false,
		arma_zoom_cutback = 30,
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
			rot = Vector3(0, -45, 2),
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

		deadzone = Vector2(0, 0),
		sway = Vector2(0, 0),
		prevDeadzoneOffset = Vector2(0, 0),
	}

	self.offset.curPos = self.offset.idle.pos
	self.offset.curRot = self.offset.idle.rot

	currentHeldString = ""
	currentHeldNumber = 67

	-- update
	self.settings.default_fieldofview = self.script.mutator.GetConfigurationInt("default_fov")
	self.settings.ban_ocz_aimming = self:parseWeaponString(self.script.mutator.GetConfigurationString("ban_ocz_aimming"))

	self.settings.can_slow_walk = self.script.mutator.GetConfigurationBool("can_slow_walk")
	self.settings.slow_walk_speed = self.script.mutator.GetConfigurationFloat("slow_walk_speed")

	self.settings.can_sway = self.script.mutator.GetConfigurationBool("can_sway")
	self.settings.sway_multiplier = self.script.mutator.GetConfigurationFloat("sway_multiplier")

	self.settings.can_deadzone = self.script.mutator.GetConfigurationBool("can_deadzone")
	self.settings.deadzone_multiplier = self.script.mutator.GetConfigurationFloat("deadzone_multiplier")
	self.settings.deadzone_limit = self.script.mutator.GetConfigurationFloat("deadzone_limit")
	self.settings.ignore_deadzone_aim = self.script.mutator.GetConfigurationBool("ignore_deadzone_aim")

	self.settings.arma_aim = self.script.mutator.GetConfigurationBool("arma_aim")
	self.settings.arma_zoom_cutback = self.script.mutator.GetConfigurationInt("arma_zoom_cutback")
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

	-- set up shiet
	self.character = actor
	self:setup()

	-- debug shit
	print("Player spawned")
	print(self.character)
end

--[[
handles everything regarding slow wlaking
]]
function main_wfm:slowWalk()
	--[[
	how the function works, when you hold down a certain keycode, it'll basically let you slow walk.
	]]
	self.script:StartCoroutine(function()
		if self.settings.can_slow_walk == false then
			return
		end

		-- blehhh we just resetting it in case we're not standing or running
		if self:restrictWhenSlowWalk() == true then
			if self.character.speedMultiplier ~= 1 then
				self.character.speedMultiplier = 1
			end

			if self.settings.is_slow_walk == true then
				self.settings.is_slow_walk = false
			end
			return
		end

		-- main shit
		if not Input:GetKeyDown(KeyCode.LeftAlt) then
			return
		end
				
		self.settings.is_slow_walk = not self.settings.is_slow_walk
		
		if self.settings.is_slow_walk == true then
			self.character.speedMultiplier = self.settings.slow_walk_speed
		else
			self.character.speedMultiplier = 1
		end
	end)
end

--[[
sets up weapon
]]
function main_wfm:weapSetup()
	local actWeap = self.character.activeWeapon

	self.script:StartCoroutine(function()
		if currentHeldString == tostring(actWeap.weaponEntry.name) or currentHeldNumber == actWeap.slot then
			return
		end

		-- just setting this up so this doesn't happen repeatly
		currentHeldString = tostring(actWeap.weaponEntry.name)
		currentHeldNumber = actWeap.slot

		print(currentHeldString)
		print(currentHeldNumber)

		if actWeap.transform.parent.name == "Weapon_Node_3D" then
			print("already has one chief")
			return
		end

		print("couldn't find weapon handler node")
		print("creating")

		local deadzoneNode = GameObject.instantiate(self.targets.handle, actWeap.transform.parent.transform)
		local handleNode = GameObject.instantiate(self.targets.handle, deadzoneNode.transform)
		deadzoneNode.name = "Deadzone_Node_3D"
		handleNode.name = "Weapon_Node_3D"
		
		deadzoneNode.transform.rotation = actWeap.transform.rotation
		deadzoneNode.transform.position = actWeap.transform.position

		handleNode.transform.rotation = actWeap.transform.rotation
		handleNode.transform.position = actWeap.transform.position
		actWeap.transform.parent = handleNode.transform
	end)
end

--[[
handles canted/overhead aimming
]]
function main_wfm:secAim()
	if Input.GetKeyDown(KeyCode.Y) then
		if self.settings.sec_aim_var ==  1 then
			self.settings.sec_aim_var = 0
		else
			self.settings.sec_aim_var = 1
		end
	end
	
	if Input.GetKeyDown(KeyCode.H) then
		if self.settings.sec_aim_var == -1 then
			self.settings.sec_aim_var = 0
		else
			self.settings.sec_aim_var = -1
		end
	end
end

--[[
handles viewmodel offsets being updated n shit

DEVELOPER NOTE: some of the code here was AI generated.... when i was working on KMCS... so yeah the code being used is pretty old, but still functional
back then i used AI to essentially make certain things that i didnt know how to do, but for this project, i'll strictly be using AI to look through documentation,
even then AI usage is still strict, i dont blame you if you either dont believe me or not like me for my AI use i understand, but rest assure, i'll do my best
]]
function main_wfm:offsets()
	local actWeap = self.character.activeWeapon
	local handleNode = actWeap.transform.parent
	local deadzoneNode = handleNode.transform.parent

	-- con is short for converted
	local conRot = Quaternion.Euler(self.offset.curRot)
	local condzRot = Quaternion.Euler(Vector3(self.offset.deadzone.x, self.offset.deadzone.y, 0))
	local consyRot = Quaternion.Euler(Vector3(-self.offset.sway.y, self.offset.sway.x, -self.offset.sway.x))
	
	local pos = self.offset.curPos + Vector3.new(0, 0, self.settings.pushback) + self.offset.sprint.current.pos + self.offset.bobbing.current.pos
	local rot = conRot * Quaternion.Euler(self.offset.sprint.current.rot) * Quaternion.Euler(self.offset.bobbing.current.rot) * Quaternion.Euler(self.offset.bobbing.current.rot)
	local dzRot = condzRot

	local lerpPos = Vector3.Lerp(handleNode.transform.localPosition, pos, Time.deltaTime * 12)
	local lerpRot = Quaternion.Slerp(handleNode.transform.localRotation, rot, Time.deltaTime * 12)
	local dzLerpRot = Quaternion.Slerp(deadzoneNode.transform.localRotation, dzRot * consyRot, Time.deltaTime * 12)

	deadzoneNode.transform.localRotation = dzLerpRot
	handleNode.transform.localPosition = lerpPos
	handleNode.transform.localRotation = lerpRot
end

-- CHECK FUNCTIONS
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
literally copied and pasted from KMCs lol
]]
function main_wfm:findStringInTable(name, tbl)
    for i, v in ipairs(tbl) do
		if name == v then
			return true
		end
	end

	return false
end

--[[
like i said copied and pasted i forgot, ts was definitely ai cuz aint no way
]]
function main_wfm:parseWeaponString(weaponString)
    local weapons = {}
    for weaponName in weaponString:gmatch("[^;]+") do
        table.insert(weapons, weaponName:match("^%s*(.-)%s*$"))
    end
    return weapons
end

--[[
lerp functions
]]
function lerp(a, b, t)
    return a + (b - a) * t
end