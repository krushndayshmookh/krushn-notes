<template>
  <div class="auth-page row items-center justify-center" style="height: 100vh;">
    <q-card style="width: 360px; padding: 40px 32px;" flat bordered>
      <div class="text-h5 text-weight-bold q-mb-xs">krushn notes</div>
      <div class="text-caption text-grey q-mb-xl">Your personal notes and tasks</div>

      <q-btn
        unelevated
        color="dark"
        class="full-width"
        icon="code"
        label="Sign in with GitHub"
        :href="loginUrl"
        no-caps
        size="md"
      />
    </q-card>
  </div>
</template>

<script setup>
const loginUrl = '/api/auth/github'
</script>
