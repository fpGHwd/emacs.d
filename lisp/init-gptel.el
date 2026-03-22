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

(provide 'init-gptel)
;;; init-gptel.el ends here
