# extended-markdown-adf-parser API Notes

Discovered 2026-03-24 from package version ^2.4.0.

## Import

```js
import { Parser } from 'extended-markdown-adf-parser';
```

The `Parser` class is the main entry point (also the default export). Other exports
exist (`MarkdownToAdfEngine`, `AdfToMarkdownEngine`, `EnhancedMarkdownParser`, etc.)
but `Parser` wraps them all with a convenient unified API.

## MD to ADF

```js
const parser = new Parser();
const adf = parser.markdownToAdf(markdownString);
```

- **Input:** markdown string
- **Returns:** ADF document object `{ version: 1, type: "doc", content: [...] }`
- Returns a plain JS object, not a JSON string
- Synchronous
- Async variant: `await parser.markdownToAdfAsync(md)` — same return type

## ADF to MD

```js
const md = parser.adfToMarkdown(adfObject);
```

- **Input:** ADF document object (the same shape returned by `markdownToAdf`)
- **Returns:** markdown string (no trailing newline)
- Synchronous

## Extended Syntax Support (native)

All three Confluence extension syntaxes are handled natively — no pre/post-processing needed:

### Panel

```markdown
~~~panel type=info
Content here
~~~
```

Produces ADF node: `{ type: "panel", attrs: { panelType: "info" }, content: [...] }`

Roundtrips cleanly. Note: `panelType` (not `type`) in the ADF attrs.

### Status (inline)

```markdown
{status:Draft|color:yellow}
```

Produces ADF inline node: `{ type: "status", attrs: { text: "Draft", color: "yellow" } }`

Lives inside a paragraph's content array. Roundtrips cleanly.

### Expand

```markdown
~~~expand title=Details
Content here
~~~
```

Produces ADF node: `{ type: "expand", attrs: { title: "Details" }, content: [...] }`

Roundtrips cleanly. Note: on roundtrip, unquoted title values get quoted (`title=Details` becomes `title="Details"`).

## Constructor

```js
const parser = new Parser();  // no required args; constructor.length = 1 (optional config)
```

## Other Methods

- `parser.markdownToAdfWithRecovery(md)` — returns a Promise (despite the non-async name)
- `parser.adfToMarkdownWithRecovery(adf)` — returns a Promise
- `parser.validateAdf(adf)` — validation
- `parser.validateMarkdown(md)` — validation
- `parser.getStats()` — conversion statistics

## Gotchas

1. **`adfToMarkdown` returns no trailing newline.** If you need a newline-terminated file, append `\n`.
2. **`markdownToAdfWithRecovery` returns a Promise**, not a sync result, despite no `Async` in the name.
3. **Panel attr is `panelType`**, not `type`, in ADF output.
4. **Expand title gets quoted on roundtrip**: `title=Foo` becomes `title="Foo"`. Functionally equivalent but textually different.
5. **The package handles standard markdown plus Confluence extensions** (panel, status, expand, and likely more). LaTeX math and TOC macros are NOT handled — those need our custom pre/post-processing.
