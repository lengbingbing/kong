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

local config = require("kong.openapi.Config");
AutoRegister = {}


-- 测试用的打印table内的数据
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
 

-- str是待分割的字符串 
local function split(str,reps)
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end
-- 生成 api name
local function guid()
    math.randomseed(tonumber(tostring(ngx.now()*1000):reverse():sub(1,9)))
    local randvar = string.format("%.0f",math.random(1000000000000000000,9223372036854775807))
    return randvar
end



---
-- @function: 检测url是否存在，判断是否返回404 ,如果返回404不注册到 kong中 
-- @param: url
-- @return: true or false
local function check_url_exists(request_uri,num_retries)
    -- ngx.log(ngx.INFO," start fetch " .. request_uri)    
    local http = require "resty.http"
    local httpc = http.new()
    httpc:set_timeout(1000)
    local res, err = nil
    while(num_retries > 0 and res == nil)
    do
        ngx.log(ngx.CRIT, "try request_uri" .. request_uri)
        res, err = httpc:request_uri(request_uri, {
            method = "GET",   
            headers = {
                ["scheme"] = "http",
                ["accept"] = "*/*",
                -- ["accept-encoding"] = "gzip",
                ["cache-control"] = "no-cache",
                ["pragma"] = "no-cache",
            } ,            
        })
        if res == nil then 
           return nil
        end
        ngx.log(ngx.CRIT, "res.status="..res.status)
        if res.status == 404 or  res.status ==302 then 
              res = nil
              break
        end
        num_retries = num_retries - 1 
        ngx.log(ngx.CRIT, "num retries: " .. num_retries)
        ngx.log(ngx.CRIT, "res is nill " .. string.format("%s",res == nil))
    end

    http:close()
    if res == nil then 
        return nil
    end
    return res.body


end
---
-- @function: 检查path 是否符合规则，符合规则注册到kong中 
-- @param: url
-- @return: true or false
local function check_path_exists(paths)
  
    local uri = ngx.var.uri
    local path_table = split(paths,',')
    local flg = false
    for key, value in pairs(path_table) do  

          if(#value>0) then
              value = string.gsub(value,",","")
              ngx.log(ngx.CRIT, "uri" .. uri)
              ngx.log(ngx.CRIT, "value" .. value)
              local res = string.match(uri, '^'..value)
              if res ~=nil then
                  flg = true
                  -- ngx.log(ngx.CRIT, "res result=true" )
                  break
              else
                  ngx.log(ngx.CRIT, "res result=false" )
              end
          end


    end 

   
    return flg


end
-- @function: 同步数据到mysql
-- @param: uri 
-- @param: value   保存到consul 中的 注册KongApi 的 Json 数据
-- @return: return
local function prepareRegData(uri,value)
           
            local consul = resty_consul:new({
                    host            = config.consul.host ,
                    port            = config.consul.port,
                    connect_timeout = (60*1000), -- 60s
                    read_timeout    = (60*1000), -- 60s
                    default_args    = {
                        -- token = "my-default-token"
                    },
                    ssl             = false,
                    ssl_verify      = true,
                    sni_host        = nil,
                })
            local replace_str =  string.gsub(uri, "/", "-")
            local save_key = 'uc/openapi/autoreg/'..replace_str
            local res, err = consul:put_key(save_key,  value)
            if not res then
                ngx.log(err)
            end
            ngx.log(ngx.CRIT, 'prepareRegData  res.status ='..res.status )
end

-- @function: 不符合规则的uri 保存到consul 中
-- @param: domain : 源域名
-- @param: value:不符合规则的uri
-- @return: return
local function inconformityRegData(domain,value)

           
            local consul = resty_consul:new({
                    host            = config.consul.host ,
                    port            = config.consul.port,
                    connect_timeout = (60*1000), -- 60s
                    read_timeout    = (60*1000), -- 60s
                    default_args    = {
                        -- token = "my-default-token"
                    },
                    ssl             = false,
                    ssl_verify      = true,
                    sni_host        = nil,
                })
         
            local key = 'uc/openapi/unautoreg/'..domain
         
            local res, err = consul:get_key(key)
            if not res then
                ngx.log(ngx.CRIT, err)
                return
        
            end
            ngx.log(ngx.CRIT, 'res.status ='..res.status )

            if res.status == 404 then
                local res, err = consul:put_key(key,  value)
                if not res then
                    ngx.log(err)
                end
                
            else
               local data = res.body[1].Value
               -- ngx.log(ngx.CRIT, 'data='..data)
               data = data..','..value
               -- ngx.log(ngx.CRIT, 'data='..data)
               res, err = consul:put_key(key,data)
               if not res then
                  ngx.log(err)
               end
               
            end


end



-- @function: 自动注册函数
-- @return: return
function AutoRegister.reg()
    --nginx变量  
  
        local headers = ngx.req.get_headers() ;
        local host = split(headers["Host"],":")[1];
        local rootPath = 'uc/openapi/config/domain/';
        local path = rootPath..host;
        local uri = ngx.var.uri
        local cache_data = ngx.shared["static_config_cache"]:get(path);
        if cache_data ~= nil then
            
            local request_body = json_decode(cache_data)
            --匹配域名是否需要自动注册功能
         
            
            if  request_body.hosts == host then

                    ngx.log(ngx.CRIT, 'string.match(request_body.hosts,host) ')  
                    match_t = {} 
                    match_t.upstream_url_t={}
                    match_t.api={}
                    match_t.upstream_uri=uri
                    match_t.matches={}
                    match_t.upstream_url_t.host= string.gsub(request_body.domain, "http://", "")  
                    match_t.upstream_url_t.port=80
                    match_t.upstream_url_t.path=uri
                    match_t.upstream_url_t.scheme=request_body.protocol
                    match_t.upstream_url_t.file=uri
                    match_t.api.created_at="1527211899491"
                    match_t.api.strip_uri="true"
                    match_t.api.id=""
                    match_t.api.name=""
                    match_t.api.http_if_terminated=false
                    match_t.api.https_only=false
                    match_t.api.retries=5
                    match_t.api.upstream_send_timeout=60000
                    match_t.api.upstream_read_timeout=60000
                    match_t.api.upstream_connect_timeout=60000
                    match_t.api.preserve_host= false
                    -- 
                    local upstream_url = request_body.domain..ngx.var.uri
                    --检查源站是否可以正常访问  
                    local flg = check_path_exists(request_body.paths)
                    if flg then
                        -- 判断源是否可用
                        if check_url_exists(request_body.domain..uri,3)~=nil then
                              local publish ={}        
                              publish["uris"]= ngx.var.uri
                              publish["requestUrl"]= host..ngx.var.uri
                              publish["hosts"]= host
                              publish["methods"]= "POST,GET"
                              publish["timeout"]= request_body.timeout
                              publish["creater"]= request_body.creater
                              publish["isDelete"]= 0
                              publish["remark"]= " "
                              publish["deptid"]= request_body.deptid
                              publish["isAuth"]= 0
                              prepareRegData(ngx.var.uri,publish)
                        else
                              ngx.log(ngx.CRIT, "验证源地址失败")
                        end
                    else
                        --保存不符合uri配置的，信息到consul
                        inconformityRegData(match_t.upstream_url_t.host,ngx.var.uri)
                       
                    end
   

            end

           return match_t    
        end
        return nil

end
 

 
return AutoRegister