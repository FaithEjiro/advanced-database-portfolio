-- =====================================================
-- CarePoint: Sample data generator (Portfolio 2)
-- Creates a realistic, reproducible dataset for query and
-- performance testing. Safe to re-run.
-- Snapshot date: 2026-10-21 (later appointments are 'Booked')
-- =====================================================
 
TRUNCATE branches, departments, staff, patients, appointments, diagnoses,
  medications, prescriptions, prescription_items, lab_tests, lab_requests,
  payments RESTART IDENTITY CASCADE;
 
SELECT setseed(0.42);  -- reproducible random data
 
-- ---------- Branches ----------
INSERT INTO branches (name, address, phone) VALUES
  ('Wuse',    'Plot 12, Aminu Kano Crescent, Wuse II, Abuja', '09012345601'),
  ('Garki',   '14 Ahmadu Bello Way, Garki Area 11, Abuja',     '09012345602'),
  ('Maitama', '7 Gana Street, Maitama, Abuja',                 '09012345603');
 
-- ---------- Departments ----------
INSERT INTO departments (name) VALUES
  ('General Medicine'), ('Paediatrics'), ('Obstetrics & Gynaecology'),
  ('Internal Medicine'), ('Dermatology'), ('Laboratory'), ('Pharmacy'),
  ('Administration');
 
-- ---------- Doctors: 30, spread across 5 clinical departments and 3 branches ----------
INSERT INTO staff (first_name, last_name, role, specialisation, department_id,
                   branch_id, phone, email, hire_date)
SELECT fn, ln, 'Doctor',
       (ARRAY['General Practice','Paediatrics','Obstetrics & Gynaecology',
              'Internal Medicine','Dermatology'])[((i - 1) % 5) + 1],
       ((i - 1) % 5) + 1,
       ((i - 1) % 3) + 1,
       '0803' || lpad(i::text, 7, '0'),
       lower(fn || '.' || ln || '.d' || i) || '@carepoint.ng',
       DATE '2015-01-01' + (i * 97 % 3000)
FROM (
  SELECT i,
         (ARRAY['Chinedu','Emeka','Tunde','Musa','Ibrahim','Olumide','Segun','Yusuf',
                'Ikenna','Abdullahi','Obinna','Kunle','Babajide','Suleiman','Uche',
                'Amaka','Ngozi','Fatima','Aisha','Funmilayo','Chioma','Zainab',
                'Blessing','Adaeze','Halima','Yetunde','Nkechi','Folake','Hauwa',
                'Ifeoma'])[1 + (i * 7) % 30] AS fn,
         (ARRAY['Okafor','Adeyemi','Bello','Ibrahim','Eze','Okonkwo','Abubakar',
                'Ogunleye','Nwosu','Danjuma','Usman','Olawale','Chukwu','Mohammed',
                'Adebayo','Obi','Lawal','Afolabi','Garba','Nnamdi'])[1 + (i * 11) % 20] AS ln
  FROM generate_series(1, 30) AS i
) s;
 
-- ---------- Other staff: per branch 2 receptionists, 2 lab techs, 2 pharmacists, 1 admin ----------
INSERT INTO staff (first_name, last_name, role, specialisation, department_id,
                   branch_id, phone, email, hire_date)
SELECT fn, ln, role, NULL, dept, branch_id,
       '0806' || lpad(rn::text, 7, '0'),
       lower(fn || '.' || ln || '.s' || rn) || '@carepoint.ng',
       DATE '2016-01-01' + (rn * 53 % 3000)::int
FROM (
  SELECT x.*,
         (ARRAY['Chinedu','Emeka','Tunde','Musa','Ibrahim','Olumide','Segun','Yusuf',
                'Ikenna','Abdullahi','Obinna','Kunle','Babajide','Suleiman','Uche',
                'Amaka','Ngozi','Fatima','Aisha','Funmilayo','Chioma','Zainab',
                'Blessing','Adaeze','Halima','Yetunde','Nkechi','Folake','Hauwa',
                'Ifeoma'])[1 + (rn * 13) % 30] AS fn,
         (ARRAY['Okafor','Adeyemi','Bello','Ibrahim','Eze','Okonkwo','Abubakar',
                'Ogunleye','Nwosu','Danjuma','Usman','Olawale','Chukwu','Mohammed',
                'Adebayo','Obi','Lawal','Afolabi','Garba','Nnamdi'])[1 + (rn * 7) % 20] AS ln
  FROM (
    SELECT row_number() OVER (ORDER BY b.branch_id, r.role) AS rn,
           b.branch_id, r.role, r.dept
    FROM branches b
    CROSS JOIN (VALUES ('Receptionist', 8, 2), ('Lab Technician', 6, 2),
                       ('Pharmacist', 7, 2), ('Admin', 8, 1)) AS r(role, dept, cnt)
    CROSS JOIN LATERAL generate_series(1, r.cnt)
  ) x
) s;
 
