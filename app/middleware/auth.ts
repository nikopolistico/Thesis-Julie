import type { AdminSession } from '~/composables/useAdminSession'

export default defineNuxtRouteMiddleware((to) => {
  const session = useAdminSession()

  if (!session.value) {
    return navigateTo('/loginpage')
  }

  const requiredRole = to.meta.requiredRole as AdminSession['role'] | undefined
  if (requiredRole && session.value.role !== requiredRole) {
    return navigateTo(dashboardPathForRole(session.value.role))
  }
})
