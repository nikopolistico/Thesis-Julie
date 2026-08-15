<script setup lang="ts">
import {
  Activity,
  ClipboardList,
  FileWarning,
  Users,
  FileX,
  ListChecks,
  Gauge,
  ShieldCheck,
  GraduationCap,
  Container,
  Server,
  Database,
  Lock,
  Terminal,
  ArrowRight,
  CheckCircle2,
  Clock,
  AlertTriangle,
  Menu,
  X,
} from '@lucide/vue'
import { ref } from 'vue'

useHead({
  title: 'AHDMS — Automated Hospital Discharge Management System',
  meta: [
    {
      name: 'description',
      content:
        'AHDMS is a web-based discharge management system proposed for Butuan Medical Center, designed to eliminate paper-based bottlenecks and speed up patient discharge.',
    },
  ],
})

const mobileNavOpen = ref(false)

const navLinks = [
  { label: 'Problem', href: '#problem' },
  { label: 'Solution', href: '#solution' },
  { label: 'Features', href: '#features' },
  { label: 'Technology', href: '#technology' },
]

const problemStats = [
  {
    icon: Users,
    value: '5–11',
    label: 'Patients in the discharge queue at a given time',
  },
  {
    icon: Activity,
    value: '3–5',
    label: 'Nurses on duty to handle that same queue',
  },
]

const paperCartIssues = [
  {
    icon: FileWarning,
    title: 'Documentation errors',
    text: 'Manual retrieval and re-entry of charts introduces mistakes that ripple downstream.',
  },
  {
    icon: FileX,
    title: 'Lost or misplaced documents',
    text: 'Physical nurse carts mean paperwork can be misfiled, delayed, or go missing entirely.',
  },
  {
    icon: Users,
    title: 'Back-and-forth communication',
    text: 'Departments coordinate by phone calls and physical routing instead of shared status updates.',
  },
  {
    icon: Clock,
    title: 'Slower clearances',
    text: 'Billing clearance, medication review, and physician sign-off all wait longer than they should.',
  },
]

const features = [
  {
    icon: ClipboardList,
    title: 'Automated Document Processing',
    text: 'Digitizes medical charts, physician notes, and patient records so staff retrieve and verify information in seconds, not trips across the ward.',
  },
  {
    icon: ListChecks,
    title: 'Automated Task Delegation',
    text: 'Assigns discharge tasks — medical clearance, billing verification, and more — based on real-time staff availability.',
  },
  {
    icon: Gauge,
    title: 'Real-Time Discharge Progress Monitoring',
    text: 'A live dashboard tracks every patient’s discharge status — pending, in progress, or completed — across all departments.',
  },
]

const techStack = [
  {
    icon: Terminal,
    category: 'Frontend',
    items: ['Nuxt.js', 'shadcn-vue', 'Tailwind CSS'],
  },
  {
    icon: Server,
    category: 'Backend',
    items: ['Node.js + Express.js', 'TypeScript'],
  },
  {
    icon: Database,
    category: 'Database',
    items: ['PostgreSQL'],
  },
  {
    icon: Lock,
    category: 'Security',
    items: ['JWT Authentication', 'HTTPS', 'Audit Logging'],
  },
  {
    icon: Container,
    category: 'Dev Tools',
    items: ['Git / GitHub', 'Postman'],
  },
]
</script>

