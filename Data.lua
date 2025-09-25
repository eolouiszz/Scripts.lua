-- data_manager.lua
-- Versão adaptada para GitHub: modular, documentada e com opção de desligar persistência
-- Uso: local DataManager = require(path.to.data_manager)
--      DataManager.Init()  -- chama durante a inicialização do servidor

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}

-- === CONFIGURAÇÃO ===
-- Se true, escreve/lerá nos DataStores do Roblox. Se false, tudo roda em "modo local"
-- (útil para publicar no GitHub sem expor dados reais do seu jogo).
local ENABLE_PERSISTENCE = false

-- Mapeamento dos nomes públicos de Stat -> nome do DataStore (strings públicas)
-- Você pode mudar os nomes dos DataStores aqui antes de publicar.
local DATASTORE_MAP = {
    Levels    = "Levels001",
    Belly     = "Belly001",
    Exp       = "Exp001",
    ExpNeed   = "ExpNeed001",
    SwordP    = "SwordP001",
    DefenseP  = "DefenseP001",
    MeleeP    = "MeleeP001",
    FruitP    = "FruitP001",
    Sword     = "Sword001",
    Defense   = "Defense001",
    Melee     = "Melee001",
    Fruit     = "Fruit001",
    Points    = "Points001",
}

-- Defaults para os stats (usado tanto na criação quanto se o DataStore estiver vazio)
local DEFAULT_STATS = {
    Levels   = 1,
    Exp      = 0,
    ExpNeed  = 200,
    Belly    = 0,
    DefenseP = 1,
    SwordP   = 1,
    MeleeP   = 1,
    FruitP   = 1,
    Points   = 0,
    Defense  = 0,
    Sword    = 0,
    Melee    = 0,
    Fruit    = 0,
}

-- Cache dos DataStore objects (para não chamar GetDataStore repetido)
local datastoreCache = {}

local function getDataStore(name)
    if not ENABLE_PERSISTENCE then return nil end
    if datastoreCache[name] then return datastoreCache[name] end
    local ds = DataStoreService:GetDataStore(name)
    datastoreCache[name] = ds
    return ds
end

-- Cria a pasta "Data" e os IntValues padrão para o jogador
local function createStatsFolder(player)
    local stats = Instance.new("Folder")
    stats.Name = "Data"
    stats.Parent = player

    for statName, default in pairs(DEFAULT_STATS) do
        local val = Instance.new("IntValue")
        val.Name = statName
        val.Value = default
        val.Parent = stats
    end

    return stats
end

-- Salva os dados de um jogador
function DataManager.SavePlayer(player)
    if not player or not player:IsDescendantOf(game) then return end
    local dataFolder = player:FindFirstChild("Data")
    if not dataFolder then return end

    if not ENABLE_PERSISTENCE then
        -- Em modo público/GitHub, não fazemos requests ao DataStore
        return true
    end

    local userId = tostring(player.UserId)

    for statName, dsName in pairs(DATASTORE_MAP) do
        local ds = getDataStore(dsName)
        if ds then
            local statValueObj = dataFolder:FindFirstChild(statName)
            if statValueObj then
                local valueToSave = statValueObj.Value
                -- UpdateAsync evita condições de corrida, mas da pra usar SetAsync com pcall também.
                local success, err = pcall(function()
                    ds:UpdateAsync(userId, function(old)
                        -- Se old for nil, retorna o novo valor; se existir, sobrescreve com novo (comportamento simples)
                        return valueToSave
                    end)
                end)
                if not success then
                    warn(("DataManager: Erro ao salvar %s do jogador %s (%s): %s"):format(statName, player.Name, userId, tostring(err)))
                end
            end
        end
    end
    return true
end

-- Carrega os dados de um jogador (popula os IntValues)
function DataManager.LoadPlayer(player)
    if not player then return end
    local dataFolder = player:FindFirstChild("Data") or createStatsFolder(player)

    if not ENABLE_PERSISTENCE then
        -- Em modo público/GitHub, apenas garante que a pasta existe e retorna
        return true
    end

    local userId = tostring(player.UserId)

    for statName, dsName in pairs(DATASTORE_MAP) do
        local ds = getDataStore(dsName)
        if ds then
            local success, result = pcall(function()
                return ds:GetAsync(userId)
            end)
            if success then
                local statObj = dataFolder:FindFirstChild(statName)
                if statObj and type(result) == "number" then
                    statObj.Value = result
                end
                -- se result for nil, mantemos o `default` já criado
            else
                warn(("DataManager: Erro ao carregar %s do jogador %s (%s): %s"):format(statName, player.Name, userId, tostring(result)))
            end
        end
    end
    return true
end

-- Sistema de level-up simples rodando por jogador (exemplo)
local function startLevelLoop(player)
    spawn(function()
        -- espera o player ter a pasta Data
        repeat task.wait() until player and player.Parent and player:FindFirstChild("Data")
        local data = player.Data
        local exp = data:FindFirstChild("Exp")
        local lvl = data:FindFirstChild("Levels")
        local expNeed = data:FindFirstChild("ExpNeed")
        local points = data:FindFirstChild("Points")

        if not (exp and lvl and expNeed and points) then return end

        while player.Parent do
            task.wait(1)
            -- Condição de level-up (exemplo ajustável)
            if exp.Value >= (100 * (lvl.Value + 1)) and lvl.Value <= 99 then
                lvl.Value += 1
                points.Value += 3
                exp.Value = math.max(0, exp.Value - expNeed.Value)
                expNeed.Value += 100

                -- Exemplo: evento para o cliente — comente se não tiver ReplicatedStorage
                local repl = game:GetService("ReplicatedStorage")
                if repl:FindFirstChild("LevelSystem") and repl.LevelSystem:FindFirstChild("LevelUpGui") then
                    local ok, e = pcall(function()
                        repl.LevelSystem.LevelUpGui:FireClient(player)
                    end)
                    if not ok then
                        warn("DataManager: Falha ao disparar LevelUpGui: "..tostring(e))
                    end
                end
            end
        end
    end)
end

-- Hooks de PlayerAdded / PlayerRemoving
function DataManager.Init()
    Players.PlayerAdded:Connect(function(player)
        -- cria pasta e carrega dados
        createStatsFolder(player)
        DataManager.LoadPlayer(player)
        -- inicia loop de level/exp (exemplo)
        startLevelLoop(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        local ok, err = pcall(function()
            DataManager.SavePlayer(player)
        end)
        if not ok then
            warn("DataManager: Erro ao salvar ao remover jogador: "..tostring(err))
        end
    end)

    -- Auto-save para todos
    spawn(function()
        while true do
            task.wait(60)
            for _, player in pairs(Players:GetPlayers()) do
                pcall(function()
                    DataManager.SavePlayer(player)
                end)
            end
        end
    end)
end

-- Expor configurações caso queira alterar em runtime (útil nos testes)
DataManager.Config = {
    ENABLE_PERSISTENCE = ENABLE_PERSISTENCE,
    SetPersistence = function(val) ENABLE_PERSISTENCE = val end,
    DATASTORE_MAP = DATASTORE_MAP,
    DEFAULT_STATS = DEFAULT_STATS,
}

return DataManager
