1. Your existing foundation is solid

- You already have the core models (CorporateSiteContact, CorporateSiteContactEmail,
  CorporateSiteContactTelephone) in the guest database
- You're already using encrypted fields, expires_at, and remaining_views - exactly what your
  abstract design needs
- Your SMS service with adapter pattern (SmsProviders::Base) is exactly the architecture your
  abstract spec describes
- Your Email and Telephone concerns already handle validation and normalization

2. The abstract design fits your multi-domain architecture well

- Putting this in top/com (corporate) domain makes sense
- Using the guest database for unauthenticated contact is the right choice
- You already have mailers organized by domain (email/com/, email/app/)

🤔 Practical Concerns & Gaps

1. State Machine - No Gem, Manual Implementation

# Your migration has this:

t.string :status, null: false, index: true, default: 'DEFAULT_VALUE'

# But your abstract spec wants:

start → email_pending → email_verified → phone_verified → completed

Honest take: You don't have AASM/state_machine gem. You'll need to:

- Use Rails enums (simple, testable)
- OR build a simple state machine module
- OR add a gem (but I see you avoid dependencies)

Recommendation: Rails enum + validator. Example: class CorporateSiteContact < GuestRecord enum
:status, { email_pending: "email_pending", email_verified: "email_verified", phone_verified:
"phone_verified", completed: "completed" }

    validates :status, inclusion: {
      in: statuses.keys,
      message: "%{value} is not a valid status"
    }

end

2. Anti-Abuse / CAPTCHA - Not Implemented Yet

Your CLAUDE.md mentions Rack::Attack with RACK_ATTACK_API_KEY, but: $ grep -r "Rack::Attack" config/

# → Nothing found

Honest take: You need to add:

1. Rack::Attack for rate limiting (IP-based, email-based, phone-based)
2. Turnstile/reCAPTCHA adapter interface
3. Redis integration for rate limit counters (you have Redis already ✓)

Missing: No anti-abuse implementation yet. Your abstract spec is aspirational here.

3. One-Time Token vs Existing Token Field

Your schema has: t.string :token, null: false, index: true, default: '', limit: 32

But your abstract spec wants:

- "Display once" semantics
- Store only final_token_digest
- Never persist raw token

Conflict: Your current schema stores a raw token (32 chars). You'll need to:

- Add token_digest column
- Remove indexing on raw token (defeats purpose)
- Implement "viewed_once" flag or remove token after display

4. Verification Code Storage - Missing Fields

Your abstract spec needs:

# For email verification

email_verifier_digest email_verifier_expires_at

# For phone verification

otp_digest otp_expires_at otp_attempts_left

Your current schema in corporate_site_contact_emails: t.string :email_address # ✓ t.timestamptz
:expires_at # ✓ t.integer :remaining_views # ✓

# Missing: verifier_digest, attempts_left

Honest take: You're 60% there. You need migration to add verification digest fields.

5. Typo Alert 🐛 - FIXED ✅

# File: app/models/corporate_site_contact_telephone.rb

class CorporateSiteContactTelephone # Fixed!

Typo has been corrected.

6. Telephone Concern Has Wrong Regex

# app/models/concerns/telephone.rb:12

validates :number, format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }

That's an email regex, not a phone number regex. Copy-paste error?

7. Abstract Spec is Over-Engineered for MVP

Your abstract spec has:

- Multiple adapters (Mail/SMS/CAPTCHA/Time/Clock/Crypto)
- Audit log (optional but mentioned)
- "Idempotent endpoints"
- "Opaque references or signed URLs"
- "Cooldown timers" with UI countdown

Honest take: This is senior engineer over-design. For your MVP:

- Start with concrete implementations (ActionMailer, AwsSmsService, SecureRandom)
- Add adapter interfaces only when you need to swap (you already did this for SMS ✓)
- Don't build a Clock adapter "for tests" - use travel_to in tests
- Don't build an audit log until you have a compliance requirement

Pragmatic approach:

1. MVP: Direct implementations with clear boundaries
2. V2: Extract adapters when you hit pain (SMS provider already done ✓)
3. V3: Add audit log when compliance demands it

