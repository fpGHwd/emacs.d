;;; ../../Sync/dotfiles/doom.d/lisp/init-org-roam.el -*- lexical-binding: t; -*-


(use-package! org-roam
  :after lib-org
  ;; :hook
  ;; (before-save-hook . #'vulpea-project-udpate-tag)
  :custom
  (org-roam-directory "~/org/roam")
  :config
  (add-hook 'before-save-hook #'vulpea-project-update-tag)

  (advice-add 'org-agenda-files :filter-return #'dynamic-agenda-files-advice))

;; (use-package! org-roam-capture
;;   :defer t
;;   :hook
;;   (org-roam-capture-after-find-file-hook . org-roam-db-build-cache))

;; https://org-roam.discourse.group/t/v2-ignore-headline-node-with-org-id/1793
;; https://www.orgroam.com/manual.html#When-to-cache
;; (setq org-roam-db-node-include-function
;;       (lambda ()
;;         (not (member "ATTACH" (org-get-tags))))) ;; 很多 attach 项目也需要用 roam 查看
;; (setq +org-roam-open-buffer-on-find-file nil)

(use-package! org-roam-ui
  :if (featurep 'org-roam-ui)
  :custom
  (org-roam-ui-sync-theme t)
  (org-roam-ui-follow t)
  (org-roam-ui-update-on-save t)
  (org-roam-ui-open-on-start t))

;; todo: 如何在反向链接的 buffer 中区分显示完成和未完成的任务，并过滤分类

(provide 'init-roam)
