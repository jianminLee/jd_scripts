FIND_FILE="/scripts/docker/merged_list_file.sh"
FIND_STR="export_jd_cookies_script_orz.sh"

# merged_list_file.sh定时任务加入cookies环境变量脚本
if ! [ `grep -c "$FIND_STR" $FIND_FILE` -ne '0' ];then
      sed -i 's/\/scripts\/logs\/auto_help_export\.log/\/scripts\/logs\/auto_help_export\.log \&\& \. \/scripts\/docker\/export_jd_cookies_script_orz\.sh/g' $FIND_FILE
      ## 更新定时任务列表
      crontab $FIND_FILE
fi

CRZAY_JOY_COIN_FILE="/scripts/docker/proc_file.sh"

# joy coin脚本加入cookies环境变量脚本
if ! [ `grep -c "$FIND_STR" $CRZAY_JOY_COIN_FILE` -ne '0' ];then
      sed -i 's/node \/scripts\/jd_crazy_joy_coin\.js/\. \/scripts\/docker\/export_jd_cookies_script_orz\.sh \&\& node \/scripts\/jd_crazy_joy_coin\.js/g' $CRZAY_JOY_COIN_FILE
      sh -x /scripts/docker/proc_file.sh
fi