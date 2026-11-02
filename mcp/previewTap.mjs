export function targetCenter(target = {}) {
  const x = Number(target.x) || 0
  const y = Number(target.y) || 0
  const width = Math.max(0, Number(target.width) || 0)
  const height = Math.max(0, Number(target.height) || 0)
  return {
    x: x + Math.floor(width / 2),
    y: y + Math.floor(height / 2),
    width,
    height,
  }
}

export function resolvePreviewTarget(targets = [], targetId) {
  const id = String(targetId || '').trim()
  const list = Array.isArray(targets) ? targets : []
  return list.find((item) => item?.id === id)
    || list.find((item) => String(item?.label || '') === id)
    || null
}

export function describeMissingTarget(targets, targetId) {
  const list = (Array.isArray(targets) ? targets : []).filter((item) => item?.id)
  if (!list.length) {
    return {
      status: 'no_targets',
      targetId,
      message: `The current frame has no semantic target "${targetId}". Do not change the Lua to add a test slot for this. Call capture_xtapp_preview to see the frame, then tap coordinates with send_xtapp_preview_touch.`,
      interactiveTargets: [],
    }
  }
  return {
    status: 'target_not_found',
    targetId,
    message: `No target named "${targetId}". Tappable now: ${list.map((item) => item.id).join(', ')}. You can also use send_xtapp_preview_touch.`,
    interactiveTargets: list,
  }
}

export async function tapPreviewTarget({ targetId, gesture = 'tap' } = {}, { getTargets, sendTouch } = {}) {
  const frame = await getTargets()
  if (!frame || frame.status === 'not_connected' || frame.status === 'error' || frame.ok === false) return frame
  const targets = frame.interactiveTargets || frame.targets || []
  const target = resolvePreviewTarget(targets, targetId)
  if (!target) return { ...frame, ...describeMissingTarget(targets, targetId) }
  const center = targetCenter(target)
  const result = await sendTouch({ x: center.x, y: center.y, gesture })
  return {
    ...result,
    input: {
      type: 'touch',
      x: center.x,
      y: center.y,
      gesture,
      targetId: target.id,
      label: target.label || target.id,
    },
  }
}
