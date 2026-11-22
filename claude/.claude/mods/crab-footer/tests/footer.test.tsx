import { expect, mock, test } from 'claude-code/testing'

import { draw, newCrab, play, tick, TRICK_NAMES } from '../hooks/crab'

test('draws the crab, the context row and the directory under the prompt', async ($, on) => {
  on('ui.render', ($, e) => { const { Text } = $.ui.resolve(e); return <Text>? for shortcuts</Text> })
  mock.clock(on)
  on('classic.CwdChanged', () => ({}))
  await $.classic.CwdChanged({ old_cwd: '/', new_cwd: '/home/someone/projects/demo' })
  const ui = await $.ui.mount({
    plugin: 'crab-footer',
    surface: 'terminal',
    component: 'PromptHint',
    props: { isDraft: false, isWorking: true, hint: '? for shortcuts' },
  })
  expect(await ui.find({ type: 'Text', text: /~\/projects\/demo/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /█/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /ctx/ })).toBeDefined()
  await ui.unmount()
})

test('the crab draws three rows through every mood and trick', async () => {
  const c = newCrab(0)
  const moods = [
    { isWorking: false, isDraft: false }, // idle, then asleep after 90s
    { isWorking: false, isDraft: true },
    { isWorking: true, isDraft: false },
  ]
  let now = 0
  for (const s of moods) {
    for (let i = 0; i < 6000; i++, now += 100) expect(draw(tick(c, now, s)).lines.length).toBe(3)
  }
  for (const t of TRICK_NAMES) {
    play(c, t, now)
    for (let i = 0; i < 60; i++, now += 100) expect(draw(tick(c, now, moods[0]!)).lines.length).toBe(3)
  }
})
