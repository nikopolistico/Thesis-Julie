<script setup lang="ts">
import {
  Activity,
  AlertTriangle,
  Bell,
  CheckCircle2,
  Circle,
  Clock,
  LayoutDashboard,
  LoaderCircle,
  LogOut,
  Menu,
  Moon,
  Search,
  Settings,
  Stethoscope,
  Sun,
  TrendingUp,
  UserPlus,
  Users,
  X,
  XCircle,
} from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'

definePageMeta({
  middleware: 'auth',
  requiredRole: 'admin',
})

useHead({
  title: 'Admin Dashboard — AHDMS',
  meta: [
    {
      name: 'description',
      content: 'Administrator analytics dashboard for the Automated Hospital Discharge Management System at Butuan Medical Center.',
    },
  ],
})

const supabase = useSupabaseClient()
const session = useAdminSession()
const officerId = computed(() => Number(session.value?.id))
const officerFullName = computed(() => session.value?.fullName ?? '')

const { initials: officerInitials } = useOfficerName(officerFullName)

const { isDark, init: initDarkMode, toggle: toggleDarkMode } = useDarkMode()
onMounted(initDarkMode)

const isLoggingOut = ref(false)
const showLogoutConfirm = ref(false)

async function handleLogout() {
  isLoggingOut.value = true
  session.value = null
  await navigateTo('/loginpage')
}

const sidebarOpen = ref(false)

const navItems = [
  { label: 'Dashboard', icon: LayoutDashboard, section: 'overview' },
  { label: 'Discharge Queue', icon: Stethoscope, section: 'discharge-queue' },
  { label: 'Patients', icon: Users, section: 'patients' },
  { label: 'Staff', icon: UserPlus, section: 'staff' },
  { label: 'Settings', icon: Settings, section: 'settings' },
] as const

type Section = typeof navItems[number]['section']

const activeSection = ref<Section>('overview')

interface Officer {
  officer_id: number
  full_name: string
  role: string
  duty_status: string
}

const officers = ref<Officer[]>([])
const isLoadingStaff = ref(false)
const staffError = ref('')
const updatingOfficerId = ref<number | null>(null)

async function loadStaff() {
  isLoadingStaff.value = true
  staffError.value = ''

  const { data, error } = await supabase.rpc('list_officers')
  if (error) {
    staffError.value = error.message
  } else {
    officers.value = data ?? []
  }

  isLoadingStaff.value = false
}

onMounted(loadStaff)

async function toggleDutyStatus(officer: Officer) {
  const nextStatus = officer.duty_status === 'on_duty' ? 'off_duty' : 'on_duty'
  updatingOfficerId.value = officer.officer_id

  const { error } = await supabase.rpc('set_duty_status', {
    p_officer_id: officer.officer_id,
    p_duty_status: nextStatus,
  })

  if (!error) await loadStaff()
  updatingOfficerId.value = null
}

const roleOptions = ['nurse', 'doctor', 'billing', 'admin']
const emptyStaffForm = { full_name: '', email: '', password: '', role: 'nurse' }
const newStaffForm = ref({ ...emptyStaffForm })
const showRegisterStaffForm = ref(false)
const isRegisteringStaff = ref(false)
const registerStaffError = ref('')

function openRegisterStaffForm() {
  newStaffForm.value = { ...emptyStaffForm }
  registerStaffError.value = ''
  showRegisterStaffForm.value = true
}

async function registerStaff() {
  isRegisteringStaff.value = true
  registerStaffError.value = ''

  const { error } = await supabase.rpc('register_officer', {
    p_email: newStaffForm.value.email,
    p_password: newStaffForm.value.password,
    p_full_name: newStaffForm.value.full_name,
    p_role: newStaffForm.value.role,
    p_admin_id: officerId.value,
  })

  if (error) {
    registerStaffError.value = error.message
    isRegisteringStaff.value = false
    return
  }

  showRegisterStaffForm.value = false
  isRegisteringStaff.value = false
  await loadStaff()
}

// ── Discharge requests (hospital-wide) ──────────────────────────────────

