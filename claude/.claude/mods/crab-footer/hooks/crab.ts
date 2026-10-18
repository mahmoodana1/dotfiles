// The crab: the Claude Code logo on an 18x6 pixel grid, each terminal cell
// holding 2x2 pixels (quadrant blocks) and two colors (fg + bg), shaded as a
// block lit from the top left, with a ground shadow beneath it.
//
//   y0  ...#############..   top (lit)
//   y1  ...##.#######.##..   face, eyes
//   y2  .#################   arms
//   y3  ...#############..   lower body (away from the light)
//   y4  ...#.#.......#.#..   legs, shadow between them
//   y5  ....#############.   ground shadow, cast right
//
// The body is 13 pixels wide so the two eyes always fall in the same half of
// their cells: the font then draws them the same width. Turned, the body is a
// box: its front (or back) narrows with the angle while a side plane widens.

export type Run = { t: string; fg?: string; bg?: string }
export type Pose = { lines: Run[][] }

export type Eye = 'center' | 'left' | 'right' | 'up' | 'shut' | 'wink'
export type Stance = 'stand' | 'crouch' | 'hop'
export type Feet = 'both' | 'left' | 'right'
export type Poof = 'dot' | 'wave'
export type Shadow = 'normal' | 'narrow' | 'wide'

export const W = 18 // sprite width in pixels (9 columns)
export const TRACK = 8 // pixels the crab wanders over (4 columns); walked in whole columns

const HI = '#E58C6C' // top face, rim light on the left edge
const BASE = '#D97757' // front face
const BACK = '#CC6D4F' // back face, seen mid-turn
const LOW = '#BF6146' // lower body, turned from the light
const SIDE = '#98472F' // right side plane
const SIDE_TOP = '#B35A3E' // top of the right side plane
const LEFT = '#DF8161' // left side plane, lit
const LEG = '#A5503A'
const EYE = '#1A1210'
const GROUND = '#15151F' // a shade darker than the terminal's #1E1E2E
const DUST = '#6C6A80'

export type Look = {
  eye: Eye
  armsUp: boolean
  stance: Stance
  step: number
  offset: number // pixels from the left of the track
  rise?: number // pixels the body is moved down (negative: up, off the top)
  angle?: number // degrees turned, 0 facing out, 180 its back
  feet?: Feet
  poof?: Poof
  shadow?: Shadow
}

type Px = [x: number, y: number, color: string]

function span(from: number, to: number): number[] {
  const xs: number[] = []
  for (let x = from; x <= to; x++) xs.push(x)
  return xs
}

function eyesAt(eye: Eye, left: number, right: number): { y: number; xs: number[] } {
  const shift = eye === 'left' ? -1 : eye === 'right' ? 1 : 0
  const xs = eye === 'shut' ? [] : eye === 'wink' ? [left] : [left + shift, right + shift]
  return { y: eye === 'up' ? 0 : 1, xs }
}

function legsFor(feet: Feet, xs: number[]): number[] {
  const half = xs.length / 2
  return feet === 'left' ? xs.slice(0, half) : feet === 'right' ? xs.slice(half) : xs
}

// The body facing out: the logo, with the head-turn shading.
function front(l: Look, set: (x: number, y: number, c: string) => void) {
  const { eye, stance } = l
  const sideFrom = eye === 'left' ? 14 : eye === 'right' ? 16 : 15
  const top = stance === 'crouch' ? 1 : 0
  const shade = (x: number, face: string, sideTop = false) => {
    if (x === 3) return HI // rim light
    if (x >= sideFrom) return sideTop ? SIDE_TOP : SIDE
    if (eye === 'right' && x === 4) return LEFT
    return face
  }
  for (const x of span(3, 15)) {
    set(x, top, shade(x, HI, true))
    set(x, top + 1, shade(x, BASE))
    set(x, top + 2, shade(x, BASE))
    set(x, top + 3, shade(x, LOW))
  }
  const eyes = eyesAt(eye, 5, 13)
  for (const x of eyes.xs) set(x, top + eyes.y, EYE)
  const ay = l.armsUp ? top + 1 : top + 2
  set(1, ay, HI)
  set(2, ay, HI)
  set(16, ay, SIDE)
  set(17, ay, SIDE)
  if (stance !== 'hop') {
    const ly = stance === 'crouch' ? 5 : 4
    const legs = l.step % 2 === 0 ? [3, 5, 13, 15] : [4, 6, 12, 14]
    for (const x of legsFor(l.feet ?? 'both', legs)) set(x, ly, LEG)
  }
}

