<template>
  <q-layout view="lHh Lpr lFf">
    <!-- Header -->
    <q-header elevated>
      <q-toolbar>
        <q-btn flat round icon="menu" @click="drawerOpen = !drawerOpen" />
        <q-toolbar-title class="text-weight-bold" style="font-size: 16px;">krushn notes</q-toolbar-title>

        <!-- Offline indicator -->
        <q-chip v-if="!isOnline" color="warning" text-color="black" icon="wifi_off" label="Offline" size="sm" />

        <!-- Sync indicator -->
        <q-spinner v-if="isSyncing" size="18px" color="white" class="q-ml-sm" />

        <q-btn flat round icon="logout" @click="auth.logout()" title="Sign out" />
      </q-toolbar>
    </q-header>

    <!-- Left Drawer -->
    <q-drawer v-model="drawerOpen" show-if-above :width="220" bordered>
      <q-list padding>
        <!-- Section: Notes -->
        <q-item-label header class="text-weight-bold text-uppercase" style="font-size: 11px; letter-spacing: 0.08em;">
          Notes
        </q-item-label>

        <!-- All Notes -->
        <q-item
          clickable v-ripple
          :active="route.path.startsWith('/notes') && notesStore.filterFolderId === undefined && !notesStore.filterTag"
          active-class="bg-primary text-white"
          @click="goAllNotes"
        >
          <q-item-section avatar><q-icon name="notes" size="18px" /></q-item-section>
          <q-item-section>All Notes</q-item-section>
        </q-item>

        <!-- Folders -->
        <q-expansion-item
          v-model="foldersExpanded"
          icon="folder"
          label="Folders"
          dense
          header-class="text-weight-medium"
        >
          <q-item
            v-for="folder in notesStore.folders"
            :key="folder._id"
            clickable v-ripple dense
            :active="notesStore.filterFolderId === folder._id"
            active-class="bg-primary text-white"
            @click="goFolder(folder._id)"
          >
            <q-item-section avatar style="min-width: 28px;">
              <q-icon name="folder_open" size="16px" />
            </q-item-section>
            <q-item-section>{{ folder.name }}</q-item-section>
            <q-item-section side>
              <q-btn flat round icon="more_vert" size="xs" @click.stop="openFolderMenu(folder, $event)" />
            </q-item-section>
          </q-item>

          <!-- New Folder -->
          <q-item clickable v-ripple dense @click="showNewFolder = true">
            <q-item-section avatar style="min-width: 28px;">
              <q-icon name="add" size="16px" color="grey" />
            </q-item-section>
            <q-item-section class="text-grey">New folder</q-item-section>
          </q-item>
        </q-expansion-item>

        <!-- Tags -->
        <q-expansion-item
          v-model="tagsExpanded"
          icon="tag"
          label="Tags"
          dense
          header-class="text-weight-medium"
        >
          <q-item
            v-for="tag in notesStore.allTags"
            :key="tag"
            clickable v-ripple dense
            :active="notesStore.filterTag === tag"
            active-class="bg-primary text-white"
            @click="goTag(tag)"
          >
            <q-item-section avatar style="min-width: 28px;">
              <q-icon name="tag" size="14px" />
            </q-item-section>
            <q-item-section style="font-size: 13px;"># {{ tag }}</q-item-section>
          </q-item>
        </q-expansion-item>

        <q-separator class="q-my-sm" />

        <!-- Section: Tasks -->
        <q-item-label header class="text-weight-bold text-uppercase" style="font-size: 11px; letter-spacing: 0.08em;">
          Tasks
        </q-item-label>

        <q-item
          v-for="list in tasksStore.taskLists"
          :key="list._id"
          clickable v-ripple dense
          :active="route.path.startsWith('/tasks') && tasksStore.activeListId === list._id"
          active-class="bg-primary text-white"
          @click="goList(list._id)"
        >
          <q-item-section avatar style="min-width: 28px;">
            <q-icon name="checklist" size="16px" />
          </q-item-section>
          <q-item-section>{{ list.name }}</q-item-section>
          <q-item-section side v-if="list.isDefault">
            <q-badge color="grey-5" label="default" />
          </q-item-section>
        </q-item>

        <q-item clickable v-ripple dense @click="showNewList = true">
          <q-item-section avatar style="min-width: 28px;">
            <q-icon name="add" size="16px" color="grey" />
          </q-item-section>
          <q-item-section class="text-grey">New list</q-item-section>
        </q-item>
      </q-list>
    </q-drawer>

    <!-- Main content -->
    <q-page-container>
      <router-view />
    </q-page-container>

    <!-- Folder context menu -->
    <q-menu v-model="folderMenuOpen" :target="folderMenuTarget">
      <q-list style="min-width: 140px;">
        <q-item clickable v-close-popup @click="startRenameFolder">
          <q-item-section>Rename</q-item-section>
        </q-item>
        <q-item clickable v-close-popup @click="confirmDeleteFolder">
          <q-item-section class="text-negative">Delete</q-item-section>
        </q-item>
      </q-list>
    </q-menu>

    <!-- New Folder dialog -->
    <q-dialog v-model="showNewFolder" @hide="newFolderName = ''">
      <q-card style="min-width: 300px;" flat bordered>
        <q-card-section class="text-h6">New Folder</q-card-section>
        <q-card-section>
          <q-input
            v-model="newFolderName"
            autofocus
            placeholder="Folder name"
            dense outlined
            @keyup.enter="createFolder"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn flat label="Create" color="primary" @click="createFolder" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Rename Folder dialog -->
    <q-dialog v-model="showRenameFolder" @hide="renameFolderName = ''">
      <q-card style="min-width: 300px;" flat bordered>
        <q-card-section class="text-h6">Rename Folder</q-card-section>
        <q-card-section>
          <q-input
            v-model="renameFolderName"
            autofocus dense outlined
            @keyup.enter="doRenameFolder"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn flat label="Save" color="primary" @click="doRenameFolder" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- New List dialog -->
    <q-dialog v-model="showNewList" @hide="newListName = ''">
      <q-card style="min-width: 300px;" flat bordered>
        <q-card-section class="text-h6">New Task List</q-card-section>
        <q-card-section>
          <q-input
            v-model="newListName"
            autofocus placeholder="List name"
            dense outlined
            @keyup.enter="createList"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn flat label="Create" color="primary" @click="createList" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-layout>
