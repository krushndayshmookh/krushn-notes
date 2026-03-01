import { boot } from 'quasar/wrappers'
import { useAuthStore } from '../stores/auth'
import { api } from './axios'

export default boot(({ app }) => {
  const auth = useAuthStore()

  // Attach token to every request
  api.interceptors.request.use((config) => {
    if (auth.token) {
      config.headers.Authorization = `Bearer ${auth.token}`
    }
    return config
  })

  // Handle 401 — clear auth and redirect
  api.interceptors.response.use(
    (res) => res,
    (err) => {
      if (err.response?.status === 401) {
        auth.logout()
      }
      return Promise.reject(err)
    }
  )
})
