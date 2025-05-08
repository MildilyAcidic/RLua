-- network.lua

local NetworkService = {
	ServiceLive           = false,
	NetworkingConnection  = nil,
	Connections           = {},
	Signals               = {}
}

--> dependencies
local RunService = game:GetService("RunService")
local remoteEvent
local remoteFunction
local unreliableRemoteEvent
local bindableEvent

--> internal dispatcher: invokes the stored callback if type(s) match
local function dispatch(connectionTable, sender, callType, nameOrMethod, ...)
	local entry = connectionTable[nameOrMethod]
	if not entry or entry.Type ~= callType then
		return
	end
	if sender then
		return entry.Callback(sender, ...)
	else
		return entry.Callback(...)
	end
end

--> creates the rme, rmf, urme, and bie
--> then hooks up server/client listeners to dispatch into Connections.
function NetworkService:New(moduleAPI)
	--> create or wait for existing remotes under this script
	if RunService:IsServer() then
		remoteEvent            = Instance.new("RemoteEvent", script)
		remoteFunction         = Instance.new("RemoteFunction", script)
		unreliableRemoteEvent  = Instance.new("UnreliableRemoteEvent", script)
		bindableEvent          = Instance.new("BindableEvent", script)
	else
		remoteEvent            = script:WaitForChild("RemoteEvent", 15)
		remoteFunction         = script:WaitForChild("RemoteFunction", 15)
		unreliableRemoteEvent  = script:WaitForChild("UnreliableRemoteEvent", 15)
		bindableEvent          = script:WaitForChild("Event", 15)
	end

	moduleAPI.Connections = {}

	if RunService:IsServer() then
		--> serverside: OSE listeners
		self.Signals.RemoteEvent = remoteEvent.OnServerEvent:Connect(function(player, ...)
			dispatch(moduleAPI.Connections, player, "REMOTE_EVENT", ...)
		end)
		self.Signals.UnreliableRemoteEvent = unreliableRemoteEvent.OnServerEvent:Connect(function(player, ...)
			dispatch(moduleAPI.Connections, player, "UREMOTE_EVENT", ...)
		end)
		self.Signals.BindableEvent = bindableEvent.Event:Connect(function(...)
			dispatch(moduleAPI.Connections, nil, "BINDABLE_EVENT", ...)
		end)
	else
		--> clientside: OCE listeners
		self.Signals.RemoteEvent = remoteEvent.OnClientEvent:Connect(function(...)
			dispatch(moduleAPI.Connections, nil, "REMOTE_EVENT", ...)
		end)
		self.Signals.UnreliableRemoteEvent = unreliableRemoteEvent.OnClientEvent:Connect(function(...)
			dispatch(moduleAPI.Connections, nil, "UREMOTE_EVENT", ...)
		end)
		self.Signals.BindableEvent = bindableEvent.Event:Connect(function(...)
			dispatch(moduleAPI.Connections, nil, "BINDABLE_EVENT", ...)
		end)
	end

	--> RMF invoke handlers
	if remoteFunction then
		if RunService:IsServer() then
			function remoteFunction.OnServerInvoke(player, ...)
				return dispatch(moduleAPI.Connections, player, "REMOTE_FUNCTION", ...)
			end
		else
			function remoteFunction.OnClientInvoke(...)
				return dispatch(moduleAPI.Connections, nil, "REMOTE_FUNCTION", ...)
			end
		end
	end

	moduleAPI.ServiceLive = true
end

--> registers a named callback for a specific remote type
function NetworkService:SetConnection(methodName, callType, callback)
	if not methodName or not callType or not callback then
		return
	end
	local entry = {
		Name     = methodName,
		Type     = callType,
		Callback = callback
	}
	self.Connections[methodName] = entry
	return entry
end

--> helper to wait for a one-off signal by name
function NetworkService:SetSignal(signalName)
	local fired, params = false, nil
	local connectionName = ("Signal*%s"):format(signalName)

	self:SetConnection(connectionName, "REMOTE_EVENT", function(...)
		fired = true
		params = {...}
	end)

	return {
		Wait = function()
			repeat task.wait() until fired
			return params
		end
	}
end

