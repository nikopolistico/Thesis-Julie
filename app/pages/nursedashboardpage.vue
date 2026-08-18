<script setup lang="ts">
import {
  Activity,
  AlertTriangle,
  Bell,
  CheckCircle2,
  ClipboardCheck,
  LayoutDashboard,
  LoaderCircle,
  LogOut,
  Menu,
  Moon,
  Search,
  Stethoscope,
  Sun,
  Users,
  X,
} from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'

definePageMeta({
  middleware: 'auth',
  requiredRole: 'nurse',
})

useHead({
  title: 'Nurse Dashboard — AHDMS',
  meta: [
    {
      name: 'description',
      content: 'Nurse patient records dashboard for the Automated Hospital Discharge Management System at Butuan Medical Center.',
    },
  ],
})

const supabase = useSupabaseClient()
const session = useAdminSession()
const officerId = computed(() => Number(session.value?.id))
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
  { label: 'Overview', icon: LayoutDashboard, section: 'overview' },
  { label: 'My Patients', icon: Users, section: 'patients' },
  { label: 'Discharge Requests', icon: Stethoscope, section: 'discharge-requests' },
  { label: 'My Tasks', icon: ClipboardCheck, section: 'tasks' },
] as const

type Section = typeof navItems[number]['section']

const activeSection = ref<Section>('overview')

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
  attending_officer_id: number | null
}

interface DischargeRequest {
  request_id: number
  patient_id: number
  patient_name: string
  status: string
  billing_verified: boolean
  timestamp: string
}

interface NurseTask {
  task_id: number
  discharge_request_id: number
  patient_id: number
  patient_name: string
  task_type: string
  status: string
  created_at: string
  completed_at: string | null
}

const patients = ref<Patient[]>([])
const dischargeRequests = ref<DischargeRequest[]>([])
const tasks = ref<NurseTask[]>([])
const isLoadingData = ref(false)
const dataError = ref('')
const searchQuery = ref('')

async function loadDashboardData() {
  isLoadingData.value = true
  const errors: string[] = []

  const [patientsRes, requestsRes, tasksRes] = await Promise.all([
    supabase.rpc('list_patients_by_officer', { p_officer_id: officerId.value }),
    supabase.rpc('list_discharge_requests_by_requester', { p_officer_id: officerId.value }),
    supabase.rpc('list_tasks_for_officer_detailed', { p_officer_id: officerId.value }),
  ])

  if (patientsRes.error) errors.push(`Patients: ${patientsRes.error.message}`)
  else patients.value = patientsRes.data ?? []

  if (requestsRes.error) errors.push(`Discharge requests: ${requestsRes.error.message}`)
  else dischargeRequests.value = requestsRes.data ?? []

  if (tasksRes.error) errors.push(`Tasks: ${tasksRes.error.message}`)
  else tasks.value = tasksRes.data ?? []

  dataError.value = errors.join(' ')
  isLoadingData.value = false
}

onMounted(loadDashboardData)

const filteredPatients = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return patients.value
  return patients.value.filter((patient) => {
    return patient.full_name.toLowerCase().includes(q)
      || (patient.philhealth_no ?? '').toLowerCase().includes(q)
      || (patient.contact_number ?? '').toLowerCase().includes(q)
      || String(patient.room_number ?? '').includes(q)
  })
})

// ── Overview: patient / discharge summary (bar chart) ───────────────────

const summaryBarColor: Record<string, string> = {
  'Total Patients': '#2a78d6',
  'Currently Admitted': '#eb6834',
  'Discharged': '#1baf7a',
  'Discharge Requests': '#eda100',
}

const summaryChartData = computed(() => {
  const counts = [
    { label: 'Total Patients', count: patients.value.length },
    { label: 'Currently Admitted', count: patients.value.filter((p) => !p.discharge_date).length },
    { label: 'Discharged', count: patients.value.filter((p) => p.discharge_date).length },
    { label: 'Discharge Requests', count: dischargeRequests.value.length },
  ].map((c) => ({ ...c, color: summaryBarColor[c.label] }))
  const max = Math.max(1, ...counts.map((c) => c.count))
  return counts.map((c) => ({ ...c, heightPct: (c.count / max) * 100 }))
})

