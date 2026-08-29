;;; 8155-debug.el --- One-stop debugging workflow for SA8155P platform  -*- lexical-binding: t -*-

;; Copyright (C) 2026
;; Author: CodeBuddy
;; Keywords: tools, debugging, android, gdb

;;; Commentary:

;; This package provides a streamlined debugging workflow for the SA8155P
;; platform within Emacs.  It covers:
;;
;;   - Compiling a single Android module via `mmm' in Docker
;;   - Pushing compiled artifacts to the device via `adb push'
;;   - One-click launch of full remote GDB debugging chain
;;   - Smart GUD buffer management and command helpers
;;   - Integrated `adb logcat' viewer
;;
;; Usage:
;;   (require '8155-debug)
;;   ;; Compile current module: C-c c
;;   ;; Start debugging: M-x 8155-gdb-debug RET
;;   ;; Toggle breakpoint at cursor: C-c C-b (in GUD)

;;; Code:

(require 'compile)
(require 'dired)

;; ---------------------------------------------------------------------------
;; User-configurable variables
;; ---------------------------------------------------------------------------

(defgroup 8155-debug nil
  "SA8155P platform debugging workflow."
  :group 'tools)

(defcustom 8155-debug-android-root "/home/wd/data/ZXD1.1/android"
  "Path to the Android source tree root."
  :type 'string
  :group '8155-debug)

(defcustom 8155-debug-product "ahx2_bsw"
  "Target product name (e.g. ahx2_bsw, zxd11p_anbeil)."
  :type 'string
  :group '8155-debug)

(defcustom 8155-debug-docker-container "b37cfa492efc"
  "Docker container ID for Android compilation."
  :type 'string
  :group '8155-debug)

(defcustom 8155-debug-lunch-target "ahx2_bsw-userdebug"
  "Lunch target for the build system."
  :type 'string
  :group '8155-debug)

(defcustom 8155-debug-gdb-port "5039"
  "TCP port used by gdbserver64 and adb forward."
  :type 'string
  :group '8155-debug)

;; ---------------------------------------------------------------------------
;; Derived paths
;; ---------------------------------------------------------------------------

(defun 8155-debug--sym-base ()
  "Return the path to the symbols directory."
  (format "%s/out/target/product/%s/symbols"
          8155-debug-android-root 8155-debug-product))

(defun 8155-debug--out-dir ()
  "Return the path to the build output directory."
  (format "%s/out/target/product/%s"
          8155-debug-android-root 8155-debug-product))

;; ---------------------------------------------------------------------------
;; 1. Compilation
;; ---------------------------------------------------------------------------

;;;###autoload
(defun 8155-compile-module ()
  "Compile the current buffer's module via `mmm' inside Docker.
