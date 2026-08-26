;;; init-biblio.el --- Bibliography and citations (citar) -*- lexical-binding: t; -*-

;; file:/home/wd/.config/emacs/sources/doom+/modules/tools/biblio/README.org
(setup citar
  (:option
   citar-bibliography '("~/org/refs/zotero.bib"
                        "~/org/refs/calibredb.bib"
                        "~/org/refs/user.bib")
   citar-library-paths '("~/.cache/calibre/downloads/")
   citar-notes-paths '("~/org/roam/notes/")))

(provide 'init-biblio)
;;; init-biblio.el ends here
