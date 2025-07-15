local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local Camera     = workspace.CurrentCamera

local MultiplierApplier = {}
MultiplierApplier.__index = MultiplierApplier


MultiplierApplier.Metadata = {}

function MultiplierApplier:Start()
	local player = Players.LocalPlayer


	self.Connection = RunService.RenderStepped:Connect(function()
		local character = player.Character
		if not character then
			return
		end

	
		local targets = {
			Speed = {
				GetBase = function()
					return character.Humanoid:GetAttribute("BaseSpeed") or 11
				end,
				Set = function(val)
					if character.Humanoid then
						character.Humanoid.WalkSpeed = val
					end
				end,
				FolderName = "SpeedMultipliers",
				DisabledAttr = "SpeedMultipliersDisabled",
			},
			FOV = {
				GetBase = function()
					return 70
				end,
				Set = function(val)
					local currentCamera = workspace.CurrentCamera
					if currentCamera then
						currentCamera.FieldOfView = val
					end
				end,
				FolderName = "FOVMultipliers",
				DisabledAttr = "FOVMultipliersDisabled",
			},
		}

	
		for key, info in pairs(targets) do
			local folder = character:FindFirstChild(info.FolderName)
			if folder and folder:IsA("Folder") then
				if not player:GetAttribute(info.DisabledAttr) then
					local baseValue = info.GetBase()
					if baseValue then
						for _, valObj in ipairs(folder:GetChildren()) do
							if valObj:IsA("NumberValue") then
								baseValue = baseValue * valObj.Value
							end
						end
						info.Set(baseValue)
					end
				end
			end
		end
	end)
end

function MultiplierApplier:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	table.clear(self.Metadata)
end

return MultiplierApplier
