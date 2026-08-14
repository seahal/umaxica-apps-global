# Search Metadata and Structured Data Boundary

Status: Deferred / future consideration.

This document records direction only. It is not an implementation contract, and nothing here is
committed to the codebase. No search metadata or structured data work is scheduled by this document.
When the work is picked up, revisit every statement below against current primary sources before
designing anything.

## Purpose

Search-engine metadata is treated as a machine-readable layer that expresses:

- service identity
- brand consistency
- the meaning of a page
- site hierarchy
- multilingual coverage
- presentation quality in search results

It is not treated as a bag of SEO tricks. `<title>`, meta description, canonical URL, Open Graph,
and structured data should move toward one coherent metadata contract rather than being added ad hoc
per page or per template.

## Structured Data

Schema.org vocabulary expressed as JSON-LD is the candidate approach. Concepts likely to be relevant
include:

```text
Organization
WebSite
WebPage
BreadcrumbList
Article / BlogPosting
```

This is a candidate list, not a requirement list. Emitting every type on every page is explicitly
not the goal. Each page emits only the structured data its role actually justifies.

## Identity Layers

The design should keep these as distinct concepts rather than collapsing them into one blob:

```text
operating entity
site
service / section
individual page
```

A rough conceptual nesting:

```text
Organization
└─ WebSite
   └─ Service / Section
      └─ WebPage
```

Concrete Schema.org types, identifiers, and the relations between these layers are decided at
implementation time against the then-current specification. This document intentionally fixes no
URL, FQDN, service name, or schema property.

## Placement

If JSON-LD is adopted, it should be embedded in the HTML of the page it describes, in a form search
engines recognize as that page's structured data. Serving a standalone JSON file does not by itself
constitute a structured data implementation.

Where SSG or SSR can produce the metadata in the initial HTML, prefer that over client-side
injection.

## Per-Page Responsibility

Structured data is decided per page role, not emitted unconditionally from a shared layout.
Conceptually:

```text
site-level metadata      → the site's representative page
organization metadata    → the representative site or page
breadcrumb               → pages that sit in a hierarchy
article metadata         → article pages
```

The concrete placement rules are decided at implementation time.

## Search Metadata Scope

The following are candidates for being organized as one Search Metadata concern:

- HTML title
- meta description
- canonical URL
- hreflang
- favicon
- Open Graph and other social metadata
- sitemap
- robots directives
- breadcrumb
- structured data
- search engine notification / indexing integration

Grouping them does not mean merging them. Their purposes and specifications differ, and forcing them
into a single large metadata object is not a goal.

## Internationalization

Where multiple languages exist, keep these responsibilities separate:

- brand name
- service name
- page name
- canonical URL
- alternate language URLs
- localized strings inside structured data

Do not conflate locale with deployment environment or with domain classification. `hreflang` design
specifically is deferred to a separate discussion. See `docs/architecture/i18n.md` for the existing
locale rules.

## Implementation Boundary

Where several frameworks, repositories, or deployment units are involved, the _meaning and contract_
of metadata may be shared, but implementation code should not be forced into a shared component.

Preferred shared assets:

```text
naming
semantics
required fields
validation rules
tests
documentation
```

Framework-specific metadata APIs should use each framework's own standard mechanism.

## Out of Scope

Not implemented, and not to be implemented on the basis of this document: JSON-LD, Schema.org
markup, canonical tags, hreflang, breadcrumbs, sitemap, robots, favicon, Open Graph, any metadata
component, validation script, or SEO library.

If a defect is found in existing metadata behavior, record it as a separate candidate issue rather
than fixing it as part of this direction.

## When This Is Revisited

Consult current primary sources, roughly in this order:

1. search engine official documentation
2. Schema.org
3. W3C and other web standards
4. framework official documentation
5. trustworthy secondary sources

Search appearance and rich result behavior change over time. Do not record specific engine behavior
in this document as settled fact.

## Related

- `docs/operations/search-engine-webmaster-tools.md`
- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/architecture/i18n.md`
- `docs/reference/subdomains.md`
