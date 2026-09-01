;;; transient-test.el --- Test transient-define-prefix features -*- lexical-binding: t; -*-

;; Usage:
;;   1. emacsclient -n /path/to/this/file
;;   2. M-x load-file RET /path/to/this/file RET
;;   3. M-x my-transient-demo

(require 'transient)

;; ── Basic prefix menu ─────────────────────────────────────────────────────────

(transient-define-prefix my-transient-basic ()
  "Basic transient menu with simple commands."
  ["Navigation"
   ("f" "Find file" find-file)
   ("b" "Switch buffer" consult-buffer)
   ("r" "Recent files" consult-recent-file)]
  ["Window"
   ("o" "Other window" other-window)
   ("0" "Delete window" delete-window)
   ("1" "Delete other windows" delete-other-windows)]
  ["Exit"
   ("q" "Quit" transient-quit-one)])

;; ── Prefix with arguments (switches) ──────────────────────────────────────────

(transient-define-prefix my-transient-with-args ()
  "Transient menu with toggle switches."
  :value '("--verbose")
  ["Options"
   ("-v" "Verbose" "--verbose")
   ("-d" "Dry run" "--dry-run")
   ("-i" "Ignore case" "--ignore-case")]
  ["Actions"
   ("r" "Run command" my-transient--run-with-args)
   ("q" "Quit" transient-quit-one)])

(defun my-transient--run-with-args (args)
  "Execute with ARGS collected from transient."
  (interactive (list (transient-args 'my-transient-with-args)))
  (message "Running with args: %S" args))

;; ── Prefix with infix (input) arguments ───────────────────────────────────────

(transient-define-prefix my-transient-with-input ()
  "Transient menu with user-input arguments."
  ["Parameters"
   ("-c" "Count" "--count=" :reader transient-read-number-N+)
   ("-n" "Name" "--name=" :reader transient-read-string-from-buffer)]
  ["Actions"
   ("e" "Execute" my-transient--run-with-input)
   ("q" "Quit" transient-quit-one)])

(defun my-transient--run-with-input (args)
  "Execute with input ARGS."
  (interactive (list (transient-args 'my-transient-with-input)))
  (message "Args: %S" args))

;; ── Stay-open (persistent) menu ───────────────────────────────────────────────

(transient-define-prefix my-transient-stay-open ()
  "Menu that stays open after executing commands."
  :transient-suffix 'transient--do-stay
  ["Commands (stay open)"
   ("n" "Next line" next-line)
   ("p" "Previous line" previous-line)
   ("b" "Beginning of line" move-beginning-of-line)
   ("e" "End of line" move-end-of-line)]
  ["Exit"
   ("q" "Quit" transient-quit-one)])

;; ── Nested submenu ────────────────────────────────────────────────────────────

(transient-define-prefix my-transient-nested ()
  "Menu with nested submenus."
  ["Main"
   ("f" "File ops" my-transient--file-submenu)
   ("e" "Edit ops" my-transient--edit-submenu)
   ("q" "Quit" transient-quit-one)])

(transient-define-prefix my-transient--file-submenu ()
  "File operations submenu."
  ["File"
   ("f" "Find file" find-file)
   ("s" "Save buffer" save-buffer)
   ("w" "Write file" write-file)]
  ["Back"
   ("g" "Back" transient-quit-one)])

(transient-define-prefix my-transient--edit-submenu ()
  "Edit operations submenu."
  ["Edit"
   ("c" "Copy region" kill-ring-save)
   ("x" "Cut region" kill-region)
   ("v" "Paste" yank)]
  ["Back"
   ("g" "Back" transient-quit-one)])

;; ── Full demo combining everything ────────────────────────────────────────────

(transient-define-prefix my-transient-demo ()
  "Complete transient demo menu."
  ["Basic Menus"
   ("1" "Basic menu" my-transient-basic :transient t)
   ("2" "With args" my-transient-with-args :transient t)
   ("3" "With input" my-transient-with-input :transient t)]
  ["Advanced"
   ("4" "Stay-open" my-transient-stay-open :transient t)
   ("5" "Nested menus" my-transient-nested :transient t)]
  ["Exit"
   ("q" "Quit" transient-quit-one)])

;; ── Key binding example ───────────────────────────────────────────────────────

;; Bind to a key in global-map for testing:
;; (define-key global-map (kbd "C-c t") #'my-transient-demo)

(provide 'transient-test)
;;; transient-test.el ends here
