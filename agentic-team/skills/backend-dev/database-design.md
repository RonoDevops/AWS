# Skill: Database Design & Migration

> Load this skill when: A feature requires new tables, columns, indexes,
> or data transformations. Covers schema design, migrations, and query optimization.

## Context

In 100% AI development, database mistakes are the hardest to fix. A wrong
column type, missing index, or bad relationship cascades through every query.
Get the schema right FIRST. Migrations must be reversible. Queries must be
efficient from day one — there's no DBA to optimize them later.

## Database Design Protocol

### Phase 1: Schema Design from Domain Model

Translate the Domain Expert's model into tables:

```
TRANSLATION RULES:

Domain Entity     → Table (one entity = one table)
Value Object      → Embedded columns OR separate table (if reused)
Aggregate Root    → Primary table with FK relationships
Enum              → CHECK constraint or enum type
1:1 Relationship  → FK with UNIQUE constraint
1:N Relationship  → FK on the "many" side
M:N Relationship  → Junction table

NAMING CONVENTIONS:
  Tables:     plural snake_case (users, order_lines, product_categories)
  Columns:    singular snake_case (email, created_at, user_id)
  PKs:        id (UUID, auto-generated)
  FKs:        [referenced_table_singular]_id (user_id, order_id)
  Indexes:    idx_[table]_[column(s)] (idx_users_email)
  Constraints: ck_[table]_[rule] (ck_orders_positive_total)
```

### Phase 2: Schema Specification

```sql
-- Template for each table:
CREATE TABLE [table_name] (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Business columns
    [column_name] [TYPE] [CONSTRAINTS],

    -- Foreign Keys
    [ref]_id UUID NOT NULL REFERENCES [ref_table](id) ON DELETE [action],

    -- Audit columns (EVERY table gets these)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Soft delete (if applicable)
    deleted_at TIMESTAMPTZ NULL,

    -- Constraints
    CONSTRAINT ck_[table]_[rule] CHECK ([expression])
);

-- Indexes
CREATE UNIQUE INDEX idx_[table]_[column] ON [table]([column]);
CREATE INDEX idx_[table]_[column] ON [table]([column]) WHERE deleted_at IS NULL;

-- Triggers
CREATE TRIGGER set_updated_at BEFORE UPDATE ON [table]
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

### Phase 3: Column Type Selection

```
CHOOSING THE RIGHT TYPE:

Text:
  Short string (name, email):     VARCHAR(N) with max length
  Long text (description, bio):   TEXT
  Fixed format (phone, zip):      VARCHAR(N) with CHECK regex
  Enum (status, role):            VARCHAR(20) with CHECK IN (...)

Numbers:
  Integer (quantity, count):      INTEGER (or BIGINT if > 2B)
  Money (price, total):           NUMERIC(12,2) — NEVER FLOAT
  Percentage (rate, score):       NUMERIC(5,2)
  Auto-increment:                 BIGSERIAL (but prefer UUID for PKs)

Dates/Times:
  Timestamp:                      TIMESTAMPTZ (always with timezone)
  Date only:                      DATE
  Duration:                       INTERVAL

Identifiers:
  Primary key:                    UUID (gen_random_uuid())
  External reference:             VARCHAR(255) (external IDs vary)

Boolean:
  Yes/No:                         BOOLEAN NOT NULL DEFAULT false

JSON:
  Flexible attributes:            JSONB (with GIN index if queried)

NEVER USE:
  ✗ FLOAT/DOUBLE for money (precision loss)
  ✗ TIMESTAMP without timezone (ambiguous)
  ✗ CHAR(N) (space-padded, wastes storage)
  ✗ SERIAL for distributed systems (use UUID)
```

### Phase 4: Migration Writing

```python
# Alembic migration template

"""
Migration: [description]
Date: [YYYY-MM-DD]
Ticket: [US-NNN]

Changes:
  - [What this migration does]
  - [Why]

Reversibility: YES — down() drops the table/column
Data impact: [None | Backfill required | Data transformation]
"""

def upgrade():
    op.create_table(
        'users',
        sa.Column('id', sa.UUID(), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('email', sa.String(255), nullable=False),
        sa.Column('password_hash', sa.String(255), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('role', sa.String(20), nullable=False, server_default='user'),
        sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("role IN ('user', 'admin')", name='ck_users_role'),
        sa.CheckConstraint("status IN ('pending', 'active', 'suspended')", name='ck_users_status'),
    )
    op.create_index('idx_users_email', 'users', ['email'], unique=True)
    op.create_index('idx_users_status', 'users', ['status'])


def downgrade():
    op.drop_index('idx_users_status')
    op.drop_index('idx_users_email')
    op.drop_table('users')
```

### Phase 5: Migration Safety Rules

```
SAFE MIGRATIONS (can run without downtime):
  ✓ CREATE TABLE
  ✓ ADD COLUMN with DEFAULT (nullable or server_default)
  ✓ CREATE INDEX CONCURRENTLY
  ✓ ADD CHECK CONSTRAINT NOT VALID + VALIDATE separately
  ✓ DROP unused column (verify no code references first)

DANGEROUS MIGRATIONS (require planning):
  ⚠️ ALTER COLUMN TYPE — may lock table, may lose data
  ⚠️ ADD NOT NULL column — fails if existing rows have NULL
  ⚠️ RENAME COLUMN — breaks all queries using old name
  ⚠️ DROP TABLE — irreversible data loss

SAFE PATTERN FOR ADDING NOT NULL COLUMN:
  Step 1: Add column as NULLABLE with default
  Step 2: Backfill existing rows
  Step 3: Add NOT NULL constraint

MIGRATION RULES:
  1. Every migration MUST have a downgrade
  2. Never modify a migration that's been applied
  3. One logical change per migration
  4. Test migration on a copy of production data
  5. Migrations must be idempotent (safe to retry)
```

### Phase 6: Query Performance

```
INDEX STRATEGY:
  Rule: If you query by it, index it
  Rule: If you join on it, index it (FKs)
  Rule: If you sort by it AND filter by it, composite index

  PRIMARY PATTERNS:
    Unique lookup:      UNIQUE INDEX on (email)
    Range query:        B-TREE INDEX on (created_at)
    Full-text search:   GIN INDEX on tsvector column
    JSON field query:   GIN INDEX on JSONB column
    Multi-column:       INDEX on (status, created_at DESC)

  COMPOSITE INDEX ORDER:
    Equality columns FIRST, range columns LAST
    Good: INDEX(status, created_at) for WHERE status='active' ORDER BY created_at
    Bad:  INDEX(created_at, status)

QUERY PATTERNS:
  Always use parameterized queries (prevent SQL injection)
  Always paginate list queries (LIMIT + OFFSET or cursor)
  Always select specific columns (not SELECT *)
  Always use EXISTS instead of COUNT for existence checks
  Use EXPLAIN ANALYZE on complex queries
```

## Output Format

```json
{
  "task_id": "T-001-01",
  "status": "DONE",
  "tables_created": ["users"],
  "indexes_created": ["idx_users_email", "idx_users_status"],
  "constraints": ["ck_users_role", "ck_users_status"],
  "migration_file": "migrations/versions/001_create_users_table.py",
  "reversible": true,
  "estimated_query_performance": {
    "get_by_id": "< 1ms (PK lookup)",
    "get_by_email": "< 1ms (unique index)",
    "list_by_status": "< 10ms (index + pagination)"
  }
}
```
