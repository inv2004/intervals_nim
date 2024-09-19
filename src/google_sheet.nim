import std/httpclient
import json
import std/strformat
import std/times
import std/strutils
import std/tables

import oauth/oauth2

from objs import defConst

const
  API_URL = "https://sheets.googleapis.com/v4/spreadsheets"
  TOKEN_URL = "https://accounts.google.com/o/oauth2/token"
  CLIENT_SCOPE = @["https://www.googleapis.com/auth/spreadsheets", "email"]
  dateFormat = "M/d/YYYY"

defConst(SHEET_ID)
defConst(CLIENT_ID)
defConst(CLIENT_SECRET)
defConst(REFRESH_TOKEN)

type
  GSheetClient = ref object
    client: HttpClient
    accessToken: string

  Row = object
    num: int
    row: JsonNode
    client: GSheetClient
    newResult*: string # empty if no updates to result

proc newGSheetClient*(): GSheetClient =
  new(result)
  result.client = newHttpClient()
  let res = result.client.refreshToken(TOKEN_URL, CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN, CLIENT_SCOPE, false)
  result.accessToken = res.body.parseJson()["access_token"].getStr()

proc row(self: GSheetClient, today: string): Row =
  let res = self.client.bearerRequest(fmt"{API_URL}/{SHEET_ID}/values/A:J?majorDimension=ROWS", self.accessToken)
  let j = res.body.parseJson
  doAssert j["majorDimension"].getStr == "ROWS"
  for i, it in j["values"].getElems:
    if it.len > 0 and it[0].getStr == today:
      return Row(num: 1+i, row: it, client: self)

proc row*(self: GSheetClient, today: DateTime): Row =
  row(self, today.format(dateFormat))

proc col(x: char): int =
  int(x.byte - 'A'.byte)

proc plan*(x: Row): string =
  if 'E'.col < x.row.len:
    return x.row['E'.col].getStr()

proc getOldText(txt: string): string =
  if txt == "":
    return ""

  var lines = txt.split("\n")
  if lines.len > 0 and lines[0].startsWith("bot: "):
    lines.delete(0)

  result = lines.join("\n")

  if result.len > 0:
    if not result.startsWith("  old: "):
      result = "  old: " & result
    result = "\n" & result

proc setCol(x: var Row, c: char, val: string, saveOld = false) =
  let old = if c.col < x.row.len: x.row[c.col].getStr else: ""

  let finalVal =
    if saveOld:
      fmt"{val}{(getOldText(old))}"
    else:
      val

  if old == finalVal:
    return

  let valueRange = fmt"{c}{x.num}"

  let res = x.client.client.bearerRequest(
    fmt"{API_URL}/{SHEET_ID}/values/{valueRange}?valueInputOption=USER_ENTERED",
    x.client.accessToken,
    httpMethod = HttpPut,
    body = $ %*{
      "range": valueRange,
      "majorDimension": "ROWS",
      "values": [[finalVal]]
    },
    extraHeaders = newHttpHeaders([("Content-Type", "application/json")])
  )

  let j = res.body.parseJson
  doAssert j["updatedCells"].getInt == 1

  if saveOld:
    x.newResult = finalVal

func date*(x: Row): string =
  x.row['A'.col].getStr  

proc `distance=`*(x: var Row, val: string) =
  x.setCol('F', val)

proc `movingTime=`*(x: var Row, val: string) =
  x.setCol('G', val)

proc `calories=`*(x: var Row, val: string) =
  x.setCol('H', val)

proc `virtual=`*(x: var Row, val: string) =
  x.setCol('I', val)

proc `comment=`*(x: var Row, val: string) =
  x.setCol('K', val)

proc `result=`*(x: var Row, val: string) =
  x.setCol('J', val, true)

proc setUpdates*(self: GSheetClient, upds: Table[string, string]) =
  for k, v in upds:
    var row = self.row(k)
    row.comment = v
  

