import assert from 'node:assert/strict'
import test from 'node:test'
import { isInsideRoot, looksAbsolute, normalizeAbsolutePath, samePath } from './projectPath.mjs'

test('macOS / Linux 只接受 / 开头的绝对路径', () => {
  assert.equal(normalizeAbsolutePath('/Users/xu/game/', 'darwin'), '/Users/xu/game')
  assert.equal(normalizeAbsolutePath('/home/a/../b', 'linux'), '/home/b')
  assert.equal(normalizeAbsolutePath('./game', 'darwin'), '')
  assert.equal(normalizeAbsolutePath('D:\\game', 'linux'), '')
  assert.equal(normalizeAbsolutePath('', 'darwin'), '')
})

test('Windows 接受盘符、正斜杠、UNC 和 Git Bash 写法，拒绝依赖当前盘的路径', () => {
  assert.equal(normalizeAbsolutePath('D:\\XTApp\\game', 'win32'), 'D:\\XTApp\\game')
  assert.equal(normalizeAbsolutePath('D:/XTApp/game/', 'win32'), 'D:\\XTApp\\game')
  assert.equal(normalizeAbsolutePath('\\\\nas\\share\\game', 'win32'), '\\\\nas\\share\\game')
  assert.equal(normalizeAbsolutePath('/d/XTApp/game', 'win32'), 'D:\\XTApp\\game')
  assert.equal(normalizeAbsolutePath('/d', 'win32'), 'D:\\')
  assert.equal(normalizeAbsolutePath('\\XTApp\\game', 'win32'), '')
  assert.equal(normalizeAbsolutePath('D:game', 'win32'), '')
  assert.equal(normalizeAbsolutePath('game', 'win32'), '')
})

test('目录边界在各系统都按路径段判断，不靠字符串前缀', () => {
  assert.equal(isInsideRoot('/a/game', '/a/game/main.lua', 'darwin'), true)
  assert.equal(isInsideRoot('/a/game', '/a/game', 'darwin'), true)
  assert.equal(isInsideRoot('/a/game', '/a/game', 'darwin', { allowRoot: false }), false)
  assert.equal(isInsideRoot('/a/game', '/a/game2/main.lua', 'darwin'), false)
  assert.equal(isInsideRoot('/a/game', '/a/other', 'linux'), false)
  assert.equal(isInsideRoot('/a/game', '/a/game/..x/main.lua', 'linux'), true)
  assert.equal(isInsideRoot('D:\\XTApp\\game', 'D:\\XTApp\\game\\assets\\hero.xic', 'win32'), true)
  assert.equal(isInsideRoot('D:\\XTApp\\game', 'd:\\xtapp\\GAME\\main.lua', 'win32'), true)
  assert.equal(isInsideRoot('D:\\XTApp\\game', 'D:\\XTApp\\game2\\main.lua', 'win32'), false)
  assert.equal(isInsideRoot('D:\\XTApp\\game', 'E:\\XTApp\\game\\main.lua', 'win32'), false)
})

test('Windows 比较目录不分大小写，其他系统区分', () => {
  assert.equal(samePath('D:\\XTApp\\Game', 'd:\\xtapp\\game', 'win32'), true)
  assert.equal(samePath('D:/XTApp/Game', 'D:\\XTApp\\Game', 'win32'), true)
  assert.equal(samePath('/Users/xu/Game', '/Users/xu/game', 'linux'), false)
  assert.equal(samePath('', undefined, 'darwin'), true)
})

test('相对目标里任何系统的绝对写法都算越界', () => {
  for (const value of ['/etc', '\\etc', 'D:\\x', 'D:/x', 'D:x', '\\\\nas\\x']) assert.equal(looksAbsolute(value), true, value)
  for (const value of ['templates/app', 'templates\\app', 'app']) assert.equal(looksAbsolute(value), false, value)
})
