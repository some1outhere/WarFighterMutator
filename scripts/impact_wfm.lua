-- Register the behaviour
behaviour("impact_wfm")

local cacheAmount = 30

function impact_wfm:Start()
	WaitForSeconds(1)
	print("active")

	self.cache = {
		count = 1,
		effects = self:cache(),
	}
	GameEvents.onProjectileSpawned.AddListener(self, "projectTile")
end

function impact_wfm:projectTile(proj)
	self.script.StartCoroutine(function()
		local flyingCount = 0
		local removeFlyCount = 60

		while true do
			if proj ~= nil then
				local target = RaycastTarget.Default
				local ray = Ray(proj.transform.position, proj.velocity.normalized)
				local hit = Physics.Raycast(ray, 6, target)

				if hit then
					print("HIT")

					if self.cache.effects[self.cache.count] == nil then
						self.cache.count = 0
					end
					self.cache.count = self.cache.count + 1
					print(self.cache.count)

					local effect = self.cache.effects[self.cache.count]
					local actualPlayerEffect = effect.transform.GetChild(0).gameObject
					
					actualPlayerEffect.transform.parent = hit.transform
					actualPlayerEffect.transform.position = hit.point
					actualPlayerEffect.transform.rotation = Quaternion.LookRotation(hit.normal, Vector3.up)

					actualPlayerEffect.GetComponent(ParticleSystem).Stop()
					actualPlayerEffect.GetComponent(ParticleSystem).Play()

					break
				end
			else
				break
			end

			flyingCount = flyingCount + 1
			if flyingCount >= removeFlyCount then
				break
			end
			coroutine.yield(WaitForSeconds(0.1))
		end
	end)
end

function impact_wfm:cache()
	local cachedEffects = {}
	for i = 1, cacheAmount do
		local effect = GameObject.instantiate(self.targets.effects)
		effect.transform.name = "effect"
		cachedEffects[i] = effect
	end
	return cachedEffects
end