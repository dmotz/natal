# Natal
# Bootstrap ClojureScript React Native apps
# Dan Motzenbecker
# http://oxism.com
# MIT License

fs         = require 'fs'
crypto     = require 'crypto'
{execSync} = require 'child_process'
chalk      = require 'chalk'
semver     = require 'semver'
reactInit  = require 'react-native/local-cli/init'
rnVersion  = require(__dirname + '/package.json').dependencies['react-native']

resources       = __dirname + '/resources/'
camelRx         = /([a-z])([A-Z])/g
projNameRx      = /\$PROJECT_NAME\$/g
projNameHyphRx  = /\$PROJECT_NAME_HYPHENATED\$/g
projNameUnderRx = /\$PROJECT_NAME_UNDERSCORED\$/g
podMinVersion   = '0.36.4'


log = (s, color = 'green') ->
  console.log chalk[color] s


logErr = (err, color = 'red') ->
  console.error chalk[color] err


editSync = (path, pairs) ->
  fs.writeFileSync path, pairs.reduce (contents, [rx, replacement]) ->
    contents.replace rx, replacement
  , fs.readFileSync path, encoding: 'ascii'


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
    execSync "lein new #{projNameHyph}"

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
    execSync 'lein cljsbuild once dev'

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

    process.chdir '../..'
    openXcode projName

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

    process.exit 1


[_, _, name] = process.argv

unless name
  logErr 'You must pass a project name as the first argument.'
  logErr 'e.g. natal HelloWorld'
  process.exit 1

init name
