<template>
  <div class="row items-center justify-center" style="height: 100vh;">
    <q-spinner size="40px" color="primary" />
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const route  = useRoute()
const auth   = useAuthStore()

onMounted(() => {
  const token = route.query.token
  if (token) {
    auth.setToken(token)
    router.replace('/notes')
  } else {
    router.replace('/login?error=callback')
  }
})
</script>
