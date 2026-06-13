;;; init-biblio.el --- Bibliography and citations (citar) -*- lexical-binding: t; -*-

(setup citar
  (:when-loaded
    (:option
     citar-bibliography '("~/org/refs/zotero.bib"
                          "~/org/refs/calibre.bib"
                          "~/org/refs/citar.bib")
     citar-library-paths (pcase (system-name)
                           ("ubuntu2204" '("~/Sync/citar-lib/"))
                           ("arch-nuc" '("/home/data/books/citar-library/")))
     citar-notes-paths '("~/org/roam/notes/"))))

(setup reftex
  (:when-loaded
    (:option reftex-default-bibliography citar-bibliography)))

(setup citar-org-roam
  (:when-loaded
    (:option citar-org-roam-subdir "notes/")))

(provide 'init-biblio)
;;; init-biblio.el ends here
