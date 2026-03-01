<template>
  <div class="column" style="height: 100%;" v-if="note">
    <!-- Toolbar -->
    <div class="row items-center q-px-md q-py-sm" style="border-bottom: 1px solid rgba(0,0,0,0.08); gap: 8px;">
      <!-- Folder picker -->
      <q-select
        v-model="selectedFolderId"
        :options="folderOptions"
        option-value="value"
        option-label="label"
        emit-value map-options
        dense outlined
        placeholder="No folder"
        style="min-width: 150px; max-width: 200px;"
        @update:model-value="onFolderChange"
      />

      <q-space />

      <!-- Tag chips (read-only, derived from content) -->
      <q-chip
        v-for="tag in note.tags"
        :key="tag"
        dense size="sm"
        color="blue-grey-2" text-color="blue-grey-9"
        :label="'#' + tag"
        class="tag-chip"
      />

      <!-- Markdown toggle -->
      <q-btn-toggle
        v-model="isRendered"
        toggle-color="primary"
        :options="[
          { label: 'Edit', value: false },
          { label: 'Preview', value: true }
        ]"
        dense no-caps size="sm"
        unelevated
        style="border: 1px solid rgba(0,0,0,0.2); border-radius: 4px;"
      />

      <!-- Delete -->
      <q-btn flat round icon="delete_outline" size="sm" color="negative" @click="deleteNote" />
    </div>

    <!-- Title input -->
    <q-input
      v-model="titleValue"
      placeholder="Title"
      borderless
      class="q-px-md q-pt-md"
      style="font-size: 20px; font-weight: 600;"
      @update:model-value="debouncedSave"
    />

    <!-- Editor / Preview area -->
    <div class="col q-px-md q-pb-md" style="overflow: hidden; display: flex; flex-direction: column;">
      <!-- Edit mode -->
      <q-input
        v-if="!isRendered"
        v-model="contentValue"
        type="textarea"
        borderless
        class="col note-editor"
        style="resize: none; height: 100%;"
        input-style="height: 100%; resize: none;"
        autogrow
        placeholder="Write in markdown..."
        @update:model-value="debouncedSave"
      />

      <!-- Preview mode -->
      <q-scroll-area v-else class="col">
        <div
          class="markdown-body q-py-sm"
          v-html="renderedContent"
        />
      </q-scroll-area>
    </div>
  </div>

  <!-- Empty state when no note selected -->
  <div v-else class="column items-center justify-center text-grey" style="height: 100%;">
    <q-icon name="edit_note" size="64px" />
    <div class="q-mt-md text-subtitle1">Select or create a note</div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import MarkdownIt from 'markdown-it'
import DOMPurify from 'dompurify'
import { useNotesStore } from '../stores/notes'
import { useQuasar } from 'quasar'

const md = new MarkdownIt({ linkify: true, typographer: true })
const $q = useQuasar()

const notesStore = useNotesStore()
const note = computed(() => notesStore.activeNote)

const isRendered    = ref(false)
const titleValue    = ref('')
const contentValue  = ref('')
const selectedFolderId = ref(null)

// Sync local state when active note changes
watch(note, (n) => {
  if (!n) return
  titleValue.value   = n.title || ''
  contentValue.value = n.content || ''
  selectedFolderId.value = n.folderId || null
}, { immediate: true })

const folderOptions = computed(() => [
  { value: null, label: 'No folder' },
  ...notesStore.folders.map(f => ({ value: f._id, label: f.name }))
])

const renderedContent = computed(() => {
  const raw = md.render(contentValue.value || '')
  return DOMPurify.sanitize(raw)
})

// ── Debounced save ─────────────────────────────────────────────────
let saveTimer = null
function debouncedSave() {
  clearTimeout(saveTimer)
  saveTimer = setTimeout(doSave, 1000)
}

async function doSave() {
  if (!note.value) return
  await notesStore.saveNote(note.value._id, {
    title:   titleValue.value,
    content: contentValue.value
  })
}

async function onFolderChange(folderId) {
  if (!note.value) return
  await notesStore.saveNote(note.value._id, { folderId })
}

async function deleteNote() {
  $q.dialog({
    title: 'Delete note?',
    message: 'This cannot be undone.',
    cancel: true
  }).onOk(async () => {
    await notesStore.deleteNote(note.value._id)
  })
}
</script>
