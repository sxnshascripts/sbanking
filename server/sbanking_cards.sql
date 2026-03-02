-- Table pour stocker le numéro de carte valide de chaque joueur
-- Lorsqu'un joueur renouvelle sa carte, l'ancien numéro est remplacé
-- et toutes les anciennes cartes deviennent invalides

CREATE TABLE IF NOT EXISTS `sbanking_cards` (
    `identifier` VARCHAR(60) NOT NULL,
    `card_number` VARCHAR(19) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
