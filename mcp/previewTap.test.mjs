import assert from 'node:assert/strict'
import test from 'node:test'
import {
  describeMissingTarget,
  resolvePreviewTarget,
  tapPreviewTarget,
  targetCenter,
} from './previewTap.mjs'

test('语义目标按矩形中心转成坐标点击', () => {
  assert.deepEqual(targetCenter({ x: 10, y: 20, width: 100, height: 60 }), {
    x: 60,
    y: 50,
    width: 100,
    height: 60,
  })
})

test('可按 id 或 label 解析目标', () => {
  const targets = [{ id: 'ok', label: '确认', x: 0, y: 0, width: 40, height: 20 }]
  assert.equal(resolvePreviewTarget(targets, 'ok').id, 'ok')
  assert.equal(resolvePreviewTarget(targets, '确认').id, 'ok')
  assert.equal(resolvePreviewTarget(targets, 'missing'), null)
})

test('没有语义目标时说明改用坐标点击，不要求测试槽', () => {
  const missing = describeMissingTarget([], 'start')
  assert.equal(missing.status, 'no_targets')
  assert.match(missing.message, /Do not change the Lua to add a test slot/)
  assert.match(missing.message, /send_xtapp_preview_touch/)
})

test('tapPreviewTarget 有矩形时走 touch，没有目标时不发命令', async () => {
  const touches = []
  const hit = await tapPreviewTarget({ targetId: 'ok', gesture: 'tap' }, {
    getTargets: async () => ({
      interactiveTargets: [{ id: 'ok', label: '确认', x: 10, y: 20, width: 100, height: 60 }],
    }),
    sendTouch: async (point) => {
      touches.push(point)
      return { status: 'complete' }
    },
  })
  assert.deepEqual(touches, [{ x: 60, y: 50, gesture: 'tap' }])
  assert.equal(hit.input.targetId, 'ok')

  const empty = await tapPreviewTarget({ targetId: 'start' }, {
    getTargets: async () => ({ interactiveTargets: [] }),
    sendTouch: async () => { throw new Error('should not touch') },
  })
  assert.equal(empty.status, 'no_targets')
})
