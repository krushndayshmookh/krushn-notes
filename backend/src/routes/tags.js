const express = require('express')
const Note = require('../models/Note')
const requireAuth = require('../middleware/auth')

const router = express.Router()
router.use(requireAuth)

// GET /api/tags — all distinct tags across the user's notes
router.get('/', async (req, res) => {
  const tags = await Note.distinct('tags', { userId: req.userId })
  res.json(tags.filter(Boolean).sort())
})

module.exports = router
