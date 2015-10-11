# Natal
# Bootstrap ClojureScript React Native apps
# Dan Motzenbecker
# http://oxism.com
# MIT License

fs      = require 'fs'
crypto  = require 'crypto'
child   = require 'child_process'
cli     = require 'commander'
chalk   = require 'chalk'
semver  = require 'semver'
pkgJson = require __dirname + '/package.json'

nodeVersion     = pkgJson.engines.node
resources       = __dirname + '/resources/'
camelRx         = /([a-z])([A-Z])/g
projNameRx      = /\$PROJECT_NAME\$/g
projNameHyphRx  = /\$PROJECT_NAME_HYPHENATED\$/g
projNameUnderRx = /\$PROJECT_NAME_UNDERSCORED\$/g
rnVersion       = '0.12.0'
podMinVersion   = '0.38.2'
process.title   = 'natal'


log = (s, color = 'green') ->
  console.log chalk[color] s


logErr = (err, color = 'red') ->
  console.error chalk[color] err
  process.exit 1


exec = (cmd, keepOutput) ->
  if keepOutput
    child.execSync cmd
  else
    child.execSync cmd, stdio: 'ignore'


readFile = (path) ->
  fs.readFileSync path, encoding: 'ascii'


edit = (path, pairs) ->
  fs.writeFileSync path, pairs.reduce (contents, [rx, replacement]) ->
    contents.replace rx, replacement
  , readFile path


pluckUuid = (line) ->
  line.match(/\[(.+)\]/)[1]


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
    JSON.parse readFile '.natal'
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


getBundleId = (name) ->
  try
    if line = readFile "native/ios/#{name}.xcodeproj/project.pbxproj"
         .match /PRODUCT_BUNDLE_IDENTIFIER = (.+);/

      line[1]

    else if line = readFile "native/ios/#{name}/Info.plist"
              .match /\<key\>CFBundleIdentifier\<\/key\>\n?\s*\<string\>(.+)\<\/string\>/

      rfcIdRx = /\$\(PRODUCT_NAME\:rfc1034identifier\)/

      if line[1].match rfcIdRx
        line[1].replace rfcIdRx, name
      else
        line[1]

    else
      throw new Error 'Cannot find bundle identifier in project.pbxproj or Info.plist'

  catch {message}
    logErr message


init = (projName) ->
  projNameHyph = projName.replace(camelRx, '$1-$2').toLowerCase()
  projNameUs   = projName.replace(camelRx, '$1_$2').toLowerCase()

  try
    log "Creating #{projName}", 'bgMagenta'
    log ''

    if fs.existsSync projNameHyph
      throw new Error "Directory #{projNameHyph} already exists"

    exec 'type lein'
    exec 'type pod'
    exec 'type watchman'
    exec 'type xcodebuild'

    podVersion = exec('pod --version', true).toString().trim()
    unless semver.satisfies podVersion, ">=#{podMinVersion}"
      throw new Error """
                      Natal requires CocoaPods #{podMinVersion} or higher (you have #{podVersion}).
                      Run [sudo] gem update cocoapods and try again.
                      """

    log 'Creating Leiningen project'
    exec "lein new #{projNameHyph}"

    log 'Updating Leiningen project'
    process.chdir projNameHyph
    exec "cp #{resources}project.clj project.clj"
    edit 'project.clj', [[projNameHyphRx, projNameHyph]]
    corePath = "src/#{projNameUs}/core.clj"
    fs.unlinkSync corePath
    corePath += 's'
    exec "cp #{resources}core.cljs #{corePath}"
    edit corePath, [[projNameHyphRx, projNameHyph], [projNameRx, projName]]

    log 'Compiling ClojureScript'
    exec 'lein cljsbuild once dev'

    log 'Creating React Native skeleton'
    fs.mkdirSync 'native'
    process.chdir 'native'

    fs.writeFileSync 'package.json', JSON.stringify
      name:    projName
      version: '0.0.1'
      private: true
      scripts:
        start: 'node_modules/react-native/packager/packager.sh'
      dependencies:
        'react-native': rnVersion
    , null, 2

    exec 'npm i'
    exec "
         node -e
         \"process.argv[3]='#{projName}';
         require('react-native/local-cli/init')('.', '#{projName}')\"
         "

    exec 'rm -rf android'
    fs.unlinkSync 'index.android.js'

    log 'Installing Pod dependencies'
    process.chdir 'ios'
    exec "cp #{resources}Podfile ."
    exec 'pod install'

    log 'Updating Xcode project'
    for ext in ['m', 'h']
      path = "#{projName}/AppDelegate.#{ext}"
      exec "cp #{resources}AppDelegate.#{ext} #{path}"
      edit path, [[projNameRx, projName], [projNameHyphRx, projNameHyph]]

    uuid1 = crypto
      .createHash 'md5'
      .update projName, 'utf8'
      .digest('hex')[...24]
      .toUpperCase()

    uuid2 = uuid1.split ''
    uuid2.splice 7, 1, ((parseInt(uuid1[7], 16) + 1) % 16).toString(16).toUpperCase()
    uuid2 = uuid2.join ''

    edit \
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
           = folder; name = out; path = ../../target/out;
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

    testId = readFile("#{projName}.xcodeproj/project.pbxproj")
      .match(new RegExp "([0-9A-F]+) \/\\* #{projName}Tests \\*\/ = \\{")[1]

    edit \
      "#{projName}.xcodeproj/xcshareddata/xcschemes/#{projName}.xcscheme",
      [
        [
          /\<Testables\>\n\s*\<\/Testables\>/
          """
          <Testables>
             <TestableReference
                skipped = "NO">
                <BuildableReference
                   BuildableIdentifier = "primary"
                   BlueprintIdentifier = "#{testId}"
                   BuildableName = "#{projName}Tests.xctest"
                   BlueprintName = "#{projName}Tests"
                   ReferencedContainer = "container:#{projName}.xcodeproj">
                </BuildableReference>
             </TestableReference>
          </Testables>
          """
        ]
      ]

    log 'Creating Natal config'
    process.chdir '../..'
    config =
      name:   projName
      device: pluckUuid getDeviceList().find (line) -> /iPhone 6/.test line

    writeConfig config
    launch config

    log ''
    log 'To get started with your new app, first cd into its directory:', 'yellow'
    log "cd #{projNameHyph}", 'inverse'
    log ''
    log 'Boot the REPL by typing:', 'yellow'
    log 'natal repl', 'inverse'
    log 'Then choose the correct device to connect to (probably 1).', 'yellow'
    log ''
    log 'At the REPL prompt type this:', 'yellow'
    log "(in-ns '#{projNameHyph}.core)", 'inverse'
    log ''
    log 'Changes you make via the REPL or by changing your .cljs files should appear live.', 'yellow'
    log ''
    log 'Try this command as an example:', 'yellow'
    log '(swap! app-state assoc :text "Hello Native World")', 'inverse'
    log ''
    log '✔ Done', 'bgMagenta'
    log ''

  catch {message}
    logErr \
      if message.match /type\:.+lein/i
        'Leiningen is required (http://leiningen.org)'
      else if message.match /type\:.+pod/i
        'CocoaPods is required (https://cocoapods.org)'
      else if message.match /type\:.+watchman/i
        'Watchman is required (https://facebook.github.io/watchman)'
      else if message.match /type\:.+xcodebuild/i
        'Xcode Command Line Tools are required'
      else
        message


