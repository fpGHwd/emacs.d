;;; init-read.el --- Settings for reading eBooks -*- lexical-binding: t; -*-
;;; Copyright (C) 2024 Wang Ding

(setup calibredb
  (:with-function calibredb)
  (:when-loaded
    (:also-load lib-util)
    (:option
     calibredb-search-page-max-rows 30
     calibredb-ref-default-bibliography "~/org/refs/calibre.bib"
     calibredb-id-width 6
     calibredb-size-show t
     calibredb-format-all-the-icons t
     calibredb-format-icons-in-terminal t
     calibredb-opds-download-dir "~/Downloads/calibredb"
     calibredb-download-dir "~/Downloads/calibredb"
     calibredb-format-nerd-icons t
     calibredb-root-dir "http://nixos-nuc:8080/opds")

    (setq calibredb-library-alist
          `(("http://nixos-nuc:8080/opds"
             (name . "calibre")
             (account . "wd")
             (password . ,(password-store-get "calibre-lib/wd")))))

    ;; calibredb hardcodes Basic auth; Calibre content server requires Digest.
    (defun +wd/calibredb-opds-request-page--digest-auth (oldfn url &optional account password)
      (let* ((info (cdr (assoc calibredb-root-dir calibredb-library-alist)))
             (account (or account (alist-get 'account info)))
             (password (or password (alist-get 'password info))))
        (if (and account password)
            (let* ((_ (defvar request-curl-options nil))
                   (request-curl-options
                    (list "--digest" "--user" (format "%s:%s" account password))))
              (funcall oldfn url))
          (funcall oldfn url account password))))
    (advice-add 'calibredb-opds-request-page :around
                #'+wd/calibredb-opds-request-page--digest-auth)
    (defun +wd/calibredb-opds-download--digest-auth (oldfn title url fmt &optional account password)
      (cl-letf* ((orig (symbol-function 'start-process-shell-command))
                 ((symbol-function 'start-process-shell-command)
                  (lambda (name buf cmd &rest args)
                    (apply orig name buf
                           (replace-regexp-in-string "curl -u" "curl --digest -u" cmd)
                           args))))
        (funcall oldfn title url fmt account password)))
    (advice-add 'calibredb-opds-download :around
                #'+wd/calibredb-opds-download--digest-auth)
    (with-eval-after-load 'meow
      (add-hook 'calibredb-search-mode-hook #'meow-motion-mode))))


;; nov.el
;; https://emacs-china.org/t/emacs-epub/4713/11
;; FIXME: errors while opening `nov' files with Unicode characters
(setup nov
  (:match-file "\\.epub\\'")
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
  (:when-loaded
    (:also-load lib-read)

    (setq pdf-annot-default-annotation-properties
          '((t         (label . "Wang Ding"))
            (text       (color . "#FFD966") (icon . "Note"))
            (highlight  (color . "#FFD966"))
            (underline  (color . "#93C47D"))
            (squiggly   (color . "#E06C75"))
            (strike-out (color . "#76A5AF"))))

    (map! :map pdf-view-mode-map
          :localleader
          (:prefix ("a" . "annotate")
                   "t" #'pdf-annot-add-text-annotation
                   "h" #'pdf-annot-add-highlight-markup-annotation
                   "u" #'pdf-annot-add-underline-markup-annotation
                   "s" #'pdf-annot-add-squiggly-markup-annotation
                   "x" #'pdf-annot-add-strikeout-markup-annotation
                   "l" #'pdf-annot-list-annotations
                   "d" #'pdf-annot-delete)
          (:prefix ("v" . "view")
                   "z" #'+wd/zathura-open-current-pdf))))


(setup org-noter
  (:when-loaded
    (:also-load lib-read)
    (:option org-noter-doc-split-fraction '(0.618 . 0.382))

    (when (string= (system-name) "ubuntu2204")
      (setq +wd/org-noter-calibre-library-root
            "/home/wd/windows_share_dir/reference/books"))

    (add-hook 'org-noter-find-additional-notes-functions
              #'+wd/org-noter-calibre-note-name)
    (add-hook 'org-noter-parse-document-property-hook
              #'+wd/org-noter-parse-document-property-calibre)
    (add-hook 'org-after-todo-state-change-hook
              #'+wd/org-noter-auto-update-read-progress)
    (add-to-list 'org-noter-notes-search-path (file-truename "~/org/noter/current"))))


(provide 'init-read)
