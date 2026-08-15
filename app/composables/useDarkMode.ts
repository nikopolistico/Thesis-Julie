export function useDarkMode() {
  const isDark = useState<boolean>('dark-mode', () => false)

  function apply(value: boolean) {
    if (!import.meta.client) return
    document.documentElement.classList.toggle('dark', value)
    localStorage.setItem('theme', value ? 'dark' : 'light')
  }

  function init() {
    if (!import.meta.client) return
    const stored = localStorage.getItem('theme')
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    isDark.value = stored ? stored === 'dark' : prefersDark
    apply(isDark.value)
  }

  function toggle() {
    isDark.value = !isDark.value
    apply(isDark.value)
  }

  return { isDark, init, toggle }
}
