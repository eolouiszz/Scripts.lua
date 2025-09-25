-- stat_points.lua
-- Sistema de distribuição de pontos para stats de personagem
-- Versão adaptada para GitHub (genérica, comentada e organizada)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Evento remoto que o cliente deve chamar para gastar pontos
local PointsEvent = ReplicatedStorage:WaitForChild("StatSystem"):WaitForChild("Points")

-- Função utilitária para limitar valores entre mínimo e máximo
local function clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

-- Configuração dos stats (mais fácil de modificar/expandir depois)
local STAT_CONFIG = {
	Defense = {
		increment = 5,   -- quanto adiciona por ponto gasto
		maxValue  = 1500,
		maxLevel  = 100,
		onApply = function(player, newValue)
			-- Exemplo: aumenta a vida do Humanoid baseado no valor de defesa
			local char = player.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.MaxHealth = newValue + 100
				end
			end
		end,
	},
	Melee = {
		increment = 1,
		maxValue  = 1500,
		maxLevel  = 100,
	},
	Fruit = {
		increment = 5,
		maxValue  = 1500,
		maxLevel  = 100,
	},
	Sword = {
		increment = 5,
		maxValue  = 1500,
		maxLevel  = 100,
	},
}

-- Função principal: quando o cliente pede para aumentar um stat
PointsEvent.OnServerEvent:Connect(function(player, statName)
	local stats = player:FindFirstChild("Data")
	if not stats then return end

	local points = stats:FindFirstChild("Points")
	local pointsStep = stats:FindFirstChild("PointsS")
	if not (points and pointsStep) then return end

	local statConfig = STAT_CONFIG[statName]
	if not statConfig then return end

	-- Ex: "Defense" -> procura "Defense" e "DefenseP" no Data
	local statValueObj = stats:FindFirstChild(statName)
	local statProgress = stats:FindFirstChild(statName .. "P")
	if not (statValueObj and statProgress) then return end

	-- Checa se o player tem pontos suficientes
	if points.Value < pointsStep.Value then return end

	-- Checa se ainda pode evoluir esse stat
	if statProgress.Value >= statConfig.maxLevel then return end

	-- Aplica aumento
	local increment = statConfig.increment * pointsStep.Value
	statValueObj.Value = clamp(statValueObj.Value + increment, 0, statConfig.maxValue)
	statProgress.Value = clamp(statProgress.Value + pointsStep.Value, 0, statConfig.maxLevel)
	points.Value = clamp(points.Value - pointsStep.Value, 0, math.huge)

	-- Aplica efeitos extras (ex: aumentar vida no Defense)
	if statConfig.onApply then
		statConfig.onApply(player, statValueObj.Value)
	end
end)
