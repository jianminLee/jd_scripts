#!/bin/sh
#自定义clone一个仓库示例脚本
  if [ ! -d "/jd_scripts_orz/" ]; then
     echo "未检查到jd_scripts_orz仓库脚本，初始化下载相关脚本"
     git clone https://github.com/jianminLee/jd_scripts.git /jd_scripts_orz
 else
     echo "更新jd_scripts_orz脚本相关文件"
     git -C /jd_scripts_orz reset --hard
     git -C /jd_scripts_orz pull --rebase
 fi
 ## 拷贝脚本到/scripts/目录下，免得安装依赖
 cp ./jd_dreamFactory.js /scripts/jd_dreamFactory_orz.js

# #自定义增加crontab任务
 ## sleep $((RANDOM % $RANDOM_DELAY_MAX)); 延迟执行，确保docker配置了RANDOM_DELAY_MAX环境变量
 echo "10 * * * * sleep $((RANDOM % $RANDOM_DELAY_MAX)); node /scripts/jd_dreamFactory_orz.js >> /scripts/logs/jd_dreamFactory_orz.log 2>&1" >> /scripts/docker/merged_list_file.sh
 # echo "59,0,1,2,3,4,5 0,9,11,13,15,17,19,20,21,22,23 * * *  node /scripts/jd_live_redrain_offical_mod.js >> /scripts/logs/jd_live_redrain_offical_mod.log 2>&1" >> /scripts/docker/merged_list_file.sh
