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
  ReceiptText,
  Search,
  Sun,
  X,
} from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import type { BillingRow } from '~/types/database.types'

definePageMeta({
  middleware: 'auth',
  requiredRole: 'billing',
})

useHead({
  title: 'Billing Dashboard — AHDMS',
  meta: [
    {
      name: 'description',
      content: 'Billing & PhilHealth clearance dashboard for the Automated Hospital Discharge Management System at Butuan Medical Center.',
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
  { label: 'My Tasks', icon: ClipboardCheck, section: 'tasks' },
  { label: 'Pending Billing', icon: ReceiptText, section: 'billing' },
] as const

type Section = typeof navItems[number]['section']

const activeSection = ref<Section>('overview')

interface BillingTask {
  task_id: number
  discharge_request_id: number
  patient_id: number
  patient_name: string
  task_type: string
  status: string
  created_at: string
}

interface DischargeRequest {
  request_id: number
  patient_id: number
  patient_name: string
  requested_by_name: string
  status: string
  billing_verified: boolean
  timestamp: string
}

const tasks = ref<BillingTask[]>([])
const dischargeRequests = ref<DischargeRequest[]>([])
const isLoadingData = ref(false)
const dataError = ref('')
const searchQuery = ref('')

async function loadDashboardData() {
  isLoadingData.value = true
  const errors: string[] = []

  const [tasksRes, requestsRes] = await Promise.all([
    supabase.rpc('list_tasks_for_officer_detailed', { p_officer_id: officerId.value }),
    supabase.rpc('list_discharge_requests_detailed', { p_status: null }),
  ])

  if (tasksRes.error) errors.push(`Tasks: ${tasksRes.error.message}`)
  else tasks.value = tasksRes.data ?? []

  if (requestsRes.error) errors.push(`Discharge requests: ${requestsRes.error.message}`)
  else dischargeRequests.value = requestsRes.data ?? []

  dataError.value = errors.join(' ')
  isLoadingData.value = false
}

onMounted(loadDashboardData)

const billingTasks = computed(() => tasks.value.filter((t) => t.task_type === 'billing_clearance'))
const philhealthTasks = computed(() => tasks.value.filter((t) => t.task_type === 'philhealth_documentation'))
const pendingTasks = computed(() => tasks.value.filter((t) => t.status !== 'done'))

const unverifiedRequests = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  return dischargeRequests.value
    .filter((r) => !r.billing_verified && (r.status === 'pending' || r.status === 'in_progress'))
    .filter((r) => !q || r.patient_name.toLowerCase().includes(q))
})

// ── Complete billing / PhilHealth tasks ─────────────────────────────────

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

// ── Clear billing (create + verify) ─────────────────────────────────────

const clearingRequest = ref<DischargeRequest | null>(null)
const billingForm = ref({ total_amount: '', philhealth_deduction: '' })
const isSavingBilling = ref(false)
const billingFormError = ref('')

function openClearBillingForm(request: DischargeRequest) {
  clearingRequest.value = request
  billingForm.value = { total_amount: '', philhealth_deduction: '' }
  billingFormError.value = ''
}

async function submitClearBilling() {
  if (!clearingRequest.value) return

  const totalAmount = Number(billingForm.value.total_amount)
  const philhealthDeduction = Number(billingForm.value.philhealth_deduction || 0)

  if (!Number.isFinite(totalAmount) || totalAmount < 0) {
    billingFormError.value = 'Enter a valid total amount.'
    return
  }
  if (!Number.isFinite(philhealthDeduction) || philhealthDeduction < 0) {
    billingFormError.value = 'Enter a valid PhilHealth deduction.'
    return
  }

  isSavingBilling.value = true
  billingFormError.value = ''

  const { data: billing, error: createError } = await supabase
    .rpc('create_billing_record', {
      p_discharge_request_id: clearingRequest.value.request_id,
      p_patient_id: clearingRequest.value.patient_id,
      p_total_amount: totalAmount,
      p_philhealth_deduction: philhealthDeduction,
    })
    .overrideTypes<BillingRow>()

  if (createError || !billing) {
    billingFormError.value = createError?.message ?? 'Could not create billing record.'
    isSavingBilling.value = false
    return
  }

  const { error: verifyError } = await supabase.rpc('verify_billing', { p_billing_id: billing.billing_id })

  if (verifyError) {
    billingFormError.value = verifyError.message
    isSavingBilling.value = false
    return
  }

  clearingRequest.value = null
  isSavingBilling.value = false
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
            {{ officerInitials || 'BL' }}
          </span>
          <div class="min-w-0 flex-1 leading-tight">
            <p class="truncate text-sm font-medium">{{ officerFullName || 'Billing' }}</p>
            <p class="truncate text-xs text-muted-foreground">Billing & PhilHealth</p>
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
              {{ officerInitials || 'BL' }}
            </span>
            <div class="min-w-0 flex-1 leading-tight">
              <p class="truncate text-sm font-medium">{{ officerFullName || 'Billing' }}</p>
              <p class="truncate text-xs text-muted-foreground">Billing & PhilHealth</p>
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
          <h1 class="truncate text-base font-semibold tracking-tight">Billing Dashboard</h1>
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
          {{ officerInitials || 'BL' }}
        </span>
      </header>

      <main class="flex-1 space-y-6 p-4 sm:p-6">
        <div v-if="dataError" class="flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2.5 text-sm text-[#d03b3b]">
          <AlertTriangle class="h-4 w-4 shrink-0" />
          {{ dataError }}
        </div>

        <template v-if="activeSection === 'overview'">
          <div class="grid gap-4 sm:grid-cols-3">
            <div class="rounded-xl border border-border bg-card p-5">
              <span class="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10">
                <ClipboardCheck class="h-4.5 w-4.5 text-primary" />
              </span>
              <p class="mt-4 text-2xl font-semibold tracking-tight tabular-nums">{{ pendingTasks.length }}</p>
              <p class="mt-1 text-sm text-muted-foreground">Open Tasks</p>
            </div>
            <div class="rounded-xl border border-border bg-card p-5">
              <span class="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10">
                <ReceiptText class="h-4.5 w-4.5 text-primary" />
              </span>
              <p class="mt-4 text-2xl font-semibold tracking-tight tabular-nums">{{ unverifiedRequests.length }}</p>
              <p class="mt-1 text-sm text-muted-foreground">Awaiting Billing Clearance</p>
            </div>
            <div class="rounded-xl border border-border bg-card p-5">
              <span class="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10">
                <CheckCircle2 class="h-4.5 w-4.5 text-primary" />
              </span>
              <p class="mt-4 text-2xl font-semibold tracking-tight tabular-nums">{{ tasks.filter((t) => t.status === 'done').length }}</p>
              <p class="mt-1 text-sm text-muted-foreground">Tasks Completed</p>
            </div>
          </div>

          <div v-if="pendingTasks.length > 0" class="flex items-center gap-2 rounded-md bg-[#fab219]/10 px-3 py-2.5 text-sm text-[#c98500]">
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ pendingTasks.length }} billing/PhilHealth task{{ pendingTasks.length === 1 ? '' : 's' }} still awaiting completion.
          </div>

          <div class="grid gap-4 lg:grid-cols-2">
            <div class="rounded-xl border border-border bg-card p-5">
              <h2 class="text-sm font-medium">Billing Clearance</h2>
              <p class="text-xs text-muted-foreground">{{ billingTasks.length }} task{{ billingTasks.length === 1 ? '' : 's' }} assigned</p>
              <ul class="mt-4 divide-y divide-border">
                <li v-for="task in billingTasks.slice(0, 5)" :key="task.task_id" class="flex items-center justify-between gap-3 py-2.5 text-sm">
                  <p class="truncate font-medium">{{ task.patient_name }}</p>
                  <span
                    class="shrink-0 rounded-full px-2 py-1 text-xs font-medium"
                    :class="task.status === 'done' ? 'bg-[#0ca30c]/10 text-[#0ca30c]' : 'bg-muted text-muted-foreground'"
                  >
                    {{ task.status === 'done' ? 'Done' : 'Pending' }}
                  </span>
                </li>
                <li v-if="billingTasks.length === 0" class="py-6 text-center text-sm text-muted-foreground">No billing tasks yet.</li>
              </ul>
            </div>
            <div class="rounded-xl border border-border bg-card p-5">
              <h2 class="text-sm font-medium">PhilHealth Documentation</h2>
              <p class="text-xs text-muted-foreground">{{ philhealthTasks.length }} task{{ philhealthTasks.length === 1 ? '' : 's' }} assigned</p>
              <ul class="mt-4 divide-y divide-border">
                <li v-for="task in philhealthTasks.slice(0, 5)" :key="task.task_id" class="flex items-center justify-between gap-3 py-2.5 text-sm">
                  <p class="truncate font-medium">{{ task.patient_name }}</p>
                  <span
                    class="shrink-0 rounded-full px-2 py-1 text-xs font-medium"
                    :class="task.status === 'done' ? 'bg-[#0ca30c]/10 text-[#0ca30c]' : 'bg-muted text-muted-foreground'"
                  >
                    {{ task.status === 'done' ? 'Done' : 'Pending' }}
                  </span>
                </li>
                <li v-if="philhealthTasks.length === 0" class="py-6 text-center text-sm text-muted-foreground">No PhilHealth tasks yet.</li>
              </ul>
            </div>
          </div>
        </template>

        <!-- My Tasks -->
        <div v-if="activeSection === 'tasks'" class="rounded-xl border border-border bg-card p-5">
          <h2 class="text-sm font-medium">Billing & PhilHealth Tasks</h2>
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
                  <th class="pb-2 pr-4 font-medium">Task</th>
                  <th class="pb-2 pr-4 font-medium">Assigned</th>
                  <th class="pb-2 pr-4 font-medium">Status</th>
                  <th class="pb-2 font-medium" />
                </tr>
              </thead>
              <tbody class="divide-y divide-border">
                <tr v-for="task in tasks" :key="task.task_id">
                  <td class="py-2 pr-4 font-medium">{{ task.patient_name }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">
                    {{ task.task_type === 'billing_clearance' ? 'Billing Clearance' : 'PhilHealth Documentation' }}
                  </td>
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
                  <td colspan="5" class="py-6 text-center text-sm text-muted-foreground">No tasks assigned yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Pending Billing -->
        <div v-if="activeSection === 'billing'" class="rounded-xl border border-border bg-card p-5">
          <h2 class="text-sm font-medium">Discharge Requests Awaiting Billing Clearance</h2>
          <p class="text-xs text-muted-foreground">
            {{ searchQuery ? `Showing results for "${searchQuery}"` : 'Compute the bill and clear it so the doctor can finalize the discharge.' }}
          </p>

          <div class="mt-4 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-border text-left text-xs text-muted-foreground">
                  <th class="pb-2 pr-4 font-medium">Patient</th>
                  <th class="pb-2 pr-4 font-medium">Requested By</th>
                  <th class="pb-2 pr-4 font-medium">Submitted</th>
                  <th class="pb-2 font-medium" />
                </tr>
              </thead>
              <tbody class="divide-y divide-border">
                <tr v-for="request in unverifiedRequests" :key="request.request_id">
                  <td class="py-2 pr-4 font-medium">{{ request.patient_name }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ request.requested_by_name }}</td>
                  <td class="py-2 pr-4 text-muted-foreground">{{ new Date(request.timestamp).toLocaleString() }}</td>
                  <td class="py-2 text-right">
                    <button type="button" class="text-xs font-medium text-primary hover:underline" @click="openClearBillingForm(request)">
                      Clear Billing
                    </button>
                  </td>
                </tr>
                <tr v-if="!isLoadingData && unverifiedRequests.length === 0">
                  <td colspan="4" class="py-6 text-center text-sm text-muted-foreground">Nothing awaiting billing clearance.</td>
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
          You'll need to sign in again to access the billing dashboard.
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

    <!-- Clear billing modal -->
    <div v-if="clearingRequest" class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/40" @click="!isSavingBilling && (clearingRequest = null)" />
      <div class="relative w-full max-w-sm rounded-xl border border-border bg-card p-6 shadow-lg">
        <h2 class="text-base font-semibold tracking-tight">Clear Billing</h2>
        <p class="mt-1 text-xs text-muted-foreground">
          For <span class="font-medium text-foreground">{{ clearingRequest.patient_name }}</span>. This records the bill and marks it verified.
        </p>

        <form class="mt-4 space-y-4" @submit.prevent="submitClearBilling">
          <div class="space-y-1.5">
            <label for="billing-total" class="text-sm font-medium">Total amount (₱)</label>
            <input
              id="billing-total"
              v-model="billingForm.total_amount"
              type="number"
              min="0"
              step="0.01"
              required
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
          </div>
          <div class="space-y-1.5">
            <label for="billing-philhealth" class="text-sm font-medium">PhilHealth deduction (₱)</label>
            <input
              id="billing-philhealth"
              v-model="billingForm.philhealth_deduction"
              type="number"
              min="0"
              step="0.01"
              class="w-full rounded-md border border-input bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
          </div>

          <div v-if="billingFormError" class="flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2 text-xs text-[#d03b3b]">
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ billingFormError }}
          </div>

          <div class="flex gap-3 pt-2">
            <button
              type="button"
              :disabled="isSavingBilling"
              class="flex-1 rounded-md border border-border py-2 text-sm font-medium transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-60"
              @click="clearingRequest = null"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="isSavingBilling"
              class="flex flex-1 items-center justify-center gap-2 rounded-md bg-primary py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              <LoaderCircle v-if="isSavingBilling" class="h-4 w-4 animate-spin" />
              {{ isSavingBilling ? 'Saving…' : 'Clear Billing' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>
