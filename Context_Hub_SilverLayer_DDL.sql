-- ==============================================================================
-- Layer: Silver (Conformed Enterprise View)
-- Architecture: Persistent Tables for Stream/Task Orchestration
-- Standard: ACORD Information Model (Party, Location, Product, Agreement, Loss)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. DIM_PARTY (ACORD Concept: Party)
-- Merges: System A (CUSTOMER, STAFF) and System B (client.csv, employee.csv)
-- ------------------------------------------------------------------------------
CREATE TABLE SILVER.DIM_PARTY (
    PARTY_SK VARCHAR(64) NOT NULL,
    SOURCE_SYSTEM VARCHAR(50) NOT NULL,
    SOURCE_RECORD_ID VARCHAR(50) NOT NULL,
    PARTY_TYPE_CD VARCHAR(20) NOT NULL, 
    FIRST_NAME VARCHAR(100),
    LAST_NAME VARCHAR(100),
    BIRTH_DT DATE,
    GENDER_CD CHAR(2),
    MARITAL_STATUS_CD VARCHAR(20),
    EMPLOYMENT_START_DT DATE,
    BASE_COMPENSATION_AMT NUMBER(18,2),
    CLIENT_CATEGORY_CD VARCHAR(50), 
    DISCOUNT_PCT NUMBER(5,2),
    RECORD_HASH VARCHAR(64) NOT NULL, 
    SYS_CREATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SYS_UPDATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (PARTY_SK)
);

COMMENT ON TABLE SILVER.DIM_PARTY IS 'ACORD Party entity representing any person or organization interacting with the insurer, encompassing customers, employees, and applicants.';
COMMENT ON COLUMN SILVER.DIM_PARTY.PARTY_SK IS 'Deterministic surrogate key generated via HASH(SOURCE_SYSTEM, SOURCE_RECORD_ID).';
COMMENT ON COLUMN SILVER.DIM_PARTY.SOURCE_SYSTEM IS 'Originating system of record (e.g., SYSTEM_A_ICEBERG, SYSTEM_B_CSV).';
COMMENT ON COLUMN SILVER.DIM_PARTY.SOURCE_RECORD_ID IS 'The original primary key from the source system (e.g., Cust_Id, client_id, employee_id).';
COMMENT ON COLUMN SILVER.DIM_PARTY.PARTY_TYPE_CD IS 'Categorization of the party role in the enterprise (e.g., Insured, Applicant, Employee, Producer).';
COMMENT ON COLUMN SILVER.DIM_PARTY.FIRST_NAME IS 'Legal first name of the party.';
COMMENT ON COLUMN SILVER.DIM_PARTY.LAST_NAME IS 'Legal last name of the party.';
COMMENT ON COLUMN SILVER.DIM_PARTY.BIRTH_DT IS 'Date of birth for individual parties.';
COMMENT ON COLUMN SILVER.DIM_PARTY.GENDER_CD IS 'Standardized gender code (e.g., M, F, U).';
COMMENT ON COLUMN SILVER.DIM_PARTY.MARITAL_STATUS_CD IS 'Standardized marital status (e.g., Single, Married).';
COMMENT ON COLUMN SILVER.DIM_PARTY.EMPLOYMENT_START_DT IS 'Date of hire for internal employees/producers; NULL for customers.';
COMMENT ON COLUMN SILVER.DIM_PARTY.BASE_COMPENSATION_AMT IS 'Base salary or allowance amount for employees/producers; NULL for customers.';
COMMENT ON COLUMN SILVER.DIM_PARTY.CLIENT_CATEGORY_CD IS 'Retail or commercial classification (mapped from System B clientType).';
COMMENT ON COLUMN SILVER.DIM_PARTY.DISCOUNT_PCT IS 'Applicable enterprise discount percentage granted to the party.';
COMMENT ON COLUMN SILVER.DIM_PARTY.RECORD_HASH IS 'MD5/SHA256 hash of all non-metadata columns to efficiently detect CDC updates during Task MERGE operations.';
COMMENT ON COLUMN SILVER.DIM_PARTY.SYS_CREATED_TS IS 'Timestamp when the record was initially ingested into the Silver layer.';
COMMENT ON COLUMN SILVER.DIM_PARTY.SYS_UPDATED_TS IS 'Timestamp when the record was last modified by the continuous pipeline.';