// The body turned: a box whose face (or back) narrows as a side widens.
function turned(l: Look, set: (x: number, y: number, c: string) => void): [number, number] {
  const a = ((((l.angle ?? 0) % 360) + 360) % 360) * (Math.PI / 180)
  const cos = Math.cos(a)
  const sin = Math.sin(a)
  const fw = Math.round(13 * Math.abs(cos))
  const sw = Math.round(4 * Math.abs(sin))
  const width = fw + sw
  const left = 9 - Math.floor(width / 2)
  const right = left + width - 1
  const sideLeft = sin > 0 // turning right shows its left side
  const faceFrom = sideLeft ? left + sw : left
  const faceTo = faceFrom + fw - 1
  const isFront = cos >= 0
  const top = l.stance === 'crouch' ? 1 : 0

  for (const x of span(left, right)) {
    const isSide = x < faceFrom || x > faceTo
    const sideColor = sideLeft ? LEFT : SIDE
    set(x, top, isSide ? (sideLeft ? HI : SIDE_TOP) : HI)
    set(x, top + 1, isSide ? sideColor : isFront ? BASE : BACK)
    set(x, top + 2, isSide ? sideColor : isFront ? BASE : BACK)
    set(x, top + 3, isSide ? sideColor : LOW)
  }
  if (isFront && fw >= 6) {
    const el = faceFrom + Math.round((2 * (fw - 1)) / 12)
    const er = faceFrom + Math.round((10 * (fw - 1)) / 12)
    const eyes = eyesAt(l.eye === 'left' || l.eye === 'right' ? 'center' : l.eye, el, er)
    for (const x of eyes.xs) set(x, top + eyes.y, EYE)
  }
  const reach = Math.round(2 * Math.abs(cos))
  const ay = l.armsUp ? top + 1 : top + 2
  for (let i = 1; i <= reach; i++) {
    set(left - i, ay, HI)
    set(right + i, ay, SIDE)
  }
  if (l.stance !== 'hop') {
    const legs = width >= 7 ? [left, left + 2, right - 2, right] : [left, right]
    for (const x of legsFor(l.feet ?? 'both', legs)) set(x, l.stance === 'crouch' ? 5 : 4, LEG)
  }
  return [left, right]
}

function pixels(l: Look): { body: Px[]; ground: Px[] } {
  const body: Px[] = []
  const ground: Px[] = []
  const rise = l.rise ?? 0
  const setBody = (x: number, y: number, c: string) => void body.push([x, y + rise, c])
  const setGround = (x: number, y: number, c: string) => void ground.push([x, y, c])

  let left = 3
  let right = 15
  if (l.angle) [left, right] = turned(l, setBody)
  else front(l, setBody)

  // the ground: none while sunk into it; small while high above it
  if (rise <= 0) {
    const shadow: Shadow = l.shadow ?? (rise <= -4 || l.stance === 'hop' ? 'narrow' : 'normal')
    const [from, to] =
      shadow === 'narrow' ? [left + 3, right - 1] : shadow === 'wide' ? [left - 1, right + 2] : [left + 1, right + 1]
    for (const x of span(from, to)) setGround(x, 5, GROUND)
    if (l.stance === 'stand' && rise === 0 && shadow !== 'narrow') {
      for (const x of span(left + 1, right - 1)) setGround(x, 4, GROUND)
    }
  }
  if (l.poof) {
    const dust: [number, number][] =
      l.poof === 'dot'
        ? [[left - 2, 4], [right + 2, 4]]
        : [[left - 3, 3], [left - 2, 4], [right + 2, 4], [right + 3, 3]]
    for (const [x, y] of dust) setGround(x, y, DUST)
  }
  return { body, ground }
}

