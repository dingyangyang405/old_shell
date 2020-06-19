#coding=utf-8

import sys
# import urllib2
#import urllib.parse
#import urllib.request
import json
import time
import requests
import getopt

#自定义机器人的封装类
class DtalkRobot(object):
    """docstring for DtRobot"""
    webhook = ""
    def __init__(self, webhook):
        super(DtalkRobot, self).__init__()
        self.webhook = webhook

    #text类型
    def sendText(self, msg, isAtAll=False, atMobiles=[]):
        data = {"msgtype":"text","text":{"content":msg},"at":{"atMobiles":atMobiles,"isAtAll":isAtAll}}
        return self.post(data)

    #markdown类型
    def sendMarkdown(self, msg):
        # data = {"msgtype":"markdown","markdown":{"title":title,"text":text}}
        return self.post(msg)

    #link类型
    def sendLink(self, title, text, messageUrl, picUrl=""):
        data = {"msgtype": "link","link": {"text": text, "title":title,"picUrl": picUrl,"messageUrl": messageUrl}}
        return self.post(data)

    #ActionCard类型
    def sendActionCard(self, actionCard):
        data = actionCard.getData();
        return self.post(data)

    #FeedCard类型
    def sendFeedCard(self, links):
        data = {"feedCard":{"links":links},"msgtype":"feedCard"}
        return self.post(data)

    def post(self, data):
        headers = {'content-type': 'application/json'}
        r = requests.post(self.webhook, data=data, headers=headers)
        print(r.text)
        return r.text
        # post_data = data
        # post_data = json.loads(post_data)
        # # post_data = json.JSONEncoder().encode(data)
        # # print(post_data)
        # post_data = urllib.parse.urlencode(post_data).encode("utf-8")
        # # print(post_data)
        # req = urllib.request.Request(self.webhook, data=post_data)
        # # req = urllib2.Request(self.webhook, post_data)
        # req.add_header('Content-Type', 'application/json')
        # content = urllib.request.urlopen(req).read()
        # # content = urllib2.urlopen(req).read()
        # print ("钉钉发送成功")
        # return content

#ActionCard类型消息结构
class ActionCard(object):
    """docstring for ActionCard"""
    title = ""
    text = ""
    singleTitle = ""
    singleURL = ""
    btnOrientation = 0
    hideAvatar = 0
    btns = []

    def __init__(self, arg=""):
        super(ActionCard, self).__init__()
        self.arg = arg

    def putBtn(self, title, actionURL):
        self.btns.append({"title":title,"actionURL":actionURL})

    def getData(self):
        data = {"actionCard":{"title":self.title,"text":self.text,"hideAvatar":self.hideAvatar,"btnOrientation":self.btnOrientation,"singleTitle":self.singleTitle,"singleURL":self.singleURL,"btns":self.btns},"msgtype":"actionCard"}
        return data

#FeedCard类型消息格式
class FeedLink(object):
    """docstring for FeedLink"""
    title = ""
    picUrl = ""
    messageUrl = ""

    def __init__(self, arg=""):
        super(FeedLink, self).__init__()
        self.arg = arg

    def getData(self):
        data = {"title":self.title,"picURL":self.picUrl,"messageURL":self.messageUrl}
        return data


def g_markdown(title="", text="", at=[]):

    msg = {
        "msgtype": "markdown",
        "markdown": {
             "title":title,
             "text": text
         },
        "at": {
            "atMobiles": at,
            "isAtAll": False
        }
    }

    return msg


#测试

if __name__ == "__main__":

    title = ""
    text = ""
    at = []

    try:
        opts,args = getopt.getopt(sys.argv[1:], "t:x:a:", ["title=", "text=", "at="])
        for opt,arg in opts:
            if opt in ("-t", "--title"):
                title = arg
            elif opt in ("-x", "--text"):
		text = "\n\n".join(arg.split("\n"))
                #text = text + "\n\n" + arg
            elif opt in ("-a", "--at"):
                at = arg
            else:
                print("use xxx")
                sys.exit(1)
    except getopt.GetoptError:
        # usage()
        sys.exit(1)

    msg = g_markdown(title, text, at)

    webhook = "https://oapi.dingtalk.com/robot/send?access_token=37264758dc6d2d7c3a18b66def948121610a2ceb50b8e0ab747f79f643e38e3e"
    robot = DtalkRobot(webhook)

    print (robot.sendMarkdown(json.dumps(msg)))