-- ------------------------------------------------------------------------------
-- 2. DIM_LOCATION (ACORD Concept: Addr / Location)
-- Merges: System A (Cust_Address) and System B (region.csv, houseNr.csv, etc.)
-- ------------------------------------------------------------------------------
CREATE TABLE SILVER.DIM_LOCATION (
    LOCATION_SK VARCHAR(64) NOT NULL,
    SOURCE_SYSTEM VARCHAR(50) NOT NULL,
    SOURCE_RECORD_ID VARCHAR(50) NOT NULL,
    TERRITORY_NAME VARCHAR(100), 
    CITY_NAME VARCHAR(100),
    STREET_NAME VARCHAR(150),
    HOUSE_NUMBER VARCHAR(20),
    FORMATTED_ADDRESS_TXT VARCHAR(255),
    RECORD_HASH VARCHAR(64) NOT NULL,
    SYS_CREATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SYS_UPDATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (LOCATION_SK)
);

COMMENT ON TABLE SILVER.DIM_LOCATION IS 'ACORD Location/Addr aggregate used to standardize postal addresses and geographic territories across the enterprise.';
COMMENT ON COLUMN SILVER.DIM_LOCATION.LOCATION_SK IS 'Deterministic surrogate key for the location.';
COMMENT ON COLUMN SILVER.DIM_LOCATION.SOURCE_SYSTEM IS 'Originating system of record.';
COMMENT ON COLUMN SILVER.DIM_LOCATION.SOURCE_RECORD_ID IS 'The original composite or primary key for the location from the source.';
COMMENT ON COLUMN SILVER.DIM_LOCATION.TERRITORY_NAME IS 'Standardized region, state, or province (e.g., Greater Poland / Wielkopolskie).';
COMMENT ON COLUMN SILVER.DIM_LOCATION.CITY_NAME IS 'Name of the city or municipality.';
COMMENT ON COLUMN SILVER.DIM_LOCATION.STREET_NAME IS 'Name of the street or thoroughfare.';
COMMENT ON COLUMN SILVER.DIM_LOCATION.HOUSE_NUMBER IS 'Specific house, building, or apartment number.';
COMMENT ON COLUMN SILVER.DIM_LOCATION.FORMATTED_ADDRESS_TXT IS 'Fully concatenated address string for systems lacking normalized geographic hierarchies (e.g., System A).';
COMMENT ON COLUMN SILVER.DIM_LOCATION.RECORD_HASH IS 'Hash of location attributes for CDC.';
COMMENT ON COLUMN SILVER.DIM_LOCATION.SYS_CREATED_TS IS 'Timestamp of record creation.';
COMMENT ON COLUMN SILVER.DIM_LOCATION.SYS_UPDATED_TS IS 'Timestamp of last record update.';

-- ------------------------------------------------------------------------------
-- 3. DIM_COMMUNICATION (ACORD Concept: Communication)
-- Merges: System A (Cust_MOB_Number, Cust_Email) and System B (phone.csv, phoneType.csv)
-- ------------------------------------------------------------------------------
CREATE TABLE SILVER.DIM_COMMUNICATION (
    COMMUNICATION_SK VARCHAR(64) NOT NULL,
    PARTY_SK VARCHAR(64) NOT NULL,
    SOURCE_SYSTEM VARCHAR(50) NOT NULL,
    COMMUNICATION_USE_CD VARCHAR(20), 
    COMMUNICATION_TYPE_CD VARCHAR(20), 
    COMMUNICATION_VALUE_TXT VARCHAR(255) NOT NULL,
    PRIMARY_IND BOOLEAN DEFAULT TRUE,
    RECORD_HASH VARCHAR(64) NOT NULL,
    SYS_CREATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SYS_UPDATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (COMMUNICATION_SK),
    FOREIGN KEY (PARTY_SK) REFERENCES SILVER.DIM_PARTY(PARTY_SK)
);

