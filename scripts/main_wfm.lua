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

	local actWeap = self.character.activeWeapon

	if actWeap == nil then
		return
	end

	-- fov
	PlayerCamera.activeCamera.fieldOfView = self.settings.fieldofview
	
	if self.character.isAiming == true then
		self.offset.curPos = self.offset.aim.pos
		self.offset.curRot = self.offset.aim.rot
	else
		self.offset.curPos = self.offset.idle.pos
		self.offset.curRot = self.offset.idle.rot
	end

	-- firing some shit
	self:weapSetup()
	self:slowWalk()
	self:offsets()
	
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

	-- to be added lateR
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
		fieldofview = 90,
		
		can_slow_walk = true,
		is_slow_walk = false,
		slow_walk_speed = 0.6
	}

	self.offset = {
		curPos = Vector3(0, 0, 0),
		curRot = Vector3(0, 0, 0),

		idle = {
			pos = Vector3(-0.065, -0.025, -0.055),
			rot = Vector3(0, 0, 2),
		},

		aim = {
			pos = Vector3(0, 0, -0.076),
			rot = Vector3(0, 0, 2),
		}
	}

	self.offset.curPos = self.offset.idle.pos
	self.offset.curRot = self.offset.idle.rot

	currentHeldString = ""
	currentHeldNumber = 67
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
	
	self.character = actor
	self:setup()
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

		local handleNode = GameObject.instantiate(self.targets.handle, actWeap.transform.parent.transform)
		handleNode.name = "Weapon_Node_3D"
		
		handleNode.transform.rotation = actWeap.transform.rotation
		handleNode.transform.position = actWeap.transform.position
		actWeap.transform.parent = handleNode.transform
	end)
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

	local conRot = Quaternion.Euler(self.offset.curRot)
	local pos = self.offset.curPos
	local rot = conRot

	local lerpPos = Vector3.Lerp(handleNode.transform.localPosition, pos, Time.deltaTime * 12)
	local lerpRot = Quaternion.Slerp(handleNode.transform.localRotation, rot, Time.deltaTime * 12)

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