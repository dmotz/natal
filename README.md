# Natal
### Bootstrap ClojureScript-based React Native apps
[Dan Motzenbecker](http://oxism.com), MIT License
[@dcmotz](https://twitter.com/dcmotz)

---

Natal is a simple command-line utility that automates most of the process of
setting up a React Native app running on ClojureScript.

It stands firmly on the shoulders of giants, specifically those of
[Mike Fikes](http://blog.fikesfarm.com) who created
[Ambly](https://github.com/omcljs/ambly) and the
[documentation](https://github.com/omcljs/ambly/wiki/ClojureScript-React-Native-Quick-Start)
on setting up a ClojureScript React Native app.


## Usage

Before getting started, make sure you have the
[required dependencies](#dependencies) installed.

Then, install the CLI using npm:

```
$ npm install -g natal
```

Then run `natal` with your app's name as the first argument:

```
$ natal FutureApp
```

If your app is more than a single word, be sure to type it in CamelCase.
A corresponding hyphenated Clojure namespace will be created.

When Xcode appears, click the play button (or ⌘-R) to run the app on the simulator.

Then run the following for an interactive workflow:

```
$ cd future-app
$ ./start.sh
```

First, choose the correct device (probably `[1]`). At the REPL prompt type this:

```clojure
(in-ns 'future-app.core)
```

Changes you make via the REPL or by changing your .cljs files should appear live.

Try this command as an example:

```clojure
(swap! app-state assoc :text "Hello Native World")
```

When the REPL starts it will print the location of its compilation log.
It's useful to tail it to see any errors, like so:

```
$ tail -f /Volumes/Ambly-81C53995/watch.log
```


## Tips
- Having `rlwrap` installed is optional but recommended since it makes the REPL
a much nicer experience with arrow keys
- Don't press ⌘-R in the simulator; code changes should be reflected automatically.
See [this issue](https://github.com/omcljs/ambly/issues/97) in Ambly for details
- Running multiple React Native apps at once can cause problems


## Dependencies
As Natal is the orchestration of many individual tools, there are quite a few dependencies.
If you've previously done React Native or Clojure development, you should hopefully
have most installed already. Platform dependencies are listed under their respective
tools.

- [npm](https://www.npmjs.com) `>=1.4`
    - [Node.js](https://nodejs.org) `>=4.0.0`
- [Leiningen](http://leiningen.org) `>=2.5.3`
    - [Java 8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
- [CocoaPods](https://cocoapods.org) `>=0.38.2`
    - [Ruby](https://www.ruby-lang.org) `>=2.0.0`
- [Xcode](https://developer.apple.com/xcode) `>=6.3`
    - [OS X](http://www.apple.com/osx) `>=10.10`
- [Watchman](https://facebook.github.io/watchman) `>=3.7.0`


## Aspirations
- [ ] Automatic wrapping of all React Native component functions for ClojureScript
- [ ] Xcode-free development with CLI tools
- [ ] Automatically run React packager in background
- [ ] Automatically tail cljs build log and report compile errors
- [ ] Templates for other ClojureScript React wrappers


Contributions are welcome.
