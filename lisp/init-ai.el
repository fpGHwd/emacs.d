;;; init-ai.el --- AI assistant configuration (gptel, aidermacs) -*- lexical-binding: t; -*-

(use-package! gptel
  :defer t
  :commands (gptel gptel-send gptel-menu)
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
  :commands (aidermacs-transient-menu)
  :init
  :bind (("C-c a" . aidermacs-transient-menu))
  :custom
  (aidermacs-default-chat-mode 'architect)
  (aidermacs-default-model "gpt-5-mini")
  (aidermacs-backend 'vterm)
  (aidermacs-program (executable-find "aider")))

(provide 'init-ai)
;;; init-ai.el ends here
