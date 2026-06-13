;;; init-llm.el --- AI assistant configuration (gptel, aidermacs) -*- lexical-binding: t; -*-

(setup gptel
  (:when-loaded
    (:option
     gptel-use-curl t
     gptel-default-mode 'org-mode
     gptel-log-level nil
     gptel-crowdsourced-prompts-file
     (expand-file-name "etc/gptel/gptel-crowdsourced-prompts.csv" doom-user-dir)
     gptel-model "gpt-5-mini"
     gptel-api-key #'gptel-api-key-from-auth-source)))

(setup aidermacs
  (keymap-global-set "C-c a" #'aidermacs-transient-menu)
  (:when-loaded
    (:option
     aidermacs-default-chat-mode 'architect
     aidermacs-default-model "gpt-5-mini"
     aidermacs-backend 'vterm
     aidermacs-program (executable-find "aider"))))

;; claude-code
(setup claude-code-ide
  (keymap-global-set "C-c C-'" #'claude-code-ide-menu)
  (:when-loaded
    (claude-code-ide-emacs-tools-setup))) ; Optionally enable Emacs MCP tools

(provide 'init-llm)
;;; init-llm.el ends here
