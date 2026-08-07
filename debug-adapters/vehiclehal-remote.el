;;; vehiclehal-remote.el --- VehicleHAL remote DAP template  -*- lexical-binding: t -*-

;; 注册 VehicleHAL 远程调试的 DAP 模板。
;; 此文件由 .dir-locals.el 自动加载，也可手动 require。

(require 'dap-mode)

(let* ((root (or (getenv "ANDROID_BUILD_TOP")
                 (locate-dominating-file default-directory ".dir-locals.el")
                 "/home/wd/data/ZXD1.1/android"))
       (sym (concat root "/out/target/product/ahx2_bsw/symbols"))
       (solib (mapconcat
               (lambda (d) (concat sym "/" d))
               '("vendor/lib64" "vendor/lib"
                 "system/lib64" "system/lib")
               ":")))

  (dap-register-debug-template
   "VehicleHAL Remote"
   (list :type "cppdbg"
         :request "attach"
         :name "VehicleHAL Remote"
         :program (concat sym "/vendor/bin/hw/vendor.zone.vehiclehal@1.0-service")
         :MIMode "gdb"
         :miDebuggerPath "gdb-multiarch"
         :miDebuggerServerAddress "localhost:5039"
         :cwd root
         :setupCommands
         (vector
          (list :text "set architecture aarch64"
                :description "Set architecture"
                :ignoreFailures nil)
          (list :text (concat "set solib-search-path " solib)
                :description "Set shared library path"
                :ignoreFailures nil)
          (list :text (concat "directory " root)
                :description "Set source directory"
                :ignoreFailures nil)
          (list :text "set scheduler-locking step"
                :description "Scheduler locking"
                :ignoreFailures nil)
          (list :text "handle SIGPIPE nostop noprint"
                :description "Ignore SIGPIPE"
                :ignoreFailures nil)))))

(provide 'vehiclehal-remote)
;;; vehiclehal-remote.el ends here
