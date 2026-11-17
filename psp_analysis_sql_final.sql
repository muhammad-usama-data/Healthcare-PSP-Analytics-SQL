-- =========================================================================
-- PROJECT:      Healthcare Patient Support Program (PSP) Analytics - Project 1
-- TOOL:         MySQL Workbench (MySQL 8.x)
-- DATABASE:     psp_sql_project
-- AUTHOR:       Muhammad Usama
-- DATA:         Synthetic PSP dataset (practice data, not real patients)
-- SOURCE:       PSP-Analysis-Cleaned 4.xlsx (cleaned in Excel, imported as CSV)
-- PURPOSE:      Data integrity checks and operational analysis of patient
--               enrolment, follow-up engagement, adherence, therapy and
--               adverse event (AE) reporting. Ends with views for Power BI.
--
-- TABLES (one row represents):
--   patients_clean   one patient
--   therapy_clean    one patient's therapy record
--   hospitals_clean  one doctor
--   ae_clean         one adverse event
--   followups_clean  one follow-up call
--
-- DATA NOTES (from the source workbook, used as reference values below):
--   * 1,000 patients, 1,000 therapy records, 40 doctors, 150 AE records,
--     3,999 follow-up records.
--   * adherence_percent: 3,870 recorded, 129 blank. Values outside 0-100
--     were cleared in Excel and kept in adherence_original (4 rows).
--   * satisfaction_score: 3,887 recorded, 112 blank.
--   * A blank means unknown. It is never treated as 0.
--   * 760 of the 781 Not Reached calls still carry an adherence value.
--     That is a logical oddity to flag before the data is used in reporting.
--
-- RUNNING THIS SCRIPT: it is read-only except Section 7, which creates
-- views (saved queries, no data is copied or changed). Run one query at a
-- time (place the cursor inside it, then use the lightning bolt with the
-- cursor icon).
-- =========================================================================

USE psp_sql_project;


-- =========================================================================
-- SECTION 1: DATABASE & SCHEMA INITIALISATION
-- =========================================================================

-- 1.1 Confirm the working database and the tables in it
SELECT DATABASE() AS current_database;

SHOW TABLES;


-- 1.2 Inspect column names and data types
-- Why: the data type decides how a column behaves. A number stored as TEXT
-- cannot be averaged reliably and sorts like words, not numbers.
DESCRIBE patients_clean;
DESCRIBE therapy_clean;
DESCRIBE hospitals_clean;
DESCRIBE ae_clean;
DESCRIBE followups_clean;


-- 1.3 One-time fix: hidden character in the first column name
-- The CSV files were saved as "CSV UTF-8", which adds an invisible marker
-- at the start of the file. The import wizard read it as part of the first
-- column name, so the columns arrived as ï»¿patient_id, ï»¿doctor_id and
-- ï»¿ae_id. The three statements below were already run once.
-- Leave them commented out: running them again returns an
-- "unknown column" error because the old name no longer exists.
-- Tip for future exports: save as plain "CSV (Comma delimited)".

-- ALTER TABLE therapy_clean
--     CHANGE COLUMN `ï»¿patient_id` `patient_id` TEXT;

-- ALTER TABLE hospitals_clean
--     CHANGE COLUMN `ï»¿doctor_id` `doctor_id` TEXT;

-- ALTER TABLE ae_clean
--     CHANGE COLUMN `ï»¿ae_id` `ae_id` TEXT;


-- 1.4 Data type and blank-value check on the follow-ups table
-- adherence_percent, satisfaction_score and missed_doses need to be numeric,
-- with blank cells stored as NULL. If blanks are stored as text or zero,
-- COUNT() treats them as values and AVG() treats them as 0.
-- Expected: 3999 rows, 129 NULL adherence, 0 zero adherence,
-- 112 NULL satisfaction, 132 NULL missed doses.
SELECT
    COUNT(*)                          AS total_rows,
    SUM(adherence_percent IS NULL)    AS null_adherence,
    SUM(adherence_percent = 0)        AS zero_adherence,
    SUM(satisfaction_score IS NULL)   AS null_satisfaction,
    SUM(missed_doses IS NULL)         AS null_missed_doses
FROM followups_clean;


-- =========================================================================
-- SECTION 2: DATA INTEGRITY & AUDIT TRAIL
-- =========================================================================

-- 2.1 Row count of the follow-ups table
-- Audit Check: the source workbook has 3,999 follow-up rows. Any other
-- number means rows were lost or duplicated during import.
SELECT
    COUNT(*) AS total_rows
