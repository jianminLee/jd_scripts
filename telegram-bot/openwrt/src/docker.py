from src.config import *
from src import common

def createAndStartContainer(cookie, tgUserId, name):
    ##lua newcontainer.lua -n jd_scripts_test -e \"JD_COOKIE=pt_key=AAJgSIA0ADC-1mV_7uCjZK2kIBxYN4sdb1L9PyAktQewf5Hse7QHaFJVBE3egdRZugQF0FeiWvI\;pt_pin=fangxueyidao\;\",\"RANDOM_DELAY_MAX=
    ##600\",\"TG_BOT_TOKEN=644204874\:AAETxq7Wr2-rXEijjKYJqn3vXsCijG6xm-w\",\"TG_USER_ID=490884842\",\"CUSTOM_SHELL_FILE=https://raw.githubusercontent.com/jianminLee/jd_scripts/main/docker_shell.sh\" -m \"/opt/jd_scri
    ##pts/logs:/scripts/logs\"
    ## 拼接参数
    n = env['jd_scripts']['docker_container_prefix'] + name
    e = '\\\"JD_COOKIE='+cookie.strip()+'\\\",\\\"RANDOM_DELAY_MAX=600\\\",\\\"TG_BOT_TOKEN=' \
        +env['jd_scripts']['tg_bot_token'] \
        +'\\\",\\\"TG_USER_ID='+str(tgUserId)+'\\\"'
    m = '\\\"/opt/jd_scripts/logs/'+ str(tgUserId) +':/scripts/logs\\\"'

    command = ("cd "+ os.path.abspath('lua/') +" && lua "+ os.path.abspath('lua/dockerman.lua') +" -n " + n + ' -e ' + e + ' -m ' + m + ' -d ' + env['jd_scripts']['existed_docker_container_id']).replace(';','\\;')
    print(n+'\n'+e+'\n'+m+'\ncommand:'+command)
    result = common.run_command(command)
    for res in result:
        if res.startswith('id:'):
            #返回容器ID
            return res[3:]
    return -1

def stopAndDeleteContainer(containerId):
    command = 'cd '+os.path.abspath('lua/')+' && lua '+os.path.abspath('lua/dockerman.lua')+' -D '+containerId
    result = common.run_command(command)
    for res in result:
        if res == 0:
            #返回容器ID
            return 0
    return -1

