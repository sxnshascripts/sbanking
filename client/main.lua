local ESX = exports['es_extended']:getSharedObject()
local bankOpen = false
local currentCardOwner = nil  -- identifier du propriétaire de la carte (nil = mon compte)

-- ══════════════════════════════════════════════
-- OUVRIR / FERMER LA BANQUE
-- ══════════════════════════════════════════════

local function openBank()
    if bankOpen then return end
    bankOpen = true
    currentCardOwner = nil

    ESX.TriggerServerCallback('sBanking:getAccounts', function(data)
        if not data then
            bankOpen = false
            return
        end

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            bank = data.bank,
            cash = data.cash,
            name = data.name,
            theme = data.theme,
            isCardMode = false,
            cardOwner = nil
        })
    end)
end

local function openBankWithCard(ownerIdentifier, ownerName)
    if bankOpen then return end
    bankOpen = true
    currentCardOwner = ownerIdentifier

    ESX.TriggerServerCallback('sBanking:getAccountByCard', function(data)
        if not data then
            bankOpen = false
            currentCardOwner = nil
            return
        end

        if data.error then
            bankOpen = false
            currentCardOwner = nil
            ESX.ShowNotification(data.message or 'Erreur')
            return
        end

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            bank = data.bank,
            cash = data.cash,
            name = data.name,
            theme = data.theme,
            isCardMode = true,
            cardOwner = ownerIdentifier,
            cardOwnerName = ownerName
        })
    end, ownerIdentifier)
end

local function closeBank()
    if not bankOpen then return end
    bankOpen = false
    currentCardOwner = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ══════════════════════════════════════════════
-- OX_TARGET SUR LES DISTRIBUTEURS
-- ══════════════════════════════════════════════

exports['ox_target']:addModel(Config.ATMModels, {
    {
        name = 'sBanking:openATM',
        icon = Config.TargetIcon,
        label = Config.TargetLabel,
        distance = Config.TargetDistance,
        onSelect = function()
            -- Récupérer les cartes bancaires du joueur
            ESX.TriggerServerCallback('sBanking:getPlayerCards', function(cards)
                if not cards or #cards == 0 then
                    -- Pas de carte dans l'inventaire, ouvrir directement son propre compte
                    openBank()
                    return
                end

                -- Filtrer les cartes : retirer les doublons et celles qui appartiennent au joueur
                local myIdentifier = ESX.GetPlayerData().identifier
                local otherCards = {}
                local seenOwners = {}

                for _, card in ipairs(cards) do
                    if card.owner ~= myIdentifier and not seenOwners[card.owner] then
                        seenOwners[card.owner] = true
                        table.insert(otherCards, card)
                    end
                end

                if #otherCards == 0 then
                    -- Toutes les cartes sont au joueur, ouvrir directement
                    openBank()
                    return
                end

                -- Construire le menu de choix
                local options = {
                    {
                        title = '💳 Mon compte bancaire',
                        description = 'Accéder à votre compte personnel',
                        icon = 'fas fa-user',
                        onSelect = function()
                            openBank()
                        end
                    }
                }

                for _, card in ipairs(otherCards) do
                    table.insert(options, {
                        title = '💳 Carte de ' .. card.ownerName,
                        description = 'N° ' .. card.cardNumber,
                        icon = 'fas fa-credit-card',
                        onSelect = function()
                            openBankWithCard(card.owner, card.ownerName)
                        end
                    })
                end

                lib.registerContext({
                    id = 'sBanking_card_choice',
                    title = '🏧 Distributeur Automatique',
                    options = options
                })
                lib.showContext('sBanking_card_choice')
            end)
        end
    }
})

-- Touche Échap pour fermer
RegisterNUICallback('closeBank', function(_, cb)
    closeBank()
    cb('ok')
end)

-- ══════════════════════════════════════════════
-- NUI CALLBACKS
-- ══════════════════════════════════════════════

RegisterNUICallback('deposit', function(data, cb)
    ESX.TriggerServerCallback('sBanking:deposit', function(result)
        cb(result)
    end, tonumber(data.amount), currentCardOwner)
end)

RegisterNUICallback('withdraw', function(data, cb)
    ESX.TriggerServerCallback('sBanking:withdraw', function(result)
        cb(result)
    end, tonumber(data.amount), currentCardOwner)
end)

RegisterNUICallback('getPlayers', function(_, cb)
    ESX.TriggerServerCallback('sBanking:getPlayers', function(result)
        cb(result)
    end)
end)

RegisterNUICallback('transfer', function(data, cb)
    ESX.TriggerServerCallback('sBanking:transfer', function(result)
        cb(result)
    end, tonumber(data.targetId), tonumber(data.amount), currentCardOwner)
end)

RegisterNUICallback('getSharedAccounts', function(_, cb)
    ESX.TriggerServerCallback('sBanking:getSharedAccounts', function(result)
        cb(result)
    end)
end)

RegisterNUICallback('createShared', function(data, cb)
    ESX.TriggerServerCallback('sBanking:createShared', function(result)
        cb(result)
    end, data.name)
end)

RegisterNUICallback('depositShared', function(data, cb)
    ESX.TriggerServerCallback('sBanking:depositShared', function(result)
        cb(result)
    end, tonumber(data.accountId), tonumber(data.amount))
end)

RegisterNUICallback('withdrawShared', function(data, cb)
    ESX.TriggerServerCallback('sBanking:withdrawShared', function(result)
        cb(result)
    end, tonumber(data.accountId), tonumber(data.amount))
end)

RegisterNUICallback('addMember', function(data, cb)
    ESX.TriggerServerCallback('sBanking:addMember', function(result)
        cb(result)
    end, tonumber(data.accountId), tonumber(data.targetId))
end)

RegisterNUICallback('removeMember', function(data, cb)
    ESX.TriggerServerCallback('sBanking:removeMember', function(result)
        cb(result)
    end, tonumber(data.accountId), data.memberIdentifier)
end)

RegisterNUICallback('deleteShared', function(data, cb)
    ESX.TriggerServerCallback('sBanking:deleteShared', function(result)
        cb(result)
    end, tonumber(data.accountId))
end)

RegisterNUICallback('getLogs', function(data, cb)
    ESX.TriggerServerCallback('sBanking:getLogs', function(result)
        cb(result)
    end, currentCardOwner)
end)

RegisterNUICallback('getSharedLogs', function(data, cb)
    ESX.TriggerServerCallback('sBanking:getSharedLogs', function(result)
        cb(result)
    end, tonumber(data.accountId))
end)

RegisterNUICallback('transferToShared', function(data, cb)
    ESX.TriggerServerCallback('sBanking:transferToShared', function(result)
        cb(result)
    end, tonumber(data.accountId), tonumber(data.amount))
end)

RegisterNUICallback('saveTheme', function(data, cb)
    ESX.TriggerServerCallback('sBanking:saveTheme', function(result)
        cb(result)
    end, data.theme)
end)

RegisterNUICallback('generateCard', function(_, cb)
    ESX.TriggerServerCallback('sBanking:generateCard', function(result)
        cb(result)
    end)
end)

RegisterNUICallback('renewCard', function(_, cb)
    ESX.TriggerServerCallback('sBanking:renewCard', function(result)
        cb(result)
    end)
end)

-- ══════════════════════════════════════════════
-- NOTIFICATION DE VIREMENT REÇU
-- ══════════════════════════════════════════════

RegisterNetEvent('sBanking:notify', function(message)
    SendNUIMessage({
        action = 'notification',
        message = message
    })
end)
