// Paint upstream's semantic tokens with the same published palette and shape
// ramp as Seele. Keep Hermes's own components, navigation and accessibility.
import tokens from './seele-tokens'
let previous = ''
async function paint() {
  const palette = await window.hermesDesktop?.seeleTheme?.()
  if (!palette || JSON.stringify(palette) === previous) return
  previous = JSON.stringify(palette)
  const style = document.documentElement.style
  const set = (name: string, value: string) => style.setProperty(name, value, 'important')
  const map: Record<string, string> = {
    '--theme-foreground': 'text', '--theme-primary': 'accent', '--theme-midground': 'accent',
    '--ui-base': 'text', '--ui-accent': 'accent', '--ui-accent-secondary': 'accent',
    '--ui-bg-chrome': 'mantle', '--ui-bg-sidebar': 'crust', '--ui-bg-editor': 'base',
    '--ui-bg-elevated': 'surface', '--ui-bg-input': 'crust', '--ui-text-primary': 'text',
    '--ui-text-secondary': 'subtext', '--ui-text-tertiary': 'subtext',
    '--dt-background': 'base', '--dt-foreground': 'text', '--dt-card': 'surface',
    '--dt-card-foreground': 'text', '--dt-popover': 'surface', '--dt-popover-foreground': 'text',
    '--dt-muted': 'mantle', '--dt-muted-foreground': 'subtext', '--dt-primary': 'accent',
    '--dt-primary-foreground': 'crust', '--dt-secondary': 'surface', '--dt-secondary-foreground': 'text',
    '--dt-accent': 'surface', '--dt-accent-foreground': 'text', '--dt-border': 'overlay',
    '--dt-input': 'crust', '--dt-ring': 'accent', '--dt-destructive': 'red',
    '--dt-destructive-foreground': 'crust', '--sidebar': 'crust', '--sidebar-foreground': 'text',
    '--sidebar-accent': 'surface', '--sidebar-accent-foreground': 'text', '--sidebar-border': 'overlay',
    '--sidebar-ring': 'accent', '--ui-red': 'red', '--ui-green': 'green', '--ui-yellow': 'yellow',
  }
  for (const [token, key] of Object.entries(map)) set(token, palette[key])
  set('--dt-font-sans', palette.fontFamily || 'sans-serif')
  set('--dt-base-size', `${tokens.textBody}px`)
  set('--radius-scalar', String(tokens.radius / tokens.textBody))
  set('--ui-row-hover-background', `color-mix(in srgb, var(--ui-base) ${tokens.hoverColor * 100}%, transparent)`)
  set('--ui-control-hover-background', `color-mix(in srgb, var(--ui-base) ${tokens.hoverColor * 100}%, transparent)`)
  set('--ui-row-active-background', `color-mix(in srgb, var(--ui-accent) ${tokens.selectedColor * 100}%, transparent)`)
  set('--ui-control-active-background', `color-mix(in srgb, var(--ui-accent) ${tokens.pressColor * 100}%, transparent)`)
  set('--ui-bg-card', `color-mix(in srgb, var(--dt-card) ${tokens.cardColor * 100}%, transparent)`)
  set('--ui-stroke-secondary', `color-mix(in srgb, var(--ui-base) ${tokens.separatorColor * 100}%, transparent)`)
  const text = parseInt(palette.text.slice(1), 16)
  const base = parseInt(palette.base.slice(1), 16)
  document.documentElement.classList.toggle('dark', text > base)
  style.colorScheme = text > base ? 'dark' : 'light'
}
void paint()
setInterval(() => void paint(), 3000)
