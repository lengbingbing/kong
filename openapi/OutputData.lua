local utils = require "kong.tools.utils"
local Router = require "kong.core.router"
local reports = require "kong.core.reports"
local balancer = require "kong.core.balancer"
local constants = require "kong.constants"
local responses = require "kong.tools.responses"
local singletons = require "kong.singletons"
local certificate = require "kong.core.certificate"
local resty_consul = require('kong.openapi.Consul')
local http = require('resty.http')
local tostring = tostring
local sub      = string.sub
local lower    = string.lower
local fmt      = string.format
local ngx      = ngx
local ERR      = ngx.ERR
local DEBUG    = ngx.DEBUG
local log      = ngx.log
local ngx_now  = ngx.now
local unpack   = unpack
local http = require "resty.http"
local cjson = require('cjson')
local json_decode = cjson.decode
local json_encode = cjson.encode
local tbl_concat = table.concat
local tbl_insert = table.insert
local tbl_insert = table.insert
local open_api_cache = require "kong.openapi.Cache"
local config = require("kong.openapi.Config");
OutputData = {}
local function split(str,reps)
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end


---
-- @function: 根据参数名生成缓存文件名
-- @return: 文件名
function getCacheName(host,request_uri)
    local filename= ngx.md5(host..request_uri)
    return filename
end

function OutputData.writeCache()
    
     local request_args_tab = ngx.req.get_uri_args()
     local optype = request_args_tab.optype
     local name = request_args_tab.name
     local key = request_args_tab.key
     local uri = request_args_tab.uri
     local status = tonumber(request_args_tab.status)
    if optype=='1' then
                ngx.log(ngx.CRIT, " request_args_tab.upstreamurl="..decodeURI(request_args_tab.upstreamurl)) 
                return ngx.exit(status)
     end
     --缓存
     if optype =='2' then
            local cache = open_api_cache:new();
            local res =  cache:read(uri,name)
            if(res==false) then
                 
                 return ngx.exit(status)
            else
                --读取到缓存数据
                for key, value in pairs(res) do  
                ngx.say(value)
                end 
                return ngx.exit(200)
            end
            
     end
     --托底
     if optype =='3' then
           
            local cache_data = ngx.shared["static_config_cache"]:get(key);
            if cache_data ~= nil then
                    local request_body = json_decode(cache_data)
                    ngx.say(request_body.bottomJson)
                    ngx.ctx.bottom = 1
            end

     end

end


 
return OutputData