FROM followups_clean;


-- 2.2 Valid versus missing values in the numeric fields
-- Audit Check: how many usable entries exist for adherence, missed doses
-- and satisfaction.
-- Expected: 3,999 rows; adherence 3,870 valid / 129 missing;
-- missed doses 3,867 valid / 132 missing; satisfaction 3,887 valid / 112 missing.
SELECT
    COUNT(*)                                          AS total_rows,
    COUNT(adherence_percent)                          AS valid_adherence_count,
    COUNT(*) - COUNT(adherence_percent)               AS null_adherence_count,
    COUNT(missed_doses)                               AS valid_missed_doses_count,
    COUNT(*) - COUNT(missed_doses)                    AS null_missed_doses_count,
    COUNT(satisfaction_score)                         AS valid_satisfaction_count,
    COUNT(*) - COUNT(satisfaction_score)              AS null_satisfaction_count
FROM followups_clean;


-- 2.3 Missing values in the key numeric fields (IS NULL version)
-- Same check as 2.2, written with IS NULL. Expected: 129 / 132 / 112.
SELECT
    COUNT(*)                          AS total_records,
    SUM(adherence_percent IS NULL)    AS missing_adherence,
    SUM(missed_doses IS NULL)         AS missing_missed_doses,
    SUM(satisfaction_score IS NULL)   AS missing_satisfaction
FROM followups_clean;


-- 2.4 Range check: adherence must sit between 0 and 100
-- Audit Check: out-of-range values were cleared in Excel (kept in
-- adherence_original), so 0 is expected.
SELECT
    COUNT(*) AS invalid_adherence_records
FROM followups_clean
WHERE adherence_percent < 0
   OR adherence_percent > 100;


-- 2.5 Range check: satisfaction must sit between 1 and 5
-- Audit Check: expect 0.
SELECT
    COUNT(*) AS invalid_satisfaction_records
FROM followups_clean
WHERE satisfaction_score < 1
   OR satisfaction_score > 5;


-- 2.6 Range check: missed doses cannot be negative
SELECT
    COUNT(*) AS negative_missed_dose_records
FROM followups_clean
WHERE missed_doses < 0;


-- 2.7 Contact status categories
-- Audit Check: only the expected categories (Reached, Not Reached) should
-- appear, with no spelling variants.
SELECT
    contact_status,
    COUNT(*) AS record_count
FROM followups_clean
GROUP BY contact_status
ORDER BY record_count DESC;


-- 2.8 Duplicate follow-up IDs
-- Audit Check: each follow-up call should have its own ID (expect 0 rows).
SELECT
    followup_id,
    COUNT(*) AS number_of_records
FROM followups_clean
GROUP BY followup_id
HAVING COUNT(*) > 1;


-- 2.9 Missing or blank follow-up IDs
SELECT
    COUNT(*) AS missing_followup_ids
FROM followups_clean
WHERE followup_id IS NULL
   OR TRIM(followup_id) = '';


-- 2.10 Duplicate patient IDs
-- Audit Check: one row per patient, so no ID should repeat (expect 0 rows).
SELECT
    patient_id,
    COUNT(*) AS number_of_records
FROM patients_clean
GROUP BY patient_id
HAVING COUNT(*) > 1;


-- 2.11 Therapy records versus distinct patients
-- Audit Check: in this dataset each patient has exactly one therapy record,
-- so the two counts should be equal.
SELECT
    COUNT(*)                     AS total_therapy_records,
    COUNT(patient_id)            AS records_with_patient_id,
    COUNT(DISTINCT patient_id)   AS distinct_patient_ids
FROM therapy_clean;


-- 2.12 Duplicate therapy records (checked on source_row)
SELECT
    source_row,
    COUNT(*) AS number_of_records
FROM therapy_clean
GROUP BY source_row
HAVING COUNT(*) > 1;


-- 2.13 Orphan check: follow-ups with no matching patient
-- Audit Check: expect 0 rows.
SELECT
    f.followup_id,
    f.patient_id
FROM followups_clean AS f
LEFT JOIN patients_clean AS p
    ON f.patient_id = p.patient_id
WHERE p.patient_id IS NULL;


-- 2.14 Orphan check: therapy records with no matching patient
-- Audit Check: expect 0 rows.
SELECT
    t.patient_id,
    t.drug_name,
    t.source_row
FROM therapy_clean AS t
LEFT JOIN patients_clean AS p
    ON t.patient_id = p.patient_id
WHERE p.patient_id IS NULL;


