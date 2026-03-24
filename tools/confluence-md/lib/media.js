// Manages the YAML mapping between local image filenames and Confluence media IDs.
import yaml from 'js-yaml';

export class MediaRegistry {
  #entries; // Map<id, { filename, page_id, source?, uploaded }>

  constructor(entries = new Map()) {
    this.#entries = entries;
  }

  /** Builds a registry from a YAML string (expects top-level `media:` key). */
  static fromYaml(text) {
    const data = yaml.load(text);
    const entries = new Map();
    if (data?.media) {
      for (const [id, fields] of Object.entries(data.media)) {
        entries.set(id, { ...fields, page_id: String(fields.page_id) });
      }
    }
    return new MediaRegistry(entries);
  }

  /** Returns the entry `{ id, ...fields }` matching the given filename and page ID, or null. */
  findByFilename(filename, pageId) {
    for (const [id, entry] of this.#entries) {
      if (entry.filename === filename && String(entry.page_id) === String(pageId)) {
        return { id, ...entry };
      }
    }
    return null;
  }

  /** Returns the entry `{ id, ...fields }` for the given media ID, or null. */
  findById(id) {
    const entry = this.#entries.get(id);
    return entry ? { id, ...entry } : null;
  }

  /** Registers a new media entry under the given ID. */
  add(id, fields) {
    this.#entries.set(id, { ...fields, page_id: String(fields.page_id) });
  }

  /** Serializes the registry back to a YAML string. */
  toYaml() {
    const obj = { media: {} };
    for (const [id, entry] of this.#entries) {
      obj.media[id] = entry;
    }
    return yaml.dump(obj, { lineWidth: -1 });
  }
}
