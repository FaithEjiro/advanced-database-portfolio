-- =====================================================
-- CarePoint: Constraint tests (Portfolio 1)
-- Tries valid and invalid inserts to prove integrity rules work.
-- Everything is rolled back at the end, so no data is kept.
-- =====================================================
\set ON_ERROR_ROLLBACK on
BEGIN;
 
-- ---------- Setup: valid rows (expect SUCCESS) ----------
INSERT INTO branches (name, address)
VALUES ('Wuse', 'Plot 12, Aminu Kano Crescent, Wuse II, Abuja');
 
INSERT INTO departments (name) VALUES ('General Medicine');
 
INSERT INTO staff (first_name, last_name, role, specialisation, department_id, branch_id, hire_date)
VALUES ('Musa', 'Bello', 'Doctor', 'General Practice',
        (SELECT department_id FROM departments WHERE name = 'General Medicine'),
        (SELECT branch_id FROM branches WHERE name = 'Wuse'), '2024-01-10');
 
INSERT INTO patients (first_name, last_name, date_of_birth, gender, phone, registered_branch_id)
VALUES ('Amaka', 'Obi', '1995-04-12', 'Female', '08031234567',
        (SELECT branch_id FROM branches WHERE name = 'Wuse'));
 
-- TEST 1 (expect FAIL): a doctor without a specialisation
INSERT INTO staff (first_name, last_name, role, branch_id, hire_date)
VALUES ('Ngozi', 'Eze', 'Doctor',
        (SELECT branch_id FROM branches WHERE name = 'Wuse'), '2025-02-01');
 
-- TEST 2 (expect FAIL): invalid blood group
INSERT INTO patients (first_name, last_name, date_of_birth, gender, phone, blood_group, registered_branch_id)
VALUES ('Tunde', 'Adeyemi', '1990-06-20', 'Male', '08029876543', 'Z+',
        (SELECT branch_id FROM branches WHERE name = 'Wuse'));
 
-- TEST 3 (expect FAIL): foreign key, branch 9999 does not exist
INSERT INTO patients (first_name, last_name, date_of_birth, gender, phone, registered_branch_id)
VALUES ('Chidi', 'Okafor', '1988-11-03', 'Male', '08051112222', 9999);
 
-- TEST 4 (expect SUCCESS): book Dr. Bello at 09:00 on 2 Nov 2026
INSERT INTO appointments (patient_id, doctor_id, branch_id, appointment_date, start_time)
VALUES ((SELECT patient_id FROM patients WHERE phone = '08031234567'),
        (SELECT staff_id FROM staff WHERE last_name = 'Bello'),
        (SELECT branch_id FROM branches WHERE name = 'Wuse'),
        '2026-11-02', '09:00');
 
-- TEST 5 (expect FAIL): double-book the same doctor, date and time
INSERT INTO appointments (patient_id, doctor_id, branch_id, appointment_date, start_time)
VALUES ((SELECT patient_id FROM patients WHERE phone = '08031234567'),
        (SELECT staff_id FROM staff WHERE last_name = 'Bello'),
        (SELECT branch_id FROM branches WHERE name = 'Wuse'),
        '2026-11-02', '09:00');
 
-- TEST 6 (expect SUCCESS): cancel the first booking, then the slot can be re-booked
UPDATE appointments SET status = 'Cancelled'
WHERE appointment_date = '2026-11-02' AND start_time = '09:00';
 
INSERT INTO appointments (patient_id, doctor_id, branch_id, appointment_date, start_time)
VALUES ((SELECT patient_id FROM patients WHERE phone = '08031234567'),
        (SELECT staff_id FROM staff WHERE last_name = 'Bello'),
        (SELECT branch_id FROM branches WHERE name = 'Wuse'),
        '2026-11-02', '09:00');
 
-- TEST 7 (expect FAIL): negative payment amount
INSERT INTO payments (appointment_id, amount, method)
VALUES ((SELECT max(appointment_id) FROM appointments), -5000, 'Cash');
 
-- Show what survived inside the transaction
SELECT appointment_id, appointment_date, start_time, status FROM appointments;
 
ROLLBACK;