-- ---------- Patients: 20,000 ----------
INSERT INTO patients (first_name, last_name, date_of_birth, gender, phone, email,
                      address, blood_group, registered_branch_id, registered_at)
SELECT
  CASE WHEN g = 'Male'
       THEN (ARRAY['Chinedu','Emeka','Tunde','Musa','Ibrahim','Olumide','Segun',
                   'Yusuf','Ikenna','Abdullahi','Obinna','Kunle','Babajide',
                   'Suleiman','Uche'])[1 + floor(random() * 15)::int]
       ELSE (ARRAY['Amaka','Ngozi','Fatima','Aisha','Funmilayo','Chioma','Zainab',
                   'Blessing','Adaeze','Halima','Yetunde','Nkechi','Folake','Hauwa',
                   'Ifeoma'])[1 + floor(random() * 15)::int]
  END,
  (ARRAY['Okafor','Adeyemi','Bello','Ibrahim','Eze','Okonkwo','Abubakar','Ogunleye',
         'Nwosu','Danjuma','Usman','Olawale','Chukwu','Mohammed','Adebayo','Obi',
         'Lawal','Afolabi','Garba','Nnamdi'])[1 + floor(random() * 20)::int],
  DATE '1945-01-01' + floor(random() * 28000)::int,
  g,
  (ARRAY['0803','0806','0813','0816','0703','0706','0805','0807','0905','0802',
         '0808','0701'])[1 + floor(random() * 12)::int] || lpad(i::text, 7, '0'),
  CASE WHEN random() < 0.6 THEN 'patient' || i || '@example.com' END,
  (ARRAY['Wuse II','Garki Area 1','Maitama','Asokoro','Gwarinpa','Kubwa','Jabi',
         'Utako','Lugbe','Karu'])[1 + floor(random() * 10)::int] || ', Abuja',
  (ARRAY['O+','O+','O+','O+','O+','A+','A+','A+','B+','B+','B+','AB+',
         'O-','A-','B-','AB-'])[1 + floor(random() * 16)::int],
  1 + floor(random() * 3)::int,
  TIMESTAMP '2023-01-01' + random() * INTERVAL '365 days'
FROM (
  SELECT i, CASE WHEN random() < 0.52 THEN 'Female' ELSE 'Male' END AS g
  FROM generate_series(1, 20000) AS i
) s;
 
-- ---------- Appointments: doctor x working day x 30-min slot, ~50% filled ----------
INSERT INTO appointments (patient_id, doctor_id, branch_id, appointment_date,
                          start_time, status, reason, created_at)
SELECT patient_id, doctor_id, branch_id, d, t,
       CASE WHEN d > DATE '2026-10-21' THEN 'Booked'
            WHEN r < 0.85 THEN 'Completed'
            WHEN r < 0.93 THEN 'Cancelled'
            ELSE 'No-show' END,
       (ARRAY['Fever','Routine check-up','Headache','Cough and cold','Stomach pain',
              'Antenatal visit','Follow-up','Skin rash','Body pains',
              'Blood pressure review'])[1 + floor(random() * 10)::int],
       (d + t) - INTERVAL '3 days'
FROM (
  SELECT 1 + floor(random() * 20000)::int AS patient_id,
         s.staff_id AS doctor_id, s.branch_id,
         day::date AS d, slot::time AS t, random() AS r
  FROM staff s
  CROSS JOIN generate_series(DATE '2024-01-01', DATE '2026-12-31', INTERVAL '1 day') AS day
  CROSS JOIN generate_series(TIMESTAMP '2000-01-01 09:00', TIMESTAMP '2000-01-01 16:30',
                             INTERVAL '30 minutes') AS slot
  WHERE s.role = 'Doctor'
    AND extract(dow FROM day) <> 0      -- closed on Sundays
    AND random() < 0.5
) x;
 
-- ---------- Diagnoses: one per completed appointment ----------
CREATE TEMP TABLE dx (k int, code text, descr text);
INSERT INTO dx VALUES
  (1,'B54','Malaria, unspecified'),        (2,'A01.0','Typhoid fever'),
  (3,'I10','Essential hypertension'),      (4,'E11.9','Type 2 diabetes mellitus'),
  (5,'J06.9','Acute upper respiratory infection'), (6,'K29.7','Gastritis'),
  (7,'N39.0','Urinary tract infection'),   (8,'M54.5','Low back pain'),
  (9,'L30.9','Dermatitis'),                (10,'D64.9','Anaemia');
 
INSERT INTO diagnoses (appointment_id, icd10_code, description, diagnosed_at)
SELECT a.appointment_id, dx.code, dx.descr,
       a.appointment_date + a.start_time + INTERVAL '15 minutes'
FROM appointments a
JOIN dx ON dx.k = (a.appointment_id * 7 % 10) + 1
WHERE a.status = 'Completed';
 
