fs         = require 'fs'
crypto     = require 'crypto'
{execSync} = require 'child_process'

resources       = __dirname + '/resources/'
binPath         = __dirname + '/node_modules/.bin/'
camelRx         = /([a-z])([A-Z])/g
projNameRx      = /\$PROJECT_NAME\$/g
projNameHyphRx  = /\$PROJECT_NAME_HYPHENATED\$/g
projNameUnderRx = /\$PROJECT_NAME_UNDERSCORED\$/g

log = (s) ->
  console.log "\x1b[32m#{ s }...\x1b[0m"


logErr = (err) ->
  console.error "\x1b[31m#{ err }\x1b[0m"


editSync = (path, pairs) ->
  fs.writeFileSync path, pairs.reduce (contents, [rx, replacement]) ->
    contents.replace rx, replacement
  , fs.readFileSync path, encoding: 'ascii'


init = (projName) ->
