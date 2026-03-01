import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { api } from '../boot/axios'
import db from '../db'

export const useNotesStore = defineStore('notes', () => {
  const folders    = ref([])
  const notes      = ref([])  // metadata only (no content)
  const allTags    = ref([])
  const activeNote = ref(null) // full note with content

  // Filters
  const filterFolderId = ref(undefined)
  const filterTag      = ref(null)

  const filteredNotes = computed(() => {
    let list = notes.value
    if (filterFolderId.value !== undefined) {
      const fid = filterFolderId.value === 'unfiled' ? null : filterFolderId.value
      list = list.filter(n => String(n.folderId ?? null) === String(fid))
    }
    if (filterTag.value) {
      list = list.filter(n => n.tags?.includes(filterTag.value))
    }
    return list.slice().sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt))
  })

  // ── Load from IndexedDB (instant, offline-capable) ──────────────────
  async function loadFromCache() {
    const [f, n, t] = await Promise.all([
      db.folders.toArray(),
      db.notes.orderBy('updatedAt').reverse().toArray(),
      db.notes.orderBy('tags').keys()
    ])
    folders.value = f
    notes.value   = n.map(({ content: _, ...meta }) => meta)  // strip content from list
    allTags.value = [...new Set(n.flatMap(n => n.tags || []))].sort()
  }

  // ── Sync from server ─────────────────────────────────────────────────
  async function syncFromServer() {
    const since = localStorage.getItem('lastSync') || new Date(0).toISOString()
    const { data } = await api.get(`/api/sync?since=${since}`)

    // Merge folders
    for (const folder of data.folders) {
      await db.folders.put({ ...folder, _id: folder._id })
    }
    // Merge notes (metadata + content)
    for (const note of data.notes) {
      await db.notes.put({ ...note, _id: note._id })
    }

    localStorage.setItem('lastSync', data.syncedAt)
    await loadFromCache()

    // Refresh tags from server
    await refreshTags()
  }

  async function refreshTags() {
    try {
      const { data } = await api.get('/api/tags')
      allTags.value = data
      await db.notes.toArray().then(notes => {
        // tags already on notes in dexie
      })
    } catch {}
  }

  // ── Folders ──────────────────────────────────────────────────────────
  async function createFolder(name) {
    const { data } = await api.post('/api/folders', { name })
    await db.folders.put({ ...data, _id: data._id })
    folders.value = await db.folders.toArray()
    return data
  }

  async function renameFolder(id, name) {
    const { data } = await api.put(`/api/folders/${id}`, { name })
    await db.folders.put({ ...data, _id: data._id })
    folders.value = await db.folders.toArray()
  }

  async function deleteFolder(id) {
    await api.delete(`/api/folders/${id}`)
    await db.folders.delete(id)
    // Unfolder notes locally
    await db.notes.where('folderId').equals(id).modify({ folderId: null })
    folders.value = await db.folders.toArray()
    notes.value   = notes.value.map(n => n.folderId === id ? { ...n, folderId: null } : n)
  }

  // ── Notes ─────────────────────────────────────────────────────────────
  async function loadNote(id) {
    // Try cache first
    const cached = await db.notes.get(id)
    if (cached) activeNote.value = cached

    // Fetch from server to get latest
    try {
      const { data } = await api.get(`/api/notes/${id}`)
      await db.notes.put({ ...data, _id: data._id })
      activeNote.value = data
    } catch {}
    return activeNote.value
  }

  async function createNote(folderId = null) {
    if (!navigator.onLine) {
      const tempId = `temp_${Date.now()}`
      const note = {
        _id: tempId, title: '', content: '', folderId,
        tags: [], updatedAt: new Date().toISOString(), createdAt: new Date().toISOString()
      }
      await db.notes.put(note)
      await db.syncQueue.add({ method: 'POST', path: '/api/notes', body: { folderId }, createdAt: Date.now() })
      notes.value.unshift(note)
      return note
    }

    const { data } = await api.post('/api/notes', { folderId })
    await db.notes.put({ ...data, _id: data._id })
    notes.value.unshift(data)
    activeNote.value = data
    return data
  }

  // Debounced save — called by editor
  async function saveNote(id, patch) {
    // Optimistically update local state
    activeNote.value = { ...activeNote.value, ...patch, updatedAt: new Date().toISOString() }
    const idx = notes.value.findIndex(n => n._id === id)
    if (idx !== -1) notes.value[idx] = { ...notes.value[idx], ...patch, updatedAt: new Date().toISOString() }

    // Persist to Dexie
    await db.notes.update(id, { ...patch, updatedAt: new Date().toISOString() })

    if (!navigator.onLine) {
      await db.syncQueue.add({ method: 'PUT', path: `/api/notes/${id}`, body: patch, createdAt: Date.now() })
      return
    }

    await api.put(`/api/notes/${id}`, patch)
  }

  async function deleteNote(id) {
    await db.notes.delete(id)
    notes.value = notes.value.filter(n => n._id !== id)
    if (activeNote.value?._id === id) activeNote.value = null

    if (!navigator.onLine) {
      await db.syncQueue.add({ method: 'DELETE', path: `/api/notes/${id}`, body: null, createdAt: Date.now() })
      return
    }
    await api.delete(`/api/notes/${id}`)
  }

  // ── Real-time Pusher event handlers ──────────────────────────────────
  function onNoteCreated(note) {
    db.notes.put({ ...note, _id: note._id })
    const exists = notes.value.find(n => n._id === note._id)
    if (!exists) notes.value.unshift(note)
  }

  function onNoteUpdated(note) {
    db.notes.put({ ...note, _id: note._id })
    const idx = notes.value.findIndex(n => n._id === note._id)
    if (idx !== -1) notes.value[idx] = note
    if (activeNote.value?._id === note._id) activeNote.value = note
  }

  function onNoteDeleted({ _id }) {
    db.notes.delete(_id)
    notes.value = notes.value.filter(n => n._id !== _id)
    if (activeNote.value?._id === _id) activeNote.value = null
  }

  function onFolderCreated(folder) {
    db.folders.put({ ...folder, _id: folder._id })
    if (!folders.value.find(f => f._id === folder._id)) folders.value.push(folder)
  }

  function onFolderUpdated(folder) {
    db.folders.put({ ...folder, _id: folder._id })
    const idx = folders.value.findIndex(f => f._id === folder._id)
    if (idx !== -1) folders.value[idx] = folder
  }

  function onFolderDeleted({ _id }) {
    db.folders.delete(_id)
    folders.value = folders.value.filter(f => f._id !== _id)
    notes.value = notes.value.map(n => n.folderId === _id ? { ...n, folderId: null } : n)
  }

  return {
    folders, notes, allTags, activeNote,
    filterFolderId, filterTag, filteredNotes,
    loadFromCache, syncFromServer, refreshTags,
    createFolder, renameFolder, deleteFolder,
    loadNote, createNote, saveNote, deleteNote,
    onNoteCreated, onNoteUpdated, onNoteDeleted,
    onFolderCreated, onFolderUpdated, onFolderDeleted
  }
})
