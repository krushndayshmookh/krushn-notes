require('dotenv').config()
require('express-async-errors')

const express  = require('express')
const cors     = require('cors')
const passport = require('passport')
const mongoose = require('mongoose')

const authRoutes    = require('../src/routes/auth')
const folderRoutes  = require('../src/routes/folders')
const noteRoutes    = require('../src/routes/notes')
const tagRoutes     = require('../src/routes/tags')
const listRoutes    = require('../src/routes/lists')
const taskRoutes    = require('../src/routes/tasks')
const syncRoutes    = require('../src/routes/sync')

const app = express()

// CORS — allow web app origin
const allowedOrigins = [
  process.env.WEB_URL,
  'http://localhost:9000',
  'http://localhost:3000'
].filter(Boolean)

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin || allowedOrigins.includes(origin)) return callback(null, true)
    callback(new Error(`CORS: origin ${origin} not allowed`))
  },
  credentials: true
}))

app.use(express.json())
app.use(express.urlencoded({ extended: false }))
app.use(passport.initialize())

// Connect to MongoDB (cached for serverless)
let dbConnected = false
async function connectDB() {
  if (dbConnected) return
  await mongoose.connect(process.env.MONGODB_URI)
  dbConnected = true
}

app.use(async (req, res, next) => {
  try {
    await connectDB()
    next()
  } catch (err) {
    next(err)
  }
})

// Health check
app.get('/health', (req, res) => res.json({ ok: true }))

// Routes
app.use('/api/auth',  authRoutes)
app.use('/api/folders', folderRoutes)
app.use('/api/notes',   noteRoutes)
app.use('/api/tags',    tagRoutes)
app.use('/api/lists',   listRoutes)
app.use('/api/tasks',   taskRoutes)
app.use('/api/sync',    syncRoutes)

// Global error handler
app.use((err, req, res, next) => {
  console.error(err)
  const status = err.status || err.statusCode || 500
  res.status(status).json({ error: err.message || 'Internal server error' })
})

// For local dev
if (require.main === module) {
  const port = process.env.PORT || 3000
  app.listen(port, () => console.log(`Backend listening on http://localhost:${port}`))
}

module.exports = app
