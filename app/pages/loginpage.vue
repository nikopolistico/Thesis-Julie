<script setup lang="ts">
import {
  Activity,
  AlertTriangle,
  ArrowLeft,
  ClipboardList,
  Eye,
  EyeOff,
  Gauge,
  ListChecks,
  Lock,
  LoaderCircle,
  LogIn,
  Mail,
  Sun,
  Moon,
} from '@lucide/vue'
import { onMounted, ref } from 'vue'

const brandHighlights = [
  { icon: ClipboardList, text: 'Digitized charts & records' },
  { icon: ListChecks, text: 'Automated task delegation' },
  { icon: Gauge, text: 'Real-time discharge tracking' },
]

useHead({
  title: 'Sign In — AHDMS',
  meta: [
    {
      name: 'description',
      content: 'Staff sign-in for the Automated Hospital Discharge Management System (AHDMS) at Butuan Medical Center.',
    },
  ],
})

const { isDark, init: initDarkMode, toggle: toggleDarkMode } = useDarkMode()
onMounted(initDarkMode)

const supabase = useSupabaseClient()
const session = useAdminSession()

const email = ref('')
const password = ref('')
const role = ref<'doctor' | 'nurse' | 'admin'>('doctor')
const showPassword = ref(false)
const isSubmitting = ref(false)
const errorMessage = ref('')

async function handleSubmit() {
  errorMessage.value = ''
  isSubmitting.value = true

  const { data, error } = await supabase
    .rpc('login_administrator', { p_email: email.value, p_password: password.value, p_role: role.value })
    .single()

      console.log('Login successful:', data)

  if (error) {
    errorMessage.value = 'Incorrect email or password.'
    isSubmitting.value = false
    return
  }

  if (!data) {
    errorMessage.value = 'Incorrect email or password.'
    isSubmitting.value = false
    return
  }


  session.value = { id: String(data.user_id), email: data.email }
  await navigateTo(
    role.value === 'admin'
      ? '/admindashboardpage'
      : role.value === 'doctor'
        ? '/doctordashboardpage'
        : '/nursedashboardpage',
  )
}
</script>

