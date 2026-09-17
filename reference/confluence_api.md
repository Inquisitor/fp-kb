---
name: Confluence API and tooling
description: What the Confluence tooling does — page and database reads, in-place node edits, body rewrites, markdown fidelity, size limits — plus REST endpoints, auth and the anchor-link format
type: reference
---

Claims here describe an external system and carry the date they were observed, so they expire. Before working
around a stated limit, follow [external_claims_recheck](external_claims_recheck.md): the due date lives in the
memory register, and a re-check is asked for rather than taken on your own initiative.

## What the tooling does

- **Pages** read as html, markdown, outline or summary. A markdown read renders neither date macros, nor
  panels, nor task lists, so it verifies wording but never layout. *(2026-09-17)*
- **Databases** read as CSV — field definitions, then views, then one row per record. *(2026-09-17)* Writing
  to one takes a CSV edit envelope; not yet exercised, so treat it as untested.
- **In-place edits** replace a node named by its `data-local-id` and leave everything else alone. This is the
  only safe way to change a page someone has formatted by hand. Not every page carries those ids — of two
  pages published from the same account, one had them and the other did not. *(2026-09-17)*
- **Body rewrites** re-create every node from the supplied markup and silently discard manual formatting; see
  [confluence_edit_preserves_layout](../feedback/confluence_edit_preserves_layout.md).
- **Read size**: a response of roughly 58 KB exceeded the tool's output limit and was spilled to a file to be
  sliced. *(2026-09-17)*
- **Write size**: bodies of roughly 25 KB publish without trouble. An older claim held that the then-current
  update tool could not handle ADF bodies beyond ~76 KB, with direct REST calls as the workaround; the tool has
  been replaced since and the threshold has not been re-tested. *(claim from 2026-05, unverified)*

## REST API v2

- Endpoint `https://{site}/wiki/api/v2/pages/{pageId}`; basic auth with `email:api-token`, base64-encoded
- ADF body: `body.representation = "atlas_doc_format"`, `body.value` a JSON string
- Fetch the current version first, then PUT with `version.number + 1`
- Credentials at `~/.config/confluence/credentials`; tokens issued through the Atlassian account security page

## Formatting

- **SVG renders inline** as `mediaSingle` → `media` with `type: "file"`, contrary to documentation claiming it
  can only appear as a download link. *(observed on the Bite System page)*
- **`contentFormat: "markdown"`** simplifies publishing but drops panels, status, expand and math. Use ADF or
  HTML for full fidelity.
- **Anchor links** follow the TOC macro: `#Heading-Title` — title case, spaces to dashes, special characters
  URL-encoded. `## Zone Fraction` → `#Zone-Fraction`; `## Scope: Which Forms and Edges` →
  `#Scope%3A-Which-Forms-and-Edges`.