-- 2.15 Orphan check: adverse events with no matching patient
-- Audit Check: expect 0 rows.
SELECT
    a.patient_id,
    COUNT(*) AS number_of_records
FROM ae_clean AS a
LEFT JOIN patients_clean AS p
    ON a.patient_id = p.patient_id
WHERE p.patient_id IS NULL
GROUP BY a.patient_id;


-- 2.16 Coverage check: patients with no follow-up recorded
-- Business Context: every patient should have at least one follow-up
-- (expect 0 rows).
SELECT
    p.patient_id
FROM patients_clean AS p
LEFT JOIN followups_clean AS f
    ON p.patient_id = f.patient_id
WHERE f.followup_id IS NULL;


-- 2.17 Join sanity check: follow-ups that match a patient
-- Audit Check: this should equal the follow-up row count in 2.1. If it is
-- higher, the join is multiplying rows (for example from duplicate IDs).
SELECT
    COUNT(*) AS matched_followup_records
FROM patients_clean AS p
INNER JOIN followups_clean AS f
    ON p.patient_id = f.patient_id;


-- 2.18 Join preview: patient details next to their follow-ups
SELECT
    p.patient_id,
    p.age,
    p.city,
    f.followup_id,
    f.contact_status,
    f.adherence_percent
FROM patients_clean AS p
INNER JOIN followups_clean AS f
    ON p.patient_id = f.patient_id
LIMIT 10;


-- =========================================================================
-- SECTION 3: PROGRAM & PATIENT DEMOGRAPHICS
-- =========================================================================

-- 3.1 Monthly enrolment trend
-- Business Context: shows how patient intake moved month to month.
-- Note: months sort in calendar order only if enrolment_month is a DATE
-- column. Check its type with DESCRIBE patients_clean.
SELECT
    enrolment_month,
    COUNT(*) AS total_patients
FROM patients_clean
GROUP BY enrolment_month
ORDER BY enrolment_month ASC;


-- 3.2 Patients by city
-- Workbook reference: Karachi 239, Lahore 210, Peshawar 120, Islamabad 107,
-- Rawalpindi 105, Faisalabad 96, Multan 66, Quetta 57.
SELECT
    city,
    COUNT(*) AS patient_count
FROM patients_clean
GROUP BY city
ORDER BY patient_count DESC;


-- 3.3 Patients by age (single years of age)
-- Note: this groups by exact age, not by age band. Patients with a blank age
-- appear as their own group.
SELECT
    age,
    COUNT(*) AS patient_count
FROM patients_clean
GROUP BY age
ORDER BY age;


-- =========================================================================
-- SECTION 4: OPERATIONAL & CONTACT KPI METRICS
-- =========================================================================

-- 4.1 Core record counts
-- Workbook reference: 1,000 patients, 1,000 therapy records, 3,999 follow-ups,
-- 150 adverse events.
SELECT
    (SELECT COUNT(*) FROM patients_clean)  AS patients_enrolled,
    (SELECT COUNT(*) FROM therapy_clean)   AS therapy_records,
    (SELECT COUNT(*) FROM followups_clean) AS followup_records,
    (SELECT COUNT(*) FROM ae_clean)        AS adverse_event_records;


-- 4.2 Contact status with share of all follow-ups
-- Business Context: reach rate across call attempts. A high Not Reached
-- share means a lot of outreach effort is not turning into a conversation.
SELECT
    contact_status,
    COUNT(*) AS followup_records,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM followups_clean),
        2
    ) AS percentage_of_all_followups
FROM followups_clean
GROUP BY contact_status
ORDER BY followup_records DESC;


-- 4.3 Therapy records by drug
SELECT
    drug_name,
    COUNT(*) AS therapy_records
FROM therapy_clean
GROUP BY drug_name
ORDER BY therapy_records DESC;


-- 4.4 Therapy status
-- Workbook reference: Active 588, Discontinued 213, Completed 199.
SELECT
    status,
    COUNT(*) AS therapy_records
FROM therapy_clean
GROUP BY status
ORDER BY therapy_records DESC;


-- 4.5 Adverse events by PV reporting status
-- Note: reported_to_PV = 'Y' means the dataset records a Y. It is not proof
-- of a regulatory submission, so report it as "AE records marked Y".
-- Workbook reference: Y 132, N 18.
SELECT
    reported_to_PV,
    COUNT(*) AS adverse_event_records
FROM ae_clean
GROUP BY reported_to_PV
ORDER BY adverse_event_records DESC;


-- =========================================================================
-- SECTION 5: CLINICAL & ADHERENCE INSIGHTS
-- =========================================================================

