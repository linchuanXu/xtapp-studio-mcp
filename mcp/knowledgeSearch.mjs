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

// 问句里的虚词到处都有，算进去会把标题带「怎么」「how」的节顶上来。
const FILLER_TERMS = new Set([
  '怎么', '怎样', '如何', '什么', '为什', '么做', '么画', '么写', '么办', '么样', '么用', '一个', '我想', '我要', '想要',
  'how', 'what', 'why', 'the', 'an', 'to', 'of', 'in', 'on', 'for', 'and', 'or', 'is', 'are', 'do', 'does', 'can', 'my', 'it',
])

// 与 Studio 检索同一分词：中文连续段整段算一个词，再拆成两字词，
// 「游戏很卡」才能碰上正文的「游戏」和关键词的「很卡」。单个汉字太泛，不算。
export function queryTerms(needle) {
  const terms = []
  for (const word of needle.split(/[^\p{L}\p{N}_.:]+/u)) {
    for (const part of word.split(/(\p{Script=Han}+)/u)) {
      if (part.length < 2) continue
      terms.push(part)
      if (part.length > 2 && /^\p{Script=Han}+$/u.test(part)) {
        for (let index = 0; index + 2 <= part.length; index += 1) terms.push(part.slice(index, index + 2))
      }
    }
  }
  return [...new Set(terms)].filter((term) => !FILLER_TERMS.has(term))
}

// keywords 是整篇的口语检索词（作者指南 jsonc 里的 keywords），命中时这篇的每一节都加分。
export function sectionScore(section, needle, terms, keywords = '') {
  const title = section.title.toLowerCase()
  const body = section.text.toLowerCase()
  const titleHit = needle && title.includes(needle) ? 20 : 0
  const termTitle = terms.reduce((total, term) => total + (title.includes(term) ? 4 : 0), 0)
  let bodyHit = 0
  if (needle.includes(' ')) bodyHit = terms.filter((term) => body.includes(term)).length
  else if (needle && body.includes(needle)) bodyHit = 2
  else bodyHit = terms.reduce((total, term) => total + (body.includes(term) ? 1 : 0), 0)
  const keywordHit = keywords ? terms.filter((term) => keywords.includes(term)).length * 2 : 0
  return titleHit + termTitle + bodyHit + keywordHit
}

export function searchSections(content, query, keywords = '') {
  const needle = String(query || '').trim().toLowerCase()
  if (!needle) return []
  const terms = queryTerms(needle)
  const words = String(keywords || '').toLowerCase()
  return markdownSections(content)
    .map((section) => ({ section, score: sectionScore(section, needle, terms, words) }))
    .filter((row) => row.score > 0)
    .sort((a, b) => b.score - a.score || a.section.line - b.section.line)
}
