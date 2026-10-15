// Browser smoke test for the web login against /api/v1 (TC-0106-05, DEF-12).
// No dependencies: drives a local headless Chrome/Edge over the DevTools protocol.
//
// Prerequisites: the Laravel API and `npm run dev` are running, and the account exists.
// Usage:
//   SMOKE_EMAIL=owner@demo.test SMOKE_PASSWORD=... node scripts/smoke-login.mjs
// Optional: SMOKE_URL (default http://localhost:5173), BROWSER (path to chrome/msedge).

import { spawn } from 'node:child_process'
import { existsSync, mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const baseUrl = process.env.SMOKE_URL || 'http://localhost:5173'
const email = process.env.SMOKE_EMAIL
const password = process.env.SMOKE_PASSWORD
const port = 9333

if (!email || !password) {
  console.error('Set SMOKE_EMAIL and SMOKE_PASSWORD.')
  process.exit(2)
}

const candidates = [
  process.env.BROWSER,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
].filter(Boolean)
const browserPath = candidates.find((path) => existsSync(path))
if (!browserPath) {
  console.error('No Chrome/Edge found; set BROWSER.')
  process.exit(2)
}

const profile = mkdtempSync(join(tmpdir(), 'smoke-login-'))
const browser = spawn(browserPath, [
  '--headless=new',
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  '--no-first-run',
  'about:blank',
])

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

async function pageWebSocketUrl() {
  for (let i = 0; i < 50; i++) {
    try {
      const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()
      const page = targets.find((t) => t.type === 'page')
      if (page) return page.webSocketDebuggerUrl
    } catch {
      // browser still starting
    }
    await sleep(200)
  }
  throw new Error('Browser did not expose a page target.')
}

let nextId = 0
const pending = new Map()
function send(ws, method, params = {}) {
  const id = ++nextId
  ws.send(JSON.stringify({ id, method, params }))
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }))
}
async function evaluate(ws, expression) {
  const { result } = await send(ws, 'Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })
  return result.value
}
async function waitFor(ws, expression, label, timeoutMs = 10000) {
  const start = Date.now()
  while (Date.now() - start < timeoutMs) {
    if (await evaluate(ws, expression)) return
    await sleep(150)
  }
  throw new Error(`Timed out waiting for: ${label}`)
}

let exitCode = 1
try {
  const ws = new WebSocket(await pageWebSocketUrl())
  await new Promise((resolve, reject) => {
    ws.onopen = resolve
    ws.onerror = reject
  })
  const pageErrors = []
  ws.onmessage = (event) => {
    const message = JSON.parse(event.data)
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id)
      pending.delete(message.id)
      if (message.error) reject(new Error(message.error.message))
      else resolve(message.result)
    } else if (message.method === 'Runtime.exceptionThrown') {
      pageErrors.push(message.params.exceptionDetails.exception?.description || message.params.exceptionDetails.text)
    }
  }

  await send(ws, 'Runtime.enable')
  await send(ws, 'Page.enable')
  await send(ws, 'Page.navigate', { url: `${baseUrl}/login` })
  await waitFor(ws, "!!document.querySelector('input[name=email]')", 'login form')

  for (const [name, value] of [['email', email], ['password', password]]) {
    await evaluate(ws, `document.querySelector('input[name=${name}]').focus()`)
    await send(ws, 'Input.insertText', { text: value })
  }
  await evaluate(ws, "document.querySelector('form.auth-form').requestSubmit()")

  await waitFor(ws, "location.pathname === '/dashboard'", 'redirect to /dashboard')
  const token = await evaluate(ws, "localStorage.getItem('token')")
  const user = await evaluate(ws, "JSON.parse(localStorage.getItem('user') || 'null')")

  if (!token) throw new Error('No token stored after login.')
  if (!user || user.email !== email) throw new Error('Stored user does not match the account.')
  if (pageErrors.length) throw new Error(`Page threw: ${pageErrors.join(' | ')}`)

  console.log(`PASS login via ${baseUrl} -> /dashboard; token stored; user ${user.email} (role ${user.role}).`)
  exitCode = 0
  ws.close()
} catch (error) {
  console.error(`FAIL ${error.message}`)
} finally {
  browser.kill()
  await sleep(300)
  try {
    rmSync(profile, { recursive: true, force: true })
  } catch {
    // profile still locked by the exiting browser
  }
  process.exit(exitCode)
}
