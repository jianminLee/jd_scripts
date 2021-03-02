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

# #自定义增加crontab任务
 echo "20 * * * * node /jd_scripts_orz/jd_dreamFactory.js >> /scripts/logs/jd_dreamFactory_orz.log 2>&1" >> /scripts/docker/merged_list_file.sh
 # echo "59,0,1,2,3,4,5 0,9,11,13,15,17,19,20,21,22,23 * * *  node /scripts/jd_live_redrain_offical_mod.js >> /scripts/logs/jd_live_redrain_offical_mod.log 2>&1" >> /scripts/docker/merged_list_file.sh
