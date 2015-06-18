from bottle import route, run, response
import requests

@route('/')
def index():
    image_response = requests.get(u'http://jw.whsw.cn/whsw/other/CheckCode.aspx?datetime=az')
    response.set_header('set-cookie', image_response.headers['set-cookie'])
    response.set_header('content-type', image_response.headers['content-type'])
    return image_response.content

run(host='localhost', port=8080)
