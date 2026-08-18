<script setup lang="ts">
import {
  Activity,
  AlertTriangle,
  Bell,
  CheckCircle2,
  Circle,
  ClipboardCheck,
  Clock,
  LayoutDashboard,
  LoaderCircle,
  LogOut,
  Menu,
  Moon,
  Search,
  Stethoscope,
  Sun,
  TrendingUp,
  Users,
  X,
  XCircle,
} from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'

definePageMeta({
  middleware: 'auth',
  requiredRole: 'doctor',
})

useHead({
  title: 'Doctor Dashboard — AHDMS',
  meta: [
    {
      name: 'description',
      content: 'Physician discharge dashboard for the Automated Hospital Discharge Management System at Butuan Medical Center.',
    },
  ],
})

const supabase = useSupabaseClient()
const session = useAdminSession()
const doctorId = computed(() => Number(session.value?.id))
const officerFullName = computed(() => session.value?.fullName ?? '')

const { isDark, init: initDarkMode, toggle: toggleDarkMode } = useDarkMode()
onMounted(initDarkMode)

const { initials: officerInitials } = useOfficerName(officerFullName)

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
  { label: 'Discharge Requests', icon: Stethoscope, section: 'discharge-requests' },
  { label: 'My Sign-offs', icon: ClipboardCheck, section: 'tasks' },
  { label: 'Patients', icon: Users, section: 'patients' },
] as const

type Section = typeof navItems[number]['section']

const activeSection = ref<Section>('overview')

// ── Data ──────────────────────────────────────────────────────────────

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

interface DoctorTask {
  task_id: number
  discharge_request_id: number
  patient_id: number
  patient_name: string
  status: string
  created_at: string
}

const requestStatusColor: Record<string, string> = {
  pending: '#fab219',
  in_progress: '#2a78d6',
  approved: '#0ca30c',
  completed: '#898781',
  rejected: '#d03b3b',
}

const patients = ref<Patient[]>([])
const dischargeRequests = ref<DischargeRequest[]>([])
const tasks = ref<DoctorTask[]>([])
const isLoadingData = ref(false)
const dataError = ref('')

async function loadDashboardData() {
  isLoadingData.value = true
  const errors: string[] = []

  const [patientsRes, requestsRes, tasksRes] = await Promise.all([
    supabase.rpc('list_all_patients'),
    supabase.rpc('list_discharge_requests_detailed', { p_status: null }),
    supabase.rpc('list_tasks_for_officer_detailed', { p_officer_id: doctorId.value }),
  ])

  if (patientsRes.error) errors.push(`Patients: ${patientsRes.error.message}`)
  else patients.value = patientsRes.data ?? []

  if (requestsRes.error) errors.push(`Discharge requests: ${requestsRes.error.message}`)
  else dischargeRequests.value = requestsRes.data ?? []

  if (tasksRes.error) errors.push(`Sign-off tasks: ${tasksRes.error.message}`)
  else tasks.value = tasksRes.data ?? []

  dataError.value = errors.join(' ')
  isLoadingData.value = false
}

onMounted(loadDashboardData)

const pendingTasks = computed(() => tasks.value.filter((t) => t.status !== 'done'))

// ── Overview stats ───────────────────────────────────────────────────

const statTiles = computed(() => {
  const pending = dischargeRequests.value.filter((r) => r.status === 'pending' || r.status === 'in_progress').length
  const approved = dischargeRequests.value.filter((r) => r.status === 'approved').length
  return [
    { icon: Stethoscope, label: 'Awaiting Sign-off', value: String(pending) },
    { icon: CheckCircle2, label: 'Approved', value: String(approved) },
    { icon: Users, label: 'Total Requests', value: String(dischargeRequests.value.length) },
  ]
})

const dischargeStatusIcon: Record<string, typeof Clock> = {
  pending: Clock,
  in_progress: Clock,
  approved: CheckCircle2,
  rejected: XCircle,
  completed: Circle,
}

const dischargeStatus = computed(() => {
  const order = ['pending', 'in_progress', 'approved', 'completed', 'rejected']
  const counts = order.map((label) => ({
    label,
    count: dischargeRequests.value.filter((r) => r.status === label).length,
    color: requestStatusColor[label],
    icon: dischargeStatusIcon[label],
  }))
  const total = counts.reduce((sum, c) => sum + c.count, 0)
  return counts.map((c) => ({ ...c, widthPct: total > 0 ? (c.count / total) * 100 : 0 }))
})
const statusTotal = computed(() => dischargeStatus.value.reduce((sum, s) => sum + s.count, 0))
const hoveredStatus = ref<number | null>(null)

