/*
  B1: MongoDB scripts (aiu_smartcampus)
  Requirements:
  - student_profiles (embedded extracurricular activities + preferences)
  - course_catalogs (nested course materials + metadata)
  - CRUD with $set, $push, $inc
  - Aggregation pipeline with $match, $group, $project
  - Text search on course descriptions
  - Index management for frequently queried fields

  NOTE (Fix): Validation failed previously because schema required int/long,
  while inserted JS numbers are often stored as double.
  This script allows numeric fields as (int|long|double|decimal) to pass validation.
*/

const DB_NAME = "aiu_smartcampus";
const campus = db.getSiblingDB(DB_NAME);

print("=== B1 START: Using DB = " + DB_NAME + " ===");
printjson(campus.runCommand({ ping: 1 }));

// ------------------------------------------
// 1) Clean re-runnable setup (drop + recreate)
// ------------------------------------------
const existing = campus.getCollectionNames();
if (existing.includes("student_profiles")) campus.student_profiles.drop();
if (existing.includes("course_catalogs"))  campus.course_catalogs.drop();

// ------------------------------
// 2) Create collections + schema
// ------------------------------
campus.createCollection("student_profiles", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["student_id", "reg_no", "name", "email", "department_name", "status", "preferences"],
      properties: {
        student_id: { bsonType: ["int", "long", "double", "decimal"] },
        reg_no: { bsonType: "string" },
        name: {
          bsonType: "object",
          required: ["first", "last"],
          properties: {
            first: { bsonType: "string" },
            last: { bsonType: "string" }
          }
        },
        email: { bsonType: "string" },
        department_name: { bsonType: "string" },
        status: { enum: ["active", "inactive", "graduated"] },

        extracurricular_activities: {
          bsonType: ["array", "null"],
          items: {
            bsonType: "object",
            required: ["name"],
            properties: {
              name: { bsonType: "string" },
              role: { bsonType: ["string", "null"] },
              hours_per_week: { bsonType: ["int", "long", "double", "decimal", "null"] },
              achievements: { bsonType: ["array", "null"] }
            }
          }
        },

        preferences: {
          bsonType: "object",
          required: ["notifications", "ui"],
          properties: {
            notifications: {
              bsonType: "object",
              required: ["email", "sms", "push"],
              properties: {
                email: { bsonType: "bool" },
                sms: { bsonType: "bool" },
                push: { bsonType: "bool" }
              }
            },
            ui: {
              bsonType: "object",
              required: ["theme", "language"],
              properties: {
                theme: { enum: ["light", "dark"] },
                language: { bsonType: "string" }
              }
            },
            interests: { bsonType: ["array", "null"] }
          }
        },

        enrollments: {
          bsonType: ["array", "null"],
          items: {
            bsonType: "object",
            required: ["course_code", "status"],
            properties: {
              course_code: { bsonType: "string" },
              course_name: { bsonType: ["string", "null"] },
              status: { enum: ["enrolled", "completed", "dropped"] },
              performance: {
                bsonType: ["object", "null"],
                properties: {
                  final_score: { bsonType: ["double", "int", "long", "decimal", "null"] },
                  grade: { bsonType: ["string", "null"] }
                }
              }
            }
          }
        },

        activity_summary: {
          bsonType: ["object", "null"],
          properties: {
            total_actions: { bsonType: ["int", "long", "double", "decimal", "null"] },
            total_seconds: { bsonType: ["int", "long", "double", "decimal", "null"] },
            last_activity_at: { bsonType: ["date", "null"] },
            engagement_score_30d: { bsonType: ["double", "int", "long", "decimal", "null"] }
          }
        },

        created_at: { bsonType: ["date", "null"] }
      }
    }
  },
  validationLevel: "moderate"
});