-- 5.1 Average adherence
-- Business Context: the average should be calculated on follow-ups that
-- actually recorded an adherence value. A blank is "unknown", not 0%.
-- Expected: 3,870 valid, 129 missing, average 81.37.
-- This is the mean of recorded measurements, not the percentage of patients
-- who are adherent.
SELECT
    COUNT(adherence_percent)               AS valid_adherence_records,
    COUNT(*) - COUNT(adherence_percent)    AS missing_adherence_records,
    ROUND(AVG(adherence_percent), 2)       AS average_adherence_percent
FROM followups_clean;


-- 5.2 Average satisfaction
-- Scores run from 1 to 5. Expected: 3,887 valid, 112 missing, average 4.00.
SELECT
    COUNT(satisfaction_score)               AS valid_satisfaction_records,
    COUNT(*) - COUNT(satisfaction_score)    AS missing_satisfaction_records,
    ROUND(AVG(satisfaction_score), 2)       AS average_satisfaction
FROM followups_clean;


-- 5.3 Satisfaction score distribution (added while formatting)
-- Business Context: the average hides the spread. Shows how many follow-ups
-- gave each score. Workbook reference: 1 = 14, 2 = 174, 3 = 892, 4 = 1,534,
-- 5 = 1,273, blank = 112.
SELECT
    satisfaction_score,
    COUNT(*) AS followup_records
FROM followups_clean
GROUP BY satisfaction_score
ORDER BY satisfaction_score;


-- 5.4 Missed dose statistics
-- Expected: 3,867 valid values (132 blank), average 1.52, range 0 to 5.
SELECT
    COUNT(missed_doses)           AS valid_records,
    ROUND(AVG(missed_doses), 2)   AS average_missed_doses,
    MIN(missed_doses)             AS minimum_missed_doses,
    MAX(missed_doses)             AS maximum_missed_doses
FROM followups_clean;


-- 5.5 Adherence by contact status
-- Business Context: compares adherence for patients who were reached with
-- those who were not. An adherence value on a Not Reached call is a data
-- oddity (760 such rows in the workbook) and needs a documented decision
-- before it is used in reporting.
SELECT
    contact_status,
    COUNT(adherence_percent)           AS valid_adherence_records,
    ROUND(AVG(adherence_percent), 2)   AS average_adherence_percent
FROM followups_clean
GROUP BY contact_status
ORDER BY average_adherence_percent DESC;


-- 5.6 Satisfaction by contact status
SELECT
    contact_status,
    COUNT(satisfaction_score)           AS valid_satisfaction_records,
    ROUND(AVG(satisfaction_score), 2)   AS average_satisfaction
FROM followups_clean
GROUP BY contact_status
ORDER BY average_satisfaction DESC;


-- =========================================================================
-- SECTION 6: CROSS-TABLE HEALTHCARE ANALYTICS
-- =========================================================================

-- 6.1 Adherence by patient city
-- Business Context: highlights cities where adherence follow-up may need
-- more attention.
-- Grain reminder: followups has several rows per patient, so each city's
-- figure is an average of follow-up measurements, not of patients.
SELECT
    p.city,
    COUNT(f.adherence_percent)           AS valid_adherence_records,
    ROUND(AVG(f.adherence_percent), 2)   AS average_adherence_percent
FROM patients_clean AS p
INNER JOIN followups_clean AS f
    ON p.patient_id = f.patient_id
GROUP BY p.city
ORDER BY average_adherence_percent DESC;


-- 6.2 Satisfaction by patient city
SELECT
    p.city,
    COUNT(f.satisfaction_score)           AS valid_satisfaction_records,
    ROUND(AVG(f.satisfaction_score), 2)   AS average_satisfaction
FROM patients_clean AS p
INNER JOIN followups_clean AS f
    ON p.patient_id = f.patient_id
GROUP BY p.city
ORDER BY average_satisfaction DESC;


-- 6.3 Adverse events by patient city
-- Business Context: where AE records are concentrated. Counts events, not
-- patients (some patients have two events). Cities with more patients will
-- naturally have more events, so this is a count, not a rate.
SELECT
    p.city,
    COUNT(*) AS adverse_event_records
FROM ae_clean AS a
INNER JOIN patients_clean AS p
    ON a.patient_id = p.patient_id
GROUP BY p.city
ORDER BY adverse_event_records DESC;


