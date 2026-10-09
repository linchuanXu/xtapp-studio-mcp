import assert from 'node:assert/strict'
import test from 'node:test'
import { markdownSections, searchSections } from './knowledgeSearch.mjs'

const SAMPLE = `# 设备 UI

没有现成的按钮。选中可以整块反色。

## 圆角组合

用矩形和圆。

## 按钮

确认按钮是黑底白字，圆角 8。

## 列表

设置行宽 440、高 70。

## 界面

### 书架

三列封面，列距 16。
`

test('a button query returns the button section, not the lead', () => {
  const [best] = searchSections(SAMPLE, '按钮')
  assert.equal(best.section.title, '按钮')
  assert.match(best.section.text, /黑底白字/)
  assert.doesNotMatch(best.section.text, /没有现成/)
  assert.doesNotMatch(best.section.text, /整块反色/)
})

test('a bookshelf query returns that subsection, not the parent screen heading alone', () => {
  const [best] = searchSections(SAMPLE, '书架')
  assert.equal(best.section.title, '书架')
  assert.match(best.section.text, /列距 16/)
  assert.doesNotMatch(best.section.text, /设置行宽/)
})

test('sections stop at the next heading', () => {
  const button = markdownSections(SAMPLE).find((section) => section.title === '按钮')
  assert.equal(button.text.split('\n').at(-1), '确认按钮是黑底白字，圆角 8。')
})