launch = ({name, device}) ->
  log 'Compiling Xcode project'
  try
    exec "
         xcodebuild
         -workspace native/ios/#{name}.xcworkspace
         -scheme #{name}
         -destination platform='iOS Simulator',OS=latest,id='#{device}'
         clean test
         "

    log 'Launching simulator'
    exec "xcrun simctl launch #{device} #{getBundleId name}"

  catch {message}
    logErr message


openXcode = (name) ->
  try
    exec "open native/ios/#{name}.xcworkspace"
  catch {message}
    logErr \
      if message.match /ENOENT/i
        """
        Cannot find #{name}.xcworkspace in native/ios.
        Run this command from your project's root directory.
        """
      else if message.match /EACCES/i
        "Invalid permissions for opening #{name}.xcworkspace in native/ios"
      else
        message


getDeviceList = ->
  try
    exec 'xcrun instruments -s devices', true
      .toString()
      .split '\n'
      .filter (line) -> /^i/.test line
  catch {message}
    logErr 'Device listing failed: ' + message


startRepl = (name) ->
  log 'Starting REPL'
  hasRlwrap =
    try
      exec 'type rlwrap'
      true
    catch
      log '
          Warning: rlwrap is not installed.\nInstall it to make the REPL a much
          better experience with arrow key support.
          ', 'red'
      false

  try
    lein = child.spawn (if hasRlwrap then 'rlwrap' else 'lein'),
      "#{if hasRlwrap then 'lein ' else ''}trampoline run -m clojure.main -e"
        .split(' ').concat(
          """
          (require '[cljs.repl :as repl])
          (require '[ambly.core :as ambly])
          (let [repl-env (ambly.core/repl-env)]
          (cljs.repl/repl repl-env
            :watch \"src\"
            :watch-fn
              (fn []
                (cljs.repl/load-file repl-env
                  \"src/#{name}/core.cljs\"))
            :analyze-path \"src\"))
          """),
      cwd:   process.cwd()
      env:   process.env
      stdio: 'inherit'

  catch {message}
    logErr message


cli._name = 'natal'
cli.version pkgJson.version

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
  .description 'Compile project and run in simulator'
  .action ->
    launch readConfig()


cli.command 'repl'
  .description 'Launch a ClojureScript REPL with background compilation'
  .action ->
    startRepl readConfig().name


cli.command 'listdevices'
  .description 'List available simulator devices by index'
  .action ->
    console.log (getDeviceList()
      .map (line, i) -> "#{i}\t#{line.replace /\[.+\]/, ''}"
      .join '\n')


cli.command 'setdevice <index>'
  .description 'Choose simulator device by index'
  .action (index) ->
    unless device = getDeviceList()[parseInt index, 10]
      logErr 'Invalid device index. Run natal listdevices for valid indexes.'

    config = readConfig()
    config.device = pluckUuid device
    writeConfig config


cli.command 'xcode'
  .description 'Open Xcode project'
  .action ->
    openXcode readConfig().name


cli.on '*', (command) ->
  logErr "Unknown command #{command[0]}. See natal --help for valid commands"


unless semver.satisfies process.version[1...], nodeVersion
  logErr """
         Natal requires Node.js version #{nodeVersion}
         You have #{process.version[1...]}
         """

if process.argv.length <= 2
  cli.outputHelp()
else
  cli.parse process.argv