campus.createCollection("course_catalogs", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["course_code", "course_name", "department_name", "credits", "description", "materials", "metadata"],
      properties: {
        course_code: { bsonType: "string" },
        course_name: { bsonType: "string" },
        department_name: { bsonType: "string" },
        credits: { bsonType: ["int", "long", "double", "decimal"] },
        description: { bsonType: "string" },

        materials: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["file_name", "file_type", "upload_date", "file_path", "file_size"],
            properties: {
              file_name: { bsonType: "string" },
              file_type: { bsonType: "string" },
              upload_date: { bsonType: "date" },
              file_path: { bsonType: "string" },
              file_size: { bsonType: ["long", "int", "double", "decimal"] },
              meta: {
                bsonType: ["object", "null"],
                properties: {
                  visibility: { enum: ["public", "enrolled_only"] },
                  tags: { bsonType: ["array", "null"] }
                }
              }
            }
          }
        },

        metadata: {
          bsonType: "object",
          required: ["level", "semester", "tags"],
          properties: {
            level: { bsonType: "string" },
            semester: { bsonType: "string" },
            prerequisites: { bsonType: ["array", "null"] },
            tags: { bsonType: "array" }
          }
        },

        updated_at: { bsonType: ["date", "null"] }
      }
    }
  },
  validationLevel: "moderate"
});

print("Collections created:");
printjson(campus.getCollectionNames());

// --------------------
// 3) Index management
// --------------------
campus.student_profiles.createIndex({ student_id: 1 }, { unique: true });
campus.student_profiles.createIndex({ reg_no: 1 }, { unique: true });
campus.student_profiles.createIndex({ department_name: 1, status: 1 });
campus.student_profiles.createIndex({ "activity_summary.last_activity_at": -1 });

campus.course_catalogs.createIndex({ course_code: 1 }, { unique: true });
campus.course_catalogs.createIndex({ department_name: 1, credits: 1 });

// Text search on course descriptions (plus name/tags)
campus.course_catalogs.createIndex(
  { course_name: "text", description: "text", "metadata.tags": "text" },
  { name: "course_text_idx" }
);

print("Indexes created (course_catalogs):");
printjson(campus.course_catalogs.getIndexes());

// -------------------------
// 4) Seed sample documents
// -------------------------
const now = new Date();

const courses = [
  {
    course_code: "CS501",
    course_name: "Advanced Database Systems",
    department_name: "Computing",
    credits: 3,
    description: "Polyglot persistence, indexing, transactions, and advanced NoSQL patterns for modern data platforms.",
    materials: [
      {
        file_name: "Week1-Polyglot.pdf",
        file_type: "pdf",
        upload_date: new Date("2025-09-10T08:00:00Z"),
        file_path: "/materials/CS501/Week1-Polyglot.pdf",
        file_size: NumberLong(2450012),
        meta: { visibility: "enrolled_only", tags: ["polyglot", "overview"] }
      },
      {
        file_name: "Week2-Indexing.pdf",
        file_type: "pdf",
        upload_date: new Date("2025-09-17T08:00:00Z"),
        file_path: "/materials/CS501/Week2-Indexing.pdf",
        file_size: NumberLong(1982200),
        meta: { visibility: "enrolled_only", tags: ["indexing", "explain"] }
      }
    ],
    metadata: {
      level: "Postgraduate",
      semester: "Sem 2",
      prerequisites: ["CS401"],
      tags: ["nosql", "mongodb", "indexing", "transactions"]
    },
    updated_at: now
  },
  {
    course_code: "BA210",
    course_name: "Business Analytics",
    department_name: "Business",
    credits: 3,
    description: "Data-driven decision-making, dashboards, and applied analytics in organizational settings.",
    materials: [
      {
        file_name: "Intro-Dashboards.pptx",
        file_type: "pptx",
        upload_date: new Date("2025-09-12T08:00:00Z"),
        file_path: "/materials/BA210/Intro-Dashboards.pptx",
        file_size: NumberLong(3123456),
        meta: { visibility: "public", tags: ["dashboards", "kpi"] }
      }
    ],
    metadata: {
      level: "Undergraduate",
      semester: "Sem 2",
      prerequisites: [],
      tags: ["analytics", "dashboards", "kpi"]
    },
    updated_at: now
  },
  {
    course_code: "ENG101",
    course_name: "Academic Writing",
    department_name: "Humanities",
    credits: 2,
    description: "Research writing, argumentation, citation practices, and academic integrity.",
    materials: [
      {
        file_name: "APA-QuickGuide.pdf",
        file_type: "pdf",
        upload_date: new Date("2025-09-05T08:00:00Z"),
        file_path: "/materials/ENG101/APA-QuickGuide.pdf",
        file_size: NumberLong(880120),
        meta: { visibility: "public", tags: ["apa", "writing"] }
      }
    ],
    metadata: {
      level: "Undergraduate",
      semester: "Sem 1",
      prerequisites: [],
      tags: ["writing", "apa", "research"]
    },
    updated_at: now
  }
];

