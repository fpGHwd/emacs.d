;;; init-read.el --- Settings for reading eBooks -*- lexical-binding: t; -*-
;;; Copyright (C) 2024 Wang Ding

(setup calibredb
  (:also-load lib-util)
  (:also-load lib-calibre)
  (:option
   calibredb-search-page-max-rows 30
   calibredb-id-width 6
   calibredb-size-show t
   calibredb-format-all-the-icons t
   calibredb-format-icons-in-terminal t
   calibredb-format-nerd-icons t)
  (:when-loaded
    (:after meow
      (add-to-list 'meow-mode-state-list '(calibredb-search-mode . motion)))

    ;; Search/browse always go through the OPDS content server; the local
    ;; library (if present) is used only to open the on-disk copy.
    (+wd/calibredb-configure-opds)

    (add-hook 'calibredb-search-mode-hook
              (lambda () (buffer-face-set :family "Sarasa Fixed SC")))

    ;; One-key: create a unified CDB-<id>.org for the book at point.
    (:bind-into calibredb-search "n" #'+wd/calibredb-org-noter)))


;; nov.el
;; https://emacs-china.org/t/emacs-epub/4713/11
;; FIXME: errors while opening `nov' files with Unicode characters
(setup nov
  (:match-file "*.epub")
  (:when-loaded
    (with-no-warnings
      (defun my-nov-content-unique-identifier (content)
        "Return the the unique identifier for CONTENT."
        (when-let* ((name (nov-content-unique-identifier-name content))
                    (selector (format "package>metadata>identifier[id='%s']"
                                      (regexp-quote name)))
                    (id (car (esxml-node-children (esxml-query selector content)))))
          (intern id)))
      (advice-add #'nov-content-unique-identifier :override #'my-nov-content-unique-identifier))))

(setup pdf-tools
  (:also-load lib-pdf-sync)
  (:when-loaded
    (:option pdf-view-continuous t)
    (defun +wd/pdf-view-enable-midnight-for-dark-theme ()
      "Enable midnight mode for PDFs when the active theme is dark."
      (require 'color)
      (when-let* ((background (face-background 'default nil t))
                  (rgb (color-name-to-rgb background)))
        (when (color-dark-p rgb)
          (pdf-view-midnight-minor-mode 1))))

    (add-hook 'pdf-view-mode-hook #'+wd/pdf-view-enable-midnight-for-dark-theme)
    (add-hook 'pdf-view-mode-hook #'+wd/pdf-sync-enable-query-on-kill)

    (setq pdf-annot-default-annotation-properties
          '((t         (label . "Wang Ding"))
            (text       (color . "#D7BA7D") (opacity . 0.9) (icon . "Note"))
            (highlight  (color . "#E5C07B") (opacity . 0.35))
            (underline  (color . "#98BE65") (opacity . 0.85))
            (squiggly   (color . "#FF6C6B") (opacity . 0.85))
            (strike-out (color . "#4DB5BD") (opacity . 0.75))))

    (map! :map pdf-view-mode-map
          :localleader
          (:prefix ("a" . "annotate")
                   "t" #'pdf-annot-add-text-annotation
                   "h" #'pdf-annot-add-highlight-markup-annotation
                   "u" #'pdf-annot-add-underline-markup-annotation
                   "s" #'pdf-annot-add-squiggly-markup-annotation
                   "x" #'pdf-annot-add-strikeout-markup-annotation
                   "l" #'pdf-annot-list-annotations
                   "d" #'pdf-annot-delete
                   "S" #'+wd/pdf-annot-sync))))


(setup org-noter
  (:also-load lib-calibre)
  ;; Keep raw-document sessions from appending book headings to the main notes.
  (:option org-noter-doc-split-fraction '(0.7 . 0.3)
           org-noter-notes-search-path (list (file-truename "~/org/noter/current")))
  (:when-loaded
    (+wd/calibredb-configure-opds)
    (add-hook 'org-noter-parse-document-property-hook
              #'+wd/org-noter-resolve-calibre-document 10)))

(setup org
  (:also-load lib-calibre)
  (:when-loaded
    (+wd/calibredb-configure-opds)
    (add-hook 'org-after-todo-state-change-hook
              #'+wd/org-noter-update-calibre-progress)))


(provide 'init-read)
;;; init-read.el ends here
