from src import command, config, redis
from telegram.ext import Updater, commandhandler
from models.db import *

if __name__ == "__main__":
    TOKEN = config.env['telegram_bot']['token']
    PORT = int(config.env['telegram_bot']['port'])

    print('检测数据库')
    if not db.table_exists(User):
        db.create_tables([User])


    print('启动webhook')
    updater = Updater(TOKEN)
    # add handlers
    updater.start_webhook(listen="0.0.0.0",
                          port=PORT,
                          url_path=TOKEN)

    updater.bot.set_webhook(config.env['telegram_bot']['url'] + TOKEN)

    handler = command.CommandHandler(updater.bot, redis.redis)

    updater.bot.set_my_commands(handler.commands())

    updater.dispatcher.add_handler(commandhandler.CommandHandler("jd_script_start", handler.jd_login_command_callback, run_async=True))

    updater.idle()