<template>
  <div class="min-h-screen bg-background text-foreground">
    <!-- Nav -->
    <header class="sticky top-0 z-50 border-b border-border/60 bg-background/80 backdrop-blur supports-backdrop-filter:bg-background/60">
      <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <a href="#" class="flex items-center gap-2 font-semibold tracking-tight">
          <span class="flex h-8 w-8 items-center justify-center rounded-md bg-primary text-primary-foreground">
            <Activity class="h-4.5 w-4.5" />
          </span>
          <span>AHDMS</span>
        </a>

        <nav class="hidden items-center gap-8 text-sm text-muted-foreground md:flex">
          <a
            v-for="link in navLinks"
            :key="link.href"
            :href="link.href"
            class="transition-colors hover:text-foreground"
          >{{ link.label }}</a>
        </nav>

        <div class="hidden md:block">
          <a
            href="/loginpage"
            class="inline-flex items-center gap-1.5 rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90"
          >
            See the System
            <ArrowRight class="h-4 w-4" />
          </a>
        </div>

        <button
          class="text-foreground md:hidden"
          aria-label="Toggle navigation menu"
          @click="mobileNavOpen = !mobileNavOpen"
        >
          <Menu v-if="!mobileNavOpen" class="h-6 w-6" />
          <X v-else class="h-6 w-6" />
        </button>
      </div>

      <div v-if="mobileNavOpen" class="border-t border-border/60 px-6 py-4 md:hidden">
        <nav class="flex flex-col gap-4 text-sm text-muted-foreground">
          <a
            v-for="link in navLinks"
            :key="link.href"
            :href="link.href"
            class="hover:text-foreground"
            @click="mobileNavOpen = false"
          >{{ link.label }}</a>
        </nav>
      </div>
    </header>

    <main>
      <!-- Hero -->
      <section class="relative overflow-hidden border-b border-border/60">
        <div
          class="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(circle_at_top,var(--color-primary),transparent_60%)]/8"
        />
        <div class="mx-auto max-w-6xl px-6 py-20 text-center sm:py-28">
          <h1 class="mx-auto max-w-3xl text-4xl font-semibold tracking-tight text-balance sm:text-5xl lg:text-6xl">
            Discharging patients shouldn't take longer than treating them.
          </h1>
          <p class="mx-auto mt-6 max-w-2xl text-balance text-lg text-muted-foreground">
            AHDMS is a web-based Automated Hospital Discharge Management System that replaces
            paper nurse carts with real-time coordination — built to shorten discharge delays
            at Butuan Medical Center.
          </p>
          <div class="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <a
              href="#problem"
              class="inline-flex w-full items-center justify-center gap-1.5 rounded-md bg-primary px-6 py-3 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 sm:w-auto"
            >
              Explore the Problem
              <ArrowRight class="h-4 w-4" />
            </a>
            <a
              href="#features"
              class="inline-flex w-full items-center justify-center gap-1.5 rounded-md border border-border px-6 py-3 text-sm font-medium transition-colors hover:bg-muted sm:w-auto"
            >
              View Features
            </a>
          </div>
        </div>
      </section>

      <!-- Problem -->
      <section id="problem" class="border-b border-border/60 bg-muted/30">
        <div class="mx-auto max-w-6xl px-6 py-20">
          <div class="mx-auto max-w-2xl text-center">
            <span class="text-sm font-medium text-primary">Statement of the Problem</span>
            <h2 class="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">
              Where the discharge process breaks down
            </h2>
            <p class="mt-4 text-muted-foreground">
              Observations at BMC point to two compounding issues: a staffing imbalance during
              peak discharge hours, and a paper-based workflow that can't keep up.
            </p>
          </div>

          <!-- Staffing imbalance -->
          <div class="mt-14 grid gap-6 sm:grid-cols-2">
            <div
              v-for="stat in problemStats"
              :key="stat.label"
              class="rounded-xl border border-border bg-card p-8 text-card-foreground"
            >
              <component :is="stat.icon" class="h-6 w-6 text-primary" />
              <div class="mt-4 text-4xl font-semibold tracking-tight">{{ stat.value }}</div>
              <p class="mt-2 text-sm text-muted-foreground">{{ stat.label }}</p>
            </div>
          </div>
          <div class="mt-4 flex items-start gap-2 rounded-xl border border-border bg-card px-6 py-4 text-sm text-muted-foreground">
            <AlertTriangle class="mt-0.5 h-4 w-4 shrink-0 text-primary" />
            <span>An unbalanced nurse-to-patient ratio during discharge hours means every
              patient in the queue waits longer than necessary.</span>
          </div>

          <!-- Paper cart issues -->
          <div class="mt-16">
            <h3 class="text-center text-lg font-medium">
              Manual, paper-based nurse carts compound the delay
            </h3>
            <div class="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
              <div
                v-for="issue in paperCartIssues"
                :key="issue.title"
                class="rounded-xl border border-border bg-card p-6 text-card-foreground"
              >
                <component :is="issue.icon" class="h-5 w-5 text-primary" />
                <h4 class="mt-4 font-medium">{{ issue.title }}</h4>
                <p class="mt-2 text-sm text-muted-foreground">{{ issue.text }}</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Solution -->
      <section id="solution" class="border-b border-border/60">
        <div class="mx-auto max-w-6xl px-6 py-20">
          <div class="mx-auto max-w-2xl text-center">
            <span class="text-sm font-medium text-primary">The Proposed Solution</span>
            <h2 class="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">
              Introducing AHDMS
            </h2>
            <p class="mt-4 text-muted-foreground">
              The Automated Hospital Discharge Management System is a web-based platform that
              digitizes records, delegates tasks intelligently, and gives every department
              visibility into where each patient stands — replacing the paper trail with a
              single source of truth.
            </p>
          </div>

          <div class="mt-12 grid gap-4 sm:grid-cols-3">
            <div class="flex items-center gap-3 rounded-lg border border-border bg-card px-5 py-4">
              <CheckCircle2 class="h-5 w-5 shrink-0 text-primary" />
              <span class="text-sm">Fewer documentation errors</span>
            </div>
            <div class="flex items-center gap-3 rounded-lg border border-border bg-card px-5 py-4">
              <CheckCircle2 class="h-5 w-5 shrink-0 text-primary" />
              <span class="text-sm">Faster billing &amp; sign-offs</span>
            </div>
            <div class="flex items-center gap-3 rounded-lg border border-border bg-card px-5 py-4">
              <CheckCircle2 class="h-5 w-5 shrink-0 text-primary" />
              <span class="text-sm">Clear cross-department visibility</span>
            </div>
          </div>
        </div>
      </section>

      <!-- Features -->
      <section id="features" class="border-b border-border/60 bg-muted/30">
        <div class="mx-auto max-w-6xl px-6 py-20">
          <div class="mx-auto max-w-2xl text-center">
            <span class="text-sm font-medium text-primary">Core Features</span>
            <h2 class="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">
              Built around the discharge workflow
            </h2>
          </div>

          <div class="mt-14 grid gap-6 lg:grid-cols-3">
            <div
              v-for="feature in features"
              :key="feature.title"
              class="rounded-xl border border-border bg-card p-8 text-card-foreground"
            >
              <span class="flex h-11 w-11 items-center justify-center rounded-lg bg-primary/10">
                <component :is="feature.icon" class="h-5 w-5 text-primary" />
              </span>
              <h3 class="mt-5 font-medium">{{ feature.title }}</h3>
              <p class="mt-2 text-sm text-muted-foreground">{{ feature.text }}</p>
            </div>
          </div>
        </div>
      </section>

      <!-- Technology -->
      <section id="technology" class="border-b border-border/60">
        <div class="mx-auto max-w-6xl px-6 py-20">
          <div class="mx-auto max-w-2xl text-center">
            <h2 class="text-3xl font-semibold tracking-tight sm:text-4xl">
              Technology stack
            </h2>
            <p class="mt-4 text-muted-foreground">
              A modern, secure stack chosen to support hospital-grade reliability and
              role-based access.
            </p>
          </div>

          <div class="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <div
              v-for="stack in techStack"
              :key="stack.category"
              class="rounded-xl border border-border bg-card p-6 text-card-foreground"
            >
              <div class="flex items-center gap-2.5">
                <component :is="stack.icon" class="h-4.5 w-4.5 text-primary" />
                <h3 class="font-medium">{{ stack.category }}</h3>
              </div>
              <ul class="mt-4 space-y-2">
                <li
                  v-for="item in stack.items"
                  :key="item"
                  class="text-sm text-muted-foreground"
                >{{ item }}</li>
              </ul>
            </div>
          </div>

          <div class="mt-6 flex flex-wrap items-center justify-center gap-3 rounded-xl border border-border bg-muted/30 px-6 py-5 text-sm text-muted-foreground">
            <ShieldCheck class="h-4 w-4 text-primary" />
            Designed with JWT auth, HTTPS, and audit logging to meet hospital data-handling
            requirements.
          </div>
        </div>
      </section>

      <!-- CTA -->
      <section class="mx-auto max-w-6xl px-6 py-20 text-center">
        <h2 class="text-3xl font-semibold tracking-tight sm:text-4xl">
          A faster discharge process for BMC starts here.
        </h2>
        <p class="mx-auto mt-4 max-w-xl text-muted-foreground">
          This proposal outlines how AHDMS can reduce discharge bottlenecks through automation,
          real-time monitoring, and smarter task delegation.
        </p>
        <div class="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a
            href="#problem"
            class="inline-flex w-full items-center justify-center gap-1.5 rounded-md bg-primary px-6 py-3 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 sm:w-auto"
          >
            Read the Full Proposal
            <ArrowRight class="h-4 w-4" />
          </a>
        </div>
      </section>
    </main>

    <footer class="border-t border-border/60">
      <div class="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 py-8 text-sm text-muted-foreground sm:flex-row">
        <div class="flex items-center gap-2">
          <Activity class="h-4 w-4" />
          <span>AHDMS &mdash; Automated Hospital Discharge Management System</span>
        </div>
        <div class="flex items-center gap-2">
          <GraduationCap class="h-4 w-4" />
          <span>Thesis Proposal, Chapters 1&ndash;3</span>
        </div>
      </div>
    </footer>
  </div>
</template>