COMMENT ON TABLE SILVER.DIM_COMMUNICATION IS 'ACORD Communication aggregate standardizing all methods of contact (phone, email, fax) linked to a specific Party.';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.COMMUNICATION_SK IS 'Deterministic surrogate key for the contact method.';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.PARTY_SK IS 'Foreign key linking the contact method to the respective Party.';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.SOURCE_SYSTEM IS 'Originating system of record.';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.COMMUNICATION_USE_CD IS 'Context of the communication method (e.g., Personal, Business).';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.COMMUNICATION_TYPE_CD IS 'Standardized classification (e.g., Mobile, Email, Landline), translating localized terms like komórkowy.';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.COMMUNICATION_VALUE_TXT IS 'The actual phone number, email address, or URI string.';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.PRIMARY_IND IS 'Boolean flag indicating if this is the preferred method of contact for the Party.';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.RECORD_HASH IS 'Hash of communication attributes for CDC.';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.SYS_CREATED_TS IS 'Timestamp of record creation.';
COMMENT ON COLUMN SILVER.DIM_COMMUNICATION.SYS_UPDATED_TS IS 'Timestamp of last record update.';

-- ------------------------------------------------------------------------------
-- 4. DIM_INSURANCE_PRODUCT (ACORD Concept: CoverageAvailable / Product)
-- Merges: System A (PRODUCT, COVERAGE) and System B (insuranceType.csv)
-- ------------------------------------------------------------------------------
CREATE TABLE SILVER.DIM_INSURANCE_PRODUCT (
    PRODUCT_SK VARCHAR(64) NOT NULL,
    SOURCE_SYSTEM VARCHAR(50) NOT NULL,
    SOURCE_RECORD_ID VARCHAR(50) NOT NULL,
    LOB_CD VARCHAR(50), 
    PRODUCT_CD VARCHAR(50),
    PRODUCT_NAME VARCHAR(100),
    COVERAGE_LEVEL_CD VARCHAR(50),
    BASE_PREMIUM_AMT NUMBER(18,2),
    TERMS_DESC VARCHAR(255),
    RECORD_HASH VARCHAR(64) NOT NULL,
    SYS_CREATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SYS_UPDATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (PRODUCT_SK)
);

COMMENT ON TABLE SILVER.DIM_INSURANCE_PRODUCT IS 'ACORD definition for coverage appetite and standardized insurance products available for binding.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.PRODUCT_SK IS 'Deterministic surrogate key for the insurance product.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.SOURCE_SYSTEM IS 'Originating system of record.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.SOURCE_RECORD_ID IS 'The original product ID or type code from the source.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.LOB_CD IS 'Line of Business classification (e.g., Auto, Home, Commercial, House).';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.PRODUCT_CD IS 'Internal alphanumeric product code or SKU.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.PRODUCT_NAME IS 'Market-facing name of the insurance product.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.COVERAGE_LEVEL_CD IS 'Tier of coverage offered (e.g., Comprehensive, Basic, Third-Party).';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.BASE_PREMIUM_AMT IS 'Standard baseline price before individual risk adjustments.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.TERMS_DESC IS 'Textual description of the standard terms and conditions.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.RECORD_HASH IS 'Hash of product attributes for CDC.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.SYS_CREATED_TS IS 'Timestamp of record creation.';
COMMENT ON COLUMN SILVER.DIM_INSURANCE_PRODUCT.SYS_UPDATED_TS IS 'Timestamp of last record update.';

