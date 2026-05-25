# Authentication Implementation TODOs

The remaining authentication-core implementation work is tracked in GitHub issue #574.

## Security Vulnerabilities

### Hardcoded User ID

- **Location**: `app/controllers/auth/app/setting/recoveries_controller.rb:36`
- **Issue**: Using `User.first.id` as hardcoded user_id
- **Priority**: CRITICAL
- **Security Risk**: Data exposure and incorrect user association
- **Details**: Passcodes are assigned to random users

## Additional TODOs

1. Implement the contact page.
2. Implement the functionality that relies on JWT.
3. Fix the asset pipeline so CSP no longer blocks it.
4. Configure OpenAPI now that Rswag has been added.
5. Reconfigure the Rails → Cloud Run → Cloud Load Balancer → Fastly path.
6. Configure AWS SES with the `.com`, `.app`, and `.org` domains for production once those domains
   are added.