const hoveredSummary = ref<string | null>(null)

const statusBarColor: Record<string, string> = {
  pending: '#fab219',
  in_progress: '#2a78d6',
  approved: '#0ca30c',
  completed: '#898781',
  rejected: '#d03b3b',
}

const pendingTasks = computed(() => tasks.value.filter((t) => t.status !== 'done'))

// ── Overview: recent activity ───────────────────────────────────────────

const recentPatients = computed(() => patients.value.slice(0, 5))
const recentDischargeRequests = computed(() => dischargeRequests.value.slice(0, 5))

// ── Tasks: complete nurse clearance ─────────────────────────────────────

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

// ── Discharge requests: create ────────────────────────────────────────

const requestFormError = ref('')
const showRequestForm = ref(false)
const showConfirmRequest = ref(false)
const requestPatientId = ref<number | null>(null)
const requestPatientSearch = ref('')
const isSavingRequest = ref(false)

const TERMINAL_STATUSES = ['completed', 'rejected']

function hasActiveRequest(patientId: number) {
  return dischargeRequests.value.some((r) => r.patient_id === patientId && !TERMINAL_STATUSES.includes(r.status))
}

const dischargeablePatients = computed(() => patients.value.filter((p) => !p.discharge_date && !hasActiveRequest(p.patient_id)))

const filteredRequestPatients = computed(() => {
  const q = requestPatientSearch.value.trim().toLowerCase()
  if (!q) return dischargeablePatients.value
  return dischargeablePatients.value.filter((p) => p.full_name.toLowerCase().includes(q))
})

const selectedRequestPatientName = computed(() => patients.value.find((p) => p.patient_id === requestPatientId.value)?.full_name ?? '')

function openNewRequestForm() {
  requestPatientId.value = dischargeablePatients.value[0]?.patient_id ?? null
  requestPatientSearch.value = ''
  requestFormError.value = ''
  showRequestForm.value = true
}

function confirmNewRequest() {
  if (requestPatientId.value === null) return
  showConfirmRequest.value = true
}

async function submitNewRequest() {
  if (requestPatientId.value === null) return

  isSavingRequest.value = true
  requestFormError.value = ''

  const { error } = await supabase.rpc('create_discharge_request', {
    p_patient_id: requestPatientId.value,
    p_requested_by: officerId.value,
  })

  if (error) {
    requestFormError.value = error.message
    isSavingRequest.value = false
    return
  }

  showConfirmRequest.value = false
  showRequestForm.value = false
  isSavingRequest.value = false
  await loadDashboardData()
}

// ── Patients: add / edit ──────────────────────────────────────────────

const showPatientForm = ref(false)
const editingPatientId = ref<number | null>(null)
const emptyPatientForm = {
  full_name: '',
  date_of_birth: '',
  age: '',
  contact_number: '',
  emergency_contact: '',
  room_number: '',
  philhealth_no: '',
}
const patientForm = ref({ ...emptyPatientForm })
const isSavingPatient = ref(false)
const patientFormError = ref('')
const patientFormStep = ref<'form' | 'preview'>('form')

const patientPreviewFields = computed(() => [
  { label: 'Full name', value: patientForm.value.full_name },
  { label: 'Age', value: patientForm.value.age || '—' },
  { label: 'Date of birth', value: patientForm.value.date_of_birth || '—' },
  { label: 'Contact number', value: patientForm.value.contact_number || '—' },
  { label: 'Emergency contact', value: patientForm.value.emergency_contact || '—' },
  { label: 'Room number', value: patientForm.value.room_number || '—' },
  { label: 'PhilHealth No.', value: patientForm.value.philhealth_no || '—' },
])

