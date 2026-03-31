-- Seed data for CI/CD demo
-- This runs on every deploy, so use INSERT OVERWRITE or TRUNCATE+INSERT pattern

-- Owners
INSERT OVERWRITE INTO CICD_DEMO.__SCHEMA__.OWNER (OWNER_ID, OWNER_NAME, OWNER_CATEGORY)
VALUES
    (1,  'Alice Johnson',           'INDIVIDUAL'),
    (2,  'Bob Smith',               'INDIVIDUAL'),
    (3,  'Cedar Park Investments',  'INVESTOR'),
    (4,  'Downtown Realty LLC',     'COMMERCIAL'),
    (5,  'Maria Garcia',            'INDIVIDUAL'),
    (6,  'Midwest Holdings Inc',    'INVESTOR'),
    (7,  'QuickFlip Properties',    'INVESTOR'),
    (8,  'Sam Chen',                'INDIVIDUAL'),
    (9,  'Metro Commercial Group',  'COMMERCIAL'),
    (10, 'Priya Patel',             'INDIVIDUAL');

-- Properties
INSERT OVERWRITE INTO CICD_DEMO.__SCHEMA__.PROPERTY (PROPERTY_ID, ADDRESS, SQUARE_FEET, ZIP_CODE, OWNER_ID)
VALUES
    (1,  '100 Main St',        1200, '63101', 1),
    (2,  '202 Oak Ave',        1800, '63101', 2),
    (3,  '305 Elm Blvd',       2400, '63102', 3),
    (4,  '410 Pine Dr',         950, '63102', 4),
    (5,  '515 Maple Ln',       1600, '63103', 5),
    (6,  '620 Cedar Ct',       3200, '63103', 6),
    (7,  '725 Birch Way',      1100, '63101', 7),
    (8,  '830 Walnut Pl',      1400, '63104', 8),
    (9,  '935 Spruce Rd',      5000, '63104', 9),
    (10, '1040 Ash St',        1750, '63102', 10),
    (11, '1145 Cherry Ln',     2000, '63103', 3),
    (12, '1250 Poplar Ave',    1350, '63101', 6),
    (13, '1355 Willow Dr',      900, '63104', 7),
    (14, '1460 Hickory Ct',    2200, '63102', 1),
    (15, '1565 Magnolia Blvd', 1500, '63103', 4);

-- Property Events (each property has at least one; some have multiple to show history)
INSERT OVERWRITE INTO CICD_DEMO.__SCHEMA__.PROPERTY_EVENT (EVENT_ID, PROPERTY_ID, EVENT_TYPE, EVENT_DATE)
VALUES
    -- Property 1: purchased then approved
    (1,  1,  'PURCHASE',      '2023-01-15'),
    (2,  1,  'APPROVED',      '2023-03-01'),
    -- Property 2: purchased
    (3,  2,  'PURCHASE',      '2023-02-10'),
    -- Property 3: purchased then abandoned
    (4,  3,  'PURCHASE',      '2022-06-01'),
    (5,  3,  'ABANDONMENT',   '2024-01-15'),
    -- Property 4: purchased, condemned
    (6,  4,  'PURCHASE',      '2021-03-20'),
    (7,  4,  'CONDEMNATION',  '2024-06-01'),
    -- Property 5: purchased and approved
    (8,  5,  'PURCHASE',      '2023-07-01'),
    (9,  5,  'APPROVED',      '2023-09-15'),
    -- Property 6: purchased
    (10, 6,  'PURCHASE',      '2023-04-10'),
    -- Property 7: purchased then abandoned
    (11, 7,  'PURCHASE',      '2022-11-01'),
    (12, 7,  'ABANDONMENT',   '2024-03-01'),
    -- Property 8: purchased and approved
    (13, 8,  'PURCHASE',      '2023-05-20'),
    (14, 8,  'APPROVED',      '2024-01-10'),
    -- Property 9: purchased
    (15, 9,  'PURCHASE',      '2023-08-15'),
    -- Property 10: purchased then condemned
    (16, 10, 'PURCHASE',      '2022-09-01'),
    (17, 10, 'CONDEMNATION',  '2024-04-01'),
    -- Property 11: purchased
    (18, 11, 'PURCHASE',      '2023-10-01'),
    -- Property 12: purchased then abandoned
    (19, 12, 'PURCHASE',      '2022-12-15'),
    (20, 12, 'ABANDONMENT',   '2024-05-01'),
    -- Property 13: purchased and approved
    (21, 13, 'PURCHASE',      '2023-06-01'),
    (22, 13, 'APPROVED',      '2024-02-01'),
    -- Property 14: purchased
    (23, 14, 'PURCHASE',      '2023-11-10'),
    -- Property 15: purchased then condemned
    (24, 15, 'PURCHASE',      '2022-08-01'),
    (25, 15, 'CONDEMNATION',  '2024-07-01');
