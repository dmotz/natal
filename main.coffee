# Natal
# Bootstrap ClojureScript React Native apps
# Dan Motzenbecker
# http://oxism.com
# MIT License

fs         = require 'fs'
crypto     = require 'crypto'
{execSync} = require 'child_process'
cli        = require 'commander'
chalk      = require 'chalk'
semver     = require 'semver'
reactInit  = require 'react-native/local-cli/init'
pkgJson    = require __dirname + '/package.json'

nodeVersion     = pkgJson.engines.node
rnVersion       = pkgJson.dependencies['react-native']
resources       = __dirname + '/resources/'
camelRx         = /([a-z])([A-Z])/g
projNameRx      = /\$PROJECT_NAME\$/g
projNameHyphRx  = /\$PROJECT_NAME_HYPHENATED\$/g
projNameUnderRx = /\$PROJECT_NAME_UNDERSCORED\$/g
podMinVersion   = '0.38.2'


log = (s, color = 'green') ->
  console.log chalk[color] s


logErr = (err, color = 'red') ->
  console.error chalk[color] err
  process.exit 1


editSync = (path, pairs) ->
  fs.writeFileSync path, pairs.reduce (contents, [rx, replacement]) ->
    contents.replace rx, replacement
  , fs.readFileSync path, encoding: 'ascii'


writeConfig = (config) ->
  try
    fs.writeFileSync '.natal', JSON.stringify config, null, 2
  catch {message}
    logErr \
      if message.match /EACCES/i
        'Invalid write permissions for creating .natal config file'
      else
        message


readConfig = ->
  try
    JSON.parse fs.readFileSync '.natal'
  catch {message}
    logErr \
      if message.match /ENOENT/i
        'No Natal config was found in this directory (.natal)'
      else if message.match /EACCES/i
        'No read permissions for .natal'
      else if message.match /Unexpected/i
        '.natal contains malformed JSON'
      else
        message


