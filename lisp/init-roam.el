;;; ../../Sync/dotfiles/doom.d/lisp/init-org-roam.el -*- lexical-binding: t; -*-


(setup org-roam
  (:hooks org-mode-hook +wd/org-roam-maybe-track-project-tag)
  (:when-loaded
    (:also-load lib-org)
    (:option org-roam-directory "~/org/roam")
    (advice-add 'org-agenda-files :filter-return #'dynamic-agenda-files-advice)))

(defun +wd/org-roam-maybe-track-project-tag ()
  "Only track Vulpea tags in Org Roam buffers."
  (when (vulpea-buffer-p)
    (add-hook 'before-save-hook #'vulpea-project-update-tag nil t)))

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

(setup org-roam-ui
  (:when-loaded
    (:option
     org-roam-ui-sync-theme t
     org-roam-ui-follow t
     org-roam-ui-update-on-save t
     org-roam-ui-open-on-start t)))

;; todo: 如何在反向链接的 buffer 中区分显示完成和未完成的任务，并过滤分类

(provide 'init-roam)
