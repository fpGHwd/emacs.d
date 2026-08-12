;;; android-dape.el --- Dape configuration for Android remote debugging  -*- lexical-binding: t -*-

;; Dape configuration for SA8155P Android remote debugging.
;;
;; Usage:
;;   M-x dape RET vehiclehal-remote RET
;;
;; Prerequisites before starting dape:
;;   1. adb root
;;   2. PID=$(adb shell pidof vendor.zone.vehiclehal@1.0-service)
;;   3. adb shell "pkill -9 gdbserver64; nohup gdbserver64 :5039 --attach $PID &"
;;   4. adb forward tcp:5039 tcp:5039

(require 'dape)

(let* ((root (or (getenv "ANDROID_BUILD_TOP")
                 "/home/wd/data/ZXD1.1/android"))
       (sym (concat root "/out/target/product/ahx2_bsw/symbols"))
       (solib (mapconcat
               (lambda (d) (concat sym "/" d))
               '("vendor/lib64" "vendor/lib"
                 "system/lib64" "system/lib")
               ":"))
       (cpptools "/home/wd/.config/emacs.d/debug-adapters/cpptools-wrapper.sh"))

  (add-to-list 'dape-configs
    `(vehiclehal-remote
      modes (c-mode c++-mode)
      ensure dape-ensure-command
      command-cwd ,root
      command ,cpptools
      fn
      (lambda (config)
        (let ((program (plist-get config :program)))
          (if (file-name-absolute-p program) config
            (thread-last
              (tramp-file-local-name (dape--guess-root config))
              (expand-file-name program) (plist-put config :program)))))
      :type "cppdbg"
      :request "launch"
      :MIMode "gdb"
      :miDebuggerPath "gdb-multiarch"
      :miDebuggerServerAddress "localhost:5039"
      :program ,(concat sym "/vendor/bin/hw/vendor.zone.vehiclehal@1.0-service")
      :cwd ,root
      :setupCommands
      [(:text "set architecture aarch64"
               :description "Set architecture"
               :ignoreFailures nil)
       (:text ,(concat "set solib-search-path " solib)
               :description "Set shared library path"
               :ignoreFailures nil)
       (:text ,(concat "directory " root)
               :description "Set source directory"
               :ignoreFailures nil)
       (:text "handle SIGPIPE nostop noprint"
               :description "Ignore SIGPIPE"
               :ignoreFailures nil)])))

(provide 'android-dape)
;;; android-dape.el ends here