-- ------------------------------------------------------------------------------
-- 5. FACT_AGREEMENT (ACORD Concept: Policy / Agreement)
-- Merges: System A (INSURANCE_POLICY, APPLICATION) and System B (insurance.csv)
-- ------------------------------------------------------------------------------
CREATE TABLE SILVER.FACT_AGREEMENT (
    AGREEMENT_SK VARCHAR(64) NOT NULL,
    INSURED_PARTY_SK VARCHAR(64) NOT NULL,
    PRODUCER_PARTY_SK VARCHAR(64), 
    PRODUCT_SK VARCHAR(64) NOT NULL,
    SOURCE_SYSTEM VARCHAR(50) NOT NULL,
    AGREEMENT_NUM VARCHAR(100) NOT NULL,
    AGREEMENT_STATUS_CD VARCHAR(20), 
    EFFECTIVE_DT DATE NOT NULL,
    EXPIRATION_DT DATE NOT NULL,
    CURRENT_TERM_AMT NUMBER(18,2), 
    RECORD_HASH VARCHAR(64) NOT NULL,
    SYS_CREATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SYS_UPDATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (AGREEMENT_SK),
    FOREIGN KEY (INSURED_PARTY_SK) REFERENCES SILVER.DIM_PARTY(PARTY_SK),
    FOREIGN KEY (PRODUCER_PARTY_SK) REFERENCES SILVER.DIM_PARTY(PARTY_SK),
    FOREIGN KEY (PRODUCT_SK) REFERENCES SILVER.DIM_INSURANCE_PRODUCT(PRODUCT_SK)
);

COMMENT ON TABLE SILVER.FACT_AGREEMENT IS 'ACORD Policy aggregate defining the details, status, and lifecycle of a binding legal insurance contract.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.AGREEMENT_SK IS 'Deterministic surrogate key for the policy agreement.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.INSURED_PARTY_SK IS 'Foreign key pointing to the primary customer/insured party.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.PRODUCER_PARTY_SK IS 'Foreign key pointing to the agent/employee responsible for the sale.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.PRODUCT_SK IS 'Foreign key pointing to the insurance product governing the agreement.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.SOURCE_SYSTEM IS 'Originating system of record.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.AGREEMENT_NUM IS 'Official policy number issued to the customer.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.AGREEMENT_STATUS_CD IS 'Current lifecycle state of the policy (e.g., Pending, Active, Expired, Canceled).';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.EFFECTIVE_DT IS 'The date and time the insurance coverage officially begins.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.EXPIRATION_DT IS 'The date and time the insurance coverage ends.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.CURRENT_TERM_AMT IS 'ACORD CurrentTermAmt representing the total gross premium for the active term.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.RECORD_HASH IS 'Hash of agreement attributes for CDC.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.SYS_CREATED_TS IS 'Timestamp of record creation.';
COMMENT ON COLUMN SILVER.FACT_AGREEMENT.SYS_UPDATED_TS IS 'Timestamp of last record update.';

-- ------------------------------------------------------------------------------
-- 6. FACT_FINANCIAL_TX (ACORD Concept: Payment / CurrentTermAmt)
-- Merges: System A (PREMIUM_PAYMENT, RECEIPT) and System B (payment.csv)
-- ------------------------------------------------------------------------------
CREATE TABLE SILVER.FACT_FINANCIAL_TX (
    TRANSACTION_SK VARCHAR(64) NOT NULL,
    AGREEMENT_SK VARCHAR(64) NOT NULL,
    PAYING_PARTY_SK VARCHAR(64) NOT NULL,
    SOURCE_SYSTEM VARCHAR(50) NOT NULL,
    SOURCE_RECORD_ID VARCHAR(50) NOT NULL,
    TRANSACTION_DT DATE NOT NULL,
    TRANSACTION_AMT NUMBER(18,2) NOT NULL,
    PAYMENT_METHOD_CD VARCHAR(50), 
    TRANSACTION_STATUS_CD VARCHAR(20),
    RECORD_HASH VARCHAR(64) NOT NULL,
    SYS_CREATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SYS_UPDATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (TRANSACTION_SK),
    FOREIGN KEY (AGREEMENT_SK) REFERENCES SILVER.FACT_AGREEMENT(AGREEMENT_SK),
    FOREIGN KEY (PAYING_PARTY_SK) REFERENCES SILVER.DIM_PARTY(PARTY_SK)
);

