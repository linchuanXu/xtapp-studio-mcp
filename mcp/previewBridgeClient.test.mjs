import assert from 'node:assert/strict'
import test from 'node:test'
import {
  classifyPreviewBridgeError,
  describeSourceSync,
  formatDroppedAssets,
  isFailedCommand,
  isRevisionConflict,
  previewRequestTimeoutMs,
  unwrapPreviewEnvelope,
} from './previewBridgeClient.mjs'

test('envelope unwraps data and surfaces stable error codes', () => {
  assert.deepEqual(unwrapPreviewEnvelope({ ok: true, data: { status: 'queued', commandId: 'c1' } }), {
    status: 'queued',
    commandId: 'c1',
  })
  assert.throws(
    () => unwrapPreviewEnvelope({ ok: false, error: { code: 'REVISION_CONFLICT', message: '修订冲突' } }),
    (error) => error.code === 'REVISION_CONFLICT' && /修订冲突/.test(error.message),
  )
  assert.throws(() => unwrapPreviewEnvelope({ status: 'queued' }), /Invalid preview bridge response/)
})

test('connection refusal is not_connected; abort is a real timeout', () => {
  assert.deepEqual(
    classifyPreviewBridgeError({ code: 'ECONNREFUSED' }, 'https://xtapp-ai-dev.xteink.cn'),
    { status: 'not_connected', message: 'Cannot reach the Studio preview bridge: https://xtapp-ai-dev.xteink.cn' },
  )
  assert.deepEqual(
    classifyPreviewBridgeError({ name: 'AbortError' }, 'https://xtapp-ai-dev.xteink.cn'),
    {
      status: 'timeout',
      code: 'PREVIEW_TIMEOUT',
      message: 'Studio response timed out: https://xtapp-ai-dev.xteink.cn',
    },
  )
})

test('dropped assets always appear in the sync text', () => {
  assert.equal(formatDroppedAssets([{ path: 'secret.bin', reason: 'path_rejected' }]), 'Not accepted: secret.bin (path_rejected)')
  assert.match(describeSourceSync({
    status: 'queued',
    revision: 'abc',
    fileCount: 2,
    assetCount: 1,
    dropped: [{ path: 'notes/readme.txt', reason: 'path_rejected' }],
  }), /Not accepted: notes\/readme.txt \(path_rejected\)/)
})

test('failed commands include envelope and outcome errors', () => {
  assert.equal(isFailedCommand({ ok: false }), true)
  assert.equal(isFailedCommand({ status: 'error' }), true)
  assert.equal(isFailedCommand({ status: 'complete', outcome: { status: 'error' } }), true)
  assert.equal(isFailedCommand({ status: 'complete' }), false)
})

test('source posts wait two minutes; other posts stay short', () => {
  assert.equal(previewRequestTimeoutMs('/preview/source'), 120_000)
  assert.equal(previewRequestTimeoutMs('/preview/run'), 10_000)
})

test('revision conflict is a typed error, unchanged sync stays honest', () => {
  assert.equal(isRevisionConflict({ code: 'REVISION_CONFLICT' }), true)
  assert.equal(isRevisionConflict({ code: 'PREVIEW_TIMEOUT' }), false)
  assert.match(describeSourceSync({ status: 'unchanged', revision: 'abc' }), /Source unchanged/)
  assert.match(describeSourceSync({ status: 'timeout', message: 'Studio response timed out: https://example' }), /timed out/)
})
