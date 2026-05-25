# Glossary

This document summarizes domain-specific terms, abbreviations, and naming rules used in the
umaxica-apps-jit repository. Please update it as the project evolves so new contributors and
developers can understand it more easily.

---

## Basic Terms

- **Business**
  - A model that represents a service provider or legal entity. It owns related information and
    management features.

- **Guest**
  - A model that represents a service user or customer. It is linked to features such as
    reservations and inquiries.

- **Profile**
  - A model that manages detailed information about users or business entities.

- **Token**
  - A value used to manage authentication and temporary access rights.

- **Speciality**
  - A service or business specialty/category.

- **Identity**
  - Information related to authentication and authorization, including external linked IDs.

- **Notification**
  - Various notification features for users or business entities.

---

## Abbreviations and Naming Rules

- **schema**
  - A DB schema definition file. Managed separately for each domain.

- **migrate**
  - A migration file. Used for database structure changes.

- **controller / service / policy**
  - Standard Rails MVC structure. Business logic belongs in services, and authorization belongs in
    policies.

---

## Notes

- Add or revise terms and naming rules as the project progresses.
- When encountering an unfamiliar term or adding a new one, be sure to append it here.

---

Last updated: 2025-11-10
