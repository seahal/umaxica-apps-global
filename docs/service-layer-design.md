# Service Layer Design Document

Last updated: 2025-11-12

## overview

This document describes Service Classes for UserService and StaffService in a multi-database
environment. Document the Layer implementation design.

## Design rationale

### 1. The need for separation of data and logic

The current application has a complex multi-database configuration and the Service It is recommended
to introduce Layer:

#### Separation of Identity vs. Personality

- **Identity data (credentials)**: Globally unique. Login credentials, MFA settings, etc.
- **Personality data (profile)**: Region-specific. User settings, locale, region-specific
  information, etc.
- This separation improves scalability and data locality

#### Separation of User vs. Staff

- **Differences in security requirements**: Staff and User have different authentication systems
  (SSO vs OAuth, etc.)
- **Differences in access patterns**: Requires clear security boundaries and load isolation
- **Operational Reasons**: Managed in separate service boundaries for increased security and load
  isolation

### 2. Service layer role

In a multi-model, multi-database environment, the Service Layer has the following responsibilities:

#### Aggregation

- Service acts as **Aggregate Root**
- Combine multiple separate models (*Identity and *Personality) to represent a complete User or
  Staff
- Centralize business logic

#### transaction management

- Managing distributed transactions between different databases
  - Identity database: Global DB
  - Personality database: Regional DB
- Guaranteed data integrity

#### Where to implement design patterns

- **CQRS (Command Query Responsibility Segregation)**: Separation of responsibility between commands
  and queries
- **Saga Pattern**: Data integrity management across separate data stores

## Current architecture analysis

### Database configuration

Application uses 10 or more PostgreSQL databases:

```
universal - Universal identifier and user data
identity - Authentication and ID management
guest - Guest contact information
profile - User profile and settings
token - Session and authentication token
business - Business logic and entities
message - Messaging system
notification - Notification management
cache - Application cache
speciality - Domain-specific functionality
storage - File storage metadata
```

Each database has a Primary/Replica pair and has a separate migration path
(`db/{database_name}_migrate/`).

### Current model structure

#### Base class

1. **IdentitiesRecord** (Identities database)

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

#### Identity model (existing)

##### User model

```ruby
# Identity database
class User < IdentitiesRecord
  # Authentication information
  has_secure_password algorithm: :argon2

  # Authentication method
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

##### Universal Identity model

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

#### Identity database related models

Certification related:

- UserEmail, OperatorEmail
- UserTelephone, OperatorTelephone
- UserIdentitySocialApple, UserIdentitySocialGoogle
- UserWebauthnCredential, StaffWebauthnCredential
- UserTimeBasedOneTimePassword, StaffTimeBasedOneTimePassword
- UserHmacBasedOneTimePassword, StaffHmacBasedOneTimePassword
- UserRecoveryCode, StaffRecoveryCode

#### Profile model

Profile / Personality model implementation tracking has been moved to GitHub issue #575.

### domain structure

#### Web interface (WWW)

- `WWW_CORPORATE_URL` (com): Corporate/Client site
- `WWW_SERVICE_URL` (app): Main service application
- `WWW_STAFF_URL` (org): Staff management interface

#### API endpoint

- `API_CORPORATE_URL`, `API_SERVICE_URL`, `API_STAFF_URL`

#### Controller configuration

```
app/controllers/www/{com,app,org}/ - Web controller for each domain
app/controllers/api/{com,app,org}/ - API controller for each domain
app/controllers/concerns/ - Shared controller logic
```

### Service Layer implementation patterns

#### Basic structure plan

```ruby
# app/services/user_service.rb
class UserService
  # Aggregation of Identity + Personality
  # transaction management
  # business logic

  def create_user(identity_params, personality_params)
    # distributed transaction management
  end

  def find_complete_user(id)
    # Combine and return Identity + Personality
  end

  def update_identity(id, params)
    # Update only Identity
  end

  def update_personality(id, params)
    # Update only Personality
  end
end

# app/services/staff_service.rb
class StaffService
  # Similar implementation for Staff
end
```

#### transaction strategy

We need to clarify our requirements for handling transactions that span multiple databases:

1. **Do you need strong consistency (ACID)? **
   - Will both Identity and Personality succeed or both fail?
   - More complex to implement, but provides the highest data integrity

2. **Is it acceptable with eventual consistency? **
   - Create Identity first, Personality asynchronously
   - Easy to implement, but may result in temporary inconsistency
   - Use background jobs if necessary

3. **Introducing Saga Pattern**
   - Manage multi-step transactions
   - Define compensation transactions (rollback processing) for each step
   - Complex but flexible

### Applying CQRS

Separate command (write) and query (read):

```ruby
# Command side
class UserCommandService
  def create_user(params)
  def update_identity(id, params)
  def update_personality(id, params)
  def delete_user(id)
end

# Query side
class UserQueryService
  def find_by_id(id)
  def find_by_email(email)
  def list_users(filters)
end
```

## Next steps (open questions)

### 1. Clarifying the data you want to move to Personality

- What kind of data/attributes should be treated as Personality?
- Where is the current data stored?
- Is it a new implementation or migration of existing data?

### 2. Defining transaction requirements

- How consistent is required?
- What are the performance requirements?
- What should be the behavior in the event of a failure (retry, rollback)?

### 3. Implementation priority

- Which should be implemented first, UserService or StaffService?
- What is the phased migration plan?
- What is the scope of impact on existing functions?

### 4. Understanding the authentication flow

- Check details of current User/Staff authentication flow
- Identifying integration points with Service Layer
- Cooperation with session management

### 5. testing strategy

- How to test in a multi-database environment
- Transaction management testing
- Integration test scope

## Reference information

### Current technology stack

- **Authentication**: WebAuthn, TOTP, Apple/Google OAuth, passcodes
- **Authorization**: Action Policy
- **Background job**: TBA
- **Password hash**: argon2
- **Security**: Rack::Attack (rate limiting)

### Related files

- Model: `app/models/user.rb`, `app/models/staff.rb`
- Base class: `app/models/identities_record.rb`, `app/models/occurrence_record.rb`,
  `app/models/profiles_record.rb`
- Database settings: `config/database.yml`
- Migration: `db/identity_migrate/`, `db/occurrences_migrate/`, `db/profile_migrate/`

## summary

Deploying Service Class Layer is highly recommended for the following reasons:

1. **Clear separation of responsibilities**: Separation of Identity (authentication) and Personality
   (profile)
2. **Scalability**: Optimal use of global and regional DBs
3. **Maintainability**: Centralize business logic and improve reusability
4. **Testability**: Easier testing by separating the model layer and business logic layer
5. **Security**: Improved safety with clear boundaries between User and Staff

This architecture is a mature design suitable for large-scale, international systems and is ideal
for applications that prioritize security, different business domains, and high scalability.

---

## Change history

- 2025-11-12: First edition created, record of current architecture analysis and design policy
