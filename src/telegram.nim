import std/asyncdispatch
import telebot
import telebot/private/utils
import std/json
import std/strutils
import std/times
import std/tables
import std/logging

import objs

defConst(TELEGRAM_API_KEY)
defConst(TELEGRAM_USER_ID)

const USER_ID = TELEGRAM_USER_ID.parseInt

const CHAT_ID = USER_ID

proc sendMsg*(msg: string) =
  let bot = newTeleBot(TELEGRAM_API_KEY)
  discard waitFor bot.sendMessage(CHAT_ID, msg, parseMode = "markdown", disableNotification = true)

proc getUpdates*(): Table[string, string] =
  let bot = newTeleBot(TELEGRAM_API_KEY)
  var clean = false
  for item in waitFor bot.getUpdates(limit = 10, timeout = 2):
    clean = true
    let upd = unmarshal(item, Update)
    let msg = upd.message
    if msg.fromUser.id != USER_ID or msg.chat.id != CHAT_ID:
      return
    if msg.replyToMessage == nil:
      continue
    let parts = msg.replyToMessage.text.split(": ")
    if parts.len != 2:
      continue
    try:
      discard parts[0].parse("M/d/YYYY")
      result[parts[0]] = msg.text
      discard waitFor bot.setMessageReaction(CHAT_ID, msg.messageId, @[ReactionTypeEmoji("👍")])
    except:
      error "cannot parse result message"
      # discard waitFor bot.sendMessage(CHAT_ID, "cannot parse result message", parseMode = "markdown", replyParameters = ReplyParameters(messageId: msg.messageId))

  if clean:
    waitFor bot.cleanUpdates()
