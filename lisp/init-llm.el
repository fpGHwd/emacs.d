;;; init-llm.el --- AI assistant configuration (gptel, claude-code-ide) -*- lexical-binding: t; -*-

(setup gptel
  (:option
   gptel-use-curl t
   gptel-default-mode 'org-mode
   gptel-log-level nil
   gptel-crowdsourced-prompts-file
   (expand-file-name "etc/gptel/gptel-crowdsourced-prompts.csv" doom-user-dir)
   gptel-model "gpt-5-mini"
   gptel-api-key #'gptel-api-key-from-auth-source))

;; claude-code
(setup claude-code-ide
  (keymap-global-set "C-c C-'" #'claude-code-ide-menu)
  (:when-loaded
    (claude-code-ide-emacs-tools-setup))) ; Optionally enable Emacs MCP tools

(provide 'init-llm)
;;; init-llm.el ends here
