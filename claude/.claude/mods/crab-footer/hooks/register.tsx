import { atom, read, update } from 'claude-code'
import type { Register, SessionMeasureInput, SessionUsage, Timer } from 'claude-code'

import type { Usage } from '../types'
import { draw, newCrab, play, tick, TRACK, TRICK_NAMES, W } from './crab'
import type { Crab, Trick } from './crab'

const TICK_MS = 100

// ---- state -----------------------------------------------------------------

const pose = atom({ plugin: 'crab-footer', key: 'pose' } as const, {
  lines: draw({ eye: 'center', armsUp: false, stance: 'stand', step: 0, offset: 4 }).lines,
})
const usage = atom({ plugin: 'crab-footer', key: 'usage' } as const, null)
const cwd = atom({ plugin: 'crab-footer', key: 'cwd' } as const, '')

// ---- the info rows ---------------------------------------------------------

function bar(percent: number, width = 10): string {
  const filled = Math.max(0, Math.min(width, Math.round((percent / 100) * width)))
  return '█'.repeat(filled) + '░'.repeat(width - filled)
}

function tone(percent: number): string {
  return percent >= 80 ? 'error' : percent >= 50 ? 'warning' : 'success'
}

function until(iso: string | undefined, now: number): string {
  if (!iso) return ''
  const ms = Date.parse(iso) - now
  if (!(ms > 0)) return ''
  const m = Math.floor(ms / 60000)
  const d = Math.floor(m / 1440)
  const h = Math.floor((m % 1440) / 60)
  return d > 0 ? `${d}d${h}h` : h > 0 ? `${h}h${m % 60}m` : `${m}m`
}

function tokens(n: number): string {
  return n >= 1_000_000 ? `${+(n / 1_000_000).toFixed(1)}M` : n >= 1000 ? `${Math.round(n / 1000)}k` : `${n}`
}

function toUsage(u: SessionUsage | SessionMeasureInput): Usage {
  return {
    limits: u.rateLimits.map(l => ({ kind: l.kind, percentUsed: l.percentUsed, resetsAt: l.resetsAt })),
    ctxTokens: u.context.tokens,
    ctxWindow: u.context.window,
    ctxPercent: u.context.percent,
    usd: u.cost?.usd,
  }
}

const LABEL: Record<string, string> = { five_hour: '5h', seven_day: 'week', spend_limit: 'spend' }

let ticker: Timer | undefined
let isWorking = false
let isDraft = false
let crab: Crab | undefined

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    ticker?.cancel()
    const c = newCrab(await $.clock.now())
    crab = c
    await $.command.register({
      name: 'crab',
      description: `Play a crab trick: ${TRICK_NAMES.join(', ')} (random when none is named)`,
    })
    let last = ''
    let busy = false
    ticker = $.clock.every(TICK_MS, () => {
      if (busy) return
      busy = true
      void $.clock
        .now()
        .then(now => {
          const p = draw(tick(c, now, { isWorking, isDraft }))
          const sig = JSON.stringify(p.lines)
          if (sig === last) return
          last = sig
          return update($, pose, () => p)
        })
        .finally(() => (busy = false))
    })
    const u = await $.session.usage()
    await update($, usage, () => toUsage(u))
    const r = await next(e)
    await update($, cwd, () => r.cwd)
    return r
  })

  on('command.run', { command: 'crab' }, async ($, e) => {
    const name = e.args.trim()
    const trick: Trick | undefined = name
      ? TRICK_NAMES.find(t => t === name)
      : TRICK_NAMES[Math.floor(Math.random() * TRICK_NAMES.length)]
    if (!trick) return { text: `No trick called "${name}". Try: ${TRICK_NAMES.join(', ')}` }
    if (crab) play(crab, trick, await $.clock.now())
    return { text: `The crab does: ${trick}` }
  })

  on('classic.CwdChanged', ($, e, next) => {
    update($, cwd, () => e.new_cwd).catch(() => {})
    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    await update($, usage, () => toUsage(e))
    return next(e)
  })

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    if (e.surface !== 'terminal') return next(e)
    isWorking = e.props.isWorking
    isDraft = e.props.isDraft
    const { Box, Text } = $.ui.resolve(e)
    const engineLine = await next(e)
    const p = await read($, pose)
    const u = await read($, usage)
    const now = await $.clock.now()

    const dir = (await read($, cwd)).replace(/^\/home\/[^/]+/, '~')
    const limits = u?.limits ?? []
    const ctxPct = u?.ctxPercent ?? 0

    return (
      <Box flexDirection="row">
        <Box flexDirection="column" flexShrink={0} width={(W + TRACK) / 2 + 2}>
          {p.lines.map((runs, i) => (
            <Text key={`c${i}`}>
              {runs.map((r, j) =>
                r.bg ? (
                  <Text key={`r${j}`} color={r.fg} backgroundColor={r.bg}>{r.t}</Text>
                ) : r.fg ? (
                  <Text key={`r${j}`} color={r.fg}>{r.t}</Text>
                ) : (
                  <Text key={`r${j}`}>{r.t}</Text>
                ),
              )}
            </Text>
          ))}
        </Box>
        <Box flexDirection="column" flexGrow={1}>
          <Box flexDirection="row">
            {limits.length === 0 ? (
              <Text dimColor wrap="truncate">
                {u?.usd !== undefined ? `session $${u.usd.toFixed(2)}` : 'usage: waiting for first response'}
              </Text>
            ) : (
              limits.map(l => (
                <Text key={l.kind} wrap="truncate">
                  <Text dimColor>{(LABEL[l.kind] ?? l.kind).padEnd(5)}</Text>
                  <Text color={tone(l.percentUsed)}>{bar(l.percentUsed)}</Text>
                  <Text>{` ${Math.round(l.percentUsed)}%`.padEnd(5)}</Text>
                  <Text dimColor>{until(l.resetsAt, now) ? ` resets ${until(l.resetsAt, now)}   ` : '   '}</Text>
                </Text>
              ))
            )}
          </Box>
          <Text wrap="truncate">
            <Text dimColor>{'ctx  '}</Text>
            <Text color={tone(ctxPct)}>{bar(ctxPct)}</Text>
            <Text>{` ${u?.ctxPercent ?? 0}%`.padEnd(5)}</Text>
            <Text dimColor>
              {` ${tokens(u?.ctxTokens ?? 0)}/${tokens(u?.ctxWindow ?? 0)}`}
              {u?.usd !== undefined && limits.length > 0 ? `   $${u.usd.toFixed(2)}` : ''}
            </Text>
          </Text>
          <Box flexDirection="row">
            <Box flexShrink={1}>
              <Text wrap="truncate-start">
                <Text dimColor>{'dir  '}</Text>
                <Text color="suggestion">{dir}</Text>
              </Text>
            </Box>
            <Box flexShrink={0} marginLeft={3}>
              {engineLine}
            </Box>
          </Box>
        </Box>
      </Box>
    )
  })
}