// Discharges per day, current week (Mon–Sun) vs. the same weekday last
// week, counted off patients.discharge_date (set when a request is
// finalized via complete_discharge_request).
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
const weeklyMax = computed(() =>
  Math.max(1, ...weeklyTrend.value.map((d) => Math.max(d.count, d.lastWeek))),
)
const weeklyTotal = computed(() => weeklyTrend.value.reduce((sum, d) => sum + d.count, 0))
const lastWeekTotal = computed(() => weeklyTrend.value.reduce((sum, d) => sum + d.lastWeek, 0))
const weeklyDeltaPct = computed(() => {
  if (lastWeekTotal.value === 0) return weeklyTotal.value === 0 ? 0 : 100
  return Math.round(((weeklyTotal.value - lastWeekTotal.value) / lastWeekTotal.value) * 100)
})
const hoveredDay = ref<number | null>(null)

// ── Sign-off tasks ───────────────────────────────────────────────────

const completingTaskId = ref<number | null>(null)
const taskActionError = ref('')

async function completeTask(taskId: number) {
  completingTaskId.value = taskId
  taskActionError.value = ''

  const { error } = await supabase.rpc('complete_task', { p_task_id: taskId })

  if (error) {
    taskActionError.value = error.message
    completingTaskId.value = null
    return
  }

  completingTaskId.value = null
  await loadDashboardData()
}

// ── Approve / reject / finalize ─────────────────────────────────────

const pendingAction = ref<{ request: DischargeRequest; kind: 'approve' | 'reject' | 'finalize' } | null>(null)
const isProcessingAction = ref(false)
const actionError = ref('')

function confirmAction(request: DischargeRequest, kind: 'approve' | 'reject' | 'finalize') {
  actionError.value = ''
  pendingAction.value = { request, kind }
}

async function runPendingAction() {
  if (!pendingAction.value) return
  isProcessingAction.value = true
  actionError.value = ''

  const { request, kind } = pendingAction.value
  const { error } = kind === 'approve'
    ? await supabase.rpc('approve_discharge_request', { p_request_id: request.request_id, p_approved_by: doctorId.value })
    : kind === 'reject'
      ? await supabase.rpc('reject_discharge_request', { p_request_id: request.request_id, p_rejected_by: doctorId.value })
      : await supabase.rpc('complete_discharge_request', { p_request_id: request.request_id })

  if (error) {
    actionError.value = error.message
    isProcessingAction.value = false
    return
  }

  pendingAction.value = null
  isProcessingAction.value = false
  await loadDashboardData()
}

// ── Patients (read-only) ─────────────────────────────────────────────────

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

