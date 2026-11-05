import { describe, it, expect } from 'vitest'
import { blocks, groupTypeFor, makeGroup, moveItem, pruneGroups, regroupAfterMove, removeItem, splitGroup } from './grouping'
import type { Group } from './model'

interface It { id: string; groupId?: string }
const item = (id: string, groupId?: string): It => ({ id, groupId })
const G: Group[] = [{ id: 'g1', type: 'superset' }]

describe('moveItem', () => {
  it('moves forward and backward without losing items', () => {
    const list = ['a', 'b', 'c', 'd']
    expect(moveItem(list, 0, 2)).toEqual(['b', 'c', 'a', 'd'])
    expect(moveItem(list, 3, 1)).toEqual(['a', 'd', 'b', 'c'])
    expect(moveItem(list, 1, 1)).toEqual(list)
  })
})

describe('regroupAfterMove', () => {
  it('keeps a group whose members stay adjacent', () => {
    const items = [item('a', 'g1'), item('b', 'g1'), item('c')]
    const out = regroupAfterMove(items, G)
    expect(out.items.map(i => i.groupId)).toEqual(['g1', 'g1', undefined])
    expect(out.groups).toEqual(G)
  })
  it('ungroups an item that was moved away from its partners and prunes the empty group', () => {
    const items = [item('a', 'g1'), item('c'), item('b', 'g1')]
    const out = regroupAfterMove(items, G)
    expect(out.items.map(i => i.groupId)).toEqual([undefined, undefined, undefined])
    expect(out.groups).toEqual([])
  })
})

describe('groupTypeFor', () => {
  it('maps counts to types, including circuit for 4+', () => {
    expect(groupTypeFor(2)).toBe('superset')
    expect(groupTypeFor(3)).toBe('triset')
    expect(groupTypeFor(4)).toBe('circuit')
    expect(groupTypeFor(7)).toBe('circuit')
  })
})

describe('makeGroup', () => {
  it('inserts the new group where the first selected item was and keeps order inside it', () => {
    const items = [item('a'), item('b'), item('c'), item('d'), item('e')]
    const out = makeGroup(items, [], ['d', 'b'])
    expect(out.items.map(i => i.id)).toEqual(['a', 'b', 'd', 'c', 'e'])
    expect(out.items.filter(i => i.groupId === out.group.id).map(i => i.id)).toEqual(['b', 'd'])
    expect(out.group.type).toBe('superset')
    expect(out.groups).toEqual([out.group])
  })
  it('ungroups an item left alone when its partner is pulled into a new group', () => {
    const items = [item('a', 'g1'), item('b', 'g1'), item('c')]
    const out = makeGroup(items, G, ['b', 'c'])
    const a = out.items.find(i => i.id === 'a')!
    expect(a.groupId).toBeUndefined()
    expect(out.groups.map(g => g.id)).toEqual([out.group.id])
  })
  it('uses the explicit type when given', () => {
    const out = makeGroup([item('a'), item('b'), item('c'), item('d')], [], ['a', 'b', 'c', 'd'])
    expect(out.group.type).toBe('circuit')
  })
})

describe('splitGroup / removeItem / pruneGroups', () => {
  it('split dissolves the group and its record', () => {
    const out = splitGroup([item('a', 'g1'), item('b', 'g1')], G, 'g1')
    expect(out.items.every(i => !i.groupId)).toBe(true)
    expect(out.groups).toEqual([])
  })
  it('remove drops the item and prunes groups that lost all members', () => {
    const out = removeItem([item('a', 'g1'), item('b')], G, 'a')
    expect(out.items.map(i => i.id)).toEqual(['b'])
    expect(out.groups).toEqual([])
  })
  it('pruneGroups keeps groups with at least one member', () => {
    expect(pruneGroups([item('a', 'g1')], G)).toEqual(G)
    expect(pruneGroups([item('a')], G)).toEqual([])
  })
})

describe('blocks', () => {
  it('groups consecutive same-group items and splits others', () => {
    const items = [item('a'), item('b', 'g1'), item('c', 'g1'), item('d'), item('e', 'g1')]
    expect(blocks(items).map(b => b.map(i => i.id))).toEqual([['a'], ['b', 'c'], ['d'], ['e']])
  })
})
