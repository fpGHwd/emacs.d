;;; init-roam.el --- org-roam and org-roam-ui -*- lexical-binding: t; -*-


(setup org-roam
  (:also-load lib-org)
  (:hooks org-mode-hook +wd/org-roam-maybe-track-project-tag)
  (:option org-roam-directory "~/org/roam")
  (:when-loaded
    (advice-add 'org-agenda-files :filter-return #'dynamic-agenda-files-advice)))

(defun +wd/org-roam-maybe-track-project-tag ()
  "Only track Vulpea tags in Org Roam buffers."
  (when (vulpea-buffer-p)
    (add-hook 'before-save-hook #'vulpea-project-update-tag nil t)))

;; refs: https://org-roam.discourse.group/t/v2-ignore-headline-node-with-org-id/1793 , https://www.orgroam.com/manual.html#When-to-cache

;; todo: 如何在反向链接的 buffer 中区分显示完成和未完成的任务，并过滤分类

(provide 'init-roam)
;;; init-roam.el ends here