--> fires a "signal" (remoteevent) to server or client
function NetworkService:FireSignal(signalName, targetPlayer, ...)
	local invokeName = ("Signal*%s"):format(signalName)
	if RunService:IsClient() then
		self:FireServerConnection(invokeName, ...)
	else
		self:FireClientConnection(targetPlayer, invokeName, ...)
	end
end

--> shows if initilized
function NetworkService:IsLive()
	return self.ServiceLive
end

--> fire client.. duh
function NetworkService:FireClientConnection(player, methodName, callType, ...)
	if RunService:IsClient() then return end
	if not player or not player:IsA("Player") then return end

	if callType == "REMOTE_EVENT" and remoteEvent then
		remoteEvent:FireClient(player, methodName, ...)
	elseif callType == "UREMOTE_EVENT" and unreliableRemoteEvent then
		unreliableRemoteEvent:FireClient(player, methodName, ...)
	elseif callType == "REMOTE_FUNCTION" and remoteFunction then
		return remoteFunction:InvokeClient(player, methodName, ...)
	end
end

--> fire all cleints.. duh
function NetworkService:FireAllClientConnection(methodName, callType, ...)
	if RunService:IsClient() then return end
	if callType == "REMOTE_EVENT" and remoteEvent then
		remoteEvent:FireAllClients(methodName, ...)
	elseif callType == "UREMOTE_EVENT" and unreliableRemoteEvent then
		unreliableRemoteEvent:FireAllClients(methodName, ...)
	end
end

--> fire server... duh
function NetworkService:FireServerConnection(methodName, callType, ...)
	if RunService:IsServer() then return end

	if callType == "REMOTE_EVENT" and remoteEvent then
		remoteEvent:FireServer(methodName, ...)
	elseif callType == "UREMOTE_EVENT" and unreliableRemoteEvent then
		unreliableRemoteEvent:FireServer(methodName, ...)
	elseif callType == "REMOTE_FUNCTION" and remoteFunction then
		return remoteFunction:InvokeServer(methodName, ...)
	end
end

--> fire bindable.. duh
function NetworkService:FireConnection(eventName, ...)
	if bindableEvent then
		bindableEvent:Fire(eventName, ...)
	end
end

--> create or fetch remote
function NetworkService:GetRemote(remoteType)
	if remoteType == "REMOTE_EVENT" then
		return RunService:IsServer() and Instance.new("RemoteEvent", script)
			or script:WaitForChild("RemoteEvent", 15)
	elseif remoteType == "UREMOTE_EVENT" then
		return RunService:IsServer() and Instance.new("UnreliableRemoteEvent", script)
			or script:WaitForChild("UnreliableRemoteEvent", 15)
	elseif remoteType == "REMOTE_FUNCTION" then
		return RunService:IsServer() and Instance.new("RemoteFunction", script)
			or script:WaitForChild("RemoteFunction", 15)
	elseif remoteType == "BINDABLE_EVENT" then
		return RunService:IsServer() and Instance.new("BindableEvent", script)
			or script:WaitForChild("Event", 15)
	else
		warn("[NetworkService] Unknown remote type:", remoteType)
	end
end

--> remove a connection in the registry
function NetworkService:RemoveConnection(methodName, callType)
	local entry = self.Connections[methodName]
	if entry and entry.Type == callType then
		self.Connections[methodName] = nil
		return entry
	end
end

--> cleans all conns
function NetworkService:Destroy()
	table.clear(self.Connections)
	for _, signalConn in pairs(self.Signals) do
		if signalConn.Disconnect then
			signalConn:Disconnect()
		end
	end
	if remoteFunction and RunService:IsServer() then
		function remoteFunction.OnServerInvoke() end
	end
	self.ServiceLive = false
end

--> safe vers of prop getter
function NetworkService:GetProperty(key)
	local success, value = pcall(function()
		return self[key]
	end)
	return success and value or nil
end

--> init net and subnet
function NetworkService:Init()
	self:New(self)
	for _, child in ipairs(script:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, err = pcall(function()
				require(child):CreateNetwork(self)
			end)
			if not ok then
				warn("[NetworkService] Error creating sub-network", child.Name, err)
			end
		end
	end
	if RunService:IsServer() then
		game:BindToClose(function()
			self:Destroy()
		end)
	end
end

return NetworkService
