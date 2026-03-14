;;; ../../Sync/dotfiles/doom.d/lisp/init-gpt.el -*- lexical-binding: t; -*-

;; gptel
(use-package! gptel
  :defer t
  :custom
  (gptel-use-curl t)
  (gptel-default-mode 'org-mode)
  (gptel-log-level nil)
  (gptel-crowdsourced-prompts-file
   (expand-file-name "etc/gptel/gptel-crowdsourced-prompts.csv" doom-user-dir))
  (gptel-model "gpt-5-mini")
  (gptel-api-key #'gptel-api-key-from-auth-source))


(use-package! aidermacs
  :defer t
  :init
  :bind (("C-c a" . aidermacs-transient-menu))
  :custom
  (aidermacs-default-chat-mode 'architect)
  (aidermacs-default-model "gpt-5-mini")
  (aidermacs-backend 'vterm)
  (aidermacs-program (executable-find "aider")))

(use-package! copilot
  :defer t
  :hook (prog-mode . copilot-mode)
  :bind (:map copilot-completion-map
              ("<tab>" . 'copilot-accept-completion)
              ("TAB" . 'copilot-accept-completion)
              ("C-TAB" . 'copilot-accept-completion-by-word)
              ("C-<tab>" . 'copilot-accept-completion-by-word))
  :config
  ;; (after! (evil copilot)
  ;;   ;; Define the custom function that either accepts the completion or does the default behavior
  ;;   (defun my/copilot-tab-or-default ()
  ;;     (interactive)
  ;;     (if (and (bound-and-true-p copilot-mode)
  ;;              ;; Add any other conditions to check for active copilot suggestions if necessary
  ;;              )
  ;;         (copilot-accept-completion)
  ;;       (evil-insert 1)))    ; Default action to insert a tab. Adjust as needed.

  ;;   ;; Bind the custom function to <tab> in Evil's insert state
  ;;   (evil-define-key 'insert 'global (kbd "<tab>") 'my/copilot-tab-or-default))
  )

(provide 'init-gptel)
;;; init-gptel.el ends here
