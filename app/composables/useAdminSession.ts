export interface AdminSession {
  id: string
  email: string
  fullName: string
  role: 'nurse' | 'doctor' | 'billing' | 'admin'
}

export function useAdminSession() {
  return useCookie<AdminSession | null>('admin_session', {
    default: () => null,
    sameSite: 'lax',
    maxAge: 60 * 60 * 8,
  })
}

export function dashboardPathForRole(role: AdminSession['role']) {
  switch (role) {
    case 'doctor':
      return '/doctordashboardpage'
    case 'billing':
      return '/billingdashboardpage'
    case 'admin':
      return '/admindashboardpage'
    default:
      return '/nursedashboardpage'
  }
}
