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
[documentation](http://cljsrn.org/ambly.html)
on setting up a ClojureScript React Native app.


## Usage

Before getting started, make sure you have the
[required dependencies](#dependencies) installed.

Then, install the CLI using npm:

```
$ npm install -g natal
```

To bootstrap a new app, run `natal init` with your app's name as an argument:

```
$ natal init FutureApp
```

If your app's name is more than a single word, be sure to type it in CamelCase.
A corresponding hyphenated Clojure namespace will be created.

By default Natal will create a simple skeleton based on the current stable
version of [Om](http://omcljs.org) (aka Om Now). If you'd like to base your app
upon Om Next, you can specify a React interface template during init:

```
$ natal init FutureApp --interface om-next
```

Keep in mind your app isn't limited to the React interfaces Natal provides
templates for; these are just for convenience.

If all goes well your app should compile and boot in the simulator.

From there you can begin an interactive workflow by starting the REPL.

```
$ cd future-app
$ natal repl
```

If there are no issues, the REPL should connect to the simulator automatically.
To manually choose which device it connects to, you can run `natal repl --choose`.

At the prompt, try loading your app's namespace:

```clojure
(in-ns 'future-app.core)
```

Changes you make via the REPL or by changing your `.cljs` files should appear live
in the simulator.

Try this command as an example:

```clojure
(swap! app-state assoc :text "Hello Native World")
```

When the REPL connects to the simulator it will print the location of its
compilation log. It's useful to tail it to see any errors, like so:

```
$ tail -f /Volumes/Ambly-81C53995/watch.log
```


## Tips
- Having `rlwrap` installed is optional but highly recommended since it makes
the REPL a much nicer experience with arrow keys.

- Don't press ⌘-R in the simulator; code changes should be reflected automatically.
See [this issue](https://github.com/omcljs/ambly/issues/97) in Ambly for details.

- Running multiple React Native apps at once can cause problems with the React
Packager so try to avoid doing so.

- You can launch your app on the simulator without opening Xcode by running
`natal launch` in your app's root directory.

- By default new Natal projects will launch on the iPhone 6 simulator. To change
which device `natal launch` uses, you can run `natal listdevices` to see a list
of available simulators, then select one by running `natal setdevice` with the
index of the device on the list.

- To change advanced settings run `natal xcode` to quickly open the Xcode project.

- The Xcode-free workflow is for convenience. If you're encountering app crashes,
you should open the Xcode project and run it from there to view errors.


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
- [Xcode](https://developer.apple.com/xcode) (+ Command Line Tools) `>=6.3`
    - [OS X](http://www.apple.com/osx) `>=10.10`
- [Watchman](https://facebook.github.io/watchman) `>=3.7.0`


## Updating Natal
You can get the latest version of Natal by running `npm up -g natal`.


## Aspirations
- [x] Xcode-free workflow with CLI tools
- [x] Templates for other ClojureScript React wrappers
- [x] Automatic wrapping of all React Native component functions for ClojureScript
- [ ] Automatically run React packager in background
- [ ] Automatically tail cljs build log and report compile errors
- [ ] Working dev tools
- [ ] Automatic bundling for offline device usage and App Store distribution
- [ ] Android support


## Example apps bootstrapped with Natal
- [Om Next app with Python server](https://github.com/dvcrn/om-react-native-demo)
  by David Mohl, demonstrated in
  [a talk at the Tokyo iOS Meetup](https://www.youtube.com/watch?v=oJ8t8Hc9XaE).

- [Zooborns](https://github.com/iamjarvo/zooborns)
  by Jearvon Dharrie, demonstrated in
  [a talk at Clojure/conj 2015](https://www.youtube.com/watch?v=GDA-g6Ca_dQ).


## Coda
Contributions are welcome.

For more ClojureScript React Native resources visit [cljsrn.org](http://cljsrn.org).

If you're looking for a simple ClojureScript wrapper around the React Native API,
check out the companion library [Natal Shell](https://github.com/dmotz/natal-shell).
It is included by default in projects generated by Natal.
