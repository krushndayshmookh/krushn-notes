import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { api } from '../boot/axios'
import db from '../db'

export const useTasksStore = defineStore('tasks', () => {
  const taskLists    = ref([])
  const tasks        = ref([])   // tasks for the active list
  const activeListId = ref(null)

  const defaultList = computed(() => taskLists.value.find(l => l.isDefault) || taskLists.value[0])

  // ── Load from cache ───────────────────────────────────────────────────
  async function loadListsFromCache() {
    taskLists.value = await db.taskLists.toArray()
  }

  async function loadTasksFromCache(listId) {
    tasks.value = await db.tasks.where('listId').equals(listId).sortBy('order')
  }

  // ── Sync from server ─────────────────────────────────────────────────
  async function syncFromServer() {
    const since = localStorage.getItem('lastSync') || new Date(0).toISOString()
    // Sync endpoint handles both notes and tasks; tasks store reads cached data
    await loadListsFromCache()
    if (activeListId.value) await loadTasksFromCache(activeListId.value)
  }

  // ── Lists ─────────────────────────────────────────────────────────────
  async function loadLists() {
    await loadListsFromCache()
    if (!navigator.onLine) return

    const { data } = await api.get('/api/lists')
    for (const list of data) {
      await db.taskLists.put({ ...list, _id: list._id })
    }
    taskLists.value = await db.taskLists.toArray()

    // Auto-select default list if none selected
    if (!activeListId.value && taskLists.value.length) {
      const def = taskLists.value.find(l => l.isDefault) || taskLists.value[0]
      await selectList(def._id)
    }
  }

  async function selectList(listId) {
    activeListId.value = listId
    await loadTasksFromCache(listId)

    if (!navigator.onLine) return
    const { data } = await api.get(`/api/lists/${listId}/tasks`)
    for (const task of data) {
      await db.tasks.put({ ...task, _id: task._id })
    }
    tasks.value = await db.tasks.where('listId').equals(listId).sortBy('order')
  }

  async function createList(name) {
    const isDefault = taskLists.value.length === 0
    const { data } = await api.post('/api/lists', { name, isDefault })
    await db.taskLists.put({ ...data, _id: data._id })
    taskLists.value = await db.taskLists.toArray()
    return data
  }

  async function renameList(id, name) {
    const { data } = await api.put(`/api/lists/${id}`, { name })
    await db.taskLists.put({ ...data, _id: data._id })
    const idx = taskLists.value.findIndex(l => l._id === id)
    if (idx !== -1) taskLists.value[idx] = data
  }

  async function deleteList(id) {
    await api.delete(`/api/lists/${id}`)
    await db.taskLists.delete(id)
    await db.tasks.where('listId').equals(id).delete()
    taskLists.value = taskLists.value.filter(l => l._id !== id)
    if (activeListId.value === id) {
      activeListId.value = null
      tasks.value = []
      if (taskLists.value.length) await selectList(taskLists.value[0]._id)
    }
  }

  // ── Tasks ─────────────────────────────────────────────────────────────
  async function addTask(content) {
    const listId = activeListId.value
    if (!listId) return

    const optimistic = {
      _id: `temp_${Date.now()}`,
      listId,
      content,
      completed: false,
      order: tasks.value.length,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }
    tasks.value.push(optimistic)

    if (!navigator.onLine) {
      await db.tasks.put(optimistic)
      await db.syncQueue.add({ method: 'POST', path: `/api/lists/${listId}/tasks`, body: { content }, createdAt: Date.now() })
      return
    }

    const { data } = await api.post(`/api/lists/${listId}/tasks`, { content })
    await db.tasks.put({ ...data, _id: data._id })
    // Replace optimistic entry
    const idx = tasks.value.findIndex(t => t._id === optimistic._id)
    if (idx !== -1) tasks.value[idx] = data
  }

  async function toggleTask(id) {
    const task = tasks.value.find(t => t._id === id)
    if (!task) return
    const completed = !task.completed
    task.completed = completed
    await db.tasks.update(id, { completed, updatedAt: new Date().toISOString() })

    if (!navigator.onLine) {
      await db.syncQueue.add({ method: 'PUT', path: `/api/tasks/${id}`, body: { completed }, createdAt: Date.now() })
      return
    }
    await api.put(`/api/tasks/${id}`, { completed })
  }

  async function updateTaskContent(id, content) {
    const task = tasks.value.find(t => t._id === id)
    if (!task) return
    task.content = content
    await db.tasks.update(id, { content, updatedAt: new Date().toISOString() })

    if (!navigator.onLine) {
      await db.syncQueue.add({ method: 'PUT', path: `/api/tasks/${id}`, body: { content }, createdAt: Date.now() })
      return
    }
    await api.put(`/api/tasks/${id}`, { content })
  }

  async function deleteTask(id) {
    tasks.value = tasks.value.filter(t => t._id !== id)
    await db.tasks.delete(id)

    if (!navigator.onLine) {
      await db.syncQueue.add({ method: 'DELETE', path: `/api/tasks/${id}`, body: null, createdAt: Date.now() })
      return
    }
    await api.delete(`/api/tasks/${id}`)
  }

  // ── Pusher handlers ───────────────────────────────────────────────────
  function onListCreated(list) {
    db.taskLists.put({ ...list, _id: list._id })
    if (!taskLists.value.find(l => l._id === list._id)) taskLists.value.push(list)
  }

  function onListUpdated(list) {
    db.taskLists.put({ ...list, _id: list._id })
    const idx = taskLists.value.findIndex(l => l._id === list._id)
    if (idx !== -1) taskLists.value[idx] = list
  }

  function onListDeleted({ _id }) {
    db.taskLists.delete(_id)
    taskLists.value = taskLists.value.filter(l => l._id !== _id)
    if (activeListId.value === _id) {
      activeListId.value = null
      tasks.value = []
    }
  }

  function onTaskCreated(task) {
    db.tasks.put({ ...task, _id: task._id })
    if (task.listId === activeListId.value && !tasks.value.find(t => t._id === task._id)) {
      tasks.value.push(task)
    }
  }

  function onTaskUpdated(task) {
    db.tasks.put({ ...task, _id: task._id })
    if (task.listId === activeListId.value) {
      const idx = tasks.value.findIndex(t => t._id === task._id)
      if (idx !== -1) tasks.value[idx] = task
    }
  }

  function onTaskDeleted({ _id }) {
    db.tasks.delete(_id)
    tasks.value = tasks.value.filter(t => t._id !== _id)
  }

  return {
    taskLists, tasks, activeListId, defaultList,
    loadListsFromCache, loadTasksFromCache, syncFromServer,
    loadLists, selectList, createList, renameList, deleteList,
    addTask, toggleTask, updateTaskContent, deleteTask,
    onListCreated, onListUpdated, onListDeleted,
    onTaskCreated, onTaskUpdated, onTaskDeleted
  }
})
