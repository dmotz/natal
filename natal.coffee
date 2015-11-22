# Natal
# Bootstrap ClojureScript React Native apps
# Dan Motzenbecker
# http://oxism.com
# MIT License

fs      = require 'fs'
net     = require 'net'
http    = require 'http'
crypto  = require 'crypto'
child   = require 'child_process'
cli     = require 'commander'
chalk   = require 'chalk'
semver  = require 'semver'
pkgJson = require __dirname + '/package.json'

nodeVersion     = pkgJson.engines.node
resources       = __dirname + '/resources/'
validNameRx     = /^[A-Z][0-9A-Z]*$/i
camelRx         = /([a-z])([A-Z])/g
projNameRx      = /\$PROJECT_NAME\$/g
projNameHyphRx  = /\$PROJECT_NAME_HYPHENATED\$/g
rnVersion       = '0.14.2'
rnPackagerPort  = 8081
podMinVersion   = '0.38.2'
process.title   = 'natal'
reactInterfaces =
  om:        'org.omcljs/om "0.9.0"'
  'om-next': 'org.omcljs/om "1.0.0-alpha22"'

interfaceNames   = Object.keys reactInterfaces
defaultInterface = 'om'
sampleCommands   =
  om:        '(swap! app-state assoc :text "Hello Native World")'
  'om-next': '(swap! app-state assoc :app/msg "Hello Native World")'


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


getUuidForDevice = (deviceName) ->
  device = getDeviceList().find (line) -> line.match deviceName
  unless device
    logErr "Cannot find device `#{deviceName}`"

  pluckUuid device


toUnderscored = (s) ->
  s.replace(camelRx, '$1_$2').toLowerCase()


checkPort = (port, cb) ->
  sock = net.connect {port}, ->
    sock.end()
    http.get "http://localhost:#{port}/status", (res) ->
      data = ''
      res.on 'data', (chunk) -> data += chunk
      res.on 'end', ->
        cb data.toString() isnt 'packager-status:running'

    .on 'error', -> cb true
    .setTimeout 3000

  sock.on 'error', ->
    sock.end()
    cb false


ensureFreePort = (cb) ->
  checkPort rnPackagerPort, (inUse) ->
    if inUse
      logErr "
             Port #{rnPackagerPort} is currently in use by another process
             and is needed by the React Native packager.
             "
    cb()


generateConfig = (name) ->
  log 'Creating Natal config'
  config =
    name:   name
    device: getUuidForDevice 'iPhone 6s'

  writeConfig config
  config


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


init = (projName, interfaceName) ->
  if projName.toLowerCase() is 'react' or !projName.match validNameRx
    logErr 'Invalid project name. Use an alphanumeric CamelCase name.'

  projNameHyph = projName.replace(camelRx, '$1-$2').toLowerCase()
  projNameUs   = toUnderscored projName

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
    edit \
      'project.clj',
      [
        [projNameHyphRx, projNameHyph]
        [/\$REACT_INTERFACE\$/, reactInterfaces[interfaceName]]
      ]

    corePath = "src/#{projNameUs}/core.clj"
    fs.unlinkSync corePath
    corePath += 's'
    exec "cp #{resources}#{interfaceName}.cljs #{corePath}"
    edit corePath, [[projNameHyphRx, projNameHyph], [projNameRx, projName]]

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
         require('react-native/local-cli/cli').init('.', '#{projName}')\"
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

    process.chdir '../..'
    launch generateConfig projName

    log ''
    log 'To get started with your new app, first cd into its directory:', 'yellow'
    log "cd #{projNameHyph}", 'inverse'
    log ''
    log 'Boot the REPL by typing:', 'yellow'
    log 'natal repl', 'inverse'
    log ''
    log 'At the REPL prompt type this:', 'yellow'
    log "(in-ns '#{projNameHyph}.core)", 'inverse'
    log ''
    log 'Changes you make via the REPL or by changing your .cljs files should appear live.', 'yellow'
    log ''
    log 'Try this command as an example:', 'yellow'
    log sampleCommands[interfaceName], 'inverse'
    log ''
    log '✔ Done', 'bgMagenta'
    log ''

  catch {message}
    logErr \
      if message.match /type.+lein/i
        'Leiningen is required (http://leiningen.org)'
      else if message.match /type.+pod/i
        'CocoaPods is required (https://cocoapods.org)'
      else if message.match /type.+watchman/i
        'Watchman is required (https://facebook.github.io/watchman)'
      else if message.match /type.+xcodebuild/i
        'Xcode Command Line Tools are required'
      else if message.match /npm/i
        "npm install failed. This may be a network issue. Check #{projNameHyph}/native/npm-debug.log for details."
      else
        message


