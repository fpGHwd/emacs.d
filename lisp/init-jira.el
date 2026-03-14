;;; ../../Sync/dotfiles/doom.d/lisp/init-jira.el -*- lexical-binding: t; -*-

;; https://github.com/nyyManni/ejira
(use-package! ejira
  :defer t
  :init
  (require 'password-store)
  (setq jiralib2-url              "http://jira.z-onesoftware.com:8080"
        jiralib2-auth             'token
        jiralib2-user-login-name  "wangding02"
        jiralib2-token            (password-store-get "zone/jira")

        ;; NOTE, this directory needs to be in `org-agenda-files'`
        ejira-org-directory       "~/Sync/org/jira"
        ejira-projects            '()

        ejira-priorities-alist    '(("Highest" . ?A)
                                    ("High"    . ?B)
                                    ("Medium"  . ?C)
                                    ("Low"     . ?D)
                                    ("Lowest"  . ?E))
        ejira-todo-states-alist   '(("To Do"       . 1)
                                    ("In Progress" . 2)
                                    ("Done"        . 3)))
  :config
  ;; Tries to auto-set custom fields by looking into /editmeta
  ;; of an issue and an epic.
  (add-hook 'jiralib2-post-login-hook #'ejira-guess-epic-sprint-fields)

  ;; They can also be set manually if autoconfigure is not used.
  ;; (setq ejira-sprint-field       'customfield_10001
  ;;       ejira-epic-field         'customfield_10002
  ;;       ejira-epic-summary-field 'customfield_10004)

  (require 'ejira-agenda)
  ;; Make the issues visisble in your agenda by adding `ejira-org-directory'
  ;; into your `org-agenda-files'.
  ;; (add-to-list 'org-agenda-files ejira-org-directory)

  ;; Add an agenda view to browse the issues that
  (org-add-agenda-custom-command
   '("j" "My JIRA issues"
     ((ejira-jql "assignee = currentUser() AND resolution = Unresolved AND status not in (Fixed, Implemented, Dev-Done, Verified) AND statusCategory not in (Done) ORDER BY updatedDate, createdDate"
                 ((org-agenda-overriding-header "个人未完成")))
      (ejira-jql "resolution = Unresolved AND status not in (Fixed, Implemented, Dev-Done, Verified) AND statusCategory not in (Done) AND assignee in (xuyang09, lipeng03, xulongjun, yaoguangxian, lifeng11, chenwending, wanghui18, wangyongtao, wangding02, guohongchao01, wangzhaowei02, fengbo01, liuguanwen, yinglingguang, jiangfeng04, qianchunlei, ouyanghan, zhangchao09, mashengxiang, zhangwenbing) AND issuetype in (BUG, Task, Sub-task, subTaskIssueTypes(), Story, Feature) AND (\"Epic Name\" in (\"A_NB_ZXD1.1P_AGT2_BSP&HAL\", \"AS4PR_ZXD1.1P_MULE_BSP&HAL\", A_NB_ZXD2.0E_AGT2_V1.1_SRS) OR project in (上汽大众A-NB, \"A_NB Issue List V1.0\", A_NB项目造车、路试问题_大众) OR VehicleType in (AS4PR_ZXD1.1P, ZXD2.0E平台_T1, 大众A_NB_PHEV_技术底座_T0.5, 大众A_NB_PHEV_ZXD2.0_T1)) ORDER BY \"Due Date\", createdDate, updatedDate"
                 ((org-agenda-overriding-header "1.1P 未完成")))
      ;; (ejira-jql "resolution = Unresolved AND status not in (Fixed, Implemented, Dev-Done, Verified) AND statusCategory not in (Done) AND (assignee = currentUser() OR assignee was currentUser()) ORDER BY updated DESC, assignee DESC"
      ;;            ((org-agenda-overriding-header "经手未完成")))
      ))))

(provide 'init-jira)
