import std/httpclient, std/base64
import std/times
import std/strformat
import std/json
import std/sequtils
import std/algorithm
import std/strutils
import std/logging

import objs
import analytics

const API_URL = "https://intervals.icu/api/v1"

defConst(INTERVALS_API_KEY)
defConst(INTERVALS_ATHLETE)

proc findActivities(client: HttpClient, today: DateTime, athlete: string): seq[Activity] =
  let todayStr = today.format("yyyy-MM-dd")
  let res = client.getContent(fmt"{API_URL}/athlete/{athlete}/activities?oldest={todayStr}&newest={todayStr}T23:59:59")
  let j = res.parseJson
  # echo j.pretty
  j.getElems.mapIt(Activity(
    id: it["id"].getStr,
    name: it["name"].getStr,
    calories: it["calories"].getInt,
    moving_time: it["moving_time"].getInt,
    distance: it["distance"].getFloat,
    virtual: it["type"].getStr == "VirtualRide"
  )).sorted

proc activity(client: HttpClient, activity: Activity): Activity =
  # let res = client.getContent(fmt"{API_URL}/activity/{activity}")
  let res = client.getContent(fmt"{API_URL}/activity/{activity.id}/streams?types=time,raw_watts")
  let streams = res.parseJson.getElems
  let timesObjs = streams.filterIt(it["type"].getStr == "time")
  doAssert timesObjs.len == 1
  doAssert timesObjs[0]["valueType"].getStr == "java.lang.Integer"
  let wattsObjs = streams.filterIt(it["type"].getStr == "raw_watts")
  doAssert wattsObjs.len == 1
  doAssert wattsObjs[0]["valueType"].getStr == "java.lang.Float"
  result = activity
  result.time = timesObjs[0]["data"].mapIt(it.getInt)
  result.watts = wattsObjs[0]["data"].mapIt(it.getFloat)

proc activities*(today: DateTime): seq[Activity] =
  let client = newHttpClient()
  client.headers["Authorization"] = "Basic " & base64.encode("API_KEY:" & INTERVALS_API_KEY)
  client.findActivities(today, INTERVALS_ATHLETE).mapIt(client.activity(it))

proc distanceSumVal*(xx: seq[Activity]): string =
  if xx.len > 0:
    return '=' & xx.mapIt(it.distance / 1000).mapIt($it.int).join("+")

proc movingTimeVal*(xx: seq[Activity]): string =
  let minutes = xx.mapIt(it.moving_time).foldl(a+b) div 60
  let dp = initDuration(minutes = minutes).toParts()
  fmt"{dp[Hours]}:{dp[Minutes]:02d}"

proc caloriesSumVal*(xx: seq[Activity]): string =
  if xx.len > 0:
    return '=' & xx.mapIt($it.calories).join("+")

proc virtualVal*(xx: seq[Activity]): string =
  if xx.anyIt(it.virtual):
    return "X"

proc resultVal*(xx: seq[Activity], plan: string): string =
  if plan != "":
    let res = $normalize_plan(plan).process(xx)[1]
    info "Result: ", res
    return "bot: " & res

proc stat*(xx: seq[Activity]): string =
  result.add "(calories: "
  result.add $xx.mapIt(it.calories).foldl(a + b)
  result.add ", moving_time: "
  result.add movingTimeVal(xx)
  result.add ", distance: "
  result.add $(xx.mapIt(it.distance).foldl(a + b) / 1000)
  result.add ", virtual: "
  result.add virtualVal(xx)
  result.add ")"

