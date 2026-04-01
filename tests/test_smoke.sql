-- Smoke tests for CICD_DEMO deployment
-- Each query returns a row with TEST_NAME and RESULT ('PASS' or 'FAIL')
-- The deploy script checks for any 'FAIL' results

-- Force the dynamic table to refresh before running tests
ALTER DYNAMIC TABLE CICD_DEMO.<% schema %>.PROPERTY_STATUS_BY_ZIP REFRESH;

-- Test 1: OWNER table has rows
SELECT 'owner_has_rows' AS TEST_NAME,
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM CICD_DEMO.<% schema %>.OWNER;

-- Test 2: PROPERTY table has rows
SELECT 'property_has_rows' AS TEST_NAME,
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM CICD_DEMO.<% schema %>.PROPERTY;

-- Test 3: PROPERTY_EVENT table has rows
SELECT 'property_event_has_rows' AS TEST_NAME,
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM CICD_DEMO.<% schema %>.PROPERTY_EVENT;

-- Test 4: Dynamic table exists and has rows
SELECT 'dynamic_table_has_rows' AS TEST_NAME,
       CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM CICD_DEMO.<% schema %>.PROPERTY_STATUS_BY_ZIP;

-- Test 5: Every property has at least one event
SELECT 'all_properties_have_events' AS TEST_NAME,
       CASE WHEN orphan_count = 0 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM (
    SELECT COUNT(*) AS orphan_count
    FROM CICD_DEMO.<% schema %>.PROPERTY p
    LEFT JOIN CICD_DEMO.<% schema %>.PROPERTY_EVENT pe ON pe.PROPERTY_ID = p.PROPERTY_ID
    WHERE pe.EVENT_ID IS NULL
);

-- Test 6: Dynamic table zip codes match property zip codes
SELECT 'dt_zips_match_properties' AS TEST_NAME,
       CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM (
    SELECT COUNT(*) AS missing_count
    FROM (
        SELECT DISTINCT ZIP_CODE FROM CICD_DEMO.<% schema %>.PROPERTY
        MINUS
        SELECT ZIP_CODE FROM CICD_DEMO.<% schema %>.PROPERTY_STATUS_BY_ZIP
    )
);

-- Test 7: Dynamic table totals equal number of properties
SELECT 'dt_total_matches_property_count' AS TEST_NAME,
       CASE WHEN dt_total = prop_count THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM (
    SELECT
        (SELECT SUM(TOTAL_PROPERTIES) FROM CICD_DEMO.<% schema %>.PROPERTY_STATUS_BY_ZIP) AS dt_total,
        (SELECT COUNT(*) FROM CICD_DEMO.<% schema %>.PROPERTY) AS prop_count
);

-- Test 8: Make sure we have only one "Merged" property event
SELECT 'only_one_merged_event' AS TEST_NAME,
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM CICD_DEMO.<% schema %>.PROPERTY_EVENT
WHERE EVENT_TYPE = 'MERGED';
