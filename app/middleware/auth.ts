export default defineNuxtRouteMiddleware(() => {
  const session = useAdminSession()

  if (!session.value) {
    return navigateTo('/loginpage')
  }
})
