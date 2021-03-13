import io, subprocess
import logging
import segno
from models.db import *
from src import docker
from src import common
from telegram import update
import datetime
from telegram.bot import BotCommand


class CommandHandler:
    def __init__(self, bot, redis):
        self.bot = bot
        self.redis = redis
        self.cache_prefix = env['telegram_bot']['redis_cache_prefix'] + 'user:'

    # 获取京东cookie并且创建、启动docker容器
    def jd_login_command_callback(self, update: update, context):
        print('接收到 京东登陆命令')
        print('用户TG ID: ' + str(update.message.chat.id))
        ## docker数量超出
        if User.select().count() >= int(env['jd_scripts']['max_docker_num']):
            update.message.reply_text('用户数量已达上限:' + env['jd_scripts']['max_docker_num'])
            print('用户数量已达上限:' + env['jd_scripts']['max_docker_num'])
            return
        ## 判断管理员
        admins = env['telegram_bot']['admins'].split(',')
        if admins[0] == '' or str(update.message.chat.id) not in admins:
            update.message.reply_text('没有权限')
            print('没有权限')
            return
        ## 防止用户频繁发送登陆请求
        cache_name = self.cache_prefix + str(update.message.chat.id)
        if self.redis.get(cache_name):
            update.message.reply_text('请勿频繁提交登陆请求，每次登陆请求间隔三分钟或登陆成功！')
            print('请求频繁，拒绝请求')
            return
        self.redis.set(cache_name, 1)
        self.redis.expire(cache_name, datetime.timedelta(minutes=3))
        result = common.run_command(['docker exec -i '
                                     + env['jd_scripts']['existed_docker_container_name']
                                     + ' /bin/sh -c "node /scripts/getJDCookie.js"'])

        login_qrcode_message = {}
        for res in result:
            if res.startswith('https://plogin.m.jd.com/cgi-bin'):
                qr = segno.make(res)
                print(qr)
                qr_img = io.BytesIO()
                qr.save(qr_img, kind='png', scale=10)
                login_qrcode_message = update.message.reply_photo(qr_img.getvalue(), '京东APP扫描二维码登陆\n二维码有效期三分钟')
                continue
                ##{'message_id': 2593, 'date': 1615472636,
                # 'chat': {'id': 490884842, 'type': 'private', 'username': 'orzlee', 'first_name': 'Orz'},
                # 'entities': [], 'caption_entities': [],
                # 'photo': [{'file_id': 'AgACAgUAAxkDAAIKIWBKJ_zt2bRqqJZMiRVvHhI1_jcZAAItqzEb8q9YVs8ou--o8j7vKT8Xb3QAAwEAAwIAA3gAA37bAgABHgQ', 'file_unique_id': 'AQADKT8Xb3QAA37bAgAB', 'width': 490, 'height': 490, 'file_size': 30636},
                # {'file_id': 'AgACAgUAAxkDAAIKIWBKJ_zt2bRqqJZMiRVvHhI1_jcZAAItqzEb8q9YVs8ou--o8j7vKT8Xb3QAAwEAAwIAA20AA4DbAgABHgQ', 'file_unique_id': 'AQADKT8Xb3QAA4DbAgAB', 'width': 320, 'height': 320, 'file_size': 31843}],
                # 'new_chat_members': [], 'new_chat_photo': [], 'delete_chat_photo': False, 'group_chat_created': False, 'supergroup_chat_created': False, 'channel_chat_created': False, 'from': {'id': 644204874, 'first_name': 'OrzLee', 'is_bot': True, 'username': 'OrzLeeBot'}}
                # print(login_qrcode_message, login_qrcode_message.chat.id)
            elif res.startswith('二维码已失效'):
                update.message.reply_text(res.strip())
                continue
            elif res.startswith('pt_key='):
                ##登陆成功
                self.createDockerContainer(
                    update=update,
                    cookie=res.strip()
                )
                break

        # 删除二维码消息
        self.bot.delete_message(chat_id=login_qrcode_message.chat.id, message_id=login_qrcode_message.message_id)

    def getCookieUserId(self, cookie):
        return cookie[(cookie.find('pt_pin=') + 7):-1]


    def createDockerContainer(self, update, cookie):
        cookie_user_id = self.getCookieUserId(cookie)
        user = User.get_or_none(User.cookie_user_id == cookie_user_id)

        if user:
            if (datetime.datetime.now() - user.updated_at).days >= int(env['jd_scripts']['min_login_days']):
                ##京东用户已经存在
                ##大于N天以上才允许更新
                ## 删除已存在容器
                docker.stopAndDeleteContainer(containerId=user.container_id)
            else:
                update.message.reply_text('登陆成功，Cookies:\n' + cookie + '\n\n京东账号ID【'+cookie_user_id+'】已存在，必须大于 '+env['jd_scripts']['min_login_days']+' 天后才能重新创建')
                return
        ## 执行docker创建容器命令
        containerId = docker.createAndStartContainer(cookie=cookie, tgUserId=update.message.chat.id, name=cookie_user_id)
        print('container id:' + str(containerId))
        if containerId != -1:
            User.replace(
                cookie_user_id=cookie_user_id,
                cookie=cookie,
                container_id=containerId,
                tg_user_id=update.message.chat.id,
                tg_username=update.message.chat.username
            ).execute()
            cache_name = self.cache_prefix + str(update.message.chat.id)
            self.redis.delete(cache_name)
            update.message.reply_text('登陆成功，Cookies:\n' + cookie + '\n\ndocker容器ID:\n' + containerId)
        else:
            update.message.reply_text('登陆成功，Cookies:\n' + cookie + '\n\n创建docker容器失败请稍后重试！')


    def commands(self):
        commands = env['telegram_bot']['commands'].split(',')
        commands_arr = []
        for command in commands:
            c,d = command.split(':')
            commands_arr.append(BotCommand(c, d))
        return commands_arr