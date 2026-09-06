;;; init-llm.el --- AI assistant configuration (gptel, claude-code-ide) -*- lexical-binding: t; -*-

(setup gptel
  (:setopt
   gptel-default-mode 'org-mode
   gptel-crowdsourced-prompts-file
   (expand-file-name "etc/gptel/gptel-crowdsourced-prompts.csv" doom-user-dir)
   gptel-model 'gpt-5.5))

;; claude-code
(setup claude-code-ide
  (:when-loaded
    (claude-code-ide-emacs-tools-setup))) ; Optionally enable Emacs MCP tools

(provide 'init-llm)
;;; init-llm.el ends here