-- ---------- Medications (prices per unit, NGN) ----------
INSERT INTO medications (name, form, strength, unit_price) VALUES
  ('Artemether/Lumefantrine', 'Tablet',    '80/480mg', 1500),
  ('Paracetamol',             'Tablet',    '500mg',      20),
  ('Amoxicillin',             'Capsule',   '500mg',      80),
  ('Ciprofloxacin',           'Tablet',    '500mg',     150),
  ('Amlodipine',              'Tablet',    '10mg',       60),
  ('Metformin',               'Tablet',    '500mg',      40),
  ('Lisinopril',              'Tablet',    '10mg',       70),
  ('Omeprazole',              'Capsule',   '20mg',       60),
  ('Ibuprofen',               'Tablet',    '400mg',      30),
  ('Ferrous sulphate',        'Tablet',    '200mg',      15),
  ('Dextromethorphan',        'Syrup',     '15mg/5ml', 1200),
  ('Hydrocortisone',          'Cream',     '1%',        900),
  ('Ceftriaxone',             'Injection', '1g',       2500),
  ('Ascorbic acid',           'Tablet',    '100mg',      10),
  ('Metronidazole',           'Tablet',    '400mg',      25);
 
-- ---------- Lab tests (NGN) ----------
INSERT INTO lab_tests (name, price) VALUES
  ('Malaria RDT', 2500), ('Malaria parasite microscopy', 3000),
  ('Full Blood Count', 6000), ('Widal test', 3500), ('Fasting Blood Sugar', 2500),
  ('Urinalysis', 2000), ('Lipid Profile', 12000), ('Liver Function Test', 15000),
  ('HbA1c', 10000), ('Pregnancy test', 2000);
 
-- ---------- Prescriptions: ~60% of completed appointments ----------
WITH ph AS (
  SELECT DISTINCT ON (branch_id) branch_id, staff_id
  FROM staff WHERE role = 'Pharmacist' ORDER BY branch_id, staff_id
)
INSERT INTO prescriptions (appointment_id, issued_at, status, dispensed_by, dispensed_at)
SELECT a.appointment_id,
       a.appointment_date + a.start_time + INTERVAL '20 minutes',
       'Dispensed', ph.staff_id,
       a.appointment_date + a.start_time + INTERVAL '50 minutes'
FROM appointments a
JOIN ph USING (branch_id)
WHERE a.status = 'Completed' AND random() < 0.6;
 
-- ---------- Prescription items: 1 to 3 different drugs per prescription ----------
INSERT INTO prescription_items (prescription_id, medication_id, dosage, frequency,
                                duration_days, quantity)
SELECT p.prescription_id,
       ((p.prescription_id + n * 5) % 15) + 1,
       '1 dose',
       (ARRAY['Once daily','Twice daily','Three times daily'])[n],
       (ARRAY[3, 5, 7])[n],
       (ARRAY[3, 10, 21])[n]
FROM prescriptions p
CROSS JOIN LATERAL generate_series(1, 1 + p.prescription_id % 3) AS n;
 
-- ---------- Lab requests: ~30% of completed appointments ----------
WITH lt AS (
  SELECT DISTINCT ON (branch_id) branch_id, staff_id
  FROM staff WHERE role = 'Lab Technician' ORDER BY branch_id, staff_id
)
INSERT INTO lab_requests (appointment_id, test_id, technician_id, status, result,
                          requested_at, result_at)
SELECT a.appointment_id,
       (a.appointment_id * 3 % 10) + 1,
       lt.staff_id, 'Completed',
       (ARRAY['Negative','Positive','Within normal range','Within normal range',
              'Slightly elevated'])[1 + floor(random() * 5)::int],
       a.appointment_date + a.start_time + INTERVAL '10 minutes',
       a.appointment_date + a.start_time + INTERVAL '2 hours'
FROM appointments a
JOIN lt USING (branch_id)
WHERE a.status = 'Completed' AND random() < 0.3;
 
-- ---------- Payments: consultation fee (NGN 5,000) + lab tests ----------
INSERT INTO payments (appointment_id, amount, method, status, paid_at)
SELECT a.appointment_id,
       5000 + COALESCE(l.lab_total, 0),
       (ARRAY['Transfer','Transfer','Transfer','Transfer','Cash','Cash',
              'Card','Card','HMO','HMO'])[(a.appointment_id % 10) + 1],
       'Paid',
       a.appointment_date + a.start_time + INTERVAL '1 hour'
FROM appointments a
LEFT JOIN (
  SELECT lr.appointment_id, sum(t.price) AS lab_total
  FROM lab_requests lr JOIN lab_tests t USING (test_id)
  GROUP BY lr.appointment_id
) l USING (appointment_id)
WHERE a.status = 'Completed';
 
-- Refresh planner statistics after the bulk load
ANALYZE;
