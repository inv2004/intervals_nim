type
  Activity* = object
    id*: string
    name*: string
    calories*: int
    moving_time*: int
    distance*: float
    virtual*: bool
    time*: seq[int]
    watts*: seq[float]

func `<`*(a, b: Activity): bool =
  a.id < b.id

template defConst*(v: untyped) =
  when defined(v):
    const v {.strdefine.}: string = ""
    when v == "REDEFINE":
      {.error: astToStr(v) & " was not redefined in src/config.nims".}
  else:
    {.error: astToStr(v) & " was not defined in src/config.nims".}
