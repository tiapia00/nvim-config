;; extends

(fenced_code_block
  (fenced_code_block_delimiter) @fence
  (info_string 
    (language) @injection.language (#eq? @injection.language "=latex"))
  (code_fence_content) @injection.content
  (#set! injection.language "latex"))
