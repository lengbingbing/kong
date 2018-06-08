local BasePlugin = require "kong.plugins.base_plugin"
local TrafficHandler = BasePlugin:extend()
local cjson = require "cjson"
local responses = require "kong.tools.responses"
local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode
local body_filter = require "kong.plugins.response-transformer.body_transformer"
local header_filter = require "kong.plugins.response-transformer.header_transformer"
local is_body_transform_set = header_filter.is_body_transform_set
local is_json_body = header_filter.is_json_body
local http = require "resty.http"
local open_api_cache = require "kong.openapi.Cache"

-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function TrafficHandler:new()
  TrafficHandler.super.new(self, "my-custom-plugin")
end

function TrafficHandler:init_worker()
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  TrafficHandler.super.init_worker(self)

  -- Implement any custom logic here
end

function TrafficHandler:certificate(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  TrafficHandler.super.certificate(self)

  -- Implement any custom logic here
end

function TrafficHandler:rewrite(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  TrafficHandler.super.rewrite(self)
  

  -- Implement any custom logic here
end
local function PrintTable( tbl , level, filteDefault)
  local msg = ""
  filteDefault = filteDefault or true --默认过滤关键字（DeleteMe, _class_type）
  level = level or 1
  local indent_str = ""
  for i = 1, level do
    indent_str = indent_str.."  "
  end

  ngx.say(indent_str .. "{")
  for k,v in pairs(tbl) do
    if filteDefault then
      if k ~= "_class_type" and k ~= "DeleteMe" then
        local item_str = string.format("%s%s = %s", indent_str .. " ",tostring(k), tostring(v))
        ngx.say(item_str)
        if type(v) == "table" then
          PrintTable(v, level + 1)
        end
      end
    else
      local item_str = string.format("%s%s = %s", indent_str .. " ",tostring(k), tostring(v))
      ngx.say(item_str)
      if type(v) == "table" then
        PrintTable(v, level + 1)
      end
    end
  end
  ngx.say(indent_str .. "}")
end




function TrafficHandler:access(config)
                -- Eventually, execute the parent implementation
                -- (will log that your plugin is entering this context)

                TrafficHandler.super.access(self)
                local open_api_config = require("kong.openapi.Config");
                local config =  open_api_config:new()
                local upstream_config_data = config:getUpstaremTrafficConfig()
                -- 缓冲数据到文件中
                
                --读取到配置信息
                if(upstream_config_data~=nil) then
                        local cache = open_api_cache:new();
                        local save_cache_res = cache:setCache(upstream_config_data.domain,upstream_config_data.cacheMinute)

                        -- 按百分比返回缓存数据
                        if upstream_config_data.separateType==2 then 
                                --是否按百分比走缓存数据
                                if(upstream_config_data.separateCachePercentage>0) then    
                                   local count =  math.random(1,100)
                                   ngx.log(ngx.CRIT, "count= " ..count) 
                                   if count<= upstream_config_data.separateCachePercentage then
                                        ngx.log(ngx.CRIT, "output cache data ") 
                                        cache:outputPercentageCache(upstream_config_data.domain)
     
                                   end

                                end
                        end

                        -- -- 并发限流
                        -- upstream_config_data.trafficStrategy   value=1 返回缓存数据 value=2 返回托底数据  
                        -- upstream_config_data.bottomJson        托底数据
                        if(upstream_config_data.trafficConcurrency>0 and upstream_config_data.trafficStrategy~=1) then
                              local limit_req = require "resty.limit.req"
                              local lim, err = limit_req.new("my_limit_req_store", upstream_config_data.trafficConcurrency, 1)
                              if not lim then --申请limit_req对象失败
                                  --buildJumpParms(strategy,domain,body,status)
                                  cache:outputCacheData(upstream_config_data.trafficStrategy,upstream_config_data.domain,upstream_config_data.bottomJso,500 )
                                  ngx.log(ngx.ERR,"failed to instantiate a resty.limit.req object: ", err)
                                  
                              end
                              -- 使用ip地址作为限流的key
                              local key = ngx.var.binary_remote_addr
                              local delay, err = lim:incoming(key, true)
                              if not delay then
                              if err == "rejected" then
                                     ngx.log(ngx.ERR,"rejected")
                                   --超时
                                   cache:outputCacheData(upstream_config_data.trafficStrategy,upstream_config_data.domain,upstream_config_data.bottomJso,503 )
                                                        -- return ngx.exit(503)
                              end
                                  ngx.log(ngx.ERR,"not rejected")
                                  cache:outputCacheData(upstream_config_data.trafficStrategy,upstream_config_data.domain,upstream_config_data.bottomJso,500 )
                                                    -- ngx.log(ngx.ERR, "failed to limit req: ", err)
                                                    -- return ngx.exit(500)
                              end
                              if delay~=nil and delay > 0 then
                                    ngx.log(ngx.ERR,"delay")
                                    cache:outputCacheData(upstream_config_data.trafficStrategy,upstream_config_data.domain,upstream_config_data.bottomJso,500 )

                              end
                         end
                       

                else

                        ngx.log(ngx.CRIT, "getUpstaremTrafficConfig " .. string.format("%s",'no data' )) 
                end

end

function TrafficHandler:header_filter(config)

    TrafficHandler.super.header_filter(self)

end

function TrafficHandler:body_filter(conf)
    TrafficHandler.super.body_filter(self)

   
end

function TrafficHandler:log(config)

    TrafficHandler.super.log(self)


end


return TrafficHandler