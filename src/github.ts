import type { Idea } from './db'
import type { Settings } from './model'

const API = 'https://api.github.com'

function headers(token: string): HeadersInit {
  return { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'Content-Type': 'application/json' }
}

export function ideaTitle(i: Idea): string {
  const first = i.text.split(/\n/)[0].trim()
  return `[${i.kind}] ${first.length > 72 ? first.slice(0, 69).trimEnd() + '…' : first}`
}

export function ideaBody(i: Idea): string {
  const when = new Date(i.createdAt).toLocaleString()
  return `${i.text}\n\n---\n_Captured in Jimmy on ${when}${i.page ? ` from \`${i.page}\`` : ''}._`
}

export interface SyncResult { created: number; closed: number; errors: string[] }

/**
 * File every open, unfiled idea as an issue; close the issue of every idea marked done.
 * `save` persists the updated idea after each step so a failure half-way loses nothing.
 */
export async function syncIdeas(ideas: Idea[], settings: Settings, save: (i: Idea) => void): Promise<SyncResult> {
  const token = settings.githubToken?.trim(), repo = settings.githubRepo?.trim()
  const res: SyncResult = { created: 0, closed: 0, errors: [] }
  if (!token || !repo) { res.errors.push('Add a GitHub token and repo first.'); return res }
  for (const i of ideas) {
    try {
      if (i.issue == null && !i.done) {
        const r = await fetch(`${API}/repos/${repo}/issues`, { method: 'POST', headers: headers(token), body: JSON.stringify({ title: ideaTitle(i), body: ideaBody(i), labels: [i.kind] }) })
        if (!r.ok) throw new Error(`${r.status} ${(await r.text()).slice(0, 120)}`)
        const j = await r.json() as { number: number; html_url: string }
        save({ ...i, issue: j.number, issueUrl: j.html_url }); res.created++
      } else if (i.issue != null && i.done && !i.closedAt) {
        const r = await fetch(`${API}/repos/${repo}/issues/${i.issue}`, { method: 'PATCH', headers: headers(token), body: JSON.stringify({ state: 'closed', state_reason: 'completed' }) })
        if (!r.ok) throw new Error(`${r.status} ${(await r.text()).slice(0, 120)}`)
        save({ ...i, closedAt: Date.now() }); res.closed++
      }
    } catch (e) {
      res.errors.push(`${ideaTitle(i)}: ${e instanceof Error ? e.message : String(e)}`)
      if (res.errors.length >= 3) break
    }
  }
  return res
}
