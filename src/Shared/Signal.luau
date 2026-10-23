--!strict
-- Signal.luau: Lightweight pure Luau event emitter / signal implementation

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		_listeners = {},
	}, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(callback: (...any) -> ()): Connection
	local node = {
		callback = callback,
		connected = true,
	}
	table.insert(self._listeners, node)

	local connection: Connection
	connection = {
		Connected = true,
		Disconnect = function()
			if not node.connected then return end
			node.connected = false
			connection.Connected = false
			local idx = table.find(self._listeners, node)
			if idx then
				table.remove(self._listeners, idx)
			end
		end,
	}
	return connection
end

function Signal:Once(callback: (...any) -> ()): Connection
	local conn: Connection
	conn = self:Connect(function(...)
		conn:Disconnect()
		callback(...)
	end)
	return conn
end

function Signal:Fire(...: any)
	-- Iterate on shallow copy to allow safe disconnect during dispatch
	local listeners = table.clone(self._listeners)
	for _, node in ipairs(listeners) do
		if node.connected then
			task.spawn(node.callback, ...)
		end
	end
end

function Signal:Wait(): ...any
	local running = coroutine.running()
	self:Once(function(...)
		task.spawn(running, ...)
	end)
	return coroutine.yield()
end

function Signal:Destroy()
	for _, node in ipairs(self._listeners) do
		node.connected = false
	end
	table.clear(self._listeners)
end

return Signal
