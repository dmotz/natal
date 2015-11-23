(ns $PROJECT_NAME_HYPHENATED$.core
  (:require [om.core :as om])
  (:require-macros [natal-shell.components :refer [view text image touchable-highlight]]
                   [natal-shell.alert-ios :refer [alert]]))

(set! js/React (js/require "react-native/Libraries/react-native/react-native.js"))

(defonce app-state (atom {:text "Welcome to $PROJECT_NAME$"}))

(defn widget [data owner]
  (reify
    om/IRender
    (render [this]
      (view {:style {:flexDirection "column" :margin 40 :alignItems "center"}}
        (text
          {:style {:fontSize 50 :fontWeight "100" :marginBottom 20 :textAlign "center"}}
          (:text data))

        (image {:source {:uri "https://raw.githubusercontent.com/cljsinfo/logo.cljs/master/cljs.png"}
                :style {:width 80 :height 80 :marginBottom 30}})

        (touchable-highlight
          {:style {:backgroundColor "#999" :padding 10 :borderRadius 5}
           :onPress #(alert "HELLO!")}
          (text {:style {:color "white" :textAlign "center" :fontWeight "bold"}} "press me"))))))

(om/root widget app-state {:target 1})

(defn ^:export init []
  ((fn render []
     (.requestAnimationFrame js/window render))))