<template>
  <div class="grid min-h-screen lg:grid-cols-2">
    <!-- Form side -->
    <div class="relative flex flex-col justify-center overflow-hidden px-6 py-12 sm:px-12 lg:px-20">
      <div
        class="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top_left,var(--color-primary),transparent_45%)]/[0.06]"
      />
      <a
        href="/"
        class="absolute left-6 top-6 flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground sm:left-12 lg:left-20"
      >
        <ArrowLeft class="h-4 w-4" />
        Back to Landing Page
      </a>

      <button
        :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        class="absolute right-6 top-6 text-muted-foreground transition-colors hover:text-foreground sm:right-12 lg:right-20"
        @click="toggleDarkMode"
      >
        <Sun v-if="isDark" class="h-5 w-5" />
        <Moon v-else class="h-5 w-5" />
      </button>

      <div class="mx-auto w-full max-w-sm">
        <a href="/" class="flex items-center gap-2.5 font-semibold tracking-tight">
          <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-lg shadow-primary/25">
            <Activity class="h-5 w-5" />
          </span>
          <span class="text-lg">AHDMS</span>
        </a>

        <h1 class="mt-10 text-2xl font-semibold tracking-tight">
          Welcome back
        </h1>
        <p class="mt-2 text-sm text-muted-foreground">
          Sign in to access the discharge management dashboard for Butuan Medical Center.
        </p>

        <form class="mt-8 rounded-2xl border border-border/60 bg-card/50 p-6 shadow-sm sm:p-7" @submit.prevent="handleSubmit">
          <fieldset :disabled="isSubmitting" class="space-y-5">
          <div class="space-y-1.5">
            <label for="email" class="text-sm font-medium">Hospital email</label>
            <div class="relative">
              <Mail class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <input
                id="email"
                v-model="email"
                type="email"
                autocomplete="username"
                placeholder="you@butuanmedicalcenter.gov.ph"
                required
                class="w-full rounded-md border border-input bg-background py-2.5 pl-10 pr-3 text-sm outline-none ring-offset-background transition-colors placeholder:text-muted-foreground focus-visible:ring-2 focus-visible:ring-ring"
              >
            </div>
          </div>

          <div class="space-y-1.5">
            <div class="flex items-center justify-between">
              <label for="password" class="text-sm font-medium">Password</label>
              <a href="#" class="text-xs text-primary hover:underline">Forgot password?</a>
            </div>
            <div class="relative">
              <Lock class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <input
                id="password"
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                autocomplete="current-password"
                placeholder="••••••••"
                required
                class="w-full rounded-md border border-input bg-background py-2.5 pl-10 pr-10 text-sm outline-none ring-offset-background transition-colors placeholder:text-muted-foreground focus-visible:ring-2 focus-visible:ring-ring"
              >
              <button
                type="button"
                class="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground transition-colors hover:text-foreground"
                :aria-label="showPassword ? 'Hide password' : 'Show password'"
                @click="showPassword = !showPassword"
              >
                <EyeOff v-if="showPassword" class="h-4 w-4" />
                <Eye v-else class="h-4 w-4" />
              </button>
            </div>
          </div>

          <div class="space-y-1.5">
            <label for="role" class="text-sm font-medium">Role</label>
            <select
              id="role"
              v-model="role"
              class="w-full rounded-md border border-input bg-background py-2.5 px-3 text-sm outline-none ring-offset-background transition-colors focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="doctor">Doctor</option>
              <option value="nurse">Nurse</option>
              <option value="admin">Admin</option>
            </select>
          </div>
          </fieldset>

          <div
            v-if="errorMessage"
            class="mt-5 flex items-center gap-2 rounded-md bg-[#d03b3b]/10 px-3 py-2.5 text-sm text-[#d03b3b]"
          >
            <AlertTriangle class="h-4 w-4 shrink-0" />
            {{ errorMessage }}
          </div>

          <button
            type="submit"
            :disabled="isSubmitting"
            class="mt-5 flex w-full items-center justify-center gap-2 rounded-md bg-primary py-2.5 text-sm font-medium text-primary-foreground shadow-md shadow-primary/20 transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <LoaderCircle v-if="isSubmitting" class="h-4 w-4 animate-spin" />
            <LogIn v-else class="h-4 w-4" />
            {{ isSubmitting ? 'Signing in…' : 'Sign In' }}
          </button>
        </form>

        <p class="mt-4 text-center text-xs text-muted-foreground">
          Authorized BMC personnel only. Access is logged for audit purposes.
        </p>
      </div>
    </div>

    <!-- Brand side -->
    <div class="relative hidden overflow-hidden bg-primary lg:block">
      <div class="absolute inset-0 bg-[radial-gradient(circle_at_top,var(--color-primary-foreground),transparent_55%)]/10" />
      <div class="absolute -top-24 -right-24 h-80 w-80 rounded-full bg-white/10 blur-3xl" />
      <div class="absolute -bottom-32 -left-16 h-96 w-96 rounded-full bg-black/10 blur-3xl" />

      <div class="relative flex h-full flex-col p-12 text-primary-foreground">
        <div class="flex items-center gap-3">
          <span class="flex h-11 w-11 items-center justify-center rounded-xl bg-white/15 shadow-lg shadow-black/10 ring-1 ring-white/20 backdrop-blur">
            <Activity class="h-5.5 w-5.5" />
          </span>
          <div class="leading-tight">
            <p class="font-semibold tracking-tight">AHDMS</p>
            <p class="text-xs opacity-70">Butuan Medical Center</p>
          </div>
        </div>

        <div class="flex flex-1 flex-col items-center justify-center text-center">
          <h2 class="max-w-md text-3xl font-semibold tracking-tight text-balance">
            One dashboard for every step of the discharge process.
          </h2>
          <p class="mt-4 max-w-sm text-sm opacity-80">
            Track documentation, task delegation, and discharge status in real time —
            no more paper carts.
          </p>

          <ul class="mt-8 space-y-3 text-left">
            <li
              v-for="highlight in brandHighlights"
              :key="highlight.text"
              class="flex items-center gap-3 rounded-lg bg-white/10 px-4 py-2.5 ring-1 ring-white/10 backdrop-blur"
            >
              <component :is="highlight.icon" class="h-4 w-4 shrink-0 opacity-90" />
              <span class="text-sm opacity-90">{{ highlight.text }}</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>
