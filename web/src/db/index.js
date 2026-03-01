import Dexie from 'dexie'

const db = new Dexie('krushnnotes')

db.version(1).stores({
  folders:   '++_id, userId',
  notes:     '++_id, userId, folderId, updatedAt, *tags',
  taskLists: '++_id, userId',
  tasks:     '++_id, listId, order',
  syncQueue: '++id, createdAt'
})

export default db