campus.course_catalogs.insertMany(courses);

const students = [
  {
    student_id: 1,
    reg_no: "AIU/PG/0001/25",
    name: { first: "Clive", last: "Aono" },
    email: "clive.aono@aiu.ac.ke",
    department_name: "Computing",
    status: "active",
    extracurricular_activities: [
      { name: "AI Club", role: "Member", hours_per_week: 3, achievements: ["Hackathon finalist"] }
    ],
    preferences: {
      notifications: { email: true, sms: false, push: true },
      ui: { theme: "dark", language: "en" },
      interests: ["databases", "security", "ai"]
    },
    enrollments: [
      { course_code: "CS501", course_name: "Advanced Database Systems", status: "enrolled", performance: null }
    ],
    activity_summary: { total_actions: 120, total_seconds: 5400, last_activity_at: now, engagement_score_30d: 72.50 },
    created_at: now
  },
  {
    student_id: 2,
    reg_no: "AIU/UG/0142/25",
    name: { first: "Amina", last: "Wanjiru" },
    email: "amina.wanjiru@aiu.ac.ke",
    department_name: "Business",
    status: "active",
    extracurricular_activities: [
      { name: "Debate Society", role: "Secretary", hours_per_week: 4, achievements: ["Best speaker 2025"] }
    ],
    preferences: {
      notifications: { email: true, sms: true, push: false },
      ui: { theme: "light", language: "en" },
      interests: ["analytics", "entrepreneurship"]
    },
    enrollments: [
      { course_code: "BA210", course_name: "Business Analytics", status: "enrolled", performance: null }
    ],
    activity_summary: { total_actions: 80, total_seconds: 3200, last_activity_at: now, engagement_score_30d: 55.25 },
    created_at: now
  },
  {
    student_id: 3,
    reg_no: "AIU/UG/0205/25",
    name: { first: "Brian", last: "Otieno" },
    email: "brian.otieno@aiu.ac.ke",
    department_name: "Humanities",
    status: "active",
    extracurricular_activities: [
      { name: "Choir", role: "Member", hours_per_week: 2, achievements: ["Campus concert lead"] }
    ],
    preferences: {
      notifications: { email: false, sms: true, push: true },
      ui: { theme: "dark", language: "en" },
      interests: ["writing", "research"]
    },
    enrollments: [
      { course_code: "ENG101", course_name: "Academic Writing", status: "enrolled", performance: null }
    ],
    activity_summary: { total_actions: 45, total_seconds: 1800, last_activity_at: now, engagement_score_30d: 31.00 },
    created_at: now
  }
];

campus.student_profiles.insertMany(students);

print("Seed counts:");
print("student_profiles = " + campus.student_profiles.countDocuments());
print("course_catalogs   = " + campus.course_catalogs.countDocuments());

