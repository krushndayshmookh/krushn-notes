const express = require('express')
const Folder   = require('../models/Folder')
const Note     = require('../models/Note')
const TaskList = require('../models/TaskList')
const Task     = require('../models/Task')
const requireAuth = require('../middleware/auth')

const router = express.Router()
router.use(requireAuth)

/**
 * GET /api/sync?since=<ISO timestamp>
 *
 * Returns all items created or updated after the given timestamp.
 * Folders and TaskLists don't have updatedAt so we use createdAt.
 * Deleted items are not tracked — client should handle missing IDs on Pusher events.
 */
router.get('/', async (req, res) => {
  const since = req.query.since ? new Date(req.query.since) : new Date(0)
  const userId = req.userId

  const [folders, notes, taskLists, tasks] = await Promise.all([
    Folder.find({ userId, createdAt: { $gt: since } }),
    Note.find({ userId, updatedAt: { $gt: since } }),
    TaskList.find({ userId, createdAt: { $gt: since } }),
    Task.find({ userId, updatedAt: { $gt: since } })
  ])

  res.json({
    folders,
    notes,
    taskLists,
    tasks,
    syncedAt: new Date().toISOString()
  })
})

module.exports = router
