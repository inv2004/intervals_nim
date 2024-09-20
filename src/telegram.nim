import std/asyncdispatch
import telebot
import telebot/private/utils
import std/json
import std/strutils
import std/times
import std/tables
import std/logging

import objs

from google_sheet import DATE_FORMAT

defConst(TELEGRAM_API_KEY)
defConst(TELEGRAM_USER_ID)

const USER_ID = TELEGRAM_USER_ID.parseInt

const CHAT_ID = USER_ID

proc newTeleBot*(): TeleBot =
  newTeleBot(TELEGRAM_API_KEY)

proc sendMsg*(bot: TeleBot, msg: string) =
  let bot = newTeleBot(TELEGRAM_API_KEY)
  discard waitFor bot.sendMessage(CHAT_ID, msg, parseMode = "markdown", disableNotification = true)

proc getDateStr(msg: Message): string =
  if msg.replyToMessage.isNil:
    return fromUnix(msg.date).local.format(DATE_FORMAT)
  try:
    let parts = msg.replyToMessage.text.split(": ")
    if parts.len != 2:
      return
    discard parts[0].parse(DATE_FORMAT)
    return parts[0]    
  except:
    discard

proc getUpdates*(bot: TeleBot): Table[string, string] =
  var clean = false
  for item in waitFor bot.getUpdates(limit = 10, timeout = 2):
    clean = true
    let upd = unmarshal(item, Update)
    var msg = upd.message
    if msg.isNil:
      msg = upd.editedMessage
    if msg.isNil:
      continue
    if msg.fromUser.id != USER_ID or msg.chat.id != CHAT_ID:
      return
    let day = getDateStr(msg)
    if day != "":
      result[day] = msg.text
      discard waitFor bot.setMessageReaction(CHAT_ID, msg.messageId, @[ReactionTypeEmoji("👍")])

  if clean:
    waitFor bot.cleanUpdates()
