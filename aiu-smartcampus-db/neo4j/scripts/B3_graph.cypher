/*
  B3: Neo4j Graph Database (aiu_smartcampus)
  Covers:
  - Academic structure (Students, Courses, Departments, Lecturers)
  - Social layer (Clubs)
  - Resource access patterns (Materials)
  - Constraints/indexes
  - Advanced Cypher queries: prerequisite path, community grouping, recommendations, influence
*/

RETURN "=== B3 START ===" AS stage;

MATCH (n) DETACH DELETE n;

//
// Constraints (uniqueness)
//
CREATE CONSTRAINT student_id_unique IF NOT EXISTS
FOR (s:Student) REQUIRE s.student_id IS UNIQUE;

CREATE CONSTRAINT student_reg_unique IF NOT EXISTS
FOR (s:Student) REQUIRE s.reg_no IS UNIQUE;

CREATE CONSTRAINT course_code_unique IF NOT EXISTS
FOR (c:Course) REQUIRE c.course_code IS UNIQUE;

CREATE CONSTRAINT dept_name_unique IF NOT EXISTS
FOR (d:Department) REQUIRE d.name IS UNIQUE;

CREATE CONSTRAINT lecturer_id_unique IF NOT EXISTS
FOR (l:Lecturer) REQUIRE l.lecturer_id IS UNIQUE;

CREATE CONSTRAINT material_id_unique IF NOT EXISTS
FOR (m:Material) REQUIRE m.material_id IS UNIQUE;

RETURN "Constraints created" AS stage;

//
// Helpful indexes / fulltext
//
CREATE INDEX course_dept_idx IF NOT EXISTS
FOR (c:Course) ON (c.department_name);

CREATE FULLTEXT INDEX course_text_idx IF NOT EXISTS
FOR (c:Course) ON EACH [c.course_name, c.description];

RETURN "Indexes created" AS stage;

//
// Seed: Departments
//
MERGE (dComp:Department {name:"Computing"});
MERGE (dBiz:Department  {name:"Business"});
MERGE (dHum:Department  {name:"Humanities"});

//
// Seed: Lecturers
//
MERGE (l1:Lecturer {lecturer_id:101, name:"Dr. Njoroge"});
MERGE (l2:Lecturer {lecturer_id:102, name:"Prof. Achieng"});

//
// Seed: Courses + prerequisite chain
//
MERGE (cs401:Course {
  course_code:"CS401",
  course_name:"Database Fundamentals",
  department_name:"Computing",
  description:"Relational design, SQL fundamentals, normalization and transactions.",
  credits:3
});

MERGE (cs501:Course {
  course_code:"CS501",
  course_name:"Advanced Database Systems",
  department_name:"Computing",
  description:"Polyglot persistence, indexing, transactions, and advanced NoSQL patterns for modern data platforms.",
  credits:3
});

MERGE (ba210:Course {
  course_code:"BA210",
  course_name:"Business Analytics",
  department_name:"Business",
  description:"Data-driven decision-making, dashboards, and applied analytics in organizational settings.",
  credits:3
});

MERGE (eng101:Course {
  course_code:"ENG101",
  course_name:"Academic Writing",
  department_name:"Humanities",
  description:"Research writing, argumentation, citation practices, and academic integrity.",
  credits:2
});

MERGE (cs501)-[:REQUIRES]->(cs401);

//
// Teaching + offering relationships
//
MATCH (c:Course)
WITH c
MATCH (d:Department {name:c.department_name})
MERGE (c)-[:OFFERED_BY]->(d);

MERGE (cs401)-[:TAUGHT_BY]->(l1);
MERGE (cs501)-[:TAUGHT_BY]->(l1);
MERGE (ba210)-[:TAUGHT_BY]->(l2);
MERGE (eng101)-[:TAUGHT_BY]->(l2);

//
// Seed: Clubs (communities)
//
MERGE (clubAI:Club {name:"AI Club"});
MERGE (clubDebate:Club {name:"Debate Society"});
MERGE (clubChoir:Club {name:"Choir"});
MERGE (clubEntre:Club {name:"Entrepreneurship Club"});

//
// Seed: Students
//
MERGE (s1:Student {
  student_id:1, reg_no:"AIU/PG/0001/25", name:"Clive Aono",
  department_name:"Computing", status:"active", engagement_score_30d:72.5
});

MERGE (s2:Student {
  student_id:2, reg_no:"AIU/UG/0142/25", name:"Amina Wanjiru",
  department_name:"Business", status:"active", engagement_score_30d:55.25
});

MERGE (s3:Student {
  student_id:3, reg_no:"AIU/UG/0205/25", name:"Brian Otieno",
  department_name:"Humanities", status:"active", engagement_score_30d:31.0
});

MERGE (s4:Student {
  student_id:4, reg_no:"AIU/UG/0999/25", name:"Faith Njeri",
  department_name:"Computing", status:"active", engagement_score_30d:60.0
});

