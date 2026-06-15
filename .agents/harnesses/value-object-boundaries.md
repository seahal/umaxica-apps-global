# Value Objects, Services, Resolvers, Policies, Queries, and Commands

## Purpose

This project intentionally avoids the common "everything is a Service Object" pattern.

Before introducing a new class, determine its architectural role and place it in the correct layer.

Prefer explicit domain concepts over generic service classes.

---

# Value Objects

A Value Object represents a domain value and its behavior.

A Value Object:

- Has no independent identity
- Is compared by value
- Is immutable after creation
- Contains domain-specific validation and behavior
- Does not persist itself
- Does not orchestrate workflows

Good examples:

```ruby
ActorContext
AuthenticationState
SessionIdentifier
SessionGeneration
CredentialIdentifier
RedirectDestination
ReturnVerificationResult
TenantContext
```

Prefer creating a Value Object when a concept is passed around the system as data.

Bad:

```ruby
ResolveActorService
BuildRedirectService
SessionStateService
```

Good:

```ruby
ActorContext
RedirectDestination
AuthenticationState
```

---

# Resolvers

A Resolver assembles or derives a Value Object.

A Resolver:

- Reads from one or more sources
- Produces a value
- Does not mutate persistent state
- Does not perform business workflows

Examples:

```ruby
ActorContextResolver
TenantContextResolver
AuthenticationStateResolver
```

Typical signature:

```ruby
ActorContextResolver.call(request)
# => ActorContext
```

---

# Policies

A Policy answers authorization or decision questions.

A Policy:

- Returns a decision
- Contains business rules
- Does not perform side effects
- Does not update records

Examples:

```ruby
ActorPermissionPolicy
TenantAccessPolicy
SecretIssuancePolicy
```

Typical signature:

```ruby
ActorPermissionPolicy.allowed?(actor, resource)
# => true/false
```

---

# Queries

A Query retrieves information.

A Query:

- Reads data
- Does not modify data
- May join multiple models
- May return Value Objects or DTOs

Examples:

```ruby
ActiveMembershipQuery
AvailableCredentialQuery
```

---

# Commands

A Command performs a single write operation.

A Command:

- Mutates state
- Has a clear write intent
- Does not coordinate large workflows

Examples:

```ruby
CreateSessionCommand
RevokeCredentialCommand
IncrementFailureCounterCommand
```

---

# Services

A Service coordinates workflows.

Services are intentionally rare.

A Service should exist only when at least one of the following is true:

- Multiple aggregates must be coordinated
- Multiple repositories/models are involved
- An external system must be called
- A transaction boundary must be managed
- A business workflow spans several steps

Examples:

```ruby
AcceptInvitationService
IssueRecoverySecretService
RotateRefreshTokenService
```

Services should orchestrate.

Services should not become containers for domain values.

Bad:

```ruby
SessionStateService
ActorContextService
RedirectDestinationService
AuthenticationStateService
```

These should usually be Value Objects or Resolvers.

---

# Decision Guide

Before creating a Service Object, ask:

1. Is this primarily a value?
   - Create a Value Object.

2. Does it derive or assemble a value?
   - Create a Resolver.

3. Does it answer a rule or permission question?
   - Create a Policy.

4. Is it a read operation?
   - Create a Query.

5. Is it a single write operation?
   - Create a Command.

6. Is it coordinating multiple models, aggregates, or external systems?
   - Create a Service.

If the answer is not #6, a Service Object is probably the wrong abstraction.

---

# Default Bias

When uncertain:

Prefer

```text
Value Object
→ Resolver
→ Policy
→ Query
→ Command
```

before introducing

```text
Service
```

Service Objects are the last resort, not the default abstraction.