launch = ({name, device}) ->
  unless device in getDeviceUuids()
    log 'Device ID not available, defaulting to iPhone 6s simulator', 'yellow'
    {device} = generateConfig name

  try
    fs.statSync 'native/node_modules'
    fs.statSync 'native/ios/Pods'
  catch
    logErr 'Dependencies are missing. Run natal deps to install them.'

  log 'Compiling ClojureScript'
  exec 'lein cljsbuild once dev'

  log 'Compiling Xcode project'
  try
    exec "
         xcodebuild
         -workspace native/ios/#{name}.xcworkspace
         -scheme #{name}
         -destination platform='iOS Simulator',OS=latest,id='#{device}'
         test
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


getDeviceUuids = ->
  getDeviceList().map (line) -> line.match(/\[(.+)\]/)[1]


startRepl = (name, autoChoose) ->
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
    child.spawn (if hasRlwrap then 'rlwrap' else 'lein'),
      "#{if hasRlwrap then 'lein ' else ''}trampoline run -m clojure.main -e"
        .split(' ').concat(
          """
          (require '[cljs.repl :as repl])
          (require '[ambly.core :as ambly])
          (let [repl-env (ambly.core/repl-env#{if autoChoose then ' :choose-first-discovered true' else ''})]
          (cljs.repl/repl repl-env
            :watch \"src\"
            :watch-fn
              (fn []
                (cljs.repl/load-file repl-env
                  \"src/#{toUnderscored name}/core.cljs\"))
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
  .description 'create a new ClojureScript React Native project'
  .option "-i, --interface [#{interfaceNames.join ' '}]", 'specify React interface'
  .action (name, cmd) ->
    if cmd
      interfaceName = cmd['interface'] or defaultInterface
    else
      interfaceName = defaultInterface

    unless reactInterfaces[interfaceName]
      logErr "Unsupported React interface: #{interfaceName}"

    if typeof name isnt 'string'
      logErr '''
             natal init requires a project name as the first argument.
             e.g.
             natal init HelloWorld
             '''

    ensureFreePort -> init name, interfaceName


cli.command 'launch'
  .description 'compile project and run in simulator'
  .action ->
    ensureFreePort -> launch readConfig()


cli.command 'repl'
  .description 'launch a ClojureScript REPL with background compilation'
  .option '-c, --choose', 'choose target device from list'
  .action (cmd) ->
    startRepl readConfig().name, !cmd.choose


cli.command 'listdevices'
  .description 'list available simulator devices by index'
  .action ->
    console.log (getDeviceList()
      .map (line, i) -> "#{i}\t#{line.replace /\[.+\]/, ''}"
      .join '\n')


cli.command 'setdevice <index>'
  .description 'choose simulator device by index'
  .action (index) ->
    unless device = getDeviceList()[parseInt index, 10]
      logErr 'Invalid device index. Run natal listdevices for valid indexes.'

    config = readConfig()
    config.device = pluckUuid device
    writeConfig config


cli.command 'xcode'
  .description 'open Xcode project'
  .action ->
    openXcode readConfig().name


cli.command 'deps'
  .description 'install all dependencies for the project'
  .action ->
    try
      log 'Installing Leiningen jars'
      exec 'lein deps'
      process.chdir 'native'
      log 'Installing npm packages'
      exec 'npm i'
      log 'Installing pods'
      process.chdir 'ios'
      exec 'pod install'
    catch {message}
      logErr message


cli.on '*', (command) ->
  logErr "unknown command #{command[0]}. See natal --help for valid commands"


unless semver.satisfies process.version[1...], nodeVersion
  logErr """
         Natal requires Node.js version #{nodeVersion}
         You have #{process.version[1...]}
         """

if process.argv.length <= 2
  cli.outputHelp()
else
  cli.parse process.argv