interface DischargeRequest {
  request_id: number
  patient_id: number
  patient_name: string
  requested_by_name: string
  approved_by_name: string | null
  status: string
  billing_verified: boolean
  timestamp: string
}

const requestStatusColor: Record<string, string> = {
  pending: '#fab219',
  in_progress: '#2a78d6',
  approved: '#0ca30c',
  completed: '#898781',
  rejected: '#d03b3b',
}

const dischargeRequests = ref<DischargeRequest[]>([])
const isLoadingDischargeRequests = ref(false)
const dischargeRequestsError = ref('')

async function loadDischargeRequests() {
  isLoadingDischargeRequests.value = true
  dischargeRequestsError.value = ''

  const { data, error } = await supabase.rpc('list_discharge_requests_detailed', { p_status: null })
  if (error) {
    dischargeRequestsError.value = error.message
  } else {
    dischargeRequests.value = data ?? []
  }

  isLoadingDischargeRequests.value = false
}

onMounted(loadDischargeRequests)

const approvedAwaitingCompletion = computed(() =>
  dischargeRequests.value.filter((r) => r.status === 'approved'))

// ── Patients (read-only, hospital-wide) ──────────────────────────────────

interface Patient {
  patient_id: number
  full_name: string
  date_of_birth: string | null
  age: number | null
  contact_number: string | null
  emergency_contact: string | null
  admission_date: string
  discharge_date: string | null
  room_number: number | null
  philhealth_no: string | null
}

const patients = ref<Patient[]>([])
const isLoadingPatients = ref(false)
const patientsError = ref('')

async function loadPatients() {
  isLoadingPatients.value = true
  patientsError.value = ''

  const { data, error } = await supabase.rpc('list_all_patients')
  if (error) {
    patientsError.value = error.message
  } else {
    patients.value = data ?? []
  }

  isLoadingPatients.value = false
}

onMounted(loadPatients)

const patientSearchQuery = ref('')

const filteredPatients = computed(() => {
  const q = patientSearchQuery.value.trim().toLowerCase()
  if (!q) return patients.value
  return patients.value.filter((patient) => {
    return patient.full_name.toLowerCase().includes(q)
      || (patient.philhealth_no ?? '').toLowerCase().includes(q)
      || (patient.contact_number ?? '').toLowerCase().includes(q)
      || String(patient.room_number ?? '').includes(q)
  })
})

const viewingPatient = ref<Patient | null>(null)

const viewingPatientFields = computed(() => {
  const p = viewingPatient.value
  if (!p) return []
  return [
    { label: 'Full name', value: p.full_name },
    { label: 'Age', value: p.age ?? '—' },
    { label: 'Date of birth', value: p.date_of_birth ?? '—' },
    { label: 'Contact number', value: p.contact_number ?? '—' },
    { label: 'Emergency contact', value: p.emergency_contact ?? '—' },
    { label: 'Admission date', value: p.admission_date },
    { label: 'Room number', value: p.room_number ?? '—' },
    { label: 'PhilHealth No.', value: p.philhealth_no ?? '—' },
    { label: 'Discharge date', value: p.discharge_date ?? '—' },
  ]
})

// ── Overview: real stats derived from loaded data ───────────────────────

const onDutyCount = computed(() => officers.value.filter((o) => o.duty_status === 'on_duty').length)
const patientsInQueue = computed(() => patients.value.filter((p) => !p.discharge_date).length)

const statTiles = computed(() => [
  { icon: Users, label: 'Patients in Queue', value: String(patientsInQueue.value) },
  { icon: Stethoscope, label: 'Staff on Duty', value: `${onDutyCount.value} of ${officers.value.length}` },
  { icon: CheckCircle2, label: 'Completed Discharges', value: String(dischargeRequests.value.filter((r) => r.status === 'completed').length) },
  { icon: AlertTriangle, label: 'Awaiting Billing', value: String(dischargeRequests.value.filter((r) => !r.billing_verified && r.status !== 'rejected' && r.status !== 'completed').length) },
])

