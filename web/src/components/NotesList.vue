<template>
  <div class="notes-list-panel column" style="height: 100%; border-right: 1px solid rgba(0,0,0,0.12);">
    <!-- Header bar -->
    <div class="row items-center q-px-md q-py-sm" style="border-bottom: 1px solid rgba(0,0,0,0.08);">
      <div class="text-subtitle2 text-weight-medium col">
        {{ headerLabel }}
      </div>
      <q-btn flat round icon="add" size="sm" @click="newNote" title="New note" />
    </div>

    <!-- Empty state -->
    <div v-if="!notesStore.filteredNotes.length" class="col column items-center justify-center text-grey">
      <q-icon name="edit_note" size="48px" />
      <div class="q-mt-sm text-caption">No notes yet</div>
    </div>

    <!-- Note items -->
    <q-scroll-area class="col">
      <q-list separator>
        <q-item
          v-for="note in notesStore.filteredNotes"
          :key="note._id"
          clickable v-ripple
          :active="activeNoteId === note._id"
          active-class="bg-blue-grey-1"
          @click="$emit('select', note._id)"
        >
          <q-item-section>
            <q-item-label class="text-weight-medium ellipsis" style="font-size: 14px;">
              {{ note.title || 'Untitled' }}
            </q-item-label>
            <q-item-label caption class="q-mt-xs">
              {{ formatDate(note.updatedAt) }}
            </q-item-label>
            <!-- Tags -->
            <div v-if="note.tags?.length" class="row q-gutter-xs q-mt-xs">
              <q-chip
                v-for="tag in note.tags.slice(0, 4)"
                :key="tag"
                dense size="xs"
                color="grey-3" text-color="grey-8"
                :label="'#' + tag"
                class="tag-chip"
              />
            </div>
          </q-item-section>
        </q-item>
      </q-list>
    </q-scroll-area>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useNotesStore } from '../stores/notes'

const props = defineProps({
  activeNoteId: { type: String, default: null }
})
const emit = defineEmits(['select', 'new'])

const notesStore = useNotesStore()

const headerLabel = computed(() => {
  if (notesStore.filterTag)     return `#${notesStore.filterTag}`
  if (notesStore.filterFolderId !== undefined) {
    const folder = notesStore.folders.find(f => f._id === notesStore.filterFolderId)
    return folder?.name || 'Unfiled'
  }
  return 'All Notes'
})

function formatDate(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  const now = new Date()
  if (d.toDateString() === now.toDateString()) {
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }
  return d.toLocaleDateString([], { month: 'short', day: 'numeric' })
}

async function newNote() {
  emit('new')
}
</script>
