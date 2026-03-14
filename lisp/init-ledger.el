;;; ../../Sync/dotfiles/doom.d/lisp/init-ledger.el -*- lexical-binding: t; -*-

(use-package! ledger-mode
  :defer t
  :mode "\\.ledger\\'"
  :hook
  (ledger-mode-hook . auto-revert-mode)
  :custom
  (ledger-reports
   '(("month meal expense"
      "ledger -f %(ledger-file) --monthly register ^Expenses:meal")
     ("month period"
      "ledger -f %(ledger-file) balance --period %(month) ^Income ^Expenses")
     ("year budget"
      "ledger --budget --yearly register ^Expenses -f %(ledger-file)")
     ("month budget"
      "ledger --budget --monthly register ^Expenses -f %(ledger-file)")
     ("cashflow" "ledger -f %(ledger-file) balance ^Income ^Expenses")
     ("net worth" "ledger -f %(ledger-file) balance ^Assets ^Liabilities")
     ("bal" "%(binary) -f %(ledger-file) bal")
     ;; ("bal" "%(binary) -f %(ledger-file) bal -V")
     ("reg" "%(binary) -f %(ledger-file) reg")
     ("payee" "%(binary) -f %(ledger-file) reg @%(payee)")
     ("account" "%(binary) -f %(ledger-file) reg %(account)")))
  (ledger-schedule-file "~/org/ledger/2021/schedule.ledger")
  (ledger-accounts-file "~/org/ledger/account.ledger")
  (ledger-reconcile-default-commodity "CNY")
  (ledger-reconcile-default-date-format "%Y-%m-%d"))


(provide 'init-ledger)
