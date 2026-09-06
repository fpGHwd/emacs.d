;;; init-vcs.el --- Version control (Magit) configuration -*- lexical-binding: t; -*-

(defconst gptel-commit-prompt
  "The user provides the result of running `git diff --cached`. You suggest a conventional commit message. Don't add anything else to the response. The following describes conventional commits.

# Conventional Commits 1.0.0

## Summary

The Conventional Commits specification is a lightweight convention on top of commit messages.
It provides an easy set of rules for creating an explicit commit history;
which makes it easier to write automated tools on top of.
This convention dovetails with [SemVer](http://semver.org),
by describing the features, fixes, and breaking changes made in commit messages.

The commit message should be structured as follows:

---
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```
---

<br />
The commit contains the following structural elements, to communicate intent to the
consumers of your library:

1. **fix:** a commit of the _type_ `fix` patches a bug in your codebase (this correlates with [`PATCH`](http://semver.org/#summary) in Semantic Versioning).
1. **feat:** a commit of the _type_ `feat` introduces a feature to the codebase (this correlates with [`MINOR`](http://semver.org/#summary) in Semantic Versioning).
1. **BREAKING CHANGE:** a commit that has a footer `BREAKING CHANGE:`, or appends a `!` after the type/scope, introduces a breaking API change (correlating with [`MAJOR`](http://semver.org/#summary) in Semantic Versioning).
A BREAKING CHANGE can be part of commits of any _type_.
1. _types_ other than `fix:` and `feat:` are allowed, for example [@commitlint/config-conventional](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional) recommends `build:`, `chore:`, `docs:`, `refactor:`, `test:`, and others.
1. _footers_ other than `BREAKING CHANGE: <description>` may be provided and follow a convention similar to git trailer format.

A scope may be provided to a commit's type, to provide additional contextual information and is contained within parenthesis, e.g., `feat(parser): add ability to parse arrays`.")

(defun gptel-commit ()
  "Generate commit message with gptel and insert it into the buffer."
  (interactive)
  (require 'gptel)
  (let* ((lines (magit-git-lines "diff" "--cached"))
         (changes (string-join lines "\n")))
    (gptel-request changes :system gptel-commit-prompt)))

(defun +magit-or-vc-log-file (&optional prompt)
  "Show the version control log for the current file."
  (interactive "P")
  (if (and (buffer-file-name)
           (eq 'Git (vc-backend (buffer-file-name))))
      (if prompt
          (call-interactively #'magit-log)
        (magit-log-buffer-file t))
    (vc-print-log)))

(defun magit-log-dangling ()
  "Show dangling commits in a Magit log buffer."
  (interactive)
  (magit-log-setup-buffer
   (-filter
    (lambda (x) (not (or (equal "" x) (s-match "error" x))))
    (s-lines
     (shell-command-to-string
      "git fsck --no-reflogs | awk '/dangling commit/ {print $3}'")))
   '("--no-walk" "--color" "--decorate" "--follow")
   nil))

(defun +magit-blob-save ()
  "Save the current Magit blob buffer back to its file."
  (interactive)
  (let ((file magit-buffer-file-name)
        (blob-buf (current-buffer)))
    (when file
      (with-current-buffer (find-file file)
        (widen)
        (replace-buffer-contents blob-buf))
      (message "save blob to file %s" file))
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (equal magit-buffer-file-name file)
          (kill-this-buffer))))))

(defun +wd/magit-push-to-gerrit (arg)
  "Push HEAD to remote branch.
With ARG 1, prompt for a remote branch; otherwise use the current branch."
  (interactive "p")
  (let* ((current-branch (magit-get-current-branch))
         (remote-name (magit-read-remote "select remote"))
         (gitlab-url (magit-get "remote" remote-name "url"))
         (gerrit-url (replace-regexp-in-string "\\(^https?://[^/]+/\\)" "\\1a/" gitlab-url))
         (remote-branch (pcase arg
                          (1 (replace-regexp-in-string ".*/" "" (magit-read-remote-branch "remote branch")))
                          (_ current-branch))))
    (magit-git-command
     (concat "git push " gerrit-url " HEAD:refs/for/" remote-branch))))

(setup magit-clone
  (:setopt magit-clone-default-directory (concat (file-truename "~/projects/github/current") "/")))

(setup magit
  (:after meow
    ;; git-commit-mode is a minor mode, meow matches on major mode (text-mode).
    ;; Use git-commit-setup-hook to switch to insert state instead.
    (:hooks git-commit-setup-hook meow-insert-mode))
  (:when-loaded
    (transient-append-suffix 'magit-log "s" '("d" "dangling" magit-log-dangling))))

(provide 'init-vcs)
;;; init-vcs.el ends here
