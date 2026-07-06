# CLAUDE.md — configdspacecris8

Configuration repository for **DSpace-CRIS 8 (QA)** at Universidad de Santiago de Chile (USACH).
This repo contains only config files — no Java/Python source code to compile or test.

## Repository layout

| Path | Purpose |
|------|---------|
| `local.cfg` | Main local overrides (URLs, secrets). **Never commit real secrets.** |
| `dspace.cfg` | Base DSpace configuration (do not edit directly; override via `local.cfg`) |
| `modules/*.cfg` | Per-module configuration files (auth, OIDC, ORCID, LDAP, authority, etc.) |
| `spring/api/*.xml` | Spring beans for the backend API |
| `spring/rest/*.xml` | Spring beans for the REST layer |
| `spring/oai/*.xml` | Spring beans for OAI-PMH |
| `entities/relationship-types.xml` | CRIS entity relationship definitions |
| `submission-forms.xml` | Metadata input forms for item submission |
| `item-submission.xml` | Submission workflow step configuration |
| `controlled-vocabularies/` | Authority/vocabulary XML files |
| `crosswalks/` | Metadata crosswalk mappings |
| `registries/` | Metadata schema and bitstream format registries |
| `emails/` | Email templates |
| `migration/` | Database migration scripts |

## Key conventions

- **`local.cfg` is the override file.** All environment-specific settings (URLs, passwords, client secrets) go there. The `local.cfg.EXAMPLE` file is the safe template to commit.
- **Secrets policy:** `local.cfg` may contain `client_secret`, LDAP passwords, DB credentials — do **not** commit these. Use `local.cfg.EXAMPLE` or environment variables instead.
- Spring bean XML files use standard Spring Framework syntax. Beans for the same subsystem are co-located (e.g., all CRIS layout beans in `spring/api/cris-*.xml`).
- Relationship types for CRIS entities are defined in `entities/relationship-types.xml`. Authority filters for Person↔Project relations use `author_authority` (not `projectinvestigators_authority`).

## Authentication modules

Authentication stack is configured in `modules/authentication*.cfg` and the corresponding Spring beans:
- `authentication-oidc.cfg` / `spring/rest/` — OIDC (Keycloak realm-based URLs)
- `authentication-ldap.cfg` — LDAP
- `authentication-password.cfg` — local password auth
- `authentication-orcid.cfg` — ORCID integration

## Deployment context

- **Instance:** QA at `https://sic.usach.cl`
- **DSpace install dir:** `/dspacecris8`
- Changes are applied by deploying updated config files to the running DSpace instance.
- No build step required for pure config changes.

## What NOT to do

- Do not edit `dspace.cfg` directly — override keys in `local.cfg` instead.
- Do not commit `local.cfg` if it contains real secrets.
- Do not add Java, Python, or compiled artifacts to this repository.