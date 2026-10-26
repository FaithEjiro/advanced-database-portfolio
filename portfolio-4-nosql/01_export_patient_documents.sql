-- =====================================================
-- CarePoint: Build one JSON document per patient (Portfolio 4)
-- Visits, diagnoses, prescriptions, lab tests and payments are
-- embedded inside the patient document. Empty fields are removed
-- (json_strip_nulls), so documents only contain what exists.
-- =====================================================
CREATE OR REPLACE VIEW mongo_patient_documents AS
SELECT json_strip_nulls(json_build_object(
  '_id', p.patient_id,
  'name', json_build_object('first', p.first_name, 'last', p.last_name),
  'gender', p.gender,
  'date_of_birth', json_build_object('$date', to_char(p.date_of_birth, 'YYYY-MM-DD"T00:00:00Z"')),
  'blood_group', p.blood_group,
  'contact', json_build_object('phone', p.phone, 'email', p.email, 'address', p.address),
  'registered_branch', b.name,
  'insurance', CASE WHEN EXISTS (
                 SELECT 1 FROM appointments a2 JOIN payments y2 ON y2.appointment_id = a2.appointment_id
                 WHERE a2.patient_id = p.patient_id AND y2.method = 'HMO')
               THEN json_build_object('type', 'HMO') END,
  'visits', COALESCE(v.visits, '[]'::json)
)) AS doc
FROM patients p
JOIN branches b ON b.branch_id = p.registered_branch_id
LEFT JOIN LATERAL (
  SELECT json_agg(json_build_object(
    'appointment_id', a.appointment_id,
    'date', json_build_object('$date', to_char(a.appointment_date + a.start_time, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')),
    'branch', ab.name,
    'doctor', json_build_object('name', s.first_name || ' ' || s.last_name,
                                'specialisation', s.specialisation),
    'status', a.status,
    'reason', a.reason,
    'diagnosis', (SELECT json_build_object('icd10', d.icd10_code, 'description', d.description)
                  FROM diagnoses d WHERE d.appointment_id = a.appointment_id LIMIT 1),
    'prescriptions', (SELECT json_agg(json_build_object(
                        'status', pr.status,
                        'items', (SELECT json_agg(json_build_object(
                                    'drug', m.name, 'strength', m.strength,
                                    'dosage', pi.dosage, 'frequency', pi.frequency,
                                    'quantity', pi.quantity))
                                  FROM prescription_items pi
                                  JOIN medications m ON m.medication_id = pi.medication_id
                                  WHERE pi.prescription_id = pr.prescription_id)))
                      FROM prescriptions pr WHERE pr.appointment_id = a.appointment_id),
    'lab_tests', (SELECT json_agg(json_build_object('test', t.name, 'result', lr.result))
                  FROM lab_requests lr JOIN lab_tests t ON t.test_id = lr.test_id
                  WHERE lr.appointment_id = a.appointment_id),
    'payment', (SELECT json_build_object('amount', y.amount, 'method', y.method)
                FROM payments y WHERE y.appointment_id = a.appointment_id LIMIT 1)
  ) ORDER BY a.appointment_date, a.start_time) AS visits
  FROM appointments a
  JOIN staff s     ON s.staff_id   = a.doctor_id
  JOIN branches ab ON ab.branch_id = a.branch_id
  WHERE a.patient_id = p.patient_id
) v ON true;
 
-- Export one document per line (the format mongoimport expects)
\copy (SELECT doc FROM mongo_patient_documents ORDER BY (doc->>'_id')::int) TO '/tmp/patient_documents.json'
