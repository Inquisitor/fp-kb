---
name: New C# files need explicit UTF-8 BOM
description: When creating a new .cs file in the FP project via the Write tool, prepend the UTF-8 BOM character (U+FEFF) -- Write doesn't add it, and `.editorconfig` mandates UTF-8 BOM.
type: feedback
---

The FP project's `.editorconfig` sets UTF-8 BOM as the file encoding. When creating new `.cs` files via
the Write tool, the BOM is not added automatically -- the file is written as plain UTF-8. Visual Studio
will normalize on save, but the freshly-written file is non-conformant until then, and tools that read
the file before VS touches it (build pipelines, grep, diff viewers) may flag it.

**How to apply:** When writing a new `.cs` file (or any file the project encodes with BOM -- `.cshtml`,
`.xaml`, etc.), include the BOM as the first character of the `content` string:

```
﻿using System;
...
```

The leading character is U+FEFF (visible as the zero-width " ﻿ " in many editors). Easiest way to insert:
copy the first character of another existing project file via Read, or paste it from a known source.

**Why:** ASCII-only rule applies to *content*; BOM is *encoding*. They don't conflict.

**Verification:** `head -c 3 path/to/file.cs | xxd` should show `ef bb bf` for a BOM-prefixed file.
