// Image downgrader: converts mediaSingle ADF nodes to image placeholders
// for the ADF→MD pipeline.
//
// downgradeImages(doc, fileIdToName) → { doc, warnings[] }
//   - fileIdToName: Map<fileId, filename> from attachments API
//   - mediaSingle nodes → paragraph with ![alt](filename) text
//   - Package can then convert that paragraph to markdown

/**
 * Finds mediaSingle nodes in the ADF tree and replaces them with
 * paragraphs containing markdown image syntax as plain text.
 * The package will emit this text as-is into the markdown output.
 *
 * @param {object} doc - ADF document
 * @param {Map<string,string>} fileIdToName - fileId → filename mapping
 * @returns {{ doc: object, warnings: string[] }}
 */
export function downgradeImages(doc, fileIdToName = new Map()) {
  const result = JSON.parse(JSON.stringify(doc));
  const warnings = [];
  walkDowngrade(result, fileIdToName, warnings);
  return { doc: result, warnings };
}

function walkDowngrade(node, fileIdToName, warnings) {
  if (!node.content) return;

  for (let i = 0; i < node.content.length; i++) {
    const child = node.content[i];

    if (child.type === 'mediaSingle') {
      const mediaNode = child.content?.find(n => n.type === 'media');
      const captionNode = child.content?.find(n => n.type === 'caption');

      if (mediaNode) {
        const fileId = mediaNode.attrs?.id;
        const alt = captionNode?.content?.[0]?.text
          || mediaNode.attrs?.alt
          || '';
        const filename = fileIdToName.get(fileId) || mediaNode.attrs?.alt || `media:${fileId}`;

        if (fileId && !fileIdToName.has(fileId)) {
          warnings.push(`Unknown media ID ${fileId}, using alt="${filename}"`);
        }

        node.content[i] = {
          type: 'paragraph',
          content: [{ type: 'text', text: `![${alt}](${filename})` }],
        };
        continue;
      }
    }

    walkDowngrade(child, fileIdToName, warnings);
  }
}
