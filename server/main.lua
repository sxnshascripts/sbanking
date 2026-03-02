local ESX = exports['es_extended']:getSharedObject()

-- ══════════════════════════════════════════════
-- HELPER : LOGGER
-- ══════════════════════════════════════════════

local function addLog(identifier, logType, amount, label, sharedAccountId)
    MySQL.insert('INSERT INTO sbanking_logs (identifier, type, amount, label, shared_account_id) VALUES (?, ?, ?, ?, ?)', {
        identifier, logType, amount, label, sharedAccountId
    })
end

-- ══════════════════════════════════════════════
-- HELPER : Résoudre le joueur cible (carte ou source)
-- ══════════════════════════════════════════════

local function resolveTarget(source, targetIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil, nil end

    -- Pas de carte, on utilise le joueur source
    if not targetIdentifier or targetIdentifier == '' then
        return xPlayer, xPlayer.getIdentifier()
    end

    -- Mode carte : vérifier si le propriétaire est en ligne (si requis)
    if not Config.BankCard.AllowOfflineUsage then
        local targetPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)
        if not targetPlayer then
            return nil, nil, 'Le propriétaire de cette carte est déconnecté'
        end
    end

    return xPlayer, targetIdentifier
end

-- Helper pour obtenir le solde bancaire d'un identifier (en ligne ou hors ligne)
local function getBankBalance(identifier)
    local xTarget = ESX.GetPlayerFromIdentifier(identifier)
    if xTarget then
        return xTarget.getAccount('bank').money
    end
    -- Joueur hors ligne : lire depuis la DB
    local result = MySQL.query.await('SELECT accounts FROM users WHERE identifier = ?', { identifier })
    if result and result[1] then
        local accounts = json.decode(result[1].accounts)
        if accounts then
            for _, acc in ipairs(accounts) do
                if acc.name == 'bank' then
                    return acc.money
                end
            end
        end
    end
    return 0
end

-- Helper pour modifier le solde bancaire d'un identifier
local function addBankMoney(identifier, amount, reason)
    local xTarget = ESX.GetPlayerFromIdentifier(identifier)
    if xTarget then
        xTarget.addAccountMoney('bank', amount, reason)
        return xTarget.getAccount('bank').money
    end
    -- Hors ligne
    local result = MySQL.query.await('SELECT accounts FROM users WHERE identifier = ?', { identifier })
    if result and result[1] then
        local accounts = json.decode(result[1].accounts)
        if accounts then
            for i, acc in ipairs(accounts) do
                if acc.name == 'bank' then
                    accounts[i].money = acc.money + amount
                    MySQL.update.await('UPDATE users SET accounts = ? WHERE identifier = ?', { json.encode(accounts), identifier })
                    return accounts[i].money
                end
            end
        end
    end
    return 0
end

local function removeBankMoney(identifier, amount, reason)
    local xTarget = ESX.GetPlayerFromIdentifier(identifier)
    if xTarget then
        xTarget.removeAccountMoney('bank', amount, reason)
        return xTarget.getAccount('bank').money
    end
    -- Hors ligne
    local result = MySQL.query.await('SELECT accounts FROM users WHERE identifier = ?', { identifier })
    if result and result[1] then
        local accounts = json.decode(result[1].accounts)
        if accounts then
            for i, acc in ipairs(accounts) do
                if acc.name == 'bank' then
                    accounts[i].money = acc.money - amount
                    MySQL.update.await('UPDATE users SET accounts = ? WHERE identifier = ?', { json.encode(accounts), identifier })
                    return accounts[i].money
                end
            end
        end
    end
    return 0
end

-- ══════════════════════════════════════════════
-- RÉCUPÉRER LES DONNÉES DU JOUEUR
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:getAccounts', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end

    local identifier = xPlayer.getIdentifier()

    local theme = 'dark'
    local result = MySQL.query.await('SELECT theme FROM sbanking_themes WHERE identifier = ?', { identifier })
    if result and result[1] then
        theme = result[1].theme
    end

    cb({
        bank = xPlayer.getAccount('bank').money,
        cash = xPlayer.getMoney(),
        name = xPlayer.getName(),
        theme = theme
    })