const dischargeStatusIcon: Record<string, typeof Clock> = {
  pending: Clock,
  in_progress: Clock,
  approved: CheckCircle2,
  rejected: XCircle,
  completed: Circle,
}

const dischargeStatus = computed(() => {
  const order = ['pending', 'in_progress', 'approved', 'completed', 'rejected']
  return order.map((label) => ({
    label,
    count: dischargeRequests.value.filter((r) => r.status === label).length,
    color: requestStatusColor[label],
    icon: dischargeStatusIcon[label],
  }))
})
const statusTotal = computed(() => dischargeStatus.value.reduce((sum, s) => sum + s.count, 0))
const hoveredStatus = ref<number | null>(null)

// Discharges per day, current week (Mon–Sun) vs. the same weekday last
// week, counted off patients.discharge_date.
function startOfWeek(date: Date) {
  const d = new Date(date)
  const day = d.getDay()
  const diff = (day === 0 ? -6 : 1) - day
  d.setDate(d.getDate() + diff)
  d.setHours(0, 0, 0, 0)
  return d
}

function countDischargesOnDay(weekStart: Date, dayOffset: number) {
  const dayStart = new Date(weekStart)
  dayStart.setDate(dayStart.getDate() + dayOffset)
  const dayEnd = new Date(dayStart)
  dayEnd.setDate(dayEnd.getDate() + 1)
  return patients.value.filter((p) => {
    if (!p.discharge_date) return false
    const d = new Date(p.discharge_date)
    return d >= dayStart && d < dayEnd
  }).length
}

const weeklyTrend = computed(() => {
  const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
  const thisWeekStart = startOfWeek(new Date())
  const lastWeekStart = new Date(thisWeekStart)
  lastWeekStart.setDate(lastWeekStart.getDate() - 7)

  return dayLabels.map((day, i) => ({
    day,
    count: countDischargesOnDay(thisWeekStart, i),
    lastWeek: countDischargesOnDay(lastWeekStart, i),
  }))
})
const weeklyMax = computed(() => Math.max(1, ...weeklyTrend.value.map((d) => Math.max(d.count, d.lastWeek))))
const weeklyTotal = computed(() => weeklyTrend.value.reduce((sum, d) => sum + d.count, 0))
const lastWeekTotal = computed(() => weeklyTrend.value.reduce((sum, d) => sum + d.lastWeek, 0))
const weeklyDeltaPct = computed(() => {
  if (lastWeekTotal.value === 0) return weeklyTotal.value === 0 ? 0 : 100
  return Math.round(((weeklyTotal.value - lastWeekTotal.value) / lastWeekTotal.value) * 100)
})
const hoveredDay = ref<number | null>(null)
</script>

