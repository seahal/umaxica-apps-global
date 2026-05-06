# Social Login Implementation Plan

## Overview

Implement an extensible architecture that supports multiple social login providers (Google, Apple,
Facebook, etc.).

## Current State

- OAuth gems are installed (omniauth, omniauth-google-oauth2, omniauth-apple).
- Database models and migrations exist but are not enabled yet.
- Controllers and views are stubbed but not implemented.
- Routes are defined but incomplete.

## Architecture Design

### 1. Unified OAuth service layer

```
app/services/oauth/
├── base_service.rb          # shared logic
├── providers/
│   ├── google_service.rb    # Google-specific processing
│   ├── apple_service.rb     # Apple-specific processing
│   └── facebook_service.rb  # placeholder for future providers
```

**BaseService responsibilities:**

- Common OAuth flow handling.
- Normalise user data.
- Error handling.
- Logging.

**Provider-specific services:**

- Provider APIs.
- Response transformation.
- Provider-specific constraints.

### 2. Provider configuration system

```yaml
# config/oauth_providers.yml
providers:
  google:
    name: "Google"
    icon: "google"
    enabled: true
    scopes: ["email", "profile"]
  apple:
    name: "Apple"
    icon: "apple"
    enabled: true
    scopes: ["name", "email"]
  facebook:
    name: "Facebook"
    icon: "facebook"
    enabled: false
    scopes: ["email", "public_profile"]
```

### 3. Shared controller concern

```ruby
# app/views/concerns/oauth_authentication.rb
module OauthAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :validate_provider
    rescue_from OmniAuth::Error, with: :oauth_error
  end

  private

  def oauth_callback
    # Shared authentication flow for every provider
  end

  def oauth_error
    # Error handling
  end
end
```

### 4. Flexible view component

```ruby
# app/components/oauth_button_component.rb
class OauthButtonComponent < ViewComponent::Base
  def initialize(provider:, action: :authenticate, size: :medium)
    @provider = provider
    @action = action
    @size = size
  end

  private

  attr_reader :provider, :action, :size

  def provider_config
    @provider_config ||= OauthProviders.find(provider)
  end

  def oauth_path
    case action
    when :authenticate
      send("new_sign_app_authentication_#{provider}_path")
    when :register
      send("new_sign_app_registration_#{provider}_path")
    end
  end
end
```

### 5. Unified routing

```ruby
# DRY out config/routes/top.rb
OauthProviders.enabled.each do |provider|
  # Registration routes
  namespace :registration do
    resource provider.to_sym, only: [:new, :create]
  end

  # Authentication routes
  namespace :authentication do
    resource provider.to_sym, only: [:new, :create]
  end

  # Settings routes
  namespace :setting do
    resource provider.to_sym, only: [:show, :destroy]
  end
end

# OAuth callbacks
get '/sign/:provider/callback', to: 'oauth_callbacks#create'
get '/sign/failure', to: 'oauth_callbacks#failure'
```

## Implementation Steps

### Phase 1: Core infrastructure

1. **Enable database migrations**
   - Uncomment and run the Google/Apple OAuth migrations.
   - Add indexes for performance.

2. **Create the OmniAuth initializer**

   ```ruby
   # config/initializers/omniauth.rb
   Rails.application.config.middleware.use OmniAuth::Builder do
     OauthProviders.enabled.each do |provider|
       provider provider.omniauth_key,
                ENV["#{provider.env_prefix}_CLIENT_ID"],
                ENV["#{provider.env_prefix}_CLIENT_SECRET"],
                provider.omniauth_options
     end
   end
   ```

3. **Add OAuth callback routes**
   - Define the unified callback handler.
   - Provide error handling routes.

### Phase 2: Service layer

1. **Create the OAuth base service**
   - Shared authentication steps.
   - User creation/lookup.
   - Session management.

2. **Implement provider-specific services**
   - Google OAuth service.
   - Apple OAuth service.
   - Extensible for additional providers.

### Phase 3: Controller implementation

1. **Create the OAuth concern**
   - Shared controller logic.
   - Error handling.
   - Security measures.

2. **Implement controller actions**
   - Registration.
   - Authentication.
   - Account linking.

### Phase 4: UI components

1. **Create the OAuth button component**
   - Flexible design system.
   - Multiple sizes and styles.
   - Provider branding.

2. **Update authentication views**
   - Add social login options.
   - Preserve existing email/phone flows.
   - Progressive enhancement.

### Phase 5: Configuration & security

1. **Environment variable setup**
   - Client IDs and secrets.
   - Provider-specific configuration.
   - Differentiate development and production.

2. **Security enhancements**
   - CSRF protection.
   - State parameter validation.
   - Rate limiting.