end)

-- ══════════════════════════════════════════════
-- RÉCUPÉRER LE COMPTE VIA CARTE BANCAIRE
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:getAccountByCard', function(source, cb, ownerIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end

    if not ownerIdentifier or ownerIdentifier == '' then
        return cb(nil)
    end

    -- Vérifier si le propriétaire est en ligne (si requis)
    if not Config.BankCard.AllowOfflineUsage then
        local ownerPlayer = ESX.GetPlayerFromIdentifier(ownerIdentifier)
        if not ownerPlayer then
            return cb({ error = true, message = 'Le propriétaire de cette carte est déconnecté' })
        end
    end

    -- Récupérer les infos du propriétaire de la carte
    local ownerPlayer = ESX.GetPlayerFromIdentifier(ownerIdentifier)
    local ownerBank = 0
    local ownerCash = 0
    local ownerName = 'Inconnu'

    if ownerPlayer then
        ownerBank = ownerPlayer.getAccount('bank').money
        ownerCash = ownerPlayer.getMoney()
        ownerName = ownerPlayer.getName()
    else
        -- Joueur hors ligne
        ownerBank = getBankBalance(ownerIdentifier)
        ownerCash = 0  -- Pas d'accès aux espèces hors ligne
        local nameResult = MySQL.query.await('SELECT firstname, lastname FROM users WHERE identifier = ?', { ownerIdentifier })
        if nameResult and nameResult[1] then
            ownerName = (nameResult[1].firstname or '') .. ' ' .. (nameResult[1].lastname or '')
        end
    end

    -- Thème du joueur qui utilise la carte (pas du propriétaire)
    local theme = 'dark'
    local themeResult = MySQL.query.await('SELECT theme FROM sbanking_themes WHERE identifier = ?', { xPlayer.getIdentifier() })
    if themeResult and themeResult[1] then
        theme = themeResult[1].theme
    end

    cb({
        bank = ownerBank,
        cash = ownerCash,
        name = ownerName,
        theme = theme,
        isCardMode = true,
        cardOwner = ownerIdentifier
    })
end)

-- ══════════════════════════════════════════════
-- GÉNÉRER UNE CARTE BANCAIRE
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:generateCard', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    local identifier = xPlayer.getIdentifier()
    local playerName = xPlayer.getName()

    -- Générer un numéro de carte unique
    local cardNumber = string.format('%04d-%04d-%04d-%04d',
        math.random(1000, 9999),
        math.random(1000, 9999),
        math.random(1000, 9999),
        math.random(1000, 9999)
    )

    -- Ajouter l'item via ox_inventory avec métadonnées
    local success = exports.ox_inventory:AddItem(source, Config.BankCard.ItemName, 1, {
        owner = identifier,
        ownerName = playerName,
        cardNumber = cardNumber,
        description = Config.BankCard.Label .. ' de ' .. playerName .. '\nN° ' .. cardNumber
    })

    if success then
        -- Enregistrer le numéro de carte valide en base (invalide les anciennes cartes)
        MySQL.query.await([[
            INSERT INTO sbanking_cards (identifier, card_number) VALUES (?, ?)
            ON DUPLICATE KEY UPDATE card_number = ?, created_at = CURRENT_TIMESTAMP
        ]], { identifier, cardNumber, cardNumber })

        addLog(identifier, 'card_generate', 0, 'Carte bancaire générée (' .. cardNumber .. ')', nil)
        cb({ success = true, message = 'Carte bancaire générée avec succès !\nN° ' .. cardNumber })
    else
        cb({ success = false, message = 'Impossible de générer la carte (inventaire plein ?)' })
    end
end)

