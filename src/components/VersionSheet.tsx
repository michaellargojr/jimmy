import { useState } from 'react'
import { EQUIPMENT, MUSCLES, today, type Arms, type Equipment, type Exercise, type MuscleGroup, type Version, type VersionChange, uid } from '../model'
import { useStore } from '../store'
import { Sheet } from './Sheet'
import { BenchIcon } from './Icons'
import { AttachmentSelect, SilhouettePicker, useAttachmentOptions } from './SetupSheet'
import { setupHistory } from '../derive'
import { setupLabel, benchLabel } from '../model'

const ANGLES = [0, 15, 30, 45, 60, 75, 90]
const TRACKED: (keyof Version)[] = ['name', 'equipment', 'arms', 'repMin', 'repMax', 'defaultSets', 'defaultWarmup', 'machine', 'attachment', 'cableHeight', 'benchAngle', 'notes']

export function shortGym(name: string): string { return name.replace('Ultradynamic Fitness - ', '') }

/** Append a change-log entry for every tracked field that differs. */
export function diffChanges(prev: Version | undefined, next: Version): VersionChange[] {
  if (!prev) return []
  const date = today()
  const out: VersionChange[] = []
  for (const f of TRACKED) {
    const a = prev[f] ?? undefined, b = next[f] ?? undefined
    if (JSON.stringify(a) !== JSON.stringify(b)) out.push({ date, field: f, from: a, to: b })
  }
  for (const gid of new Set([...Object.keys(prev.gymNotes ?? {}), ...Object.keys(next.gymNotes ?? {})])) {
    const a = prev.gymNotes?.[gid] || undefined, b = next.gymNotes?.[gid] || undefined
    if (a !== b) out.push({ date, field: `gymNote:${gid}`, from: a, to: b })
  }
  const pm = prev.media?.[0]?.url, nm = next.media?.[0]?.url
  if (pm !== nm) out.push({ date, field: 'video', from: pm, to: nm })
  return out
}

function fmtVal(v: unknown): string {
  if (v == null || v === '') return '–'
  if (typeof v === 'boolean') return v ? 'on' : 'off'
  return String(v)
}

