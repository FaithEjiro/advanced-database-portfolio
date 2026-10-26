// =====================================================
// CarePoint: MongoDB queries (Portfolio 4)
// Run inside the container:
//   mongosh carepoint --quiet --file /tmp/02_queries.js
// =====================================================
 
// Helper: list the stages of a query plan (e.g. COLLSCAN, IXSCAN)
function stages(p) {
  const out = [p.stage];
  if (p.inputStage) out.push(...stages(p.inputStage));
  return out;
}
function planSummary(e) {
  return {
    plan: stages(e.queryPlanner.winningPlan).join(" <- "),
    documentsReturned: e.executionStats.nReturned,
    documentsExamined: e.executionStats.totalDocsExamined,
    timeMs: e.executionStats.executionTimeMillis
  };
}
 
// Start clean: remove any custom index from a previous run
db.patient_records.dropIndexes();
 
const phone = db.patient_records.findOne({ _id: 1234 }, { "contact.phone": 1 }).contact.phone;
 
print("\n===== M1: Patient history by phone (one document, no joins) =====");
printjson(db.patient_records.findOne(
  { "contact.phone": phone },
  { name: 1, contact: 1, registered_branch: 1, insurance: 1, visits: { $slice: -2 } }
));
print("Total visits for this patient:",
      db.patient_records.findOne({ "contact.phone": phone }).visits.length);
 
print("\n===== M2: Positive malaria tests, last 30 days (compare SQL Q7) =====");
const m2 = db.patient_records.aggregate([
  { $unwind: "$visits" },
  { $match: { "visits.date": { $gte: ISODate("2026-09-21"), $lt: ISODate("2026-10-22") } } },
  { $unwind: "$visits.lab_tests" },
  { $match: { "visits.lab_tests.result": "Positive", "visits.lab_tests.test": /^Malaria/ } },
  { $project: { _id: 0, date: "$visits.date", branch: "$visits.branch",
                patient: { $concat: ["$name.first", " ", "$name.last"] },
                test: "$visits.lab_tests.test" } },
  { $sort: { date: -1 } }
]).toArray();
print("Results found:", m2.length, "(SQL Q7 found 72)");
printjson(m2.slice(0, 5));
 
print("\n===== M3: Top 5 diagnoses of 2025 (compare SQL Q4) =====");
printjson(db.patient_records.aggregate([
  { $unwind: "$visits" },
  { $match: { "visits.date": { $gte: ISODate("2025-01-01"), $lt: ISODate("2026-01-01") },
              "visits.diagnosis": { $exists: true } } },
  { $group: { _id: "$visits.diagnosis.icd10",
              description: { $first: "$visits.diagnosis.description" },
              cases: { $sum: 1 } } },
  { $sort: { cases: -1 } },
  { $limit: 5 }
]).toArray());
 
print("\n===== M4: Flexible fields (exist only when needed) =====");
printjson({
  totalPatients:       db.patient_records.countDocuments({}),
  withInsuranceField:  db.patient_records.countDocuments({ insurance: { $exists: true } }),
  withoutEmailField:   db.patient_records.countDocuments({ "contact.email": { $exists: false } }),
  withBloodGroupField: db.patient_records.countDocuments({ blood_group: { $exists: true } })
});
 
print("\n===== M5: Change structure without ALTER TABLE =====");
// Remove anything added by a previous run, so the script can be re-run
db.patient_records.updateOne({ _id: 1234 },
  { $unset: { allergies: "" }, $pull: { visits: { appointment_id: 999999 } } });
db.patient_records.updateOne({ _id: 1234 },
  { $set: { allergies: ["Penicillin", "Sulfa drugs"] } });
db.patient_records.updateOne({ _id: 1234 },
  { $push: { visits: { appointment_id: 999999, date: ISODate("2026-11-05T10:00:00Z"),
                       branch: "Wuse", status: "Booked", reason: "Follow-up" } } });
printjson(db.patient_records.findOne({ _id: 1234 },
  { name: 1, allergies: 1, visits: { $slice: -1 } }));
print("Patients with an allergies field:",
      db.patient_records.countDocuments({ allergies: { $exists: true } }));
 
print("\n===== M6: Phone search BEFORE index =====");
printjson(planSummary(db.patient_records.find({ "contact.phone": phone }).explain("executionStats")));
 
db.patient_records.createIndex({ "contact.phone": 1 }, { name: "idx_contact_phone" });
 
print("\n===== M6: Phone search AFTER index =====");
printjson(planSummary(db.patient_records.find({ "contact.phone": phone }).explain("executionStats")));
 
print("\n===== M7: Storage =====");
const s = db.patient_records.stats();
printjson({
  documents: s.count,
  dataSizeMB: (s.size / 1048576).toFixed(1),
  storageOnDiskMB: (s.storageSize / 1048576).toFixed(1),
  averageDocumentKB: (s.avgObjSize / 1024).toFixed(1)
});
