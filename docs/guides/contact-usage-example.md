# Corporate Site Contact - Usage Example

## Complete Verification Flow

This document shows how to use the new verification system in your controllers/services.

## Step 1: Create Initial Contact

```ruby
# User fills out initial form
contact = CorporateSiteContact.create!(
  category: "inquiry",
  status: "email_pending"
)

# Status: email_pending ✓
```

## Step 2: Email Verification

### Send Email Code

```ruby
# Create email record
email = contact.corporate_site_contact_emails.create!(
  email_address: "user@example.com"
)

# Generate and send code
raw_code = email.generate_verifier!
# => "123456" (6-digit code)

# Send via mailer
ContactMailer.verification_code(email.email_address, raw_code).deliver_later

# Code details:
# - Expires in 15 minutes
# - 3 attempts allowed
# - Stored as Argon2 hash (raw_code discarded after sending)
```

### Verify Email Code

```ruby
# User submits code from email
if email.verify_code(params[:code])
  # Success! Transition contact state
  contact.verify_email!
  # Status: email_verified ✓

  redirect_to phone_step_path
else
  # Failed - check why
  if email.verifier_expired?
    flash[:error] = "Code expired. Request a new one."
  elsif email.verifier_attempts_left <= 0
    flash[:error] = "Too many attempts. Request a new code."
  else
    flash[:error] = "Invalid code. #{email.verifier_attempts_left} attempts remaining."
  end

  render :verify_email
end
```

### Resend Email Code

```ruby
if email.can_resend_verifier?
  raw_code = email.generate_verifier!
  ContactMailer.verification_code(email.email_address, raw_code).deliver_later
  flash[:notice] = "New verification code sent!"
else
  flash[:error] = "Cannot resend yet. Use existing code."
end
```

## Step 3: Phone Verification

### Send OTP

```ruby
# Create phone record
phone = contact.corporate_site_contact_telephones.create!(
  telephone_number: "+1234567890"
)

# Generate and send OTP
raw_otp = phone.generate_otp!
# => "654321" (6-digit OTP)

# Send via SMS
AwsSmsService.send_message(
  to: phone.telephone_number,
  message: "Your verification code: #{raw_otp}"
)

# OTP details:
# - Expires in 10 minutes
# - 3 attempts allowed
# - Stored as Argon2 hash (raw_otp discarded after sending)
```

### Verify OTP

```ruby
# User submits OTP from SMS
if phone.verify_otp(params[:otp])
  # Success! Transition contact state
  contact.verify_phone!
  # Status: phone_verified ✓

  redirect_to details_step_path
else
  # Failed - check why
  if phone.otp_expired?
    flash[:error] = "OTP expired. Request a new one."
  elsif phone.otp_attempts_left <= 0
    flash[:error] = "Too many attempts. Request a new OTP."
  else
    flash[:error] = "Invalid OTP. #{phone.otp_attempts_left} attempts remaining."
  end

  render :verify_phone
end
```

## Step 4: Collect Details

```ruby
# User fills out title and description
topic = contact.corporate_site_contact_topics.create!(
  title: params[:title],
  description: params[:description]
)
```

## Step 5: Complete & Generate Final Token

```ruby
# Transition to completed state
contact.complete!
# Status: completed ✓

# Generate one-time token
raw_token = contact.generate_final_token
# => "7YmHxK4nTwR9BvJp2FsL6cD3Gqa8zMeN" (32 chars)

# Token details:
# - Expires in 7 days
# - Can only be viewed once
# - Stored as Argon2 hash

# Display token to user (ONE TIME ONLY!)
flash[:success] = "Your reference token: #{raw_token}"
flash[:warning] = "Save this token! It will only be shown once."
```

## Step 6: Token Verification (Later)

```ruby
# User comes back with token
contact = CorporateSiteContact.find(params[:contact_id])

if contact.verify_token(params[:token])
  # Success! Show contact details
  @contact = contact
  # Token is now marked as viewed

  render :show_contact
else
  # Failed - check why
  if contact.token_viewed?
    flash[:error] = "Token already used. Cannot view again."
  elsif contact.token_expired?
    flash[:error] = "Token expired."
  else
    flash[:error] = "Invalid token."
  end

  redirect_to root_path
end
```

## State Transition Rules

