from configparser import ConfigParser
import os

env = ConfigParser()
env.read(os.path.abspath('env.config'), encoding='UTF-8')

# def addJDCookies(cookie):
#     cookies = env['jd_scripts']['jd_cookies'].split('&')
#     ##防止重复cookie 先删除再添加
#     cookies.remove(cookie.strip())
#     cookies.append(cookie.strip())
#     env.set('jd_scripts','jd_cookies', '&'.join(cookies))
#
# def delJDCookies(oldCookie):
#     cookies = env['jd_scripts']['jd_cookies'].split('&')
#     for index, cookie in cookies:
#         if cookie == oldCookie.strip() or cookie[(cookie.find('pt_pin=') + 7):-1] == oldCookie.strip():
#             cookies.remove(cookie)
#             env.set('jd_scripts','jd_cookies', '&'.join(cookies))