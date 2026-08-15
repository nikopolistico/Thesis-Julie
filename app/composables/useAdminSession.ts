export interface AdminSession {
  id: string
  email: string
}

export function useAdminSession() {
  return useCookie<AdminSession | null>('admin_session', {
    default: () => null,
    sameSite: 'lax',
    maxAge: 60 * 60 * 8,
  })
}