Runs `mmm' on the directory containing the current file."
  (interactive)
  (let* ((file (or (buffer-file-name)
                   (user-error "Buffer is not visiting a file")))
         (rel-path (file-relative-name (file-name-directory file)
                                       8155-debug-android-root)))
    (compile
     (format "docker exec -i %s /bin/bash -c 'cd %s && source build/envsetup.sh && lunch %s && mmm %s'"
             8155-debug-docker-container
             8155-debug-android-root
             8155-debug-lunch-target
             rel-path))))

;;;###autoload
(defun 8155-compile-current-file ()
  "Compile the file corresponding to the current buffer.
Derives the module path from the buffer's file name."
  (interactive)
  (8155-compile-module))

;; ---------------------------------------------------------------------------
;; 2. File push (Dired integration)
;; ---------------------------------------------------------------------------

;;;###autoload
(defun 8155-dired-adb-push (target-dir)
  "Push marked files in Dired to the device at TARGET-DIR.
Prompts for the target directory on the device."
  (interactive
   (list (read-string "Target dir on device: " "/data/local/tmp/")))
  (let ((files (dired-get-marked-files)))
    (unless files
      (user-error "No files marked in Dired"))
    (dolist (f files)
      (let ((target (concat (file-name-as-directory target-dir)
                            (file-name-nondirectory f))))
        (message "Pushing %s -> %s" f target)
        (start-process (format "adb-push-%s" (file-name-nondirectory f))
                       "*adb-push*"
                       "adb" "push" f target)))))

;;;###autoload
(defun 8155-dired-adb-push-nativetest ()
  "Push marked files to /data/local/tmp/ on the device."
  (interactive)
  (8155-dired-adb-push "/data/local/tmp/"))

;; ---------------------------------------------------------------------------
;; 3. One-click remote GDB debugging
;; ---------------------------------------------------------------------------

;;;###autoload
(defun 8155-gdb-debug (process-name)
  "One-click start remote GDB debugging for PROCESS-NAME.
PROCESS-NAME can be:
  - A running process name (e.g. \"vendor.zone.vehiclehal@1.0-service\")
  - A nativetest path (e.g. \"systemaudio_tests\")
  - A full path on the device (e.g. \"/data/local/tmp/tests/systemaudio_tests\")

This function performs all setup steps automatically:
  1. Check ADB connection
  2. Find process PID (if attach mode)
  3. Kill old gdbserver64
  4. Start new gdbserver64
  5. Set up adb port forward
  6. Launch Emacs GUD with proper symbol paths"
  (interactive "sProcess name or test path: ")
  (let* ((sym-base (8155-debug--sym-base))
         (src-root 8155-debug-android-root)
         ;; Determine symbol file path
         (sym-file
          (cond
           ;; 1. vendor HAL service
           ((file-exists-p (format "%s/vendor/bin/hw/%s" sym-base process-name))
            (format "%s/vendor/bin/hw/%s" sym-base process-name))
           ;; 2. system binary
           ((file-exists-p (format "%s/system/bin/%s" sym-base process-name))
            (format "%s/system/bin/%s" sym-base process-name))
           ;; 3. nativetest64
           ((file-exists-p (format "%s/data/nativetest64/%s/%s"
                                   sym-base process-name process-name))
            (format "%s/data/nativetest64/%s/%s"
                    sym-base process-name process-name))
           ;; 4. nativetest (32-bit)
           ((file-exists-p (format "%s/data/nativetest/%s/%s"
                                   sym-base process-name process-name))
            (format "%s/data/nativetest/%s/%s"
                    sym-base process-name process-name))
           ;; 5. Full device path given - extract basename and search
           ((string-prefix-p "/" process-name)
            (let ((base (file-name-nondirectory process-name)))
              (or (8155-debug--find-symbol-file base sym-base)
                  (user-error "Cannot find symbol file for: %s" process-name))))
           (t (or (8155-debug--find-symbol-file process-name sym-base)
                  (user-error "Cannot find symbol file for: %s" process-name))))))

    ;; Step 1: Check ADB connection
    (message "[1/5] Checking ADB connection...")
    (unless (zerop (call-process "adb" nil nil nil "devices"))
      (user-error "ADB not available"))
    
    ;; Step 2-4: Handle gdbserver64
    (message "[2/5] Setting up gdbserver64...")
    (let* ((is-attach (not (string-prefix-p "/" process-name)))
           (pid (when is-attach
                  (string-trim
                   (with-output-to-string
                     (call-process "adb" nil standard-output nil
                                   "shell" "pidof" process-name))))))
      
      ;; Kill old gdbserver64
      (call-process "adb" nil nil nil
                    "shell" "pkill -9 gdbserver64 2>/dev/null; true")
      (sleep-for 0.5)
      
      ;; Start new gdbserver64
      (if (and is-attach (> (length pid) 0))
          (progn
            (message "[3/5] Attaching to %s (PID: %s)..." process-name pid)
            (call-process "adb" nil nil nil "shell"
                          (format "nohup gdbserver64 :%s --attach %s > /dev/null 2>&1 &"
                                  8155-debug-gdb-port pid)))
        (message "[3/5] Starting gdbserver64 with %s..." process-name)
        (call-process "adb" nil nil nil "shell"
                      (format "nohup gdbserver64 :%s %s > /dev/null 2>&1 &"
                              8155-debug-gdb-port process-name))))
    
    ;; Step 5: Port forward
    (message "[4/5] Setting up port forward...")
    (call-process "adb" nil nil nil
                  "forward" (format "tcp:%s" 8155-debug-gdb-port)
                  (format "tcp:%s" 8155-debug-gdb-port))
    (sleep-for 1)
    
    ;; Step 6: Launch GUD
    (message "[5/5] Launching GDB...")
    (let ((gdb-cmd
           (format "gdb-multiarch -i=mi \
-ex \"set architecture aarch64\" \
-ex \"file %s\" \
-ex \"set solib-search-path %s/vendor/lib64:%s/vendor/lib:%s/system/lib64:%s/system/lib\" \
-ex \"directory %s\" \
-ex \"target remote localhost:%s\""
                   sym-file
                   sym-base sym-base sym-base sym-base
                   src-root
                   8155-debug-gdb-port)))
      (gdb gdb-cmd))
    
    (message "GDB debugging started for: %s" process-name)))

(defun 8155-debug--find-symbol-file (base-name sym-base)
  "Search for BASE-NAME symbol file under SYM-BASE.
Returns the first match found, or nil."
  (let ((candidates
         (list (format "%s/vendor/bin/hw/%s" sym-base base-name)
               (format "%s/system/bin/%s" sym-base base-name)
               (format "%s/data/nativetest64/%s/%s" sym-base base-name base-name)
               (format "%s/data/nativetest/%s/%s" sym-base base-name base-name))))
    (cl-find-if #'file-exists-p candidates)))

;; ---------------------------------------------------------------------------
;; 4. GUD helpers
;; ---------------------------------------------------------------------------

(defun 8155-gud-buffer ()
  "Find and return the current GUD buffer.
Raises an error if no GUD buffer exists."
  (or (seq-find (lambda (b) (string-match-p "gud" (buffer-name b)))
                (buffer-list))
      (user-error "GUD buffer not found.  Did you start GDB?")))

(defun 8155-gud-cmd (cmd)
  "Send CMD to the GUD buffer as if typed interactively."
  (with-current-buffer (8155-gud-buffer)
    (goto-char (point-max))
    (insert cmd)
    (comint-send-input)))

;;;###autoload
(defun 8155-gud-continue ()
  "Send `continue' to the GUD buffer."
  (interactive)
  (8155-gud-cmd "continue"))

