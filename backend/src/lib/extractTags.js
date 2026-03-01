/**
 * Extract hashtags from markdown content.
 * Matches #word patterns (alphanumeric + underscore).
 * Returns a deduplicated lowercase array.
 */
function extractTags(content) {
  if (!content) return []
  const matches = content.match(/#(\w+)/g) || []
  const tags = matches.map(t => t.slice(1).toLowerCase())
  return [...new Set(tags)]
}

module.exports = extractTags
