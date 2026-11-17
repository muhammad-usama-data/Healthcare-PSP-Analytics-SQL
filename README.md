# Healthcare Patient Support Program (PSP) Analytics (MySQL)

## Project Overview
Performed end-to-end data auditing, operational analysis, and Power BI view engineering on a **Healthcare Patient Support Program (PSP)** dataset using **MySQL**. Drawing from real-world experience in **Pharmacovigilance and Patient Support Programs**, this project evaluates patient enrolment, follow-up outreach effectiveness, medication adherence, therapy status, and adverse event (AE) reporting.

*(Disclaimer: This analysis uses an AI-generated synthetic dataset created purely for portfolio and practice purposes. No real patient or proprietary company data is included.)*

## Relational Schema Analyzed
The database (`psp_sql_project`) models a realistic 5-table PSP operational workflow:
* `patients_clean` – 1,000 enrolled patient records (demographics, city, enrolment month).
* `therapy_clean` – 1,000 therapy records tracking prescribed drugs and treatment status.
* `followups_clean` – 3,999 follow-up call logs measuring outreach reach rate, adherence %, missed doses, and satisfaction.
* `ae_clean` – 150 adverse event (AE) records and Pharmacovigilance (PV) reporting flags.
* `hospitals_clean` – 40 prescribing physician/hospital records.

## Key Analytical Highlights & Domain Insights
* **Data Integrity & Clinical Audit:** Validated primary/foreign key relationships across 5 tables (zero orphan records), handled UTF-8 BOM import artifacts, enforced clinical range checks (0–100% adherence, 1–5 satisfaction), and flagged a key operational anomaly where **760 of 781 "Not Reached" calls** still carried recorded adherence values.
* **Program & Therapy Metrics:** Tracked **1,000 patients** across major Pakistani cities—led by **Karachi (239)** and **Lahore (210)**—and evaluated therapy progression (**588 Active**, **213 Discontinued**, **199 Completed**).
* **Clinical Adherence & Satisfaction:** Calculated mean medication adherence (**81.37%** across 3,870 valid records), average missed doses (**1.52**), and patient satisfaction (**4.00 / 5.00**), carefully separating `NULL` (unknown) values from `0` so averages remain clinically accurate.
* **Pharmacovigilance (PV) Tracking:** Audited **150 adverse event records**, identifying **132 records marked for PV reporting (`Y`)** and **18 unmarked (`N`)**, alongside geographic AE distributions.
* **BI-Ready View Layer:** Engineered **12 modular SQL views (`vw_*`)** covering core KPIs, adherence by city/contact status, therapy status, and PV reporting so Power BI can connect directly without duplicating data.

## Tools & SQL Techniques Used
* **MySQL 8.x:** Relational `LEFT`/`INNER JOIN` auditing, `NULL`-safe aggregations (`COUNT` vs `COUNT(*)`), conditional `SUM` checks, `GROUP BY` / `HAVING` duplicate detection, subqueries, and `CREATE OR REPLACE VIEW` modeling.
* **Microsoft Excel:** Initial data cleaning and outlier isolation (`adherence_original`) prior to CSV import.

## Files Included
* `psp_analysis_sql_final.sql` – Complete 7-section SQL script covering schema validation, data integrity audit, demographic/operational KPIs, clinical adherence insights, cross-table analytics, and 12 Power BI summary views.