function openNewPatientForm() {
  editingPatientId.value = null
  patientForm.value = { ...emptyPatientForm }
  patientFormError.value = ''
  patientFormStep.value = 'form'
  showPatientForm.value = true
}

function openEditPatientForm(patient: Patient) {
  editingPatientId.value = patient.patient_id
  patientForm.value = {
    full_name: patient.full_name,
    date_of_birth: patient.date_of_birth ?? '',
    age: patient.age === null ? '' : String(patient.age),
    contact_number: patient.contact_number ?? '',
    emergency_contact: patient.emergency_contact ?? '',
    room_number: patient.room_number === null ? '' : String(patient.room_number),
    philhealth_no: patient.philhealth_no ?? '',
  }
  patientFormError.value = ''
  patientFormStep.value = 'form'
  showPatientForm.value = true
}

function handlePatientFormSubmit() {
  if (patientFormStep.value === 'form') {
    patientFormError.value = ''
    patientFormStep.value = 'preview'
    return
  }
  submitPatientForm()
}

async function submitPatientForm() {
  isSavingPatient.value = true
  patientFormError.value = ''

  if (patientForm.value.contact_number && !/^\+?\d{7,15}$/.test(patientForm.value.contact_number)) {
    patientFormError.value = 'Invalid contact number format. Please enter a valid number.'
    isSavingPatient.value = false
    return
  }

  const { error } = editingPatientId.value === null
    ? await supabase.rpc('register_patient', {
        p_full_name: patientForm.value.full_name,
        p_date_of_birth: patientForm.value.date_of_birth || null,
        p_age: patientForm.value.age === '' ? null : Number(patientForm.value.age),
        p_contact_number: patientForm.value.contact_number || null,
        p_emergency_contact: patientForm.value.emergency_contact || null,
        p_room_number: patientForm.value.room_number === '' ? null : Number(patientForm.value.room_number),
        p_philhealth_no: patientForm.value.philhealth_no || null,
        p_attending_officer_id: officerId.value,
      })
    : await supabase.rpc('update_patient_info', {
        p_patient_id: editingPatientId.value,
        p_contact_number: patientForm.value.contact_number || null,
        p_emergency_contact: patientForm.value.emergency_contact || null,
        p_room_number: patientForm.value.room_number === '' ? null : Number(patientForm.value.room_number),
      })

  if (error) {
    patientFormError.value = error.message
    isSavingPatient.value = false
    return
  }

  showPatientForm.value = false
  isSavingPatient.value = false
  await loadDashboardData()
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
            {{ officerInitials || 'RN' }}
          </span>
          <div class="min-w-0 flex-1 leading-tight">
            <p class="truncate text-sm font-medium">{{ officerFullName || 'Nurse' }}</p>
            <p class="truncate text-xs text-muted-foreground">Patient Records</p>
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
              {{ officerInitials || 'RN' }}
            </span>
            <div class="min-w-0 flex-1 leading-tight">
              <p class="truncate text-sm font-medium">{{ officerFullName || 'Nurse' }}</p>
              <p class="truncate text-xs text-muted-foreground">Patient Records</p>
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
          <h1 class="truncate text-base font-semibold tracking-tight">Nurse Dashboard</h1>
        </div>

        <div class="relative hidden max-w-xs flex-1 sm:block">
          <Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <input
            v-model="searchQuery"
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
          {{ officerInitials || 'RN' }}
        </span>
      </header>

      <main class="flex-1 space-y-6 p-4 sm:p-6">
        <div v-if="dataError" class="flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2.5 text-sm text-[#d03b3b]">
          <AlertTriangle class="h-4 w-4 shrink-0" />
          {{ dataError }}
        </div>

        <template v-if="activeSection === 'overview'">
          <!-- Patients & discharge summary -->
          <div class="rounded-xl border border-border bg-card p-5">
            <h2 class="text-sm font-medium">Patients &amp; Discharge Summary</h2>
            <p class="text-xs text-muted-foreground">Overview of your caseload</p>

            <div class="mt-6 flex h-40 items-end gap-6 px-2 sm:gap-10">
              <div
                v-for="bar in summaryChartData"
                :key="bar.label"
                class="relative flex h-full flex-1 flex-col items-center justify-end"
                tabindex="0"
                role="img"
                :aria-label="`${bar.label}: ${bar.count}`"
                @mouseenter="hoveredSummary = bar.label"
                @mouseleave="hoveredSummary = null"
                @focus="hoveredSummary = bar.label"
                @blur="hoveredSummary = null"
              >
                <div
                  v-if="hoveredSummary === bar.label"
                  class="absolute -top-8 z-10 whitespace-nowrap rounded-md border border-border bg-popover px-2 py-1 text-xs shadow-sm"
                >
                  <span class="font-semibold tabular-nums text-popover-foreground">{{ bar.count }}</span>
                  <span class="ml-1 text-muted-foreground">{{ bar.label }}</span>
                </div>
                <span class="mb-1 text-xs font-medium tabular-nums text-foreground">{{ bar.count }}</span>
                <div
                  class="w-full max-w-6 rounded-t-[4px] transition-opacity"
                  :class="hoveredSummary === bar.label ? 'opacity-80' : 'opacity-100'"
                  :style="{ height: `${bar.heightPct}%`, minHeight: '2px', backgroundColor: bar.color }"
                />
                <span class="mt-2 text-center text-xs text-muted-foreground">{{ bar.label }}</span>
              </div>
            </div>
          </div>

          <!-- Needs attention -->
          <div v-if="pendingTasks.length > 0" class="flex items-center gap-2 rounded-md bg-[#fab219]/10 px-3 py-2.5 text-sm text-[#c98500]">
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ pendingTasks.length }} nurse clearance task{{ pendingTasks.length === 1 ? '' : 's' }} still awaiting completion.
          </div>

          <div class="grid gap-4 lg:grid-cols-2">
            <!-- Recently Admitted Patients -->
            <div class="rounded-xl border border-border bg-card p-5">
              <h2 class="text-sm font-medium">Recently Admitted Patients</h2>
              <p class="text-xs text-muted-foreground">Your 5 newest patients</p>

              <ul class="mt-4 divide-y divide-border">
                <li v-for="patient in recentPatients" :key="patient.patient_id" class="flex items-center justify-between gap-3 py-2.5 text-sm">
                  <div class="min-w-0">
                    <p class="truncate font-medium">{{ patient.full_name }}</p>
                    <p class="text-xs text-muted-foreground">Room {{ patient.room_number ?? '—' }}</p>
                  </div>
                  <span class="shrink-0 text-xs text-muted-foreground">{{ patient.admission_date }}</span>
                </li>
                <li v-if="recentPatients.length === 0" class="py-6 text-center text-sm text-muted-foreground">No patients yet.</li>
              </ul>
            </div>

            <!-- Recent Discharge Requests -->
            <div class="rounded-xl border border-border bg-card p-5">
              <h2 class="text-sm font-medium">Recent Discharge Requests</h2>
              <p class="text-xs text-muted-foreground">Your 5 latest submissions</p>

              <ul class="mt-4 divide-y divide-border">
                <li v-for="request in recentDischargeRequests" :key="request.request_id" class="flex items-center justify-between gap-3 py-2.5 text-sm">
                  <div class="min-w-0">
                    <p class="truncate font-medium">{{ request.patient_name }}</p>
                    <p class="text-xs text-muted-foreground">{{ new Date(request.timestamp).toLocaleDateString() }}</p>
                  </div>
                  <span
                    class="inline-flex shrink-0 items-center gap-1.5 rounded-full px-2 py-1 text-xs font-medium capitalize"
                    :style="{ backgroundColor: `${statusBarColor[request.status] ?? '#898781'}1a`, color: statusBarColor[request.status] ?? '#898781' }"
                  >
                    <span class="h-1.5 w-1.5 rounded-full" :style="{ backgroundColor: statusBarColor[request.status] ?? '#898781' }" />
                    {{ request.status.replace('_', ' ') }}
                  </span>
                </li>
                <li v-if="recentDischargeRequests.length === 0" class="py-6 text-center text-sm text-muted-foreground">No discharge requests yet.</li>
              </ul>
            </div>
          </div>
        </template>

        <!-- Patients -->
        <div v-if="activeSection === 'patients'" class="rounded-xl border border-border bg-card p-5">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-sm font-medium">Patient Records</h2>
              <p class="text-xs text-muted-foreground">
                {{ searchQuery ? `Showing results for "${searchQuery}"` : 'Patients under your care' }}
              </p>
            </div>
            <button
              type="button"
              class="rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground transition-opacity hover:opacity-90"
              @click="openNewPatientForm"
            >
              Add Patient
            </button>
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
                    <button type="button" class="text-xs font-medium text-primary hover:underline" @click="openEditPatientForm(patient)">
                      Edit
                    </button>
                  </td>
                </tr>
                <tr v-if="!isLoadingData && filteredPatients.length === 0">
                  <td colspan="6" class="py-6 text-center text-sm text-muted-foreground">
                    {{ searchQuery ? 'No patients match your search.' : 'No patients yet.' }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Discharge Requests -->
        <div v-if="activeSection === 'discharge-requests'" class="rounded-xl border border-border bg-card p-5">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-sm font-medium">Discharge Requests</h2>
              <p class="text-xs text-muted-foreground">Requests you've submitted</p>
            </div>
            <button
              type="button"
              :disabled="dischargeablePatients.length === 0"
              class="rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
              @click="openNewRequestForm"
            >
              Request Discharge
            </button>
          </div>

          <div class="mt-4 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-border text-left text-xs text-muted-foreground">
                  <th class="pb-2 pr-4 font-medium">Patient</th>
                  <th class="pb-2 pr-4 font-medium">Billing Verified</th>
                  <th class="pb-2 pr-4 font-medium">Submitted</th>
                  <th class="pb-2 font-medium">Status</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-border">
                <tr v-for="request in dischargeRequests" :key="request.request_id">
                  <td class="py-2 pr-4 font-medium">{{ request.patient_name }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ request.billing_verified ? 'Yes' : 'No' }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ new Date(request.timestamp).toLocaleString() }}</td>
                  <td class="py-2">
                    <span
                      class="inline-flex items-center gap-1.5 rounded-full px-2 py-1 text-xs font-medium capitalize"
                      :style="{ backgroundColor: `${statusBarColor[request.status] ?? '#898781'}1a`, color: statusBarColor[request.status] ?? '#898781' }"
                    >
                      <span class="h-1.5 w-1.5 rounded-full" :style="{ backgroundColor: statusBarColor[request.status] ?? '#898781' }" />
                      {{ request.status.replace('_', ' ') }}
                    </span>
                  </td>
                </tr>
                <tr v-if="!isLoadingData && dischargeRequests.length === 0">
                  <td colspan="4" class="py-6 text-center text-sm text-muted-foreground">No discharge requests yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Tasks -->
        <div v-if="activeSection === 'tasks'" class="rounded-xl border border-border bg-card p-5">
          <h2 class="text-sm font-medium">Nurse Clearance Tasks</h2>
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
                  <td colspan="4" class="py-6 text-center text-sm text-muted-foreground">No tasks assigned yet.</td>
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
          You'll need to sign in again to access the patient records dashboard.
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

    <!-- Add / edit patient modal -->
    <div v-if="showPatientForm" class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/40" @click="!isSavingPatient && (showPatientForm = false)" />
      <div class="relative flex max-h-[90vh] w-full max-w-md flex-col rounded-xl border border-border bg-card p-6 shadow-lg">
        <h2 class="shrink-0 text-base font-semibold tracking-tight">
          <template v-if="patientFormStep === 'form'">{{ editingPatientId === null ? 'Add Patient' : 'Edit Patient' }}</template>
          <template v-else>{{ editingPatientId === null ? 'Confirm New Patient' : 'Confirm Patient Changes' }}</template>
        </h2>
        <p v-if="patientFormStep === 'preview'" class="mt-1 shrink-0 text-xs text-muted-foreground">Please check the details below before saving.</p>
        <p v-else-if="editingPatientId !== null" class="mt-1 shrink-0 text-xs text-muted-foreground">
          Only contact info and room number can be changed after registration.
        </p>

        <form class="mt-4 flex min-h-0 flex-1 flex-col" @submit.prevent="handlePatientFormSubmit">
        <div v-if="patientFormStep === 'form'" class="min-h-0 flex-1 space-y-4 overflow-y-auto pr-1">
          <div class="space-y-1.5">
            <label for="patient-name" class="text-sm font-medium">Full name</label>
            <input
              id="patient-name"
              v-model="patientForm.full_name"
              type="text"
              required
              :disabled="editingPatientId !== null"
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60"
            >
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div class="space-y-1.5">
              <label for="patient-age" class="text-sm font-medium">Age</label>
              <input
                id="patient-age"
                v-model="patientForm.age"
                type="number"
                min="0"
                :disabled="editingPatientId !== null"
                class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60"
              >
            </div>
            <div class="space-y-1.5">
              <label for="patient-dob" class="text-sm font-medium">Date of birth</label>
              <input
                id="patient-dob"
                v-model="patientForm.date_of_birth"
                type="date"
                :disabled="editingPatientId !== null"
                class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60"
              >
            </div>
          </div>
          <div class="space-y-1.5">
            <label for="patient-contact" class="text-sm font-medium">Contact number</label>
            <input
              id="patient-contact"
              v-model="patientForm.contact_number"
              type="text"
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
          </div>
          <div class="space-y-1.5">
            <label for="patient-emergency" class="text-sm font-medium">Emergency contact</label>
            <input
              id="patient-emergency"
              v-model="patientForm.emergency_contact"
              type="text"
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
          </div>
          <div class="space-y-1.5">
            <label for="patient-room" class="text-sm font-medium">Room number</label>
            <input
              id="patient-room"
              v-model="patientForm.room_number"
              type="number"
              min="0"
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
          </div>
          <div class="space-y-1.5">
            <label for="patient-philhealth" class="text-sm font-medium">PhilHealth No.</label>
            <input
              id="patient-philhealth"
              v-model="patientForm.philhealth_no"
              type="text"
              :disabled="editingPatientId !== null"
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-60"
            >
          </div>
        </div>

        <dl v-else class="min-h-0 flex-1 space-y-3 overflow-y-auto pr-1">
          <div v-for="field in patientPreviewFields" :key="field.label" class="flex justify-between gap-4 border-b border-border pb-2 text-sm">
            <dt class="text-muted-foreground">{{ field.label }}</dt>
            <dd class="text-right font-medium">{{ field.value }}</dd>
          </div>
        </dl>

          <div v-if="patientFormError" class="mt-4 flex shrink-0 items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2 text-xs text-[#d03b3b]">
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ patientFormError }}
          </div>

          <div class="mt-4 flex shrink-0 gap-3">
            <button
              type="button"
              :disabled="isSavingPatient"
              class="flex-1 rounded-md border border-border py-2 text-sm font-medium transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-60"
              @click="patientFormStep === 'form' ? (showPatientForm = false) : (patientFormStep = 'form')"
            >
              {{ patientFormStep === 'form' ? 'Cancel' : 'Back' }}
            </button>
            <button
              type="submit"
              :disabled="isSavingPatient"
              class="flex flex-1 items-center justify-center gap-2 rounded-md bg-primary py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              <LoaderCircle v-if="isSavingPatient" class="h-4 w-4 animate-spin" />
              <template v-if="patientFormStep === 'form'">Next</template>
              <template v-else>{{ isSavingPatient ? 'Saving…' : 'Confirm & Save' }}</template>
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- New discharge request modal -->
    <div v-if="showRequestForm" class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/40" @click="!isSavingRequest && (showRequestForm = false)" />
      <div class="relative w-full max-w-sm rounded-xl border border-border bg-card p-6 shadow-lg">
        <h2 class="text-base font-semibold tracking-tight">New Discharge Request</h2>
        <p class="mt-1 text-xs text-muted-foreground">
          Filing this auto-assigns nurse, doctor, billing, and PhilHealth tasks to on-duty staff.
        </p>

        <form class="mt-4 space-y-4" @submit.prevent="confirmNewRequest">
          <div class="space-y-1.5">
            <label for="request-patient-search" class="text-sm font-medium">Patient</label>
            <div class="relative">
              <Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <input
                id="request-patient-search"
                v-model="requestPatientSearch"
                type="search"
                placeholder="Search patients…"
                class="w-full rounded-md border border-input bg-background py-2 pl-9 pr-3 text-sm outline-none placeholder:text-muted-foreground focus-visible:ring-2 focus-visible:ring-ring"
              >
            </div>
            <div class="max-h-48 space-y-1 overflow-y-auto rounded-md border border-border p-1.5">
              <button
                v-for="patient in filteredRequestPatients"
                :key="patient.patient_id"
                type="button"
                class="w-full rounded-md px-2.5 py-1.5 text-left text-sm transition-colors"
                :class="requestPatientId === patient.patient_id
                  ? 'bg-primary/10 text-primary'
                  : 'hover:bg-muted'"
                @click="requestPatientId = patient.patient_id"
              >
                {{ patient.full_name }}
              </button>
              <p v-if="filteredRequestPatients.length === 0" class="px-2.5 py-1.5 text-sm text-muted-foreground">
                No matching patients.
              </p>
            </div>
          </div>

          <div v-if="requestFormError" class="flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2 text-xs text-[#d03b3b]">
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ requestFormError }}
          </div>

          <div class="flex gap-3 pt-2">
            <button
              type="button"
              :disabled="isSavingRequest"
              class="flex-1 rounded-md border border-border py-2 text-sm font-medium transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-60"
              @click="showRequestForm = false"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="isSavingRequest || requestPatientId === null"
              class="flex flex-1 items-center justify-center gap-2 rounded-md bg-primary py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              <LoaderCircle v-if="isSavingRequest" class="h-4 w-4 animate-spin" />
              {{ isSavingRequest ? 'Submitting…' : 'Submit Request' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Confirm discharge request modal -->
    <div v-if="showConfirmRequest" class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/40" @click="!isSavingRequest && (showConfirmRequest = false)" />
      <div class="relative w-full max-w-sm rounded-xl border border-border bg-card p-6 shadow-lg">
        <span class="flex h-10 w-10 items-center justify-center rounded-full bg-primary/10">
          <Stethoscope class="h-5 w-5 text-primary" />
        </span>
        <h2 class="mt-4 text-base font-semibold tracking-tight">Submit discharge request?</h2>
        <p class="mt-1.5 text-sm text-muted-foreground">
          This will request discharge for <span class="font-medium text-foreground">{{ selectedRequestPatientName }}</span>.
        </p>

        <div v-if="requestFormError" class="mt-4 flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2 text-xs text-[#d03b3b]">
          <AlertTriangle class="h-4 w-4 shrink-0" />
          {{ requestFormError }}
        </div>

        <div class="mt-6 flex gap-3">
          <button
            type="button"
            :disabled="isSavingRequest"
            class="flex-1 rounded-md border border-border py-2 text-sm font-medium transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-60"
            @click="showConfirmRequest = false"
          >
            No
          </button>
          <button
            type="button"
            :disabled="isSavingRequest"
            class="flex flex-1 items-center justify-center gap-2 rounded-md bg-primary py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            @click="submitNewRequest"
          >
            <LoaderCircle v-if="isSavingRequest" class="h-4 w-4 animate-spin" />
            {{ isSavingRequest ? 'Submitting…' : 'Yes, submit' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
