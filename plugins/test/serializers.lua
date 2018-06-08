local tablex = require "pl.tablex"

local _M = {}

local EMPTY = tablex.readonly({})



-- 删除table中的元素  
local function removeElementByKey(tbl,key)  
    --新建一个临时的table  
    local tmp ={}  
  
    --把每个key做一个下标，保存到临时的table中，转换成{1=a,2=c,3=b}   
    --组成一个有顺序的table，才能在while循环准备时使用#table  
    for i in pairs(tbl) do  
        table.insert(tmp,i)  
    end  
  
    local newTbl = {}  
    --使用while循环剔除不需要的元素  
    local i = 1  
    while i <= #tmp do  
        local val = tmp [i]  
        if val == key then  
            --如果是需要剔除则remove   
            table.remove(tmp,i)  
         else  
            --如果不是剔除，放入新的tabl中  
            newTbl[val] = tbl[val]  
            i = i + 1  
         end  
     end  
    return newTbl  
end  

function _M.serialize(ngx,response_timeout)
  local authenticated_entity
  local is_timeout 
  if ngx.ctx.authenticated_credential ~= nil then
    authenticated_entity = {
      id = ngx.ctx.authenticated_credential.id,
      consumer_id = ngx.ctx.authenticated_credential.consumer_id
    }
  end
  if response_timeout >0 then
      if (ngx.var.request_time * 1000)>response_timeout then
          is_timeout = true
      else
          is_timeout = false
      end
  else 
      is_timeout = false
  end
  
  return {
    request = {
      uri = ngx.var.request_uri,
      request_uri = ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. ngx.var.server_port .. ngx.var.request_uri,
      querystring = ngx.req.get_uri_args(), -- parameters, as a table
      method = ngx.req.get_method(), -- http method
      headers = removeElementByKey(ngx.req.get_headers(),"cookie"),
      size = ngx.var.request_length,
      
    },
    response = {
      status = ngx.status,
      headers = ngx.resp.get_headers(),
      size = ngx.var.bytes_sent,
      body_size = tonumber(ngx.var.body_bytes_sent) 
      
    },
    tries = (ngx.ctx.balancer_address or EMPTY).tries,
    latencies = {
      kong = (ngx.ctx.KONG_ACCESS_TIME or 0) +
             (ngx.ctx.KONG_RECEIVE_TIME or 0) +
             (ngx.ctx.KONG_REWRITE_TIME or 0) + 
             (ngx.ctx.KONG_BALANCER_TIME or 0),
      proxy = ngx.ctx.KONG_WAITING_TIME or -1,
      request = ngx.var.request_time * 1000,
      is_timeout = is_timeout
    },
    authenticated_entity = authenticated_entity,
    api = ngx.ctx.api,
    consumer = ngx.ctx.authenticated_consumer,
    client_ip = ngx.var.remote_addr,
    started_at = ngx.req.start_time() * 1000
  }
end

return _M