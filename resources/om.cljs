;; Need to set js/React first so that Om can load
(set! js/React (js/require "react-native/Libraries/react-native/react-native.js"))

(ns $PROJECT_NAME_HYPHENATED$.core
  (:require [om.core :as om]))

;; Reset js/React back as the form above loads in a different React
(set! js/React (js/require "react-native/Libraries/react-native/react-native.js"))


;; Set up some methods to help create React Native elements
(defn view [opts & children]
  (apply js/React.createElement js/React.View (clj->js opts) children))

(defn text [opts & children]
  (apply js/React.createElement js/React.Text (clj->js opts) children))


;; Set up our Om UI
(defonce app-state (atom {:text "Welcome to $PROJECT_NAME$"}))

(defn widget [data owner]
  (reify
    om/IRender
    (render [this]
      (view {:style {:flexDirection "column" :margin 40}}
        (text {:style {:fontSize 50 :fontWeight "100"}} (:text data))))))

(om/root widget app-state {:target 1})

(defn ^:export init []
  ((fn render []
     (.requestAnimationFrame js/window render))))
