#Downloads JSONs of blocked by RKN IPS and domains then saves parsed data to files as IPset sets. Urls published here: https://reestr.rublacklist.net/article/api
import json
import requests
import os

stats = 'https://reestr.rublacklist.net/api/v2/json'
domains = 'https://reestr.rublacklist.net/api/v2/domains/json'
ips = 'https://reestr.rublacklist.net/api/v2/ips/json'

for str in requests.get(stats).json():
    print(str)
    break

def saveipset( list, setname ):
    os.system("ipset create {} hash:net".format(setname))
    for rec in list:
        os.system("ipset add {} {}".format(setname, rec))
    os.system("ipset save > {}".format(setname))

list = ['190.168.1.247', '192.168.1.248']
saveipset(list, "ips")