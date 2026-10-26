-- =====================================================
-- CarePoint: COMMIT, ROLLBACK and SAVEPOINT (Portfolio 3)
-- Workflow: "complete a consultation" = 6 steps that must
-- succeed or fail together (atomicity).
-- =====================================================
 
-- Pick the next booked appointment for doctor 5
SELECT appointment_id AS appt, branch_id AS br
FROM appointments
WHERE status = 'Booked' AND doctor_id = 5
ORDER BY appointment_date, start_time
LIMIT 1 \gset
 
\echo '########## DEMO 1: COMMIT (all steps succeed) ##########'
SELECT name, stock_quantity AS stock_before FROM medications WHERE medication_id = 2;
 
BEGIN;
UPDATE appointments SET status = 'Completed' WHERE appointment_id = :appt;
 
INSERT INTO diagnoses (appointment_id, icd10_code, description)
VALUES (:appt, 'J06.9', 'Acute upper respiratory infection');
 
INSERT INTO prescriptions (appointment_id, status, dispensed_by, dispensed_at)
VALUES (:appt, 'Dispensed',
        (SELECT staff_id FROM staff WHERE role = 'Pharmacist' AND branch_id = :br
         ORDER BY staff_id LIMIT 1),
        now())
RETURNING prescription_id \gset
 
INSERT INTO prescription_items (prescription_id, medication_id, dosage, frequency, duration_days, quantity)
VALUES (:prescription_id, 2, '1 tablet', 'Three times daily', 3, 9);
 
UPDATE medications SET stock_quantity = stock_quantity - 9 WHERE medication_id = 2;
 
INSERT INTO payments (appointment_id, amount, method)
VALUES (:appt, 5000 + 9 * 20, 'Transfer');
COMMIT;
 
SELECT name, stock_quantity AS stock_after FROM medications WHERE medication_id = 2;
 
 
-- Pick another booked appointment for the failure demos
SELECT appointment_id AS appt2, branch_id AS br2
FROM appointments
WHERE status = 'Booked' AND doctor_id = 5
ORDER BY appointment_date, start_time
LIMIT 1 \gset
 
\echo '########## DEMO 2a: ROLLBACK (step 5 fails, everything undone) ##########'
SELECT name, stock_quantity AS stock_before FROM medications WHERE medication_id = 1;
 
BEGIN;
UPDATE appointments SET status = 'Completed' WHERE appointment_id = :appt2;
 
INSERT INTO diagnoses (appointment_id, icd10_code, description)
VALUES (:appt2, 'B54', 'Malaria, unspecified');
 
INSERT INTO prescriptions (appointment_id, status, dispensed_by, dispensed_at)
VALUES (:appt2, 'Dispensed',
        (SELECT staff_id FROM staff WHERE role = 'Pharmacist' AND branch_id = :br2
         ORDER BY staff_id LIMIT 1),
        now())
RETURNING prescription_id AS failed_rx \gset
 
INSERT INTO prescription_items (prescription_id, medication_id, dosage, frequency, duration_days, quantity)
VALUES (:failed_rx, 1, '1 tablet', 'Twice daily', 5, 10);
 
-- Only 5 in stock: 5 - 10 = -5 violates chk_stock_non_negative
UPDATE medications SET stock_quantity = stock_quantity - 10 WHERE medication_id = 1;
 
-- The transaction is now aborted: this payment will be refused
INSERT INTO payments (appointment_id, amount, method)
VALUES (:appt2, 5000, 'Cash');
ROLLBACK;
 
\echo '--- After ROLLBACK: appointment still Booked, no diagnosis, no prescription, stock unchanged ---'
SELECT appointment_id, status FROM appointments WHERE appointment_id = :appt2;
SELECT count(*) AS diagnoses_saved    FROM diagnoses     WHERE appointment_id = :appt2;
SELECT count(*) AS prescriptions_saved FROM prescriptions WHERE appointment_id = :appt2;
SELECT name, stock_quantity AS stock_after FROM medications WHERE medication_id = 1;
 
 
\echo '########## DEMO 2b: SAVEPOINT (undo only the failed part) ##########'
BEGIN;
UPDATE appointments SET status = 'Completed' WHERE appointment_id = :appt2;
 
INSERT INTO diagnoses (appointment_id, icd10_code, description)
VALUES (:appt2, 'B54', 'Malaria, unspecified');
 
SAVEPOINT before_dispensing;
 
INSERT INTO prescriptions (appointment_id, status, dispensed_by, dispensed_at)
VALUES (:appt2, 'Dispensed',
        (SELECT staff_id FROM staff WHERE role = 'Pharmacist' AND branch_id = :br2
         ORDER BY staff_id LIMIT 1),
        now())
RETURNING prescription_id AS sp_rx \gset
 
INSERT INTO prescription_items (prescription_id, medication_id, dosage, frequency, duration_days, quantity)
VALUES (:sp_rx, 1, '1 tablet', 'Twice daily', 5, 10);
 
-- Fails again: not enough stock
UPDATE medications SET stock_quantity = stock_quantity - 10 WHERE medication_id = 1;
 
-- Undo only the dispensing steps; the appointment update and diagnosis survive
ROLLBACK TO SAVEPOINT before_dispensing;
 
-- Record the prescription as Pending (to be dispensed when stock arrives)
INSERT INTO prescriptions (appointment_id, status)
VALUES (:appt2, 'Pending')
RETURNING prescription_id AS pending_rx \gset
 
INSERT INTO prescription_items (prescription_id, medication_id, dosage, frequency, duration_days, quantity)
VALUES (:pending_rx, 1, '1 tablet', 'Twice daily', 5, 10);
 
INSERT INTO payments (appointment_id, amount, method)
VALUES (:appt2, 5000, 'Cash');
COMMIT;
 
\echo '########## FINAL STATE OF BOTH APPOINTMENTS ##########'
SELECT a.appointment_id, a.status,
       (SELECT count(*) FROM diagnoses d WHERE d.appointment_id = a.appointment_id) AS diagnoses,
       (SELECT string_agg(p.status, ', ') FROM prescriptions p WHERE p.appointment_id = a.appointment_id) AS prescriptions,
       (SELECT count(*) FROM payments y WHERE y.appointment_id = a.appointment_id) AS payments
FROM appointments a
WHERE a.appointment_id IN (:appt, :appt2)
ORDER BY a.appointment_id;
 
SELECT medication_id, name, stock_quantity FROM medications WHERE medication_id IN (1, 2);
