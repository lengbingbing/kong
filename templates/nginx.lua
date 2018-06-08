return [[
> if nginx_user then

> end
worker_processes ${{NGINX_WORKER_PROCESSES}};
daemon ${{NGINX_DAEMON}};
user root root ;
pid pids/nginx.pid;
error_log ${{PROXY_ERROR_LOG}} ${{LOG_LEVEL}};

> if nginx_optimizations then
worker_rlimit_nofile ${{WORKER_RLIMIT}};
> end

events {
> if nginx_optimizations then
    worker_connections ${{WORKER_CONNECTIONS}};
    multi_accept on;
> end
}

http {
    include 'nginx-kong.conf';
}
]]
