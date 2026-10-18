import { expect, mock, test } from 'claude-code/testing'

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
