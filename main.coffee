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
  projNameHyph = projName.replace(camelRx, '$1-$2').toLowerCase()
  projNameUs   = projName.replace(camelRx, '$1_$2').toLowerCase()

  try
    execSync 'type lein'
    execSync 'type pod'

    log 'Creating Leiningen project'
    execSync "lein new #{ projNameHyph }"

    log 'Updating Leiningen project'
    process.chdir projNameHyph
    execSync "cp #{ resources }project.clj project.clj"
    editSync 'project.clj', [[projNameHyphRx, projNameHyph]]
    corePath = "src/#{ projNameUs }/core.clj"
    fs.unlinkSync corePath
    corePath += 's'
    execSync "cp #{ resources }core.cljs #{ corePath }"
    editSync corePath, [[projNameHyphRx, projNameHyph], [projNameRx, projName]]
    execSync "cp #{ resources }ambly.sh start.sh"
    editSync 'start.sh', [[projNameUnderRx, projNameUs]]

    log 'Compiling ClojureScript'
    execSync 'lein cljsbuild once dev'

    log 'Creating React Native skeleton'
    execSync "#{ binPath }react-native init #{ projName }"
    execSync "mv #{ projName } iOS"

    log 'Installing Pod dependencies'
    process.chdir 'iOS'
    execSync "cp #{ resources }Podfile ."
    execSync 'pod install'

  catch e
    logErr e.message

    process.exit 1