;;;###autoload
(defun 8155-gud-next ()
  "Send `next' to the GUD buffer."
  (interactive)
  (8155-gud-cmd "next"))

;;;###autoload
(defun 8155-gud-step ()
  "Send `step' to the GUD buffer."
  (interactive)
  (8155-gud-cmd "step"))

;;;###autoload
(defun 8155-gud-break-here ()
  "Set a breakpoint at the current cursor position in source code.
Automatically sends `break file:line' to GUD."
  (interactive)
  (let ((file (file-name-nondirectory (buffer-file-name)))
        (line (line-number-at-pos)))
    (8155-gud-cmd (format "break %s:%d" file line))
    (message "Breakpoint set: %s:%d" file line)))

;;;###autoload
(defun 8155-gud-print-var (var-name)
  "Print the value of VAR-NAME in the GUD session.
When called interactively, defaults to the symbol at point."
  (interactive
   (list (read-string "Variable: " (thing-at-point 'symbol t))))
  (8155-gud-cmd (format "print %s" var-name)))

;;;###autoload
(defun 8155-gud-backtrace ()
  "Send `bt' (backtrace) to GUD and display results."
  (interactive)
  (8155-gud-cmd "bt"))

;;;###autoload
(defun 8155-gud-info-locals ()
  "Send `info locals' to GUD."
  (interactive)
  (8155-gud-cmd "info locals"))

