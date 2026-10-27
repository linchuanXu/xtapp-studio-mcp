import assert from 'node:assert/strict'
import test from 'node:test'
import { describePreviewReady, previewCommandWaitMs, requireProjectDir } from './previewReady.mjs'

test('run 必须带当前 worktree 绝对路径', () => {
  assert.throws(() => requireProjectDir(''), /projectDir/)
  assert.equal(requireProjectDir('/Users/xu/last-ink'), '/Users/xu/last-ink')
})

test('启动预览多等一会儿，按键和截图仍用短超时', () => {
  assert.equal(previewCommandWaitMs('/preview/run'), 30_000)
  assert.equal(previewCommandWaitMs('/preview/restart'), 30_000)
  assert.equal(previewCommandWaitMs('/preview/input'), 4_000)
  assert.equal(previewCommandWaitMs('/preview/capture'), 4_000)
})

test('未打开预览页时只请用户打开链接，不报成功', () => {
  const ready = describePreviewReady({
    connectedStatus: 'not_connected',
    previewUrl: 'https://xtapp-ai-dev.xteink.cn/studio/preview?preview=1&session=abc',
    displayName: '末班墨水车',
  })
  assert.equal(ready.userStatus, 'need_login_or_open_page')
  assert.match(ready.message, /请打开这个预览页/)
  assert.match(ready.message, /session=abc/)
  assert.equal(ready.displayName, '末班墨水车')
})

test('没选过工程时提示先 run_xtapp_preview，不报未连接', () => {
  const ready = describePreviewReady({ connectedStatus: 'no_project' })
  assert.equal(ready.userStatus, 'no_project')
  assert.match(ready.message, /run_xtapp_preview/)
})

test('人读状态区分运行中、超时和页已打开', () => {
  assert.equal(describePreviewReady({
    connectedStatus: 'running',
    commandStatus: 'complete',
    previewUrl: 'https://example/preview',
    displayName: '斗地主',
  }).userStatus, 'running')
  assert.equal(describePreviewReady({
    connectedStatus: 'timeout',
    previewUrl: 'https://example/preview',
  }).userStatus, 'timeout')
  assert.equal(describePreviewReady({
    connectedStatus: 'ready',
    commandStatus: 'queued_timeout',
    previewUrl: 'https://example/preview',
  }).userStatus, 'timeout')
  assert.equal(describePreviewReady({
    connectedStatus: 'ready',
    previewUrl: 'https://example/preview',
  }).userStatus, 'page_open')
})
