
local helpers = require("kong.openapi.Helpers");
files = require("kong.openapi.Files");
local open_api_config = require "kong.openapi.Config"
openApiCache ={}



local function split(str,reps)
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end
local function getHostName()
            local headers = ngx.req.get_headers() ;
            local host = split(headers["Host"],":")[1];
            return host
end

function openApiCache:new()
	local o = {};
	o = setmetatable( o, {__index = self} );
	self:init();
	return o;
end

function openApiCache:init() 
	-- self.cachePath = config.cache.path;lu
	self.cachePath= open_api_config.cache.path
	self.cacheName= "static_cache"
	self.percentage_cacheName= "percentage"
	return true;
end

--读取文件
function openApiCache:read( uri ,filename)
	
	local filePath = files:getFilePath(uri) ~= nil and files:getFilePath(uri) or uri;
	filename = filename .. '.cache';
	filePath = self.cachePath .. filePath
	local file = helpers:rtrim( filePath, '/' ) .. '/' .. filename;
	if files:file_exists( file ) == false then
		return false;
	end
	return files:readFile( file );
end



--写数据到文件中
function openApiCache:write( uri, content,filename )
	
	-- local filename = files:getFileName( uri ) ~= nil and files:getFileName( uri ) or 'index';
	local filePath = files:getFilePath(uri) ~= nil and files:getFilePath(uri) or uri;
	filename = filename .. '.cache';
	filePath = self.cachePath .. filePath
	
	files:mkdirs(filePath);
	
	files:write( helpers:rtrim( filePath, '/' ) .. '/' .. filename, content );
	return true;
end


-- @function: 获取源站数据，默认重试3次
-- @param: request_uri    请求URL
-- @param: num_retries 	  失败重试次数
-- return: 源数据内容
function openApiCache:fetch_upstream_data(request_uri,num_retries)
	ngx.log(ngx.CRIT," start fetch " .. request_uri)	
	local http = require "resty.http"
	local httpc = http.new()
	-- local args = ngx.req.get_uri_args();
	httpc:set_timeout(1000)
	local res, err = nil
	while(num_retries > 0 and res == nil)
	do
		-- ngx.log(ngx.INFO, "try " .. num_retries)
		res, err = httpc:request_uri(request_uri, {
		    method = "GET",   
		    -- body=args,
		    headers = {
		    	["scheme"] = "http",
		    	["accept"] = "*/*",
		    	-- ["accept-encoding"] = "gzip",
		    	["cache-control"] = "no-cache",
		    	["pragma"] = "no-cache",
			} ,            
		})
		num_retries = num_retries - 1 
		
		-- ngx.log(ngx.CRIT, "res is nill " .. string.format("%s",res == nil))
	end

	http:close()

	if res == nil then 
		ngx.log(ngx.CRIT, "res is null" )
		return nil
	end
	-- ngx.log(ngx.CRIT, "res.status="..res.status )
  	if res.status == 200 then
  		-- ngx.log(ngx.CRIT, "res.body="..res.body )
  		return res.body
  	else
  		return nil
  	end

	
end




---
-- @function: 根据参数名生成缓存文件名
-- 
-- @return: 文件名
function getCacheName(host,request_uri)
    local filename= ngx.md5(host..request_uri)
    return filename
end
-- @function: 请求源站数据，保存数据进行文件缓存
-- @param: cache_name 
function openApiCache:setCache(domain,minute)	

		local request_uri = ngx.var.request_uri
		local uri = ngx.var.uri
	   	local upstream_url =domain..request_uri
	   	local host = getHostName()
	    local fileName = getCacheName(host,request_uri)
		local cache_name = self.cacheName
		local num_retries = 3
		local expire_in_second = 60*minute

		local data = ngx.shared[cache_name]:get(fileName)
		-- 判断缓存是否过期
		if data == nill then 
			-- ngx.log(ngx.CRIT, "ready cache ,beging write file " ) m
			local fetch_data = openApiCache:fetch_upstream_data(upstream_url,num_retries)		
			-- 源站取数据失败
			if fetch_data == nil then
				ngx.log(ngx.CRIT, "fetch_data is nill ,upstream_url="..upstream_url) 
				return false
			end
			--保存数据到本地文件
		    local add_cache_flg = openApiCache:write(uri,fetch_data,fileName)
		    --写文件成功后，保存缓存
		    if(add_cache_flg) then
				ngx.shared[cache_name]:set(fileName,fileName,expire_in_second)	
				return true
				-- ngx.log(ngx.CRIT, "set cache success " .. string.format("%s",cache_name )) 
			else
				return false
			end
		else
			--缓存未过期
			-- ngx.log(ngx.CRIT, "hit cache ,no write file " ) 
			return true	
		end

	
