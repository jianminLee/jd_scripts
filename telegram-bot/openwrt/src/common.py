import subprocess, logging

def run_command(cmd):
    ## 脚本最多三分钟后自动退出
    print('执行命令')
    try:
        proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True,
            encoding='utf8',
            bufsize=1,
            universal_newlines=True
        )
    except Exception as e:
        logging.error(e)
        return
    while True:
        r = proc.stdout.readline().strip()
        if r:
            print(r)
            yield r
        if subprocess.Popen.poll(proc) != None and not r:
            break
    proc.stdin.close()
    proc.terminate()