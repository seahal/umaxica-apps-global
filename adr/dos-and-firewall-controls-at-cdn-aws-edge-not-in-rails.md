# DoS and Firewall Controls at CDN/AWS Edge, Not in Rails

Accepted: 2026-06-18

## Context

This Rails application is intended to run behind a layered AWS edge:

```text
Cloudflare DNS
-> CloudFront + AWS WAF
-> Application Load Balancer
-> ECS task
-> Puma / Rails
```

The origin is meant to be hidden structurally, not merely difficult to guess. The application origin
must not be treated as a public internet target that absorbs generic abuse, network-layer filtering,
or edge DDoS traffic. CloudFront, AWS WAF, the load balancer, and ECS networking own those
boundaries.

The repository already distinguishes request-level, surface-level, and application-level concerns.
That separation should extend to abuse mitigation:

- public HTTP abuse belongs at the CDN / WAF edge;
- origin exposure control belongs at the load balancer and security-group boundary;
- Rails should handle only application-semantic rate limiting and cheap rejection that depends on
  business identity or ceremony state.

This matters because the visible IP at each layer is not the same:

- CloudFront and the load balancer may not preserve the viewer IP in the form Rails expects.
- ALB source-IP conditions can only see the CloudFront-facing source, not the original viewer.
- Rails request IP handling depends on a trusted proxy chain and on the origin not being directly
  reachable.

Cloudflare is used here as DNS, not as the primary traffic-shaping or proxy defense boundary.
DNS-only operation must not be mistaken for active proxy-based protection.

## Decision

1. Rails application code does not own `iptables`, WAF, or Nginx-based DoS protection.
2. Network-layer and generic HTTP abuse controls are owned by CloudFront, AWS WAF, the ALB, security
   groups, and ECS networking.
3. CloudFront + AWS WAF own public-facing HTTP abuse controls such as viewer IP allow/deny, managed
   rules, coarse rate limits, bot/flood mitigation, and path-based protection.
4. The ALB is an origin gate. It must accept traffic only from CloudFront and must reject direct
   access attempts.
5. The ECS task must only accept inbound traffic from the ALB security group, must not have a public
   IP, and must not expose Puma/Rails on `0.0.0.0/0`.
6. Rails owns only semantic rate limiting and other application-aware rejection logic.
7. Origin hiding is a structural requirement, not a DNS-obscurity suggestion.

## Boundary Definition

### CloudFront + AWS WAF

Own:

- viewer IP allow/deny
- managed rules
- coarse rate limit
- bot and flood mitigation
- path-based protection
- public-facing HTTP defense

### ALB

Own:

- receiving origin requests only from CloudFront
- rejecting direct ALB access
- using CloudFront origin-facing prefix list or equivalent security-group restriction
- validating a secret custom header from CloudFront in listener rules and returning `403` when
  absent
- not acting as the primary viewer-IP policy engine

### ECS task

Own:

- no public IP
- inbound only from the ALB security group
- no direct `0.0.0.0/0` exposure for Puma/Rails
- no task-local `iptables` construction as the primary defense boundary

### Rails

Own:

- semantic rate limiting
- cheap application-level rejection that depends on request meaning, account state, or ceremony
  state
- no dependence on WAF, Nginx, or local firewall rules for basic survivability

Semantic rate-limit keys should prefer business meaning over raw IP alone when possible. Suitable
keys include `client_id`, `identity_id`, `account_id`, `session_id`, `email_hmac`,
`refresh_token_family_id`, credential id, and organization id. If IP is part of the policy, it is a
secondary signal, not the only key.

The semantic rate-limit store must be shared across ECS tasks. MemoryStore-based designs are not
acceptable for the production boundary because they would split limits per task.

## Consequences

### Positive

- Rails stays focused on application behavior instead of absorbing network abuse.
- ECS tasks and Puma are not treated as a DDoS absorption layer.
- The defense boundary is easier to reason about because CloudFront/WAF, ALB, security groups, and
  Rails each have one clear owner.
- Application-layer abuse can be shaped with business knowledge.
- The design avoids operational dependence on Nginx tuning or kernel firewall configuration inside
  the task.

### Negative

- If CloudFront, AWS WAF, the ALB, or security-group configuration is wrong, Rails will not rescue
  the deployment.
- ALB direct-access prevention becomes an IaC requirement, not a Rails concern.
- Rails IP-based checks must account for the trusted proxy chain and the possibility of a wrong
  source-IP interpretation.
- Shared-store semantic rate limiting is required.
- Cloudflare DNS-only must not be mistaken for a defense layer.
- IPv4 and IPv6 policy must stay aligned across CloudFront, ALB, WAF, security groups, and IP sets.

## Accident Risks

### ALB direct access bypass

If the ALB DNS name is reachable directly, CloudFront WAF can be bypassed. The design therefore
requires both security-group restriction to CloudFront origin-facing ranges and a secret custom
header check at the ALB listener.

### Source IP misinterpretation

CloudFront -> ALB -> Rails can expose different source-IP views. ALB source-IP conditions do not
represent viewer IP when CloudFront is in front. If Rails uses `request.remote_ip` or
`X-Forwarded-For` in a rate-limit key, the trusted proxy chain and the ALB direct-access block are
preconditions.

### Cloudflare role confusion

Cloudflare is a DNS provider in this design. DNS-only operation does not provide the proxy-based
WAF/DDoS behavior expected from CloudFront + AWS WAF.

### IPv6 gaps

IPv4-only restriction is insufficient if IPv6 remains open. The CloudFront, ALB, WAF, security
group, and IP-set policy must be aligned for both address families.

### Internal endpoint exposure

Only the minimum `/health` contract should remain reachable internally. Operational endpoints such
as `/health/readiness`, `/metrics`, `/admin`, `/sidekiq`, `/rails/info`, and `__dev` routes must not
be public in production.

## Related

- `docs/operations/health-check.md`
- `docs/architecture/controller-boundaries.md`
- `docs/security/credential-abuse-rate-limits.md`
- `docs/reference/health-endpoints.md`
- `adr/internal-health-endpoint-edge-isolation.md`
- `adr/public-controller-base.md`
