--[[
LuCI - Lua Configuration Interface
Copyright 2019 lisaac <https://github.com/lisaac/luci-app-dockerman>
]]--

require "luci.util"
-- local uci = luci.model.uci.cursor()
docker = require "luci.model.docker"
dk = docker.new()
create_body = {}

containers = dk.containers:list({ query = { all = true } }).body

--//网摘,直接打印到屏幕
--function printTable(t, n)
--    if "table" ~= type(t) then
--        return 0;
--    end
--    n = n or 0;
--    local str_space = "";
--    for i = 1, n do
--        str_space = str_space .. "  ";
--    end
--    print(str_space .. "{");
--    for k, v in pairs(t) do
--        local str_k_v
--        if (type(k) == "string") then
--            str_k_v = str_space .. "  " .. tostring(k) .. " = ";
--        else
--            str_k_v = str_space .. "  [" .. tostring(k) .. "] = ";
--        end
--        if "table" == type(v) then
--            print(str_k_v);
--            printTable(v, n + 1);
--        else
--            if (type(v) == "string") then
--                str_k_v = str_k_v .. "\"" .. tostring(v) .. "\"";
--            else
--                str_k_v = str_k_v .. tostring(v);
--            end
--            print(str_k_v);
--        end
--    end
--    print(str_space .. "}");
--end


function dockerHandler(cmd, con)
    local res = dk.containers[cmd](dk, { id = con })
    if res and res.code >= 300 then
        print(-1)
        return -1
    else
        print(0)
        return 0
    end
end

local function main(cmd, options, arguments)

    if options["delete"] ~= nil then
        dockerHandler('kill', options["delete"])
        dockerHandler('remove', options["delete"])
        return
    end

    if options["name"] == nil then
        print('缺少参数 -n\n必须指定容器名称')
        print(-1)
        return
    end

    name = options["name"]

    if options["duplicate"] ~= nil then
        create_body = dk:containers_duplicate_config({ id = options["duplicate"] }) or {}
    else
        -- 取第一个容器ID复制配置
        if containers[1] ~= nil then
            create_body = dk:containers_duplicate_config({ id = containers[1].Id }) or {}
        else
            print(-1)
            return
        end
    end
    create_body.NetworkingConfig = nil

    if options["env"] ~= nil then
        -- 环境变量
        --     {
        --         "JD_COOKIE=" .. arg[1],
        --         "RANDOM_DELAY_MAX=600",
        --         "TG_BOT_TOKEN=644204874:AAETxq7Wr2-rXEijjKYJqn3vXsCijG6xm-w",
        --         "TG_USER_ID=" .. arg[2],
        --         "CUSTOM_SHELL_FILE=https://raw.githubusercontent.com/jianminLee/jd_scripts/main/docker_shell.sh",
        --     }
        print("return {" .. options["env"] .. "}")
        create_body.Env = loadstring("return {" .. options["env"] .. "}")()
    end
    if options["mount"] ~= nil then
        -- 磁盘挂载
        --     {
        --         "/opt/jd_scripts/logs/".. name ..":/scripts/logs"
        --     }
        create_body.HostConfig.Binds = loadstring("return {" .. options["mount"] .. "}")()
    end

    create_body = docker.clear_empty_tables(create_body)

    local res = dk.containers:create({ name = name, body = create_body })
    if res and res.code == 201 then
        if dockerHandler('start', res.body.Id) == 0 then
            print("id:" .. res.body.Id)
            return
        end
    else
        print('失败 code:' .. res.Code .. ' message:'.. (res.body.message and res.body.message or res.message))
    end
    print(-1)
    return
end

local cli = require("click")

local mainCommand = cli.FunctionCommand {
    desc = "openwrt docker man cli",
    options = {
        { "-m, --mount", help = "容器挂载目录" },
        { "-d, --duplicate", help = "容器ID 复制容易配置，复制后依然可以使用其他选项覆盖" },
        { "-D, --delete", help = "容器ID 删除容器" },
        { "-n, --name", help = "容器名称" },
        { "-e, --env", help = "容器环境变量" },
    },
    arguments = {

    },
    entry_func = main,
}

if cli.__name__() == "__main__" then
    cli.main(mainCommand, nil, arg)
end