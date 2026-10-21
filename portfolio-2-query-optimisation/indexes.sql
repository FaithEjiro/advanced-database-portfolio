-- =====================================================
-- CarePoint: Performance indexes (Portfolio 2)
-- Based on the "before" execution plans.
-- PostgreSQL indexes primary keys automatically, but NOT foreign keys.
-- =====================================================
 
-- Receptionists search patients by phone (Q1)
CREATE INDEX idx_patients_phone ON patients (phone);
 
-- Patient history and recall list (Q1, Q9, Q10).
-- Composite index: patient_id first (exact match), then appointment_date
-- (range filter / sort), so one index serves several queries.
CREATE INDEX idx_appointments_patient_date ON appointments (patient_id, appointment_date);
 
-- Date-range reports such as "last 30 days" (Q7)
CREATE INDEX idx_appointments_date ON appointments (appointment_date);
 
-- Foreign keys used in joins to appointments (Q1, Q7, Q10, Q8, Q3)
CREATE INDEX idx_diagnoses_appointment     ON diagnoses (appointment_id);
CREATE INDEX idx_lab_requests_appointment  ON lab_requests (appointment_id);
CREATE INDEX idx_prescriptions_appointment ON prescriptions (appointment_id);
CREATE INDEX idx_payments_appointment      ON payments (appointment_id);
 
-- Refresh statistics so the planner knows about the new indexes
ANALYZE;
 
-- Indexes take disk space: record the cost
SELECT indexrelname AS index_name,
       relname      AS table_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE indexrelname LIKE 'idx_%'
ORDER BY pg_relation_size(indexrelid) DESC;
