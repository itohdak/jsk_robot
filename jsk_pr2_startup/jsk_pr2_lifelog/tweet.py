#!/usr/bin/env python

import roslib
roslib.load_manifest('jsk_pr2_startup')
import rospy
import twoauth,yaml,sys
import re, os
from std_msgs.msg import String


def twit_lst(tw_str):
    ret = []
    tw_len = 140
    while True:
        a = tw_str[tw_len-140:tw_len]
        if a == '':
            return ret
        tw_len = tw_len + 140
        ret.append(a)

def twit(dat):
    message = dat.data
    rospy.loginfo(rospy.get_name() + " sending %s", message)
    # search word start from / and end with {.jpeg,.jpg,.png,.gif}
    m = re.search('/\S+\.(jpeg|jpg|png|gif)', message)
    if m :
        filename = m.group(0)
        message = re.sub(filename,"",message)
        if os.path.exists(filename):
            ##rospy.logdebug(rospy.get_name() + " tweet %s with file %s", message, filename)
            twitter.status_update_with_media(message, filename)
            return

    lst = twit_lst(message)
    lst.reverse() ## tweet bottom line first
    for sub_msg in lst:
        ##rospy.logdebug(rospy.get_name() + " tweet %s", sub_msg)
        twitter.status_update(sub_msg)
    ## seg faults if message is longer than 140 byte ???
    ##twitter.status_update(message)
    return

def load_oauth_settings():
# see http://d.hatena.ne.jp/gumilab/20101004/1286154912 to setup CKEY/AKEY
    try:
        key = yaml.load(open('/var/lib/robot/twitter_account_pr2jsk.yaml'))
        global CKEY, CSECRET, AKEY, ASECRET
        CKEY = key['CKEY']
        CSECRET = key['CSECRET']
        AKEY = key['AKEY']
        ASECRET = key['ASECRET']
    except IOError as e:
        rospy.logerr('"/var/lib/robot/twitter_account_pr2jsk.yaml" not found')
        rospy.logerr("$ rosrun python_twoauth get_access_token.py")
        rospy.logerr("cat /var/lib/robot/twitter_account_pr2jsk.yaml <<EOF")
        rospy.logerr("CKEY: xxx")
        rospy.logerr("CSECRET: xxx")
        rospy.logerr("AKEY: xxx")
        rospy.logerr("ASECRET: xxx")
        rospy.logerr("EOF")
        rospy.logerr('see http://d.hatena.ne.jp/gumilab/20101004/1286154912 for detail')
        sys.exit(-1)

if __name__ == '__main__':
    rospy.init_node('rostwitter', anonymous=True)
    load_oauth_settings()
    twitter = twoauth.api(CKEY, CSECRET, AKEY, ASECRET)
    rospy.Subscriber("pr2twit", String, twit)
    rospy.spin()
