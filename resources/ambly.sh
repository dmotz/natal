#!/bin/bash

if hash rlwrap 2>/dev/null; then
    COMMAND="rlwrap lein"
else
    COMMAND="lein"
fi

$COMMAND trampoline run -m clojure.main -e \
"(require '[cljs.repl :as repl])
(require '[ambly.core :as ambly])
(let [repl-env (ambly.core/repl-env)]
  (cljs.repl/repl repl-env
    :watch \"src\"
    :watch-fn
      (fn []
        (cljs.repl/load-file repl-env
          \"src/$PROJECT_NAME_UNDERSCORED$/core.cljs\"))
    :analyze-path \"src\"))"
