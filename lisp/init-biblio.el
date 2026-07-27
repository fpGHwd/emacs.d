;;; init-biblio.el --- Bibliography and citations (citar) -*- lexical-binding: t; -*-

(setup citar
  (:option
   citar-bibliography '("~/org/refs/zotero.bib"
                        "~/org/refs/calibre.bib"
                        "~/org/refs/citar.bib")
   citar-library-paths (pcase (system-name)
                         ("ubuntu2204" '("~/Sync/citar-lib/")))
   citar-notes-paths '("~/org/roam/notes/"))
  (:with-feature reftex
    (:option reftex-default-bibliography citar-bibliography))
  (:with-feature citar-org-roam
    (:option citar-org-roam-subdir "notes/")))

(provide 'init-biblio)
;;; init-biblio.el ends here
