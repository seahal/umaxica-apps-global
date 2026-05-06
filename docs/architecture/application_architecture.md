# Application Architecture Guidelines

## Target Architecture

This project uses **MVC + Service + Form** as its standard architecture. The goal is to avoid Fat
Controllers and Fat Models by separating responsibilities along Rails conventions.

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
class UserRegistrationForm < ApplicationForm
  attribute :email, :string
  attribute :password, :string
  attribute :profile_name, :string

  validates :email, :password, :profile_name, presence: true

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      user = User.create!(email: email, password: password)
      user.create_profile!(name: profile_name)
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

### 4. `app/services` (Service)

**Role:**

- Execute complex domain logic such as payments, email delivery, and external API integration
- Act as pure Ruby transaction scripts called from controllers or background jobs

**Base class:** `ApplicationService`

**Rules:**

- Prefer a single responsibility per class.
- Expose `#call` as the primary public method.

**Example:**

```ruby
class SendWelcomeEmailService < ApplicationService
  def initialize(user:)
    @user = user
  end

  def call
    return false unless @user.active?

    # Put logic here that does not belong in the model,
    # such as external API calls or complex branching.
    Mailer.welcome(@user).deliver_now

    # Record an event on success.
    Rails.event.record("user.welcomed", user_id: @user.id)
    true
  end
end
```

**Invocation:** `SendWelcomeEmailService.call(user: current_user)`

---

## Background Processing

### `app/jobs` (Job)

**Role:**

- Run heavy work asynchronously, such as bulk updates, slow external API calls, or file generation
- Use `Solid Queue` (ActiveJob) as the backend

**Constraints:**

- Jobs should remain thin wrappers that call `Service.call` whenever possible, instead of
  reimplementing complex logic.
