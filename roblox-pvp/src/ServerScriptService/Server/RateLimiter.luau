--!strict
-- Limiteur de débit (token bucket) par joueur et par clé d'action.
local Players = game:GetService("Players")

local RateLimiter = {}

local buckets: { [Player]: { [string]: { Tokens: number, Last: number } } } = {}

-- Autorise `perSecond` actions/seconde avec une rafale max de `burst`.
function RateLimiter.Check(player: Player, key: string, perSecond: number, burst: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local b = playerBuckets[key]
	if not b then
		b = { Tokens = burst, Last = now }
		playerBuckets[key] = b
	end
	b.Tokens = math.min(burst, b.Tokens + (now - b.Last) * perSecond)
	b.Last = now
	if b.Tokens >= 1 then
		b.Tokens -= 1
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimiter
