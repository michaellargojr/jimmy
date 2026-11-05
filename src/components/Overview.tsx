/**
 * Reorder + group editor shared by routines and live workouts (see OverviewPage).
 * All list arithmetic is in src/grouping.ts; this file is only wiring + layout.
 */
import { useState } from 'react'
import { DndContext, PointerSensor, TouchSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from '@dnd-kit/core'
import { SortableContext, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import type { Group, Version } from '../model'
import { versionIndex } from '../indexes'
import { blocks, groupTypeFor, makeGroup, moveItem, regroupAfterMove, removeItem, splitGroup } from '../grouping'

export interface OvItem { id: string; versionId: string; groupId?: string; done?: boolean }

function Row({ item, version, selected, selecting, onSelect, onRemove, groupMark }: {
  item: OvItem; version?: Version; selected: boolean; selecting: boolean; onSelect: () => void; onRemove: () => void; groupMark?: string
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: item.id })
  const style = { transform: CSS.Transform.toString(transform), transition, opacity: isDragging ? .6 : 1 }
  return (
    <div ref={setNodeRef} style={style} className={'ovrow' + (selected ? ' sel' : '') + (item.done ? ' done' : '')} onClick={selecting ? onSelect : undefined}>
      <button className="handlebtn" {...attributes} {...listeners} aria-label="drag">⠿</button>
      <div className="grow">
        <div style={{ fontWeight: 600 }}>{version?.name ?? '?'}</div>
        {groupMark && <div className="small" style={{ color: 'var(--accent)' }}>{groupMark}</div>}
      </div>
      {selecting ? <span className={'tog sm' + (selected ? ' on' : '')}>{selected ? '✓' : ''}</span> : <button className="iconbtn" style={{ width: 34, height: 34 }} onClick={onRemove} aria-label="remove">✕</button>}
    </div>
  )
}

const GROUP_LABEL = { superset: 'Superset', triset: 'Triset', circuit: 'Circuit' } as const

export function Overview({ items, groups, versions, onChange, onAdd }: {
  items: OvItem[]; groups: Group[]; versions: Version[]
  onChange: (items: OvItem[], groups: Group[]) => void; onAdd: () => void
}) {
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }), useSensor(TouchSensor, { activationConstraint: { delay: 120, tolerance: 6 } }))
  const [selecting, setSelecting] = useState(false)
  const [sel, setSel] = useState<string[]>([])
  const vmap = versionIndex(versions).byId
  const gmap = new Map(groups.map(g => [g.id, g]))

  const onDragEnd = (e: DragEndEvent) => {
    const { active, over } = e
    if (!over || active.id === over.id) return
    const from = items.findIndex(i => i.id === active.id), to = items.findIndex(i => i.id === over.id)
    if (from < 0 || to < 0) return
    const next = regroupAfterMove(moveItem(items, from, to), groups)
    onChange(next.items, next.groups)
  }
  const group = () => {
    const next = makeGroup(items, groups, sel, groupTypeFor(sel.length))
    onChange(next.items, next.groups)
    setSel([]); setSelecting(false)
  }
  const split = (groupId: string) => { const next = splitGroup(items, groups, groupId); onChange(next.items, next.groups) }
  const remove = (id: string) => { const next = removeItem(items, groups, id); onChange(next.items, next.groups) }

  return (
    <div className="stack">
      <div className="row" style={{ flexWrap: 'wrap' }}>
        {!selecting ? (
          <>
            <button className="btn sm" onClick={() => { setSelecting(true); setSel([]) }}>Group…</button>
            <button className="btn sm" onClick={onAdd}>+ Add exercise</button>
            <span className="small faint grow" style={{ textAlign: 'right' }}>hold ⠿ to drag</span>
          </>
        ) : (
          <>
            <span className="small muted">Tap 2+ then:</span>
            <button className="btn sm primary" disabled={sel.length < 2} onClick={group}>{GROUP_LABEL[groupTypeFor(sel.length)]}</button>
            <button className="btn sm ghost" onClick={() => { setSelecting(false); setSel([]) }}>Cancel</button>
          </>
        )}
      </div>
      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
        <SortableContext items={items.map(i => i.id)} strategy={verticalListSortingStrategy}>
          <div className="stack" style={{ gap: 8 }}>
            {blocks(items).map(block => {
              const g = block[0].groupId ? gmap.get(block[0].groupId) : undefined
              const rows = block.map(it => (
                <Row key={it.id} item={it} version={vmap.get(it.versionId)} selected={sel.includes(it.id)} selecting={selecting}
                  onSelect={() => setSel(s => (s.includes(it.id) ? s.filter(x => x !== it.id) : [...s, it.id]))}
                  onRemove={() => remove(it.id)} />
              ))
              return g && block.length > 1 ? (
                <div key={block[0].id} className="ovgroup">
                  <div className="row small" style={{ color: 'var(--accent)', padding: '0 4px' }}><span className="grow">{g.type}</span><button className="chip" onClick={() => split(g.id)}>split</button></div>
                  {rows}
                </div>
              ) : rows
            })}
          </div>
        </SortableContext>
      </DndContext>
    </div>
  )
}