-- =========================================================================
-- SECTION 7: POWER BI SUMMARY VIEWS
-- =========================================================================
-- A view is a saved query: it stores the instructions, not a copy of the
-- data, and always reflects the current tables. Power BI can connect to
-- these views as if they were tables. ORDER BY is left out on purpose
-- because Power BI sorts in the report.
-- Creating a view is safe and reversible (DROP VIEW name; removes it).
-- Views read the current tables, so they update when the data changes.

-- 7.1 Core record counts
CREATE OR REPLACE VIEW vw_kpi_core_counts AS
SELECT
    (SELECT COUNT(*) FROM patients_clean)  AS patients_enrolled,
    (SELECT COUNT(*) FROM therapy_clean)   AS therapy_records,
    (SELECT COUNT(*) FROM followups_clean) AS followup_records,
    (SELECT COUNT(*) FROM ae_clean)        AS adverse_event_records;


-- 7.2 Adherence summary
CREATE OR REPLACE VIEW vw_kpi_adherence AS
SELECT
    COUNT(adherence_percent)               AS valid_adherence_records,
    COUNT(*) - COUNT(adherence_percent)    AS missing_adherence_records,
    ROUND(AVG(adherence_percent), 2)       AS average_adherence_percent
FROM followups_clean;


-- 7.3 Satisfaction summary
CREATE OR REPLACE VIEW vw_kpi_satisfaction AS
SELECT
    COUNT(satisfaction_score)               AS valid_satisfaction_records,
    COUNT(*) - COUNT(satisfaction_score)    AS missing_satisfaction_records,
    ROUND(AVG(satisfaction_score), 2)       AS average_satisfaction
FROM followups_clean;


-- 7.4 Contact status summary
CREATE OR REPLACE VIEW vw_contact_status_summary AS
SELECT
    contact_status,
    COUNT(*) AS followup_records,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM followups_clean),
        2
    ) AS percentage_of_all_followups
FROM followups_clean
GROUP BY contact_status;


-- 7.5 Adherence and satisfaction by contact status
CREATE OR REPLACE VIEW vw_outcomes_by_contact_status AS
SELECT
    contact_status,
    COUNT(adherence_percent)           AS valid_adherence_records,
    ROUND(AVG(adherence_percent), 2)   AS average_adherence_percent,
    COUNT(satisfaction_score)          AS valid_satisfaction_records,
    ROUND(AVG(satisfaction_score), 2)  AS average_satisfaction
FROM followups_clean
GROUP BY contact_status;


-- 7.6 Monthly enrolment
CREATE OR REPLACE VIEW vw_monthly_enrolment AS
SELECT
    enrolment_month,
    COUNT(*) AS total_patients
FROM patients_clean
GROUP BY enrolment_month;


-- 7.7 Patients by city
CREATE OR REPLACE VIEW vw_patients_by_city AS
SELECT
    city,
    COUNT(*) AS patient_count
FROM patients_clean
GROUP BY city;


-- 7.8 Adherence and satisfaction by city
CREATE OR REPLACE VIEW vw_outcomes_by_city AS
SELECT
    p.city,
    COUNT(f.adherence_percent)           AS valid_adherence_records,
    ROUND(AVG(f.adherence_percent), 2)   AS average_adherence_percent,
    COUNT(f.satisfaction_score)          AS valid_satisfaction_records,
    ROUND(AVG(f.satisfaction_score), 2)  AS average_satisfaction
FROM patients_clean AS p
INNER JOIN followups_clean AS f
    ON p.patient_id = f.patient_id
GROUP BY p.city;


-- 7.9 Therapy by drug and by status
CREATE OR REPLACE VIEW vw_therapy_by_drug AS
SELECT
    drug_name,
    COUNT(*) AS therapy_records
FROM therapy_clean
GROUP BY drug_name;

CREATE OR REPLACE VIEW vw_therapy_by_status AS
SELECT
    status,
    COUNT(*) AS therapy_records
FROM therapy_clean
GROUP BY status;


-- 7.10 Adverse events by PV reporting status and by city
CREATE OR REPLACE VIEW vw_ae_pv_reporting AS
SELECT
    reported_to_PV,
    COUNT(*) AS adverse_event_records
FROM ae_clean
GROUP BY reported_to_PV;

CREATE OR REPLACE VIEW vw_ae_by_city AS
SELECT
    p.city,
    COUNT(*) AS adverse_event_records
FROM ae_clean AS a
INNER JOIN patients_clean AS p
    ON a.patient_id = p.patient_id
GROUP BY p.city;


-- 7.11 Confirm the views exist

SHOW FULL TABLES WHERE Table_type = 'VIEW';


