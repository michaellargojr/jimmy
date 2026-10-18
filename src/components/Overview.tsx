import { useState } from 'react'
import { DndContext, PointerSensor, TouchSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from '@dnd-kit/core'
import { SortableContext, arrayMove, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import type { Group, GroupType, Version } from '../model'
import { uid } from '../model'

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
      {selecting ? <span className={'tog sm' + (selected ? ' on' : '')}>{selected ? '✓' : ''}</span> : <button className="iconbtn" style={{ width: 34, height: 34 }} onClick={onRemove}>✕</button>}
    </div>
  )
}

export function Overview({ items, groups, versions, onChange, onAdd }: {
  items: OvItem[]; groups: Group[]; versions: Version[]
  onChange: (items: OvItem[], groups: Group[]) => void; onAdd: () => void
}) {
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }), useSensor(TouchSensor, { activationConstraint: { delay: 120, tolerance: 6 } }))
  const [selecting, setSelecting] = useState(false)
  const [sel, setSel] = useState<string[]>([])
  const vmap = new Map(versions.map(v => [v.id, v]))
  const gmap = new Map(groups.map(g => [g.id, g]))

  const onDragEnd = (e: DragEndEvent) => {
    const { active, over } = e
    if (!over || active.id === over.id) return
    const from = items.findIndex(i => i.id === active.id), to = items.findIndex(i => i.id === over.id)
    const moved = arrayMove(items, from, to)
    // a moved item leaves its group unless it lands adjacent to a member of that group
    const fixed = moved.map((it, i) => {
      if (!it.groupId) return it
      const prev = moved[i - 1], next = moved[i + 1]
      const adjacent = (prev && prev.groupId === it.groupId) || (next && next.groupId === it.groupId)
      return adjacent ? it : { ...it, groupId: undefined }
    })
    onChange(fixed, groups.filter(g => fixed.some(i => i.groupId === g.id)))
  }
  const makeGroup = (type: GroupType) => {
    const g: Group = { id: uid(), type }
    const chosen = items.filter(i => sel.includes(i.id)).map(i => ({ ...i, groupId: g.id }))
    const rest = items.filter(i => !sel.includes(i.id)).map(i => (i.groupId && !items.some(x => x.groupId === i.groupId && !sel.includes(x.id) && x.id !== i.id) ? { ...i, groupId: undefined } : i))
    // insert the group where the first selected item was
    const firstIdx = items.findIndex(i => sel.includes(i.id))
    const before = rest.slice(0, Math.min(firstIdx, rest.length)), after = rest.slice(Math.min(firstIdx, rest.length))
    const next = [...before, ...chosen, ...after]
    onChange(next, [...groups.filter(gr => next.some(i => i.groupId === gr.id)), g])
    setSel([]); setSelecting(false)
  }
  const split = (groupId: string) => {
    onChange(items.map(i => (i.groupId === groupId ? { ...i, groupId: undefined } : i)), groups.filter(g => g.id !== groupId))
  }
  const remove = (id: string) => {
    const next = items.filter(i => i.id !== id)
    onChange(next, groups.filter(g => next.some(i => i.groupId === g.id)))
  }

  // render consecutive same-group items inside a bracket
  const blocks: OvItem[][] = []
  for (const it of items) {
    const last = blocks[blocks.length - 1]
    if (it.groupId && last && last[0].groupId === it.groupId) last.push(it); else blocks.push([it])
  }

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
            <button className="btn sm primary" disabled={sel.length < 2} onClick={() => makeGroup(sel.length >= 3 ? 'triset' : 'superset')}>{sel.length >= 4 ? 'Circuit' : sel.length === 3 ? 'Triset' : 'Superset'}</button>
            <button className="btn sm ghost" onClick={() => { setSelecting(false); setSel([]) }}>Cancel</button>
          </>
        )}
      </div>
      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
        <SortableContext items={items.map(i => i.id)} strategy={verticalListSortingStrategy}>
          <div className="stack" style={{ gap: 8 }}>
            {blocks.map(block => {
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