4. Missing: Controller Layer

You have no controllers yet in top/com for the contact flow. Your abstract spec lists 8 routes: GET
/contact/new POST /contact GET /contact/verify-email

# ... etc

But you only have healths_controller.rb in top/com/.

9. Service Layer Pattern

Your existing services (AwsSmsService, AccountService, etc.) are class methods: class AwsSmsService
class << self def send_message(to:, message:, subject: nil)

Your abstract spec implies instance-based services: AntiAbuse.verify!(token:, context:) # Class
method? EmailVerifier.issue!(session:) # Instance method?

Recommendation: Stay consistent. Your codebase uses class-method services. Don't mix styles.

🎯 What I'd Actually Build (Given Your Codebase)

Phase 1 (MVP - 2-3 days):

1. Fix the typo (Telepyhone → Telephone)
2. Fix the regex in Telephone concern
3. Add missing fields to migrations (verifier digests, attempt counters)
4. Build simple Rails enum state machine (no gem)
5. Build 3 service objects (not adapters yet):
   - ContactEmailVerifier - generates codes, stores digests, validates
   - ContactPhoneVerifier - generates OTP, validates attempts
   - ContactTokenIssuer - issues one-time token, stores digest
6. Add Rack::Attack rate limiting (you already have Redis)
7. Build controllers for the 8 routes
8. Write controller tests (your existing test style)

Phase 2 (Anti-abuse - 1 day): 9. Add Turnstile gem (or recaptcha gem) 10. Wrap in thin adapter if
you really need swappability

Phase 3 (Production hardening - 1-2 days): 11. Add audit logging (separate table) 12. Add monitoring
(OpenTelemetry already configured) 13. Load testing + tune rate limits

🚨 Critical Issues to Fix Immediately

1. Typo: Telepyhone → Telephone - FIXED ✅
2. Wrong regex: Telephone concern has email regex (app/models/concerns/telephone.rb:12)
3. Missing indexes: Need indexes on email_address and telephone_number for lookups (encrypted fields
   need deterministic encryption - you already have this ✓)

💡 Architecture Suggestions

Use your existing patterns:

- ✓ Keep using GuestRecord base class
- ✓ Keep using concerns (Email, Telephone)
- ✓ Keep using class-method services (don't mix with instance-based)
- ✓ Keep using minitest style
- ✓ Keep adapter pattern only where you already have it (SMS)

New patterns needed:

- State machine: Rails enum + validator (simplest)
- Rate limiting: Rack::Attack + Redis (you have Redis)
- Verification codes: Store digests only (argon2 - you already use it)

📊 Complexity Assessment

Your abstract spec rates as:

- Conceptual complexity: 8/10 (state machine, multiple verifiers, one-time tokens)
- Implementation complexity: 6/10 (you have most building blocks)
- Over-engineering risk: 7/10 (too many adapters, too early)

Recommended: Drop it to 5/10 by:

- Using concrete implementations first
- Extract adapters only when pain occurs
- Ship MVP faster, iterate based on real usage

📝 What I'd Change in Your Abstract Spec

- Adapters (ports & drivers):
- Mail adapter (send message)
- SMS adapter (send message) ← You already have this
- CAPTCHA adapter (verify token server-side)
- Time/Clock (injectable for tests) ← Just use travel_to
- Crypto (hashing/secret management) ← Use BCrypt/Argon2 directly

* Concrete Implementations (MVP):
* ActionMailer (with your existing email/com/ structure)
* AwsSmsService (already done ✓)
* Rack::Attack + Turnstile gem
* Rails.cache for rate limiting
* Argon2 for hashing (already in Gemfile ✓)

✅ My Honest Verdict

Your abstract spec is excellent architecturally - it shows deep thinking about security, state
management, and testability.

But for your actual codebase: You're 60% there already. The spec is slightly over-engineered for
what you need right now. I'd:

1. Fix the bugs first (typo, regex)
2. Add missing columns (digests, attempts)
3. Build it simply using your existing patterns
4. Ship the MVP
5. Refactor to adapters only when you feel pain

Your team will thank you for shipping faster rather than building a perfect adapter layer that might
never need swapping.
