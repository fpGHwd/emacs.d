;;; init-org-capture.el --- Org capture configuration -*- lexical-binding: t; -*-

(setup org
  (:when-loaded
    (:after meow
      (:hooks org-capture-mode-hook meow-insert-mode))
    (:hooks org-capture-mode-hook (lambda () (eldoc-mode -1)))
    (defvar +wd/org-capture-file-for-ios (expand-file-name "notes_ios.org" org-directory))
    (defvar +wd/scheduled-capture-args nil
      "Plist holding :title, :scheduled, :body for the `cs' capture template.")
    (add-to-list 'org-capture-templates '("c" "Capture for external app or command"))
    (add-to-list 'org-capture-templates
                 '("cn" "Capture Notes" entry (file+headline +org-capture-notes-file "Inbox")
                   "* %u %:description\n%:initial\n" :immediate-finish t :prepend t))
    (add-to-list 'org-capture-templates
                 '("ci" "Capture Bunch of Notes from iOS" entry (file+headline +wd/org-capture-file-for-ios "Inbox for iOS")
                   "* %:description\n%:initial\n" :immediate-finish t :prepend t))
    (add-to-list 'org-capture-templates
                 '("ct" "Capture Todo" entry (file+headline +org-capture-todo-file "Inbox")
                   "* [ ] %:description\n%:initial\n" :immediate-finish t :prepend t))
    (add-to-list 'org-capture-templates
                 '("cj" "Capture Journal" entry (file+olp+datetree +org-capture-journal-file)
                   "* %U %:description\n%:initial\n" :immediate-finish t :prepend t))
    (add-to-list 'org-capture-templates
                 '("cs" "Scheduled Capture" entry (file+headline +org-capture-todo-file "Inbox")
                   "* %u %(or (plist-get +wd/scheduled-capture-args :title) \"无标题\")\nSCHEDULED: %(plist-get +wd/scheduled-capture-args :scheduled)\n%(or (plist-get +wd/scheduled-capture-args :body) \"\")"
                   :immediate-finish t :prepend t))
    (load "~/projects/2026/haskell-web/scripts/lib-org-capture.el" t)))

(provide 'init-org-capture)
;;; init-org-capture.el ends here
