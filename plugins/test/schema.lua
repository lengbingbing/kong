return {
  fields = {
    host = { required = true, type = "string" },
    port = { required = true, type = "number" },
    timeout = { default = 10000, type = "number" },
    response_timeout = { default = 10000, type = "number" },
    keepalive = { default = 60000, type = "number" }
  }
}