function viewPatientById(patientId: number) {
  viewingPatient.value = patients.value.find((p) => p.patient_id === patientId) ?? null
}
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
          <span
            v-if="item.section === 'tasks' && pendingTasks.length > 0"
            class="ml-auto rounded-full bg-primary/15 px-1.5 py-0.5 text-[10px] font-semibold text-primary"
          >
            {{ pendingTasks.length }}
          </span>
        </button>
      </nav>

      <div class="shrink-0 border-t border-border p-3">
        <div class="flex items-center gap-3 rounded-md px-3 py-2">
          <span class="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-xs font-medium text-secondary-foreground">
            {{ officerInitials || 'DR' }}
          </span>
          <div class="min-w-0 flex-1 leading-tight">
            <p class="truncate text-sm font-medium">{{ officerFullName || 'Doctor' }}</p>
            <p class="truncate text-xs text-muted-foreground">Attending Physician</p>
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
              {{ officerInitials || 'DR' }}
            </span>
            <div class="min-w-0 flex-1 leading-tight">
              <p class="truncate text-sm font-medium">{{ officerFullName || 'Doctor' }}</p>
              <p class="truncate text-xs text-muted-foreground">Attending Physician</p>
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
          <h1 class="truncate text-base font-semibold tracking-tight">Doctor Dashboard</h1>
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
          <span v-if="pendingTasks.length > 0" class="absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full bg-[#d03b3b]" />
        </button>

        <span class="flex h-8 w-8 items-center justify-center rounded-full bg-secondary text-xs font-medium text-secondary-foreground">
          {{ officerInitials || 'DR' }}
        </span>
      </header>

      <main class="flex-1 space-y-6 p-4 sm:p-6">
        <div v-if="dataError" class="flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2.5 text-sm text-[#d03b3b]">
          <AlertTriangle class="h-4 w-4 shrink-0" />
          {{ dataError }}
        </div>

        <template v-if="activeSection === 'overview'">
        <!-- Stat tiles -->
        <div class="grid gap-4 sm:grid-cols-3">
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

        <div class="grid items-stretch gap-4 xl:grid-cols-3">
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
                    width: `${status.widthPct}%`,
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

        <!-- Discharge Requests -->
        <div v-if="activeSection === 'discharge-requests'" class="rounded-xl border border-border bg-card p-5">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-sm font-medium">Discharge Requests</h2>
              <p class="text-xs text-muted-foreground">
                Hospital-wide, all nurses
              </p>
            </div>
          </div>

          <div class="mt-4 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-border text-left text-xs text-muted-foreground">
                  <th class="pb-2 pr-4 font-medium">Patient</th>
                  <th class="pb-2 pr-4 font-medium">Requested By</th>
                  <th class="pb-2 pr-4 font-medium">Billing Verified</th>
                  <th class="pb-2 pr-4 font-medium">Submitted</th>
                  <th class="pb-2 pr-4 font-medium">Status</th>
                  <th class="pb-2 font-medium" />
                </tr>
              </thead>
              <tbody class="divide-y divide-border">
                <tr v-for="request in dischargeRequests" :key="request.request_id">
                  <td class="py-2 pr-4">
                    <button type="button" class="font-medium text-primary hover:underline" @click="viewPatientById(request.patient_id)">
                      {{ request.patient_name }}
                    </button>
                  </td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ request.requested_by_name }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ request.billing_verified ? 'Yes' : 'No' }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ new Date(request.timestamp).toLocaleString() }}</td>
                  <td class="py-2 pr-4">
                    <span
                      class="inline-flex items-center gap-1.5 rounded-full px-2 py-1 text-xs font-medium capitalize"
                      :style="{ backgroundColor: `${requestStatusColor[request.status] ?? '#898781'}1a`, color: requestStatusColor[request.status] ?? '#898781' }"
                    >
                      <span class="h-1.5 w-1.5 rounded-full" :style="{ backgroundColor: requestStatusColor[request.status] ?? '#898781' }" />
                      {{ request.status.replace('_', ' ') }}
                    </span>
                  </td>
                  <td class="py-2 text-right">
                    <div v-if="request.status === 'pending' || request.status === 'in_progress'" class="flex justify-end gap-3">
                      <button type="button" class="text-xs font-medium text-[#0ca30c] hover:underline" @click="confirmAction(request, 'approve')">
                        Approve
                      </button>
                      <button type="button" class="text-xs font-medium text-[#d03b3b] hover:underline" @click="confirmAction(request, 'reject')">
                        Reject
                      </button>
                    </div>
                    <button
                      v-else-if="request.status === 'approved'"
                      type="button"
                      class="text-xs font-medium text-primary hover:underline"
                      @click="confirmAction(request, 'finalize')"
                    >
                      Finalize Discharge
                    </button>
                  </td>
                </tr>
                <tr v-if="!isLoadingData && dischargeRequests.length === 0">
                  <td colspan="6" class="py-6 text-center text-sm text-muted-foreground">No discharge requests yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- My Sign-offs -->
        <div v-if="activeSection === 'tasks'" class="rounded-xl border border-border bg-card p-5">
          <h2 class="text-sm font-medium">Doctor Sign-off Tasks</h2>
          <p class="text-xs text-muted-foreground">Auto-assigned when a discharge request is filed</p>

          <div v-if="taskActionError" class="mt-4 flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2.5 text-sm text-[#d03b3b]">
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ taskActionError }}
          </div>

          <div class="mt-4 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-border text-left text-xs text-muted-foreground">
                  <th class="pb-2 pr-4 font-medium">Patient</th>
                  <th class="pb-2 pr-4 font-medium">Assigned</th>
                  <th class="pb-2 pr-4 font-medium">Status</th>
                  <th class="pb-2 font-medium" />
                </tr>
              </thead>
              <tbody class="divide-y divide-border">
                <tr v-for="task in tasks" :key="task.task_id">
                  <td class="py-2 pr-4 font-medium">{{ task.patient_name }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ new Date(task.created_at).toLocaleString() }}</td>
                  <td class="py-2 pr-4">
                    <span
                      class="inline-flex items-center gap-1.5 rounded-full px-2 py-1 text-xs font-medium"
                      :class="task.status === 'done' ? 'bg-[#0ca30c]/10 text-[#0ca30c]' : 'bg-muted text-muted-foreground'"
                    >
                      <CheckCircle2 v-if="task.status === 'done'" class="h-3.5 w-3.5" />
                      {{ task.status === 'done' ? 'Done' : 'Pending' }}
                    </span>
                  </td>
                  <td class="py-2 text-right">
                    <button
                      v-if="task.status !== 'done'"
                      type="button"
                      :disabled="completingTaskId === task.task_id"
                      class="text-xs font-medium text-primary hover:underline disabled:cursor-not-allowed disabled:opacity-60"
                      @click="completeTask(task.task_id)"
                    >
                      {{ completingTaskId === task.task_id ? 'Completing…' : 'Mark Complete' }}
                    </button>
                  </td>
                </tr>
                <tr v-if="!isLoadingData && tasks.length === 0">
                  <td colspan="4" class="py-6 text-center text-sm text-muted-foreground">No sign-off tasks assigned yet.</td>
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
                <tr v-if="!isLoadingData && filteredPatients.length === 0">
                  <td colspan="6" class="py-6 text-center text-sm text-muted-foreground">
                    {{ patientSearchQuery ? 'No patients match your search.' : 'No patients yet.' }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
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

    <!-- Approve / reject / finalize confirmation modal -->
    <div v-if="pendingAction" class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/40" @click="!isProcessingAction && (pendingAction = null)" />
      <div class="relative w-full max-w-sm rounded-xl border border-border bg-card p-6 shadow-lg">
        <span
          class="flex h-10 w-10 items-center justify-center rounded-full"
          :class="pendingAction.kind === 'reject' ? 'bg-[#d03b3b]/10' : 'bg-[#0ca30c]/10'"
        >
          <XCircle v-if="pendingAction.kind === 'reject'" class="h-5 w-5 text-[#d03b3b]" />
          <CheckCircle2 v-else class="h-5 w-5 text-[#0ca30c]" />
        </span>
        <h2 class="mt-4 text-base font-semibold tracking-tight">
          <template v-if="pendingAction.kind === 'approve'">Approve discharge request?</template>
          <template v-else-if="pendingAction.kind === 'reject'">Reject discharge request?</template>
          <template v-else>Finalize discharge?</template>
        </h2>
        <p class="mt-1.5 text-sm text-muted-foreground">
          <template v-if="pendingAction.kind === 'approve'">
            Requires every task done and billing verified for
            <span class="font-medium text-foreground">{{ pendingAction.request.patient_name }}</span>.
          </template>
          <template v-else-if="pendingAction.kind === 'reject'">
            This will mark <span class="font-medium text-foreground">{{ pendingAction.request.patient_name }}</span>'s discharge request as rejected.
          </template>
          <template v-else>
            This will mark <span class="font-medium text-foreground">{{ pendingAction.request.patient_name }}</span> as officially discharged.
          </template>
        </p>

        <div v-if="actionError" class="mt-4 flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2 text-xs text-[#d03b3b]">
          <AlertTriangle class="h-4 w-4 shrink-0" />
          {{ actionError }}
        </div>

        <div class="mt-6 flex gap-3">
          <button
            type="button"
            :disabled="isProcessingAction"
            class="flex-1 rounded-md border border-border py-2 text-sm font-medium transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-60"
            @click="pendingAction = null"
          >
            Cancel
          </button>
          <button
            type="button"
            :disabled="isProcessingAction"
            class="flex flex-1 items-center justify-center gap-2 rounded-md py-2 text-sm font-medium text-white transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            :class="pendingAction.kind === 'reject' ? 'bg-[#d03b3b]' : 'bg-[#0ca30c]'"
            @click="runPendingAction"
          >
            <LoaderCircle v-if="isProcessingAction" class="h-4 w-4 animate-spin" />
            {{ isProcessingAction ? 'Saving…' : 'Yes, continue' }}
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
  </div>
</template>