/** Create or edit a version. For create, pass exerciseName + muscle; a base Exercise is created if needed. */
export function VersionSheet({ open, onClose, version, exerciseName, muscle, onSaved }: {
  open: boolean; onClose: () => void; version?: Version; exerciseName?: string; muscle?: MuscleGroup; onSaved: (v: Version) => void
}) {
  const { exercises, gyms, workouts, putExercise, putVersion } = useStore()
  const attachmentOptions = useAttachmentOptions()
  const trend = version ? setupHistory(version.id, workouts) : []
  const [name, setName] = useState(version?.name ?? exerciseName ?? '')
  const [mg, setMg] = useState<MuscleGroup>(muscle ?? (exercises.find(e => e.id === version?.exerciseId)?.muscleGroup ?? 'Back'))
  const [equipment, setEquipment] = useState<Equipment>(version?.equipment ?? 'cable')
  const [arms, setArms] = useState<Arms>(version?.arms ?? 'two')
  const [repMin, setRepMin] = useState(version?.repMin ?? 5)
  const [repMax, setRepMax] = useState(version?.repMax ?? 8)
  const [sets, setSets] = useState(version?.defaultSets ?? 2)
  const [warm, setWarm] = useState(version?.defaultWarmup ?? true)
  const [machine, setMachine] = useState(version?.machine ?? '')
  const [attachment, setAttachment] = useState(version?.attachment ?? '')
  const [notes, setNotes] = useState(version?.notes ?? '')
  const [cable, setCable] = useState<number | undefined>(version?.cableHeight)
  const [bench, setBench] = useState<number | undefined>(version?.benchAngle)
  const [video, setVideo] = useState(version?.media?.[0]?.url ?? '')
  const [gymNotes, setGymNotes] = useState<Record<string, string>>({ ...(version?.gymNotes ?? {}) })
  const [showLog, setShowLog] = useState(false)
  const isCable = equipment === 'cable'

  const save = () => {
    let ex: Exercise | undefined = version ? exercises.find(e => e.id === version.exerciseId) : exercises.find(e => e.name.toLowerCase() === (exerciseName ?? name).toLowerCase())
    if (!ex) { ex = { id: uid(), name: exerciseName ?? name, muscleGroup: mg, aliases: [] }; putExercise(ex) }
    else if (ex.muscleGroup !== mg) putExercise({ ...ex, muscleGroup: mg })
    const cleanNotes: Record<string, string> = {}
    for (const [gid, t] of Object.entries(gymNotes)) if (t.trim()) cleanNotes[gid] = t.trim()
    const url = video.trim()
    const media: Version['media'] = url ? [{ type: /tiktok\.com/i.test(url) ? 'tiktok' : 'video', url }, ...(version?.media?.slice(1) ?? [])] : (version?.media?.slice(1) ?? [])
    const v: Version = {
      id: version?.id ?? uid(), exerciseId: ex.id, name: name.trim() || ex.name, equipment, arms, repMin, repMax, defaultSets: sets, defaultWarmup: warm,
      machine: machine.trim() || undefined, attachment: attachment.trim() || undefined, notes: notes.trim() || undefined,
      gymNotes: cleanNotes, media, changes: version?.changes ?? [],
      cableHeight: isCable ? cable : undefined, benchAngle: bench,
    }
    v.changes = [...v.changes, ...diffChanges(version, v)]
    putVersion(v); onSaved(v); onClose()
  }
  const Stepper = ({ v, set, min = 0 }: { v: number; set: (n: number) => void; min?: number }) => (
    <span className="row" style={{ gap: 6 }}>
      <button className="tog sm" onClick={() => set(Math.max(min, v - 1))}>−</button>
      <b style={{ minWidth: 22, textAlign: 'center' }}>{v}</b>
      <button className="tog sm" onClick={() => set(v + 1)}>+</button>
    </span>
  )
  const log = (version?.changes ?? []).slice().reverse()
  return (
    <Sheet open={open} onClose={onClose} title={version ? 'Edit exercise' : 'New exercise'}>
      <div className="stack">
        <input className="search" value={name} onChange={e => setName(e.target.value)} placeholder="Name (e.g. Cable Shrug)" />
        <div className="row" style={{ flexWrap: 'wrap', gap: 6 }}>
          {MUSCLES.map(m => <button key={m} className={'chip' + (mg === m ? ' on' : '')} onClick={() => setMg(m)}>{m}</button>)}
        </div>
        <div className="row" style={{ flexWrap: 'wrap', gap: 6 }}>
          {EQUIPMENT.map(e => <button key={e} className={'chip' + (equipment === e ? ' on' : '')} onClick={() => setEquipment(e)}>{e}</button>)}
        </div>
        <div className="row" style={{ gap: 6 }}>
          <button className={'chip' + (arms === 'two' ? ' on' : '')} onClick={() => setArms('two')}>two hands</button>
          <button className={'chip' + (arms === 'one' ? ' on' : '')} onClick={() => setArms('one')}>one hand (L/R)</button>
        </div>
        <div className="row"><span className="muted small grow">Rep range</span><Stepper v={repMin} set={setRepMin} min={1} /><span className="faint">to</span><Stepper v={repMax} set={setRepMax} min={1} /></div>
        <div className="row"><span className="muted small grow">Working sets</span><Stepper v={sets} set={setSets} min={1} /><button className={'chip' + (warm ? ' on' : '')} onClick={() => setWarm(!warm)}>warm-up</button></div>

        <div className="small muted" style={{ marginTop: 4 }}>Usual setup <span className="faint">(each session records its own; this is the starting point)</span></div>
        {isCable && <SilhouettePicker value={cable} onChange={setCable} />}
        <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
          <span className="muted small" style={{ width: 60 }}>Bench</span>
          <span style={{ color: 'var(--fg2)' }}><BenchIcon angle={bench ?? 0} size={30} /></span>
          <button className={'chip' + (bench == null ? ' on' : '')} onClick={() => setBench(undefined)}>none</button>
          {ANGLES.map(a => <button key={a} className={'chip' + (bench === a ? ' on' : '')} onClick={() => setBench(a)}>{benchLabel(a)}</button>)}
        </div>
        <div className="row">
          <span className="muted small" style={{ width: 60 }}>Attach.</span>
          <div className="grow"><AttachmentSelect value={attachment || undefined} options={attachmentOptions} onChange={a => setAttachment(a ?? '')} /></div>
        </div>
        <input className="search" value={machine} onChange={e => setMachine(e.target.value)} placeholder="Machine / brand (optional)" />
        {trend.length > 0 && (
          <div className="small faint">
            <div>Setup trend</div>
            {trend.map(t => <div key={t.date + t.item.id}>{t.date.slice(5)} · {setupLabel(t.item)}</div>)}
          </div>
        )}
        <input className="search" inputMode="url" value={video} onChange={e => setVideo(e.target.value)} placeholder="Video link (TikTok, YouTube…)" />
        <textarea className="ta" style={{ minHeight: 60 }} value={notes} onChange={e => setNotes(e.target.value)} placeholder="Notes: notch, grip, cues" />
        {gyms.length > 0 && (
          <div className="stack" style={{ gap: 6 }}>
            <span className="muted small">Per gym (seat number, pin, which machine)</span>
            {gyms.map(g => (
              <input key={g.id} className="search" value={gymNotes[g.id] ?? ''} onChange={e => setGymNotes({ ...gymNotes, [g.id]: e.target.value })} placeholder={`At ${shortGym(g.name)}`} />
            ))}
          </div>
        )}
        {log.length > 0 && (
          <div className="small faint">
            <button className="faint" onClick={() => setShowLog(!showLog)}>{showLog ? '▾' : '▸'} {log.length} change{log.length === 1 ? '' : 's'} logged</button>
            {showLog && (
              <div className="stack" style={{ gap: 2, marginTop: 4 }}>
                {log.slice(0, 12).map((c, i) => <div key={i}>{c.date.slice(5)} · {c.field.replace('gymNote:', 'gym note ')}: {fmtVal(c.from)} → {fmtVal(c.to)}</div>)}
              </div>
            )}
          </div>
        )}
        <button className="btn primary block" onClick={save} disabled={!name.trim()}>Save</button>
      </div>
    </Sheet>
  )
}
