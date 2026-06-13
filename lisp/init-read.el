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
     calibredb-root-dir "/home/wd/Calibre Library")

    ;; for folder driver metadata: it should be .metadata.calibre
    (setq calibredb-library-alist
          (when calibredb-root-dir (list (list calibredb-root-dir))))
    (when (not (string= (system-name) "arch-nuc"))
      (push `("http://nixos-nuc:8083/opds"
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
                                        " --with-library=http://nixos-nuc:8080"
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


(after! pdf-tools
  (defun +wd/zathura-open-current-pdf ()
    "Open the current pdf-view buffer's file in zathura at the current page."
    (interactive)
    (unless (derived-mode-p 'pdf-view-mode)
      (user-error "Not in a pdf-view buffer"))
    (start-process "zathura" nil "zathura"
                   "-P" (number-to-string (pdf-view-current-page))
                   buffer-file-name))

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
         "z" #'+wd/zathura-open-current-pdf)))


(use-package! org-noter
  :defer t
  :custom
  (org-noter-doc-split-fraction '(0.618 . 0.382))
  :config
  (require 'lib-read)

  (when (string= (system-name) "ubuntu2204")
    (setq +wd/org-noter-calibre-library-root
          "/home/wd/windows_share_dir/reference/books"))

  (defun +wd/org-noter--find-document-in-calibre (document)
    "Resolve DOCUMENT by filename under `+wd/org-noter-calibre-library-root`."
    (let* ((doc (and (stringp document) (string-trim document)))
           (expanded (and doc (expand-file-name doc))))
      (cond
       ((or (null doc) (string-empty-p doc)) nil)
       ((file-exists-p expanded) expanded)
       ((not (file-directory-p +wd/org-noter-calibre-library-root)) nil)
       (t
        (let* ((filename (file-name-nondirectory expanded))
               (matches (directory-files-recursively
                         +wd/org-noter-calibre-library-root
                         (concat "\\`" (regexp-quote filename) "\\'")))
               (sorted (sort matches (lambda (a b) (< (length a) (length b))))))
          (car sorted))))))

  (defun +wd/org-noter-parse-document-property-calibre (document &rest _)
    "Hook for `org-noter-parse-document-property-hook' to resolve DOCUMENT path."
    (+wd/org-noter--find-document-in-calibre document))

  (defun +wd/org-noter-calibre-note-name (document-path)
    "Return notes filename for DOCUMENT-PATH by querying calibredb.
File is named calibredb-{id}.org.  If it does not yet exist in
`org-noter-notes-search-path', pre-create it with the correct heading
and NOTER_DOCUMENT property so org-noter adopts it without inserting
an auto-generated heading based on the transliterated PDF filename."
    (when-let* ((_ (require 'calibredb nil t))
                (id  (+wd/org-noter--calibre-id-from-path document-path))
                (row (car (calibredb-query
                           (format "SELECT b.title, group_concat(a.name, ' & ')
FROM books b
LEFT JOIN books_authors_link ba ON b.id = ba.book
LEFT JOIN authors a ON ba.author = a.id
WHERE b.id = %s GROUP BY b.id" id))))
                (title  (or (nth 0 row) "Unknown"))
                (author (mapconcat #'identity
                                   (seq-take (split-string (or (nth 1 row) "Unknown") " & ") 2)
                                   " & "))
                (filename (format "CDB-%s.org" id))
                (notes-dir (car org-noter-notes-search-path))
                (notes-path (expand-file-name filename notes-dir)))
      (unless (file-exists-p notes-path)
        (with-temp-file notes-path
          (insert (format "* %s - %s\n:PROPERTIES:\n:NOTER_DOCUMENT: %s\n:END:\n"
                          title author document-path))))
      filename))

  (add-hook 'org-noter-find-additional-notes-functions
            #'+wd/org-noter-calibre-note-name)
  (add-hook 'org-noter-parse-document-property-hook
            #'+wd/org-noter-parse-document-property-calibre)
  (add-hook 'org-after-todo-state-change-hook
            #'+wd/org-noter-auto-update-read-progress)
  (add-to-list 'org-noter-notes-search-path (file-truename "~/org/noter/current")))


(provide 'init-read)
