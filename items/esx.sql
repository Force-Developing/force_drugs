-- ESX inventory (only needed when you don't run ox_inventory).
-- Used by force_drugs (reward) and force_drugsell (what the dealers buy). One item = 1 gram.
INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES
    ('coke', 'Cocaine', 1),
    ('meth', 'Meth', 1),
    ('weed', 'Weed', 1);
