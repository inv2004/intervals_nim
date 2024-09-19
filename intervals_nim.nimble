# Package

version       = "0.1.0"
author        = "inv2004"
description   = "A new awesome nimble package"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["intervals_nim"]


# Dependencies

requires "nim >= 2.0.2"
requires "oauth"
requires "asciigraph"
requires "telebot"

task static, "build static release":
  exec "nimble build -d:musl -d:release -d:libressl -d:pcre"