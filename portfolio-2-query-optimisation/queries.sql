-- =====================================================
-- CarePoint: Business queries (Portfolio 2)
-- Snapshot date: 2026-10-21
-- =====================================================
\timing on
 
-- Pick a real patient's phone number to search with (as a receptionist would)
SELECT phone AS pphone FROM patients WHERE patient_id = 1234 \gset
\echo 'Searching for patient with phone:' :pphone
 
-- Q1: Full visit history for a patient, searched by phone number
SELECT a.appointment_date, a.start_time, b.name AS branch,
       s.first_name || ' ' || s.last_name AS doctor,
       a.status, d.icd10_code, d.description AS diagnosis
FROM patients p
JOIN appointments a ON a.patient_id = p.patient_id
JOIN staff s        ON s.staff_id   = a.doctor_id
JOIN branches b     ON b.branch_id  = a.branch_id
LEFT JOIN diagnoses d ON d.appointment_id = a.appointment_id
WHERE p.phone = :'pphone'
ORDER BY a.appointment_date DESC, a.start_time DESC;
 
-- Q2: Doctor 5's schedule for tomorrow (active appointments only)
SELECT a.start_time, p.first_name || ' ' || p.last_name AS patient,
       a.reason, a.status
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 5
  AND a.appointment_date = DATE '2026-10-22'
  AND a.status <> 'Cancelled'
ORDER BY a.start_time;
 
-- Q3: Monthly revenue per branch in 2025 (NGN)
SELECT date_trunc('month', pay.paid_at)::date AS month, b.name AS branch,
       count(*) AS payments, sum(pay.amount) AS revenue_ngn
FROM payments pay
JOIN appointments a ON a.appointment_id = pay.appointment_id
JOIN branches b     ON b.branch_id = a.branch_id
WHERE pay.paid_at >= '2025-01-01' AND pay.paid_at < '2026-01-01'
GROUP BY 1, 2
ORDER BY 1, 2;
 
-- Q4: Top 5 diagnoses in 2025 with percentage share
SELECT icd10_code, description, count(*) AS cases,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct_of_all
FROM diagnoses
WHERE diagnosed_at >= '2025-01-01' AND diagnosed_at < '2026-01-01'
GROUP BY icd10_code, description
ORDER BY cases DESC
LIMIT 5;
 
-- Q5: Top 10 doctors by completed appointments in 2025
SELECT s.first_name || ' ' || s.last_name AS doctor, s.specialisation,
       b.name AS branch, count(*) AS completed,
       RANK() OVER (ORDER BY count(*) DESC) AS workload_rank
FROM appointments a
JOIN staff s    ON s.staff_id  = a.doctor_id
JOIN branches b ON b.branch_id = s.branch_id
WHERE a.status = 'Completed'
  AND a.appointment_date BETWEEN '2025-01-01' AND '2025-12-31'
GROUP BY s.staff_id, s.first_name, s.last_name, s.specialisation, b.name
ORDER BY workload_rank
LIMIT 10;
 
-- Q6: No-show and cancellation rates per branch (past appointments)
SELECT b.name AS branch, count(*) AS total,
       count(*) FILTER (WHERE a.status = 'No-show')   AS no_shows,
       round(100.0 * count(*) FILTER (WHERE a.status = 'No-show') / count(*), 1)   AS no_show_pct,
       count(*) FILTER (WHERE a.status = 'Cancelled') AS cancelled,
       round(100.0 * count(*) FILTER (WHERE a.status = 'Cancelled') / count(*), 1) AS cancel_pct
FROM appointments a
JOIN branches b ON b.branch_id = a.branch_id
WHERE a.appointment_date <= DATE '2026-10-21'
GROUP BY b.name
ORDER BY b.name;
 
-- Q7: Positive malaria tests in the last 30 days
SELECT a.appointment_date, b.name AS branch,
       p.first_name || ' ' || p.last_name AS patient, t.name AS test, lr.result
FROM lab_requests lr
JOIN lab_tests t     ON t.test_id = lr.test_id
JOIN appointments a  ON a.appointment_id = lr.appointment_id
JOIN patients p      ON p.patient_id = a.patient_id
JOIN branches b      ON b.branch_id = a.branch_id
WHERE lr.result = 'Positive'
  AND t.name LIKE 'Malaria%'
  AND a.appointment_date BETWEEN DATE '2026-10-21' - 30 AND DATE '2026-10-21'
ORDER BY a.appointment_date DESC;
 
-- Q8: Top 3 medications by dispensed value per branch in 2025
SELECT branch, medication, units, value_ngn
FROM (
  SELECT b.name AS branch, m.name AS medication,
         sum(pi.quantity) AS units,
         sum(pi.quantity * m.unit_price) AS value_ngn,
         ROW_NUMBER() OVER (PARTITION BY b.name
                            ORDER BY sum(pi.quantity * m.unit_price) DESC) AS rn
  FROM prescription_items pi
  JOIN medications m   ON m.medication_id = pi.medication_id
  JOIN prescriptions pr ON pr.prescription_id = pi.prescription_id
  JOIN appointments a  ON a.appointment_id = pr.appointment_id
  JOIN branches b      ON b.branch_id = a.branch_id
  WHERE pr.issued_at >= '2025-01-01' AND pr.issued_at < '2026-01-01'
  GROUP BY b.name, m.name
) ranked
WHERE rn <= 3
ORDER BY branch, rn;
 
-- Q9: Recall list: patients with no appointment in the last 12 months
SELECT count(*) AS patients_to_recall
FROM patients p
WHERE NOT EXISTS (
  SELECT 1 FROM appointments a
  WHERE a.patient_id = p.patient_id
    AND a.appointment_date > DATE '2026-10-21' - 365
);
 
-- Q10: Reusable view of patient visits, then use it
CREATE OR REPLACE VIEW v_patient_visits AS
SELECT p.patient_id, p.first_name || ' ' || p.last_name AS patient,
       a.appointment_id, a.appointment_date, b.name AS branch,
       s.first_name || ' ' || s.last_name AS doctor, a.status,
       d.description AS diagnosis
FROM patients p
JOIN appointments a ON a.patient_id = p.patient_id
JOIN staff s        ON s.staff_id   = a.doctor_id
JOIN branches b     ON b.branch_id  = a.branch_id
LEFT JOIN diagnoses d ON d.appointment_id = a.appointment_id;
 
SELECT appointment_date, branch, doctor, status, diagnosis
FROM v_patient_visits
WHERE patient_id = 1234
ORDER BY appointment_date DESC
LIMIT 5;
