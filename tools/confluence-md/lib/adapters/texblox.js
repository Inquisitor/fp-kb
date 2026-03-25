// texblox-macro adapter — Forge app for LaTeX rendering in Confluence Cloud.
//
// Handles: ADF node creation (outbound), ADF node recognition (inbound),
// and workarounds for plugin quirks (single-char formula fix).

const EXT_TYPE = 'com.atlassian.ecosystem';
const EXT_KEY = '446c2bb7-9a68-48a6-83f6-38fc41031264/d02fb427-8edb-4057-9783-ef5e9d32b349/static/texblox-macro';
const EXT_KEY_MARKER = 'texblox-macro';

// --- Outbound (MD → ADF): create ADF nodes ---

/**
 * Prepare a LaTeX formula for texblox rendering.
 * Wraps single-character formulas in braces to work around a texblox
 * rendering bug where very short formulas produce blank output.
 */
function prepareFormula(formula) {
  const trimmed = formula.trim();
  if (trimmed.length === 1) {
    return `{${trimmed}}`;
  }
  return formula;
}

/**
 * Create a texblox inlineExtension ADF node.
 * @param {string} formula - LaTeX formula (raw, from MD source)
 * @param {'inline'|'block'} displayMode
 * @returns {object} ADF inlineExtension node
 */
export function makeNode(formula, displayMode) {
  return {
    type: 'inlineExtension',
    attrs: {
      extensionType: EXT_TYPE,
      extensionKey: EXT_KEY,
      text: 'LaTeX Formula',
      parameters: {
        guestParams: {
          formula: prepareFormula(formula),
          displayMode,
        },
        forgeEnvironment: 'PRODUCTION',
        extensionTitle: 'LaTeX Formula',
      },
    },
  };
}

// --- Inbound (ADF → MD): recognize and extract ---

/**
 * Check if an ADF node is a texblox LaTeX node.
 */
export function isMatch(node) {
  return (
    node.type === 'inlineExtension' &&
    node.attrs?.extensionKey?.includes(EXT_KEY_MARKER)
  );
}

/**
 * Extract formula and display mode from a texblox node.
 * Reverses the single-char workaround (strips braces from `{x}` → `x`).
 * @returns {{ formula: string, displayMode: string }}
 */
export function extract(node) {
  const gp = node.attrs?.parameters?.guestParams;
  let formula = gp?.formula ?? '';
  const displayMode = gp?.displayMode ?? 'inline';

  // Reverse single-char workaround: {x} → x
  const braceMatch = formula.match(/^\{(.)\}$/);
  if (braceMatch) {
    formula = braceMatch[1];
  }

  return { formula, displayMode };
}
