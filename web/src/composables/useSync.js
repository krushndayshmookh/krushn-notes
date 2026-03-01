import { ref, onMounted, onUnmounted } from 'vue'
import Pusher from 'pusher-js'
import { api } from '../boot/axios'
import db from '../db'
import { useNotesStore } from '../stores/notes'
import { useTasksStore } from '../stores/tasks'
import { useAuthStore } from '../stores/auth'

export function useSync() {
  const isOnline  = ref(navigator.onLine)
  const isSyncing = ref(false)
  let pusherInstance = null

  const notes = useNotesStore()
  const tasks = useTasksStore()
  const auth  = useAuthStore()

  // ── Flush offline queue ────────────────────────────────────────────
  async function flushQueue() {
    const queue = await db.syncQueue.orderBy('createdAt').toArray()
    for (const op of queue) {
      try {
        if (op.method === 'POST')   await api.post(op.path, op.body)
        if (op.method === 'PUT')    await api.put(op.path, op.body)
        if (op.method === 'DELETE') await api.delete(op.path)
        await db.syncQueue.delete(op.id)
      } catch (err) {
        // Stop on first error — retry later in order
        console.warn('Queue flush stopped at', op, err)
        break
      }
    }
  }

  // ── Full delta sync ────────────────────────────────────────────────
  async function syncAll() {
    if (isSyncing.value) return
    isSyncing.value = true
    try {
      await flushQueue()
      await notes.syncFromServer()
      await tasks.loadLists()
    } catch (err) {
      console.error('Sync failed:', err)
    } finally {
      isSyncing.value = false
    }
  }

  // ── Pusher setup ───────────────────────────────────────────────────
  function connectPusher() {
    if (pusherInstance || !auth.token) return

    pusherInstance = new Pusher(process.env.PUSHER_KEY, {
      cluster: process.env.PUSHER_CLUSTER,
      authEndpoint: '/api/auth/pusher',
      auth: {
        headers: { Authorization: `Bearer ${auth.token}` }
      }
    })

    // Extract userId from JWT (payload is base64url, no crypto needed)
    const payload = JSON.parse(atob(auth.token.split('.')[1]))
    const userId  = payload.sub

    const channel = pusherInstance.subscribe(`private-user-${userId}`)

    channel.bind('note:created',  (data) => notes.onNoteCreated(data))
    channel.bind('note:updated',  (data) => notes.onNoteUpdated(data))
    channel.bind('note:deleted',  (data) => notes.onNoteDeleted(data))
    channel.bind('folder:created',(data) => notes.onFolderCreated(data))
    channel.bind('folder:updated',(data) => notes.onFolderUpdated(data))
    channel.bind('folder:deleted',(data) => notes.onFolderDeleted(data))
    channel.bind('list:created',  (data) => tasks.onListCreated(data))
    channel.bind('list:updated',  (data) => tasks.onListUpdated(data))
    channel.bind('list:deleted',  (data) => tasks.onListDeleted(data))
    channel.bind('task:created',  (data) => tasks.onTaskCreated(data))
    channel.bind('task:updated',  (data) => tasks.onTaskUpdated(data))
    channel.bind('task:deleted',  (data) => tasks.onTaskDeleted(data))
  }

  function disconnectPusher() {
    pusherInstance?.disconnect()
    pusherInstance = null
  }

  // ── Online/offline handlers ────────────────────────────────────────
  function handleOnline() {
    isOnline.value = true
    syncAll()
  }

  function handleOffline() {
    isOnline.value = false
  }

  onMounted(async () => {
    window.addEventListener('online',  handleOnline)
    window.addEventListener('offline', handleOffline)

    // Load from cache immediately (offline-capable render)
    await notes.loadFromCache()
    await tasks.loadListsFromCache()

    // Sync if online
    if (navigator.onLine) {
      await syncAll()
      connectPusher()
    }
  })

  onUnmounted(() => {
    window.removeEventListener('online',  handleOnline)
    window.removeEventListener('offline', handleOffline)
    disconnectPusher()
  })

  return { isOnline, isSyncing, syncAll }
}
