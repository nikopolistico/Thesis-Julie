import type { ComputedRef, Ref } from 'vue'

export function useOfficerName(name: Ref<string> | ComputedRef<string>) {
  const initials = computed(() => {
    const parts = name.value.trim().split(/\s+/).filter(Boolean)
    if (parts.length === 0) return ''
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
  })

  return { initials }
}
