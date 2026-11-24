# Workflowy record format

## Dated notes

Use the same contract under project and Personal `notes`.

1. Put every record directly under `notes`, oldest first. The record title is an ISO 8601 date or timestamp by itself. Give a substantive follow-up its own sibling and link the earlier record under `Related`. Keep corrections to the same record in place when they do not describe a distinct event.
2. Use the finest precision supported by the source. Preserve minutes, seconds, fractions, and the known UTC offset. Record live work in the operator's local time with the real offset. For historical work preserve the source offset or convert a known instant without losing precision. Preserve wall time if the offset is unknown and state that in `Date basis`. Use a date alone only when the source provides no finer date. Use a verified capture timestamp with `Date basis` when the event date is unknown. Flag a legacy record with neither for review.
3. Compare known instants for order. For day-only entries, place them before timed entries on that local calendar day. Keep stable source order for ties and avoid inferring a time from sibling order. Distinct events at the same instant remain distinct records.
4. Use the first three fields below on every record, then only optional fields that have values. Labels are standalone bullets, even if they have a single value. Indent each value beneath its label. Use one tag, link, or distinct item per bullet. Use nested bullets for supporting detail and keep the full account in one place.

| Field | Value |
| --- | --- |
| `Title` | Short descriptive label. |
| `Tags` | Primary project hashtag or `#personal`, with any relevant existing topic tags. One native tag per value. |
| `Details` | The substantive record, including context, reasoning, questions, and findings. Break it into readable bullets. |
| `Outcome` | Supported result or disposition when useful. |
| `Evidence` | Exact source, one link or locator per child. Use absolute external URLs. |
| `Next actions` | Follow-up work, one action per child. |
| `Related` | Direct Workflowy links to the exact related records. |
| `Recorded at` | Capture or entry timestamp when distinct and relevant. |
| `Date basis` | Meaning, source, or precision limitation when it needs explanation. |

Use [the project outline](templates/project-outline.md) for a paste-ready example. A native Workflowy date can be a standalone value when it preserves the source precision, with the exact ISO timestamp retained as the authoritative date when the widget represents a day only.

## Spec Kit

Keep one direct bullet per formal slice in code order. Use only its formal code and short title, such as `S094 Check source order`. Give each slice its own bullet even when it belongs to a release or epic.

Use label-only fields with nested values. Use `Date` for the supported authoritative integration or closeout date and `Date basis` when its meaning needs explanation. Use Pending or Unknown under `Date` when applicable and leave it out of date queries. Use `Epic` when membership is documented, with the linked epic as its own value. Use `Scope`, `Outcome`, `Evidence`, `Tags`, and `Related` when useful. Keep substantive dated narratives in `notes` and link from the slice. Put each evidence link on its own bullet.

The operator owns any future timeline. Routine agent work creates neither timeline fields or tags nor saved searches, synthesized views, or exports.