-- ══════════════════════════════════════════════
-- RENOUVELER UNE CARTE BANCAIRE (en cas de vol)
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:renewCard', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    local identifier = xPlayer.getIdentifier()
    local playerName = xPlayer.getName()

    -- Vérifier qu'une carte existe en base
    local existing = MySQL.query.await('SELECT card_number FROM sbanking_cards WHERE identifier = ?', { identifier })
    if not existing or not existing[1] then
        return cb({ success = false, message = 'Vous n\'avez aucune carte à renouveler' })
    end

    local oldCardNumber = existing[1].card_number

    -- Générer un nouveau numéro de carte
    local newCardNumber = string.format('%04d-%04d-%04d-%04d',
        math.random(1000, 9999),
        math.random(1000, 9999),
        math.random(1000, 9999),
        math.random(1000, 9999)
    )

    -- Supprimer les anciennes cartes du joueur dans son inventaire
    local items = exports.ox_inventory:GetInventoryItems(source)
    if items then
        for _, item in pairs(items) do
            if item.name == Config.BankCard.ItemName and item.metadata and item.metadata.owner == identifier then
                exports.ox_inventory:RemoveItem(source, Config.BankCard.ItemName, 1, nil, item.slot)
            end
        end
    end

    -- Ajouter la nouvelle carte
    local success = exports.ox_inventory:AddItem(source, Config.BankCard.ItemName, 1, {
        owner = identifier,
        ownerName = playerName,
        cardNumber = newCardNumber,
        description = Config.BankCard.Label .. ' de ' .. playerName .. '\nN° ' .. newCardNumber
    })

    if success then
        -- Mettre à jour le numéro valide en base (invalide l'ancienne carte volée)
        MySQL.update.await('UPDATE sbanking_cards SET card_number = ?, created_at = CURRENT_TIMESTAMP WHERE identifier = ?', { newCardNumber, identifier })

        addLog(identifier, 'card_renew', 0, 'Carte renouvelée (ancien: ' .. oldCardNumber .. ' → nouveau: ' .. newCardNumber .. ')', nil)
        cb({ success = true, message = 'Carte renouvelée avec succès !\nAncienne carte invalidée.\nNouveau N° ' .. newCardNumber })
    else
        cb({ success = false, message = 'Impossible de renouveler la carte (inventaire plein ?)' })
    end
end)

-- ══════════════════════════════════════════════
-- VÉRIFIER SI LE PROPRIÉTAIRE EST EN LIGNE
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:checkCardOwnerOnline', function(source, cb, ownerIdentifier)
    if Config.BankCard.AllowOfflineUsage then
        return cb(true)
    end

    local ownerPlayer = ESX.GetPlayerFromIdentifier(ownerIdentifier)
    cb(ownerPlayer ~= nil)
end)

-- ══════════════════════════════════════════════
-- RÉCUPÉRER LES CARTES DU JOUEUR (avec validation)
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:getPlayerCards', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end

    local items = exports.ox_inventory:GetInventoryItems(source)
    local cards = {}

    if items then
        for _, item in pairs(items) do
            if item.name == Config.BankCard.ItemName and item.metadata then
                local cardNumber = item.metadata.cardNumber
                local ownerIdentifier = item.metadata.owner

                -- Vérifier si le numéro de carte est encore valide en base
                local valid = MySQL.query.await('SELECT card_number FROM sbanking_cards WHERE identifier = ?', { ownerIdentifier })

                if valid and valid[1] and valid[1].card_number == cardNumber then
                    table.insert(cards, {
                        owner = ownerIdentifier,
                        ownerName = item.metadata.ownerName or 'Inconnu',
                        cardNumber = cardNumber
                    })
                end
                -- Si la carte n'est pas valide, on l'ignore (carte révoquée/renouvelée)
            end
        end
    end

    cb(cards)
end)

-- ══════════════════════════════════════════════
-- LOGS
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:getLogs', function(source, cb, targetIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end

    local identifier = targetIdentifier or xPlayer.getIdentifier()
    local logs = MySQL.query.await('SELECT type, amount, label, created_at FROM sbanking_logs WHERE identifier = ? AND shared_account_id IS NULL ORDER BY created_at DESC LIMIT 10', { identifier })

    cb(logs or {})
end)

