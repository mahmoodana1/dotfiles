export type Limit = { kind: string; percentUsed: number; resetsAt?: string }
export type Usage = {
  limits: Limit[]
  ctxTokens?: number
  ctxWindow: number
  ctxPercent?: number
  usd?: number
}
export type Run = { t: string; fg?: string; bg?: string }
export type Pose = { lines: Run[][] }

declare module 'claude-code' {
  interface PluginState {
    'crab-footer': { pose: Pose; usage: Usage | null; cwd: string }
  }
}
