CREATE TABLE IF NOT EXISTS `sbanking_shared_accounts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `owner` VARCHAR(100) NOT NULL,
    `balance` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `sbanking_shared_members` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `account_id` INT NOT NULL,
    `identifier` VARCHAR(100) NOT NULL,
    `role` VARCHAR(20) DEFAULT 'member',
    FOREIGN KEY (`account_id`) REFERENCES `sbanking_shared_accounts`(`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `sbanking_themes` (
    `identifier` VARCHAR(100) PRIMARY KEY,
    `theme` VARCHAR(50) DEFAULT 'dark'
);

CREATE TABLE IF NOT EXISTS `sbanking_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(100) NOT NULL,
    `type` VARCHAR(30) NOT NULL,
    `amount` INT NOT NULL,
    `label` VARCHAR(255) NOT NULL,
    `shared_account_id` INT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_shared` (`shared_account_id`)
);