ESX.RegisterServerCallback('sBanking:getSharedLogs', function(source, cb, accountId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end

    local logs = MySQL.query.await('SELECT type, amount, label, created_at FROM sbanking_logs WHERE shared_account_id = ? ORDER BY created_at DESC LIMIT 10', { accountId })

    cb(logs or {})
end)

-- ══════════════════════════════════════════════
-- DÉPOSER
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:deposit', function(source, cb, amount, targetIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return cb({ success = false, message = 'Montant invalide' })
    end

    if xPlayer.getMoney() < amount then
        return cb({ success = false, message = 'Fonds insuffisants' })
    end

    -- Déterminer le compte cible
    local accountIdentifier = xPlayer.getIdentifier()
    local isCardMode = targetIdentifier and targetIdentifier ~= '' and targetIdentifier ~= accountIdentifier

    if isCardMode then
        -- Vérifier que le propriétaire est connecté si requis
        if not Config.BankCard.AllowOfflineUsage then
            local ownerPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)
            if not ownerPlayer then
                return cb({ success = false, message = 'Le propriétaire de la carte est déconnecté' })
            end
        end
        accountIdentifier = targetIdentifier
    end

    -- Retirer l'argent liquide du joueur qui utilise le distributeur
    xPlayer.removeMoney(amount, 'Dépôt bancaire' .. (isCardMode and ' (carte)' or ''))

    -- Ajouter au compte du propriétaire de la carte
    local newBalance = addBankMoney(accountIdentifier, amount, 'Dépôt bancaire' .. (isCardMode and ' via carte' or ''))

    addLog(accountIdentifier, 'deposit', amount, 'Dépôt d\'espèces' .. (isCardMode and ' (via carte de ' .. xPlayer.getName() .. ')' or ''), nil)

    cb({
        success = true,
        message = string.format('Dépôt de $%s effectué', amount),
        bank = newBalance,
        cash = xPlayer.getMoney()
    })
end)

-- ══════════════════════════════════════════════
-- RETIRER
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:withdraw', function(source, cb, amount, targetIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return cb({ success = false, message = 'Montant invalide' })
    end

    -- Déterminer le compte cible
    local accountIdentifier = xPlayer.getIdentifier()
    local isCardMode = targetIdentifier and targetIdentifier ~= '' and targetIdentifier ~= accountIdentifier

    if isCardMode then
        if not Config.BankCard.AllowOfflineUsage then
            local ownerPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)
            if not ownerPlayer then
                return cb({ success = false, message = 'Le propriétaire de la carte est déconnecté' })
            end
        end
        accountIdentifier = targetIdentifier
    end

    local currentBalance = getBankBalance(accountIdentifier)
    if currentBalance < amount then
        return cb({ success = false, message = 'Fonds insuffisants en banque' })
    end

    -- Retirer du compte du propriétaire de la carte
    local newBalance = removeBankMoney(accountIdentifier, amount, 'Retrait bancaire' .. (isCardMode and ' via carte' or ''))

    -- Donner l'argent liquide au joueur qui utilise le distributeur
    xPlayer.addMoney(amount, 'Retrait bancaire' .. (isCardMode and ' (carte)' or ''))

    addLog(accountIdentifier, 'withdraw', amount, 'Retrait d\'espèces' .. (isCardMode and ' (via carte par ' .. xPlayer.getName() .. ')' or ''), nil)

    cb({
        success = true,
        message = string.format('Retrait de $%s effectué', amount),
        bank = newBalance,
        cash = xPlayer.getMoney()
    })
end)

-- ══════════════════════════════════════════════
-- VIREMENT VERS JOUEUR
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:getPlayers', function(source, cb)
    local players = {}
    local xPlayers = ESX.GetExtendedPlayers()

    for _, xPlayer in pairs(xPlayers) do
        if xPlayer.source ~= source then
            table.insert(players, {
                id = xPlayer.source,
                name = xPlayer.getName()
            })
        end
    end

    cb(players)
end)

