/*
 * Browser smoke test of the production build. Not part of `pnpm check` because it
 * needs a browser; run it before a release or after touching Live/Plan/PWA code.
 *
 *   pnpm build
 *   npx vite preview --port 4173 --strictPort &
 *   node scripts/smoke.cjs http://127.0.0.1:4173/
 *
 * Needs `playwright` resolvable (global install or `pnpm add -D playwright` +
 * `npx playwright install chromium`). Screenshots go to .smoke-shots/ (gitignored).
 * Each step prints ok/FAIL; the process exits non-zero on any failure.
 */
const { chromium, devices } = require('playwright')
const fs = require('fs')
const path = require('path')

const base = process.argv[2] || 'http://127.0.0.1:4173/'
const shots = path.resolve(__dirname, '..', '.smoke-shots')
fs.mkdirSync(shots, { recursive: true })
const shot = name => path.join(shots, name)

;(async () => {
  const browser = await chromium.launch()
  const ctx = await browser.newContext({ ...devices['iPhone 13'], deviceScaleFactor: 1 })
  const page = await ctx.newPage()
  const errors = []
  page.on('pageerror', e => errors.push('pageerror: ' + e.message))
  page.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()) })
  const failed = []
  page.on('requestfailed', r => failed.push(r.url() + ' ' + (r.failure()?.errorText ?? '')))

  const step = async (name, fn) => { try { await fn(); console.log('ok   ', name) } catch (e) { console.log('FAIL ', name, '-', e.message); process.exitCode = 1 } }

  await step('home loads and seeds', async () => {
    await page.goto(base, { waitUntil: 'networkidle' })
    await page.waitForSelector('h1:has-text("Jimmy")', { timeout: 15000 })
    await page.waitForSelector('.card.routine', { timeout: 15000 })
    const n = await page.locator('.card.routine').count()
    if (n < 4) throw new Error('expected seeded routines, got ' + n)
    await page.screenshot({ path: shot('01-home.png') })
  })

  await step('history shows seeded workouts', async () => {
    if (!(await page.locator('text=History').count())) throw new Error('no History section')
  })

  await step('open a routine (lazy Plan chunk)', async () => {
    await page.locator('.card.routine').first().click()
    await page.waitForSelector('button:has-text("Start workout")', { timeout: 15000 })
    await page.screenshot({ path: shot('02-plan.png') })
  })

  await step('order & groups page (lazy Overview chunk)', async () => {
    await page.locator('a:has-text("Order & groups")').click()
    await page.waitForSelector('button:has-text("Group…")', { timeout: 15000 })
    await page.screenshot({ path: shot('03-overview.png') })
    await page.goBack()
    await page.waitForSelector('button:has-text("Start workout")')
  })

  await step('start a workout and land on Live', async () => {
    await page.locator('button:has-text("Start workout")').click()
    await page.waitForSelector('.exercise', { timeout: 15000 })
    await page.waitForSelector('.timer')
    await page.screenshot({ path: shot('04-live.png') })
  })

  await step('timer advances', async () => {
    const a = await page.locator('.timer').first().textContent()
    await page.waitForTimeout(1500)
    const b = await page.locator('.timer').first().textContent()
    if (a === b) throw new Error('timer did not advance: ' + a)
  })

  await step('open weight wheel, tap a value, see it in the row', async () => {
    const first = page.locator('.exercise').first()
    await first.locator('.field').nth(0).click()
    await page.waitForSelector('.wheel')
    const opt = page.locator('.wheel .opt', { hasText: /^40$/ }).first()
    await opt.scrollIntoViewIfNeeded()
    await opt.click()
    await page.waitForTimeout(300)
    await page.locator('button:has-text("Done")').click()
    await page.waitForSelector('.wheel', { state: 'detached' })
    const txt = await first.locator('.field').nth(0).textContent()
    if (!txt.includes('40')) throw new Error('weight not written: ' + txt)
    await page.screenshot({ path: shot('05-weight.png') })
  })

  await step('reload keeps the workout in progress and the value', async () => {
    await page.reload({ waitUntil: 'networkidle' })
    await page.waitForSelector('.exercise', { timeout: 15000 })
    const txt = await page.locator('.exercise').first().locator('.field').nth(0).textContent()
    if (!txt.includes('40')) throw new Error('weight lost after reload: ' + txt)
  })

  await step('back to home shows IN PROGRESS and no redirect loop', async () => {
    await page.locator('a[aria-label="Home"]').first().click()
    await page.waitForSelector('text=IN PROGRESS', { timeout: 10000 })
  })

  await step('settings page (lazy chunk) shows version', async () => {
    await page.goto(base + '#/settings', { waitUntil: 'networkidle' })
    await page.waitForSelector('text=/Jimmy v\\d/', { timeout: 15000 })
    await page.screenshot({ path: shot('06-settings.png') })
  })

  await step('library page (lazy chunk)', async () => {
    await page.goto(base + '#/library', { waitUntil: 'networkidle' })
    await page.waitForSelector('h1:has-text("Exercises")', { timeout: 15000 })
  })

  await step('unknown routine id does not crash', async () => {
    await page.goto(base + '#/plan/does-not-exist', { waitUntil: 'networkidle' })
    await page.waitForSelector('text=Routine not found', { timeout: 15000 })
  })

  await step('news draft is off by default, on with flag', async () => {
    await page.goto(base + '#/news', { waitUntil: 'networkidle' })
    await page.waitForSelector('h1:has-text("Jimmy")', { timeout: 15000 }) // unknown route falls back to Home
    await page.evaluate(() => localStorage.setItem('jimmy.flags', JSON.stringify({ news: true, pose3d: true })))
    await page.reload({ waitUntil: 'networkidle' }) // flags are read once at startup
    await page.goto(base + '#/news', { waitUntil: 'networkidle' })
    await page.waitForSelector('h1:has-text("News")', { timeout: 15000 })
    await page.waitForSelector('.news-rank', { timeout: 15000 })
    await page.screenshot({ path: shot('07-news.png') })
    await page.locator('.news-rank').first().click()
    await page.waitForSelector('text=Favourite exercises', { timeout: 15000 })
    await page.screenshot({ path: shot('08-athlete.png') })
  })

  await step('pose3d draft renders on a curl card when flagged', async () => {
    await page.goto(base + '#/', { waitUntil: 'networkidle' })
    await page.locator('.card.routine', { hasText: 'Biceps' }).first().click()
    await page.waitForSelector('button:has-text("Start workout")')
    await page.locator('button:has-text("Start workout")').click()
    await page.waitForSelector('.pose', { timeout: 15000 })
    await page.screenshot({ path: shot('09-pose.png') })
    await page.evaluate(() => localStorage.removeItem('jimmy.flags'))
  })

  await step('no page errors or failed requests', async () => {
    const realFailed = failed.filter(f => !f.includes('ytimg'))
    if (errors.length || realFailed.length) throw new Error(JSON.stringify({ errors, failed: realFailed }, null, 2))
  })

  await browser.close()
})().catch(e => { console.error(e); process.exit(1) })
