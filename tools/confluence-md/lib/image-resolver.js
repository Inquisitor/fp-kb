// Image resolver: replaces CFMD_IMAGE_* placeholders in ADF with mediaSingle nodes.
//
// resolveImages(doc, placeholderMap, fileIdMap, pageId)
//   - fileIdMap: Map<filename, fileId> from upload or attachment lookup
//   - pageId: Confluence page ID (for collection attr)
//   - Returns: { doc, warnings[] }

const IMAGE_PLACEHOLDER_RE = /CFMD_IMAGE_\d{4}/;

/**
 * Default layout for mediaSingle nodes.
 * SVGs scale well, so we use a wide fixed-pixel layout.
 */
const MEDIA_DEFAULTS = {
  layout: 'center',
  width: 760,
  widthType: 'pixel',
};

/**
 * Walks the ADF tree and replaces paragraphs containing image placeholders
 * with mediaSingle nodes (or warning paragraphs if fileId is unavailable).
 *
 * @param {object} doc - ADF document
 * @param {PlaceholderMap} map - placeholder map from preprocessMd
 * @param {Map<string,string>} fileIdMap - filename → fileId (from upload or lookup)
 * @param {string} pageId - target Confluence page ID
 * @returns {{ doc: object, warnings: string[] }}
 */
export function resolveImages(doc, map, fileIdMap, pageId) {
  const result = JSON.parse(JSON.stringify(doc));
  const warnings = [];
  walkResolve(result, map, fileIdMap, pageId, warnings);
  return { doc: result, warnings };
}

function walkResolve(node, map, fileIdMap, pageId, warnings) {
  if (!node.content) return;

  for (let i = 0; i < node.content.length; i++) {
    const child = node.content[i];

    // Look for paragraphs whose text contains an image placeholder
    if (child.type === 'paragraph' && hasSoleImagePlaceholder(child, map)) {
      const text = child.content[0].text.trim();
      const entry = map.get(text);
      const filename = entry.content.path.split('/').pop();
      const fileId = fileIdMap.get(filename);

      if (fileId) {
        node.content[i] = buildMediaSingle(entry.content, fileId, pageId);
      } else {
        warnings.push(`Image not resolved: ${entry.content.path} (filename: ${filename})`);
        node.content[i] = buildWarningParagraph(entry.content);
      }
      continue;
    }

    // Recurse
    walkResolve(child, map, fileIdMap, pageId, warnings);
  }
}

function hasSoleImagePlaceholder(para, map) {
  if (!para.content || para.content.length !== 1) return false;
  const child = para.content[0];
  if (child.type !== 'text') return false;
  const text = child.text.trim();
  const entry = map.get(text);
  return entry?.type === 'image';
}

function buildMediaSingle(imageInfo, fileId, pageId) {
  const node = {
    type: 'mediaSingle',
    attrs: { ...MEDIA_DEFAULTS },
    content: [
      {
        type: 'media',
        attrs: {
          id: fileId,
          collection: `contentId-${pageId}`,
          type: 'file',
          alt: imageInfo.path.split('/').pop(),
        },
      },
    ],
  };

  // Add caption from alt text if present
  if (imageInfo.alt) {
    node.content.push({
      type: 'caption',
      content: [{ type: 'text', text: imageInfo.alt }],
    });
  }

  return node;
}

function buildWarningParagraph(imageInfo) {
  return {
    type: 'paragraph',
    content: [{
      type: 'text',
      text: `⚠ Image not uploaded: ${imageInfo.path}`,
      marks: [{ type: 'em' }],
    }],
  };
}
