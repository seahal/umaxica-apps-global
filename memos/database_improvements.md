# Database Improvements Needed

## Hash Partitioning Requirements

### Staff Tables

- **Location**: `db/searches_migrate/20240827130202_create_staffs.rb:7`
- **Issue**: Staff table needs hash partition implementation
- **Priority**: High
- **Details**: Current implementation lacks proper partitioning for scalability

### Email-User Relation Tables

- **Location**: `db/searches_migrate/20240829210307_create_user_email_users.rb:5`
- **Issue**: User email users table needs hash partition
- **Priority**: High

- **Location**: `db/searches_migrate/20240829210221_create_staff_email_staffs.rb:5`
- **Issue**: Staff email staffs table needs hash partition
- **Priority**: High

### Staff Column Type

- **Location**: `db/searches_migrate/20240829210221_create_staff_email_staffs.rb:9`
- **Issue**: Want to use column type=staff instead of current implementation
- **Priority**: Medium
- **Details**: Type safety improvement needed

### User Tables

- **Location**: `db/searches_migrate/20240827130201_create_users.rb:7`
- **Issue**: User table needs hash partition implementation
- **Priority**: High

### Token Tables

- **Location**: `db/tokens_migrate/20240830163631_create_user_tokens.rb:5-6`
- **Issues**:
  1. User token table needs hash partition
  2. Table structure should be aligned with ID conventions
- **Priority**: High
- **Details**: Both partitioning and schema alignment needed

## Recommendations

1. Implement consistent hash partitioning strategy across all user/staff tables
2. Standardize column types for better type safety
3. Review table structure alignment with ID conventions
4. Consider performance implications of current non-partitioned approach
