const express = require('express')
const Folder = require('../models/Folder')
const Note   = require('../models/Note')
const requireAuth = require('../middleware/auth')
const { triggerUserEvent } = require('../lib/pusher')

const router = express.Router()
router.use(requireAuth)

// GET /api/folders
router.get('/', async (req, res) => {
  const folders = await Folder.find({ userId: req.userId }).sort({ name: 1 })
  res.json(folders)
})

// POST /api/folders
router.post('/', async (req, res) => {
  const { name } = req.body
  if (!name?.trim()) return res.status(400).json({ error: 'name is required' })

  const folder = await Folder.create({ userId: req.userId, name: name.trim() })
  await triggerUserEvent(req.userId, 'folder:created', folder)
  res.status(201).json(folder)
})

// PUT /api/folders/:id
router.put('/:id', async (req, res) => {
  const { name } = req.body
  if (!name?.trim()) return res.status(400).json({ error: 'name is required' })

  const folder = await Folder.findOneAndUpdate(
    { _id: req.params.id, userId: req.userId },
    { name: name.trim() },
    { new: true }
  )
  if (!folder) return res.status(404).json({ error: 'Folder not found' })

  await triggerUserEvent(req.userId, 'folder:updated', folder)
  res.json(folder)
})

// DELETE /api/folders/:id
router.delete('/:id', async (req, res) => {
  const folder = await Folder.findOneAndDelete({ _id: req.params.id, userId: req.userId })
  if (!folder) return res.status(404).json({ error: 'Folder not found' })

  // Notes in the deleted folder become unfoldered (not deleted)
  await Note.updateMany(
    { userId: req.userId, folderId: req.params.id },
    { $set: { folderId: null, updatedAt: new Date() } }
  )

  await triggerUserEvent(req.userId, 'folder:deleted', { _id: req.params.id })
  res.json({ success: true })
})

module.exports = router
