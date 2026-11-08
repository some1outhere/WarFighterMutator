-- Register the behaviour
behaviour("character_wfm")

--[[
compared to the main wfm this lowk has less comments but that's cuz im so fucking lazy, but ill be sure to add in the same concepts

"anyways ima seperate built functions and my functions so i dont have a heart attack and fucking die
update: also added check functions because yes. i should probably learn how to actually improve performance, im just too fucking shy to ask but oh well :("

- sum1outbear/Braincell5/Kanzou 
]]

--TODO: working on making this shit have better performance

-- BUILT IN FUNCTIONS
--[[
Called once when the Ravenscript component is instantiated.
It should be safe to interact with other components and scripts which references you gathered in Awake().

in my own words: fires when a battle is started
]]
function character_wfm:Start()
	self.settings = {
		painWound = 30,
		heavilyWounded = 25,
		gearVolume = 1,

		doGearMovement = false,
	}

	self.settings.painWound = self.script.mutator.GetConfigurationInt("crying_health")
	self.settings.heavilyWounded = self.script.mutator.GetConfigurationInt("heavily_wounded")
	self.settings.gearVolume = self.script.mutator.GetConfigurationFloat("gear_volume")
	self.settings.doGearMovement = self.script.mutator.GetConfigurationBool("do_gear_movement")

	GameEvents.onActorSpawn.AddListener(self, "onSpawn")
end

-- MY OWN FUNCTIONS
--[[
where our player spawns n shit
]]
function character_wfm:onSpawn(actor)
	local hasNode = nil
	for i = 0, actor.transform.childCount - 1 do
		local child = actor.transform.GetChild(i)
		local childObj = child.gameObject.transform

		if childObj.name == "audioNode" then
			hasNode = childObj
			break
		end
	end

	actor.canDeployParachute = false
	if self.script.mutator.GetConfigurationDropdown("team_para_allowance") == 0 then
		actor.canDeployParachute = true
	elseif self.script.mutator.GetConfigurationDropdown("team_para_allowance") == 1 and tostring(actor.team) == "Blue" then
		actor.canDeployParachute = true
	elseif self.script.mutator.GetConfigurationDropdown("team_para_allowance") == 2 and tostring(actor.team) == "Red" then
		actor.canDeployParachute = true
	end
	
	if self.script.mutator.GetConfigurationDropdown("restriction_team") == 1 and tostring(actor.team) == "Red" then
		return
	elseif self.script.mutator.GetConfigurationDropdown("restriction_team") == 2 and tostring(actor.team) == "Blue" then
		return
	end
	
	if hasNode ~= nil then
		-- print("already has one")
		self:enable(actor, hasNode)
		return
	end

	local audioNode = GameObject.instantiate(self.targets.player_audio, actor.transform)
	audioNode.transform.name = "audioNode"

	--[[
	print(actor.transform.name.. " initialized")
	print(audioNode.transform.parent)
	]]

	self:enable(actor, audioNode)
end

--[[
sets up an actor so it could play sounds n shit
]]
function character_wfm:enable(actor, audioNode)
	local gear_foley = nil
	local wounded = nil
	local heavily_wounded = nil

	-- just getting the shit
	for i = 0, audioNode.transform.childCount - 1 do
		local child = audioNode.transform.GetChild(i)
		local childObj = child.gameObject

		if childObj.name == "gear_foley" then
			gear_foley = childObj
		elseif childObj.name == "wounded" then
			wounded = childObj
		elseif childObj.name == "heavily_wounded" then
			heavily_wounded = childObj
		end

		--print(childObj.name)
	end

	local gear_foley_soundBank = gear_foley.GetComponent(SoundBank)
	local wounded_soundBank = wounded.GetComponent(SoundBank)
	local heaily_wounded_soundBank = heavily_wounded.GetComponent(SoundBank)
	
	local gear_foley_audioSource = gear_foley.GetComponent(AudioSource)
	local wounded_audioSource = wounded.GetComponent(AudioSource)
	local heaily_wounded_audioSource = heavily_wounded.GetComponent(AudioSource)

	local function gearSounds(velocity)
		if velocity > 0.02 and self:check(actor) == true then
			-- it's still shit but it can definitely be improved
			local calculated = Mathf.Clamp(2 / velocity, 0, 0.65)
					
			--[[
			if velocity is slow then the timer is higher
			if velocity is faster then the timer is lower
			]]

			--gear_foley_soundBank.SetVolume(self.settings.gearVolume)
			gear_foley_soundBank.PlayRandom()
			coroutine.yield(WaitForSeconds(calculated))
		else
			coroutine.yield(WaitForSeconds(0.015))
		end
	end

	local function woundSounds()
		-- handle this shit
		if actor.health <= self.settings.heavilyWounded and actor.isPlayer == false then
			if heaily_wounded_soundBank.IsPlaying() == false then
				heaily_wounded_soundBank.PlayRandom()
			end

			if wounded_soundBank.IsPlaying() == true then
				wounded_audioSource.Stop()
			end
		elseif actor.health <= self.settings.painWound then
			if wounded_soundBank.IsPlaying() == false then
				wounded_soundBank.PlayRandom()
			end

			if heaily_wounded_soundBank.IsPlaying() == true then
				heaily_wounded_audioSource.Stop()
			end
		end
	end

	local function stopBitching()
		if wounded_soundBank.IsPlaying() == true then
			wounded_audioSource.Stop()
		end

		if heaily_wounded_soundBank.IsPlaying() == true then
			heaily_wounded_audioSource.Stop()
		end
	end

	-- movement sounds
	-- this is only for player due to some performance issues that im quite inexperienced to fix
	self.script:StartCoroutine(function()
		if self.settings.doGearMovement == false then
			return
		end
		
		if actor.isPlayer == false then
			return
		end

		while true do
			if actor.isDead == true then
				break
			end

			local velocity = actor.velocity.magnitude

			gearSounds(velocity)
		end
	end)

	-- health sounds
	self.script:StartCoroutine(function()
		while true do
			if actor.isDead == true then
				stopBitching()
				break
			end

			if self.settings.cryingHealth == 0 and self.settings.heavilyWounded == 0 then
				break
			end

			woundSounds()
			coroutine.yield(WaitForSeconds(1))
		end
	end)
end

-- CHECK FUNCTIONS
--[[
checking whether we are grounded or not
]]
function character_wfm:isGrounded(actor)
	local distance = 0.5
	local target = RaycastTarget.ProjectileHit
	local ray = Ray(actor.position, -actor.transform.up)
	local hit = Physics.Raycast(ray, distance, target)

	if hit then
		return true
	end
	return false
end

--[[
like the name says, checks important shit, true equals pass
]]
function character_wfm:check(actor)
	if actor.isInWater == true then
		return false
	end
	if actor.isSeated == true then
		return false
	end
	if actor.isSwimming == true then
		return false
	end
	if actor.ladder == true then
		return false
	end
	if self:isGrounded(actor) == false then
		return false
	end

	return true
end