<template>
  <div class="flex min-h-screen bg-muted/30">
    <!-- Sidebar (desktop) -->
    <aside class="hidden w-64 shrink-0 flex-col border-r border-border bg-card lg:sticky lg:top-0 lg:flex lg:h-screen">
      <div class="flex h-16 shrink-0 items-center gap-2.5 border-b border-border px-6">
        <span class="flex h-9 w-9 items-center justify-center rounded-lg bg-primary text-primary-foreground">
          <Activity class="h-5 w-5" />
        </span>
        <span class="font-semibold tracking-tight">AHDMS</span>
      </div>

      <nav class="flex-1 space-y-1 overflow-y-auto px-3 py-4">
        <button
          v-for="item in navItems"
          :key="item.label"
          type="button"
          class="flex w-full items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors"
          :class="activeSection === item.section
            ? 'bg-primary/10 text-primary'
            : 'text-muted-foreground hover:bg-muted hover:text-foreground'"
          @click="activeSection = item.section"
        >
          <component :is="item.icon" class="h-4 w-4" />
          {{ item.label }}
        </button>
      </nav>

      <div class="shrink-0 border-t border-border p-3">
        <div class="flex items-center gap-3 rounded-md px-3 py-2">
          <span class="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-xs font-medium text-secondary-foreground">
            {{ officerInitials || 'AD' }}
          </span>
          <div class="min-w-0 flex-1 leading-tight">
            <p class="truncate text-sm font-medium">{{ officerFullName || 'Admin' }}</p>
            <p class="truncate text-xs text-muted-foreground">System Administrator</p>
          </div>
        </div>
        <button
          type="button"
          :disabled="isLoggingOut"
          class="mt-1 flex w-full items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:cursor-not-allowed disabled:opacity-60"
          @click="showLogoutConfirm = true"
        >
          <LoaderCircle v-if="isLoggingOut" class="h-4 w-4 animate-spin" />
          <LogOut v-else class="h-4 w-4" />
          {{ isLoggingOut ? 'Logging out…' : 'Log Out' }}
        </button>
      </div>
    </aside>

    <!-- Sidebar (mobile) -->
    <div v-if="sidebarOpen" class="fixed inset-0 z-40 lg:hidden">
      <div class="absolute inset-0 bg-black/40" @click="sidebarOpen = false" />
      <aside class="relative flex h-full w-64 flex-col bg-card">
        <div class="flex h-16 shrink-0 items-center justify-between border-b border-border px-6">
          <div class="flex items-center gap-2.5">
            <span class="flex h-9 w-9 items-center justify-center rounded-lg bg-primary text-primary-foreground">
              <Activity class="h-5 w-5" />
            </span>
            <span class="font-semibold tracking-tight">AHDMS</span>
          </div>
          <button aria-label="Close menu" @click="sidebarOpen = false">
            <X class="h-5 w-5 text-muted-foreground" />
          </button>
        </div>
        <nav class="flex-1 space-y-1 overflow-y-auto px-3 py-4">
          <button
            v-for="item in navItems"
            :key="item.label"
            type="button"
            class="flex w-full items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors"
            :class="activeSection === item.section
              ? 'bg-primary/10 text-primary'
              : 'text-muted-foreground hover:bg-muted hover:text-foreground'"
            @click="activeSection = item.section; sidebarOpen = false"
          >
            <component :is="item.icon" class="h-4 w-4" />
            {{ item.label }}
          </button>
        </nav>
        <div class="shrink-0 border-t border-border p-3">
          <div class="flex items-center gap-3 rounded-md px-3 py-2">
            <span class="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-xs font-medium text-secondary-foreground">
              {{ officerInitials || 'AD' }}
            </span>
            <div class="min-w-0 flex-1 leading-tight">
              <p class="truncate text-sm font-medium">{{ officerFullName || 'Admin' }}</p>
              <p class="truncate text-xs text-muted-foreground">System Administrator</p>
            </div>
          </div>
          <button
            type="button"
            :disabled="isLoggingOut"
            class="mt-1 flex w-full items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:cursor-not-allowed disabled:opacity-60"
            @click="showLogoutConfirm = true"
          >
            <LoaderCircle v-if="isLoggingOut" class="h-4 w-4 animate-spin" />
            <LogOut v-else class="h-4 w-4" />
            {{ isLoggingOut ? 'Logging out…' : 'Log Out' }}
          </button>
        </div>
      </aside>
    </div>

    <!-- Main -->
    <div class="flex min-w-0 flex-1 flex-col">
      <!-- Top bar -->
      <header class="flex h-16 items-center gap-4 border-b border-border bg-card px-4 sm:px-6">
        <button aria-label="Open menu" class="text-muted-foreground lg:hidden" @click="sidebarOpen = true">
          <Menu class="h-5 w-5" />
        </button>

        <div class="min-w-0 flex-1">
          <h1 class="truncate text-base font-semibold tracking-tight">Admin Dashboard</h1>
        </div>

        <div class="relative hidden max-w-xs flex-1 sm:block">
          <Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <input
            v-model="patientSearchQuery"
            type="search"
            placeholder="Search patients…"
            class="w-full rounded-md border border-input bg-background py-2 pl-9 pr-3 text-sm outline-none placeholder:text-muted-foreground focus-visible:ring-2 focus-visible:ring-ring"
          >
        </div>

        <button
          :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'"
          class="text-muted-foreground hover:text-foreground"
          @click="toggleDarkMode"
        >
          <Sun v-if="isDark" class="h-5 w-5" />
          <Moon v-else class="h-5 w-5" />
        </button>

        <button aria-label="Notifications" class="relative text-muted-foreground hover:text-foreground">
          <Bell class="h-5 w-5" />
          <span v-if="approvedAwaitingCompletion.length > 0" class="absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full bg-[#d03b3b]" />
        </button>

        <span class="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-xs font-medium text-secondary-foreground">
          {{ officerInitials || 'AD' }}
        </span>
      </header>

      <main class="flex-1 space-y-6 p-4 sm:p-6">
        <template v-if="activeSection === 'overview'">
        <!-- Stat tiles -->
        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <div
            v-for="tile in statTiles"
            :key="tile.label"
            class="rounded-xl border border-border bg-card p-5"
          >
            <span class="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10">
              <component :is="tile.icon" class="h-4.5 w-4.5 text-primary" />
            </span>
            <p class="mt-4 text-2xl font-semibold tracking-tight tabular-nums">{{ tile.value }}</p>
            <p class="mt-1 text-sm text-muted-foreground">{{ tile.label }}</p>
          </div>
        </div>

        <div class="grid gap-4 xl:grid-cols-3">
          <!-- Weekly discharge trend -->
          <div class="rounded-xl border border-border bg-card p-5 xl:col-span-2">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h2 class="text-sm font-medium">Discharges This Week</h2>
                <p class="text-xs text-muted-foreground">Finalized discharges per day vs. last week</p>
              </div>
              <span
                class="flex items-center gap-1 text-xs font-medium"
                :class="weeklyDeltaPct >= 0 ? 'text-[#0ca30c]' : 'text-[#d03b3b]'"
              >
                <TrendingUp v-if="weeklyDeltaPct >= 0" class="h-3.5 w-3.5" />
                <TrendingUp v-else class="h-3.5 w-3.5 rotate-180" />
                {{ weeklyDeltaPct >= 0 ? '+' : '' }}{{ weeklyDeltaPct }}% vs last week
              </span>
            </div>

            <div class="mt-4 flex items-center gap-4 text-xs text-muted-foreground">
              <span class="flex items-center gap-1.5">
                <span class="h-2 w-2 rounded-full bg-primary" />
                This week
              </span>
              <span class="flex items-center gap-1.5">
                <span class="h-2 w-2 rounded-full bg-primary/25" />
                Last week
              </span>
            </div>

            <div class="relative mt-4 flex h-48 gap-3 sm:gap-4">
              <div class="pointer-events-none absolute inset-x-0 top-0 flex h-full flex-col justify-between">
                <div v-for="n in 4" :key="n" class="border-t border-border/60 first:border-transparent" />
              </div>

              <div
                v-for="(day, i) in weeklyTrend"
                :key="day.day"
                class="relative z-10 flex flex-1 flex-col items-center gap-2"
                @mouseenter="hoveredDay = i"
                @mouseleave="hoveredDay = null"
              >
                <div
                  v-if="hoveredDay === i"
                  class="absolute -top-14 whitespace-nowrap rounded-md bg-foreground px-2.5 py-1.5 text-xs font-medium text-background shadow-sm"
                >
                  <div class="tabular-nums">This week: {{ day.count }}</div>
                  <div class="tabular-nums opacity-70">Last week: {{ day.lastWeek }}</div>
                </div>
                <div class="flex w-full flex-1 items-end justify-center gap-1">
                  <div
                    class="w-full max-w-3.5 rounded-t-sm transition-colors"
                    :class="hoveredDay === i ? 'bg-primary' : 'bg-primary/80'"
                    :style="{ height: `${(day.count / weeklyMax) * 100}%` }"
                  />
                  <div
                    class="w-full max-w-3.5 rounded-t-sm bg-primary/25 transition-colors"
                    :class="hoveredDay === i ? 'bg-primary/35' : 'bg-primary/25'"
                    :style="{ height: `${(day.lastWeek / weeklyMax) * 100}%` }"
                  />
                </div>
                <span class="text-xs text-muted-foreground">{{ day.day }}</span>
              </div>
            </div>
          </div>

          <!-- Discharge status breakdown -->
          <div class="rounded-xl border border-border bg-card p-5">
            <h2 class="text-sm font-medium">Discharge Status</h2>
            <p class="text-xs text-muted-foreground">{{ statusTotal }} discharge request{{ statusTotal === 1 ? '' : 's' }}, hospital-wide</p>

            <div v-if="statusTotal === 0" class="flex h-24 items-center justify-center text-sm text-muted-foreground">
              No discharge requests yet.
            </div>
            <template v-else>
              <div class="mt-5 flex h-3 w-full overflow-hidden rounded-full bg-muted">
                <div
                  v-for="(status, i) in dischargeStatus"
                  :key="status.label"
                  class="h-full transition-opacity"
                  :style="{
                    width: `${(status.count / statusTotal) * 100}%`,
                    backgroundColor: status.color,
                    opacity: hoveredStatus === null || hoveredStatus === i ? 1 : 0.35,
                  }"
                  @mouseenter="hoveredStatus = i"
                  @mouseleave="hoveredStatus = null"
                />
              </div>

              <ul class="mt-5 space-y-3">
                <li
                  v-for="(status, i) in dischargeStatus"
                  :key="status.label"
                  class="flex items-center justify-between text-sm"
                  @mouseenter="hoveredStatus = i"
                  @mouseleave="hoveredStatus = null"
                >
                  <span class="flex items-center gap-2">
                    <component :is="status.icon" class="h-4 w-4" :style="{ color: status.color }" />
                    <span class="capitalize" :class="hoveredStatus !== null && hoveredStatus !== i ? 'text-muted-foreground' : ''">
                      {{ status.label.replace('_', ' ') }}
                    </span>
                  </span>
                  <span class="font-medium tabular-nums">{{ status.count }}</span>
                </li>
              </ul>
            </template>
          </div>
        </div>
        </template>

        <!-- Discharge Queue -->
        <div v-if="activeSection === 'discharge-queue'" class="rounded-xl border border-border bg-card p-5">
          <h2 class="text-sm font-medium">Discharge Queue</h2>
          <p class="text-xs text-muted-foreground">Approved by a doctor, awaiting final completion</p>

          <div v-if="dischargeRequestsError" class="mt-4 flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2.5 text-sm text-[#d03b3b]">
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ dischargeRequestsError }}
          </div>

          <div class="mt-4 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-border text-left text-xs text-muted-foreground">
                  <th class="pb-2 pr-4 font-medium">Patient</th>
                  <th class="pb-2 pr-4 font-medium">Requested By</th>
                  <th class="pb-2 pr-4 font-medium">Approved By</th>
                  <th class="pb-2 font-medium">Submitted</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-border">
                <tr v-for="request in approvedAwaitingCompletion" :key="request.request_id">
                  <td class="py-2 pr-4 font-medium">{{ request.patient_name }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ request.requested_by_name }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ request.approved_by_name ?? '—' }}</td>
                  <td class="py-2 text-muted-foreground">{{ new Date(request.timestamp).toLocaleString() }}</td>
                </tr>
                <tr v-if="!isLoadingDischargeRequests && approvedAwaitingCompletion.length === 0">
                  <td colspan="4" class="py-6 text-center text-sm text-muted-foreground">No approved requests are awaiting completion.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Patients -->
        <div v-if="activeSection === 'patients'" class="rounded-xl border border-border bg-card p-5">
          <div>
            <h2 class="text-sm font-medium">Patient Records</h2>
            <p class="text-xs text-muted-foreground">
              {{ patientSearchQuery ? `Showing results for "${patientSearchQuery}"` : 'All patients, hospital-wide (read-only)' }}
            </p>
          </div>

          <div v-if="patientsError" class="mt-4 flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2.5 text-sm text-[#d03b3b]">
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ patientsError }}
          </div>

          <div class="mt-4 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-border text-left text-xs text-muted-foreground">
                  <th class="pb-2 pr-4 font-medium">Name</th>
                  <th class="pb-2 pr-4 font-medium">Admitted</th>
                  <th class="pb-2 pr-4 font-medium">Room</th>
                  <th class="pb-2 pr-4 font-medium">PhilHealth No.</th>
                  <th class="pb-2 pr-4 font-medium">Discharge Date</th>
                  <th class="pb-2 font-medium" />
                </tr>
              </thead>
              <tbody class="divide-y divide-border">
                <tr v-for="patient in filteredPatients" :key="patient.patient_id">
                  <td class="py-2 pr-4 font-medium">{{ patient.full_name }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ patient.admission_date }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ patient.room_number ?? '—' }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ patient.philhealth_no ?? '—' }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ patient.discharge_date ?? '—' }}</td>
                  <td class="py-2 text-right">
                    <button type="button" class="text-xs font-medium text-primary hover:underline" @click="viewingPatient = patient">
                      View
                    </button>
                  </td>
                </tr>
                <tr v-if="!isLoadingPatients && filteredPatients.length === 0">
                  <td colspan="6" class="py-6 text-center text-sm text-muted-foreground">
                    {{ patientSearchQuery ? 'No patients match your search.' : 'No patients yet.' }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Staff -->
        <div v-if="activeSection === 'staff'" class="space-y-6">
          <div class="rounded-xl border border-border bg-card p-5">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h2 class="text-sm font-medium">Staff</h2>
                <p class="mt-1 text-xs text-muted-foreground">All staff members, hospital-wide</p>
              </div>
              <button
                type="button"
                class="rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground transition-opacity hover:opacity-90"
                @click="openRegisterStaffForm"
              >
                Register Staff
              </button>
            </div>

            <div v-if="staffError" class="mt-4 flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2.5 text-sm text-[#d03b3b]">
              <AlertTriangle class="h-4 w-4 shrink-0" />
              {{ staffError }}
            </div>

            <div class="mt-4 overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-border text-left text-xs text-muted-foreground">
                    <th class="pb-2 pr-4 font-medium">Name</th>
                    <th class="pb-2 pr-4 font-medium">Role</th>
                    <th class="pb-2 font-medium">Duty status</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-border">
                  <tr v-for="officer in officers" :key="officer.officer_id">
                    <td class="py-2 pr-4 font-medium">{{ officer.full_name }}</td>
                    <td class="py-2 pr-4 text-muted-foreground capitalize">{{ officer.role }}</td>
                    <td class="py-2">
                      <button
                        type="button"
                        :disabled="updatingOfficerId === officer.officer_id"
                        class="rounded-full px-2.5 py-1 text-xs font-medium capitalize transition-opacity hover:opacity-80 disabled:cursor-not-allowed disabled:opacity-60"
                        :class="officer.duty_status === 'on_duty' ? 'bg-[#0ca30c]/10 text-[#0ca30c]' : 'bg-muted text-muted-foreground'"
                        @click="toggleDutyStatus(officer)"
                      >
                        {{ officer.duty_status.replace('_', ' ') }}
                      </button>
                    </td>
                  </tr>
                  <tr v-if="!isLoadingStaff && officers.length === 0">
                    <td colspan="3" class="py-6 text-center text-sm text-muted-foreground">No staff found.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Settings -->
        <div v-if="activeSection === 'settings'" class="rounded-xl border border-border bg-card p-5">
          <h2 class="text-sm font-medium">Settings</h2>
          <p class="mt-1 text-xs text-muted-foreground">Nothing here yet.</p>
        </div>
      </main>
    </div>

    <!-- Logout confirmation modal -->
    <div v-if="showLogoutConfirm" class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/40" @click="!isLoggingOut && (showLogoutConfirm = false)" />
      <div class="relative w-full max-w-sm rounded-xl border border-border bg-card p-6 shadow-lg">
        <span class="flex h-10 w-10 items-center justify-center rounded-full bg-[#d03b3b]/10">
          <LogOut class="h-5 w-5 text-[#d03b3b]" />
        </span>
        <h2 class="mt-4 text-base font-semibold tracking-tight">Log out of AHDMS?</h2>
        <p class="mt-1.5 text-sm text-muted-foreground">
          You'll need to sign in again to access the discharge dashboard.
        </p>

        <div class="mt-6 flex gap-3">
          <button
            type="button"
            :disabled="isLoggingOut"
            class="flex-1 rounded-md border border-border py-2 text-sm font-medium transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-60"
            @click="showLogoutConfirm = false"
          >
            No, stay
          </button>
          <button
            type="button"
            :disabled="isLoggingOut"
            class="flex flex-1 items-center justify-center gap-2 rounded-md bg-[#d03b3b] py-2 text-sm font-medium text-white transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            @click="handleLogout"
          >
            <LoaderCircle v-if="isLoggingOut" class="h-4 w-4 animate-spin" />
            {{ isLoggingOut ? 'Logging out…' : 'Yes, log out' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Patient view modal -->
    <div v-if="viewingPatient" class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/40" @click="viewingPatient = null" />
      <div class="relative flex max-h-[90vh] w-full max-w-md flex-col rounded-xl border border-border bg-card p-6 shadow-lg">
        <h2 class="shrink-0 text-base font-semibold tracking-tight">Patient Information</h2>

        <dl class="mt-4 min-h-0 flex-1 space-y-3 overflow-y-auto pr-1">
          <div v-for="field in viewingPatientFields" :key="field.label" class="flex justify-between gap-4 border-b border-border pb-2 text-sm">
            <dt class="text-muted-foreground">{{ field.label }}</dt>
            <dd class="text-right font-medium">{{ field.value }}</dd>
          </div>
        </dl>

        <button
          type="button"
          class="mt-4 shrink-0 rounded-md border border-border py-2 text-sm font-medium transition-colors hover:bg-muted"
          @click="viewingPatient = null"
        >
          Close
        </button>
      </div>
    </div>

    <!-- Register staff modal -->
    <div v-if="showRegisterStaffForm" class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/40" @click="!isRegisteringStaff && (showRegisterStaffForm = false)" />
      <div class="relative w-full max-w-md rounded-xl border border-border bg-card p-6 shadow-lg">
        <h2 class="text-base font-semibold tracking-tight">Register New Staff</h2>
        <p class="mt-1 text-xs text-muted-foreground">Creates a login and an officer profile in one go</p>

        <form class="mt-4 grid gap-4 sm:grid-cols-2" @submit.prevent="registerStaff">
          <div class="space-y-1.5">
            <label for="staff-full-name" class="text-sm font-medium">Full name</label>
            <input
              id="staff-full-name"
              v-model="newStaffForm.full_name"
              type="text"
              required
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
          </div>
          <div class="space-y-1.5">
            <label for="staff-role" class="text-sm font-medium">Role</label>
            <select
              id="staff-role"
              v-model="newStaffForm.role"
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option v-for="option in roleOptions" :key="option" :value="option" class="capitalize">{{ option }}</option>
            </select>
          </div>
          <div class="space-y-1.5 sm:col-span-2">
            <label for="staff-email" class="text-sm font-medium">Email</label>
            <input
              id="staff-email"
              v-model="newStaffForm.email"
              type="email"
              required
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
          </div>
          <div class="space-y-1.5 sm:col-span-2">
            <label for="staff-password" class="text-sm font-medium">Password</label>
            <input
              id="staff-password"
              v-model="newStaffForm.password"
              type="password"
              required
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
          </div>

          <div v-if="registerStaffError" class="flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2 text-xs text-[#d03b3b] sm:col-span-2">
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ registerStaffError }}
          </div>

          <div class="flex gap-3 sm:col-span-2">
            <button
              type="button"
              :disabled="isRegisteringStaff"
              class="flex-1 rounded-md border border-border py-2 text-sm font-medium transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-60"
              @click="showRegisterStaffForm = false"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="isRegisteringStaff"
              class="flex flex-1 items-center justify-center gap-2 rounded-md bg-primary py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              <LoaderCircle v-if="isRegisteringStaff" class="h-4 w-4 animate-spin" />
              {{ isRegisteringStaff ? 'Registering…' : 'Register Staff' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>
