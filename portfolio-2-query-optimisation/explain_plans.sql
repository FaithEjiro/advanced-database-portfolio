-- =====================================================
-- CarePoint: Execution plans for index-sensitive queries
-- Run once BEFORE and once AFTER creating indexes.
-- =====================================================
SELECT phone AS pphone FROM patients WHERE patient_id = 1234 \gset
 
\echo '=== Q1: Patient history by phone ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.appointment_date, a.start_time, b.name, s.first_name, s.last_name,
       a.status, d.icd10_code, d.description
FROM patients p
JOIN appointments a ON a.patient_id = p.patient_id
JOIN staff s        ON s.staff_id   = a.doctor_id
JOIN branches b     ON b.branch_id  = a.branch_id
LEFT JOIN diagnoses d ON d.appointment_id = a.appointment_id
WHERE p.phone = :'pphone'
ORDER BY a.appointment_date DESC, a.start_time DESC;
 
\echo '=== Q2: Doctor schedule (uses existing partial index) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.start_time, p.first_name, p.last_name, a.reason, a.status
FROM appointments a
JOIN patients p ON p.patient_id = a.patient_id
WHERE a.doctor_id = 5 AND a.appointment_date = DATE '2026-10-22'
  AND a.status <> 'Cancelled'
ORDER BY a.start_time;
 
\echo '=== Q7: Positive malaria tests, last 30 days ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.appointment_date, b.name, p.first_name, p.last_name, t.name, lr.result
FROM lab_requests lr
JOIN lab_tests t    ON t.test_id = lr.test_id
JOIN appointments a ON a.appointment_id = lr.appointment_id
JOIN patients p     ON p.patient_id = a.patient_id
JOIN branches b     ON b.branch_id = a.branch_id
WHERE lr.result = 'Positive' AND t.name LIKE 'Malaria%'
  AND a.appointment_date BETWEEN DATE '2026-10-21' - 30 AND DATE '2026-10-21'
ORDER BY a.appointment_date DESC;
 
\echo '=== Q9: Recall list (anti-join) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM patients p
WHERE NOT EXISTS (
  SELECT 1 FROM appointments a
  WHERE a.patient_id = p.patient_id
    AND a.appointment_date > DATE '2026-10-21' - 365
);
 
\echo '=== Q10: Patient history through the view ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT appointment_date, branch, doctor, status, diagnosis
FROM v_patient_visits
WHERE patient_id = 1234
ORDER BY appointment_date DESC
LIMIT 5;