ESX.RegisterServerCallback('sBanking:transfer', function(source, cb, targetId, amount, cardOwnerIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end
    if not xTarget then return cb({ success = false, message = 'Destinataire introuvable ou déconnecté' }) end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return cb({ success = false, message = 'Montant invalide' })
    end

    -- Déterminer le compte source
    local senderIdentifier = xPlayer.getIdentifier()
    local isCardMode = cardOwnerIdentifier and cardOwnerIdentifier ~= '' and cardOwnerIdentifier ~= senderIdentifier

    if isCardMode then
        if not Config.BankCard.AllowOfflineUsage then
            local ownerPlayer = ESX.GetPlayerFromIdentifier(cardOwnerIdentifier)
            if not ownerPlayer then
                return cb({ success = false, message = 'Le propriétaire de la carte est déconnecté' })
            end
        end
        senderIdentifier = cardOwnerIdentifier
    end

    local senderBalance = getBankBalance(senderIdentifier)
    if senderBalance < amount then
        return cb({ success = false, message = 'Fonds insuffisants en banque' })
    end

    local newBalance = removeBankMoney(senderIdentifier, amount, 'Virement envoyé à ' .. xTarget.getName())
    xTarget.addAccountMoney('bank', amount, 'Virement reçu de carte bancaire')

    local senderName = isCardMode and ('carte de ' .. (ESX.GetPlayerFromIdentifier(cardOwnerIdentifier) and ESX.GetPlayerFromIdentifier(cardOwnerIdentifier).getName() or 'Inconnu')) or xPlayer.getName()

    addLog(senderIdentifier, 'transfer_out', amount, 'Virement vers ' .. xTarget.getName() .. (isCardMode and ' (via carte)' or ''), nil)
    addLog(xTarget.getIdentifier(), 'transfer_in', amount, 'Virement de ' .. senderName, nil)

    TriggerClientEvent('sBanking:notify', targetId, string.format('Vous avez reçu un virement de $%s', amount))

    cb({
        success = true,
        message = string.format('Virement de $%s envoyé à %s', amount, xTarget.getName()),
        bank = newBalance,
        cash = xPlayer.getMoney()
    })
end)

-- ══════════════════════════════════════════════
-- VIREMENT PERSONNEL → COMPTE PARTAGÉ
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:transferToShared', function(source, cb, accountId, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    amount = tonumber(amount)
    accountId = tonumber(accountId)
    if not amount or amount <= 0 then
        return cb({ success = false, message = 'Montant invalide' })
    end

    if xPlayer.getAccount('bank').money < amount then
        return cb({ success = false, message = 'Fonds insuffisants en banque' })
    end

    local identifier = xPlayer.getIdentifier()
    local isMember = MySQL.scalar.await('SELECT COUNT(*) FROM sbanking_shared_members WHERE account_id = ? AND identifier = ?', { accountId, identifier })

    if isMember == 0 then
        return cb({ success = false, message = 'Vous n\'êtes pas membre de ce compte' })
    end

    local accountInfo = MySQL.query.await('SELECT name FROM sbanking_shared_accounts WHERE id = ?', { accountId })
    local accountName = accountInfo and accountInfo[1] and accountInfo[1].name or 'Compte partagé'

    xPlayer.removeAccountMoney('bank', amount, 'Virement vers compte partagé: ' .. accountName)
    MySQL.update.await('UPDATE sbanking_shared_accounts SET balance = balance + ? WHERE id = ?', { amount, accountId })

    addLog(identifier, 'transfer_to_shared', amount, 'Virement vers ' .. accountName, nil)
    addLog(identifier, 'shared_deposit', amount, 'Virement de ' .. xPlayer.getName(), accountId)

    local account = MySQL.query.await('SELECT balance FROM sbanking_shared_accounts WHERE id = ?', { accountId })

    cb({
        success = true,
        message = string.format('Virement de $%s vers "%s"', amount, accountName),
        bank = xPlayer.getAccount('bank').money,
        cash = xPlayer.getMoney(),
        sharedBalance = account[1].balance
    })
end)

