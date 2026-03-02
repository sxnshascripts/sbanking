Config = {}

-- ══════════════════════════════════════════════
-- PROPS DE DISTRIBUTEURS (ATM)
-- Ajoutez ou retirez des modèles ici
-- ══════════════════════════════════════════════

Config.ATMModels = {
    'prop_atm_01',
    'prop_atm_02',
    'prop_atm_03',
    'prop_fleeca_atm',
}

-- ══════════════════════════════════════════════
-- PARAMÈTRES DU TARGET
-- ══════════════════════════════════════════════

Config.TargetLabel = 'Accéder au distributeur'
Config.TargetIcon  = 'fas fa-university'
Config.TargetDistance = 2.0

-- ══════════════════════════════════════════════
-- CARTE BANCAIRE
-- ══════════════════════════════════════════════

Config.BankCard = {
    ItemName = 'bankcard',               -- Nom de l'item dans la base de données items
    Label    = 'Carte Bancaire',         -- Label affiché
    AllowOfflineUsage = false,           -- Autoriser l'utilisation de la carte d'un joueur déconnecté
}