//
// Enrollments
//
MERGE (s1)-[:ENROLLED_IN {status:"enrolled"}]->(cs501);
MERGE (s1)-[:ENROLLED_IN {status:"completed"}]->(cs401);

MERGE (s2)-[:ENROLLED_IN {status:"enrolled"}]->(ba210);

MERGE (s3)-[:ENROLLED_IN {status:"enrolled"}]->(eng101);

MERGE (s4)-[:ENROLLED_IN {status:"enrolled"}]->(cs401);
MERGE (s4)-[:ENROLLED_IN {status:"enrolled"}]->(cs501);

//
// Club memberships
//
MERGE (s1)-[:MEMBER_OF]->(clubAI);
MERGE (s2)-[:MEMBER_OF]->(clubDebate);
MERGE (s2)-[:MEMBER_OF]->(clubEntre);
MERGE (s3)-[:MEMBER_OF]->(clubChoir);
MERGE (s4)-[:MEMBER_OF]->(clubAI);
MERGE (s4)-[:MEMBER_OF]->(clubEntre);

//
// Materials + access patterns
//
MERGE (m1:Material {material_id:"CS501-W1", course_code:"CS501", title:"Week1-Polyglot.pdf", type:"pdf"});
MERGE (m2:Material {material_id:"CS501-W2", course_code:"CS501", title:"Week2-Indexing.pdf", type:"pdf"});
MERGE (m3:Material {material_id:"BA210-I1", course_code:"BA210", title:"Intro-Dashboards.pptx", type:"pptx"});

MERGE (cs501)-[:HAS_MATERIAL]->(m1);
MERGE (cs501)-[:HAS_MATERIAL]->(m2);
MERGE (ba210)-[:HAS_MATERIAL]->(m3);

MERGE (s1)-[:VIEWED {seconds:420}]->(m1);
MERGE (s1)-[:VIEWED {seconds:600}]->(m2);
MERGE (s4)-[:VIEWED {seconds:300}]->(m1);
MERGE (s2)-[:VIEWED {seconds:500}]->(m3);

RETURN "Seed complete" AS stage;

//
// Proof counts
//
MATCH (s:Student) RETURN count(s) AS students;
MATCH (c:Course)  RETURN count(c) AS courses;
MATCH (d:Department) RETURN count(d) AS departments;
MATCH (m:Material) RETURN count(m) AS materials;

//
// 1) Prerequisite path finding (chain)
//
RETURN "Query1: prerequisite chain for CS501" AS info;
MATCH p=(target:Course {course_code:"CS501"})-[:REQUIRES*1..5]->(pre:Course)
RETURN [n IN nodes(p) | n.course_code] AS prereq_path;

//
// 2) Community-style grouping (clubs as communities)
//
RETURN "Query2: club communities (members per club)" AS info;
MATCH (club:Club)<-[:MEMBER_OF]-(s:Student)
RETURN club.name AS community, count(s) AS members, collect(s.name) AS member_names
ORDER BY members DESC, community;

//
// 3) Course recommendations: courses peers take that 'Clive' isn't enrolled in
//
RETURN "Query3: recommendations for Clive (peer-enrollment based)" AS info;
MATCH (me:Student {reg_no:"AIU/PG/0001/25"})-[:ENROLLED_IN]->(cCommon:Course)
MATCH (peer:Student)-[:ENROLLED_IN]->(cCommon)
WHERE peer <> me
MATCH (peer)-[:ENROLLED_IN]->(rec:Course)
WHERE NOT (me)-[:ENROLLED_IN]->(rec)
RETURN rec.course_code, rec.course_name, count(DISTINCT peer) AS peer_support
ORDER BY peer_support DESC, rec.course_code;

// 
// 4) Influence proxy: who is most connected via shared clubs + shared courses?
//
RETURN "Query4: influence proxy (connections via shared clubs/courses)" AS info;

MATCH (a:Student)
OPTIONAL MATCH (a)-[:ENROLLED_IN]->(:Course)<-[:ENROLLED_IN]-(b:Student)
WHERE a <> b
WITH a, collect(DISTINCT b) AS coursePeers

OPTIONAL MATCH (a)-[:MEMBER_OF]->(:Club)<-[:MEMBER_OF]-(b2:Student)
WHERE a <> b2
WITH a, coursePeers, collect(DISTINCT b2) AS clubPeers

WITH a, coursePeers + clubPeers AS allPeers
UNWIND allPeers AS p
WITH a, collect(DISTINCT p) AS peers
RETURN a.reg_no AS student, a.name AS name, size(peers) AS connections
ORDER BY connections DESC, student;//
// 5) Resource access patterns: most viewed materials
//
RETURN "Query5: most viewed materials" AS info;
MATCH (:Student)-[v:VIEWED]->(m:Material)
RETURN m.material_id, m.title, count(v) AS views, round(avg(v.seconds),2) AS avg_seconds
ORDER BY views DESC, avg_seconds DESC;

RETURN "=== B3 END ===" AS stage;