// quadrant glyph by bits: top-left 1, top-right 2, bottom-left 4, bottom-right 8
const QUAD = ' ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█'

function rgb(c: string): [number, number, number] {
  const n = parseInt(c.slice(1), 16)
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}

function distance(a: string, b: string): number {
  const [r1, g1, b1] = rgb(a)
  const [r2, g2, b2] = rgb(b)
  return (r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2
}

// One cell from its four pixels. A cell shows two colors, or one where a
// pixel is empty (the terminal's own background shows there); extra colors
// fold into the nearest one kept. The eyes are always kept: as a color where
// the cell has two, as a gap (the dark background) where it has one. On a tie
// the lower pixel's color wins, so a leg is not drawn in the rim's light. The
// ground between the legs is kept too, or the legs would merge into a block.
function cell(quad: (string | null)[]): Run {
  const hasEmpty = quad.includes(null)
  const solid = quad.filter((c): c is string => c !== null)
  const hasBody = solid.some(c => c !== EYE)
  // with an empty pixel the cell holds one color: the body's, the eye left as a gap
  const px = hasEmpty && hasBody ? quad.map(c => (c === EYE ? null : c)) : quad
  const counts = new Map<string, { n: number; last: number }>()
  px.forEach((c, i) => {
    if (!c) return
    const was = counts.get(c)
    counts.set(c, { n: (was?.n ?? 0) + (c === EYE ? 10 : c === GROUND ? 5 : 1), last: i })
  })
  if (counts.size === 0) return { t: ' ' }
  const kept = [...counts.entries()]
    .sort((a, b) => b[1].n - a[1].n || b[1].last - a[1].last)
    .slice(0, hasEmpty ? 1 : 2)
    .map(([c]) => c)
  const near = (c: string) => kept.reduce((best, k) => (distance(c, k) < distance(c, best) ? k : best))
  const fg = kept[0] as string
  const bits = px.reduce((acc, c, i) => (c && near(c) === fg ? acc | (1 << i) : acc), 0)
  const bg = kept[1]
  return bg ? { t: QUAD[bits] as string, fg, bg } : { t: QUAD[bits] as string, fg }
}

export function draw(look: Look): Pose {
  const width = W + TRACK
  const grid: (string | null)[][] = Array.from({ length: 6 }, () => Array<string | null>(width).fill(null))
  const { body, ground } = pixels(look)
  for (const [x, y, c] of [...ground, ...body]) {
    const row = grid[y]
    const gx = x + look.offset
    if (row && gx >= 0 && gx < width) row[gx] = c
  }
  const at = (y: number, x: number) => grid[y]?.[x] ?? null
  const lines: Run[][] = []
  for (let y = 0; y < 6; y += 2) {
    const runs: Run[] = []
    for (let x = 0; x < width; x += 2) {
      const r = cell([at(y, x), at(y, x + 1), at(y + 1, x), at(y + 1, x + 1)])
      const last = runs[runs.length - 1]
      if (last && last.fg === r.fg && last.bg === r.bg) last.t += r.t
      else runs.push(r)
    }
    lines.push(runs)
  }
  return { lines }
}

// ---- behaviour ---------------------------------------------------------------
//
// The crab is always doing one small activity: a list of keyframes, each held
// for its time. When the list runs out it picks the next one from its mood:
//
//   idle     rests and breathes, glances around, scans, strolls, waves,
//            stretches, and now and then plays a trick
//   watching the person is typing: it holds still and pays attention
//   working  a turn is running: hop bursts, pacing, looking up to think, tapping
//   asleep   nothing has happened for a while: slow blinks, then eyes shut and
//            deep slow breaths; anything happening wakes it with a start
//
// The tricks are the ones Claude Code's own logo plays at launch (jump, look,
// spin, peekaboo, drop, waddle, peek, wink, boop, tap, sneeze, turn, coin-hop,
// skip, celebrate), frame for frame, at a gentler pace. The crab opens the
// session with one, and a finished turn gets a celebratory one.

type Frame = {
  eye?: Eye
  armsUp?: boolean
  stance?: Stance
  dx?: number
  at?: number // move to this spot on the track first
  ms: number
  // held for this frame only
  rise?: number
  angle?: number
  feet?: Feet
  poof?: Poof
  shadow?: Shadow
  shift?: number
}
type Mood = 'idle' | 'watching' | 'working' | 'asleep'

export type Crab = {
  x: number
  gaze: Eye
  stance: Stance
  armsUp: boolean
  legPhase: number
  frame: Frame
  queue: Frame[]
  frameEnd: number
  mood: Mood
  lastActive: number
  blinkUntil: number
  nextBlink: number
  breathAt: number
}

export type Signals = { isWorking: boolean; isDraft: boolean }

const SLEEP_AFTER_MS = 90_000
const BEAT = 95 // one frame of a trick (Claude Code's own run at 60)

const rand = (a: number, b: number) => a + Math.random() * (b - a)
const pick = <T>(xs: readonly T[]): T => xs[Math.floor(Math.random() * xs.length)] as T
const chance = (p: number) => Math.random() < p

function weighted<T>(options: readonly [number, T][]): T {
  let r = Math.random() * options.reduce((sum, [w]) => sum + w, 0)
  for (const [w, v] of options) if ((r -= w) < 0) return v
  return (options[options.length - 1] as [number, T])[1]
}

// -- tricks --------------------------------------------------------------------

type PoseName = 'default' | 'arms-up' | 'look-left' | 'look-right' | 'shut'

const POSES: Record<PoseName, Frame> = {
  default: { eye: 'center', armsUp: false, stance: 'stand', ms: 0 },
  'arms-up': { eye: 'center', armsUp: true, stance: 'stand', ms: 0 },
  'look-left': { eye: 'left', armsUp: false, stance: 'stand', ms: 0 },
  'look-right': { eye: 'right', armsUp: false, stance: 'stand', ms: 0 },
  shut: { eye: 'shut', armsUp: false, stance: 'stand', ms: 0 },
}

const f = (pose: PoseName, beats: number, extra: Partial<Frame> = {}): Frame => ({
  ...POSES[pose],
  ...extra,
  ms: beats * BEAT,
})

const land = (): Frame[] => [
  f('default', 1, { stance: 'crouch', poof: 'dot' }),
  f('default', 1, { stance: 'crouch', poof: 'wave' }),
]
const leap = (beats = 3): Frame => f('arms-up', beats, { stance: 'hop' })
const blink = (): Frame[] => [f('shut', 1), f('default', 1)]
const turn = (angles: number[], extra: Partial<Frame> = {}): Frame[] =>
  angles.map(angle => f('default', 1, { angle, ...extra }))

const jump = (): Frame[] => [...land(), leap(), f('default', 1), ...land(), leap(), f('default', 1)]

export const TRICKS = {
  jump,
  look: (): Frame[] => [f('look-right', 5), f('look-left', 5), f('default', 1)],
  celebrate: (): Frame[] => [...jump(), f('default', 3, { stance: 'crouch' }), f('default', 2)],
  spin: (): Frame[] => [
    f('look-left', 2), f('look-right', 2), f('look-left', 2), f('arms-up', 3), f('default', 1),
  ],
  turn: (): Frame[] => [
    ...turn([12, 30, 55, 75, 90]),
    ...turn([105, 125, 150, 180, 180]),
    ...turn([210, 235, 255, 270]),
    ...turn([285, 305, 330, 348]),
    f('default', 2),
  ],
  peekaboo: (): Frame[] => [
    f('default', 1, { rise: 6 }),
    f('default', 3, { rise: 4 }), f('look-right', 3, { rise: 4 }), f('look-left', 3, { rise: 4 }),
    f('default', 2, { rise: 4 }), f('default', 1, { rise: 2 }),
    f('arms-up', 4), f('default', 2), ...blink(),
  ],
  drop: (): Frame[] => [
    f('arms-up', 1, { rise: -6 }), f('arms-up', 2, { rise: -4 }), f('arms-up', 2, { rise: -2 }),
    f('arms-up', 1), ...land(), f('default', 3), ...blink(),
  ],
  waddle: (): Frame[] => [
    f('look-right', 1, { at: 0, shift: -20 }),
    ...[-12, -10, -8, -6, -4, -2].map((shift, i) =>
      f('look-right', 2, { shift, feet: i % 2 === 0 ? 'left' : 'right' }),
    ),
    f('look-right', 2), f('default', 2), ...blink(),
  ],
  peek: (): Frame[] => [
    f('look-right', 1, { at: 0, shift: -20 }),
    f('look-right', 5, { shift: -13 }),
    f('look-right', 3, { shift: -20 }),
    f('look-right', 4, { shift: -11 }),
    f('arms-up', 2, { shift: -6 }), f('arms-up', 2), ...land(), f('default', 1),
  ],
  wink: (): Frame[] => [f('default', 6, { eye: 'wink' }), f('default', 1)],
  boop: (): Frame[] => [
    f('shut', 1, { stance: 'crouch', poof: 'dot' }), f('shut', 2, { stance: 'crouch', poof: 'wave' }),
    f('look-left', 4), f('default', 2), ...blink(),
  ],
  tap: (): Frame[] => [
    ...(['left', 'right', 'left', 'right'] as const).map(feet => f('default', 2, { feet })),
    f('default', 1, { feet: 'left' }), f('default', 1, { feet: 'right' }),
    f('arms-up', 3), f('default', 1),
  ],
  sneeze: (): Frame[] => [
    f('shut', 4, { armsUp: true }),
    f('shut', 2, { stance: 'crouch', poof: 'wave' }),
    f('shut', 2), f('default', 2), ...blink(),
  ],
  'coin-hop': (): Frame[] => [
    f('default', 2, { stance: 'crouch' }),
    f('arms-up', 1, { stance: 'hop', shadow: 'wide' }),
    ...turn([55, 90, 125, 180], { stance: 'hop', shadow: 'narrow' }),
    ...turn([235, 270, 305], { stance: 'hop', shadow: 'narrow' }),
    f('arms-up', 1, { stance: 'hop', shadow: 'wide' }), ...land(), f('default', 1),
  ],
  skip: (): Frame[] => [
    f('default', 1, { at: 0, shift: -20, stance: 'crouch' }),
    f('arms-up', 2, { shift: -12, stance: 'hop' }), f('default', 1, { shift: -12 }),
    f('default', 1, { shift: -12, stance: 'crouch' }),
    f('arms-up', 2, { shift: -6, stance: 'hop' }), f('default', 1, { shift: -6 }),
    f('default', 1, { shift: -6, stance: 'crouch' }),
    leap(2), ...land(), f('default', 1),
  ],
} satisfies Record<string, () => Frame[]>

export type Trick = keyof typeof TRICKS
export const TRICK_NAMES = Object.keys(TRICKS) as Trick[]

const IDLE_TRICKS: Trick[] = ['look', 'spin', 'wink', 'tap', 'boop', 'sneeze', 'jump', 'turn', 'peekaboo', 'peek']
const CELEBRATIONS: Trick[] = ['celebrate', 'jump', 'coin-hop', 'turn', 'spin']

export function play(c: Crab, trick: Trick, now: number) {
  c.queue = TRICKS[trick]()
  c.frameEnd = now
}

// -- activities ----------------------------------------------------------------

export function newCrab(now: number): Crab {
  return {
    x: 4, gaze: 'center', stance: 'stand', armsUp: false, legPhase: 0, frame: { ms: 0 },
    // open the session the way Claude Code opens: with a trick
    queue: [{ ms: 600 }, ...TRICKS[pick(TRICK_NAMES)]()],
    frameEnd: now, mood: 'idle', lastActive: now,
    blinkUntil: 0, nextBlink: now + 2500, breathAt: now,
  }
}

function stroll(c: Crab, stepMs: number): Frame[] {
  let target = c.x
  while (target === c.x) target = 2 * Math.floor(rand(0, TRACK / 2 + 1))
  const dir = Math.sign(target - c.x)
  const eye: Eye = dir > 0 ? 'right' : 'left'
  const frames: Frame[] = [{ eye, ms: rand(450, 750) }] // look before walking
  for (let x = c.x; x !== target; x += 2 * dir) frames.push({ eye, dx: 2 * dir, ms: stepMs })
  frames.push({ ms: rand(500, 900) }) // settle on its feet
  if (chance(0.4)) frames.push({ eye: dir > 0 ? 'left' : 'right', ms: rand(700, 1100) }) // look back
  frames.push({ eye: 'center', ms: 400 })
  return frames
}

function hop(): Frame[] {
  return [
    { stance: 'crouch', ms: 240 }, // wind up
    { stance: 'hop', armsUp: true, ms: 320 },
    { stance: 'crouch', armsUp: false, ms: 160 }, // land soft
    { stance: 'stand', ms: 380 },
  ]
}

function idle(c: Crab): Frame[] {
  return weighted<() => Frame[]>([
    [48, () => [{ ms: rand(5000, 12000) }]],
    [18, () => [{ eye: (chance(0.03) ? 'up' : pick(['left', 'right'] as const)), ms: rand(1500, 3000) }, { eye: 'center', ms: rand(300, 600) }]],
    [5, () => [
      { eye: 'left', ms: rand(800, 1200) }, { eye: 'center', ms: 260 },
      { eye: 'right', ms: rand(800, 1200) }, { eye: 'center', ms: 500 },
    ]],
    [9, () => stroll(c, 420)],
    [3, () => [
      { eye: 'center', ms: 350 },
      { armsUp: true, ms: 420 }, { armsUp: false, ms: 320 },
      { armsUp: true, ms: 420 }, { armsUp: false, ms: 700 },
    ]],
    [3, () => [
      { stance: 'crouch', ms: 700 },
      { stance: 'stand', armsUp: true, eye: 'center', ms: 1100 },
      { armsUp: false, eye: 'center', ms: 600 },
    ]],
    [3, () => [...TRICKS[pick(IDLE_TRICKS)](), { ms: rand(3000, 6000) }]],
  ])()
}

function working(c: Crab): Frame[] {
  return weighted<() => Frame[]>([
    [30, () => [{ ms: rand(2500, 6000) }]],
    [14, () => [...Array.from({ length: Math.floor(rand(1, 3)) }, hop).flat(), { ms: rand(1500, 3000) }]],
    [12, () => stroll(c, 300)],
    [24, () => [
      { eye: pick(['left', 'right'] as const), ms: rand(1100, 1800) }, { eye: 'center', ms: rand(600, 900) },
      { eye: pick(['left', 'right'] as const), ms: rand(700, 1100) }, { eye: 'center', ms: 400 },
    ]],
    [10, () => [
      ...Array.from({ length: 4 }, (): Frame[] => [{ armsUp: true, ms: 300 }, { armsUp: false, ms: 300 }]).flat(),
      { ms: 500 },
    ]],
  ])()
}

function dozeOff(): Frame[] {
  return [
    { eye: 'shut', ms: 500 }, { eye: 'center', ms: 900 },
    { eye: 'shut', ms: 900 }, { eye: 'center', ms: 600 },
    { eye: 'shut', stance: 'crouch', ms: 1200 },
  ]
}

function wakeUp(): Frame[] {
  return [
    { eye: 'center', stance: 'hop', ms: 220 }, // startled
    { stance: 'stand', ms: 500 },
    { eye: 'left', ms: 450 }, { eye: 'right', ms: 450 }, { eye: 'center', ms: 300 },
  ]
}

// -- the clock ---------------------------------------------------------------

function moodOf(c: Crab, now: number, s: Signals): Mood {
  if (s.isWorking) return 'working'
  if (s.isDraft) return 'watching'
  if (c.mood === 'asleep' || now - c.lastActive > SLEEP_AFTER_MS) return 'asleep'
  return 'idle'
}

export function tick(c: Crab, now: number, s: Signals): Look {
  if (s.isWorking || s.isDraft) c.lastActive = now
  const mood = moodOf(c, now, s)

  // a change of mood cuts the current activity short
  if (mood !== c.mood) {
    const was = c.mood
    c.mood = mood
    c.stance = 'stand'
    c.armsUp = false
    c.queue =
      was === 'asleep' ? wakeUp()
        : mood === 'asleep' ? dozeOff()
          : was === 'working' && mood === 'idle' && chance(0.35) ? [{ eye: 'center', ms: 200 }, ...TRICKS[pick(CELEBRATIONS)]()]
            : mood === 'watching' ? [{ eye: 'center', ms: 400 }]
              : []
    c.frameEnd = now
  }

  // advance to the next keyframe when this one is done
  while (now >= c.frameEnd) {
    if (c.queue.length === 0) {
      c.queue =
        c.mood === 'working' ? working(c)
          : c.mood === 'idle' ? idle(c)
            : c.mood === 'watching' ? [{ eye: chance(0.75) ? 'center' : pick(['left', 'right'] as const), ms: rand(1500, 3500) }]
              : [{ eye: 'shut', stance: 'stand', ms: 10_000 }]
    }
    const fr = c.queue.shift() as Frame
    c.frame = fr
    if (fr.at !== undefined) c.x = fr.at
    if (fr.eye) c.gaze = fr.eye
    if (fr.stance) c.stance = fr.stance
    if (fr.armsUp !== undefined) c.armsUp = fr.armsUp
    if (fr.dx) {
      c.x = Math.max(0, Math.min(TRACK, c.x + fr.dx))
      c.legPhase += 1
    } else {
      c.legPhase = 0
    }
    c.frameEnd = Math.max(c.frameEnd, now - 1000) + fr.ms
  }
  const fr = c.frame

  // blinks, except asleep or while a trick holds the eyes
  if (c.mood !== 'asleep' && now >= c.nextBlink) {
    c.blinkUntil = now + rand(110, 170)
    c.nextBlink = chance(0.15) ? now + 300 : now + rand(2800, 7000)
  }
  const isTrick =
    fr.rise !== undefined || fr.angle !== undefined || fr.shift !== undefined || fr.poof !== undefined
  const eye: Eye = now < c.blinkUntil && !isTrick && c.gaze !== 'wink' ? 'shut' : c.gaze

  // breathing: a slow crouch while standing still, deeper and slower asleep
  let stance = c.stance
  const isStill = stance === 'stand' && !c.armsUp && c.legPhase === 0 && !isTrick && !fr.feet
  if (isStill && c.mood !== 'working') {
    const period = c.mood === 'asleep' ? 5200 : 4200
    const depth = c.mood === 'asleep' ? 0.2 : 0.7
    if (Math.sin(((now - c.breathAt) / period) * Math.PI * 2) > depth) stance = 'crouch'
  }

  return {
    eye,
    armsUp: c.armsUp,
    stance,
    step: c.legPhase,
    offset: c.x + (fr.shift ?? 0),
    rise: fr.rise,
    angle: fr.angle,
    feet: fr.feet,
    poof: fr.poof,
    shadow: fr.shadow,
  }
}
