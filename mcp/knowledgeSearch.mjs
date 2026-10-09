const HEADING = /^(#{2,4})\s+(.+?)\s*#*\s*$/

export function markdownSections(content) {
  const lines = String(content || '').split('\n')
  const marks = []
  for (let index = 0; index < lines.length; index += 1) {
    const match = HEADING.exec(lines[index])
    if (match) marks.push({ title: match[2].trim(), line: index })
  }
  const sections = []
  const preambleEnd = marks[0]?.line ?? lines.length
  const preamble = lines.slice(0, preambleEnd).join('\n').trim()
  if (preamble) sections.push({ title: '', line: 1, text: preamble })
  for (let index = 0; index < marks.length; index += 1) {
    const end = marks[index + 1]?.line ?? lines.length
    sections.push({
      title: marks[index].title,
      line: marks[index].line + 1,
      text: lines.slice(marks[index].line, end).join('\n').trim(),
    })
  }
  return sections
}

export function sectionScore(section, needle, terms) {
  const title = section.title.toLowerCase()
  const body = section.text.toLowerCase()
  const titleHit = needle && title.includes(needle) ? 20 : 0
  const termTitle = terms.reduce((total, term) => total + (title.includes(term) ? 4 : 0), 0)
  let bodyHit = 0
  if (needle.includes(' ')) bodyHit = terms.filter((term) => body.includes(term)).length
  else if (needle && body.includes(needle)) bodyHit = 2
  else bodyHit = terms.reduce((total, term) => total + (body.includes(term) ? 1 : 0), 0)
  return titleHit + termTitle + bodyHit
}

export function searchSections(content, query) {
  const needle = String(query || '').trim().toLowerCase()
  if (!needle) return []
  const terms = [...new Set(needle.split(/[^\p{L}\p{N}_.:]+/u).filter((term) => term.length >= 2))]
  return markdownSections(content)
    .map((section) => ({ section, score: sectionScore(section, needle, terms) }))
    .filter((row) => row.score > 0)
    .sort((a, b) => b.score - a.score || a.section.line - b.section.line)
}
