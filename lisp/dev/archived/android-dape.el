;;; android-dape.el --- Dape + GDB DAP for Android remote debugging  -*- lexical-binding: t -*-

;; Attempt to use nix gdb 17.2 with --interpreter=dap for Android remote debugging.
;;
;; ⚠️ 已知限制：GDB DAP 的 :request "launch" 会尝试本地执行 :program，
;;    aarch64 二进制在 x86_64 主机上会报 "Exec format error"。
;;    :request "attach" 只支持本地 PID，无法连接远程 gdbserver。
;;    这是 DAP 协议语义限制，非配置可绕。
;;
;; 当前保留此文件用于实验，推荐日常使用 8155-debug.el (GUD)。

(require 'dape)

(let* ((root (or (getenv "ANDROID_BUILD_TOP")
                 "/home/wd/data/ZXD1.1/android"))
       (sym (concat root "/out/target/product/ahx2_bsw/symbols"))
       (solib (mapconcat
               (lambda (d) (concat sym "/" d))
               '("vendor/lib64" "vendor/lib"
                 "system/lib64" "system/lib")
               ":"))
       ;; nix gdb 17.2 支持 --interpreter=dap
       (nix-gdb "/nix/store/fq5hd83bkipznh5n0m3zxcs4gk6hcbjc-gdb-17.2/bin/gdb"))

  (add-to-list 'dape-configs
    `(vehiclehal-remote-gdb
      modes (c-mode c++-mode)
      ensure dape-ensure-command
      command-cwd ,root
      command ,nix-gdb
      command-args ("--interpreter=dap")
      :request "launch"
      :program ,(concat sym "/vendor/bin/hw/vendor.zone.vehiclehal@1.0-service")
      :cwd ,root
      :args []
      :stopAtBeginningOfMainSubprogram nil
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
       (:text "set scheduler-locking step"
               :description "Scheduler locking"
               :ignoreFailures nil)
       (:text "handle SIGPIPE nostop noprint"
               :description "Ignore SIGPIPE"
               :ignoreFailures nil)])))

(provide 'android-dape)
;;; android-dape.el ends here