-- ══════════════════════════════════════════════
-- COMPTES PARTAGÉS
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:getSharedAccounts', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end

    local identifier = xPlayer.getIdentifier()

    local accounts = MySQL.query.await([[
        SELECT sa.*, sm.role
        FROM sbanking_shared_accounts sa
        INNER JOIN sbanking_shared_members sm ON sa.id = sm.account_id
        WHERE sm.identifier = ?
    ]], { identifier })

    if not accounts then return cb({}) end

    for i, account in ipairs(accounts) do
        local members = MySQL.query.await([[
            SELECT sm.identifier, sm.role
            FROM sbanking_shared_members sm
            WHERE sm.account_id = ?
        ]], { account.id })
        accounts[i].members = members or {}
    end

    cb(accounts)
end)

ESX.RegisterServerCallback('sBanking:createShared', function(source, cb, name)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    local identifier = xPlayer.getIdentifier()

    if not name or name == '' then
        return cb({ success = false, message = 'Nom de compte requis' })
    end

    local id = MySQL.insert.await('INSERT INTO sbanking_shared_accounts (name, owner) VALUES (?, ?)', { name, identifier })
    MySQL.insert.await('INSERT INTO sbanking_shared_members (account_id, identifier, role) VALUES (?, ?, ?)', { id, identifier, 'owner' })

    addLog(identifier, 'shared_create', 0, 'Création du compte "' .. name .. '"', id)

    cb({ success = true, message = string.format('Compte "%s" créé avec succès', name) })
end)

