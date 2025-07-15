return {
	["CreateHitbox"] = function(_, attacker, params, onhitCB)
		local character = attacker.Character or attacker
		local primaryPart = character and character.PrimaryPart

		if not primaryPart then return end


	
		local Ragdolls = require(game.ReplicatedStorage.Modules.Ragdoll)

		local config = {
			Size = params.Size or Vector3.new(4.5, 6, 7.5),
			CFrameOffset = params.CFrameOffset or CFrame.new(0, -1, -2),
			CFrame = params.CFrame,
			Damage = params.Damage or 15,
			Penetration = params.Penetration or 0,
			TrueDamage = params.TrueDamage or 0,
			Time = params.Time or 0.125,
			Knockback = params.Knockback or 0,
			HitMultiple = params.HitMultiple or false,
			PredictVelocity = params.PredictVelocity ~= nil and params.PredictVelocity or true,
			ExecuteOnKill = params.ExecuteOnKill or false,
			FriendlyFire = params.FriendlyFire or true,
			RagdollOnHit = params.RagdollOnHit or false,
			UpKnockback = params.UpKnockback or 0,
			Hide = false,
			Connections = params.Connections or {}
		}

		local hitboxState = {
			HumanoidsDamaged = {},
			Creator = attacker,
			Damage = config.Damage,
			IsProjectile = config.CFrame ~= nil,
			TimePast = 0
		}

		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		overlapParams.FilterDescendantsInstances = {character}

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {character}

		local function fireConnection(name, ...)
			if config.Connections[name] then
				config.Connections[name](...)
			end
		end

		function hitboxState.Cancel()
			hitboxState.Cancelled = true
		end
		
		--> main loop

		task.spawn(function()
			while true do
				if not character.Parent or not character.PrimaryPart or hitboxState.TimePast >= config.Time or hitboxState.Cancelled then
					fireConnection("Ended")
					return
				end

				if (#hitboxState.HumanoidsDamaged > 0 and not config.HitMultiple) or character:GetAttribute("Stunned") then
					break
				end

				local hitboxPart = Instance.new("Part")
				hitboxPart.Name = attacker.Name .. "Hitbox"
				hitboxPart.Transparency = 1
				hitboxPart.CanCollide = false
				hitboxPart.CanTouch = false
				hitboxPart.CanQuery = false
				hitboxPart.Anchored = true
				hitboxPart.Size = config.Size
				hitboxPart.Material = Enum.Material.ForceField

				local cframe = config.CFrame and (typeof(config.CFrame) == "function" and config.CFrame() or config.CFrame) 
					or primaryPart.CFrame * config.CFrameOffset

				if not cframe then break end

				hitboxPart.CFrame = cframe
				hitboxPart.Parent = workspace:FindFirstChild("Hitboxes")

				if config.Hide then
					hitboxPart.Transparency = 1
					hitboxPart:SetAttribute("Hidden", true)
				end

				task.delay(2, function()
					hitboxPart:Destroy()
				end)

				if config.PredictVelocity and attacker:IsA("Player") then
					local pingCompensation = math.clamp(10 * attacker:GetNetworkPing(), 0, 3)
					local velocityFactor = 6.5 - pingCompensation
					local predictedOffset = hitboxPart.CFrame:VectorToObjectSpace(primaryPart.AssemblyLinearVelocity) / velocityFactor
					hitboxPart.CFrame = hitboxPart.CFrame * CFrame.new(predictedOffset)
				end

				local parts = workspace:GetPartsInPart(hitboxPart, overlapParams)
				table.sort(parts, function(a, b)
					return (a.Parent:GetAttribute("HitboxPriority") or 1) > (b.Parent:GetAttribute("HitboxPriority") or 1)
				end)
				
				local rayDirection = primaryPart.CFrame.LookVector * (hitboxPart.Size.Z + 1)
				local rayResult    = workspace:Raycast(primaryPart.Position, rayDirection, raycastParams)
				local wallDistance = rayResult and (rayResult.Position - primaryPart.Position).Magnitude
				local wallPart    = rayResult and rayResult.Instance
				local hitHumanoids = {}

				for _, part in ipairs(parts) do
					local humanoid = part.Parent:FindFirstChild("Humanoid")
					if not (humanoid and humanoid.Health > 0 and not hitboxState.HumanoidsDamaged[humanoid]) then
						continue
					end

					local targetModel = humanoid.Parent
					local targetRoot  = targetModel.PrimaryPart
					if not targetRoot then
						continue
					end

					--> cast a ray exactly to the target root, this is to primarily prevent hitting through walls
					local direction   = (targetRoot.Position - primaryPart.Position)
					local rayResult   = workspace:Raycast(primaryPart.Position, direction, raycastParams)

					if rayResult then
						--> if the ray hit something other than the target model, block
						if not rayResult.Instance:IsDescendantOf(targetModel) then
							continue
						end
					end
					--> else rayResult==nil means nothing in the way, so we hit them

					--> team check / ff
					if not (workspace:GetAttribute("FriendlyFire") or config.FriendlyFire) then
						if targetModel:GetAttribute("Team") == character:GetAttribute("Team") then
							continue
						end
					end

					--> record
					hitboxState.HumanoidsDamaged[humanoid] = true
					table.insert(hitHumanoids, humanoid)
					if not config.HitMultiple then
						break
					end
				end

				hitboxPart.Color = #hitHumanoids > 0 and Color3.new(0.5, 1, 0.5) or Color3.new(1, 0.25, 0.25)

				for index, humanoid in pairs(hitHumanoids) do
					local targetCharacter = humanoid.Parent
					local targetRoot = targetCharacter:IsA("Model") and targetCharacter.PrimaryPart

					if targetRoot then
						local resistance = 0
						local resistanceFolder = targetCharacter:FindFirstChild("ResistanceMultipliers")
						if resistanceFolder then
							for _, valueObj in pairs(resistanceFolder:GetChildren()) do
								resistance += valueObj.Value
							end
						end

						local damage = config.Damage * (1 - (resistance - (character:GetAttribute("StrengthBuff") or 0)) / 100)
						targetCharacter:SetAttribute("TimesHit", (targetCharacter:GetAttribute("TimesHit") or 0) + 1)


						if humanoid.Health + (humanoid:GetAttribute("Overheal") or 0) - damage <= 0 then
							warn('Kill')
						end
						
						
						
						if config.RagdollOnHit then
						--[[	Ragdolls:Enable(targetCharacter)
							task.delay(2, function()
								Ragdolls:Disable(targetCharacter)
							end)]]
						end

						if config.Knockback > 0 then
							if config.Knockback >= 15 then
								targetRoot.Velocity = hitboxPart.CFrame.LookVector * config.Knockback * 10
							else
								local bodyVelocity = Instance.new("BodyVelocity")
								bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
								bodyVelocity.Velocity = hitboxPart.CFrame.LookVector * config.Knockback * 10
								bodyVelocity.Parent = targetRoot
								if config.UpKnockback > 0 then
									bodyVelocity.Velocity.Y = config.UpKnockback * 5
								end
								game.Debris:AddItem(bodyVelocity, 0.05)
							end
							
							
						end

						local overheal = humanoid:GetAttribute("Overheal")
						if overheal then
							local remaining = overheal - damage
							humanoid:SetAttribute("Overheal", remaining > 0 and remaining or nil)
						else
							
							if onhitCB then
								onhitCB(character, attacker)
							end
						end

						targetCharacter:SetAttribute("RecentAttacker", attacker.Name)
						targetCharacter:SetAttribute("RecentAttackerTime", tick())

						fireConnection("Hit", targetCharacter, index == 1)
						--Network:FireClientConnection(attacker, "Hit", "UREMOTE_EVENT", damage, Vector3.new(targetRoot.Position.X, targetRoot.Position.Y, targetRoot.Position.Z))
					end
				end

				hitboxState.TimePast += game:GetService("RunService").Heartbeat:Wait()
			end
		end)

		return hitboxState
	end,

	["Start"] = function()
		if game:GetService("RunService"):IsServer() then
			if not workspace:FindFirstChild('Hitboxes') then
				Instance.new("Folder", workspace).Name = "Hitboxes"
			end
		end
	end
}
