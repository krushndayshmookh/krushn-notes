import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('token') || null)

  const isLoggedIn = computed(() => !!token.value)

  function setToken(t) {
    token.value = t
    localStorage.setItem('token', t)
  }

  function logout() {
    token.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('lastSync')
    window.location.href = '/login'
  }

  return { token, isLoggedIn, setToken, logout }
})
