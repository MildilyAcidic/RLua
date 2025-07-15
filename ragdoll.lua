


local RagdollModule = {}
local NetworkModule = require(game.ReplicatedStorage.Modules.Network)


function RagdollModule.Enable(self, character, createCopy)
	
	if character:GetAttribute("CantRagdoll") then
		return
	end

	
	if character:GetAttribute("Ragdolling") then
		return
	end

	
	character:SetAttribute("Ragdolling", true)
	character.Archivable = true

	local ragdollCharacter

	if createCopy then
		
		local function hideOriginalCharacter()
			for _, descendant in pairs(character:GetDescendants()) do
				if descendant:IsA("Fire") or descendant:IsA("ParticleEmitter") or descendant:IsA("Light") then
					descendant:Destroy()
				else
					local isBasePart = descendant:IsA("BasePart")
					if isBasePart or descendant:IsA("Decal") then
						if isBasePart then
							descendant.CollisionGroup = "DeadPlayers"
						end
						descendant.Transparency = 1
					end
				end
			end
		end

		
		local ragdollsFolder = workspace:FindFirstChild("Ragdolls")
		if not ragdollsFolder then
			return
		end

		
	

		if #ragdollsFolder:GetChildren() >= 10 then
			hideOriginalCharacter()
			return
		end

		
		ragdollCharacter = character:Clone()
		ragdollCharacter.Parent = ragdollsFolder

		if ragdollCharacter.PrimaryPart then
			ragdollCharacter.PrimaryPart.Anchored = false
		end

		
		hideOriginalCharacter()

		
		for _, descendant in pairs(ragdollCharacter:GetDescendants()) do
			if descendant:IsA("Sound") or descendant:IsA("ParticleEmitter") or 
				descendant:IsA("Light") or descendant:IsA("Beam") or descendant:IsA("Highlight") then
				descendant:Destroy()
			end
		end

		
		local componentsToRemove = {"BodyVelocity", "LinearVelocity", "PlayerAura"}
		for index, componentName in pairs(componentsToRemove) do
			local component = ragdollCharacter:FindFirstChild(componentName, true)
			while component and (index > 2 or not false) do
				component.Name = "ded"
				component:Destroy()
				component = ragdollCharacter:FindFirstChild(componentName, true)
			end
		end

		
		local playerAura = ragdollCharacter:FindFirstChild("PlayerAura", true)
		while playerAura do
			playerAura.Name = "ded"
			playerAura:Destroy()
			playerAura = ragdollCharacter:FindFirstChild("PlayerAura", true)
		end

		
		task.spawn(function()
			local humanoid = ragdollCharacter:WaitForChild("Humanoid", 5)
			if humanoid then
				humanoid.Health = 1
				humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

				
				if game:GetService("RunService"):IsClient() and 
					game.Players.LocalPlayer.Character == character then
					local originalHumanoid = character:FindFirstChild("Humanoid")
					if originalHumanoid and originalHumanoid.BreakJointsOnDeath then
						workspace.CurrentCamera.CameraSubject = ragdollCharacter:FindFirstChild("Head") or humanoid
					else
						workspace.CurrentCamera.CameraSubject = humanoid
					end
				end
			end
		end)

		
		task.delay(30, function()
			if ragdollCharacter.Parent then
				game:GetService("Debris"):AddItem(ragdollCharacter, 10)

				
				for _, descendant in pairs(ragdollCharacter:GetDescendants()) do
					if descendant:IsA("BasePart") or descendant:IsA("Decal") then
						game:GetService("TweenService"):Create(
							descendant, 
							TweenInfo.new(10, Enum.EasingStyle.Linear), 
							{Transparency = 1}
						):Play()
					end
				end
			end
		end)
	else
		ragdollCharacter = character
	end

	
	for _, descendant in pairs(ragdollCharacter:GetDescendants()) do
		if descendant:IsA("Motor6D") and 
			descendant.Parent.Name ~= "HumanoidRootPart" and 
			descendant.Parent.Name ~= "Head" then

			
			local ballSocket = Instance.new("BallSocketConstraint")
			ballSocket.Name = "TemporaryRagdollInstance"

			
			local attachment0 = Instance.new("Attachment")
			attachment0.Name = "TemporaryRagdollInstance"
			local attachment1 = Instance.new("Attachment")
			attachment1.Name = "TemporaryRagdollInstance"

			
			attachment0.Parent = descendant.Part0
			attachment1.Parent = descendant.Part1
			ballSocket.Parent = descendant.Parent
			ballSocket.Attachment0 = attachment0
			ballSocket.Attachment1 = attachment1
			attachment0.CFrame = descendant.C0
			attachment1.CFrame = descendant.C1
			ballSocket.LimitsEnabled = true
			ballSocket.TwistLimitsEnabled = true

			
			descendant.Enabled = false
		end
	end

	
	local humanoid = ragdollCharacter:FindFirstChild("Humanoid")
	if humanoid then
		
		ragdollCharacter:SetAttribute("OriginalJumpInfo", 
			string.format("%s|%s", humanoid.JumpPower, humanoid.JumpHeight))

		humanoid.RequiresNeck = false
		humanoid.PlatformStand = true
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end

	
	for _, descendant in pairs(ragdollCharacter:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if not descendant:GetAttribute("OriginalCollision") then
				descendant:SetAttribute("OriginalCollision", descendant.CanCollide)
			end
			descendant.CanCollide = false
		end
	end

	
	local importantParts = {
		["Head"] = true,
		["Torso"] = true,
		["Left Arm"] = true,
		["Left Leg"] = true,
		["Right Arm"] = true,
		["Right Leg"] = true
	}

	local function createRagdollPart(basePart, yOffset)
		local ragdollPart = Instance.new("Part")
		ragdollPart.Transparency = 1
		ragdollPart.CFrame = basePart.CFrame * CFrame.new(0, yOffset, 0)
		local baseSize = basePart.Size
		local adjustedOffset = 0.05 + yOffset
		ragdollPart.Size = baseSize - Vector3.new(0.05, adjustedOffset, 0.05)
		ragdollPart.Name = "RagdollPart"
		ragdollPart.CollisionGroup = "Ragdolls"
		ragdollPart.Shape = Enum.PartType.Ball
		ragdollPart.Parent = ragdollCharacter

		
		local weld = Instance.new("WeldConstraint")
		weld.Parent = ragdollPart
		weld.Part1 = ragdollPart
		weld.Part0 = basePart
	end

	
	for _, part in pairs(ragdollCharacter:GetChildren()) do
		if part:IsA("BasePart") and (importantParts[part.Name] or 
			(part.Transparency < 0.25 and part.Name ~= "HumanoidRootPart" and part.Name ~= "CollisionHitbox")) then

			
			task.delay(0.125, function()
				part.CanCollide = false
			end)

			
			if part.Name == "Head" then
				createRagdollPart(part, 0)
			else
				createRagdollPart(part, -0.3)
				createRagdollPart(part, 0.3)
			end
		end
	end

	
	task.delay(0.25, function()
		require(game.ReplicatedStorage.Modules.Sound):Play("ragdolledLol", {
			Parent = ragdollCharacter.PrimaryPart
		})
	end)

	return ragdollCharacter
end


function RagdollModule.Disable(self, character)
	if character:GetAttribute("CantRagdoll") then
		return
	end

	if not character.Parent then
		return
	end

	if not character:FindFirstChild("Humanoid") then
		return
	end

	
	character:SetAttribute("Ragdolling", nil)

	
	for _, descendant in pairs(character:GetDescendants()) do
		if descendant.Name == "TemporaryRagdollInstance" then
			descendant:Destroy()
		elseif descendant:IsA("Motor6D") then
			descendant.Enabled = true
		end
	end

	
	for _, child in pairs(character:GetChildren()) do
		if child.Name == "RagdollPart" then
			child:Destroy()
		elseif child:GetAttribute("OriginalCollision") then
			child.CanCollide = child:GetAttribute("OriginalCollision")
			child:SetAttribute("OriginalCollision", nil)
		end
	end

	
	local originalJumpInfo = character:GetAttribute("OriginalJumpInfo")
	if originalJumpInfo then
		local jumpData = string.split(originalJumpInfo, "|")
		character.Humanoid.JumpPower = tonumber(jumpData[1]) or 0
		character.Humanoid.JumpHeight = tonumber(jumpData[2]) or 0
	else
		local characterParent = character.Parent
		if tostring(characterParent) == "Spectating" then
			character.Humanoid.JumpPower = game.StarterPlayer.CharacterJumpPower
			character.Humanoid.JumpHeight = game.StarterPlayer.CharacterJumpHeight
		else
			character.Humanoid.JumpPower = 0
			character.Humanoid.JumpHeight = 0
		end
	end

	
	character.Humanoid.PlatformStand = false
end


function RagdollModule.Start(self)
	if game:GetService("RunService"):IsServer() then
		
		local ragdollsFolder = Instance.new("Folder")
		ragdollsFolder.Name = "Ragdolls"
		ragdollsFolder.Parent = workspace

		
		local function setupCharacterCleanup(descendant)
			local character = descendant.Parent
			local isValidCharacter = character and character:IsA("Model")
			if isValidCharacter then
				isValidCharacter = character.PrimaryPart
			end

			if isValidCharacter and descendant:IsA("Humanoid") then
				descendant.Died:Connect(function()
					game:GetService("Debris"):AddItem(character, 30)
				end)
			end
		end

		workspace.DescendantAdded:Connect(setupCharacterCleanup)
		for _, descendant in pairs(workspace:GetDescendants()) do
			setupCharacterCleanup(descendant)
		end

	elseif game:GetService("RunService"):IsClient() then
		
		NetworkModule:SetConnection("Ragdoll", "REMOTE_EVENT", function(character, timeStamp, velocityData, cframe)
			
			if timeStamp then
				repeat
					task.wait()
				until workspace:GetServerTimeNow() >= (tonumber(timeStamp) or 0)
			end

			
			local ragdollCharacter = self:Enable(character, true)
			if ragdollCharacter and ragdollCharacter.PrimaryPart then
				
				if cframe then
					ragdollCharacter:SetPrimaryPartCFrame(cframe)
				end

				
				if velocityData then
					local ragdollSillies = game.Players.LocalPlayer.PlayerData.Settings.Advanced.RagdollSillies
					local velocityComponents = string.split(velocityData, "|")
					local primaryPart = ragdollCharacter.PrimaryPart
					local x = tonumber(velocityComponents[1]) or 0
					local y = tonumber(velocityComponents[2]) or 0
					local z = tonumber(velocityComponents[3]) or 0

					
					local multiplier = ragdollSillies.Value and 10 or 1
					primaryPart.Velocity = Vector3.new(x, y, z) * multiplier
				end
			end
		end)

		
		local function setupClientRagdoll(descendant)
			local character = descendant.Parent
			local isValidCharacter = character and character:IsA("Model")
			if isValidCharacter then
				isValidCharacter = character.PrimaryPart
			end

			if isValidCharacter and descendant:IsA("Humanoid") then
				descendant.Died:Connect(function()
					task.wait()
					if not character.PrimaryPart.Anchored then
						self:Enable(character, true)
					end
				end)
			end
		end

		workspace.DescendantAdded:Connect(setupClientRagdoll)
		for _, descendant in pairs(workspace:GetDescendants()) do
			setupClientRagdoll(descendant)
		end
	end
end

return RagdollModule
