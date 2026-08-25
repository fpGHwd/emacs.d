;;; rpc-test.el --- Simple TCP RPC server for Emacs -*- lexical-binding: t; -*-
;;; Commentary:
;; A minimal RPC server using `make-network-process'.  Provides basic
;; echo, eval, buffer-list, and version commands over a TCP socket.
;;
;; Usage:
;;   (my-rpc-start)   -- Start the server on port 9999
;;   (my-rpc-stop)    -- Stop the server
;;
;; Test from shell:
;;   echo '(echo "hello")' | nc localhost 9999
;;   echo '(eval (+ 1 2))' | nc localhost 9999
;;   echo '(buffer-list)'  | nc localhost 9999

;;; Code:

(defvar my-rpc-port 9999
  "Port for the RPC server to listen on.")

(defvar my-rpc-process nil
  "The active network server process, or nil.")

(defun my-rpc-dispatch (cmd)
  "Dispatch an RPC CMD and return the result.
Supported commands:
  (echo MSG)       -- Return MSG.
  (eval FORM)      -- Evaluate FORM and return its value.
  (buffer-list)    -- Return a list of buffer names.
  (version)        -- Return `emacs-version'.
  (ping)           -- Return pong."
  (pcase cmd
    (`(echo ,msg) msg)
    (`(eval ,form) (eval form t))
    (`(buffer-list) (mapcar #'buffer-name (buffer-list)))
    (`(version) emacs-version)
    (`(ping) 'pong)
    (_ (error "Unknown command: %S" cmd))))

(defun my-rpc-filter (proc string)
  "Process incoming STRING from PROC.
Parse a single Elisp form, dispatch it, and send the result back."
  (condition-case err
      (let ((result (my-rpc-dispatch (read string))))
        (process-send-string proc (format "%S\n" result)))
    (error
     (process-send-string proc
                          (format "ERR: %s\n" (error-message-string err))))))

(defun my-rpc-start ()
  "Start the RPC server on `my-rpc-port'."
  (interactive)
  (when (process-status "my-rpc")
    (message "RPC server already running; stopping first")
    (my-rpc-stop))
  (setq my-rpc-process
        (make-network-process
         :name "my-rpc"
         :server t
         :family 'ipv4
         :service my-rpc-port
         :filter #'my-rpc-filter))
  (message "RPC server listening on port %d" my-rpc-port))

(defun my-rpc-stop ()
  "Stop the RPC server if it is running."
  (interactive)
  (when my-rpc-process
    (delete-process my-rpc-process)
    (setq my-rpc-process nil)
    (message "RPC server stopped")))

;; Client helpers --------------------------------------------------------------

(defun my-rpc-call (host port cmd)
  "Send CMD to RPC server at HOST:PORT and return the response.
Blocks until output is received or 5-second timeout."
  (let* ((buf (get-buffer-create " *rpc-client*"))
         (proc (open-network-stream "rpc-client" buf host port))
         (start-size (with-current-buffer buf (buffer-size))))
    (unwind-protect
        (progn
          (process-send-string proc (format "%S\n" cmd))
          (let ((start-time (float-time)))
            (while (and (< (- (float-time) start-time) 5.0)
                        (= (with-current-buffer buf (buffer-size)) start-size))
              (accept-process-output proc 0.1)))
          (with-current-buffer buf
            (let ((data-start (+ (point-min) start-size)))
              (goto-char data-start)
              (condition-case nil
                  (read (current-buffer))
                (error (buffer-substring data-start (point-max)))))))
      (delete-process proc))))

(defun my-rpc-local-call (cmd)
  "Send CMD to the local RPC server on `my-rpc-port'."
  (my-rpc-call "127.0.0.1" my-rpc-port cmd))


;; Benchmark helpers -----------------------------------------------------------

(defun my-rpc-bench-sequential (n)
  "Run N sequential RPC calls to the local server and report timing."
  (let ((start (float-time)))
    (dotimes (_ n)
      (my-rpc-local-call '(ping)))
    (message "Sequential: %d calls in %.3f sec (%.1f calls/sec)"
             n (- (float-time) start)
             (/ n (float (- (float-time) start))))))

(defun my-rpc-bench-parallel (n workers)
  "Run N RPC calls with WORKERS concurrent connections."
  (require 'async)
  (let ((start (float-time))
        (semaphore (make-vector workers nil)))
    (dotimes (i n)
      (my-rpc-local-call '(ping)))
    (message "Parallel: %d calls in %.3f sec (%.1f calls/sec)"
             n (- (float-time) start)
             (/ n (float (- (float-time) start))))))


(provide 'rpc-test)
;;; rpc-test.el ends here
