# Normalisation: CarePoint Family Clinic
 
Normalisation organises data so that each fact is stored once, avoiding
update, insertion and deletion anomalies. The CarePoint schema was derived
from a single unnormalised "visit record" and refined to Third Normal Form (3NF).
 
## 0. Unnormalised form (UNF)
 
A paper clinic visit card, recorded as one row per visit:
 
| visit_no | patient_name | patient_phone | doctor_name | doctor_dept | branch | branch_address | date | medications | tests |
|---|---|---|---|---|---|---|---|---|---|
| 101 | Amaka Obi | 0803... | Dr. Bello | Paediatrics | Wuse | Plot 12, Wuse II | 2026-10-01 | Paracetamol 500mg x10; Amoxicillin 250mg x15 | Malaria RDT; FBC |
 
**Problems:**
- `medications` and `tests` hold **multiple values in one cell** (repeating groups).
- Patient, doctor and branch details are **repeated on every visit**. If Amaka
  changes her phone number, every past row must be updated (update anomaly).
- A new doctor cannot be recorded until they see a patient (insertion anomaly).
- Deleting a patient's only visit loses the doctor's details too (deletion anomaly).
 
## 1. First Normal Form (1NF): atomic values, no repeating groups
 
Rule: every cell holds a single value, and every row is uniquely identifiable.
 
- The medications list was split into separate rows, one per drug, which became
  `prescription_items`.
- The tests list was split the same way, which became `lab_requests`.
- Names were split into `first_name` and `last_name`.
- Every table was given a primary key (e.g. `appointment_id`).
 
## 2. Second Normal Form (2NF): no partial dependencies
 
Rule: in a table with a **composite key**, every non-key column must depend on
the **whole** key, not just part of it.
 
`prescription_items` has the composite key `(prescription_id, medication_id)`.
 
- `dosage`, `frequency`, `duration_days` and `quantity` depend on **both**
  (the dose of *this* drug on *this* prescription), so they stay.
- `medication name`, `form`, `strength` and `unit_price` depend **only on
  `medication_id`**. These were moved to a separate `medications` table.
 
Result: a drug's details are stored once in `medications`, and the
many-to-many relationship between prescriptions and medications is resolved by
the junction table `prescription_items`.
 
## 3. Third Normal Form (3NF): no transitive dependencies
 
Rule: non-key columns must depend **only on the key**, not on another non-key
column.
 
| Transitive dependency found | Resolution |
|---|---|
| appointment → doctor → doctor's name, department | Appointment stores only `doctor_id`; doctor details live in `staff` |
| staff → department → department name | `staff` stores `department_id`; name lives in `departments` |
| appointment / staff / patient → branch → branch address | Only `branch_id` is stored; address lives in `branches` |
| appointment → patient → phone, date of birth | Appointment stores only `patient_id`; details live in `patients` |
| lab request → test → test name, price | `lab_requests` stores `test_id`; details live in `lab_tests` |
 
Every non-key attribute in the final 12 tables depends on the key, the whole
key, and nothing but the key. Each table also satisfies **BCNF**, since every
determinant is a candidate key.
 
## 4. Deliberate design decisions
 
- **Doctors are not a separate table.** A doctor is a `staff` row with
  `role = 'Doctor'`. This avoids duplicating names, phones and emails across
  tables. A CHECK constraint ensures every doctor has a specialisation.
- **`appointments.branch_id` is stored even though staff have a branch.** This
  is not redundancy: a doctor may cover a different branch on a given day, so
  the branch is a fact about the *appointment*, not just the doctor.
- **`payments.amount` is stored rather than calculated.** Medication and test
  prices change over time; storing the amount paid preserves an accurate
  financial history.
 
## 5. Constraints enforcing data integrity
 
| Constraint type | Examples |
|---|---|
| Primary keys | Every table; composite key on `prescription_items` |
| Foreign keys | 17 relationships, e.g. `appointments.patient_id → patients` |
| UNIQUE | Branch name, department name, staff email, lab test name |
| CHECK | Valid roles, genders, blood groups, statuses; amounts > 0 |
| Business rules | Doctor must have a specialisation; dispensed prescription must record pharmacist and time; completed lab test must have a result |
| Partial unique index | `uq_doctor_slot`: a doctor cannot have two active appointments at the same date and time |