COMMENT ON TABLE SILVER.FACT_FINANCIAL_TX IS 'Standardized ledger of all financial events, tracking premium remittances and payment execution states.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.TRANSACTION_SK IS 'Deterministic surrogate key for the financial transaction.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.AGREEMENT_SK IS 'Foreign key linking the transaction to a specific policy agreement.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.PAYING_PARTY_SK IS 'Foreign key linking the transaction to the remitting party/customer.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.SOURCE_SYSTEM IS 'Originating system of record.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.SOURCE_RECORD_ID IS 'The original receipt or payment ID from the source.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.TRANSACTION_DT IS 'The operational date the transaction was processed.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.TRANSACTION_AMT IS 'The monetary value of the processed transaction.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.PAYMENT_METHOD_CD IS 'The vehicle of transaction (e.g., Cash, Credit, EFT).';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.TRANSACTION_STATUS_CD IS 'Current state of the funds (e.g., Settled, Pending, Failed).';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.RECORD_HASH IS 'Hash of transaction attributes for CDC.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.SYS_CREATED_TS IS 'Timestamp of record creation.';
COMMENT ON COLUMN SILVER.FACT_FINANCIAL_TX.SYS_UPDATED_TS IS 'Timestamp of last record update.';

-- ------------------------------------------------------------------------------
-- 7. FACT_LOSS_EVENT (ACORD Concept: Claim / Loss)
-- Merges: System A (CLAIM, CLAIM_SETTLEMENT, INCIDENT)
-- ------------------------------------------------------------------------------
CREATE TABLE SILVER.FACT_LOSS_EVENT (
    LOSS_EVENT_SK VARCHAR(64) NOT NULL,
    AGREEMENT_SK VARCHAR(64) NOT NULL,
    CLAIMANT_PARTY_SK VARCHAR(64) NOT NULL,
    SOURCE_SYSTEM VARCHAR(50) NOT NULL,
    SOURCE_CLAIM_ID VARCHAR(50) NOT NULL,
    LOSS_DT DATE NOT NULL,
    REPORTED_DT DATE NOT NULL,
    LOSS_TYPE_CD VARCHAR(50), 
    CLAIM_STATUS_CD VARCHAR(20),
    INCURRED_AMT NUMBER(18,2), 
    PAID_TOTAL_AMT NUMBER(18,2), 
    SETTLEMENT_DT DATE,
    RECORD_HASH VARCHAR(64) NOT NULL,
    SYS_CREATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SYS_UPDATED_TS TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (LOSS_EVENT_SK),
    FOREIGN KEY (AGREEMENT_SK) REFERENCES SILVER.FACT_AGREEMENT(AGREEMENT_SK),
    FOREIGN KEY (CLAIMANT_PARTY_SK) REFERENCES SILVER.DIM_PARTY(PARTY_SK)
);

COMMENT ON TABLE SILVER.FACT_LOSS_EVENT IS 'ACORD Loss aggregate containing information regarding the background, status, and financial resolution of a filed claim.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.LOSS_EVENT_SK IS 'Deterministic surrogate key for the loss event/claim.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.AGREEMENT_SK IS 'Foreign key linking the claim to the active policy agreement.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.CLAIMANT_PARTY_SK IS 'Foreign key pointing to the party reporting the loss.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.SOURCE_SYSTEM IS 'Originating system of record.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.SOURCE_CLAIM_ID IS 'The original incident or claim ID assigned by the source.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.LOSS_DT IS 'The exact date the hazard/incident occurred.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.REPORTED_DT IS 'The date the claim was officially filed with the insurer.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.LOSS_TYPE_CD IS 'ACORD Hazard/Damage classification (e.g., Collision, Theft, Fire).';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.CLAIM_STATUS_CD IS 'Current state of adjudication (e.g., Approved, Pending, Rejected, Settled).';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.INCURRED_AMT IS 'Initial estimated or requested payout amount by the claimant.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.PAID_TOTAL_AMT IS 'Final settled monetary amount disbursed by the insurer.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.SETTLEMENT_DT IS 'The date the claim was financially resolved and closed.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.RECORD_HASH IS 'Hash of loss event attributes for CDC.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.SYS_CREATED_TS IS 'Timestamp of record creation.';
COMMENT ON COLUMN SILVER.FACT_LOSS_EVENT.SYS_UPDATED_TS IS 'Timestamp of last record update.';