;;; -*- lexical-binding: t; -*-

(require 'jsonrpc)

(defun my-rpc-handle-request (proc string)
  "Handle RPC request with PROC and STRING."
  (let* ((req (json-parse-string string :object-type 'alist :array-type 'list))
         (method (alist-get 'method req))
         (params (alist-get 'params req))
         (result
          (pcase method
            ("add" (+ (nth 0 params) (nth 1 params)))
            ("echo" (nth 0 params))
            (_ (format "Unknown method: %s" method)))))
    (process-send-string proc (concat (json-encode `(("result" . ,result))) "\n"))))


(defun my-rpc-start-server (port)
  "Start RPC with PORT."
  (make-network-process
   :name "my-rpc-server"
   :buffer "*my-rpc-server*"
   :family 'ipv4
   :service port
   :server t
   :filter #'my-rpc-handle-request))

(defun +wd/open-my-rpc-start-server ()
  (interactive)
  (my-rpc-start-server 5000))


;; test rpc server
;; nc localhost 5000
;; {"method": "add", "params": [2, 3]}
;; {"result":5}
;; printf '{"method": "add", "params": [2, 3]}' | nc localhost 5000


;; (defun my-rpc-call (host port method params callback)
;;   (let ((proc (make-network-process
;;                :name "my-rpc-client"
;;                :buffer "*my-rpc-client*"
;;                :host host
;;                :service port
;;                :filter (lambda (proc string)
;;                          (funcall callback (json-parse-string string :object-type 'alist))
;;                          (delete-process proc)))))
;;     (process-send-string proc (concat (json-encode `(("method" . ,method)
;;                                                      ("params" . ,params))) "\n"))))


(require 'json)

;; (defun my-httpd-handler (proc req)
;;   (let ((path (httpd-parse-url req)))
;;     (cond
;;      ((string= path "/api/")
;;       (httpd-send-response proc "200 OK" "text/plain" "Hello from API!"))
;;      (t
;;       (httpd-send-response proc "404 Not Found" "text/plain" "Not Found")))))

;; (defun my-httpd-add-handler (proc req)
;;   (let* ((json-request (httpd-parse-json req))
;;          (num1 (alist-get 'num1 json-request))
;;          (num2 (alist-get 'num2 json-request))
;;          (sum (+ num1 num2)))
;;     (httpd-send-response proc "200 OK" "application/json"
;;                          (json-encode `((result . ,sum))))))

;; (add-hook 'httpd-start-hook
;;           (lambda ()
;;             (httpd-define-handler "/api/add" 'my-httpd-add-handler)))

(defun +wd/start-http-server ()
  (interactive)
  (setq httpd-root "~/public_html")
  (setq httpd-port 8089)
  (setq httpd-host "localhost")
  (httpd-start))

;; network-connection
;; network-connection-to-service
;; pcap to check connection between host and client


(provide 'lib-capture)
