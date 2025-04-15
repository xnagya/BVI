description = [[
Detects exposed .git directory by checking /.git/HEAD for readable Git refs.
]]

author = "Bc. András Nagy"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"vuln", "discovery"}

portrule = function(host, port)
  return port.protocol == "tcp" and port.service:match("http")
end

action = function(host, port)
  local http = require "http"
  local stdnse = require "stdnse"
  local url = "/.git/HEAD"

  local response = http.get(host, port, url)

  if not response then
    return "No response received from server"
  end

  stdnse.print_debug(1, "Git HEAD status: %s", response.status)
  stdnse.print_debug(1, "Git HEAD body: %s", response.body or "no body")

  if response.status == 200 and response.body and response.body:match("ref:") then
    return string.format(
      "[VULNERABLE] Exposed .git directory detected!\nURL: %s\nResponse: %s",
      url,
      response.body
    )
  elseif response.status == 403 then
    return "[INFO] .git directory exists but access is forbidden (403)"
  elseif response.status == 404 then
    return "[OK] .git/HEAD not found (404)"
  else
    return string.format("[UNKNOWN] Unexpected response: %s", response.status)
  end
end
