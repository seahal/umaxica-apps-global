# Service Layer Design Document

Last updated: 2025-11-12

## Overview

This document records the design for introducing a Service Class layer for UserService and
StaffService in a multi-database environment.

## Design Rationale

### 1. The need to separate data and logic

The current application has a complex multi-database setup, so introducing a Service Layer is
recommended for the following reasons:

#### Separation of Identity vs. Personality

- **Identity data (authentication data)**: Globally unique. Login credentials, MFA settings, and
  similar data.
- **Personality data (profile data)**: Region-specific. User settings, locale, region-specific
  information, and similar data.
- This separation improves scalability and data locality.

#### Separation of User vs. Staff

- **Different security requirements**: Staff and User use different authentication systems (SSO vs.
  OAuth, etc.).
- **Different access patterns**: Clear security boundaries and load separation are required.
- **Operational reasons**: Managing them through separate service boundaries improves security and
  workload isolation.

### 2. The role of the Service Layer

In a multi-model, multi-database environment, the Service Layer is responsible for:

#### Aggregation

- Services act as an **Aggregate Root**
- They combine multiple separated models (*Identity and *Personality) to represent a complete User
  or Staff
- They centralize business logic

#### Transaction management

- Manage distributed transactions across different databases
  - Identity database: global DB
  - Personality database: regional DB
- Ensure data consistency

#### Where design patterns belong

- **CQRS (Command Query Responsibility Segregation)**: Separate command and query responsibilities
- **Saga Pattern**: Manage consistency across separated data stores

## Current Architecture Analysis

### Database layout

The application uses more than 10 PostgreSQL databases:

```
universal      - Universal identifiers and user data
identity       - Authentication and ID management
guest          - Guest contact information
profile        - User profiles and settings
token          - Sessions and authentication tokens
business       - Business logic and entities
message        - Messaging system
notification   - Notification management
cache          - Application cache
speciality     - Domain-specific features
storage        - File storage metadata
```

Each database has a Primary/Replica pair and its own migration path (`db/{database_name}_migrate/`).

### Current model structure

#### Base classes

1. **IdentitiesRecord** (Identity database)

   ```ruby
   class IdentitiesRecord < ApplicationRecord
     self.abstract_class = true
     connects_to database: { writing: :identity, reading: :identity_replica }
   end
   ```

2. **OccurrenceRecord** (Occurrence database)

   ```ruby
   class OccurrenceRecord < ApplicationRecord
     self.abstract_class = true
     connects_to database: { writing: :occurrence, reading: :occurrence_replica }
   end
   ```

3. **ProfilesRecord** (Profile database)

   ```ruby
   class ProfilesRecord < ApplicationRecord
     self.abstract_class = true
     connects_to database: { writing: :profile, reading: :profile_replica }
   end
   ```

#### Existing identity models

##### User model

```ruby
# Identity database
class User < IdentitiesRecord
  # Authentication data
  has_secure_password algorithm: :argon2

  # Authentication methods
  has_many :user_emails
  has_many :user_telephones
  has_one :user_apple_auth
  has_one :user_google_auth
  has_many :user_sessions
  has_many :user_time_based_one_time_password
  has_many :user_webauthn_credentials
end
```

Table: `users`

- id (uuid)
- password_digest
- webauthn_id
- created_at, updated_at

##### Staff model

```ruby
# Identity database
class Staff < IdentitiesRecord
  has_secure_password algorithm: :argon2
  has_many :staff_emails
end
```

Table: `staffs`

- id (uuid)
- password_digest
- webauthn_id
- created_at, updated_at

##### Universal identity models

```ruby
# Universal database - for OTP
class UniversalUserIdentity < OccurrenceRecord
  self.table_name = "universal_user_identifiers"
end

class UniversalStaffIdentity < OccurrenceRecord
  self.table_name = "universal_staff_identifiers"
end
```

Table structure:

- id (uuid)
- otp_private_key
- last_otp_at
- created_at, updated_at

#### Related identity models

Authentication-related models:

- UserEmail, StaffEmail
- UserTelephone, StaffTelephone
- UserIdentitySocialApple, UserIdentitySocialGoogle
- UserWebauthnCredential, StaffWebauthnCredential
- UserTimeBasedOneTimePassword, StaffTimeBasedOneTimePassword
- UserHmacBasedOneTimePassword, StaffHmacBasedOneTimePassword
- UserRecoveryCode, StaffRecoveryCode