ESX.RegisterServerCallback('sBanking:depositShared', function(source, cb, accountId, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return cb({ success = false, message = 'Montant invalide' })
    end

    if xPlayer.getAccount('bank').money < amount then
        return cb({ success = false, message = 'Fonds insuffisants en banque' })
    end

    local identifier = xPlayer.getIdentifier()
    local isMember = MySQL.scalar.await('SELECT COUNT(*) FROM sbanking_shared_members WHERE account_id = ? AND identifier = ?', { accountId, identifier })

    if isMember == 0 then
        return cb({ success = false, message = 'Vous n\'êtes pas membre de ce compte' })
    end

    xPlayer.removeAccountMoney('bank', amount, 'Dépôt compte partagé')
    MySQL.update.await('UPDATE sbanking_shared_accounts SET balance = balance + ? WHERE id = ?', { amount, accountId })

    addLog(identifier, 'shared_deposit', amount, 'Dépôt par ' .. xPlayer.getName(), accountId)

    local account = MySQL.query.await('SELECT balance FROM sbanking_shared_accounts WHERE id = ?', { accountId })

    cb({
        success = true,
        message = string.format('Dépôt de $%s sur le compte partagé', amount),
        bank = xPlayer.getAccount('bank').money,
        cash = xPlayer.getMoney(),
        sharedBalance = account[1].balance
    })
end)

ESX.RegisterServerCallback('sBanking:withdrawShared', function(source, cb, accountId, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return cb({ success = false, message = 'Montant invalide' })
    end

    local identifier = xPlayer.getIdentifier()
    local isMember = MySQL.scalar.await('SELECT COUNT(*) FROM sbanking_shared_members WHERE account_id = ? AND identifier = ?', { accountId, identifier })

    if isMember == 0 then
        return cb({ success = false, message = 'Vous n\'êtes pas membre de ce compte' })
    end

    local account = MySQL.query.await('SELECT balance FROM sbanking_shared_accounts WHERE id = ?', { accountId })

    if not account or not account[1] or account[1].balance < amount then
        return cb({ success = false, message = 'Fonds insuffisants sur le compte partagé' })
    end

    MySQL.update.await('UPDATE sbanking_shared_accounts SET balance = balance - ? WHERE id = ?', { amount, accountId })
    xPlayer.addAccountMoney('bank', amount, 'Retrait compte partagé')

    addLog(identifier, 'shared_withdraw', amount, 'Retrait par ' .. xPlayer.getName(), accountId)

    cb({
        success = true,
        message = string.format('Retrait de $%s du compte partagé', amount),
        bank = xPlayer.getAccount('bank').money,
        cash = xPlayer.getMoney(),
        sharedBalance = account[1].balance - amount
    })
end)

ESX.RegisterServerCallback('sBanking:addMember', function(source, cb, accountId, targetId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    local identifier = xPlayer.getIdentifier()

    local isOwner = MySQL.scalar.await('SELECT COUNT(*) FROM sbanking_shared_members WHERE account_id = ? AND identifier = ? AND role = ?', { accountId, identifier, 'owner' })

    if isOwner == 0 then
        return cb({ success = false, message = 'Seul le propriétaire peut ajouter des membres' })
    end

    local xTarget = ESX.GetPlayerFromId(tonumber(targetId))
    if not xTarget then return cb({ success = false, message = 'Joueur cible introuvable' }) end

    local targetIdentifier = xTarget.getIdentifier()

    local alreadyMember = MySQL.scalar.await('SELECT COUNT(*) FROM sbanking_shared_members WHERE account_id = ? AND identifier = ?', { accountId, targetIdentifier })

    if alreadyMember > 0 then
        return cb({ success = false, message = 'Ce joueur est déjà membre' })
    end

    MySQL.insert.await('INSERT INTO sbanking_shared_members (account_id, identifier, role) VALUES (?, ?, ?)', { accountId, targetIdentifier, 'member' })

    addLog(identifier, 'shared_add_member', 0, xTarget.getName() .. ' ajouté', accountId)

    cb({ success = true, message = string.format('%s ajouté au compte partagé', xTarget.getName()) })
end)

ESX.RegisterServerCallback('sBanking:removeMember', function(source, cb, accountId, memberIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    local identifier = xPlayer.getIdentifier()

    local isOwner = MySQL.scalar.await('SELECT COUNT(*) FROM sbanking_shared_members WHERE account_id = ? AND identifier = ? AND role = ?', { accountId, identifier, 'owner' })

    if isOwner == 0 then
        return cb({ success = false, message = 'Seul le propriétaire peut retirer des membres' })
    end

    if memberIdentifier == identifier then
        return cb({ success = false, message = 'Vous ne pouvez pas vous retirer vous-même' })
    end

    MySQL.query.await('DELETE FROM sbanking_shared_members WHERE account_id = ? AND identifier = ?', { accountId, memberIdentifier })

    addLog(identifier, 'shared_remove_member', 0, 'Membre retiré', accountId)

    cb({ success = true, message = 'Membre retiré du compte partagé' })
end)

ESX.RegisterServerCallback('sBanking:deleteShared', function(source, cb, accountId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false, message = 'Joueur introuvable' }) end

    local identifier = xPlayer.getIdentifier()

    local isOwner = MySQL.scalar.await('SELECT COUNT(*) FROM sbanking_shared_members WHERE account_id = ? AND identifier = ? AND role = ?', { accountId, identifier, 'owner' })

    if isOwner == 0 then
        return cb({ success = false, message = 'Seul le propriétaire peut supprimer ce compte' })
    end

    local account = MySQL.query.await('SELECT balance FROM sbanking_shared_accounts WHERE id = ?', { accountId })
    if account and account[1] and account[1].balance > 0 then
        xPlayer.addAccountMoney('bank', account[1].balance, 'Fermeture compte partagé')
    end

    MySQL.query.await('DELETE FROM sbanking_shared_accounts WHERE id = ?', { accountId })

    cb({
        success = true,
        message = 'Compte partagé supprimé',
        bank = xPlayer.getAccount('bank').money,
        cash = xPlayer.getMoney()
    })
end)

-- ══════════════════════════════════════════════
-- THÈME
-- ══════════════════════════════════════════════

ESX.RegisterServerCallback('sBanking:saveTheme', function(source, cb, theme)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({ success = false }) end

    local identifier = xPlayer.getIdentifier()
    local validThemes = { 'dark', 'light', 'ocean', 'emerald', 'sunset', 'purple' }
    local isValid = false

    for _, v in ipairs(validThemes) do
        if v == theme then isValid = true break end
    end

    if not isValid then
        return cb({ success = false, message = 'Thème invalide' })
    end

    MySQL.query.await([[
        INSERT INTO sbanking_themes (identifier, theme) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE theme = ?
    ]], { identifier, theme, theme })

    cb({ success = true, message = 'Thème sauvegardé' })
end)