;;;###autoload
(defun 8155-gud-set-scheduler-locking (mode)
  "Set GDB scheduler-locking to MODE.
Recommended: `step' for general use, `on' during single-stepping."
  (interactive
   (list (completing-read "Mode (off/on/step): " '("off" "on" "step")
                          nil t nil nil "step")))
  (8155-gud-cmd (format "set scheduler-locking %s" mode))
  (message "scheduler-locking set to %s" mode))

;; ---------------------------------------------------------------------------
;; 5. adb logcat integration
;; ---------------------------------------------------------------------------

;;;###autoload
(defun 8155-logcat (&optional tag)
  "Open a buffer with live `adb logcat' output.
If TAG is provided, filter by that tag."
  (interactive "sLog tag (empty for all): ")
  (let ((buf (get-buffer-create "*adb-logcat*")))
    (with-current-buffer buf
      (erase-buffer)
      (let ((proc (start-process "adb-logcat" buf
                                 "adb" "logcat"
                                 (if (or (null tag) (string-empty-p tag))
                                     "-v" "threadtime")
                                 (if (or (null tag) (string-empty-p tag))
                                     "threadtime"
                                   "-s") tag)))
        (set-process-filter proc 'comint-output-filter))
      (special-mode))
    (pop-to-buffer buf)
    (message "adb logcat started%s"
             (if (or (null tag) (string-empty-p tag)) "" (format " [tag: %s]" tag)))))

;;;###autoload
(defun 8155-logcat-kill ()
  "Kill the adb logcat process and close its buffer."
  (interactive)
  (when-let ((proc (get-buffer-process "*adb-logcat*")))
    (delete-process proc))
  (when (get-buffer "*adb-logcat*")
    (kill-buffer "*adb-logcat*"))
  (message "adb logcat stopped"))

;; ---------------------------------------------------------------------------
;; 6. Key bindings
;; ---------------------------------------------------------------------------

(defvar 8155-debug-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c c") #'8155-compile-module)
    (define-key map (kbd "C-c C-a g") #'8155-gdb-debug)
    (define-key map (kbd "C-c C-a l") #'8155-logcat)
    (define-key map (kbd "C-c C-a k") #'8155-logcat-kill)
    map)
  "Keymap for 8155-debug commands.
Bind this to a prefix key in your init file, e.g.:
  (global-set-key (kbd \"C-c a\") 8155-debug-mode-map)
Or use individual bindings directly.")

;; GUD-mode specific bindings
(setup gud
  (:bind
   "C-c C-c" #'8155-gud-continue
   "C-c C-n" #'8155-gud-next
   "C-c C-s" #'8155-gud-step
   "C-c C-b" #'8155-gud-break-here
   "C-c C-p" #'8155-gud-print-var
   "C-c C-t" #'8155-gud-backtrace
   "C-c C-l" #'8155-gud-info-locals
   "C-c C-z" #'8155-gud-set-scheduler-locking))

;; Dired bindings
(setup dired
  (:bind
   "C-c P" #'8155-dired-adb-push
   "C-c p" #'8155-dired-adb-push-nativetest))

;; C/C++ mode bindings for compilation
(setup cc-mode
  (:hooks c-mode-common-hook
          (lambda ()
            (local-set-key (kbd "C-c c") #'8155-compile-module))))

;; ---------------------------------------------------------------------------
;; 7. Optional: gdb-many-windows setup
;; ---------------------------------------------------------------------------

;;;###autoload
(defun 8155-gdb-setup-windows ()
  "Configure `gdb-many-windows' layout for 8155 debugging.
Call this after GDB starts to get a 6-pane layout:
  - Source code
  - GDB console
  - Locals / Registers
  - Stack / Breakpoints"
  (interactive)
  (setq gdb-many-windows t)
  (gdb-restore-windows)
  (message "gdb-many-windows enabled"))

;; ---------------------------------------------------------------------------

(provide '8155-debug)
;;; 8155-debug.el ends here
