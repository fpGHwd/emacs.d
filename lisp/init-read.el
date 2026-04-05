;;; init-read.el --- Settings for reading eBooks -*- lexical-binding: t; -*-
;;; Copyright (C) 2024 Wang Ding

(setup calibredb
  (:with-function calibredb)
  (:only-if (or (string= (system-name) "nixos-nuc")
                (string= (system-name) "arch-nuc")))
  (:when-loaded
    (:also-load lib-misc)
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
     calibredb-library-alist `()
     calibredb-db-dir (expand-file-name "metadata.db" calibredb-root-dir)
     calibredb-root-dir (pcase system-name
                          ("nixos-nuc" "/home/wd/Calibre Library")
                          ("arch-nuc" "/home/data/books/calibre-lib")
                          ("ubuntu2204" "/home/wd/Documents/calibre-web")))

    ;; (calibredb-title-face ((t :family "Sarasa Gothic SC")))
    ;; (calibredb-comment-face ((t :family "Sarasa Gothic SC")))

    ;; for folder driver metadata: it should be .metadata.calibre
    (when (not (string= (system-name) "arch-nuc"))
      (push `(,(pcase system-name
                 ("ubuntu2204" "https://library.autove.dev/opds")
                 (_ "http://nixos-nuc.local:8083/opds"))
              (name . "calibre-web")
              (account . "wd")
              (password . ,(password-store-get "calibre-web/wd")))
            calibredb-library-alist))))



;; nov.el
;; https://emacs-china.org/t/emacs-epub/4713/11
;; FIXME: errors while opening `nov' files with Unicode characters
(use-package nov
  :mode ("\\.epub\\'" . nov-mode)
  :init
  ;; (set-evil-initial-state! 'nov-mode 'emacs)
  :config
  (with-no-warnings
    (defun my-nov-content-unique-identifier (content)
      "Return the the unique identifier for CONTENT."
      (when-let* ((name (nov-content-unique-identifier-name content))
                  (selector (format "package>metadata>identifier[id='%s']"
                                    (regexp-quote name)))
                  (id (car (esxml-node-children (esxml-query selector content)))))
        (intern id)))
    (advice-add #'nov-content-unique-identifier :override #'my-nov-content-unique-identifier)))

;; (setup nov
;;   (:file-match "\\.epub\\'")
;;   (:when-loaded
;;     (:hooks nov-mode-hook +nov-annotate-font-lock)
;;     (defface +nov-annotate-face
;;       '((t (:foreground "#86C166")))
;;       "Face for # in nov-annotate-face."
;;       :group 'nov-annotate-face)

;;     (defun +nov-annotate-font-lock ()
;;       "Set up font-lock for # in +nov-annotate-face."
;;       (font-lock-add-keywords
;;        nil
;;        '(("『\\(\\(?:.\\|\n\\)*?\\)』" . '+nov-annotate-face)))
;;       (font-lock-flush))))


(defun +wd/add-book-to-calibre ()
  (interactive)
  (let* ((postfix (list ".pdf" ".epub" ".mobi" ".azw" ".azw3"))
         (library "Calibre Library")
         (path-list (mapcar #'file-truename '("~/Downloads"
                                              "/mnt/nas/data-wd/book"
                                              "/mnt/nas/datb-wd/book")))
         (bin-path (executable-find "calibredb"))
         (password (password-store-get "calibre-lib/wd"))
         (bash-path (executable-find "bash")))
    (dolist (pa path-list)
      (dolist (pf postfix)
        (when (file-directory-p pa)
          (mapcar (lambda (path)
                    (let* ((cmd (concat bin-path
                                        " --with-library=http://nixos-nuc.local:8080"
                                        " --username=wd"
                                        " --password=" password
                                        " --duplicates add " "'" path "'")))
                      ;; (message "cmd is [%s]" cmd)
                      (set-process-sentinel
                       (start-process "calibredb-add-book" nil bash-path "-c" cmd)
                       (lambda (proc event)
                         ;; (message "event: %s" event)
                         (when (string-equal event "finished\n")
                           (delete-file path)
                           (message "Add to calibre & delete origin: %s" path))))))
                  (directory-files pa t pf)))))))


(provide 'init-read)
