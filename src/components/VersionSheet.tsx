import { useState } from 'react'
import { EQUIPMENT, MUSCLES, type Arms, type Equipment, type Exercise, type MuscleGroup, type Version, uid } from '../model'
import { useStore } from '../store'
import { Sheet } from './Sheet'

/** Create or edit a version. For create, pass exerciseName + muscle; a base Exercise is created if needed. */
export function VersionSheet({ open, onClose, version, exerciseName, muscle, onSaved }: {
  open: boolean; onClose: () => void; version?: Version; exerciseName?: string; muscle?: MuscleGroup; onSaved: (v: Version) => void
}) {
  const { exercises, putExercise, putVersion } = useStore()
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

  const save = () => {
    let ex: Exercise | undefined = version ? exercises.find(e => e.id === version.exerciseId) : exercises.find(e => e.name.toLowerCase() === (exerciseName ?? name).toLowerCase())
    if (!ex) { ex = { id: uid(), name: exerciseName ?? name, muscleGroup: mg, aliases: [] }; putExercise(ex) }
    else if (ex.muscleGroup !== mg) putExercise({ ...ex, muscleGroup: mg })
    const v: Version = {
      id: version?.id ?? uid(), exerciseId: ex.id, name: name.trim() || ex.name, equipment, arms, repMin, repMax, defaultSets: sets, defaultWarmup: warm,
      machine: machine.trim() || undefined, attachment: attachment.trim() || undefined, notes: notes.trim() || undefined,
      gymNotes: version?.gymNotes ?? {}, media: version?.media ?? [], changes: version?.changes ?? [],
      cableHeight: version?.cableHeight, benchAngle: version?.benchAngle,
    }
    putVersion(v); onSaved(v); onClose()
  }
  const Stepper = ({ v, set, min = 0 }: { v: number; set: (n: number) => void; min?: number }) => (
    <span className="row" style={{ gap: 6 }}>
      <button className="tog sm" onClick={() => set(Math.max(min, v - 1))}>−</button>
      <b style={{ minWidth: 22, textAlign: 'center' }}>{v}</b>
      <button className="tog sm" onClick={() => set(v + 1)}>+</button>
    </span>
  )
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
        <div className="row">
          <input className="search grow" value={machine} onChange={e => setMachine(e.target.value)} placeholder="Machine / brand (optional)" />
          <input className="search grow" value={attachment} onChange={e => setAttachment(e.target.value)} placeholder="Attachment (rope, V-bar)" />
        </div>
        <textarea className="ta" style={{ minHeight: 60 }} value={notes} onChange={e => setNotes(e.target.value)} placeholder="Notes: cable height, bench angle, notch, grip" />
        <button className="btn primary block" onClick={save} disabled={!name.trim()}>Save</button>
      </div>
    </Sheet>
  )
}
