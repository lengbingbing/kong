local BasePlugin = require "kong.plugins.base_plugin"
local responses = require "kong.tools.responses"
local strip = require("pl.stringx").strip
local tonumber = tonumber
local tablex = require "pl.tablex"
-- local basic_serializer = require "serializers"
local cjson = require "cjson"
local MB = 2^20

local TestHandler = BasePlugin:extend()

TestHandler.PRIORITY = 1000

function TestHandler:access(conf)
  TestHandler.super.access(self)

  -- local uri_args = ngx.req.get_uri_args()  
  -- for k, v in pairs(uri_args) do  
  --     if type(v) == "table" then  
  --         ngx.say(k, " : ", table.concat(v, ", "), "<br/>")  
  --     else  
  --         if(k=="appid") then  
  --               if(v=="jd") then
  --                      ngx.redirect("http://jd.com", 302)  
  --               end
  --         end
  --         ngx.say(k, ": ", v, "<br/>")  
  --     end  
  -- end
--   ngx.req.set_header("Content-Type", "application/json;charset=utf8")
--   ngx.header["Content-Type"] ="application/json; charset=utf-8";
 
--   local myIP = ngx.req.get_headers()["X-Real-IP"]
--   if myIP == nil then
--     myIP = ngx.req.get_headers()["x_forwarded_for"];
--   end
--   if myIP == nil then
--     myIP = ngx.var.remote_addr;
--   end
--   ngx.header["myIP"] =myIP;
--   ngx.req.set_header("X-RateLimit-Remaining","127");
  
  

--   -- ngx.say(ngx.var.body_bytes_sent)  
 
      -- local binary_remote_addr = ngx.var.binary_remote_addr
      -- return responses.send_HTTP_FORBIDDEN(binary_remote_addr)
end

local function log(premature, conf, message)
  -- if premature then
  --   return
  -- end

  -- local ok, err
  -- local host = conf.host
  -- local port = conf.port
  -- local timeout = conf.timeout
  -- local keepalive = conf.keepalive

  -- local sock = ngx.socket.tcp()
  -- sock:settimeout(timeout)

  -- ok, err = sock:connect(host, port)
  -- if not ok then
  --   ngx.log(ngx.ERR, "[tcp-log] failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
  --   return
  -- end

  -- ok, err = sock:send(cjson.encode(message) .. "\r\n")
  -- if not ok then
  --   ngx.log(ngx.ERR, "[tcp-log] failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
  -- end

  -- ok, err = sock:setkeepalive(keepalive)
  -- if not ok then
  --   ngx.log(ngx.ERR, "[tcp-log] failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
  --   return
  -- end
end




function TestHandler:header_filter(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  -- TestHandler.super.header_filter(self);
  -- local request = ngx.var.request_time * 1000
  -- local response_timeout = config.response_timeout
  -- if config.response_timeout>0 then
  --   if request>response_timeout then
  --     ngx.exit(418);
  --  end
  -- end

end

function TestHandler:log(conf)
  -- TestHandler.super.log(self)
  -- local response_timeout = conf.response_timeout
  -- local message = basic_serializer.serialize(ngx,response_timeout)
  -- local ok, err = ngx.timer.at(0, log, conf, message)
  -- if not ok then
  --   ngx.log(ngx.ERR, "[tcp-log] failed to create timer: ", err)
  -- end

end


return TestHandler




