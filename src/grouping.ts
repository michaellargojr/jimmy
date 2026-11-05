/**
 * Pure list + group arithmetic shared by the routine planner (Plan, OverviewPage)
 * and the live workout (Overview, Live panes). Nothing here touches React or the
 * store, so it is fully unit-tested in src/grouping.test.ts.
 *
 * A "group" is a superset / triset / circuit. Membership is a `groupId` on each
 * item; the Group record itself only carries the type. Invariants we maintain:
 *  1. Members of a group are consecutive in the list. After any move, an item that
 *     no longer touches another member of its group leaves the group.
 *  2. Group records with no members are dropped.
 *  3. A group with a single remaining member is still "a group" in the data, but
 *     the UI only labels it when 2+ members are adjacent (see blocks()).
 */
import type { Group, GroupType } from './model'
import { uid } from './model'

export interface Grouped { groupId?: string }

/** arrayMove without a dnd-kit dependency, so this module is testable in isolation. */
export function moveItem<T>(items: T[], from: number, to: number): T[] {
  const next = items.slice()
  const [it] = next.splice(from, 1)
  next.splice(to, 0, it)
  return next
}

/** Drop groups that no item references. */
export function pruneGroups<T extends Grouped>(items: T[], groups: Group[]): Group[] {
  return groups.filter(g => items.some(i => i.groupId === g.id))
}

/** Invariant 1: an item keeps its group only if a neighbour shares it. Then invariant 2. */
export function regroupAfterMove<T extends Grouped>(items: T[], groups: Group[]): { items: T[]; groups: Group[] } {
  const next = items.map((it, i) => {
    if (!it.groupId) return it
    const prev = items[i - 1], after = items[i + 1]
    const adjacent = (prev && prev.groupId === it.groupId) || (after && after.groupId === it.groupId)
    return adjacent ? it : { ...it, groupId: undefined }
  })
  return { items: next, groups: pruneGroups(next, groups) }
}

/** 2 => superset, 3 => triset, 4+ => circuit. */
export function groupTypeFor(count: number): GroupType {
  return count >= 4 ? 'circuit' : count === 3 ? 'triset' : 'superset'
}

/**
 * Pull the selected items out, give them a fresh group, and put them back where
 * the first selected item was. Items that were left alone in their old group
 * (because their partners were selected) lose that group.
 */
export function makeGroup<T extends Grouped & { id: string }>(items: T[], groups: Group[], selectedIds: string[], type: GroupType = groupTypeFor(selectedIds.length)): { items: T[]; groups: Group[]; group: Group } {
  const sel = new Set(selectedIds)
  const group: Group = { id: uid(), type }
  const chosen = items.filter(i => sel.has(i.id)).map(i => ({ ...i, groupId: group.id }))
  const rest = items.filter(i => !sel.has(i.id)).map(i => {
    if (!i.groupId) return i
    const stillHasPartner = items.some(x => x.groupId === i.groupId && !sel.has(x.id) && x.id !== i.id)
    return stillHasPartner ? i : { ...i, groupId: undefined }
  })
  const firstIdx = items.findIndex(i => sel.has(i.id))
  const cut = Math.min(Math.max(firstIdx, 0), rest.length)
  const next = [...rest.slice(0, cut), ...chosen, ...rest.slice(cut)]
  return { items: next, groups: [...pruneGroups(next, groups), group], group }
}

/** Dissolve one group; its members become standalone. */
export function splitGroup<T extends Grouped>(items: T[], groups: Group[], groupId: string): { items: T[]; groups: Group[] } {
  return { items: items.map(i => (i.groupId === groupId ? { ...i, groupId: undefined } : i)), groups: groups.filter(g => g.id !== groupId) }
}

/** Remove one item by id and prune groups. */
export function removeItem<T extends Grouped & { id: string }>(items: T[], groups: Group[], id: string): { items: T[]; groups: Group[] } {
  const next = items.filter(i => i.id !== id)
  return { items: next, groups: pruneGroups(next, groups) }
}

/** Consecutive items sharing a groupId form one block (one pane on the Live page, one bracket in Overview). */
export function blocks<T extends Grouped>(items: T[]): T[][] {
  const out: T[][] = []
  for (const it of items) {
    const last = out[out.length - 1]
    if (it.groupId && last && last[0].groupId === it.groupId) last.push(it)
    else out.push([it])
  }
  return out
}
