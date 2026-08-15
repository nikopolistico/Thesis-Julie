import tailwindcss from "@tailwindcss/vite";

export default defineNuxtConfig({
  modules: ["@nuxt/content", "@nuxtjs/supabase"],
  css: ["~/assets/css/tailwind.css"],
  vite: {
    plugins: [tailwindcss()],
  },
  devtools: { enabled: true },
  compatibilityDate: "2024-04-03",
  supabase: {
    // We don't use Supabase Auth at all (sign-in/up go through our own
    // `administrator` table + RPCs, see supabase/schema.sql) — this
    // module is only used as a typed Postgres client for `.rpc()` calls.
    // Route protection is handled entirely by our own `auth` middleware
    // (see app/middleware/auth.ts), so the module's own redirect logic
    // is fully disabled, and `login`/`callback` are left at unused
    // dummy paths so the module doesn't intercept any real route of ours
    // (it previously pointed `callback` at /dashboardpage, which made
    // the module hijack that route and render it client-only/blank).
    redirectOptions: {
      login: "/_unused-supabase-login",
      callback: "/_unused-supabase-callback",
      exclude: ["/*"],
    },
  },
});
