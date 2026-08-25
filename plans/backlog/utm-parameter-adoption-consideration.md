# UTM Parameter Adoption Consideration

## Status

```text
Status: Under consideration
Decision: Not yet decided
Implementation: Not started
```

This note records that using UTM parameters (`utm_source`, `utm_medium`, `utm_campaign`,
`utm_content`, `utm_term`) on Umaxica Project outbound links is an available option, and organizes
the points that must be settled before any adoption decision. It is not a specification, and it does
not commit the project to adopting UTM parameters. No application code, database schema, URL
generation, analytics service, or existing link was changed for this note.

Related material:

- `docs/legal/analytics-consent-boundary.md` — consent gate that any campaign attribution analytics
  must sit behind
- `adr/publishing-db-content-authority.md`, `adr/publishing-taxonomy-architecture.md` — current
  Publishing model authority
- `adr/public-private-url-boundaries.md`, `adr/secure-jump-link-redirector.md` — current URL and
  redirect boundaries
- `docs/operations/search-engine-webmaster-tools.md` — search surface operations

## Possible Uses

- Measuring article inflow from social posts
- Measuring inflow from email and newsletter delivery
- Analyzing navigation between Docs, News, and Help
- Analyzing inflow across the multiple Umaxica-managed sites and domains
- Distinguishing individual posts, buttons, and banners that point at the same article
- Aggregating access per campaign

## Candidate Parameters

General candidates: `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`. None of
these are required; the set is a candidate list only.

A minimum candidate set, if adoption ever happens:

```text
utm_source
utm_medium
utm_campaign
```

`utm_content` would be a candidate only where posts, links, or CTAs inside the same campaign must be
distinguished. `utm_term` has no identified use yet.

## Naming Rules

Adoption would require a naming rule, because values drift without one. Realistic drift:

```text
twitter
x
x_com
```

```text
social
organic_social
social_media
```

Decisions deferred to a future adoption review:

- whether values are lowercased
- whether the word separator is `_` or `-`
- whether `twitter` or `x` is the canonical source name
- how organic distribution is distinguished from paid distribution
- whether campaign names embed a date
- whether content IDs, slugs, or Publication IDs are used as values
- which parameter expresses the site or domain

## URL And Cache

- UTM-bearing and UTM-free URLs are expected to return the same content.
- CDN and application caches must not create a separate cache entry per UTM value.
- Query strings in cache keys on Cloudflare, CloudFront, Rails, and Hono would need review for this
  effect.
- Excluding UTM parameters from cache keys would likely be necessary.
- Whether URL normalization keeps or strips UTM parameters is undecided.
- Whether redirects carry UTM parameters through is undecided.
- Whether pagination, locale switching, and sign-in transitions carry UTM parameters is undecided.

## SEO

- UTM-bearing URLs may be treated as distinct URLs by search engines.
- Candidate policy: canonical URLs point at the UTM-free URL.
- Candidate policy: sitemaps never list UTM-bearing URLs.
- Candidate policy: internal links carry no UTM parameters.
- Candidate policy: UTM parameters are limited to externally distributed links (social, email, ads).
- `robots.txt` alone does not solve URL duplication.

## Privacy And Security

- UTM values must not carry personal data.
- Email addresses, phone numbers, user IDs, session IDs, and OTP values must never appear in UTM
  values.
- URLs are recorded in browser history, `Referer` headers, access logs, and analytics services.
- Values that directly identify a user must not be used.
- Free-form input must not be passed through into UTM values.
- An allowlist or enumerated value set may be required.

Any campaign attribution built on UTM parameters is optional analytics under
`docs/legal/analytics-consent-boundary.md` and would sit behind `performant` consent.

## Data Model And Publishing Relationship

Future options, none selected. Existing `Entry`, `EntryRevision`, `EntryVersion`, `Publication`, and
taxonomy models are unchanged by this note and must not be changed on account of it.

- store UTM values on the content record itself
- manage them per Publication or per distribution channel
- manage them per distribution event (a social post, an email send)
- persist fully built UTM-bearing URLs, or generate them on demand
- keep them out of `Entry`, `EntryRevision`, `EntryVersion`, and `Publication` entirely and treat
  them as a separate distribution management concern
- do not equate content IDs with campaign IDs
- possibly separate the article URL from the measurement URL

## Implementation Candidates

Candidates only; no option is chosen.

- append UTM parameters in a URL generation helper
- add a dedicated distribution URL generation service
- select a campaign from an admin surface
- generate URLs automatically when posting to social or sending email
- disallow free-form entry and select from predefined values
- strip UTM parameters from the browser URL after sending them to the analytics pipeline
- record inflow information server-side for a limited period
- use an external URL shortener or measurement service

## Evaluation Criteria For A Future Decision

- Is access analysis actually needed?
- Can the results feed real decisions?
- Can operators sustain the naming rules?
- Do URLs stay reasonably short?
- Does it complicate CDN and cache design?
- Does the privacy policy need an addition?
- Does it create a dependency on a specific service such as Google Analytics?
- Is a data model needed to store UTM values?
- Can it be operated consistently across multiple domains?
- Is the introduction and operating cost justified?

## Open Decisions

1. Adopt UTM parameters at all, or not.
2. Parameter set: minimum three, or including `utm_content` / `utm_term`.
3. Canonical value vocabulary and casing/separator rules.
4. Canonical name for the X / Twitter source.
5. Organic versus paid distinction.
6. Whether campaign names embed dates, and which ID (content ID, slug, Publication ID) is used.
7. Which parameter expresses site or domain across the multiple Umaxica domains.
8. Cache key handling on Cloudflare, CloudFront, Rails, and Hono.
9. Normalization, redirect, and cross-navigation carry-through behavior.
10. Canonical, sitemap, and internal-link policy.
11. Allowlist or enumeration enforcement for values.
12. Where UTM data lives relative to the Publishing model, if anywhere.
13. Implementation mechanism, if adopted.
14. Privacy policy and cookie notice wording, if adopted.
