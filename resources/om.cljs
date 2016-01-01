(ns $PROJECT_NAME_HYPHENATED$.core
  (:require-macros [natal-shell.core :refer [with-error-view]]
                   [natal-shell.components :refer [view text image touchable-highlight]]
                   [natal-shell.alert :refer [alert]])
  (:require [om.core :as om]))

(set! js/React (js/require "react-native/Libraries/react-native/react-native.js"))

(defonce app-state (atom {:text "Welcome to $PROJECT_NAME$"}))

(defn main-view [data owner]
  (reify
    om/IRender
    (render [this]
      (with-error-view
        (view
          {:style
            {:flexDirection "column" :margin 40 :alignItems "center"}}
          (text
            {:style
              {:fontSize 50 :fontWeight "100" :marginBottom 20 :textAlign "center"}}
            (:text data))

          (image
            {:source
              {:uri "https://raw.githubusercontent.com/cljsinfo/logo.cljs/master/cljs.png"}
             :style {:width 80 :height 80 :marginBottom 30}})

          (touchable-highlight
            {:style {:backgroundColor "#999" :padding 10 :borderRadius 5}
             :onPress #(alert "HELLO!")}

            (text
              {:style {:color "white" :textAlign "center" :fontWeight "bold"}}
              "press me")))))))


(om/root main-view app-state {:target 1})