end


-- @function: 读取缓冲数据，输出到客户端
function openApiCache:getCache(domain,strategy,body)
	--缓存是否正针对get请求
	local request_method = ngx.var.request_method;
	if(request_method == "GET" ) then
			local uri = ngx.var.uri;
			local request_uri = ngx.var.request_uri
		   	local upstream_url = domain..request_uri
			local fileName = getFileName(domain,upstream_url)

			local file_table = openApiCache:read(uri ,fileName)
			if(file_table==false) then
				return false
			end
			for key, value in pairs(file_table) do  
                ngx.say(value)
            end 


            -- return ngx.exit(200)
	end
	return false

end


function openApiCache:buildJumpParms(strategy,domain,body,status)

          
            local request_uri = ngx.var.request_uri; 
            local host = getHostName()
        	local uri = ngx.var.uri;
        	local jump_url = nil
        	local upstream_url = host..uri
            local child_key =  string.gsub(upstream_url, "/", "-")
            local key = 'uc/openapi/config/upstreamurl/'..child_key
            if(strategy==1) then
                jump_url = '/outputdata?optype=1'..'&status='..status
                return true,jump_url
                            -- return false,nil
            end
            -- 缓存数据
            if(strategy==2) then

		            local cachename = getCacheName(host,request_uri)
					local data = ngx.shared["static_cache"]:get(cachename)
                    -- 判断缓存是否过期
                    if data == nill then 
                        ngx.log(ngx.CRIT, "cachename------------过期 ")    
                        return false,nil
                    end
		         	local res =  openApiCache:read(uri,cachename)
					if(res==false) then
						ngx.log(ngx.CRIT, "没有缓存文件------------过期 cachename="..cachename)    
		               return false,nil
		            else
		               jump_url = '/outputdata?name='..cachename..'&optype=2&key='..key..'&uri='..uri..'&status='..status..'&cache=true&bottom=false'
		               return true,jump_url
		           end

           end
           -- 托底
           if(strategy==3) then
                
                jump_url = '/outputdata?key='..key..'&optype=3'..'&status='..status..'&cache=false&bottom=true'
                return true,jump_url
            end
              
            if(strategy==4) then
                local cachename = getCacheName(host,request_uri)    
				local data = ngx.shared["static_cache"]:get(cachename)
                -- 判断缓存是否过期
                if data == nill then 
			             jump_url = '/outputdata?key='..key..'&optype=3'..'&status='..status..'&cache=false&bottom=true'
			             return true,jump_url
                end        	
	            local res =  openApiCache:read(uri,cachename)
	            if(res==false) then
			             
			             jump_url = '/outputdata?key='..key..'&optype=3'..'&status='..status..'&cache=false&bottom=true'
			             return true,jump_url
		        else
		                 jump_url = '/outputdata?name='..cachename..'&optype=2&key='..key..'&uri='..uri..'&status='..status..'&cache=true&bottom=false'
		                 return true,jump_url
		        end
	                 

             end



end
function openApiCache:outputCacheData(strategy,domain,body,status)
		
      local res, jump_url = openApiCache:buildJumpParms(strategy,domain,body,status)
      -- ngx.log(ngx.CRIT, "jump_url " .. jump_url) 
      if res then
        	return ngx.exec(jump_url) 
        	
      else
        	return ngx.exit(status)
      end
end
--返回按百分比限流的数据
function openApiCache:outputPercentageCache(domain)

      local res, jump_url = openApiCache:buildJumpParms(2,domain,'',200)
     
      if res then
      		 ngx.log(ngx.CRIT, "百分比输出，跳转链接==" .. jump_url) 
        	return ngx.exec(jump_url) 
 	  end


end

return openApiCache;
