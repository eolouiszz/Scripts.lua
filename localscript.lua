local tool = script.Parent
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- Animação de Idle
local idleAnim = Instance.new("Animation")
idleAnim.AnimationId = "rbxassetid://id"
local idleTrack = humanoid:LoadAnimation(idleAnim)
idleTrack.Priority = Enum.AnimationPriority.Idle

-- Animações de Ataque (Combo)
local attackIDs = {
	"rbxassetid://id",   -- Atack 1
	"rbxassetid://id",   -- Atack 2
	"rbxassetid://id",    -- Atack 3
}

local attackTracks = {}
for _, id in ipairs(attackIDs) do
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = humanoid:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	table.insert(attackTracks, track)
end

-- Estado do combo
local combo = 1
local canAttack = true
local lastAttackTime = os.clock()
local comboResetDelay = 1.5 -- segundos sem atacar pra resetar

-- Reset automático do combo após tempo sem atacar
task.spawn(function()
	while true do
		task.wait(0.1)
		if os.clock() - lastAttackTime > comboResetDelay then
			combo = 1
		end
	end
end)

-- Tocar idle ao equipar
tool.Equipped:Connect(function()
	if not idleTrack.IsPlaying then
		idleTrack:Play()
	end
end)

-- Parar animações ao desequipar
tool.Unequipped:Connect(function()
	if idleTrack.IsPlaying then idleTrack:Stop() end
	for _, track in ipairs(attackTracks) do
		if track.IsPlaying then track:Stop() end
	end
end)

-- Função de ataque (combo sequencial)
local function attack()
	if not canAttack then return end
	canAttack = false

	lastAttackTime = os.clock() -- reinicia o timer de inatividade

	-- Para idle enquanto ataca
	if idleTrack.IsPlaying then
		idleTrack:Stop()
	end

	local currentTrack = attackTracks[combo]
	currentTrack:Play()
	currentTrack:AdjustSpeed(1.8)

	task.delay(0.4, function()
		combo += 1
		if combo > #attackTracks then
			combo = 1
		end
		canAttack = true
	end)

	task.delay(0.5, function()
		if not idleTrack.IsPlaying and tool.Parent == character then
			idleTrack:Play()
		end
	end)
end

tool.Activated:Connect(attack)
