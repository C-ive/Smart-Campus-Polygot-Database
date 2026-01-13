# C2 — Distributed Transaction Demo: Trade-offs (MySQL + MongoDB)

## What the demo proves
This demo intentionally creates failure windows and concurrency races to show why cross-database “atomic” commits are hard, and what patterns reduce inconsistency.

## 1) Lost Update in high-concurrency enrollment
### Naive approach (problem)
Two concurrent enroll transactions:
- read seat counter value
- compute `old + 1`
- write back `enrolled = old + 1`

Result: both writers can overwrite each other → seat counter ends incorrect even though enrollments rows exist.

### Fix
Use row locking (`SELECT ... FOR UPDATE`) so the second transaction waits and reads the updated value before writing.

**Trade-off:** locking increases correctness but reduces concurrency throughput under heavy load.

## 2) Two-Phase Commit (2PC) pattern across MySQL + MongoDB
### Pattern used
- Phase 1 PREPARE: write durable “prepare” records in BOTH databases
  - MySQL: `distributed_tx_log` + `enrollment_intents`
  - Mongo: `tx_prepares`
- Phase 2 COMMIT: materialize changes in both systems
  - MySQL: insert into `enrollments`
  - Mongo: add course to `student_profiles.enrolled_courses`

### Failure window + recovery
A simulated crash occurs after MySQL commit and before Mongo commit.
Recovery scans logs and completes the missing side to restore consistency.

**Trade-offs:**
- Stronger consistency than “naive” multi-write
- But has coordinator complexity, “in-doubt” states, and operational overhead
- True 2PC across heterogeneous systems still requires careful recovery design

## 3) Compensating Transaction (Saga)
If Mongo fails after MySQL enrollment commit, the system compensates by deleting the MySQL enrollment.

**Trade-offs:**
- Higher availability and simpler than full 2PC
- But allows temporary inconsistency and requires business-acceptable rollback semantics
- Compensation must be carefully designed (idempotent + safe)

## Conclusion
- Use locking/atomic updates to prevent local concurrency anomalies (lost updates).
- For cross-database writes:
  - 2PC-style coordination improves correctness but adds complexity.
  - Saga improves availability but accepts eventual consistency and rollback behavior.
