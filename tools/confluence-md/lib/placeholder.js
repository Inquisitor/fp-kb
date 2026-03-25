// Manages CFMD_* placeholder tokens for LaTeX, TOC, and image extraction.
const PREFIX = 'CFMD';
const TYPE_MAP = {
  mathinl: 'MATHINL',
  mathblk: 'MATHBLK',
  toc: 'TOC',
  image: 'IMAGE',
};

export class PlaceholderMap {
  #entries = new Map();
  #counters = { mathinl: 0, mathblk: 0, toc: 0, image: 0 };

  /** Registers content under a new placeholder token and returns the token ID. */
  add(type, content) {
    if (!(type in TYPE_MAP)) throw new Error(`Unknown type: ${type}`);
    const n = ++this.#counters[type];
    const id = `${PREFIX}_${TYPE_MAP[type]}_${String(n).padStart(4, '0')}`;
    this.#entries.set(id, { type, content });
    return id;
  }

  /** Returns the entry `{ type, content }` for the given placeholder ID, or undefined. */
  get(id) {
    return this.#entries.get(id);
  }

  /** Total number of registered placeholders. */
  get size() {
    return this.#entries.size;
  }

  /** Iterates over all `[id, { type, content }]` pairs. */
  entries() {
    return this.#entries.entries();
  }

  /** Returns a global RegExp that matches any placeholder token of the given type. */
  regex(type) {
    const tag = TYPE_MAP[type];
    if (!tag) throw new Error(`Unknown type: ${type}`);
    return new RegExp(`${PREFIX}_${tag}_\\d{4}`);
  }
}