</template>

<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore }  from '../stores/auth'
import { useNotesStore } from '../stores/notes'
import { useTasksStore } from '../stores/tasks'
import { useSync }       from '../composables/useSync'

const route  = useRoute()
const router = useRouter()
const $q     = useQuasar()
const auth   = useAuthStore()
const notesStore = useNotesStore()
const tasksStore = useTasksStore()

const { isOnline, isSyncing } = useSync()

const drawerOpen     = ref(true)
const foldersExpanded = ref(true)
const tagsExpanded    = ref(false)

// Folder dialogs
const showNewFolder     = ref(false)
const newFolderName     = ref('')
const showRenameFolder  = ref(false)
const renameFolderName  = ref('')
const folderMenuOpen    = ref(false)
const folderMenuTarget  = ref(null)
const activeMenuFolder  = ref(null)

// List dialogs
const showNewList  = ref(false)
const newListName  = ref('')

// ── Navigation helpers ─────────────────────────────────────────────
function goAllNotes() {
  notesStore.filterFolderId = undefined
  notesStore.filterTag = null
  router.push('/notes')
}

function goFolder(id) {
  notesStore.filterFolderId = id
  notesStore.filterTag = null
  router.push('/notes')
}

function goTag(tag) {
  notesStore.filterFolderId = undefined
  notesStore.filterTag = tag
  router.push('/notes')
}

function goList(id) {
  tasksStore.selectList(id)
  router.push(`/tasks/${id}`)
}

// ── Folder actions ─────────────────────────────────────────────────
function openFolderMenu(folder, evt) {
  activeMenuFolder.value = folder
  folderMenuTarget.value = evt.target
  folderMenuOpen.value   = true
}

async function createFolder() {
  if (!newFolderName.value.trim()) return
  await notesStore.createFolder(newFolderName.value.trim())
  showNewFolder.value = false
  newFolderName.value = ''
}

function startRenameFolder() {
  renameFolderName.value = activeMenuFolder.value?.name || ''
  showRenameFolder.value = true
}

async function doRenameFolder() {
  if (!renameFolderName.value.trim()) return
  await notesStore.renameFolder(activeMenuFolder.value._id, renameFolderName.value.trim())
  showRenameFolder.value = false
}

function confirmDeleteFolder() {
  $q.dialog({
    title: 'Delete folder?',
    message: 'Notes inside will become unfiled. This cannot be undone.',
    cancel: true,
    persistent: true
  }).onOk(async () => {
    await notesStore.deleteFolder(activeMenuFolder.value._id)
  })
}

// ── List actions ───────────────────────────────────────────────────
async function createList() {
  if (!newListName.value.trim()) return
  const list = await tasksStore.createList(newListName.value.trim())
  showNewList.value = false
  newListName.value = ''
  goList(list._id)
}
</script>
