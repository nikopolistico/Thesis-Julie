export function useOfficerName() {
  const supabase = useSupabaseClient()
  const name = ref('')

  async function loadOfficerName(officerId: number) {
    const { data, error } = await supabase.rpc('get_officer_name', { p_officer_id: officerId })
    if (!error && data) name.value = data
  }

  const initials = computed(() => {
    const parts = name.value.trim().split(/\s+/).filter(Boolean)
    if (parts.length === 0) return ''
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
  })

  return { name, initials, loadOfficerName }
}