// -----------------------------------------
// 5) CRUD examples with $set, $push, $inc
// -----------------------------------------
print("\n=== CRUD DEMO ===");

// READ
print("READ: Find one student by reg_no");
printjson(campus.student_profiles.findOne({ reg_no: "AIU/PG/0001/25" }));

// UPDATE ($inc)
print("UPDATE ($inc): Increment total_actions +5 and total_seconds +300 for student_id=1");
campus.student_profiles.updateOne(
  { student_id: 1 },
  { $inc: { "activity_summary.total_actions": 5, "activity_summary.total_seconds": 300 } }
);
printjson(campus.student_profiles.findOne(
  { student_id: 1 },
  { student_id: 1, "activity_summary.total_actions": 1, "activity_summary.total_seconds": 1, _id: 0 }
));

// UPDATE ($set)
print("UPDATE ($set): Set UI theme to light for student_id=1");
campus.student_profiles.updateOne(
  { student_id: 1 },
  { $set: { "preferences.ui.theme": "light" } }
);

// UPDATE ($push)
print("UPDATE ($push): Add a new extracurricular activity for student_id=2");
campus.student_profiles.updateOne(
  { student_id: 2 },
  { $push: { extracurricular_activities: { name: "Entrepreneurship Club", role: "Member", hours_per_week: 2, achievements: ["Pitch day participant"] } } }
);

// CREATE (upsert)
print("CREATE (upsert): Insert a new student if missing (student_id=4)");
campus.student_profiles.updateOne(
  { student_id: 4 },
  {
    $setOnInsert: {
      student_id: 4,
      reg_no: "AIU/UG/0999/25",
      name: { first: "Faith", last: "Njeri" },
      email: "faith.njeri@aiu.ac.ke",
      department_name: "Computing",
      status: "active",
      extracurricular_activities: [],
      preferences: { notifications: { email: true, sms: false, push: true }, ui: { theme: "dark", language: "en" }, interests: ["networks"] },
      enrollments: [],
      activity_summary: { total_actions: 0, total_seconds: 0, last_activity_at: null, engagement_score_30d: 0.0 },
      created_at: now
    }
  },
  { upsert: true }
);
print("student_profiles = " + campus.student_profiles.countDocuments());

// DELETE
print("DELETE: Remove the upserted demo student_id=4");
campus.student_profiles.deleteOne({ student_id: 4 });
print("student_profiles = " + campus.student_profiles.countDocuments());

// ----------------------------------------------------
// 6) Aggregation pipeline ($match, $group, $project)
// ----------------------------------------------------
print("\n=== AGGREGATION DEMO ($match/$group/$project) ===");
const agg = campus.student_profiles.aggregate([
  { $match: { status: "active" } },
  {
    $group: {
      _id: "$department_name",
      students: { $sum: 1 },
      avg_engagement_30d: { $avg: "$activity_summary.engagement_score_30d" }
    }
  },
  {
    $project: {
      _id: 0,
      department_name: "$_id",
      students: 1,
      avg_engagement_30d: { $round: ["$avg_engagement_30d", 2] }
    }
  }
]);
printjson(agg.toArray());

// ------------------------------
// 7) Text search (course desc.)
// ------------------------------
print("\n=== TEXT SEARCH DEMO ===");
print("Search for: 'indexing transactions'");
const textResults = campus.course_catalogs.find(
  { $text: { $search: "indexing transactions" } },
  { score: { $meta: "textScore" }, course_code: 1, course_name: 1, score: 1, _id: 0 }
).sort({ score: { $meta: "textScore" } });
printjson(textResults.toArray());

// -----------------------------
// 8) Show index inventory (proof)
// -----------------------------
print("\n=== INDEX INVENTORY (proof) ===");
print("student_profiles indexes:");
printjson(campus.student_profiles.getIndexes());
print("course_catalogs indexes:");
printjson(campus.course_catalogs.getIndexes());

print("\n=== B1 END ===");
