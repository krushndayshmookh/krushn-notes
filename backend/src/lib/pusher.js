const Pusher = require('pusher')

const pusher = new Pusher({
  appId:   process.env.PUSHER_APP_ID,
  key:     process.env.PUSHER_KEY,
  secret:  process.env.PUSHER_SECRET,
  cluster: process.env.PUSHER_CLUSTER,
  useTLS:  true
})

/**
 * Trigger an event on a user's private channel.
 * @param {string} userId  MongoDB ObjectId string
 * @param {string} event   e.g. 'note:updated'
 * @param {object} payload
 */
function triggerUserEvent(userId, event, payload) {
  const channel = `private-user-${userId}`
  return pusher.trigger(channel, event, payload)
}

module.exports = { pusher, triggerUserEvent }
