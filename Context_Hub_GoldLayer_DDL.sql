-- ==============================================================================
-- Layer: Gold (Aggregated & Denormalized for BI / Analytics)
-- Architecture: Snowflake Dynamic Tables
-- Standard: ACORD Information Model (PartyProfile, PerformanceSnapshots)
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS GOLD;

-- ------------------------------------------------------------------------------
-- 1. DIM_CUSTOMER_360
-- Target Lag: 1 Hour (Refreshes hourly as Silver data updates)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.DIM_CUSTOMER_360
  TARGET_LAG = '1 hour'
  WAREHOUSE = COMPUTE_WH
  COMMENT = 'A denormalized, comprehensive view of a customer joining core identity, location, and contact methods.'
AS
SELECT 
    p.PARTY_SK AS CUSTOMER_SK,
    COALESCE(p.FIRST_NAME || ' ' || p.LAST_NAME, 'UNKNOWN') AS FULL_NAME,
    p.CLIENT_CATEGORY_CD,
    TRUNC(DATEDIFF(YEAR, p.BIRTH_DT, CURRENT_DATE())) AS AGE,
    l.TERRITORY_NAME AS PRIMARY_TERRITORY,
    c.COMMUNICATION_TYPE_CD AS PRIMARY_CONTACT_METHOD,
    c.COMMUNICATION_VALUE_TXT AS PRIMARY_CONTACT_VALUE,
    COALESCE(SUM(f.TRANSACTION_AMT), 0) AS CUSTOMER_LIFETIME_VALUE
FROM SILVER.DIM_PARTY p
LEFT JOIN SILVER.DIM_LOCATION l 
    ON p.SOURCE_RECORD_ID = l.SOURCE_RECORD_ID 
    AND p.SOURCE_SYSTEM = l.SOURCE_SYSTEM
LEFT JOIN SILVER.DIM_COMMUNICATION c 
    ON p.PARTY_SK = c.PARTY_SK 
    AND c.PRIMARY_IND = TRUE
LEFT JOIN SILVER.FACT_FINANCIAL_TX f 
    ON p.PARTY_SK = f.PAYING_PARTY_SK
    AND f.TRANSACTION_STATUS_CD = 'Settled'
WHERE p.PARTY_TYPE_CD = 'Insured'
GROUP BY 
    p.PARTY_SK, 
    p.FIRST_NAME, 
    p.LAST_NAME, 
    p.CLIENT_CATEGORY_CD, 
    p.BIRTH_DT, 
    l.TERRITORY_NAME, 
    c.COMMUNICATION_TYPE_CD, 
    c.COMMUNICATION_VALUE_TXT;

-- ------------------------------------------------------------------------------
-- 2. FACT_POLICY_PREMIUM_METRICS
-- Target Lag: 1 Day (Daily batch snapshot for executive dashboards)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.FACT_POLICY_PREMIUM_METRICS
  TARGET_LAG = '1 day'
  WAREHOUSE = COMPUTE_WH
  COMMENT = 'Aggregated daily snapshot of active policies, Gross Written Premium (GWP), and product performance.'
AS
SELECT 
    CURRENT_DATE() AS SNAPSHOT_DATE,
    prod.LOB_CD,
    prod.PRODUCT_NAME,
    COUNT(DISTINCT a.AGREEMENT_SK) AS ACTIVE_POLICY_COUNT,
    SUM(a.CURRENT_TERM_AMT) AS GROSS_WRITTEN_PREMIUM,
    COUNT(DISTINCT CASE WHEN a.EFFECTIVE_DT = CURRENT_DATE() THEN a.AGREEMENT_SK ELSE NULL END) AS NEW_POLICIES_WRITTEN
FROM SILVER.FACT_AGREEMENT a
JOIN SILVER.DIM_INSURANCE_PRODUCT prod 
    ON a.PRODUCT_SK = prod.PRODUCT_SK
WHERE a.AGREEMENT_STATUS_CD = 'Active'
  AND a.EFFECTIVE_DT <= CURRENT_DATE()
  AND a.EXPIRATION_DT >= CURRENT_DATE()
GROUP BY 
    prod.LOB_CD,
    prod.PRODUCT_NAME;

-- ------------------------------------------------------------------------------
-- 3. FACT_LOSS_PERFORMANCE
-- Target Lag: 1 Hour (Refreshes hourly for claims operations monitoring)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.FACT_LOSS_PERFORMANCE
  TARGET_LAG = '1 hour'
  WAREHOUSE = COMPUTE_WH
  COMMENT = 'Denormalized claims analytical table providing insights into claim severity, frequency, and settlement speed.'
AS
SELECT 
    l.LOSS_EVENT_SK,
    prod.LOB_CD,
    l.LOSS_TYPE_CD,
    l.CLAIM_STATUS_CD,
    DATEDIFF(DAY, l.LOSS_DT, l.REPORTED_DT) AS DAYS_TO_REPORT,
    DATEDIFF(DAY, l.REPORTED_DT, l.SETTLEMENT_DT) AS DAYS_TO_SETTLE,
    l.PAID_TOTAL_AMT AS SETTLED_AMOUNT,
    CASE 
        WHEN a.CURRENT_TERM_AMT > 0 THEN (l.PAID_TOTAL_AMT / a.CURRENT_TERM_AMT) 
        ELSE 0 
    END AS CLAIM_SEVERITY_RATIO
FROM SILVER.FACT_LOSS_EVENT l
JOIN SILVER.FACT_AGREEMENT a 
    ON l.AGREEMENT_SK = a.AGREEMENT_SK
JOIN SILVER.DIM_INSURANCE_PRODUCT prod 
    ON a.PRODUCT_SK = prod.PRODUCT_SK;