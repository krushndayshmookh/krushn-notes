<template>
  <q-page class="row no-wrap" style="height: calc(100vh - 50px); overflow: hidden;">
    <!-- Notes list panel -->
    <NotesList
      class="notes-list-panel"
      :active-note-id="activeNoteId"
      @select="openNote"
      @new="newNote"
    />

    <!-- Note editor -->
    <div class="col">
      <NoteEditor />
    </div>
  </q-page>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import NotesList  from '../components/NotesList.vue'
import NoteEditor from '../components/NoteEditor.vue'
import { useNotesStore } from '../stores/notes'

const route  = useRoute()
const router = useRouter()
const notesStore = useNotesStore()

const activeNoteId = computed(() => route.params.id || null)

onMounted(async () => {
  // If a note ID is in the URL, load it
  if (route.params.id) {
    await notesStore.loadNote(route.params.id)
  }
})

async function openNote(id) {
  await notesStore.loadNote(id)
  router.push(`/notes/${id}`)
}

async function newNote() {
  const folderId = notesStore.filterFolderId === undefined ? null : notesStore.filterFolderId
  const note = await notesStore.createNote(folderId)
  router.push(`/notes/${note._id}`)
}
</script>
