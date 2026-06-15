# Application Architecture Guidelines

## Target Architecture

This project uses **MVC + Service + Form** plus explicit domain helper objects as its standard
architecture. The goal is to avoid Fat Controllers, Fat Models, and generic "everything is a Service
Object" classes by separating responsibilities along Rails conventions.

## Responsibilities by Directory

### 1. `app/controllers` (Controller)

**Role:**

- Route incoming requests
- Accept parameters and pass them to Forms or Services
- Return responses (HTML, JSON, redirects, etc.)

**Rules:**

- Do not write business logic directly in controllers.
- Keep controller methods short.
- Delegate complex query building and multi-database persistence operations to Forms or Services.

### 2. `app/models` (Model)

**Role:**

- Behavior tied directly to the database
- Validations that depend on database structure, such as uniqueness
- Scopes and schema introspection

**Rules:**

- Keep knowledge limited to a single model.
- Do not include external API calls or transaction logic spanning multiple models.

---

### 3. `app/forms` (Form)

**Role:**

- Validate data received from requests using business rules
- Transform data across multiple models and save related records consistently

**Base class:** `ApplicationForm` (wraps `ActiveModel::Model` and `ActiveModel::Attributes`)

**Example:**

```ruby
class ClientRegistrationForm < ApplicationForm
  attribute :email, :string
  attribute :password, :string
  attribute :profile_name, :string

  validates :email, :password, :profile_name, presence: true

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      client = Client.create!(email: email, password: password)
      client.create_profile!(name: profile_name)
    end
    true
  rescue ActiveRecord::RecordInvalid
    # Handle validation errors and database constraint violations here.
    errors.add(:base, "Registration failed")
    false
  end
end
```

---

### 4. Value Objects, Resolvers, Policies, Queries, and Commands

**Role:**

- Model domain values passed around as data with immutable Value Objects.
- Assemble or derive those values with Resolvers.
- Answer authorization or decision questions with Policies.
- Keep read-only retrieval in Queries.
- Keep a single write intent in Commands.

**Rules:**

- Prefer a Value Object when a concept is primarily a domain value with behavior.
- Prefer a Resolver when the object only assembles or derives a Value Object.
- Do not create a Service Object just to hold, validate, or name a value.
- Follow `.agents/harnesses/rules/project/value-object-boundaries.mdc` before adding one of these
  object types or before adding a new Service Object.

---

### 5. `app/services` (Service)

**Role:**

- Coordinate workflows across multiple models, aggregates, transaction boundaries, external systems,
  or several business steps.
- Act as pure Ruby transaction scripts called from controllers or background jobs.

**Base class:** `ApplicationService`

**Rules:**

- Prefer a single responsibility per class.
- Expose `#call` as the primary public method.
- Keep services as orchestration. Do not use them as generic containers for domain values.

**Example:**

```ruby
class SendWelcomeEmailService < ApplicationService
  def initialize(client:)
    @client = client
  end

  def call
    return false unless @client.active?

    # Put logic here that does not belong in the model,
    # such as external API calls or complex branching.
    Mailer.welcome(@client).deliver_now

    # Record an event on success.
    Rails.logger.info(LogEvent.format("client.welcomed", client_id: @client.id))
    true
  end
end
```

**Invocation:** `SendWelcomeEmailService.call(client: current_client)`

---

## Background Processing

### `app/jobs` (Job)

**Role:**

- Run heavy work asynchronously, such as bulk updates, slow external API calls, or file generation
- Use `Solid Queue` (ActiveJob) as the backend

**Constraints:**

- Jobs should remain thin wrappers that call `Service.call` whenever possible, instead of
  reimplementing complex logic.
