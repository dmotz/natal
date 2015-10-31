;; Need to set js/React first so that Om can load
(set! js/React (js/require "react-native/Libraries/react-native/react-native.js"))

(ns $PROJECT_NAME_HYPHENATED$.core
  (:require [om.next :as om :refer-macros [defui]]))

;; Reset js/React back as the form above loads in an different React
(set! js/React (js/require "react-native/Libraries/react-native/react-native.js"))


;; Setup some methods to help create React Native elements
(defn view [opts & children]
  (apply js/React.createElement js/React.View (clj->js opts) children))

(defn text [opts & children]
  (apply js/React.createElement js/React.Text (clj->js opts) children))


;; Set up our Om UI
(defonce app-state (atom {:app/msg "Welcome to $PROJECT_NAME$"}))

(defui WidgetComponent
  static om/IQuery
  (query [this]
         '[:app/msg])
  Object
  (render [this]
          (let [{:keys [app/msg]} (om/props this)]
            (view {:style {:flexDirection "column" :margin 40}}
                  (text nil msg)))))

;; om.next parser
(defmulti read om/dispatch)
(defmethod read :default
  [{:keys [state]} k _]
  (let [st @state]
    (find st k)
    (if-let [[_ v] (find st k)]
      {:value v}
      {:value :not-found})))

(def reconciler
  (om/reconciler
   {:state app-state
    :parser (om/parser {:read read})
    :root-render #(.render js/React %1 %2)
    :root-unmount #(.unmountComponentAtNode js/React %)}))

(om/add-root! reconciler WidgetComponent 1)

(defn ^:export init []
  ((fn render []
     (.requestAnimationFrame js/window render))))