#### Profile models

Profile / Personality model tracking has been moved to GitHub issue #575.

### Domain structure

#### Web interface (WWW)

- `WWW_CORPORATE_URL` (com): corporate/client site
- `WWW_SERVICE_URL` (app): main service application
- `WWW_STAFF_URL` (org): staff administration interface

#### API endpoints

- `API_CORPORATE_URL`, `API_SERVICE_URL`, `API_STAFF_URL`

#### Controller structure

```
app/controllers/www/{com,app,org}/  - Web controllers for each domain
app/controllers/api/{com,app,org}/  - API controllers for each domain
app/controllers/concerns/           - Shared controller logic
```

### Service Layer implementation pattern

#### Basic structure

```ruby
# app/services/user_service.rb
class UserService
  # Identity + Personality aggregation
  # Transaction management
  # Business logic

  def create_user(identity_params, personality_params)
    # Distributed transaction management
  end

  def find_complete_user(id)
    # Combine Identity + Personality and return the result
  end

  def update_identity(id, params)
    # Update Identity only
  end

  def update_personality(id, params)
    # Update Personality only
  end
end

# app/services/staff_service.rb
class StaffService
  # Same implementation pattern for staff
end
```

#### Transaction strategy

We need to clarify how transactions across multiple databases should be handled:

1. **Is strong consistency (ACID) required?**
   - Both Identity and Personality succeed, or both fail
   - More complex to implement, but provides the strongest consistency

2. **Is eventual consistency acceptable?**
   - Create Identity first, then create Personality asynchronously
   - Easier to implement, but may temporarily create inconsistent states
   - Use background jobs if needed

3. **Introduce the Saga Pattern**
   - Manage multi-step transactions
   - Define compensation transactions for each step
   - Flexible, but more complex

### Applying CQRS

Separate Command (write) and Query (read):

```ruby
# Command side
class UserCommandService
  def create_user(params)
  end

  def update_identity(id, params)
  end

  def update_personality(id, params)
  end

  def delete_user(id)
  end
end

# Query side
class UserQueryService
  def find_by_id(id)
  end

  def find_by_email(email)
  end

  def list_users(filters)
  end
end
```

## Next steps (open questions)

### 1. Clarify which data should move to Personality

- What specific data or attributes should be treated as Personality?
- Where is the current data stored?
- Is this a new implementation, or a migration of existing data?

### 2. Define transaction requirements

- How much consistency is required?
- What are the performance requirements?
- What should happen on failure (retry, rollback)?

### 3. Prioritize the implementation

- Which should be implemented first, UserService or StaffService?
- What is the phased migration plan?
- What is the impact range on existing features?

### 4. Understand the authentication flow

- Confirm the details of the current User/Staff authentication flow
- Identify integration points with the Service Layer
- Determine how it connects with session management

### 5. Test strategy

- How to test in a multi-database environment
- How to test transaction management
- Scope of integration tests

## Reference information

### Current technical stack

- **Authentication**: WebAuthn, TOTP, Apple/Google OAuth, recovery codes
- **Authorization**: Pundit + Rolify
- **Background jobs**: undecided
- **Password hashing**: argon2
- **Security**: Rack::Attack (rate limiting)

### Related files

- Models: `app/models/user.rb`, `app/models/staff.rb`
- Base classes: `app/models/identities_record.rb`, `app/models/occurrence_record.rb`,
  `app/models/profiles_record.rb`
- Database config: `config/database.yml`
- Migrations: `db/identity_migrate/`, `db/occurrences_migrate/`, `db/profile_migrate/`

## Summary

Introducing a Service Class Layer is strongly recommended for the following reasons:

1. **Clear separation of responsibilities**: separation of Identity (authentication) and Personality
   (profile)
2. **Scalability**: optimal use of global and regional databases
3. **Maintainability**: centralizing business logic and improving reuse
4. **Testability**: easier testing by separating model logic from business logic
5. **Security**: improved safety through a clear boundary between User and Staff

This architecture is a mature design suitable for large, international systems and is best for
applications that prioritize security, multiple business domains, and high scalability.

---

## Change log

- 2025-11-12: Initial version created, recording the current architecture analysis and design policy
