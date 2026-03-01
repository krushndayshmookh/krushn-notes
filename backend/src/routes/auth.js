const express = require('express')
const passport = require('passport')
const GitHubStrategy = require('passport-github2').Strategy
const jwt = require('jsonwebtoken')
const User = require('../models/User')
const { pusher } = require('../lib/pusher')
const requireAuth = require('../middleware/auth')

const router = express.Router()

// Configure GitHub strategy
passport.use(new GitHubStrategy(
  {
    clientID:     process.env.GITHUB_CLIENT_ID,
    clientSecret: process.env.GITHUB_CLIENT_SECRET,
    callbackURL:  `${process.env.API_URL || 'http://localhost:3000'}/api/auth/github/callback`
  },
  async (accessToken, refreshToken, profile, done) => {
    try {
      let user = await User.findOne({ githubId: profile.id })
      if (!user) {
        user = await User.create({
          githubId:  profile.id,
          username:  profile.username,
          email:     profile.email || profile.emails?.[0]?.value || '',
          avatarUrl: profile.photos?.[0]?.value || ''
        })
      }
      done(null, user)
    } catch (err) {
      done(err)
    }
  }
))

// Start GitHub OAuth
router.get('/github', passport.authenticate('github', { session: false }))

// GitHub OAuth callback
router.get(
  '/github/callback',
  passport.authenticate('github', { session: false, failureRedirect: `${process.env.WEB_URL}/login?error=oauth` }),
  (req, res) => {
    const token = jwt.sign(
      { sub: req.user._id.toString(), username: req.user.username },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    )

    // Redirect to web app with token, or to native app via custom URL scheme
    const webUrl = process.env.WEB_URL || 'http://localhost:9000'
    res.redirect(`${webUrl}/auth/callback?token=${token}`)
  }
)

// Pusher private channel auth
router.post('/pusher', requireAuth, (req, res) => {
  const socketId = req.body.socket_id
  const channel  = req.body.channel_name

  // Only allow users to auth their own channel
  const expectedChannel = `private-user-${req.userId}`
  if (channel !== expectedChannel) {
    return res.status(403).json({ error: 'Forbidden' })
  }

  const authResponse = pusher.authorizeChannel(socketId, channel)
  res.json(authResponse)
})

module.exports = router