init = (projName) ->
  projNameHyph = projName.replace(camelRx, '$1-$2').toLowerCase()
  projNameUs   = projName.replace(camelRx, '$1_$2').toLowerCase()

  try
    log "Creating #{projName}", 'bgMagenta'
    log ''

    if fs.existsSync projNameHyph
      throw new Error "Directory #{projNameHyph} already exists"

    execSync 'type lein'
    execSync 'type pod'
    podVersion = execSync('pod --version').toString().trim()
    unless semver.satisfies podVersion, ">=#{podMinVersion}"
      throw new Error """
                      Natal requires CocoaPods #{podMinVersion} or higher (you have #{podVersion}).
                      Run [sudo] gem update cocoapods and try again.
                      """

    log 'Creating Leiningen project'
    execSync "lein new #{projNameHyph}", stdio: 'ignore'

    log 'Updating Leiningen project'
    process.chdir projNameHyph
    execSync "cp #{resources}project.clj project.clj"
    editSync 'project.clj', [[projNameHyphRx, projNameHyph]]
    corePath = "src/#{projNameUs}/core.clj"
    fs.unlinkSync corePath
    corePath += 's'
    execSync "cp #{resources}core.cljs #{corePath}"
    editSync corePath, [[projNameHyphRx, projNameHyph], [projNameRx, projName]]
    execSync "cp #{resources}ambly.sh start.sh"
    editSync 'start.sh', [[projNameUnderRx, projNameUs]]

    log 'Compiling ClojureScript'
    execSync 'lein cljsbuild once dev', stdio: 'ignore'

    log 'Creating React Native skeleton'
    fs.mkdirSync 'iOS'
    process.chdir 'iOS'
    _log = console.log
    global.console.log = ->
    reactInit '.', projName
    global.console.log = _log
    fs.writeFileSync 'package.json', JSON.stringify
      name:    projName
      version: '0.0.1'
      private: true
      scripts:
        start: 'node_modules/react-native/packager/packager.sh'
      dependencies:
        'react-native': rnVersion
    , null, 2
    execSync 'npm i', stdio: 'ignore'

    log 'Installing Pod dependencies'
    process.chdir 'iOS'
    execSync "cp #{resources}Podfile ."
    execSync 'pod install', stdio: 'ignore'

    log 'Updating Xcode project'
    for ext in ['m', 'h']
      path = "#{projName}/AppDelegate.#{ext}"
      execSync "cp #{resources}AppDelegate.#{ext} #{path}"
      editSync path, [[projNameRx, projName], [projNameHyphRx, projNameHyph]]

    uuid1 = crypto
      .createHash 'md5'
      .update projName, 'utf8'
      .digest('hex')[...24]
      .toUpperCase()

    uuid2 = uuid1.split ''
    uuid2.splice 7, 1, ((parseInt(uuid1[7], 16) + 1) % 16).toString(16).toUpperCase()
    uuid2 = uuid2.join ''

    editSync \
      "#{projName}.xcodeproj/project.pbxproj",
      [
        [
          /OTHER_LDFLAGS = "-ObjC";/g
          'OTHER_LDFLAGS = "${inherited}";'
        ]
        [
          /\/\* End PBXBuildFile section \*\//
          "\t\t#{uuid2} /* out in Resources */ =
           {isa = PBXBuildFile; fileRef = #{uuid1} /* out */; };
           \n/* End PBXBuildFile section */"
        ]
        [
          /\/\* End PBXFileReference section \*\//
          "\t\t#{uuid1} /* out */ = {isa = PBXFileReference; lastKnownFileType
           = folder; name = out; path = ../../../target/out;
           sourceTree = \"<group>\"; };\n/* End PBXFileReference section */"
        ]
        [
          /main.jsbundle \*\/\,/
          "main.jsbundle */,\n\t\t\t\t#{uuid1} /* out */,"
        ]
        [
          /\/\* LaunchScreen.xib in Resources \*\/\,/
          "/* LaunchScreen.xib in Resources */,
           \n\t\t\t\t#{uuid2} /* out in Resources */,"
        ]
      ]

    log 'Creating Natal config'
    process.chdir '../..'
    writeConfig name: projName

    log '\nWhen Xcode appears, click the play button to run the app on the simulator.', 'yellow'
    log 'Then run the following for an interactive workflow:', 'yellow'
    log "cd #{projNameHyph}", 'inverse'
    log './start.sh', 'inverse'
    log 'First, choose the correct device (Probably [1]).', 'yellow'
    log 'At the REPL prompt type this:', 'yellow'
    log "(in-ns '#{projNameHyph}.core)", 'inverse'
    log 'Changes you make via the REPL or by changing your .cljs files should appear live.', 'yellow'
    log 'Try this command as an example:', 'yellow'
    log '(swap! app-state assoc :text "Hello Native World")', 'inverse'
    log ''
    log '✔ Done', 'bgMagenta'
    log ''

  catch {message}
    logErr \
      if message.match /type\:.+lein/i
        'Leiningen is required (http://leiningen.org/)'
      else if message.match /type\:.+pod/i
        'CocoaPods is required (https://cocoapods.org/)'
      else
        message


openXcode = (name) ->
  try
    execSync "open iOS/iOS/#{name}.xcworkspace", stdio: 'ignore'
  catch {message}
    logErr \
      if message.match /ENOENT/i
        """
        Cannot find #{name}.xcworkspace in iOS/iOS.
        Run this command from your project's root directory.
        """
      else if message.match /EACCES/i
        "Invalid permissions for opening #{name}.xcworkspace in iOS/iOS"
      else
        message


getDeviceList = ->
  try
    execSync 'xcrun instruments -s devices'
      .toString()
      .split '\n'
      .filter (line) -> /^i/.test line
  catch {message}
    logErr 'Device listing failed: ' + message


cli.version '0.0.4'

cli.command 'init <name>'
  .description 'Create a new ClojureScript React Native project'
  .action (name) ->
    if typeof name isnt 'string'
      logErr '''
             natal init requires a project name as the first argument.
             e.g.
             natal init HelloWorld
             '''

    init name

cli.command 'launch'
  .description 'Run project in simulator and start REPL'
  .action ->
    launch readConfig()

cli.command 'xcode'
  .description 'Open Xcode project'
  .action ->
    openXcode readConfig().name

cli.command 'listdevices'
  .description 'List available simulator devices by index'
  .action ->
    console.log (getDeviceList()
      .map (line, i) -> "#{i}\t#{line}"
      .join '\n')


unless semver.satisfies process.version[1...], nodeVersion
  logErr """
         Natal requires Node.js version #{nodeVersion}
         You have #{process.version[1...]}
         """

cli.parse process.argv