```ruby
contact.email_pending?
# ↓ verify_email!
contact.email_verified?
# ↓ verify_phone!
contact.phone_verified?
# ↓ complete!
contact.completed?
```

### Transition Guards

```ruby
# Check before transitioning
contact.can_verify_email?  # true if email_pending
contact.can_verify_phone?  # true if email_verified
contact.can_complete?      # true if phone_verified

# Transitions return false if guard fails
contact.verify_phone!  # => false (if not email_verified yet)
```

## Error Handling Pattern

```ruby
def verify_email_code
  @contact = CorporateSiteContact.find(params[:id])
  @email = @contact.corporate_site_contact_emails.last

  unless @email.verify_code(params[:code])
    handle_verification_failure(@email)
    return
  end

  unless @contact.verify_email!
    flash[:error] = "Cannot verify email at this stage"
    redirect_to root_path
    return
  end

  redirect_to phone_step_path, notice: "Email verified!"
end

private

def handle_verification_failure(email)
  @error = if email.verifier_expired?
    "Code expired"
  elsif email.verifier_attempts_left <= 0
    "Too many failed attempts"
  else
    "Invalid code (#{email.verifier_attempts_left} attempts left)"
  end

  @can_resend = email.can_resend_verifier?
  render :verify_email
end
```

## Testing Example

```ruby
test "complete verification flow" do
  # Create contact
  contact = CorporateSiteContact.create!(category: "inquiry")
  assert contact.email_pending?

  # Email verification
  email = contact.corporate_site_contact_emails.create!(email_address: "test@example.com")
  code = email.generate_verifier!
  assert email.verify_code(code)
  assert contact.verify_email!
  assert contact.email_verified?

  # Phone verification
  phone = contact.corporate_site_contact_telephones.create!(telephone_number: "+1234567890")
  otp = phone.generate_otp!
  assert phone.verify_otp(otp)
  assert contact.verify_phone!
  assert contact.phone_verified?

  # Complete
  assert contact.complete!
  assert contact.completed?

  # Token
  token = contact.generate_final_token
  assert contact.verify_token(token)
  assert contact.token_viewed?
  assert_not contact.verify_token(token) # Cannot verify twice
end
```

## Rate Limiting (Recommended)

```ruby
# config/initializers/rack_attack.rb

# Limit email verifier requests per IP
Rack::Attack.throttle("email_verifier/ip", limit: 5, period: 1.hour) do |req|
  req.ip if req.path == "/contact/verify-email" && req.post?
end

# Limit OTP requests per phone number
Rack::Attack.throttle("otp/phone", limit: 3, period: 10.minutes) do |req|
  req.params["telephone_number"] if req.path == "/contact/send-otp" && req.post?
end

# Limit token verification attempts
Rack::Attack.throttle("token/ip", limit: 10, period: 1.hour) do |req|
  req.ip if req.path == "/contact/verify-token" && req.post?
end
```

## Security Best Practices

1. **Never log raw codes/tokens**

   ```ruby
   # ❌ BAD
   Rails.logger.info "Verification code: #{raw_code}"

   # ✅ GOOD
   Rails.logger.info "Verification code sent to #{email.email_address}"
   ```

2. **Always use HTTPS in production**
   - Codes/tokens transmitted in clear text over HTTPS
   - Never send via query params (use POST body or secure cookies)

3. **Display token only once**

   ```erb
   <% if flash[:raw_token] %>
     <div class="alert alert-warning">
       <strong>Reference Token:</strong> <%= flash[:raw_token] %>
       <p>⚠️ Save this token! It will not be shown again.</p>
     </div>
   <% end %>
   ```

4. **Monitor for abuse**
   - Track failed verification attempts
   - Alert on unusual patterns (many codes to same email/phone)
   - Log state transitions for audit trail

## Performance Tips

```ruby
# Eager load associations
@contact = CorporateSiteContact
  .includes(:corporate_site_contact_emails, :corporate_site_contact_telephones)
  .find(params[:id])

# Index queries
# Already indexed:
# - corporate_site_contacts.status
# - corporate_site_contacts.category
# - corporate_site_contact_emails.verifier_expires_at
# - corporate_site_contact_telephones.otp_expires_at
# - corporate_site_contacts.token_digest
```
