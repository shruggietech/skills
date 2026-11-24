# Workspace layout

Use this structure when the operator asks to establish or upgrade an instance. Reuse the existing root and move retained records in place.

```text
- AI Agent Workspace
  - ABOUT
  - PERSONAL
    - notes
  - PROJECTS
  - REFERENCE
    - Entities
    - Glossary
    - Remote Data
  - STANDARDS
```

## ABOUT

Use these two child bullets. The second is a live external link. This skill is the source of the workspace rules and templates.

- Private workspace for the operator and their authorized agents.
- [Get the latest Workflowy skill](https://github.com/shruggietech/skills/releases/latest)

## PERSONAL

Use `notes` for generic non-project work. Follow the [dated record contract](record-format.md). On an existing installation, an operator-maintained `assets` branch covers personal holdings and dealings such as property, real estate, and money. Preserve operator-maintained branches during upgrades. Start an empty instance with `notes`.

## PROJECTS

Use one branch per named project. Sort by name, ignoring case. Put project-level hashtags under `info > Tags` as individual bullet values. Put `info`, `notes`, and where applicable `spec-kit` directly under it. Use `info > Details` for durable purpose and scope, and `info > Links` for primary repository, tracker, documentation, or other verified project entry points. Use the [project template](templates/project-outline.md) and [backfill guide](project-backfill.md).

## REFERENCE

Use [the catalog contracts](shared-catalogs.md) for Entities, Glossary, and Remote Data. Sort records within each catalog by preferred name, ignoring case. Use `Tags` for each record's hashtags.

## STANDARDS

This is the operator's durable guide to applicable company and cross-project practices. Before governed work, locate the relevant topic and read its current instructions and linked authority. Apply the parts that govern the task and respect any documented scope. Put lasting requirements here when the operator asks to record a standard. Use the relevant project or Personal notes for session history. Leave the topic structure to the operator's practices.
